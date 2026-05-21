# Deployment System Documentation

This directory contains a simplified deployment system for the Jenkins Capacity Analyzer application.

## 📁 Files in This Directory

| File | Purpose |
|------|---------|
| `package-for-deployment.sh` | Creates deployment-ready tarball from local files |
| `update-on-server.sh` | Updates application on production server |
| `test-package.sh` | Comprehensive testing of deployment packages |
| `QUICK-DEPLOY.md` | Quick reference guide for deployment |
| `wsgi.py` | WSGI entry point for Apache |
| `apache2-jenkins-capacity.conf` | Apache configuration template |
| `deploy.sh` | Initial deployment script (for new installations) |

## 🚀 Quick Start

### Creating a Deployment Package

```bash
cd jenkins-capacity-report
./deployment/package-for-deployment.sh
```

This creates a timestamped tarball (e.g., `jenkins-capacity-20260415-120434.tar.gz`) containing only the files needed for deployment.

### Deploying to Server

```bash
# Transfer package
scp jenkins-capacity-*.tar.gz user@nagios.adoptopenjdk.net:/tmp/

# SSH and update
ssh user@nagios.adoptopenjdk.net
cd /var/www/jenkins-capacity-report
sudo ./deployment/update-on-server.sh /tmp/jenkins-capacity-*.tar.gz
```

## 📦 What Gets Packaged

### ✅ Included

- **Application Code**: `main.py`, `web_app.py`, `src/`
- **Web Templates**: `templates/`
- **Deployment Config**: `deployment/wsgi.py`, Apache configs
- **Scripts & Tools**: `scripts/`, `tools/`
- **Documentation**: `docs/`, `README.md`
- **Dependencies**: `requirements.txt`
- **Examples**: `.env.example`, `tools/*.example`
- **Tests**: `tests/`

### ❌ Excluded (Preserved on Server)

- **Sensitive Config**: `.env`, `Credentials.txt`
- **User Database**: `data/users.json`
- **Cloud Config**: `data/clouds.xml.live`
- **Metrics History**: `data/metrics_history.json`
- **Excluded Nodes**: `data/excluded_nodes.json`
- **Generated Data**: `*.csv`, `*.json` reports
- **Logs**: `logs/*.log`
- **Virtual Environment**: `venv/`
- **Development Artifacts**: `__pycache__/`, `.git/`, `.vscode/`

## 🔧 Script Details

### package-for-deployment.sh

**Purpose**: Creates a clean, deployment-ready tarball

**Features**:
- Excludes sensitive files automatically
- Generates checksums for integrity verification
- Creates file manifest
- Runs 13 automated verification tests
- Produces packages ~100-200KB in size

**Usage**:
```bash
./deployment/package-for-deployment.sh [output-directory]
```

**Output**:
- `jenkins-capacity-YYYYMMDD-HHMMSS.tar.gz` - The deployment package
- Verification report showing all tests passed

### update-on-server.sh

**Purpose**: Safely updates the application on the production server

**Features**:
- Pre-flight checks (Apache status, disk space, .env existence)
- Automatic backup before update
- Preserves sensitive files (.env, users.json, clouds.xml.live, etc.)
- Updates Python dependencies only if requirements.txt changed
- Graceful Apache reload (no downtime)
- Post-deployment verification
- Automatic cleanup of old backups (keeps last 10)

**Usage**:
```bash
sudo ./deployment/update-on-server.sh <path-to-tarball>
```

**Requirements**:
- Must run as root (sudo)
- Application must already be installed at `/var/www/jenkins-capacity-report`
- Apache2 must be installed and configured

**Backup Location**: `/var/backups/jenkins-capacity/`

### test-package.sh

**Purpose**: Comprehensive testing of deployment packages

**Features**:
- 35 automated tests covering:
  - Tarball integrity
  - Critical file presence (9 tests)
  - Directory structure (6 tests)
  - Security (5 tests - sensitive files excluded)
  - Data exclusion (3 tests)
  - Artifact exclusion (5 tests)
  - Package metadata (3 tests)
  - Content validation (4 tests)

**Usage**:
```bash
./deployment/test-package.sh <path-to-tarball>
```

**Exit Codes**:
- `0` - All tests passed
- `1` - One or more tests failed

## 🔒 Security Features

### Automatic Exclusion of Sensitive Data

The packaging script automatically excludes:
- Environment configuration (`.env`)
- Credentials (`Credentials.txt`)
- User database (`data/users.json`)
- Cloud configuration (`data/clouds.xml.live`)
- Any generated data files

### Verification Tests

Both the packaging and testing scripts verify that sensitive files are NOT included in the package.

### File Preservation

The update script automatically preserves these files during deployment:
- `.env` - Jenkins credentials and configuration
- `data/users.json` - User accounts and roles
- `data/clouds.xml.live` - Cloud configuration
- `data/excluded_nodes.json` - Node exclusion list
- `data/metrics_history.json` - Historical metrics

## 📊 Package Statistics

Typical package contains:
- **Files**: ~48 files
- **Size**: ~100KB (compressed)
- **Directories**: 8 main directories
- **Python files**: ~15 source files
- **Templates**: ~8 HTML templates
- **Documentation**: ~10 markdown files

## 🔄 Deployment Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ LOCAL MACHINE                                               │
├─────────────────────────────────────────────────────────────┤
│ 1. Make code changes                                        │
│ 2. Test locally                                             │
│ 3. Run: ./deployment/package-for-deployment.sh             │
│    ├─ Creates timestamped tarball                          │
│    ├─ Excludes sensitive files                             │
│    ├─ Generates checksums                                  │
│    └─ Runs verification tests                              │
│ 4. (Optional) Run: ./deployment/test-package.sh <tarball>  │
│ 5. Transfer: scp <tarball> user@server:/tmp/               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ PRODUCTION SERVER                                           │
├─────────────────────────────────────────────────────────────┤
│ 1. SSH to server                                            │
│ 2. Run: sudo ./deployment/update-on-server.sh <tarball>    │
│    ├─ Pre-flight checks                                    │
│    ├─ Creates backup                                       │
│    ├─ Preserves sensitive files                            │
│    ├─ Extracts new version                                 │
│    ├─ Restores preserved files                             │
│    ├─ Updates dependencies (if needed)                     │
│    ├─ Reloads Apache                                       │
│    └─ Verifies deployment                                  │
│ 3. Verify: https://nagios.adoptopenjdk.net/jenkins-capacity│
└─────────────────────────────────────────────────────────────┘
```

## 🛠️ Troubleshooting

### Package Creation Issues

**Problem**: Script fails to create package

**Solutions**:
```bash
# Verify you're in the correct directory
pwd  # Should show: .../jenkins-capacity-report

# Check if critical files exist
ls -la main.py web_app.py requirements.txt

# Check disk space
df -h .
```

### Package Testing Issues

**Problem**: Tests fail

**Solutions**:
```bash
# Check which tests failed
./deployment/test-package.sh <tarball> | grep "✗"

# Verify tarball integrity
tar -tzf <tarball> | head

# Re-create package
./deployment/package-for-deployment.sh
```

### Server Update Issues

**Problem**: Update script fails

**Solutions**:
```bash
# Check if running as root
whoami  # Should output: root

# Verify tarball exists
ls -lh /tmp/jenkins-capacity-*.tar.gz

# Check Apache status
systemctl status apache2

# Check disk space
df -h /var/www

# View detailed error logs
tail -100 /var/log/apache2/error.log
```

### Application Not Responding

**Problem**: Application doesn't load after update

**Solutions**:
```bash
# Check Apache error log
tail -100 /var/log/apache2/error.log

# Check application log
tail -100 /var/www/jenkins-capacity-report/logs/web_app.log

# Verify Python dependencies
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/pip list

# Restart Apache
sudo systemctl restart apache2

# Rollback if needed
cd /var/www/jenkins-capacity-report
sudo tar -xzf /var/backups/jenkins-capacity/jenkins-capacity-backup-*.tar.gz
sudo systemctl reload apache2
```

## 📝 Best Practices

1. **Always test locally before deploying**
   - Run the application locally
   - Test all features
   - Check for errors in logs

2. **Use the test script**
   ```bash
   ./deployment/test-package.sh jenkins-capacity-*.tar.gz
   ```

3. **Keep backups**
   - Backups are automatic
   - Last 10 backups are retained
   - Located in `/var/backups/jenkins-capacity/`

4. **Monitor logs during deployment**
   ```bash
   # In one terminal
   sudo tail -f /var/log/apache2/error.log
   
   # In another terminal
   sudo tail -f /var/www/jenkins-capacity-report/logs/web_app.log
   ```

5. **Verify after deployment**
   - Check the application URL
   - Test key features
   - Review logs for errors

## 🔗 Related Documentation

- **Quick Deploy Guide**: `QUICK-DEPLOY.md` - One-page deployment reference
- **Full Deployment Guide**: `../docs/DEPLOYMENT.md` - Comprehensive deployment documentation
- **Server-Specific Guide**: `../docs/DEPLOYMENT-GUIDE-nagios-adoptopenjdk.md` - nagios.adoptopenjdk.net specific instructions
- **Main README**: `../README.md` - Application overview and features

## 📞 Support

For issues or questions:
- Review the troubleshooting section above
- Check Apache error logs: `/var/log/apache2/error.log`
- Check application logs: `/var/www/jenkins-capacity-report/logs/web_app.log`
- Review the full deployment documentation

## 🎯 Summary

This deployment system provides:
- ✅ **Simple**: 3 commands to deploy
- ✅ **Safe**: Automatic backups and file preservation
- ✅ **Secure**: Sensitive files never included in packages
- ✅ **Fast**: Small packages (~100KB)
- ✅ **Reliable**: Automated testing and verification
- ✅ **Zero Downtime**: Graceful Apache reload

---

**Created by**: Bob  
**Last Updated**: 2026-04-15