#!/usr/bin/env python3

"""
Wazuh Alert Recovery and Reindexing Tool

This script extracts and reindexes Wazuh alerts from compressed log files
within a specific time range. Useful for data recovery, reprocessing, and migration.


Originally Sourced From This Blog Post
https://wazuh.com/blog/recover-your-data-using-wazuh-alert-backups/

Additional validation checks and improvements added by #IBMBob
"""

import gzip
import time
import json
import argparse
import re
import os
import sys
import signal
from datetime import datetime, timedelta
from typing import Optional, TextIO


class RecoveryConfig:
    """Configuration and validation for the recovery process."""
    
    def __init__(self, args: argparse.Namespace):
        """Initialize configuration from command-line arguments."""
        self.eps_max = args.eps if args.eps else 400
        self.wazuh_path = args.wazuh_path if args.wazuh_path else '/var/ossec/'
        self.max_size = args.max_size if args.max_size else 1.0
        self.output_file = args.output_file
        self.log_file = args.log_file
        self.dry_run = args.dry_run
        self.skip_filebeat_check = args.skip_filebeat_check
        self.min_timestamp_str = args.min_timestamp
        self.max_timestamp_str = args.max_timestamp
        self.filebeat_manifest = args.filebeat_manifest if args.filebeat_manifest else '/usr/share/filebeat/module/wazuh/alerts/manifest.yml'
        
        # Parsed values (set during validation)
        self.min_timestamp: datetime = datetime.now()  # Will be set in validate()
        self.max_timestamp: datetime = datetime.now()  # Will be set in validate()
        self.max_bytes: int = 0
        
        # File handles
        self.log_handle: Optional[TextIO] = None
        
    def validate(self) -> bool:
        """
        Validate all configuration parameters.
        
        Returns:
            bool: True if all validations pass, False otherwise
        """
        # Validate EPS
        if self.eps_max <= 0:
            self._log_error("EPS must be greater than 0")
            return False
        
        if self.eps_max > 10000:
            self._log_warning(f"EPS value {self.eps_max} is very high and may impact system performance")
        
        # Validate max_size
        if self.max_size <= 0:
            self._log_error("max_size must be greater than 0")
            return False
        
        self.max_bytes = int(self.max_size * 1024 * 1024 * 1024)
        
        # Validate timestamps
        if not self._validate_timestamps():
            return False
        
        # Validate Wazuh path
        if not self._validate_wazuh_path():
            return False
        
        # Validate output file path (only if not dry-run)
        if not self.dry_run and not self._validate_output_path():
            return False
        
        # Validate Filebeat configuration (only if not dry-run and not skipped)
        if not self.dry_run and not self.skip_filebeat_check:
            if not self._validate_filebeat_config():
                return False
        
        # Open log file if specified
        if self.log_file:
            try:
                self.log_handle = open(self.log_file, 'a+')
            except IOError as e:
                self._log_error(f"Cannot open log file '{self.log_file}': {e}")
                return False
        
        return True
    
    def _validate_timestamps(self) -> bool:
        """Validate timestamp format and range."""
        # Validate format with regex first
        timestamp_pattern = r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$'
        
        if not re.match(timestamp_pattern, self.min_timestamp_str):
            self._log_error(f"Invalid min_timestamp format: '{self.min_timestamp_str}'. Expected: YYYY-MM-DDTHH:MM:SS")
            return False
        
        if not re.match(timestamp_pattern, self.max_timestamp_str):
            self._log_error(f"Invalid max_timestamp format: '{self.max_timestamp_str}'. Expected: YYYY-MM-DDTHH:MM:SS")
            return False
        
        # Parse timestamps
        try:
            self.min_timestamp = datetime.strptime(self.min_timestamp_str, '%Y-%m-%dT%H:%M:%S')
        except ValueError as e:
            self._log_error(f"Cannot parse min_timestamp: {e}")
            return False
        
        try:
            self.max_timestamp = datetime.strptime(self.max_timestamp_str, '%Y-%m-%dT%H:%M:%S')
        except ValueError as e:
            self._log_error(f"Cannot parse max_timestamp: {e}")
            return False
        
        # Validate timestamp order
        if self.min_timestamp >= self.max_timestamp:
            self._log_error("min_timestamp must be before max_timestamp")
            return False
        
        # Validate timestamps are not in the future
        now = datetime.now()
        if self.max_timestamp > now:
            self._log_warning(f"max_timestamp is in the future (current time: {now.strftime('%Y-%m-%dT%H:%M:%S')})")
        
        # Validate reasonable date range (not more than 10 years)
        date_diff = (self.max_timestamp - self.min_timestamp).days
        if date_diff > 3650:
            self._log_warning(f"Date range is very large ({date_diff} days). This may take a long time.")
        
        return True
    
    def _validate_wazuh_path(self) -> bool:
        """Validate Wazuh installation path exists."""
        if not os.path.isdir(self.wazuh_path):
            self._log_error(f"Wazuh path does not exist: '{self.wazuh_path}'")
            return False
        
        # Check if alerts directory exists
        alerts_path = os.path.join(self.wazuh_path, 'logs', 'alerts')
        if not os.path.isdir(alerts_path):
            self._log_error(f"Wazuh alerts directory does not exist: '{alerts_path}'")
            return False
        
        return True
    
    def _validate_filebeat_config(self) -> bool:
        """
        Validate that the output file path is configured in Filebeat manifest.
        
        Returns:
            bool: True if configured or manifest doesn't exist, False if not configured
        """
        # Check if Filebeat manifest exists
        if not os.path.exists(self.filebeat_manifest):
            self._log_warning(f"Filebeat manifest not found at '{self.filebeat_manifest}'")
            self._log_warning("Skipping Filebeat configuration check")
            return True
        
        try:
            # Read the manifest file
            with open(self.filebeat_manifest, 'r') as f:
                manifest_content = f.read()
            
            # Get absolute path of output file for comparison
            output_abs_path = os.path.abspath(self.output_file)
            
            # Check if the output file path is in the manifest
            if output_abs_path in manifest_content or self.output_file in manifest_content:
                return True
            
            # Path not found in manifest
            self._log_error("=" * 70)
            self._log_error("FILEBEAT CONFIGURATION ERROR")
            self._log_error("=" * 70)
            self._log_error(f"Output file '{self.output_file}' is NOT configured in Filebeat!")
            self._log_error(f"Filebeat manifest: {self.filebeat_manifest}")
            self._log_error("")
            self._log_error("To fix this issue:")
            self._log_error("1. Edit the Filebeat manifest file:")
            self._log_error(f"   sudo nano {self.filebeat_manifest}")
            self._log_error("")
            self._log_error("2. Add your output file path to the 'paths' section:")
            self._log_error("   filebeat.modules:")
            self._log_error("     - module: wazuh")
            self._log_error("       alerts:")
            self._log_error("         enabled: true")
            self._log_error("         input:")
            self._log_error("           paths:")
            self._log_error("             - /var/ossec/logs/alerts/alerts.json")
            self._log_error(f"             - {output_abs_path}")
            self._log_error("")
            self._log_error("3. Restart Filebeat service:")
            self._log_error("   sudo systemctl restart filebeat")
            self._log_error("")
            self._log_error("4. Verify Filebeat is running:")
            self._log_error("   sudo systemctl status filebeat")
            self._log_error("")
            self._log_error("Alternatively, use --skip-filebeat-check to bypass this validation")
            self._log_error("=" * 70)
            
            return False
            
        except IOError as e:
            self._log_error(f"Cannot read Filebeat manifest '{self.filebeat_manifest}': {e}")
            return False
        except Exception as e:
            self._log_error(f"Error validating Filebeat configuration: {e}")
            return False
    
    def _validate_output_path(self) -> bool:
        """Validate output file path is writable."""
        output_dir = os.path.dirname(self.output_file)
        
        # If no directory specified, use current directory
        if not output_dir:
            output_dir = '.'
        
        # Check if directory exists
        if not os.path.isdir(output_dir):
            self._log_error(f"Output directory does not exist: '{output_dir}'")
            return False
        
        # Check if directory is writable
        if not os.access(output_dir, os.W_OK):
            self._log_error(f"Cannot write to output directory: '{output_dir}'")
            return False
        
        # Check if output file already exists and warn
        if os.path.exists(self.output_file):
            self._log_warning(f"Output file '{self.output_file}' already exists and will be overwritten")
        
        return True
    
    def _log_error(self, message: str):
        """Log error message to stderr."""
        print(f"ERROR: {message}", file=sys.stderr)
    
    def _log_warning(self, message: str):
        """Log warning message to stderr."""
        print(f"WARNING: {message}", file=sys.stderr)
    
    def close(self):
        """Close any open file handles."""
        if self.log_handle:
            self.log_handle.close()


class RecoveryStats:
    """Track statistics during recovery process."""
    
    def __init__(self):
        self.total_alerts = 0
        self.files_processed = 0
        self.files_not_found = 0
        self.errors = 0
        self.start_time = time.time()
    
    def get_summary(self) -> str:
        """Generate summary statistics string."""
        elapsed = time.time() - self.start_time
        elapsed_str = str(timedelta(seconds=int(elapsed)))
        
        summary = [
            "\n" + "="*60,
            "RECOVERY SUMMARY",
            "="*60,
            f"Total alerts extracted: {self.total_alerts:,}",
            f"Files processed: {self.files_processed}",
            f"Files not found: {self.files_not_found}",
            f"Errors encountered: {self.errors}",
            f"Time elapsed: {elapsed_str}",
            "="*60
        ]
        
        return "\n".join(summary)


class WazuhRecovery:
    """Main recovery process handler."""
    
    def __init__(self, config: RecoveryConfig):
        self.config = config
        self.stats = RecoveryStats()
        self.month_dict = ['Null', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        self.interrupted = False
        
        # Setup signal handler for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle interrupt signals gracefully."""
        self.log("\nReceived interrupt signal. Shutting down gracefully...")
        self.interrupted = True
    
    def log(self, message: str):
        """
        Log message with timestamp to console and optionally to file.
        
        Args:
            message: Message to log
        """
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        formatted_msg = f"{timestamp} wazuh-reinjection: {message}"
        print(formatted_msg)
        
        if self.config.log_handle:
            self.config.log_handle.write(formatted_msg + "\n")
            self.config.log_handle.flush()
    
    def run(self) -> bool:
        """
        Execute the recovery process.
        
        Returns:
            bool: True if successful, False otherwise
        """
        self.log("Starting Wazuh alert recovery process")
        self.log(f"Time range: {self.config.min_timestamp_str} to {self.config.max_timestamp_str}")
        self.log(f"EPS limit: {self.config.eps_max}")
        self.log(f"Max output size: {self.config.max_size} GB")
        
        if self.config.dry_run:
            self.log("DRY RUN MODE - No output will be written")
            return self._dry_run()
        else:
            return self._process_alerts()
    
    def _dry_run(self) -> bool:
        """Preview what would be processed without writing output."""
        current_time = datetime(self.config.min_timestamp.year,
                               self.config.min_timestamp.month,
                               self.config.min_timestamp.day)
        max_time = datetime(self.config.max_timestamp.year,
                           self.config.max_timestamp.month,
                           self.config.max_timestamp.day)
        
        self.log("\nFiles that would be processed:")
        
        while current_time <= max_time and not self.interrupted:
            alert_file = self._get_alert_file_path(current_time)
            
            if os.path.exists(alert_file):
                file_size = os.path.getsize(alert_file)
                size_mb = file_size / (1024 * 1024)
                self.log(f"  ✓ {alert_file} ({size_mb:.2f} MB)")
                self.stats.files_processed += 1
            else:
                self.log(f"  ✗ {alert_file} (not found)")
                self.stats.files_not_found += 1
            
            current_time += timedelta(days=1)
        
        self.log(self.stats.get_summary())
        return True
    
    def _process_alerts(self) -> bool:
        """Process and extract alerts to output file."""
        chunk = 0
        
        try:
            with open(self.config.output_file, 'w') as output_handle:
                current_time = datetime(self.config.min_timestamp.year,
                                       self.config.min_timestamp.month,
                                       self.config.min_timestamp.day)
                max_time = datetime(self.config.max_timestamp.year,
                                   self.config.max_timestamp.month,
                                   self.config.max_timestamp.day)
                
                while current_time <= max_time and not self.interrupted:
                    alert_file = self._get_alert_file_path(current_time)
                    
                    if os.path.exists(alert_file):
                        chunk = self._process_file(alert_file, output_handle, chunk)
                        self.stats.files_processed += 1
                        
                        # Check if output file exceeded max size
                        if os.path.getsize(self.config.output_file) >= self.config.max_bytes:
                            self.log("Output file reached max size, truncating and restarting")
                            output_handle.seek(0)
                            output_handle.truncate()
                            time.sleep(5)
                    else:
                        self.log(f"File not found: {alert_file}")
                        self.stats.files_not_found += 1
                    
                    current_time += timedelta(days=1)
                
                if self.interrupted:
                    self.log("Process interrupted by user")
                    return False
                
        except IOError as e:
            self.log(f"ERROR: Cannot write to output file: {e}")
            return False
        
        self.log(self.stats.get_summary())
        self.log(f"Output written to: {self.config.output_file}")
        
        if os.path.exists(self.config.output_file):
            output_size = os.path.getsize(self.config.output_file) / (1024 * 1024 * 1024)
            self.log(f"Output file size: {output_size:.2f} GB")
        
        return True
    
    def _get_alert_file_path(self, date: datetime) -> str:
        """Generate alert file path for given date."""
        return os.path.join(
            self.config.wazuh_path,
            'logs', 'alerts',
            str(date.year),
            self.month_dict[date.month],
            f'ossec-alerts-{date.day:02d}.json.gz'
        )
    
    def _process_file(self, alert_file: str, output_handle: TextIO, chunk: int) -> int:
        """
        Process a single alert file.
        
        Args:
            alert_file: Path to the alert file
            output_handle: Output file handle
            chunk: Current chunk counter for EPS limiting
            
        Returns:
            int: Updated chunk counter for EPS rate limiting
        """
        daily_alerts = 0
        try:
            self.log(f"Processing: {alert_file}")
            
            with gzip.open(alert_file, 'rt', encoding='utf-8', errors='replace') as compressed_alerts:
                for line_num, line in enumerate(compressed_alerts, 1):
                    if self.interrupted:
                        break
                    
                    try:
                        line_json = json.loads(line)
                        
                        # Extract and validate timestamp
                        if 'timestamp' not in line_json:
                            continue
                        
                        string_timestamp = line_json['timestamp'][:19]
                        
                        # Ensure timestamp integrity (pad milliseconds if needed)
                        while len(line_json['timestamp'].split("+")[0]) < 23:
                            line_json['timestamp'] = (line_json['timestamp'][:20] + 
                                                     "0" + line_json['timestamp'][20:])
                        
                        # Parse event timestamp
                        try:
                            event_date = datetime.strptime(string_timestamp, '%Y-%m-%dT%H:%M:%S')
                        except ValueError:
                            continue
                        
                        # Check if timestamp is within range
                        if (event_date >= self.config.min_timestamp and 
                            event_date <= self.config.max_timestamp):
                            
                            output_handle.write(json.dumps(line_json) + "\n")
                            daily_alerts += 1
                            self.stats.total_alerts += 1
                            chunk += 1
                            
                            # Apply EPS rate limiting
                            if chunk >= self.config.eps_max:
                                output_handle.flush()
                                chunk = 0
                                time.sleep(1)
                    
                    except json.JSONDecodeError as e:
                        self.stats.errors += 1
                        if self.config.log_handle:
                            self.log(f"JSON decode error at line {line_num}: {e}")
                    except Exception as e:
                        self.stats.errors += 1
                        if self.config.log_handle:
                            self.log(f"Error processing line {line_num}: {e}")
            
            date_str = f"{alert_file.split('/')[-3]}-{alert_file.split('/')[-2]}-{alert_file.split('/')[-1].split('-')[-1].split('.')[0]}"
            self.log(f"Extracted {daily_alerts:,} alerts from {date_str}")
            
        except Exception as e:
            self.log(f"ERROR processing file {alert_file}: {e}")
            self.stats.errors += 1
        
        return chunk


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Wazuh Alert Recovery and Reindexing Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic recovery for one day
  %(prog)s -min 2024-01-15T00:00:00 -max 2024-01-15T23:59:59 -o alerts.json
  
  # With custom EPS and logging
  %(prog)s -min 2024-01-01T00:00:00 -max 2024-01-07T23:59:59 \\
           -o alerts.json -eps 500 -log recovery.log
  
  # Dry run to preview
  %(prog)s -min 2024-01-01T00:00:00 -max 2024-01-31T23:59:59 \\
           -o alerts.json --dry-run

For more information, see README.md
        """
    )
    
    # Required arguments
    parser.add_argument('-min', '--min_timestamp',
                       required=True,
                       metavar='TIMESTAMP',
                       help='Start timestamp (format: YYYY-MM-DDTHH:MM:SS)')
    
    parser.add_argument('-max', '--max_timestamp',
                       required=True,
                       metavar='TIMESTAMP',
                       help='End timestamp (format: YYYY-MM-DDTHH:MM:SS)')
    
    parser.add_argument('-o', '--output_file',
                       required=True,
                       metavar='FILE',
                       help='Output file path')
    
    # Optional arguments
    parser.add_argument('-eps', '--eps',
                       type=int,
                       metavar='N',
                       help='Events per second rate limit (default: 400)')
    
    parser.add_argument('-sz', '--max_size',
                       type=float,
                       metavar='GB',
                       help='Maximum output file size in GB (default: 1)')
    
    parser.add_argument('-w', '--wazuh_path',
                       metavar='PATH',
                       help='Path to Wazuh installation (default: /var/ossec/)')
    
    parser.add_argument('-log', '--log_file',
                       metavar='FILE',
                       help='Log file for detailed output')
    
    parser.add_argument('--dry-run',
                       action='store_true',
                       help='Preview files without writing output')
    
    parser.add_argument('--skip-filebeat-check',
                       action='store_true',
                       help='Skip Filebeat configuration validation')
    
    parser.add_argument('--filebeat-manifest',
                       metavar='PATH',
                       help='Path to Filebeat manifest file (default: /usr/share/filebeat/module/wazuh/alerts/manifest.yml)')
    
    args = parser.parse_args()
    
    # Create and validate configuration
    config = RecoveryConfig(args)
    
    if not config.validate():
        config.close()
        sys.exit(1)
    
    # Run recovery process
    recovery = WazuhRecovery(config)
    success = recovery.run()
    
    # Cleanup
    config.close()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

# Made with Bob
