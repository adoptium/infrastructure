# Monthly Metrics Archiving Feature

## Overview

The Monthly Archiving feature automatically organizes historical metrics data by calendar month, providing:
- **Current month snapshots** displayed in the main metrics history table
- **Archived monthly summaries** with comprehensive rollup statistics
- **Automatic archiving** at month boundaries
- **Manual archiving** via UI button

## Architecture

### Components

1. **ArchiveManager** (`src/archive_manager.py`)
   - Manages monthly archive files
   - Calculates comprehensive statistics
   - Handles archive storage and retrieval

2. **MetricsTracker Extensions** (`src/metrics_tracker.py`)
   - `get_current_month_snapshots()` - Filters current month data
   - `archive_and_cleanup()` - Archives completed months
   - `get_archived_summary()` - Retrieves archive summaries

3. **Web Interface** (`web_app.py`, `templates/metrics_history.html`)
   - Updated metrics history page
   - Archive summary table
   - Manual archive button
   - Automatic scheduler

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Record Snapshot                                              │
│   ↓                                                          │
│ metrics_history.json (current month only)                    │
│   ↓                                                          │
│ Month End / Manual Archive                                   │
│   ↓                                                          │
│ Calculate Statistics                                         │
│   ↓                                                          │
│ data/archive/metrics_YYYY-MM.json                           │
│   ↓                                                          │
│ Display in Monthly Archive Summary Table                     │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

```
jenkins-capacity-report/
├── data/
│   ├── metrics_history.json          # Current month snapshots only
│   └── archive/                       # Monthly archive files
│       ├── metrics_2026-01.json      # January 2026 archive
│       ├── metrics_2026-02.json      # February 2026 archive
│       ├── metrics_2026-03.json      # March 2026 archive
│       └── metrics_2026-04.json      # April 2026 archive
└── src/
    └── archive_manager.py             # Archive management module
```

## Archive File Format

Each monthly archive file contains:

```json
{
  "month": "2026-04",
  "start_date": "2026-04-01T08:15:23.474918",
  "end_date": "2026-04-30T23:45:12.599903",
  "snapshot_count": 720,
  "summary": {
    "overall": {
      "avg_total_nodes": 118.5,
      "min_total_nodes": 115,
      "max_total_nodes": 122,
      "avg_online_percentage": 92.15,
      "min_online_percentage": 85.2,
      "max_online_percentage": 98.1,
      ...
    },
    "executors": { ... },
    "build_nodes": { ... },
    "test_nodes": { ... },
    "infra_nodes": { ... },
    "docker_host_nodes": { ... }
  },
  "snapshots": [ /* all raw snapshots */ ]
}
```

## Statistics Calculated

For each archived month, the following statistics are calculated:

### Overall Metrics
- Average, min, max total nodes
- Average online/offline nodes
- Average, min, max online percentage
- Average excluded nodes

### Executor Metrics
- Average total/busy/idle executors
- Average, min, max utilization percentage

### Category Metrics (Build, Test, Infra, Docker)
For each category:
- Average total/online/offline/excluded nodes
- Average, min, max online percentage

## Usage

### Automatic Archiving

Archiving runs automatically at **00:05 on the 1st of each month** when the metrics scheduler is enabled.

Configuration in `.env`:
```bash
METRICS_AUTO_RECORD=true
METRICS_SNAPSHOT_INTERVAL=60  # minutes
```

### Manual Archiving

1. Navigate to **Metrics History** page
2. Scroll to **Monthly Archive Summary** section
3. Click **📦 Archive Previous Months** button
4. Confirm the action

This will:
- Archive all completed months
- Move snapshots to archive files
- Keep only current month in `metrics_history.json`
- Reload the page to show updated archives

### Viewing Archives

The **Monthly Archive Summary** table displays:
- Month and year
- Number of snapshots
- Date range
- Average nodes and online percentage
- Statistics for each category (Build, Test, Infra, Docker)
- Executor utilization statistics
- Min/Max ranges for key metrics

## API Endpoints

### POST /archive-metrics

Manually trigger archiving of completed months.

**Authentication:** Requires Operator or Admin role

**Request:**
```bash
curl -X POST http://localhost:5000/archive-metrics \
  -H "Content-Type: application/json" \
  -b "session_token=YOUR_SESSION_TOKEN"
```

**Response:**
```json
{
  "success": true,
  "archived_months": ["2026-01", "2026-02", "2026-03"],
  "snapshots_archived": 2160,
  "current_month_snapshots": 480,
  "message": "Successfully archived 3 month(s) with 2160 snapshots"
}
```

## Benefits

### Performance
- **Smaller main file**: `metrics_history.json` contains only current month
- **Faster page loads**: Less data to process and display
- **Efficient queries**: Quick access to current data

### Organization
- **Clear separation**: Current vs historical data
- **Easy navigation**: Monthly summaries at a glance
- **Scalable**: Handles years of data efficiently

### Analytics
- **Trend analysis**: Compare months easily
- **Capacity planning**: Historical patterns visible
- **Reporting**: Monthly statistics readily available

## Maintenance

### Backup Archives

Archive files are stored in `data/archive/`. To backup:

```bash
# Backup all archives
tar -czf metrics-archives-$(date +%Y%m%d).tar.gz data/archive/

# Backup specific month
cp data/archive/metrics_2026-04.json backups/
```

### Restore Archives

To restore archived data:

```bash
# Restore all archives
tar -xzf metrics-archives-20260420.tar.gz

# Restore specific month
cp backups/metrics_2026-04.json data/archive/
```

### Delete Old Archives

To remove archives older than a certain date:

```bash
# Delete archives older than 1 year
find data/archive/ -name "metrics_*.json" -mtime +365 -delete
```

## Troubleshooting

### Archive Not Appearing

**Issue:** Archived month not showing in summary table

**Solutions:**
1. Check archive file exists: `ls data/archive/metrics_YYYY-MM.json`
2. Verify file format is valid JSON
3. Check application logs for errors
4. Refresh the page

### Archiving Failed

**Issue:** Manual archiving returns error

**Solutions:**
1. Check user has Operator or Admin role
2. Verify `data/archive/` directory exists and is writable
3. Check application logs: `tail -f logs/web_app.log`
4. Ensure no file system issues

### Missing Snapshots

**Issue:** Snapshots disappeared after archiving

**Solutions:**
1. Check archive file: `cat data/archive/metrics_YYYY-MM.json`
2. Snapshots are moved, not deleted
3. Verify month is correct (archives only completed months)
4. Check logs for archiving confirmation

## Development

### Adding New Statistics

To add new statistics to archives:

1. Update `MonthlyArchive` dataclass in `src/archive_manager.py`
2. Update `calculate_monthly_summary()` method
3. Update template to display new statistics
4. Test with sample data

### Modifying Archive Format

To change archive file structure:

1. Update `archive_month()` method in `ArchiveManager`
2. Update `load_archive()` to handle new format
3. Consider backward compatibility
4. Document changes

## Best Practices

1. **Regular Backups**: Backup archive files regularly
2. **Monitor Disk Space**: Archives grow over time
3. **Test Archiving**: Use manual button to test before relying on automatic
4. **Review Logs**: Check logs after automatic archiving runs
5. **Validate Data**: Periodically verify archive file integrity

## Future Enhancements

Potential improvements:
- Detailed archive viewer (click month to see all snapshots)
- Export archives to CSV/Excel
- Archive compression for older months
- Configurable retention policies
- Archive search and filtering
- Comparison tools between months

---

**Made with Bob** - Jenkins Capacity Analyzer