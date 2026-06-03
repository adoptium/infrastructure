# Jenkins logRotator Configuration Tool

Safely configure logRotator settings in Jenkins job `config.xml` files.

## Purpose

This script ensures all Jenkins jobs have proper build retention policies configured:
1. Sets `removeLastBuild=true` to allow deletion of the last build
2. Ensures `daysToKeep` and `artifactDaysToKeep` are set (default: 365 days)
3. Ensures `numToKeep` and `artifactNumToKeep` are set (default: 5 builds)
4. Creates complete logRotator configuration for jobs that don't have one

This prevents old builds from accumulating and consuming excessive memory/disk space.

## Features

- ✅ **Safe XML parsing** - Uses Python's built-in ElementTree with character entity preservation
- ✅ **Automatic backups** - Creates backups preserving directory structure
- ✅ **Pattern matching** - Supports glob and regex for job selection
- ✅ **Dry-run mode** - Preview changes without modifying files
- ✅ **Smart defaults** - Creates sensible retention policies
- ✅ **Detailed reporting** - Shows exactly what changed per field
- ✅ **Dual format support** - Handles both `<logRotator>` and `<jenkins.model.BuildDiscarderProperty>` formats
- ✅ **Character entity preservation** - Maintains escaped characters like `&#xd;` in XML

## Requirements

- Python 3.6+
- No external dependencies (uses only Python standard library)

## Quick Start

```bash
# Test on single job
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/dir \
    --pattern "my-job" \
    --verbose \
    --dry-run

# Update all jobs
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/dir
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `jenkins_home` | Path to JENKINS_HOME directory (required) |
| `backup_dir` | Directory for backups (required) |
| `--pattern PATTERN` | Process only jobs matching this pattern (glob or regex) |
| `--dry-run` | Show changes without modifying files |
| `--verbose` | Show detailed output for all jobs |
| `--list-matches` | List all jobs (or matching jobs if pattern provided) without processing |

## Configuration Rules

The script applies these rules:

1. **If logRotator exists:**
   - Sets `daysToKeep=365` if missing/empty/-1
   - Sets `artifactDaysToKeep=365` if missing/empty/-1
   - Sets `numToKeep=5` if missing/empty/-1
   - Sets `artifactNumToKeep=5` if missing/empty/-1
   - Sets `removeLastBuild=true`

2. **If logRotator doesn't exist:**
   - Creates complete logRotator with:
     - `daysToKeep=365`
     - `numToKeep=5`
     - `artifactDaysToKeep=365`
     - `artifactNumToKeep=5`
     - `removeLastBuild=true`

## Pattern Examples

```bash
# Exact match
--pattern "my-job"

# Glob patterns
--pattern "Test*"              # All jobs starting with Test
--pattern "build-*"            # All jobs starting with build-

# Regex patterns
--pattern "Test.*"             # All jobs starting with Test
--pattern ".*openjdk8.*"       # All jobs containing openjdk8
--pattern "build-scripts/.*"   # All jobs in build-scripts folder
```

## Supported XML Formats

The tool supports both current and legacy Jenkins XML formats:

**Format 1: Direct logRotator (older Jenkins versions)**
```xml
<properties>
  <logRotator>
    <daysToKeep>365</daysToKeep>
    <numToKeep>5</numToKeep>
    <artifactDaysToKeep>365</artifactDaysToKeep>
    <artifactNumToKeep>5</artifactNumToKeep>
    <removeLastBuild>true</removeLastBuild>
  </logRotator>
</properties>
```

**Format 2: BuildDiscarderProperty (current Jenkins versions)**
```xml
<properties>
  <jenkins.model.BuildDiscarderProperty>
    <strategy class="hudson.tasks.LogRotator">
      <daysToKeep>365</daysToKeep>
      <numToKeep>5</numToKeep>
      <artifactDaysToKeep>365</artifactDaysToKeep>
      <artifactNumToKeep>5</artifactNumToKeep>
      <removeLastBuild>true</removeLastBuild>
    </strategy>
  </jenkins.model.BuildDiscarderProperty>
</properties>
```

Both formats are fully supported and will be updated appropriately.

## XML Changes

**Before (missing logRotator):**
```xml
<project>
  <properties/>
  <!-- No logRotator -->
</project>
```

**After:**
```xml
<project>
  <properties>
    <jenkins.model.BuildDiscarderProperty>
      <strategy class="hudson.tasks.LogRotator">
        <daysToKeep>365</daysToKeep>
        <numToKeep>5</numToKeep>
        <artifactDaysToKeep>365</artifactDaysToKeep>
        <artifactNumToKeep>5</artifactNumToKeep>
        <removeLastBuild>true</removeLastBuild>
      </strategy>
    </jenkins.model.BuildDiscarderProperty>
  </properties>
</project>
```

## Output Indicators

- ✅ Modified - Job was successfully updated
- ✅ Created - New logRotator was created
- ℹ️ No changes - Job already has correct configuration
- ❌ Error - Problem processing job (e.g., multiple logRotators)

## Example Output

```
================================================================================
SUMMARY
================================================================================
Total: 150
✅ Modified: 45
✅ Created: 30 (new logRotator)
⏭️  Skipped: 70 (no changes needed)
❌ Errors: 5
================================================================================

FIELD STATISTICS
================================================================================
daysToKeep:
  - Set to 365: 45 jobs
  - Created with 365: 30 jobs
  
artifactDaysToKeep:
  - Set to 365: 45 jobs
  - Created with 365: 30 jobs

numToKeep:
  - Set to 5: 20 jobs
  - Created with 5: 30 jobs

removeLastBuild:
  - Set to true: 75 jobs
================================================================================
```

## Safety Features

1. **Automatic Backups**: Backups created in separate directory preserving structure
2. **Dry-run Mode**: Test changes without modifying files
3. **Error Handling**: Graceful error handling per job
4. **Skip Logic**: Skips jobs that don't need changes
5. **Detailed Logging**: Shows exactly what changed per field
6. **Character Preservation**: Maintains XML character entities like `&#xd;`
7. **XML Version Preservation**: Keeps original XML version (1.0 or 1.1)

## Character Entity Preservation

The tool preserves XML character entities (like `&#xd;` for carriage return) by:
1. Detecting and replacing them with unique placeholders before parsing
2. Processing the XML normally
3. Restoring the original entities after writing

This ensures that special characters in descriptions and other fields remain exactly as they were.

## Troubleshooting

**Permission denied:**
- Ensure write access to Jenkins job directories and backup directory
- May need to run as Jenkins user or with sudo

**Rollback:**
```bash
# Backups are in the backup directory preserving structure
# Find backup
ls -la /backup/dir/jobs/my-job/config.xml

# Restore
cp /backup/dir/jobs/my-job/config.xml \
   /home/jenkins/.jenkins/jobs/my-job/config.xml
```

**Multiple logRotators error:**
- Manual intervention required
- Check config.xml for duplicate logRotator definitions
- Remove duplicates manually

## Post-Update Steps

1. **Reload Jenkins**: Manage Jenkins → Reload Configuration from Disk
2. **Verify Changes**: Check a few jobs in Jenkins UI to confirm settings
3. **Monitor**: Watch for any issues after reload

## Usage Examples

### Basic Usage

```bash
# Update all jobs with defaults
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins

# Dry-run to preview changes
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins --dry-run --verbose
```

### Pattern Matching

```bash
# Update only test jobs
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins --pattern "Test*"

# Update jobs in specific folder
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins --pattern "build-scripts/.*"

# List all jobs without processing
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins --list-matches

# List only jobs matching a pattern without processing
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins --pattern "Test*" --list-matches
```

### Verbose Output

```bash
# See detailed changes for all jobs
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins --verbose

# Combine with pattern and dry-run
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins \
    --pattern "my-job" \
    --verbose \
    --dry-run
```

## Version History

### v2.1.0 (Current)
- Changed default retention from 30 to 365 days
- Modified backup strategy to preserve directory structure
- Enhanced summary statistics with per-field changes
- Added character entity preservation (e.g., `&#xd;`)
- Added XML version preservation (1.0 or 1.1)
- Fixed `--list-matches` to work with or without pattern

### v2.0.0
- Added support for both logRotator formats
- Removed archival logic (both formats are valid)
- Enhanced field-level statistics

### v1.0.0
- Initial release
- Support for direct `<logRotator>` format only

## License

Internal tool for Adoptium infrastructure management.

## Author

Adoptium Infrastructure Team