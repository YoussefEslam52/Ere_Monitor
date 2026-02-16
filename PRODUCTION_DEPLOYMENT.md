# Production Deployment Guide - Ere_Monitor SDP Monitoring System

**Version:** 2.0
**Last Updated:** 2026-02-16
**System:** ERE (Environment Resource Explorer) Monitoring for SDP Infrastructure

---

## 1. SYSTEM REQUIREMENTS

### Hardware & OS
- **OS:** Linux (RHEL 7+, CentOS 7+, Ubuntu 18.04+)
- **CPU:** 2+ cores
- **Memory:** 4GB RAM (8GB recommended for 50+ SDPs)
- **Disk:** 10GB+ (for database growth, depends on SDP count)
- **Network:** SSH access to all SDP nodes, HTTP/HTTPS for dashboard

### Software Requirements
- **Bash:** 4.0+ (for monitoring scripts)
- **SQLite3:** 3.8.0+ (for database)
- **PHP:** 5.4+ (for API/Dashboard)
- **Apache/Nginx:** For web dashboard
- **SSH:** Client with key-based auth configured

### Network Requirements
- SSH connectivity to all SDP servers (port 22 default)
- HTTP(S) access to dashboard server (port 80/443)
- Optional: SMS gateway connectivity (for alarm notifications)

---

## 2. PRODUCTION FILE STRUCTURE

```
/var/opt/ere-monitor/
├── config/
│   ├── sdp.config              # SDP inventory (IP, hostname list)
│   └── alarms.config           # Alarm thresholds configuration
├── scripts/
│   ├── ere_monitor_fast.sh     # Main monitoring script
│   ├── run_complete_monitoring.sh
│   ├── db_loader.sh            # Database loader
│   └── cron_wrapper.sh         # Cron job wrapper
├── database/
│   ├── database_schema_v2.sql  # Database schema
│   └── sdp_monitor.db          # SQLite database (auto-created)
├── web/
│   ├── api.php                 # REST API backend
│   ├── index.html              # Main dashboard
│   ├── tree-analysis.html      # Tree detail view
│   ├── diagnostic.html         # Diagnostic page
│   └── chart.min.js            # Chart library
├── logs/
│   ├── ere_monitor.log         # Script logs
│   ├── ere_alarms_latest.txt   # Latest alarms
│   └── ere_stats_latest.txt    # Latest statistics
└── backup/
    └── sdp_monitor.db.backup   # Database backups
```

---

## 3. PRODUCTION FILES - COMPLETE LIST

| File | Type | Size | Purpose |
|------|------|------|---------|
| `ere_monitor_fast.sh` | Script | ~24KB | Main monitoring engine (parallel SSH, smart parsing) |
| `run_complete_monitoring.sh` | Script | ~2KB | Orchestration wrapper |
| `db_loader.sh` | Script | ~6KB | Database loader (creates/updates SQLite DB) |
| `database_schema_v2.sql` | SQL | ~5KB | Database schema with 7 tables + views |
| `api.php` | PHP | ~12KB | REST API (PHP 5.4 compatible) |
| `index.html` | Web | ~10KB | Dashboard main page |
| `tree-analysis.html` | Web | ~8KB | Tree-specific analysis view |
| `diagnostic.html` | Web | ~5KB | Diagnostic/debug page |
| `chart.min.js` | JS | ~50KB | Charting library (for trends) |
| `sdp.config` | Config | TBD | SDP inventory list |

---

## 4. STEP-BY-STEP DEPLOYMENT

### Phase 1: Infrastructure Setup

#### 4.1 Create Service Account & Directories

```bash
# Create service user
sudo useradd -m -d /var/opt/ere-monitor -s /bin/bash sdpmonitor
sudo mkdir -p /var/opt/ere-monitor/{config,scripts,database,web,logs,backup}

# Set ownership
sudo chown -R sdpmonitor:sdpmonitor /var/opt/ere-monitor
sudo chmod 750 /var/opt/ere-monitor

# Create SSH key for SDP access
sudo -u sdpmonitor ssh-keygen -t rsa -b 4096 -N "" -f /var/opt/ere-monitor/.ssh/id_rsa
sudo chmod 700 /var/opt/ere-monitor/.ssh
sudo chmod 600 /var/opt/ere-monitor/.ssh/id_rsa
```

#### 4.2 Install Dependencies

```bash
# RHEL/CentOS
sudo yum install -y bash sqlite php php-cli apache2-utils

# Ubuntu/Debian
sudo apt-get install -y sqlite3 php php-cli

# Verify installations
bash --version
sqlite3 --version
php --version
```

### Phase 2: Deploy Production Files

#### 4.3 Copy Scripts

```bash
# From this repository, copy scripts to production
sudo cp SDP_Script/ere_monitor_fast.sh /var/opt/ere-monitor/scripts/
sudo cp SDP_Script/run_complete_monitoring.sh /var/opt/ere-monitor/scripts/
sudo cp SDP_Script/db_loader.sh /var/opt/ere-monitor/scripts/

# Make executable
sudo chmod 750 /var/opt/ere-monitor/scripts/*.sh
sudo chown sdpmonitor:sdpmonitor /var/opt/ere-monitor/scripts/*.sh
```

#### 4.4 Deploy Database Schema

```bash
# Copy schema file
sudo cp SDP_Script/database_schema_v2.sql /var/opt/ere-monitor/database/

# Set ownership
sudo chown sdpmonitor:sdpmonitor /var/opt/ere-monitor/database/database_schema_v2.sql
```

#### 4.5 Deploy Web Dashboard

```bash
# Create web directory (Apache example)
sudo mkdir -p /var/www/html/sdp-monitor/data

# Copy dashboard files
sudo cp SDP_Script/sdp-monitor/*.html /var/www/html/sdp-monitor/
sudo cp SDP_Script/sdp-monitor/*.js /var/www/html/sdp-monitor/
sudo cp SDP_Script/sdp-monitor/api.php /var/www/html/sdp-monitor/

# Set permissions (Apache user access)
sudo chown -R apache:apache /var/www/html/sdp-monitor
sudo chmod 755 /var/www/html/sdp-monitor
sudo chmod 755 /var/www/html/sdp-monitor/data
sudo chmod 644 /var/www/html/sdp-monitor/*.{html,js,php}
```

### Phase 3: Configuration

#### 4.6 Create SDP Inventory File

Create `/var/opt/ere-monitor/config/sdp.config`:

```csv
Hostname,IP
SDP27B,192.168.1.27
SDP28B,192.168.1.28
SDP29B,192.168.1.29
SDP30B,192.168.1.30
...
SDP70B,192.168.1.70
```

**Requirements:**
- CSV format: Hostname, IP (comma-separated)
- One SDP per line
- Header line: `Hostname,IP`
- IPs must be reachable via SSH from monitoring server
- Ensure SSH keys are distributed to all SDPs

#### 4.7 Configure SSH Access

```bash
# As sdpmonitor user, test SSH connectivity
su - sdpmonitor

# Add SDP public key to all SDPs
cat ~/.ssh/id_rsa.pub

# On each SDP server:
echo "sdpmonitor_public_key" >> /home/sdpuser/.ssh/authorized_keys
chmod 600 /home/sdpuser/.ssh/authorized_keys

# Test connection (back on monitoring server)
ssh -i ~/.ssh/id_rsa sdpuser@SDP27B "echo 'SSH working'"
```

#### 4.8 Configure Web Server

**Apache Configuration (`/etc/httpd/conf.d/sdp-monitor.conf`):**

```apache
<VirtualHost *:80>
    ServerName sdp-monitor.example.com
    DocumentRoot /var/www/html/sdp-monitor

    <Directory /var/www/html/sdp-monitor>
        AllowOverride All
        Require all granted
    </Directory>

    # PHP handler
    <Files "*.php">
        SetHandler "proxy:unix:/run/php-fpm.sock|fcgi://localhost"
    </Files>

    # Logging
    ErrorLog /var/log/httpd/sdp-monitor-error.log
    CustomLog /var/log/httpd/sdp-monitor-access.log combined

    # Enable gzip compression
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml application/json
    </IfModule>
</VirtualHost>
```

**PHP Configuration (`/var/www/html/sdp-monitor/config.php`):**

```php
<?php
// Database path (must be writable by Apache user)
define('DB_FILE', '/var/www/html/sdp-monitor/data/sdp_monitor.db');

// Monitoring server details
define('MONITOR_USER', 'sdpmonitor');
define('MONITOR_SERVER', 'monitoring.example.com');

// Alarm thresholds
define('CRITICAL_THRESHOLD', 5);    // SDPs with 5+ alarms = critical
define('WARNING_THRESHOLD', 1);     // SDPs with 1+ alarms = warning
?>
```

### Phase 4: Database Initialization

#### 4.9 Initialize Database

```bash
# As sdpmonitor user
sudo -u sdpmonitor bash << 'EOF'

# Set database path
export DB_FILE="/var/www/html/sdp-monitor/data/sdp_monitor.db"
export SCHEMA_FILE="/var/opt/ere-monitor/database/database_schema_v2.sql"

# Initialize database (creates tables & indexes)
sqlite3 "$DB_FILE" < "$SCHEMA_FILE"

# Verify schema
sqlite3 "$DB_FILE" ".tables"

# Expected output: alarms alarm_distribution categories monitoring_runs
#                  sdp_categories sdp_status trees

EOF
```

### Phase 5: Scheduling & Automation

#### 4.10 Create Cron Jobs

**Edit crontab as sdpmonitor user:**

```bash
sudo -u sdpmonitor crontab -e
```

**Add these entries:**

```cron
# Monitor every 5 minutes (adjust frequency as needed)
*/5 * * * * /var/opt/ere-monitor/scripts/run_complete_monitoring.sh >> /var/opt/ere-monitor/logs/ere_monitor.cron.log 2>&1

# Backup database daily at 2 AM
0 2 * * * cp /var/www/html/sdp-monitor/data/sdp_monitor.db /var/opt/ere-monitor/backup/sdp_monitor.db.backup.$(date +\%Y\%m\%d)

# Clean old backups (keep 30 days)
0 3 * * * find /var/opt/ere-monitor/backup -name "*.backup.*" -mtime +30 -delete

# Log rotation check
0 4 * * * find /var/opt/ere-monitor/logs -name "*.log" -size +100M -exec gzip {} \;
```

#### 4.11 Update run_complete_monitoring.sh

Edit `/var/opt/ere-monitor/scripts/run_complete_monitoring.sh`:

```bash
#!/bin/bash
# Complete monitoring orchestration

SCRIPT_DIR="/var/opt/ere-monitor/scripts"
CONFIG_DIR="/var/opt/ere-monitor/config"
HOME_DIR="/var/opt/ere-monitor"

# Set HOME for sdpmonitor user
export HOME="$HOME_DIR"

# Run main monitor
cd "$HOME_DIR"
bash "$SCRIPT_DIR/ere_monitor_fast.sh" "$CONFIG_DIR/sdp.config"

# Load results into database
bash "$SCRIPT_DIR/db_loader.sh"

# Log completion
echo "$(date): Monitoring cycle complete" >> /var/opt/ere-monitor/logs/ere_monitor.cron.log
```

### Phase 6: Verification & Testing

#### 4.12 Test Monitoring Cycle

```bash
# Run manual test as sdpmonitor
sudo -u sdpmonitor bash /var/opt/ere-monitor/scripts/run_complete_monitoring.sh

# Expected output:
# - Collecting from reference SDP
# - Starting parallel collection
# - Database loaded: X alarms inserted
```

#### 4.13 Verify Database

```bash
# Check database contents
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db << 'EOF'
SELECT COUNT(*) as total_runs FROM monitoring_runs;
SELECT COUNT(*) as total_alarms FROM alarms;
SELECT * FROM v_latest_alarms LIMIT 5;
EOF
```

#### 4.14 Test Web Dashboard

```bash
# Test API endpoint
curl http://localhost/sdp-monitor/api.php?action=dashboard

# Expected: JSON response with stats, health, alarms

# Test web browser
# Navigate to: http://your-server/sdp-monitor/index.html
```

### Phase 7: Production Hardening

#### 4.15 Security Configuration

```bash
# Restrict file permissions
sudo chmod 640 /var/www/html/sdp-monitor/data/sdp_monitor.db

# Disable PHP directory listing
echo "php_flag engine off" | sudo tee /var/www/html/sdp-monitor/.htaccess

# Setup SELinux context (if enabled)
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/sdp-monitor/data(/.*)?"
sudo restorecon -Rv /var/www/html/sdp-monitor

# Configure firewall
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

#### 4.16 Enable HTTPS (Optional but Recommended)

```bash
# Install certificate (Let's Encrypt example)
sudo certbot certonly --apache -d sdp-monitor.example.com

# Update Apache config to redirect HTTP to HTTPS
# Add to VirtualHost:
# Redirect permanent / https://sdp-monitor.example.com/
```

#### 4.17 Setup Monitoring & Alerting

```bash
# Monitor cron job execution
sudo tail -f /var/opt/ere-monitor/logs/ere_monitor.cron.log

# Setup syslog forwarding
echo "*.* @@syslog-server:514" | sudo tee -a /etc/rsyslog.d/ere-monitor.conf
sudo systemctl restart rsyslog

# Monitor database size
du -h /var/www/html/sdp-monitor/data/sdp_monitor.db
```

---

## 5. PRODUCTION CONFIGURATION REFERENCE

### 5.1 ere_monitor_fast.sh Configuration Variables

Edit the script header (lines 3-25):

```bash
USER="sdpuser"                      # SSH user on SDPs
BASE_PATH="/var/opt/fds/config/ere" # Path to config trees on SDPs
REFERENCE_SDP="SDP27B"              # Reference node (source of truth)
CONFIG_FILE="sdp.config"            # Inventory file path
MAX_PARALLEL=20                     # Parallel SSH connections

# Whitelist trees (1 file allowed, no alarm for single file)
IGNORE_SINGLE_FILE_TREES=("Statistic" "PreAnalysis")

# Whitelist categories (tree:category format)
IGNORE_SINGLE_FILE_CATEGORIES=("ProductFee:main" "Bonus:special")
```

### 5.2 Database Schema Overview

| Table | Purpose |
|-------|---------|
| `monitoring_runs` | Metadata for each monitoring cycle |
| `alarms` | Individual alarm records |
| `alarm_distribution` | Summary counts by severity |
| `sdp_status` | Per-SDP health metrics |
| `trees` | Tree metadata per run |
| `categories` | Category file counts per tree |
| `sdp_categories` | Detailed file counts by SDP/tree/category |

### 5.3 API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `api.php?action=dashboard` | Main dashboard data (stats, alarms, trends) |
| `api.php?action=alarms&limit=50` | Recent alarms list |
| `api.php?action=sdp_status` | All SDP health status |
| `api.php?action=trees` | Tree summary |
| `api.php?action=sdp_alarms&sdp=SDP27B` | Alarms for specific SDP |
| `api.php?action=diagnostic` | Sample alarm format (debug) |

---

## 6. MONITORING & MAINTENANCE

### 6.1 Daily Checks

```bash
# Check cron job execution
sudo grep "ere_monitor" /var/log/cron

# Verify latest run completed successfully
sudo -u sdpmonitor tail -20 /var/opt/ere-monitor/logs/ere_monitor.cron.log

# Check disk usage
df -h /var/www/html/sdp-monitor/data/

# Monitor alarm count trends
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db \
  "SELECT DATE(run_timestamp), total_alarms FROM monitoring_runs ORDER BY run_timestamp DESC LIMIT 7;"
```

### 6.2 Weekly Maintenance

```bash
# Archive old logs
gzip /var/opt/ere-monitor/logs/*.log

# Verify SSH connectivity to all SDPs
for sdp in SDP{27..70}B; do
  ssh -i /var/opt/ere-monitor/.ssh/id_rsa sdpuser@$sdp "echo OK" 2>/dev/null && echo "$sdp: OK" || echo "$sdp: FAILED"
done

# Test database integrity
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db "PRAGMA integrity_check;"

# Backup configuration
tar czf /var/opt/ere-monitor/backup/config_backup_$(date +%Y%m%d).tar.gz \
  /var/opt/ere-monitor/config/ /var/opt/ere-monitor/scripts/
```

### 6.3 Database Maintenance

```bash
# Vacuum database (reclaim space)
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db "VACUUM;"

# Analyze indexes (optimize queries)
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db "ANALYZE;"

# Check for orphaned records
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db << 'EOF'
-- Find alarms referencing non-existent runs
SELECT COUNT(*) FROM alarms WHERE run_id NOT IN (SELECT run_id FROM monitoring_runs);

-- Find SDPs without recent status
SELECT sdp_name, COUNT(*) FROM sdp_status
GROUP BY sdp_name HAVING COUNT(*) < 10;
EOF
```

---

## 7. TROUBLESHOOTING

### 7.1 Common Issues

**Issue: SSH connection timeouts**
```bash
# Solution: Verify SSH connectivity
ssh -v -i /var/opt/ere-monitor/.ssh/id_rsa sdpuser@SDP27B
# Check firewall: sudo firewall-cmd --list-all
# Check SSH daemon: systemctl status sshd
```

**Issue: Database locked error**
```bash
# Solution: Check for stuck processes
lsof /var/www/html/sdp-monitor/data/sdp_monitor.db
# Kill if necessary: kill -9 <PID>
# Restore from backup if corrupted
```

**Issue: No alarms appearing**
```bash
# Verify monitoring script ran
sudo -u sdpmonitor /var/opt/ere-monitor/scripts/run_complete_monitoring.sh -v
# Check database
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db "SELECT COUNT(*) FROM alarms;"
# Review logs
tail -50 /var/opt/ere-monitor/logs/ere_monitor.cron.log
```

**Issue: Dashboard shows "No data"**
```bash
# Verify API works
curl -v http://localhost/sdp-monitor/api.php?action=dashboard
# Check database exists and has data
ls -lh /var/www/html/sdp-monitor/data/sdp_monitor.db
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db ".tables"
# Check Apache/PHP error logs
tail -20 /var/log/httpd/error_log
```

### 7.2 Performance Tuning

```bash
# Increase parallel SSH connections (for 50+ SDPs)
# Edit ere_monitor_fast.sh, change: MAX_PARALLEL=40

# Database indexes analysis
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db << 'EOF'
.mode column
.headers on
SELECT name FROM sqlite_master WHERE type='index';
EOF

# Monitor script execution time
time /var/opt/ere-monitor/scripts/ere_monitor_fast.sh /var/opt/ere-monitor/config/sdp.config
```

---

## 8. BACKUP & DISASTER RECOVERY

### 8.1 Backup Strategy

```bash
# Full backup script (save to /opt/backup_ere.sh)
#!/bin/bash
BACKUP_DIR="/var/opt/ere-monitor/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup database
cp /var/www/html/sdp-monitor/data/sdp_monitor.db \
   $BACKUP_DIR/sdp_monitor.db.$TIMESTAMP

# Backup configuration and scripts
tar czf $BACKUP_DIR/ere-monitor-config.$TIMESTAMP.tar.gz \
  /var/opt/ere-monitor/{config,scripts,database}

# Keep only 7 days of backups
find $BACKUP_DIR -name "sdp_monitor.db.*" -mtime +7 -delete
find $BACKUP_DIR -name "ere-monitor-config.*.tar.gz" -mtime +7 -delete

echo "Backup complete: $TIMESTAMP"
```

### 8.2 Restore from Backup

```bash
# Restore database
RESTORE_TIME="20260216_143022"
cp /var/opt/ere-monitor/backup/sdp_monitor.db.$RESTORE_TIME \
   /var/www/html/sdp-monitor/data/sdp_monitor.db

# Restore configuration
tar xzf /var/opt/ere-monitor/backup/ere-monitor-config.$RESTORE_TIME.tar.gz \
  -C /

# Verify restoration
sudo -u sdpmonitor sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db \
  "SELECT COUNT(*) FROM monitoring_runs;"
```

---

## 9. DEPLOYMENT CHECKLIST

- [ ] System requirements verified (OS, disk, memory)
- [ ] Service account created (`sdpmonitor` user)
- [ ] Directory structure created (`/var/opt/ere-monitor/`)
- [ ] Production scripts deployed and executable
- [ ] Database schema deployed
- [ ] Web dashboard deployed to Apache/Nginx
- [ ] SDP inventory configured (`sdp.config`)
- [ ] SSH keys generated and distributed to all SDPs
- [ ] SSH connectivity tested to all SDPs
- [ ] Database initialized with schema
- [ ] Web server configured and PHP working
- [ ] API endpoints tested (`curl` verification)
- [ ] Cron jobs configured for monitoring cycles
- [ ] Initial monitoring cycle executed manually
- [ ] Dashboard accessible via web browser
- [ ] Security hardening applied (permissions, firewall)
- [ ] Logging and alerting configured
- [ ] Backup strategy implemented
- [ ] Disaster recovery tested
- [ ] Documentation updated for operations team

---

## 10. SUPPORT & DOCUMENTATION

**System Components:**
- **Monitoring Engine:** `ere_monitor_fast.sh` - Parallel SSH collection, smart parsing, alarm generation
- **Database Layer:** SQLite3 with 7 tables, indexed for performance
- **API Layer:** PHP 5.4+ compatible REST API
- **Frontend:** Responsive HTML5 dashboard with real-time charting

**Key Features:**
- Parallel monitoring of 40+ SDPs (configurable MAX_PARALLEL)
- Configurable alarm whitelisting (by tree/category)
- Real-time SMS notifications (optional)
- 7-day trend analysis and reporting
- Comprehensive audit trail

**Contact & Escalation:**
- Primary: YoussefEslam52@example.com
- Escalation: DevOps Team
- 24/7 Support: Available for critical alarms

---

**End of Deployment Guide**
