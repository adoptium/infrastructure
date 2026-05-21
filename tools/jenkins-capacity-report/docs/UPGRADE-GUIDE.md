# Upgrade Guide - Metrics Tracking Feature

## Upgrading to Version with Automatic Metrics Tracking

If you're upgrading from a previous version, follow these steps to enable the new automatic metrics tracking feature.

### 1. Install New Dependencies

The metrics tracking feature requires the APScheduler library:

```bash
pip install -r requirements.txt
```

Or install directly:
```bash
pip install apscheduler>=3.10.0
```

### 2. Update Configuration

Add the new configuration options to your `.env` file:

```bash
# Metrics Tracking Configuration
# Enable automatic snapshot recording (true/false)
METRICS_AUTO_RECORD=true

# Interval in minutes between automatic snapshots (default: 60)
METRICS_SNAPSHOT_INTERVAL=60
```

You can copy these from `.env.example` if needed.

### 3. Restart the Application

After updating dependencies and configuration:

```bash
# If running directly
python web_app.py

# If using systemd
sudo systemctl restart jenkins-capacity

# If using Apache/WSGI
sudo systemctl restart apache2
```

### 4. Verify Automatic Recording

Check the application logs to confirm the scheduler started:

```bash
# Look for these log messages:
# "Starting automatic metrics recording every X minutes"
# "Metrics recording scheduler started successfully"
# "Metrics snapshot recorded successfully at ..."
```

### 5. Access Metrics History

Navigate to the "📊 Metrics History" page in the web interface to view recorded snapshots.

## Configuration Options

### Enable/Disable Automatic Recording

```bash
# Enable (default)
METRICS_AUTO_RECORD=true

# Disable (use manual recording only)
METRICS_AUTO_RECORD=false
```

### Adjust Recording Interval

```bash
# Hourly (default)
METRICS_SNAPSHOT_INTERVAL=60

# Every 30 minutes
METRICS_SNAPSHOT_INTERVAL=30

# Every 6 hours
METRICS_SNAPSHOT_INTERVAL=360

# Daily
METRICS_SNAPSHOT_INTERVAL=1440
```

## Troubleshooting

### Scheduler Not Starting

**Check logs for errors:**
```bash
tail -f /path/to/app.log | grep -i scheduler
```

**Common issues:**
- APScheduler not installed: Run `pip install apscheduler`
- Configuration error: Check `.env` file syntax
- Permission issues: Ensure app can write to `data/metrics_history.json`

### Snapshots Not Recording

**Verify configuration:**
```bash
# Check if auto-record is enabled
grep METRICS_AUTO_RECORD .env
```

**Check Jenkins connectivity:**
- Ensure Jenkins URL, username, and API token are correct
- Test connection manually via the dashboard

### High Memory Usage

If you have many snapshots (>10,000), consider:
- Clearing old data periodically
- Increasing the recording interval
- Implementing data retention policies

## Rollback

If you need to disable the feature:

1. Set `METRICS_AUTO_RECORD=false` in `.env`
2. Restart the application
3. The scheduler will not start, but existing data remains accessible

## Data Migration

The metrics history file (`data/metrics_history.json`) is created automatically. No migration is needed for existing installations.

To preserve existing data when upgrading:
```bash
# Backup before upgrade
cp data/metrics_history.json data/metrics_history.backup.json

# After upgrade, data is automatically used
```

---

**Made with Bob**