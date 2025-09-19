# 🔐 PASSWORD CHANGE CHECKLIST - CINEMATCH DEPLOYMENT

## ⚠️ CRITICAL: Change These Passwords Immediately!

### 1. Linux Admin User Password
```bash
# Change the cinematchadmin user password
sudo passwd cinematchadmin
# Enter new secure password (min 12 chars, mix of upper/lower/numbers/symbols)
```

### 2. PostgreSQL Database Password
```bash
# Connect to PostgreSQL as postgres user
sudo -u postgres psql

# Change cinematch_user password
ALTER USER cinematch_user WITH PASSWORD 'YOUR_NEW_SECURE_PASSWORD';

# Exit PostgreSQL
\q
```

### 3. Redis Password
```bash
# Generate new Redis password
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Edit Redis configuration
sudo nano /etc/redis/redis.conf
# Find and update: requirepass YOUR_NEW_REDIS_PASSWORD

# Restart Redis
sudo systemctl restart redis-server

# Test new password
redis-cli -a YOUR_NEW_REDIS_PASSWORD ping
```

### 4. Update .env File After Password Changes
```bash
# Edit the environment file
nano /var/www/cinematch/.env

# Update these lines with new passwords:
DATABASE_URL=postgresql://cinematch_user:NEW_DB_PASSWORD@localhost:5432/cinematch
REDIS_URL=redis://:NEW_REDIS_PASSWORD@localhost:6379/0
CACHE_REDIS_URL=redis://:NEW_REDIS_PASSWORD@localhost:6379/1
CELERY_BROKER_URL=redis://:NEW_REDIS_PASSWORD@localhost:6379/2
CELERY_RESULT_BACKEND=redis://:NEW_REDIS_PASSWORD@localhost:6379/3
```

### 5. Update Backup Script
```bash
# Edit backup script with new passwords
sudo nano /usr/local/bin/cinematch-backup.sh

# Update these lines:
DB_PASS="NEW_DB_PASSWORD"
REDIS_PASS="NEW_REDIS_PASSWORD"
```

### 6. Generate New Flask Secret Keys
```bash
# Generate new secret key
python3 -c "import secrets; print('SECRET_KEY=' + secrets.token_hex(32))"

# Generate new encryption key
python3 -c "from cryptography.fernet import Fernet; print('ENCRYPTION_KEY=' + Fernet.generate_key().decode())"

# Update in .env file
nano /var/www/cinematch/.env
```

### 7. Create Admin Dashboard Password
```bash
# Generate secure admin password
python3 -c "import secrets; print(secrets.token_urlsafe(16))"

# Save this password securely - you'll use it to access the admin dashboard
```

## 📋 Password Requirements

### Strong Password Guidelines:
- **Length**: Minimum 12 characters (16+ recommended)
- **Complexity**: Mix of uppercase, lowercase, numbers, and symbols
- **Uniqueness**: Different password for each service
- **No Dictionary Words**: Avoid common words or patterns
- **No Personal Info**: Don't use names, dates, or personal information

### Recommended Password Format Examples:
- Database: `Db#2024$Cin3m@tch!Sec`
- Redis: `R3d!s$2024#S3cur3P@ss`
- Admin: `Adm!n#C1n3m@tch$2024`

## 🔄 Password Rotation Schedule

- **Every 30 days**: Admin user password
- **Every 60 days**: Database passwords
- **Every 90 days**: Redis password, Secret keys
- **Immediately**: If any breach or unauthorized access suspected

## 📝 Password Storage Best Practices

1. **Use a Password Manager** (e.g., Bitwarden, 1Password)
2. **Enable 2FA** where possible
3. **Never share passwords** via email or chat
4. **Document in secure location** only
5. **Set up monitoring** for failed login attempts

## 🚨 After Changing Passwords:

1. **Restart all services**:
```bash
sudo systemctl restart postgresql
sudo systemctl restart redis-server
sudo systemctl restart nginx
sudo systemctl restart cinematch  # (after we create the service)
```

2. **Test all connections**:
```bash
# Test database
PGPASSWORD=NEW_PASSWORD psql -h localhost -U cinematch_user -d cinematch -c "\dt"

# Test Redis
redis-cli -a NEW_PASSWORD ping

# Test application
curl https://cinematch.online/health
```

3. **Run backup test**:
```bash
sudo /usr/local/bin/cinematch-backup.sh
```

## 🔒 Security Checklist

- [ ] Changed cinematchadmin password
- [ ] Changed PostgreSQL password
- [ ] Changed Redis password
- [ ] Updated .env file with new passwords
- [ ] Updated backup script with new passwords
- [ ] Generated new Flask secret keys
- [ ] Created admin dashboard password
- [ ] Tested all services after changes
- [ ] Documented passwords in secure location
- [ ] Set up password rotation reminders

## 📞 Emergency Contacts

- Server Provider: DigitalOcean/Hetzner Support
- Domain Registrar: Your domain provider
- SSL Issues: Let's Encrypt Community

---
**Created**: $(date)
**Last Updated**: $(date)
**Next Review**: 30 days