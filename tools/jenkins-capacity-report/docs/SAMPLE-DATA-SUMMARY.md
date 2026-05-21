# Sample Archive Data Summary

## Overview

6 months of sample archive data has been generated for demonstration purposes.

## Generated Archives

| Month | File | Snapshots | Size | Avg Online % | Avg Utilization % |
|-------|------|-----------|------|--------------|-------------------|
| October 2025 | `metrics_2025-10.json` | 744 | 917 KB | 92.85% | 19.78% |
| November 2025 | `metrics_2025-11.json` | 720 | 887 KB | 92.99% | 20.31% |
| December 2025 | `metrics_2025-12.json` | 744 | 917 KB | 92.95% | 20.34% |
| January 2026 | `metrics_2026-01.json` | 744 | 917 KB | 92.87% | 19.57% |
| February 2026 | `metrics_2026-02.json` | 672 | 829 KB | 93.01% | 20.06% |
| March 2026 | `metrics_2026-03.json` | 744 | 917 KB | 92.97% | 20.16% |

**Total:** 4,368 snapshots across 6 months (5.3 MB)

## Data Characteristics

### Snapshot Frequency
- **~24 snapshots per day** (hourly intervals)
- Realistic timestamp distribution
- Random minute/second values

### Node Statistics
- **Total Nodes:** 115-122 (varies per snapshot)
- **Online Percentage:** 88-98% (realistic variation)
- **Excluded Nodes:** 5-10 per snapshot

### Category Breakdown

#### Build Nodes
- Total: 7-9 nodes
- Online: 90-100%
- Average across all months: ~95%

#### Test Nodes
- Total: 88-95 nodes
- Online: 85-95%
- Average across all months: ~90%

#### Infrastructure Nodes
- Total: 5 nodes (constant)
- Online: 95-100%
- Average across all months: ~97.5%

#### Docker Host Nodes
- Total: 10 nodes (constant)
- Online: 95-100%
- Average across all months: ~97.5%

### Executor Statistics
- **Total Executors:** 118-125
- **Utilization:** 5-35%
- **Average Utilization:** ~20%

## Viewing the Data

### Web Interface

1. Start the Flask application:
   ```bash
   cd jenkins-capacity-report
   python3 web_app.py
   ```

2. Navigate to: `http://localhost:5000/metrics-history`

3. You will see:
   - **Current Month Snapshots** (April 2026) - 25 snapshots
   - **Monthly Archive Summary** - 6 archived months with comprehensive statistics

### Archive Table Display

The Monthly Archive Summary table shows:
- Month and snapshot count
- Date range
- Overall statistics (avg nodes, avg online %, range)
- Category statistics (Build, Test, Infra, Docker)
- Executor utilization statistics
- Min/Max ranges for key metrics

## File Locations

```
jenkins-capacity-report/
└── data/
    ├── metrics_history.json          # Current month (April 2026)
    └── archive/                       # Historical archives
        ├── metrics_2025-10.json      # October 2025
        ├── metrics_2025-11.json      # November 2025
        ├── metrics_2025-12.json      # December 2025
        ├── metrics_2026-01.json      # January 2026
        ├── metrics_2026-02.json      # February 2026
        └── metrics_2026-03.json      # March 2026
```

## Testing Archiving

### Manual Archive Test

You can test the archiving functionality by clicking the "📦 Archive Previous Months" button on the Metrics History page. This will:
- Archive any completed months from `metrics_history.json`
- Move them to the archive directory
- Display them in the Monthly Archive Summary table

### Automatic Archiving

The system is configured to automatically archive at 00:05 on the 1st of each month when the scheduler is running.

## Regenerating Sample Data

To regenerate the sample data, run:

```bash
cd jenkins-capacity-report
python3 << 'EOF'
# [Include the generation script from earlier]
EOF
```

## Data Integrity

All generated archives include:
- ✓ Valid JSON format
- ✓ Complete snapshot data
- ✓ Comprehensive statistics
- ✓ Proper timestamp formatting
- ✓ Realistic value ranges
- ✓ All required fields

---

**Generated:** April 20, 2026  
**Purpose:** Demonstration and testing of monthly archiving feature