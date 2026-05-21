# Dynamic Node Naming Pattern Implementation Summary

## Overview

This document summarizes the implementation of configuration-based node naming pattern support for dynamically provisioned Jenkins nodes.

## Problem Statement

The Jenkins Capacity Analyzer needed to support three types of dynamically provisioned nodes with different naming patterns:

1. **Azure Dynamic Nodes**: `build-linux-x64-21bf53` (no provider in name)
2. **Orka Dynamic Nodes**: `test-orka-macos14-arm64` (provider included)
3. **GitHub Actions Nodes**: `gha-macos15-x64` (special prefix)

The existing system expected a standard 5-part naming pattern: `function-provider-os-arch-number`

## Solution

Implemented a flexible, configuration-based pattern matching system using regex patterns with priority-based matching.

## Implementation Details

### 1. Configuration File

**File**: `config/node_patterns.json`

Contains pattern definitions with:
- Regex patterns with named capture groups
- Priority ordering (lower = higher priority)
- Template-based field extraction
- Fallback configuration

### 2. Pattern Matcher Class

**File**: `src/node_pattern_matcher.py`

**Key Components**:
- `NodePattern`: Represents a single pattern with compiled regex
- `NodePatternMatcher`: Matches node names against patterns
- `NodeMetadata`: Extracted metadata (provider, function, OS, architecture)
- Global singleton pattern for efficient reuse

**Features**:
- Automatic pattern loading from JSON config
- Priority-based pattern matching
- Template substitution for field extraction
- Fallback handling for unmatched nodes
- Default patterns if config file missing

### 3. Configuration Integration

**File**: `src/config.py`

Added `node_patterns_config` parameter to Config class:
- Loads from `NODE_PATTERNS_CONFIG` environment variable
- Defaults to `./config/node_patterns.json`
- Integrated with existing configuration system

### 4. Updated Parsing Functions

**File**: `main.py`

Updated functions to use NodePatternMatcher:
- `extract_provider_from_name()` - Uses pattern matcher with backward compatibility
- `extract_os_from_name()` - Extracts OS from correct position based on pattern
- `extract_architecture_from_name()` - Extracts and normalizes architecture
- `get_node_category()` - Maps function to category using pattern metadata

### 5. Environment Configuration

**File**: `.env.example`

Added configuration option:
```bash
NODE_PATTERNS_CONFIG=./config/node_patterns.json
```

### 6. Testing

**File**: `tests/test_node_patterns.py`

Comprehensive test suite covering:
- All three dynamic node types
- Standard 5-part nodes
- Docker, infrastructure, and service nodes
- Controller nodes
- Pattern priority verification

**Test Results**: 19/19 tests passed ✓

### 7. Documentation

**File**: `docs/NODE-NAMING-PATTERNS.md`

Complete documentation including:
- Configuration format and structure
- Supported patterns with examples
- Template substitution syntax
- Adding new patterns
- Usage examples
- Troubleshooting guide

## Supported Node Patterns

| Pattern Type | Example | Provider | Function | OS | Arch |
|-------------|---------|----------|----------|-----|------|
| Azure Dynamic | `build-linux-x64-21bf53` | azure | build | linux | x64 |
| Orka Dynamic | `test-orka-macos14-arm64` | orka | test | macos14 | aarch64 |
| GHA Dynamic | `gha-macos15-x64` | github-actions | test | macos15 | x64 |
| Standard | `test-azure-win11-x64-1` | azure | test | win11 | x64 |
| Docker Static | `test-docker-ubuntu2404-x64-1` | docker | test | ubuntu2404 | x64 |

## Benefits

1. **Flexibility**: Easy to add new patterns without code changes
2. **Maintainability**: Clear separation of pattern logic from business logic
3. **Extensibility**: Simple JSON configuration for new providers
4. **Backward Compatibility**: Existing nodes continue to work
5. **Performance**: Compiled regex patterns for efficient matching
6. **Testability**: Comprehensive test coverage for all patterns

## Files Created

- `config/node_patterns.json` - Pattern configuration
- `src/node_pattern_matcher.py` - Pattern matching engine
- `tests/test_node_patterns.py` - Test suite
- `docs/NODE-NAMING-PATTERNS.md` - User documentation
- `docs/DYNAMIC-NODES-IMPLEMENTATION.md` - This file

## Files Modified

- `.env.example` - Added NODE_PATTERNS_CONFIG
- `src/config.py` - Added node_patterns_config parameter
- `main.py` - Updated parsing functions to use NodePatternMatcher
- `README.md` - Added link to NODE-NAMING-PATTERNS.md

## Usage Example

```python
from src.node_pattern_matcher import get_pattern_matcher

# Get pattern matcher instance
matcher = get_pattern_matcher()

# Match a node name
metadata = matcher.match("build-linux-x64-21bf53")

print(f"Provider: {metadata.provider}")      # azure
print(f"Function: {metadata.function}")      # build
print(f"OS: {metadata.os}")                  # linux
print(f"Architecture: {metadata.architecture}")  # x64
print(f"Pattern: {metadata.pattern_name}")   # azure_dynamic
```

## Adding New Patterns

To add support for a new node naming pattern:

1. Edit `config/node_patterns.json`
2. Add a new pattern object with appropriate regex and templates
3. Set priority to control matching order
4. Test with sample node names using `tests/test_node_patterns.py`

Example:
```json
{
  "name": "my_pattern",
  "regex": "^(?P<function>build|test)-custom-(?P<os>[a-z0-9]+)-(?P<arch>[a-z0-9]+)$",
  "priority": 4,
  "provider": "my-provider",
  "function": "{function}",
  "os": "{os}",
  "architecture": "{arch}",
  "description": "My custom pattern"
}
```

## Migration Notes

- **No breaking changes**: Existing functionality preserved
- **Automatic migration**: Old node names work without changes
- **Configuration optional**: System works with default patterns if config missing
- **Backward compatible**: All existing helper functions maintain same API

## Testing

Run the test suite:
```bash
cd jenkins-capacity-report
python tests/test_node_patterns.py
```

Expected output: All tests pass with detailed pattern matching results.

## Future Enhancements

Potential improvements:
- Pattern validation tool
- Pattern testing UI in web dashboard
- Pattern statistics and usage reporting
- Dynamic pattern reloading without restart
- Pattern versioning and migration support

## Made with Bob