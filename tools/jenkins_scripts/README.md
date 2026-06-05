# Jenkins Scripts

Collection of utility scripts and scriptlets for managing Jenkins configurations and infrastructure.

## Available Tools

### updateLogRotators.scriptlet

**Groovy scriptlet** to configure build retention policies (LogRotator settings) for Jenkins jobs. Runs directly in Jenkins Script Console.

**Key Features:**
- Updates existing LogRotator settings (sets defaults for -1 values)
- Creates LogRotator for jobs that don't have one
- Forces `removeLastBuild=true` for all jobs
- Preserves existing artifact retention settings
- Dry-run mode for safe testing
- Works with all job types that support LogRotator
- Uses Jenkins API (no file parsing required)

**Configuration (edit in scriptlet):**
```groovy
boolean dryRun = true                              // Set to false to apply changes
boolean process_all_jobs = false                   // Set to true to process ALL jobs
String filter_DisplayName_starts_with = "STARTS_WITH_FILTER_VALUE"   // Filter prefix (ignored if process_all_jobs = true)

// Default LogRotator values
int default_daysToKeep = 365
int default_numToKeep  = 5
int default_artifactDaysToKeep = -1
int default_artifactNumToKeep  = 1
boolean default_removeLastBuild = true
```

**Usage:**

**Step 0: Backup all config.xml files (IMPORTANT)**
```bash
# Run from Jenkins home directory
cd /home/jenkins/.jenkins
find jobs -name "config.xml" -print0 | tar -czf jenkins-configs-$(date +%Y%m%d-%H%M%S).tar.gz --null -T -

# Verify backup was created
ls -lh jenkins-configs-*.tar.gz
```

**Step 1-6: Run the scriptlet**
1. Open Jenkins → Manage Jenkins → Script Console
2. Copy the contents of `updateLogRotators.scriptlet`
3. Configure processing mode:
   - **Option A:** Set `process_all_jobs = true` to process ALL jobs
   - **Option B:** Set `process_all_jobs = false` and set `filter_DisplayName_contains = "your-substring"`
4. Set `dryRun = true` for testing
5. Click "Run"
6. Review output, then set `dryRun = false` and run again to apply

**What It Does:**
- **For jobs with existing LogRotator:**
  - Sets `daysToKeep=365` if currently -1
  - Sets `numToKeep=5` if currently -1
  - Forces `removeLastBuild=true` if not already set
  - Preserves artifact settings unchanged
  - Only updates jobs that need changes (skips jobs already configured correctly)
  
- **For jobs without LogRotator:**
  - Creates new LogRotator with default values
  - Sets all retention policies

- **Optional immediate log rotation:**
  - If `performRotate = true`, calls `job.logRotate()` after updating
  - Immediately prunes old builds according to new retention policy
  - Useful for cleaning up builds right away

**Safety:**
- Always test with `dryRun = true` first
- Use job name filter to limit scope
- Review output before applying changes
- Changes are saved immediately when `dryRun = false`
- Summary report shows exactly what was changed

## Requirements

- **Scriptlets (.scriptlet):** Run in Jenkins Script Console (no external dependencies)
- **Python scripts (.py):** Python 3.6+ (uses only standard library)

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

### Scriptlet Usage (Recommended)

**Advantages:**
- ✅ Runs directly in Jenkins (no file system access needed)
- ✅ Uses Jenkins API (respects job types and permissions)
- ✅ Immediate feedback in Script Console
- ✅ No backup needed (Jenkins handles configuration)
- ✅ Works with all job types (Freestyle, Pipeline, etc.)

**Steps:**
1. Edit scriptlet to set dry-run and defaults
2. Modify job filter (line 17) to target specific jobs
3. Run in Script Console with `dryRun = true`
4. Review output
5. Set `dryRun = false` and run again

**Job Filtering:**

The scriptlet uses `filter_DisplayName_starts_with` for simple prefix matching. For more complex filtering, edit line 22 in the scriptlet:

```groovy
// Current implementation (simple prefix filter)
boolean shouldProcess = process_all_jobs || job.fullDisplayName.startsWith(filter_DisplayName_starts_with)

// Custom filter examples:

// Jobs in specific folder
boolean shouldProcess = process_all_jobs || job.fullDisplayName.startsWith("MyFolder/")

// Jobs matching regex
boolean shouldProcess = process_all_jobs || job.fullDisplayName.matches(".*openjdk.*")

// Multiple prefixes (OR)
boolean shouldProcess = process_all_jobs ||
    job.fullDisplayName.startsWith("build-") ||
    job.fullDisplayName.startsWith("test-")

// Folder AND name pattern (AND)
boolean shouldProcess = process_all_jobs ||
    (job.fullDisplayName.startsWith("MyFolder/") &&
     job.fullDisplayName.contains("production"))

// Exclude certain jobs
boolean shouldProcess = (process_all_jobs || job.fullDisplayName.startsWith("build-")) &&
    !job.fullDisplayName.contains("archived")
```

## Post-Update Steps

After running scriptlets in Script Console:

1. **Verify Changes**
   - Check a few jobs in Jenkins UI to confirm settings
   - Navigate to job → Configure → Build Discarder
   - Verify retention policies are set correctly

2. **Monitor**
   - Watch for any job execution issues
   - Check Jenkins system logs if needed

**Note:** Scriptlets save changes immediately (no reload needed). Changes are applied via Jenkins API and persisted to disk automatically.

## Troubleshooting

### Scriptlet Errors

**"No such property: dryRun"**
- Ensure `dryRun` variable is defined at top of script
- Check for typos in variable name

**"Method not found: supportsLogRotator()"**
- Job type doesn't support LogRotator
- This is normal for folders and organization items
- Script will skip these automatically

**Changes Not Applied**
- Verify `dryRun = false` when applying changes
- Check Script Console output for errors
- Ensure you have admin permissions in Jenkins

**"WARNING: Unrecognized BuildDiscarder"**
- Job has a custom BuildDiscarder implementation
- Script only handles standard LogRotator
- These jobs are skipped automatically

## Contributing

When adding new scripts to this collection:

1. Follow the established patterns (dry-run, backups, pattern matching)
2. Use only Python standard library (no external dependencies)
3. Include comprehensive documentation
4. Add usage examples
5. Update this README with a summary and link to detailed docs

## Script Review

### updateLogRotators.scriptlet Analysis

**Strengths:**
- ✅ Clean, readable Groovy code
- ✅ Proper dry-run implementation
- ✅ Handles both existing and missing LogRotators
- ✅ Preserves artifact settings when updating
- ✅ Clear output messages
- ✅ Uses Jenkins API correctly

**Suggestions:**
- Line 17: Currently filters `job.fullDisplayName.startsWith("andrew")` - remember to update this filter for production use
- Consider adding a counter summary at the end (e.g., "Processed X jobs, Updated Y, Created Z")
- Could add validation to ensure defaults are reasonable (e.g., daysToKeep > 0)

**Security:**
- Script requires Jenkins admin permissions to run
- Only runs in Script Console (not exposed to users)
- Changes are logged in Jenkins audit log

## License

Internal tools for Adoptium infrastructure management.

## Author

Adoptium Infrastructure Team

## Support

For issues or questions:
- Check the detailed documentation for each tool
- Review troubleshooting sections
- Contact the Adoptium Infrastructure Team