#!/bin/bash

# Cinematch Restoration Script
# For cinematch.online deployment
# Usage: restore.sh <backup_directory> [options]

set -e

# ============================================
# CONFIGURATION
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/var/www/cinematch"
LOG_FILE="/var/log/cinematch-restore.log"

# Database configuration
DB_HOST="${DB_HOST:-your-db-cluster.b.db.ondigitalocean.com}"
DB_PORT="${DB_PORT:-25060}"
DB_NAME="${DB_NAME:-cinematch}"
DB_USER="${DB_USER:-cinematch_user}"
DB_PASS="${DB_PASS:-myssel}"

# Redis configuration
REDIS_PASSWORD="${REDIS_PASSWORD:-your_redis_password_here}"

# ============================================
# FUNCTIONS
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

show_help() {
    cat << EOF
Cinematch Restoration Script

Usage: $0 <backup_directory> [options]

Options:
    -h, --help          Show this help message
    -f, --force         Skip confirmation prompts
    --db-only          Restore database only
    --files-only       Restore files only
    --config-only      Restore configurations only
    --no-restart       Don't restart services after restore

Examples:
    $0 /mnt/backups/cinematch/weekly_2024_W45/20241103_020000
    $0 /mnt/backups/cinematch/weekly_2024_W45/20241103_020000 --db-only
    $0 /mnt/backups/cinematch/weekly_2024_W45/20241103_020000 --force

EOF
}

verify_backup() {
    local backup_dir=$1
    
    log "Verifying backup directory: $backup_dir"
    
    # Check if directory exists
    if [ ! -d "$backup_dir" ]; then
        error_exit "Backup directory not found: $backup_dir"
    fi
    
    # Check if checksums file exists
    if [ ! -f "$backup_dir/checksums.sha256" ]; then
        error_exit "Checksums file not found in backup directory"
    fi
    
    # Verify checksums
    cd "$backup_dir"
    if ! sha256sum -c checksums.sha256 > /dev/null 2>&1; then
        error_exit "Backup integrity check failed! Backup may be corrupted."
    fi
    
    log "✓ Backup integrity verified"
    
    # Check manifest
    if [ -f "$backup_dir/manifest.json" ]; then
        log "Backup manifest found:"
        jq -r '.backup_date, .domain, .backup_type' "$backup_dir/manifest.json" 2>/dev/null || cat "$backup_dir/manifest.json"
    fi
}

backup_current_state() {
    log "Creating backup of current state before restoration..."
    
    local current_backup="/tmp/cinematch_pre_restore_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$current_backup"
    
    # Backup current application
    if [ -d "$APP_DIR" ]; then
        tar -czf "$current_backup/current_app.tar.gz" -C "$(dirname $APP_DIR)" "$(basename $APP_DIR)" 2>/dev/null || true
    fi
    
    # Backup current database
    PGPASSWORD=$DB_PASS pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --format=custom \
        --file="$current_backup/current_database.dump" 2>/dev/null || true
    
    log "Current state backed up to: $current_backup"
    echo "$current_backup" > /tmp/cinematch_rollback_path
}

restore_database() {
    local backup_dir=$1
    
    log "Starting database restoration..."
    
    # Find database backup file
    local db_file
    if [ -f "$backup_dir/database.dump" ]; then
        db_file="$backup_dir/database.dump"
    else
        error_exit "Database backup file not found in $backup_dir"
    fi
    
    log "Restoring database from: $db_file"
    
    # Stop application to prevent database access
    systemctl stop cinematch 2>/dev/null || true
    
    # Restore database
    PGPASSWORD=$DB_PASS pg_restore \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        --verbose \
        "$db_file" 2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log "✓ Database restoration completed successfully"
    else
        error_exit "Database restoration failed"
    fi
}

restore_files() {
    local backup_dir=$1
    
    log "Starting files restoration..."
    
    # Find application backup file
    local app_file
    if [ -f "$backup_dir/application.tar.gz" ]; then
        app_file="$backup_dir/application.tar.gz"
    else
        error_exit "Application backup file not found in $backup_dir"
    fi
    
    log "Restoring application files from: $app_file"
    
    # Stop application
    systemctl stop cinematch 2>/dev/null || true
    
    # Backup current .env file if it exists
    if [ -f "$APP_DIR/.env" ]; then
        cp "$APP_DIR/.env" "/tmp/cinematch_env_backup_$(date +%Y%m%d_%H%M%S)"
        log "Current .env file backed up"
    fi
    
    # Remove current application directory (except logs)
    if [ -d "$APP_DIR" ]; then
        mv "$APP_DIR/logs" "/tmp/cinematch_logs_backup" 2>/dev/null || true
        rm -rf "$APP_DIR"
    fi
    
    # Extract application files
    mkdir -p "$(dirname $APP_DIR)"
    tar -xzf "$app_file" -C "$(dirname $APP_DIR)" 2>&1 | tee -a "$LOG_FILE"
    
    # Restore logs if they were backed up
    if [ -d "/tmp/cinematch_logs_backup" ]; then
        mkdir -p "$APP_DIR/logs"
        mv "/tmp/cinematch_logs_backup"/* "$APP_DIR/logs/" 2>/dev/null || true
        rm -rf "/tmp/cinematch_logs_backup"
    fi
    
    # Set correct permissions
    chown -R www-data:www-data "$APP_DIR"
    chmod -R 755 "$APP_DIR"
    
    log "✓ Files restoration completed successfully"
}

restore_configurations() {
    local backup_dir=$1
    
    log "Starting configuration restoration..."
    
    # Find configuration backup file
    local config_file
    if [ -f "$backup_dir/configurations.tar.gz" ]; then
        config_file="$backup_dir/configurations.tar.gz"
    else
        log "Configuration backup file not found, skipping..."
        return 0
    fi
    
    log "Restoring configurations from: $config_file"
    
    # Extract to temporary directory
    local temp_dir="/tmp/cinematch_config_restore"
    mkdir -p "$temp_dir"
    tar -xzf "$config_file" -C "$temp_dir" 2>&1 | tee -a "$LOG_FILE"
    
    # Restore nginx configuration
    if [ -f "$temp_dir/nginx.conf" ]; then
        cp "$temp_dir/nginx.conf" "/etc/nginx/sites-available/cinematch"
        nginx -t && systemctl reload nginx
        log "✓ Nginx configuration restored"
    fi
    
    # Restore systemd service
    if [ -f "$temp_dir/cinematch.service" ]; then
        cp "$temp_dir/cinematch.service" "/etc/systemd/system/"
        systemctl daemon-reload
        log "✓ Systemd service restored"
    fi
    
    # Restore Redis configuration
    if [ -f "$temp_dir/redis.conf" ]; then
        cp "$temp_dir/redis.conf" "/etc/redis/"
        systemctl restart redis-server
        log "✓ Redis configuration restored"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    log "✓ Configuration restoration completed successfully"
}

restore_redis() {
    local backup_dir=$1
    
    log "Starting Redis data restoration..."
    
    # Find Redis backup file
    local redis_file
    if [ -f "$backup_dir/redis.rdb.gz" ]; then
        redis_file="$backup_dir/redis.rdb.gz"
    elif [ -f "$backup_dir/redis.rdb" ]; then
        redis_file="$backup_dir/redis.rdb"
    else
        log "Redis backup file not found, skipping..."
        return 0
    fi
    
    log "Restoring Redis data from: $redis_file"
    
    # Stop Redis
    systemctl stop redis-server
    
    # Restore Redis dump
    if [[ "$redis_file" == *.gz ]]; then
        gunzip -c "$redis_file" > /var/lib/redis/dump.rdb
    else
        cp "$redis_file" /var/lib/redis/dump.rdb
    fi
    
    # Set correct ownership
    chown redis:redis /var/lib/redis/dump.rdb
    
    # Start Redis
    systemctl start redis-server
    
    # Verify Redis is working
    if redis-cli -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
        log "✓ Redis data restoration completed successfully"
    else
        log "WARNING: Redis restoration may have failed"
    fi
}

# ============================================
# MAIN SCRIPT
# ============================================

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error_exit "This script must be run as root"
fi

# Parse command line arguments
BACKUP_DIR=""
FORCE=false
DB_ONLY=false
FILES_ONLY=false
CONFIG_ONLY=false
NO_RESTART=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --db-only)
            DB_ONLY=true
            shift
            ;;
        --files-only)
            FILES_ONLY=true
            shift
            ;;
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --no-restart)
            NO_RESTART=true
            shift
            ;;
        -*)
            error_exit "Unknown option: $1"
            ;;
        *)
            if [ -z "$BACKUP_DIR" ]; then
                BACKUP_DIR="$1"
            else
                error_exit "Multiple backup directories specified"
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$BACKUP_DIR" ]; then
    echo "Error: Backup directory not specified"
    show_help
    exit 1
fi

# Start logging
log "========================================="
log "Cinematch Restoration Started"
log "Backup Source: $BACKUP_DIR"
log "========================================="

# Verify backup
verify_backup "$BACKUP_DIR"

# Show warning and get confirmation
if [ "$FORCE" = false ]; then
    echo
    echo "WARNING: This will restore Cinematch from backup!"
    echo "Source: $BACKUP_DIR"
    echo "Domain: cinematch.online"
    echo
    echo "This operation will:"
    [ "$DB_ONLY" = false ] && [ "$FILES_ONLY" = false ] && [ "$CONFIG_ONLY" = false ] && echo "  - Replace the current database"
    [ "$DB_ONLY" = false ] && [ "$FILES_ONLY" = false ] && [ "$CONFIG_ONLY" = false ] && echo "  - Replace application files"
    [ "$DB_ONLY" = false ] && [ "$FILES_ONLY" = false ] && [ "$CONFIG_ONLY" = false ] && echo "  - Replace configurations"
    [ "$DB_ONLY" = true ] && echo "  - Replace the current database ONLY"
    [ "$FILES_ONLY" = true ] && echo "  - Replace application files ONLY"
    [ "$CONFIG_ONLY" = true ] && echo "  - Replace configurations ONLY"
    echo
    read -p "Do you want to continue? (type 'yes' to confirm): " -r
    if [ "$REPLY" != "yes" ]; then
        log "Restoration cancelled by user"
        exit 0
    fi
fi

# Create backup of current state
backup_current_state

# Perform restoration based on options
if [ "$CONFIG_ONLY" = true ]; then
    restore_configurations "$BACKUP_DIR"
elif [ "$DB_ONLY" = true ]; then
    restore_database "$BACKUP_DIR"
elif [ "$FILES_ONLY" = true ]; then
    restore_files "$BACKUP_DIR"
else
    # Full restoration
    restore_database "$BACKUP_DIR"
    restore_files "$BACKUP_DIR"
    restore_configurations "$BACKUP_DIR"
    restore_redis "$BACKUP_DIR"
fi

# Restart services unless requested not to
if [ "$NO_RESTART" = false ]; then
    log "Restarting services..."
    
    systemctl start cinematch
    systemctl status cinematch --no-pager
    
    # Wait a moment for the service to start
    sleep 5
    
    # Test the application
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        log "✓ Application health check passed"
    else
        log "WARNING: Application health check failed"
    fi
    
    # Test external access
    if curl -f https://cinematch.online/health > /dev/null 2>&1; then
        log "✓ External access test passed"
    else
        log "WARNING: External access test failed"
    fi
fi

log "========================================="
log "Restoration Summary"
log "========================================="
log "Source: $BACKUP_DIR"
log "Status: COMPLETED"
log "Domain: cinematch.online"
log "Rollback available at: $(cat /tmp/cinematch_rollback_path 2>/dev/null || echo 'Not available')"
log "========================================="

log "Restoration completed successfully!"
log "Please verify the application is working correctly at https://cinematch.online"