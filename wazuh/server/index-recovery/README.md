# Wazuh Alert Recovery and Reindexing Tool

## Origins

Based On A Script Originally Sourced From This Blog Post
https://wazuh.com/blog/recover-your-data-using-wazuh-alert-backups/

## Overview

The `recovery.py` script is a powerful tool designed to extract and reindex Wazuh alerts from compressed log files within a specific time range. It's particularly useful for:

- **Data Recovery**: Recovering alerts after index corruption or data loss
- **Reprocessing**: Re-ingesting historical alerts with updated configurations
- **Migration**: Moving alerts between Wazuh installations
- **Analysis**: Extracting specific time ranges for forensic analysis

## Features

- ✅ Time-range based alert extraction
- ✅ Configurable Events Per Second (EPS) rate limiting
- ✅ Automatic file size management (truncate and restart output when limit reached)
- ✅ Progress tracking and detailed logging
- ✅ Dry-run mode for preview without writing
- ✅ Graceful interrupt handling (Ctrl+C)
- ✅ Comprehensive parameter validation
- ✅ Summary statistics on completion
- ✅ **Filebeat configuration validation** - Ensures output file is configured for ingestion

## Requirements

- **Python**: 3.6 or higher
- **Wazuh Installation**: With alert logs in standard location (`/var/ossec/logs/alerts/`)
- **Filebeat**: Configured to ingest Wazuh alerts (for automatic reindexing)
- **Disk Space**: Sufficient space for output files (consider using `-sz` parameter)
- **Permissions**: Read access to Wazuh logs, write access to output directory

## Installation

No installation required. The script uses only Python standard library modules.

```bash
# Make the script executable
chmod +x recovery.py

# Verify Python version
python3 --version
```

## Usage

### Basic Syntax

```bash
./recovery.py -min <MIN_TIMESTAMP> -max <MAX_TIMESTAMP> -o <OUTPUT_FILE> [OPTIONS]
```

### Required Parameters

| Parameter | Description | Format | Example |
|-----------|-------------|--------|---------|
| `-min`, `--min_timestamp` | Start of time range | `YYYY-MM-DDTHH:MM:SS` | `2024-01-01T00:00:00` |
| `-max`, `--max_timestamp` | End of time range | `YYYY-MM-DDTHH:MM:SS` | `2024-01-02T23:59:59` |
| `-o`, `--output_file` | Output file path | File path | `./recovered_alerts.json` |

### Optional Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `-eps`, `--eps` | Events per second rate limit | `400` | `-eps 500` |
| `-sz`, `--max_size` | Max output file size in GB | `1` | `-sz 2.5` |
| `-w`, `--wazuh_path` | Path to Wazuh installation | `/var/ossec/` | `-w /opt/wazuh/` |
| `-log`, `--log_file` | Log file for operation details | None | `-log recovery.log` |
| `--dry-run` | Preview without writing output | `False` | `--dry-run` |
| `--skip-filebeat-check` | Skip Filebeat configuration validation | `False` | `--skip-filebeat-check` |
| `--filebeat-manifest` | Path to Filebeat manifest file | `/usr/share/filebeat/module/wazuh/alerts/manifest.yml` | `--filebeat-manifest /custom/path/manifest.yml` |

## Examples

### Example 1: Basic Recovery

Extract alerts from a single day:

```bash
./recovery.py \
  -min 2024-01-15T00:00:00 \
  -max 2024-01-15T23:59:59 \
  -o alerts_jan15.json
```

### Example 2: With Custom EPS and Logging

Extract alerts with rate limiting and detailed logging:

```bash
./recovery.py \
  -min 2024-01-01T00:00:00 \
  -max 2024-01-07T23:59:59 \
  -o alerts_week1.json \
  -eps 500 \
  -log recovery_week1.log
```

### Example 3: Large Dataset with Size Limit

Extract large dataset with automatic output truncation when size limit is reached:

```bash
./recovery.py \
  -min 2024-01-01T00:00:00 \
  -max 2024-01-31T23:59:59 \
  -o alerts_january.json \
  -sz 5.0 \
  -eps 300 \
  -log january_recovery.log
```

### Example 4: Custom Wazuh Path

For non-standard Wazuh installations:

```bash
./recovery.py \
  -min 2024-01-01T00:00:00 \
  -max 2024-01-02T00:00:00 \
  -o alerts.json \
  -w /opt/wazuh/
```

### Example 5: Dry Run Preview

Preview what would be processed without writing output:

    ./recovery.py \
      -min 2024-01-01T00:00:00 \
      -max 2024-01-31T23:59:59 \
      -o alerts.json \
      --dry-run

## Filebeat Integration
### Overview

For the recovered alerts to be automatically reindexed into your Wazuh indexer, the output file must be configured in Filebeat's Wazuh module. The script automatically validates this configuration and will error if the output file is not properly configured.

### Step-by-Step Setup

#### 1. Configure Filebeat Manifest

Edit the Filebeat Wazuh alerts manifest file:

```bash
sudo nano /usr/share/filebeat/module/wazuh/alerts/manifest.yml
```

Add your recovery output file path to the `paths` section:

```yaml
filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
      input:
        paths:
          - /var/ossec/logs/alerts/alerts.json
          - /tmp/recovery.json  # Add your recovery file path here
```

**Important Notes:**
- Use the **absolute path** to your recovery output file
- The path must match exactly what you specify with the `-o` parameter
- Multiple recovery paths can be added if needed

#### 2. Restart Filebeat Service

After updating the configuration, restart Filebeat:

```bash
# For systemd-based systems (most modern Linux distributions)
sudo systemctl restart filebeat

# For SysV init systems
sudo service filebeat restart
```

#### 3. Verify Filebeat Status

Confirm Filebeat is running correctly:

```bash
# Check service status
sudo systemctl status filebeat

# Check Filebeat logs for errors
sudo tail -f /var/log/filebeat/filebeat
```

#### 4. Run Recovery Script

Now you can run the recovery script. It will automatically validate the Filebeat configuration:

```bash
./recovery.py \
  -min 2024-01-01T00:00:00 \
  -max 2024-01-02T00:00:00 \
  -o /tmp/recovery.json
```

### Filebeat Validation Behavior

**Automatic Validation:**
- The script checks if your output file is configured in the Filebeat manifest
- If not configured, the script will **error and exit** with detailed instructions
- This prevents creating recovery files that won't be ingested

**Skipping Validation:**
If you need to bypass the Filebeat check (e.g., for testing or manual ingestion):

```bash
./recovery.py \
  -min 2024-01-01T00:00:00 \
  -max 2024-01-02T00:00:00 \
  -o /tmp/recovery.json \
  --skip-filebeat-check
```

**Custom Manifest Location:**
If your Filebeat manifest is in a non-standard location:

```bash
./recovery.py \
  -min 2024-01-01T00:00:00 \
  -max 2024-01-02T00:00:00 \
  -o /tmp/recovery.json \
  --filebeat-manifest /custom/path/to/manifest.yml
```

### Troubleshooting Filebeat Integration

#### Error: "Output file is NOT configured in Filebeat"

**Cause:** The output file path is not in the Filebeat manifest.

**Solution:**
1. Edit the manifest: `sudo nano /usr/share/filebeat/module/wazuh/alerts/manifest.yml`
2. Add your output file path to the `paths` section
3. Restart Filebeat: `sudo systemctl restart filebeat`
4. Re-run the recovery script

#### Filebeat Not Ingesting Recovered Alerts

**Possible causes and solutions:**

1. **File permissions issue:**
   ```bash
   # Ensure Filebeat can read the recovery file
   sudo chmod 644 /tmp/recovery.json
   sudo chown root:root /tmp/recovery.json
   ```

2. **Filebeat registry issue:**
   ```bash
   # Check Filebeat registry
   sudo cat /var/lib/filebeat/registry/filebeat/log.json | grep recovery.json
   
   # If needed, clear registry (CAUTION: will re-ingest all files)
   sudo systemctl stop filebeat
   sudo rm -rf /var/lib/filebeat/registry
   sudo systemctl start filebeat
   ```

3. **Filebeat not monitoring the file:**
   ```bash
   # Check Filebeat logs
   sudo journalctl -u filebeat -f
   
   # Look for messages about your recovery file
   sudo grep recovery.json /var/log/filebeat/filebeat
   ```

4. **File format issue:**
   - Ensure the recovery file contains valid JSON (one alert per line)
   - Check for any corruption: `head -n 5 /tmp/recovery.json`

#### Verifying Ingestion

Check if alerts are being ingested:

```bash
# Monitor Filebeat harvester
sudo filebeat test output

# Check indexer for new alerts
curl -X GET "localhost:9200/wazuh-alerts-*/_count" -H 'Content-Type: application/json'
```


## How It Works

1. **Validation**: Validates all parameters and checks file/directory accessibility
2. **Date Range Iteration**: Iterates through each day in the specified range
3. **File Processing**: Reads compressed alert files (`ossec-alerts-DD.json.gz`)
4. **Timestamp Filtering**: Filters alerts within the exact timestamp range
5. **Rate Limiting**: Applies EPS throttling to avoid overwhelming the system
6. **Output Management**: Writes filtered alerts and truncates the output when the size limit is reached
7. **Summary**: Provides statistics on completion

## Output Format

The output file contains one JSON alert per line (JSONL format):

```json
{"timestamp":"2024-01-15T10:30:45.123+0000","rule":{"level":5,"description":"SSH authentication success"},...}
{"timestamp":"2024-01-15T10:31:12.456+0000","rule":{"level":3,"description":"User login"},...}
```

This format is compatible with:
- Wazuh indexer bulk import
- Elasticsearch bulk API
- Logstash input
- Custom processing scripts

## Performance Tuning

### EPS (Events Per Second)

The `-eps` parameter controls throughput:

- **Lower values (100-300)**: Gentler on system resources, slower processing
- **Default (400)**: Balanced for most systems
- **Higher values (500-1000)**: Faster processing, higher resource usage

**Recommendation**: Start with default, increase if system can handle it.

### File Size Management

The `-sz` parameter prevents output files from growing too large:

- When limit is reached, the file is truncated and restarted
- Useful for continuous reindexing scenarios
- Set based on available disk space and indexer capabilities

**Recommendation**: Use 1-5 GB for most scenarios.

## Troubleshooting

### Error: "Incorrect min timestamp"

**Cause**: Timestamp format is invalid

**Solution**: Ensure format is exactly `YYYY-MM-DDTHH:MM:SS`
```bash
# Correct
-min 2024-01-15T10:30:00

# Incorrect
-min 2024-01-15 10:30:00
-min 2024/01/15T10:30:00
```

### Error: "min_timestamp must be before max_timestamp"

**Cause**: Date range is reversed

**Solution**: Ensure min is earlier than max
```bash
# Correct
-min 2024-01-01T00:00:00 -max 2024-01-02T00:00:00

# Incorrect
-min 2024-01-02T00:00:00 -max 2024-01-01T00:00:00
```

### Error: "Wazuh path does not exist"

**Cause**: Specified Wazuh path is invalid

**Solution**: Verify Wazuh installation path
```bash
# Check if path exists
ls -la /var/ossec/logs/alerts/

# Use correct path
-w /var/ossec/
```

### Error: "Cannot write to output directory"

**Cause**: No write permissions for output location

**Solution**: Check permissions or use different directory
```bash
# Check permissions
ls -ld /path/to/output/

# Use writable location
-o /tmp/alerts.json
```

### Warning: "Couldn't find file"

**Cause**: No alert file exists for that date

**Solution**: This is normal if no alerts were generated that day. The script continues to the next day.

### Issue: Script is too slow

**Solutions**:
1. Increase EPS: `-eps 800`
2. Reduce date range: Process smaller chunks
3. Check disk I/O: Ensure output disk isn't bottleneck
4. Verify compression: Ensure gzip files aren't corrupted

### Issue: Output file too large

**Solutions**:
1. Reduce max size: `-sz 0.5` (500 MB)
2. Split date range: Process in smaller time windows
3. Filter at source: Modify script to filter by rule level or agent

## Best Practices

1. **Always use logging**: `-log recovery.log` for troubleshooting
2. **Test with dry-run**: Use `--dry-run` first to preview
3. **Start small**: Test with 1-day range before processing months
4. **Monitor resources**: Watch CPU, memory, and disk I/O during processing
5. **Backup first**: Ensure original logs are backed up before recovery
6. **Verify output**: Check output file integrity after completion
7. **Use appropriate EPS**: Don't overwhelm your indexer

## Advanced Usage

### Processing Multiple Time Ranges

Use a shell script to process multiple ranges:

```bash
#!/bin/bash
for month in {01..12}; do
  ./recovery.py \
    -min 2024-${month}-01T00:00:00 \
    -max 2024-${month}-31T23:59:59 \
    -o alerts_2024_${month}.json \
    -log recovery_2024_${month}.log
done
```

### Filtering Specific Agents

Modify the script to add agent filtering (requires code modification):

```python
# In the processing loop, add:
if 'agent' in line_json and line_json['agent']['id'] == '001':
    # Process only agent 001
```

### Integration with Indexer

The generated output file is JSONL (one alert per line). For ingestion/reindexing, use Filebeat (recommended; see above) or a pipeline that supports JSON Lines input (for example, Logstash with a json_lines codec).

## Limitations

- Only processes compressed `.json.gz` alert files
- Requires alerts to be in standard Wazuh format
- Memory usage increases with EPS rate
- No built-in deduplication (processes all matching alerts)

## Support

For issues or questions:
1. Check this documentation
2. Review log files for error details
3. Verify Wazuh installation and log structure
4. Check GitHub issues for similar problems

## Version History

- **v2.0**: Enhanced validation, error handling, dry-run mode, progress tracking
- **v1.0**: Initial release with basic functionality

## License

This tool is part of the Wazuh infrastructure recovery toolkit.