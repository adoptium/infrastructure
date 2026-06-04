# Jenkins Scripts

Collection of utility scripts for managing Jenkins configurations and infrastructure.

## Available Tools

### logRotatorUpdate.py

Configure build retention policies (logRotator settings) in Jenkins job config.xml files.

**Key Features:**
- Sets build retention policies (days to keep, number to keep)
- Supports both XML formats (direct logRotator and BuildDiscarderProperty)
- Automatic backups with directory structure preservation
- Pattern matching for selective job updates
- Dry-run mode for safe testing
- Character entity preservation in XML

**Quick Start:**
```bash
# Update all jobs
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/dir

# Test on specific jobs
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/dir \
    --pattern "Test*" --dry-run --verbose
```

**[Full Documentation →](LOG_ROTATOR_UPDATE.md)**

## Requirements

All scripts require:
- Python 3.6+
- No external dependencies (uses only Python standard library)

## Common Features

- **Safe Operations**: All tools include dry-run modes and automatic backups
- **Pattern Matching**: Support for glob and regex patterns to target specific jobs
- **Detailed Reporting**: Clear output showing what changed and why
- **Error Handling**: Graceful error handling with detailed error messages

## Installation

No installation required. Scripts can be run directly:

```bash
# Clone or download the scripts
cd /path/to/jenkins_scripts

# Run any script
python3 logRotatorUpdate.py --help
```

## Usage Patterns

### Dry-Run First
Always test changes with `--dry-run` before applying:
```bash
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/dir \
    --pattern "my-jobs*" --dry-run --verbose
```

### Pattern Matching
Use patterns to target specific jobs. Patterns match the filesystem path structure (Jenkins stores folders as `jobs/<folder>/jobs/<job>`):

```bash
# Glob patterns
--pattern "Test*"                 # Top-level jobs starting with Test
--pattern "build-*"               # Top-level jobs starting with build-

# Regex patterns
--pattern ".*openjdk8.*"          # Jobs containing openjdk8 (any level)
--pattern "folder/jobs/.*"        # Jobs in "folder" (filesystem structure)
```

**Note:** For jobs in folders, patterns must include `/jobs/` directories (e.g., `folder/jobs/job-name`).

### List Matching Jobs
Preview which jobs match your pattern:
```bash
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/dir \
    --pattern "Test*" --list-matches
```

## Post-Update Steps

After running any script that modifies Jenkins configurations:

1. **Reload Jenkins Configuration**
   - Navigate to: Manage Jenkins → Reload Configuration from Disk
   - Or use Jenkins CLI: `java -jar jenkins-cli.jar -s http://jenkins reload-configuration`

2. **Verify Changes**
   - Check a few jobs in Jenkins UI to confirm settings
   - Review the script output for any errors

3. **Monitor**
   - Watch Jenkins logs for any issues
   - Check job execution after changes

## Backup and Recovery

All scripts create backups before making changes:

```bash
# Backups preserve directory structure
/backup/dir/
  └── jobs/
      └── my-job/
          └── config.xml

# Restore from backup
cp /backup/dir/jobs/my-job/config.xml \
   /home/jenkins/.jenkins/jobs/my-job/config.xml

# Then reload Jenkins configuration
```

## Troubleshooting

### Permission Denied
- Ensure write access to Jenkins directories and backup directory
- May need to run as Jenkins user: `sudo -u jenkins python3 script.py ...`
- Or with sudo: `sudo python3 script.py ...`

### Script Errors
- Check Python version: `python3 --version` (requires 3.6+)
- Verify paths are correct and accessible
- Use `--verbose` flag for detailed output
- Check script output for specific error messages

### Jenkins Not Reflecting Changes
- Reload Jenkins configuration from disk
- Check file permissions on modified config.xml files
- Verify XML is well-formed (scripts validate before writing)

## Contributing

When adding new scripts to this collection:

1. Follow the established patterns (dry-run, backups, pattern matching)
2. Use only Python standard library (no external dependencies)
3. Include comprehensive documentation
4. Add usage examples
5. Update this README with a summary and link to detailed docs

## Version History

See individual tool documentation for version history:
- [logRotatorUpdate.py versions](LOG_ROTATOR_UPDATE.md#version-history)

## License

Internal tools for Adoptium infrastructure management.

## Author

Adoptium Infrastructure Team

## Support

For issues or questions:
- Check the detailed documentation for each tool
- Review troubleshooting sections
- Contact the Adoptium Infrastructure Team