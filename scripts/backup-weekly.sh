#!/bin/bash

# Cinematch Weekly Backup Script
# Configured for cinematch.online with PostgreSQL and Redis
# Uses root privileges with password: mqeeVEXehLje

set -e

# ============================================
# CONFIGURATION
# ============================================

# Backup settings
BACKUP_ROOT="/mnt/backups/cinematch"
DATE=$(date +%Y%m%d_%H%M%S)
WEEK=$(date +%Y_W%U)
BACKUP_RETENTION_DAYS=30

# Database configuration
DB_HOST="${DB_HOST:-your-db-cluster.b.db.ondigitalocean.com}"
DB_PORT="${DB_PORT:-25060}"
DB_NAME="${DB_NAME:-cinematch}"
DB_USER="${DB_USER:-cinematch_backup}"
DB_PASS="${DB_PASS:-backup_password_here}"

# Redis configuration
REDIS_PASSWORD="${REDIS_PASSWORD:-your_redis_password_here}"

# Application paths
APP_DIR="/var/www/cinematch"
NGINX_CONFIG="/etc/nginx/sites-available/cinematch"
SYSTEMD_SERVICE="/etc/systemd/system/cinematch.service"
REDIS_CONFIG="/etc/redis/redis.conf"

# Logging
LOG_FILE="/var/log/cinematch-backup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# ============================================
# FUNCTIONS
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

send_notification() {
    local status=$1
    local message=$2
    
    # You can configure email/slack notifications here
    if [ "$status" = "success" ]; then
        log "BACKUP SUCCESS: $message"
    else
        log "BACKUP FAILURE: $message"
    fi
}

verify_prerequisites() {
    log "Verifying prerequisites..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then 
        error_exit "This script must be run as root"
    fi
    
    # Check if backup volume is mounted
    if ! mountpoint -q /mnt/backups; then
        error_exit "Backup volume is not mounted at /mnt/backups"
    fi
    
    # Check available disk space (minimum 5GB)
    available_space=$(df /mnt/backups | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 5242880 ]; then
        error_exit "Insufficient disk space on backup volume"
    fi
    
    # Check required commands
    for cmd in pg_dump redis-cli tar gzip sha256sum curl; do
        if ! command -v $cmd &> /dev/null; then
            error_exit "Required command '$cmd' is not installed"
        fi
    done
    
    log "Prerequisites verified successfully"
}

# ============================================
# MAIN BACKUP PROCESS
# ============================================

log "========================================="
log "Cinematch Weekly Backup Started"
log "Domain: cinematch.online"
log "========================================="

# Verify prerequisites
verify_prerequisites

# Create weekly backup directory
WEEKLY_DIR="$BACKUP_ROOT/weekly_$WEEK"
BACKUP_DIR="$WEEKLY_DIR/$DATE"
mkdir -p "$BACKUP_DIR"
log "Backup directory created: $BACKUP_DIR"

# ============================================
# 1. DATABASE BACKUP
# ============================================

log "Starting PostgreSQL database backup..."

# Export database with custom format for flexibility
PGPASSWORD=$DB_PASS pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --no-password \
    --verbose \
    --format=custom \
    --compress=9 \
    --file="$BACKUP_DIR/database.dump" \
    2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log "Database backup completed successfully"
    
    # Also create SQL format backup for easy viewing
    PGPASSWORD=$DB_PASS pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --no-password \
        --format=plain \
        --file="$BACKUP_DIR/database.sql"
    
    gzip "$BACKUP_DIR/database.sql"
    log "SQL format backup created: database.sql.gz"
else
    error_exit "Database backup failed"
fi

# ============================================
# 2. APPLICATION FILES BACKUP
# ============================================

log "Starting application files backup..."

# Create list of files to exclude
cat > "$BACKUP_DIR/exclude.txt" <<EOF
venv/
__pycache__/
*.pyc
.git/
logs/*.log
instance/tmp/
uploads/tmp/
.env.local
.env.*.local
node_modules/
EOF

# Backup application files
tar -czf "$BACKUP_DIR/application.tar.gz" \
    --exclude-from="$BACKUP_DIR/exclude.txt" \
    -C "$(dirname $APP_DIR)" \
    "$(basename $APP_DIR)" \
    2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log "Application files backup completed"
    rm "$BACKUP_DIR/exclude.txt"
else
    error_exit "Application files backup failed"
fi

# ============================================
# 3. CONFIGURATION FILES BACKUP
# ============================================

log "Starting configuration files backup..."

# Create temporary directory for configs
CONFIG_TEMP="$BACKUP_DIR/configs_temp"
mkdir -p "$CONFIG_TEMP"

# Copy configuration files
cp "$NGINX_CONFIG" "$CONFIG_TEMP/nginx.conf" 2>/dev/null || true
cp "$SYSTEMD_SERVICE" "$CONFIG_TEMP/cinematch.service" 2>/dev/null || true
cp "$REDIS_CONFIG" "$CONFIG_TEMP/redis.conf" 2>/dev/null || true
cp "$APP_DIR/.env" "$CONFIG_TEMP/app.env" 2>/dev/null || true

# Copy SSL certificates info (not the actual certificates)
echo "SSL Certificate Information for cinematch.online" > "$CONFIG_TEMP/ssl_info.txt"
echo "==========================================" >> "$CONFIG_TEMP/ssl_info.txt"
openssl x509 -in /etc/letsencrypt/live/cinematch.online/cert.pem -noout -dates >> "$CONFIG_TEMP/ssl_info.txt" 2>/dev/null || true

# Create tarball of configs
tar -czf "$BACKUP_DIR/configurations.tar.gz" -C "$CONFIG_TEMP" . 2>&1 | tee -a "$LOG_FILE"
rm -rf "$CONFIG_TEMP"

log "Configuration files backup completed"

# ============================================
# 4. REDIS DATA BACKUP
# ============================================

log "Starting Redis data backup..."

# Trigger Redis background save
redis-cli -a "$REDIS_PASSWORD" BGSAVE > /dev/null 2>&1

# Wait for background save to complete
while [ $(redis-cli -a "$REDIS_PASSWORD" LASTSAVE 2>/dev/null) -eq $(redis-cli -a "$REDIS_PASSWORD" LASTSAVE 2>/dev/null) ]; do
    sleep 1
done

# Copy Redis dump file
if [ -f "/var/lib/redis/dump.rdb" ]; then
    cp "/var/lib/redis/dump.rdb" "$BACKUP_DIR/redis.rdb"
    gzip "$BACKUP_DIR/redis.rdb"
    log "Redis data backup completed: redis.rdb.gz"
else
    log "WARNING: Redis dump file not found"
fi

# ============================================
# 5. CREATE BACKUP MANIFEST
# ============================================

log "Creating backup manifest..."

cat > "$BACKUP_DIR/manifest.json" <<EOF
{
    "backup_date": "$(date -Iseconds)",
    "backup_type": "weekly_full",
    "domain": "cinematch.online",
    "server": {
        "hostname": "$(hostname)",
        "ip": "$(curl -s ifconfig.me)",
        "os": "$(lsb_release -ds)",
        "kernel": "$(uname -r)"
    },
    "database": {
        "host": "$DB_HOST",
        "name": "$DB_NAME",
        "backup_file": "database.dump",
        "sql_backup": "database.sql.gz"
    },
    "files": {
        "application": "application.tar.gz",
        "configurations": "configurations.tar.gz",
        "redis": "redis.rdb.gz"
    },
    "retention_days": $BACKUP_RETENTION_DAYS
}
EOF

# ============================================
# 6. GENERATE CHECKSUMS
# ============================================

log "Generating checksums..."

cd "$BACKUP_DIR"
sha256sum *.dump *.tar.gz *.gz 2>/dev/null > checksums.sha256
log "Checksums generated: checksums.sha256"

# ============================================
# 7. CREATE BACKUP REPORT
# ============================================

log "Creating backup report..."

BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
FILE_COUNT=$(find "$BACKUP_DIR" -type f | wc -l)

cat > "$BACKUP_DIR/report.txt" <<EOF
=====================================
Cinematch Backup Report
=====================================
Date: $(date)
Domain: cinematch.online
Backup Location: $BACKUP_DIR
Total Size: $BACKUP_SIZE
Files: $FILE_COUNT

Contents:
---------
$(ls -lh "$BACKUP_DIR" | grep -v "^total")

Verification:
-------------
Database backup: $([ -f "$BACKUP_DIR/database.dump" ] && echo "✓ OK" || echo "✗ FAILED")
Application backup: $([ -f "$BACKUP_DIR/application.tar.gz" ] && echo "✓ OK" || echo "✗ FAILED")
Configuration backup: $([ -f "$BACKUP_DIR/configurations.tar.gz" ] && echo "✓ OK" || echo "✗ FAILED")
Redis backup: $([ -f "$BACKUP_DIR/redis.rdb.gz" ] && echo "✓ OK" || echo "✗ FAILED")
Checksums: $([ -f "$BACKUP_DIR/checksums.sha256" ] && echo "✓ OK" || echo "✗ FAILED")

Next Scheduled Backup: $(date -d "next Sunday 02:00")
=====================================
EOF

cat "$BACKUP_DIR/report.txt"

# ============================================
# 8. CLEANUP OLD BACKUPS
# ============================================

log "Cleaning old backups (older than $BACKUP_RETENTION_DAYS days)..."

# Find and remove old backup directories
find "$BACKUP_ROOT" -type d -name "weekly_*" -mtime +$BACKUP_RETENTION_DAYS -exec rm -rf {} + 2>/dev/null || true

# Count remaining backups
REMAINING_BACKUPS=$(find "$BACKUP_ROOT" -type d -name "weekly_*" | wc -l)
log "Cleanup completed. Remaining backup sets: $REMAINING_BACKUPS"

# ============================================
# 9. VERIFY BACKUP INTEGRITY
# ============================================

log "Verifying backup integrity..."

cd "$BACKUP_DIR"
if sha256sum -c checksums.sha256 > /dev/null 2>&1; then
    log "✓ Backup integrity verified successfully"
    BACKUP_STATUS="SUCCESS"
else
    log "✗ Backup integrity verification failed!"
    BACKUP_STATUS="FAILED"
fi

# ============================================
# 10. FINAL SUMMARY
# ============================================

log "========================================="
log "Backup Summary"
log "========================================="
log "Status: $BACKUP_STATUS"
log "Location: $BACKUP_DIR"
log "Size: $BACKUP_SIZE"
log "Duration: $SECONDS seconds"
log "========================================="

# Send notification
send_notification "$BACKUP_STATUS" "Weekly backup completed. Size: $BACKUP_SIZE, Location: $BACKUP_DIR"

# Set appropriate exit code
if [ "$BACKUP_STATUS" = "SUCCESS" ]; then
    exit 0
else
    exit 1
fi