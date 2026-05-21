# Metrics Tracking Feature

## Overview

The Jenkins Capacity Report now includes historical metrics tracking functionality with **automatic snapshot recording**. This feature allows you to capture snapshots of your Jenkins infrastructure over time and analyze trends in node availability, capacity, and utilization.

Snapshots are recorded automatically at configurable intervals when the web application is running, with no need for external cron jobs or manual intervention.

## Features

### 1. **Metrics Snapshots**
Each snapshot captures:
- **Total Nodes**: Number of active nodes (excluding excluded nodes)
- **Online Nodes**: Number of nodes currently online
- **Offline Nodes**: Number of nodes currently offline
- **Excluded Nodes**: Number of nodes marked as excluded
- **Online/Offline Percentages**: Calculated based on active nodes only
- **Executor Statistics**: Total, busy, and idle executors
- **Utilization Percentage**: Overall executor utilization

### 2. **Historical Data Storage**
- Metrics are stored in a local JSON file (`data/metrics_history.json`)
- Data persists across application restarts
- Thread-safe operations for concurrent access
- Automatic file creation on first use

### 3. **Statistics Dashboard**
View comprehensive statistics including:
- Total number of snapshots recorded
- Average online percentage over time
- Average utilization percentage
- Maximum and minimum node counts
- Average online and offline node counts
- Recording period (first to last snapshot)

## Usage

### Accessing the Metrics History Page

1. Navigate to the main dashboard
2. Click on **"📊 Metrics History"** in the navigation bar
3. Or directly access: `http://your-server/metrics-history`

### Automatic Snapshot Recording

**Built-in Scheduler:**
The application includes a built-in background scheduler that automatically records snapshots at configurable intervals. This is **enabled by default** and requires no external setup.

**Configuration:**
Add these settings to your `.env` file:

```bash
# Enable/disable automatic recording (default: true)
METRICS_AUTO_RECORD=true

# Interval in minutes between snapshots (default: 60)
METRICS_SNAPSHOT_INTERVAL=60
```

**Common Intervals:**
- `60` - Hourly snapshots (default)
- `30` - Every 30 minutes
- `360` - Every 6 hours
- `1440` - Daily snapshots

**How it works:**
1. When the web application starts, the scheduler is initialized
2. Snapshots are recorded automatically at the configured interval
3. Each recording refreshes data from Jenkins before saving
4. The scheduler runs in the background and doesn't affect web performance
5. Logs show when snapshots are recorded successfully

**Viewing Logs:**
```bash
# Check application logs for snapshot recording
tail -f /path/to/app.log | grep "metrics snapshot"
```

### Manual Recording

You can also record snapshots manually at any time:

**Via Web Interface:**
1. Go to the Metrics History page
2. Click the **"📸 Record Snapshot"** button
3. The system will refresh data and save immediately

**Via API:**
```bash
# Using curl
curl -X POST http://your-server/api/metrics/record

# Using Python requests
import requests
response = requests.post('http://your-server/api/metrics/record')
print(response.json())
```

### Disabling Automatic Recording

If you prefer manual control or external scheduling:

```bash
# In .env file
METRICS_AUTO_RECORD=false
```

Then use cron jobs or other schedulers:
```bash
# Hourly via cron
0 * * * * curl -X POST http://your-server/api/metrics/record
```

## API Endpoints

### Record Metrics Snapshot
```
POST /api/metrics/record
```
Records a new metrics snapshot after refreshing data from Jenkins.

**Response:**
```json
{
  "success": true,
  "snapshot": {
    "timestamp": "2026-03-30T08:42:15.123456",
    "total_nodes": 150,
    "online_nodes": 145,
    "offline_nodes": 5,
    "excluded_nodes": 10,
    "online_percentage": 96.67,
    "offline_percentage": 3.33,
    "total_executors": 600,
    "busy_executors": 450,
    "idle_executors": 150,
    "utilization_percentage": 75.0
  },
  "message": "Metrics snapshot recorded successfully"
}
```

### Get Recent Snapshots
```
GET /api/metrics/snapshots?limit=100
```
Retrieves the most recent metrics snapshots.

**Parameters:**
- `limit` (optional): Maximum number of snapshots to return (default: 100)

**Response:**
```json
{
  "snapshots": [...],
  "count": 100
}
```

### Get Statistics
```
GET /api/metrics/statistics
```
Retrieves calculated statistics from all snapshots.

**Response:**
```json
{
  "total_snapshots": 500,
  "first_recorded": "2026-01-01T00:00:00",
  "last_recorded": "2026-03-30T08:42:15",
  "avg_online_percentage": 95.5,
  "avg_utilization": 72.3,
  "max_nodes": 160,
  "min_nodes": 140,
  "avg_online_nodes": 143.2,
  "avg_offline_nodes": 6.8
}
```

### Clear History
```
POST /api/metrics/clear
```
Clears all recorded metrics history.

**Response:**
```json
{
  "success": true,
  "cleared_count": 500,
  "message": "Cleared 500 metrics snapshots"
}
```

## Data Storage

### File Location
Metrics are stored in: `data/metrics_history.json` (in the data subdirectory)

### File Format
```json
[
  {
    "timestamp": "2026-03-30T08:42:15.123456",
    "total_nodes": 150,
    "online_nodes": 145,
    "offline_nodes": 5,
    "excluded_nodes": 10,
    "online_percentage": 96.67,
    "offline_percentage": 3.33,
    "total_executors": 600,
    "busy_executors": 450,
    "idle_executors": 150,
    "utilization_percentage": 75.0
  },
  ...
]
```

### Backup and Restore

**Backup:**
```bash
cp data/metrics_history.json data/metrics_history_backup_$(date +%Y%m%d).json
```

**Restore:**
```bash
cp data/metrics_history_backup_20260330.json data/metrics_history.json
```

## Important Notes

### Excluded Nodes
- Excluded nodes are **NOT** counted in the total, online, or offline statistics
- The excluded node count is tracked separately
- Online/offline percentages are calculated based on active nodes only
- This ensures accurate capacity reporting for your actual working infrastructure

### Data Refresh
- Each snapshot recording triggers a fresh data pull from Jenkins
- This ensures metrics reflect the current state at the time of recording
- Network latency and Jenkins response time may affect recording duration

### Performance Considerations
- The metrics file grows with each snapshot
- Consider periodic cleanup of old data if storage is a concern
- Large history files (>10,000 snapshots) may impact page load times
- The system loads up to 500 recent snapshots on the metrics page by default

## Use Cases

1. **Capacity Planning**: Track node growth over time to plan infrastructure expansion
2. **Availability Monitoring**: Monitor online/offline trends to identify reliability issues
3. **Utilization Analysis**: Understand executor usage patterns to optimize resource allocation
4. **Incident Investigation**: Review historical data during outages or performance issues
5. **Reporting**: Generate capacity reports for management or compliance purposes

## Troubleshooting

### Metrics Not Recording
- Check file permissions on `data/metrics_history.json`
- Verify Jenkins connectivity
- Check application logs for errors

### Missing Data
- Ensure automated recording is configured correctly
- Verify cron jobs are running
- Check API endpoint accessibility

### Large File Size
- Consider implementing data retention policies
- Archive old data periodically
- Use the clear history function to reset

## Future Enhancements

Potential improvements for future versions:
- Data export to CSV/Excel
- Graphical charts and visualizations
- Configurable retention policies
- Email alerts for capacity thresholds
- Integration with monitoring systems (Prometheus, Grafana)
- Trend analysis and predictions

---

**Made with Bob**