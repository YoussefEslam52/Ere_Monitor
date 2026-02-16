# Production Files Manifest - Ere_Monitor

**Generated:** 2026-02-16
**Status:** Ready for Production Deployment

---

## COMPLETE FILE STRUCTURE FOR PRODUCTION

```
PRODUCTION_PACKAGE/
│
├── DEPLOYMENT_STEPS.txt
├── PRE_DEPLOYMENT_CHECKLIST.txt
├── PRODUCTION_DEPLOYMENT.md (detailed guide)
│
├── scripts/
│   ├── ere_monitor_fast.sh         [24 KB] Main monitoring engine
│   ├── run_complete_monitoring.sh  [2 KB]  Orchestration wrapper
│   ├── db_loader.sh                [6 KB]  Database loader
│   └── cron_wrapper.sh             [NEW]   Cron execution wrapper
│
├── database/
│   └── database_schema_v2.sql      [5 KB]  SQLite3 schema (7 tables + views)
│
├── web/
│   ├── api.php                     [12 KB] REST API (PHP 5.4+ compatible)
│   ├── index.html                  [10 KB] Main dashboard
│   ├── tree-analysis.html          [8 KB]  Tree detail view
│   ├── diagnostic.html             [5 KB]  Diagnostic page
│   └── chart.min.js                [50 KB] Chart library
│
├── config/
│   ├── sdp.config.template         [NEW]   SDP inventory template
│   ├── apache_vhost.conf           [NEW]   Apache configuration
│   └── php_config.php              [NEW]   PHP settings
│
└── monitoring/
    ├── .htaccess                   [NEW]   Web security settings
    └── data/.gitkeep               [NEW]   Database directory placeholder
```

---

## CRITICAL PRODUCTION PATHS

### Server Directories
```
/var/opt/ere-monitor/              # Main installation directory
├── config/                         # Configuration files
├── scripts/                        # Executable scripts
├── database/                       # Schema & backups
├── logs/                           # Log files
└── backup/                         # Database backups

/var/www/html/sdp-monitor/         # Web dashboard
├── data/                           # SQLite database location
├── *.php                           # API endpoint
└── *.html                          # Frontend pages
```

---

## FILE DEPLOYMENT MAP

### Step 1: Scripts Deployment
| Source File | Deploy To | Permissions | Owner |
|-------------|-----------|-------------|-------|
| `scripts/ere_monitor_fast.sh` | `/var/opt/ere-monitor/scripts/` | 750 | sdpmonitor |
| `scripts/run_complete_monitoring.sh` | `/var/opt/ere-monitor/scripts/` | 750 | sdpmonitor |
| `scripts/db_loader.sh` | `/var/opt/ere-monitor/scripts/` | 750 | sdpmonitor |

### Step 2: Database Deployment
| Source File | Deploy To | Permissions | Owner |
|-------------|-----------|-------------|-------|
| `database/database_schema_v2.sql` | `/var/opt/ere-monitor/database/` | 640 | sdpmonitor |

### Step 3: Web Deployment
| Source File | Deploy To | Permissions | Owner |
|-------------|-----------|-------------|-------|
| `web/api.php` | `/var/www/html/sdp-monitor/` | 644 | apache |
| `web/index.html` | `/var/www/html/sdp-monitor/` | 644 | apache |
| `web/tree-analysis.html` | `/var/www/html/sdp-monitor/` | 644 | apache |
| `web/diagnostic.html` | `/var/www/html/sdp-monitor/` | 644 | apache |
| `web/chart.min.js` | `/var/www/html/sdp-monitor/` | 644 | apache |

### Step 4: Configuration Deployment
| Source File | Deploy To | Permissions | Owner |
|-------------|-----------|-------------|-------|
| `config/sdp.config` | `/var/opt/ere-monitor/config/` | 640 | sdpmonitor |
| `config/apache_vhost.conf` | `/etc/httpd/conf.d/` | 644 | root |

---

## PRODUCTION DEPLOYMENT QUICK START

### 1. Download Production Package
```bash
# Clone repository to deployment server
git clone https://github.com/YoussefEslam52/Ere_Monitor.git
cd Ere_Monitor
```

### 2. Create Service Account
```bash
sudo useradd -m -d /var/opt/ere-monitor -s /bin/bash sdpmonitor
sudo mkdir -p /var/opt/ere-monitor/{config,scripts,database,logs,backup}
sudo chown -R sdpmonitor:sdpmonitor /var/opt/ere-monitor
```

### 3. Deploy Scripts
```bash
sudo cp SDP_Script/ere_monitor_fast.sh /var/opt/ere-monitor/scripts/
sudo cp SDP_Script/run_complete_monitoring.sh /var/opt/ere-monitor/scripts/
sudo cp SDP_Script/db_loader.sh /var/opt/ere-monitor/scripts/
sudo chmod 750 /var/opt/ere-monitor/scripts/*.sh
sudo chown sdpmonitor:sdpmonitor /var/opt/ere-monitor/scripts/*.sh
```

### 4. Deploy Database
```bash
sudo cp SDP_Script/database_schema_v2.sql /var/opt/ere-monitor/database/
sudo chown sdpmonitor:sdpmonitor /var/opt/ere-monitor/database/database_schema_v2.sql
```

### 5. Deploy Web Dashboard
```bash
sudo mkdir -p /var/www/html/sdp-monitor/data
sudo cp SDP_Script/sdp-monitor/*.php /var/www/html/sdp-monitor/
sudo cp SDP_Script/sdp-monitor/*.html /var/www/html/sdp-monitor/
sudo cp SDP_Script/sdp-monitor/*.js /var/www/html/sdp-monitor/
sudo chown -R apache:apache /var/www/html/sdp-monitor
sudo chmod 755 /var/www/html/sdp-monitor/data
```

### 6. Configure SDP Inventory
```bash
# Create sdp.config with your SDP list
cat > /var/opt/ere-monitor/config/sdp.config << 'EOF'
Hostname,IP
SDP27B,192.168.1.27
SDP28B,192.168.1.28
SDP29B,192.168.1.29
EOF

sudo chown sdpmonitor:sdpmonitor /var/opt/ere-monitor/config/sdp.config
sudo chmod 640 /var/opt/ere-monitor/config/sdp.config
```

### 7. Initialize Database
```bash
sudo -u sdpmonitor bash << 'EOF'
export DB_FILE="/var/www/html/sdp-monitor/data/sdp_monitor.db"
export SCHEMA_FILE="/var/opt/ere-monitor/database/database_schema_v2.sql"
sqlite3 "$DB_FILE" < "$SCHEMA_FILE"
EOF
```

### 8. Configure Cron Job
```bash
# Edit crontab for sdpmonitor user
sudo -u sdpmonitor crontab -e

# Add this line (every 5 minutes):
*/5 * * * * /var/opt/ere-monitor/scripts/run_complete_monitoring.sh >> /var/opt/ere-monitor/logs/ere_monitor.cron.log 2>&1
```

### 9. Test Deployment
```bash
# Run initial monitoring cycle
sudo -u sdpmonitor /var/opt/ere-monitor/scripts/run_complete_monitoring.sh

# Verify database
sqlite3 /var/www/html/sdp-monitor/data/sdp_monitor.db "SELECT COUNT(*) FROM monitoring_runs;"

# Test API
curl http://localhost/sdp-monitor/api.php?action=dashboard
```

### 10. Access Dashboard
```
http://your-server/sdp-monitor/index.html
```

---

## FILE SIZE SUMMARY

| Component | Size | Type |
|-----------|------|------|
| ere_monitor_fast.sh | 24 KB | Bash script |
| run_complete_monitoring.sh | 2 KB | Bash script |
| db_loader.sh | 6 KB | Bash script |
| database_schema_v2.sql | 5 KB | SQL schema |
| api.php | 12 KB | PHP code |
| index.html | 10 KB | HTML |
| tree-analysis.html | 8 KB | HTML |
| diagnostic.html | 5 KB | HTML |
| chart.min.js | 50 KB | JavaScript |
| **Total (compressed)** | **~40 KB** | **ZIP** |

---

## PRE-DEPLOYMENT VERIFICATION CHECKLIST

### Infrastructure
- [ ] OS is Linux (RHEL 7+, CentOS 7+, Ubuntu 18.04+)
- [ ] Bash 4.0+ installed (`bash --version`)
- [ ] SQLite3 3.8.0+ installed (`sqlite3 --version`)
- [ ] PHP 5.4+ installed (`php --version`)
- [ ] Apache/Nginx configured and running
- [ ] At least 10GB disk space available
- [ ] 4GB+ RAM available
- [ ] Network connectivity to all SDPs verified

### SSH Configuration
- [ ] SSH key-based auth configured
- [ ] Public key distributed to all SDP servers
- [ ] SSH connectivity tested to at least 3 SDPs
- [ ] Default SSH user matches configuration (sdpuser)

### Database & Web
- [ ] SQLite3 can read/write to `/var/www/html/sdp-monitor/data/`
- [ ] PHP PDO extension available (`php -m | grep PDO`)
- [ ] Apache has write permissions to database directory
- [ ] Web directory structure created and permissions set

### Monitoring Account
- [ ] sdpmonitor user created and home directory set
- [ ] .ssh directory created with proper permissions (700)
- [ ] SSH key pair generated for sdpmonitor user
- [ ] sudoers file configured (if necessary)

### Configuration
- [ ] sdp.config created with correct IP addresses
- [ ] REFERENCE_SDP in ere_monitor_fast.sh is online and accessible
- [ ] CONFIG_FILE path matches actual sdp.config location
- [ ] BASE_PATH matches SDP config tree location (`/var/opt/fds/config/ere` default)

### Security
- [ ] File permissions set correctly (750 for scripts, 640 for configs)
- [ ] Ownership correct (sdpmonitor for scripts, apache for web)
- [ ] Firewall configured to allow SSH to SDPs
- [ ] Database file not world-readable

### Testing
- [ ] Manual monitoring cycle completed successfully
- [ ] Database populated with test data
- [ ] API endpoint responds with JSON
- [ ] Dashboard accessible and loads without errors
- [ ] No critical errors in Apache/PHP logs

---

## PRODUCTION RELEASE SIGN-OFF

```
PROJECT: Ere_Monitor SDP Infrastructure Monitoring
VERSION: 2.0 Production Release
DATE: 2026-02-16

COMPONENT VERIFICATION:
✓ Monitoring Scripts: ere_monitor_fast.sh, run_complete_monitoring.sh, db_loader.sh
✓ Database: SQLite3 schema v2 with 7 tables
✓ Web Dashboard: HTML5 frontend + PHP 5.4 API
✓ Configuration: Modular, externalized to sdp.config
✓ Documentation: Complete deployment guide included

QUALITY GATES:
✓ SSH parallel collection (max 20 concurrent)
✓ Smart alarm parsing and grouping
✓ Database persistence and indexing
✓ REST API fully functional
✓ Dashboard responsive (mobile-compatible)
✓ Error handling and recovery

DEPLOYMENT APPROVED BY:
_________________________  _____________
Infrastructure Team        Date

_________________________  _____________
Security Team             Date

_________________________  _____________
Operations Team           Date
```

---

**For complete deployment instructions, see: PRODUCTION_DEPLOYMENT.md**

---

**Package Contents Summary:**
- ✓ 3 Bash monitoring & database scripts
- ✓ 1 SQL schema file
- ✓ 5 Web frontend files (HTML/JS/PHP)
- ✓ Configuration templates
- ✓ Complete deployment guide
- ✓ Pre-deployment checklist
- ✓ Troubleshooting guide
- ✓ Backup & recovery procedures
