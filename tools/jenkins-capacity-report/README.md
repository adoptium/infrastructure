# Jenkins Capacity Analyzer

A Python utility to extract and analyze Jenkins node capacity data, helping you understand build and test capacity across your Jenkins infrastructure.

## Features

- **Extract Node Data**: Retrieve comprehensive information about all Jenkins nodes via the Jenkins API
- **Capacity Analysis**: Calculate utilization metrics including busy/idle executors
- **Label-based Grouping**: Analyze capacity by node labels (e.g., OS, architecture, capabilities)
- **Cloud Capacity Reporting**: Analyze cloud provider configurations, templates, and instance limits (optional)
- **Node Exclusion**: Exclude specific nodes from statistics and reporting without removing them from Jenkins
- **Historical Metrics Tracking**: Record and analyze capacity trends over time with automated snapshots
- **Detailed Reporting**: Generate both summary and detailed node reports
- **Interactive Web Dashboard**: Real-time visualization with filtering and sorting capabilities
- **Data Export**: Save results to JSON and CSV files for further analysis

## Prerequisites

- Python 3.8 or higher
- Jenkins instance with API access
- Jenkins API token (not password)

## Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd Bob-Jenkins-Capacity
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure your Jenkins credentials:
   - Copy `.env.example` to `.env`
   - Edit `.env` with your Jenkins details:
```bash
JENKINS_URL=https://ci.adoptium.net
JENKINS_USERNAME=your_username
JENKINS_API_TOKEN=your_api_token

# Optional: Path to Jenkins clouds.xml export file
CLOUD_CONFIG_FILE=./data/clouds.xml.live
```

4. **(Optional but Recommended)** Set up cloud capacity reporting:
   
   Cloud capacity reporting provides insights into your Jenkins cloud provider configurations (AWS, Azure, Kubernetes, Docker, etc.) including template definitions, instance limits, and executor counts.
   
   **To enable cloud capacity reporting:**
   
   a. **On your Jenkins controller server**, run the extraction script:
   ```bash
   cd /path/to/jenkins-capacity-report/tools
   ./extract_clouds_config.sh -o ../data/clouds.xml.live
   ```
   
   b. **Copy the generated file** to your application directory:
   ```bash
   # If running remotely, copy from Jenkins server to your local machine
   scp jenkins-server:/path/to/jenkins-capacity-report/data/clouds.xml.live ./data/
   ```
   
   c. **Verify the configuration** in your `.env` file:
   ```bash
   CLOUD_CONFIG_FILE=./data/clouds.xml.live
   ```
   
   d. **Restart the application** if it's already running
   
   **Note:** The extraction script must be run on the Jenkins controller where the main `config.xml` file is located. It extracts the `<clouds>` section which contains all cloud provider configurations.
   
   **Without this file:**
   - Cloud capacity sections will show a warning message
   - Cloud Statistics page will display setup instructions
   - The "Cloud Statistics" navigation button will be disabled
   - CLI output will not include cloud capacity information

## Usage

### Web Dashboard (Recommended)

Run the Flask web application for an interactive dashboard:
```bash
python web_app.py
```

Then open your browser to: `http://localhost:5000`

The web dashboard provides:
- Real-time capacity overview with visual cards
- Quick stats by function with subcategories
- Cloud provider capacity and template information (if configured)
- **Node exclusion management** - exclude/include nodes from reporting
- Detailed node information organized by category and provider
- Interactive filtering and sorting capabilities
- Refresh button to update data on demand
- Responsive design for desktop and mobile

#### Node Exclusion Feature

The dashboard includes a powerful node exclusion feature that allows you to temporarily remove nodes from all statistics and counts without deleting them from Jenkins:

**To exclude a node:**
1. Navigate to the "All Nodes" tab
2. Find the node you want to exclude
3. Click the "✕ Exclude" button next to the node
4. Confirm the action

**To include a node back:**
1. Navigate to the "Excluded Nodes" tab
2. Find the node you want to include
3. Click the "✓ Include" button next to the node
4. Confirm the action

**Key features:**
- Excluded nodes are stored persistently in `excluded_nodes.json`
- Excluded nodes do NOT appear in:
  - Total node counts
  - Online/offline statistics
  - Category listings
  - Filter results
  - Label summaries
- Excluded nodes ARE visible in:
  - The dedicated "Excluded Nodes" tab (highlighted in red)
  - Node detail pages (if accessed directly)
- The "Excluded Nodes" tab shows a count badge
- You can clear all excluded nodes at once with the "Clear All" button

**Use cases:**
- Temporarily remove decommissioned nodes from reporting
- Exclude test/development nodes from production statistics
- Hide nodes undergoing maintenance without affecting Jenkins configuration

#### Metrics History Tracking

The dashboard includes **automatic** historical metrics tracking to monitor capacity trends over time:

**Features:**
- ✨ **Automatic snapshot recording** - No cron jobs needed!
- Configurable recording interval (default: hourly)
- Track total nodes, online/offline counts, and utilization over time
- Excluded nodes are tracked separately and don't affect statistics
- View comprehensive statistics including averages and trends
- Export and backup historical data

**Configuration:**
Add to your `.env` file:
```bash
# Enable automatic recording (default: true)
METRICS_AUTO_RECORD=true

# Recording interval in minutes (default: 60)
METRICS_SNAPSHOT_INTERVAL=60
```

**How it works:**
- Snapshots are recorded automatically when the web app is running
- Built-in background scheduler handles all recording
- No external cron jobs or scripts required
- Logs show when snapshots are recorded

**Manual recording:**
You can also record snapshots manually:
1. Navigate to the "📊 Metrics History" page
2. Click the "📸 Record Snapshot" button

**Data storage:**
- Metrics are stored in `metrics_history.json` (automatically created)
- File is excluded from git by default
- Can be backed up and restored as needed

For detailed information, see [METRICS-TRACKING.md](METRICS-TRACKING.md)


### Command Line Interface

Run the analyzer for console output and file export:
```bash
python main.py
```

This will:
1. Connect to your Jenkins instance
2. Fetch all node information
3. Display a capacity summary in the console
4. Show detailed node information
5. Save results to timestamped JSON and CSV files

### Output Files

The CLI tool generates the following files:
- `jenkins_nodes_YYYYMMDD_HHMMSS.json` - Detailed information about each node
- `jenkins_summary_YYYYMMDD_HHMMSS.json` - Capacity summary and statistics (includes cloud capacity if configured)
- `jenkins_nodes_YYYYMMDD_HHMMSS.csv` - Node data in CSV format for spreadsheet analysis
- `jenkins_cloud_capacity_YYYYMMDD_HHMMSS.csv` - Cloud provider capacity limits (if cloud config file is available)

### Console Output Example

```
============================================================
JENKINS CAPACITY SUMMARY
============================================================

Nodes:
  Total:   10
  Online:  8
  Offline: 2

Executors:
  Total: 40
  Busy:  25
  Idle:  15
  Utilization: 62.5%

Capacity by Label:
  Label                Nodes    Online   Executors  Busy     Idle    
  -------------------- -------- -------- ---------- -------- --------
  linux                5        4        20         12       8       
  windows              3        3        12         8        4       
  x64                  8        7        32         20       12      

============================================================
```

## Project Structure

```
jenkins-capacity-report/
├── src/
│   ├── __init__.py          # Package initialization
│   ├── models.py            # Data models (JenkinsNode, CapacitySummary)
│   ├── jenkins_client.py    # Jenkins API client
│   └── config.py            # Configuration management
├── templates/
│   ├── dashboard.html       # Web dashboard template
│   └── error.html           # Error page template
├── main.py                  # CLI entry point
├── web_app.py               # Flask web application
├── requirements.txt         # Python dependencies
├── .env.example            # Example environment configuration
├── .env                    # Your environment configuration (not in git)
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

## Data Models

### JenkinsNode
Represents a Jenkins node with properties:
- `name`: Node display name
- `description`: Node description
- `num_executors`: Number of executors
- `labels`: List of assigned labels
- `offline`: Whether node is offline
- `offline_cause`: Reason for being offline
- `idle`: Whether node is idle
- `temporarily_offline`: Temporary offline status
- `busy_executors`: Number of busy executors
- `idle_executors`: Number of idle executors

### CapacitySummary
Summary statistics:
- `total_nodes`: Total number of nodes
- `online_nodes`: Number of online nodes
- `offline_nodes`: Number of offline nodes
- `total_executors`: Total executors across all nodes
- `busy_executors`: Number of busy executors
- `idle_executors`: Number of idle executors
- `utilization_percentage`: Percentage of executors in use
- `labels_summary`: Capacity grouped by labels

## API Usage

You can also use the library programmatically:

```python
from src.config import Config
from src.jenkins_client import JenkinsClient

# Initialize
config = Config.from_env()
client = JenkinsClient(
    url=config.jenkins_url,
    username=config.username,
    api_token=config.api_token
)

# Get all nodes
nodes = client.get_all_nodes()

# Get capacity report
nodes, summary = client.get_capacity_report()

# Access data
print(f"Total executors: {summary.total_executors}")
print(f"Utilization: {summary.utilization_percentage}%")

for node in nodes:
    print(f"{node.name}: {node.busy_executors}/{node.num_executors} busy")
```

## Logging

Logs are written to:
- Console (stdout)
- `jenkins_capacity.log` file

Log level can be adjusted in `main.py`.

## Security Notes

- Never commit your `.env` file to version control
- Use Jenkins API tokens, not passwords
- Ensure your API token has appropriate read permissions
- The `.gitignore` file is configured to exclude `.env` and sensitive data

## Future Enhancements

Potential features for future versions:
- Historical capacity tracking
- Trend analysis and visualization
- Alerting for capacity thresholds
- Web dashboard for real-time monitoring
- Database storage for long-term analysis
- Comparison reports between time periods

## Troubleshooting

### Connection Issues
- Verify Jenkins URL is correct and accessible
- Check that API token is valid
- Ensure network connectivity to Jenkins instance

### Authentication Errors
- Regenerate API token in Jenkins user settings
- Verify username matches Jenkins account

### Missing Data
- Check Jenkins user has permission to view node information
- Verify nodes are properly configured in Jenkins

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.


## Additional Documentation

- **[Node Naming Patterns](docs/NODE-NAMING-PATTERNS.md)** - Configuration-based node naming pattern system for parsing dynamic and static node names
- **[Metrics Tracking](docs/METRICS-TRACKING.md)** - Historical capacity metrics and trend analysis
- **[Monthly Archiving](docs/MONTHLY-ARCHIVING.md)** - Automatic archiving of historical metrics data
- **[RBAC Guide](docs/RBAC-GUIDE.md)** - Role-based access control configuration
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Production deployment instructions
- **[Excluded Nodes API](docs/EXCLUDED-NODES-API.md)** - Node exclusion feature documentation

## Production Deployment

### 🚀 Simplified Deployment System

This project includes a streamlined deployment system for easy updates to production servers.

**Quick 3-Step Deployment:**

```bash
# 1. Create deployment package (local machine)
./deployment/package-for-deployment.sh

# 2. Transfer to server
scp jenkins-capacity-*.tar.gz user@nagios.adoptopenjdk.net:/tmp/

# 3. Update on server
ssh user@nagios.adoptopenjdk.net
cd /var/www/jenkins-capacity-report
sudo ./deployment/update-on-server.sh /tmp/jenkins-capacity-*.tar.gz
```

**Features:**
- ✅ Automatic exclusion of sensitive files (.env, users.json, clouds.xml.live)
- ✅ Automatic backups before updates
- ✅ Zero-downtime deployment (graceful Apache reload)
- ✅ Automated verification tests (35 tests)
- ✅ Small packages (~100KB vs 100MB+)
- ✅ Rollback capability

**Documentation:**
- **Quick Reference**: [deployment/QUICK-DEPLOY.md](deployment/QUICK-DEPLOY.md) - One-page deployment guide
- **Deployment System**: [deployment/README.md](deployment/README.md) - Complete deployment documentation
- **Full Guide**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) - Comprehensive deployment instructions
- **Server-Specific**: [docs/DEPLOYMENT-GUIDE-nagios-adoptopenjdk.md](docs/DEPLOYMENT-GUIDE-nagios-adoptopenjdk.md) - nagios.adoptopenjdk.net guide

### Initial Installation

For first-time installation on a new server:

```bash
# Automated initial deployment
sudo ./deployment/deploy.sh
```

The initial deployment script will:
- Install required system packages
- Set up Python virtual environment
- Configure Apache2 with WSGI
- Set proper file permissions
- Guide you through configuration options

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed initial installation instructions.

## License

[Add your license here]

## Author

Created for analyzing Jenkins capacity at Adoptium CI infrastructure.
</content>