#!/bin/bash

# Cinematch Production Setup Script
# For cinematch.online deployment
# Run as: sudo ./setup-production.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error "This script must be run as root (use sudo)"
fi

log "Starting Cinematch Production Setup for cinematch.online"
log "=================================================="

# 1. Update system
log "Updating system packages..."
apt update && apt upgrade -y

# 2. Install essential packages
log "Installing essential packages..."
apt install -y \
    python3.11 \
    python3-pip \
    python3.11-venv \
    postgresql-client \
    redis-server \
    redis-tools \
    nginx \
    supervisor \
    git \
    curl \
    certbot \
    python3-certbot-nginx \
    jq \
    htop \
    ufw

# 3. Configure UFW Firewall
log "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 4. Set up attached volume for backups
log "Setting up backup volume..."
BACKUP_DEVICE="/dev/sda"  # Adjust as needed
BACKUP_MOUNT="/mnt/backups"

# Check if device exists
if [ -b "$BACKUP_DEVICE" ]; then
    # Format if needed (be careful!)
    if ! blkid "$BACKUP_DEVICE" | grep -q ext4; then
        warn "Formatting backup device $BACKUP_DEVICE..."
        mkfs.ext4 "$BACKUP_DEVICE"
    fi
    
    # Create mount point and mount
    mkdir -p "$BACKUP_MOUNT"
    if ! mountpoint -q "$BACKUP_MOUNT"; then
        mount "$BACKUP_DEVICE" "$BACKUP_MOUNT"
    fi
    
    # Add to fstab
    if ! grep -q "$BACKUP_DEVICE" /etc/fstab; then
        echo "$BACKUP_DEVICE $BACKUP_MOUNT ext4 defaults,nofail,discard 0 2" >> /etc/fstab
    fi
    
    # Create backup directory structure
    mkdir -p "$BACKUP_MOUNT/cinematch"
    chmod 700 "$BACKUP_MOUNT/cinematch"
    
    log "Backup volume configured at $BACKUP_MOUNT"
else
    warn "Backup device $BACKUP_DEVICE not found. Please attach volume and rerun."
fi

# 5. Configure Redis
log "Configuring Redis..."
systemctl stop redis-server

# Backup original config
cp /etc/redis/redis.conf /etc/redis/redis.conf.backup

# Generate Redis password
REDIS_PASSWORD=$(openssl rand -hex 32)

# Configure Redis
cat > /etc/redis/redis.conf <<EOF
# Redis Configuration for Cinematch
bind 127.0.0.1 ::1
protected-mode yes
port 6379
timeout 300
tcp-keepalive 300

# Persistence
save 900 1
save 300 10
save 60 10000
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis

# Security
requirepass $REDIS_PASSWORD

# Memory Management
maxmemory 512mb
maxmemory-policy allkeys-lru

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Append Only File
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
EOF

systemctl start redis-server
systemctl enable redis-server

# Test Redis
redis-cli -a "$REDIS_PASSWORD" ping
log "Redis configured with password: $REDIS_PASSWORD"

# 6. Create application user and directories
log "Setting up application structure..."
useradd -m -s /bin/bash cinematch 2>/dev/null || true
usermod -aG www-data cinematch

# Ensure proper ownership
chown -R www-data:www-data /var/www/cinematch
chmod -R 755 /var/www/cinematch

# 7. Set up Python environment
log "Setting up Python environment..."
cd /var/www/cinematch

# Create virtual environment
sudo -u www-data python3.11 -m venv venv
sudo -u www-data ./venv/bin/pip install --upgrade pip

# Install Python packages
sudo -u www-data ./venv/bin/pip install -r requirements.txt

# Install Playwright browsers
sudo -u www-data ./venv/bin/playwright install chromium
sudo -u www-data ./venv/bin/playwright install-deps chromium

# 8. Create systemd service
log "Creating systemd service..."
cat > /etc/systemd/system/cinematch.service <<EOF
[Unit]
Description=Cinematch AI Movie Recommendation Service
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=notify
User=www-data
Group=www-data
RuntimeDirectory=cinematch
WorkingDirectory=/var/www/cinematch
Environment="PATH=/var/www/cinematch/venv/bin"
ExecStart=/var/www/cinematch/venv/bin/gunicorn app:app -c gunicorn.conf.py
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=10

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/www/cinematch/logs /var/www/cinematch/instance
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true
LockPersonality=true
RestrictRealtime=true
RestrictSUIDSGID=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cinematch

# 9. Configure nginx
log "Configuring nginx..."
cat > /etc/nginx/sites-available/cinematch <<'EOF'
upstream cinematch_app {
    server 127.0.0.1:5000 fail_timeout=0;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name cinematch.online www.cinematch.online;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Main HTTPS Server (will be updated after SSL setup)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name cinematch.online www.cinematch.online;
    
    # Temporary self-signed certificate (will be replaced)
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
    
    location / {
        proxy_pass http://cinematch_app;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /static {
        alias /var/www/cinematch/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Enable cinematch site
ln -sf /etc/nginx/sites-available/cinematch /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t
systemctl restart nginx

# 10. Set up SSL certificate
log "Setting up SSL certificate for cinematch.online..."
mkdir -p /var/www/certbot

# Get SSL certificate
certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --non-interactive \
    --agree-tos \
    --email admin@cinematch.online \
    --domains cinematch.online,www.cinematch.online \
    --expand || warn "SSL certificate setup failed. You may need to configure DNS first."

# Update nginx with proper SSL configuration if certificate was obtained
if [ -f "/etc/letsencrypt/live/cinematch.online/fullchain.pem" ]; then
    log "Updating nginx with SSL configuration..."
    cat > /etc/nginx/sites-available/cinematch <<'EOF'
upstream cinematch_app {
    server 127.0.0.1:5000 fail_timeout=0;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name cinematch.online www.cinematch.online;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Main HTTPS Server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name cinematch.online www.cinematch.online;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/cinematch.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cinematch.online/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/cinematch.online/chain.pem;
    
    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    location / {
        proxy_pass http://cinematch_app;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /static {
        alias /var/www/cinematch/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    nginx -t && systemctl reload nginx
fi

# 11. Set up SSL auto-renewal
log "Setting up SSL auto-renewal..."
cat > /etc/cron.d/certbot-renewal <<EOF
# Check for SSL renewal twice daily
0 0,12 * * * root certbot renew --quiet --no-self-upgrade --post-hook "systemctl reload nginx"

# Force renewal every 60 days
0 3 */60 * * root certbot renew --force-renewal --quiet --no-self-upgrade --post-hook "systemctl reload nginx"
EOF

# 12. Set up backup cron job
log "Setting up backup system..."
chmod +x /var/www/cinematch/scripts/backup-weekly.sh
chmod +x /var/www/cinematch/scripts/restore.sh

# Create weekly backup cron job
cat > /etc/cron.d/cinematch-backup <<EOF
# Cinematch Weekly Backup - Runs every Sunday at 2 AM
# Using root with password: mqeeVEXehLje
0 2 * * 0 root /var/www/cinematch/scripts/backup-weekly.sh
EOF

# 13. Create .env file with API keys
log "Creating environment configuration with API keys..."
if [ ! -f "/var/www/cinematch/.env" ]; then
    cp /var/www/cinematch/.env.example /var/www/cinematch/.env
    
    # Update Redis password in .env
    sed -i "s|REDIS_URL=redis://localhost:6379/0|REDIS_URL=redis://:$REDIS_PASSWORD@localhost:6379/0|g" /var/www/cinematch/.env
    
    # Generate additional secure keys
    SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    ENCRYPTION_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
    ADMIN_PATH=$(python3 -c "import secrets; print('admin-' + secrets.token_urlsafe(16))")
    
    # Update generated keys in .env
    sed -i "s|SECRET_KEY=.*|SECRET_KEY=$SECRET_KEY|g" /var/www/cinematch/.env
    sed -i "s|ENCRYPTION_KEY=.*|ENCRYPTION_KEY=$ENCRYPTION_KEY|g" /var/www/cinematch/.env
    sed -i "s|ADMIN_SECRET_PATH=.*|ADMIN_SECRET_PATH=$ADMIN_PATH|g" /var/www/cinematch/.env
    
    chown www-data:www-data /var/www/cinematch/.env
    chmod 600 /var/www/cinematch/.env
    
    log "✓ Environment configuration created with API keys included"
    log "✓ Generated SECRET_KEY: $SECRET_KEY"
    log "✓ Generated ADMIN_SECRET_PATH: $ADMIN_PATH"
    
    warn "Please update DATABASE_URL and DigitalOcean Spaces credentials in .env"
else
    log "✓ .env file already exists, skipping API key configuration"
fi

# 14. Create logs directory
log "Setting up logging..."
mkdir -p /var/www/cinematch/logs
mkdir -p /var/www/cinematch/instance
chown -R www-data:www-data /var/www/cinematch/logs
chown -R www-data:www-data /var/www/cinematch/instance

# Set up log rotation
cat > /etc/logrotate.d/cinematch <<EOF
/var/www/cinematch/logs/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 0644 www-data www-data
    postrotate
        systemctl reload cinematch
    endscript
}

/var/log/cinematch-backup.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF

# 15. Final summary
log "=================================================="
log "Cinematch Production Setup Complete!"
log "=================================================="
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Edit /var/www/cinematch/.env with remaining values:"
echo "   - DATABASE_URL (PostgreSQL connection)"
echo "   - DigitalOcean Spaces credentials"
echo "   ✓ API keys are already configured"
echo ""
echo "2. Initialize the database:"
echo "   cd /var/www/cinematch"
echo "   sudo -u www-data ./venv/bin/flask db upgrade"
echo "   sudo -u www-data ./venv/bin/flask init-db"
echo "   sudo -u www-data ./venv/bin/flask create-admin"
echo ""
echo "3. Start the application:"
echo "   systemctl start cinematch"
echo ""
echo "4. Test the deployment:"
echo "   curl https://cinematch.online/health"
echo ""
echo -e "${GREEN}Configuration Details:${NC}"
echo "Domain: cinematch.online"
echo "Application: /var/www/cinematch"
echo "Backups: /mnt/backups/cinematch"
echo "Redis Password: $REDIS_PASSWORD"
echo "SSL Auto-renewal: Every 60 days"
echo "Database User: cinematch_user"
echo "Database Password: myssel"
echo "Backup Root Password: mqeeVEXehLje"
echo ""
echo -e "${YELLOW}Security Reminders:${NC}"
echo "- Change default SSH port"
echo "- Set up fail2ban"
echo "- Configure database connection limits"
echo "- Review and test all security settings"
echo ""
echo "Setup completed at: $(date)"