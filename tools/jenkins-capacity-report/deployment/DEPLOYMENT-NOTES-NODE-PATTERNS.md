# Deployment Notes: Node Naming Pattern System

## Overview

This deployment includes a new configuration-based node naming pattern system that requires the `config/` directory to be deployed.

## New Files in This Release

### Required Files
- `config/node_patterns.json` - Pattern configuration (REQUIRED)
- `src/node_pattern_matcher.py` - Pattern matching engine (REQUIRED)
- `tests/test_node_patterns.py` - Test suite

### Updated Files
- `src/config.py` - Added node_patterns_config parameter
- `main.py` - Updated parsing functions to use NodePatternMatcher
- `.env.example` - Added NODE_PATTERNS_CONFIG setting

### Documentation
- `docs/NODE-NAMING-PATTERNS.md` - User guide
- `docs/DYNAMIC-NODES-IMPLEMENTATION.md` - Implementation details

## Deployment Checklist

### 1. Pre-Deployment Verification

✅ Verify package includes `config/node_patterns.json`:
```bash
tar -tzf jenkins-capacity-YYYYMMDD-HHMMSS.tar.gz | grep config/node_patterns.json
```

✅ Verify package includes `src/node_pattern_matcher.py`:
```bash
tar -tzf jenkins-capacity-YYYYMMDD-HHMMSS.tar.gz | grep node_pattern_matcher.py
```

### 2. Deployment Steps

The standard deployment process will automatically include the new files:

```bash
# Transfer package to server
scp jenkins-capacity-YYYYMMDD-HHMMSS.tar.gz user@server:/tmp/

# SSH to server
ssh user@server

# Run update script (preserves .env and data/)
cd /var/www/jenkins-capacity-report
sudo ./deployment/update-on-server.sh /tmp/jenkins-capacity-YYYYMMDD-HHMMSS.tar.gz
```

### 3. Post-Deployment Verification

✅ Verify config directory exists:
```bash
ls -la /var/www/jenkins-capacity-report/config/
```

✅ Verify node_patterns.json is readable:
```bash
cat /var/www/jenkins-capacity-report/config/node_patterns.json | jq . | head -20
```

✅ Test pattern matching:
```bash
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/python tests/test_node_patterns.py
```

Expected output: `27 passed, 0 failed out of 27 tests`

✅ Check application logs for pattern loading:
```bash
tail -f /var/log/apache2/jenkins-capacity-error.log | grep -i pattern
```

Expected: `Loaded X node naming patterns from ./config/node_patterns.json`

### 4. Configuration (Optional)

The system works with default patterns. To customize:

1. Edit `/var/www/jenkins-capacity-report/config/node_patterns.json`
2. Add or modify patterns as needed
3. Reload Apache: `sudo systemctl reload apache2`
4. Verify with test script

## Backward Compatibility

✅ **Fully backward compatible** - All existing node names will continue to work
✅ **No .env changes required** - NODE_PATTERNS_CONFIG has a sensible default
✅ **No database migration needed** - Pure code update

## New Supported Node Patterns

This release adds support for:

1. **Azure Dynamic Nodes**: `build-linux-x64-21bf53`
2. **Orka Dynamic Nodes**: `test-orka-macos14-arm64`
3. **GitHub Actions Nodes**: `gha-macos15-x64`
4. **Nodes with Suffixes**: `dockerhost-azure-win2022-x64-1-amd`
5. **Multi-part Suffixes**: `test-sxa-ubuntu2004-armv7l-odroid-2`

## Troubleshooting

### Pattern File Not Found

**Symptom**: Log shows "Pattern config file not found"

**Solution**:
```bash
# Verify file exists
ls -la /var/www/jenkins-capacity-report/config/node_patterns.json

# Check permissions
sudo chown www-data:www-data /var/www/jenkins-capacity-report/config/node_patterns.json
sudo chmod 644 /var/www/jenkins-capacity-report/config/node_patterns.json
```

### Nodes Showing as "Unknown"

**Symptom**: Nodes appear with "UNKNOWN" type or architecture

**Solution**:
1. Check node name format
2. Run test script to verify patterns
3. Add custom pattern to `config/node_patterns.json` if needed
4. See `docs/NODE-NAMING-PATTERNS.md` for pattern syntax

### Import Errors

**Symptom**: `ModuleNotFoundError: No module named 'src.node_pattern_matcher'`

**Solution**:
```bash
# Verify file exists
ls -la /var/www/jenkins-capacity-report/src/node_pattern_matcher.py

# Reinstall if needed
cd /var/www/jenkins-capacity-report
sudo -u www-data venv/bin/pip install -r requirements.txt
sudo systemctl reload apache2
```

## Rollback Procedure

If issues occur, rollback is simple:

1. Restore previous deployment package
2. Extract over current installation
3. Reload Apache

The old code will work fine - it just won't recognize the new dynamic node patterns.

## Performance Impact

✅ **Minimal** - Patterns are compiled once at startup
✅ **Cached** - Global singleton pattern for efficiency
✅ **No database queries** - Pure in-memory pattern matching

## Security Considerations

✅ **No sensitive data** in config files
✅ **Read-only** pattern file (644 permissions)
✅ **No user input** in pattern matching
✅ **Validated regex** patterns at load time

## Support

For issues or questions:
- See `docs/NODE-NAMING-PATTERNS.md` for usage guide
- See `docs/DYNAMIC-NODES-IMPLEMENTATION.md` for technical details
- Run test suite: `python tests/test_node_patterns.py`

## Made with Bob