# Node Naming Pattern Configuration

This document describes the configuration-based node naming pattern system used to extract metadata (provider, function, OS, architecture) from Jenkins node names.

## Overview

The Jenkins Capacity Analyzer uses a flexible, regex-based pattern matching system to parse node names and extract relevant metadata. This allows the system to handle various naming conventions including:

- **Standard static nodes** with 5-part naming (e.g., `test-azure-win11-x64-1`)
- **Azure dynamic nodes** with 4-part naming (e.g., `build-linux-x64-21bf53`)
- **Orka dynamic nodes** with provider in name (e.g., `test-orka-macos14-arm64`)
- **GitHub Actions nodes** with special prefix (e.g., `gha-macos15-x64`)

## Node Categories

The system categorizes nodes into the following groups based on their function:

- **Dynamic Nodes**: Automatically provisioned/deprovisioned nodes from cloud providers (Azure, Orka, GitHub Actions)
  - Subcategorized by function: Build Function and Test Function
- **Static Docker Nodes**: Docker container nodes (provider=docker)
- **Infrastructure Nodes**: Controller nodes (Built-In Node, master), service nodes (jenkins-*, eclipse-*, trss-*, worker*), and infrastructure nodes (infra-*)
- **Build Nodes**: Static nodes used for building software (build-*)
- **Test Nodes**: Static nodes used for testing (test-*)
- **Docker Host Nodes**: Physical/virtual machines hosting Docker containers (dockerhost-*)
- **Other Nodes**: Nodes that don't match any pattern

**Note**:
- Controller, service, and infrastructure nodes are all consolidated into the "Infrastructure Nodes" category for reporting purposes.
- Dynamic nodes are grouped separately from static build/test nodes and are further organized by their function (build or test).

## Configuration File

The node naming patterns are defined in `config/node_patterns.json`. This file contains:

1. **patterns**: Array of pattern definitions (processed in priority order)
2. **fallback**: Default values when no pattern matches

### Pattern Definition Structure

Each pattern in the configuration has the following fields:

```json
{
  "name": "pattern_identifier",
  "regex": "^regex_pattern_with_named_groups$",
  "priority": 1,
  "provider": "provider_name_or_{group}",
  "function": "function_name_or_{group}",
  "os": "{group}",
  "architecture": "{group}",
  "description": "Human-readable description"
}
```

**Fields:**

- **name**: Unique identifier for the pattern
- **regex**: Regular expression with named capture groups (e.g., `(?P<function>build|test)`)
- **priority**: Lower numbers = higher priority (patterns are tried in priority order)
- **provider**: Static value or template using `{group_name}` to extract from regex
- **function**: Static value or template using `{group_name}` to extract from regex
- **os**: Template using `{group_name}` to extract from regex
- **architecture**: Template using `{group_name}` to extract from regex
- **description**: Documentation for the pattern

### Template Substitution

Templates use `{group_name}` syntax to reference named groups from the regex:

- `{function}` - Replaced with the value captured by `(?P<function>...)`
- `{provider}` - Replaced with the value captured by `(?P<provider>...)`
- `{os}` - Replaced with the value captured by `(?P<os>...)`
- `{arch}` - Replaced with the value captured by `(?P<arch>...)`

Static values (no curly braces) are used as-is without substitution.

## Supported Patterns

### 1. Azure Dynamic Nodes (Priority 1) 🔄

**Pattern:** `build-linux-x64-21bf53`, `test-windows-x64-abc123`

**Format:** `function-os-arch-uniqueid`

**Regex:** `^(?P<function>build|test)-(?P<os>linux|windows|macos\d*)-(?P<arch>x64|aarch64|arm64)-(?P<uid>[a-z0-9]{6})$`

**Extraction:**
- Provider: `azure` (static)
- Function: `{function}` (build or test)
- OS: `{os}` (linux, windows, macos)
- Architecture: `{arch}` (x64, aarch64, arm64)
- **Is Dynamic:** `true`

**Category:** Dynamic Nodes → Build Function or Test Function

### 2. Orka Dynamic Nodes (Priority 2) 🔄

**Pattern:** `build-orka-macos14-arm64`, `test-orka-macos15-x64`

**Format:** `function-orka-os-arch`

**Regex:** `^(?P<function>build|test)-orka-(?P<os>macos\d+)-(?P<arch>x64|arm64|aarch64)$`

**Extraction:**
- Provider: `orka` (static)
- Function: `{function}` (build or test)
- OS: `{os}` (macos14, macos15, etc.)
- Architecture: `{arch}` (x64, arm64, aarch64)
- **Is Dynamic:** `true`

**Category:** Dynamic Nodes → Build Function or Test Function

### 3. GitHub Actions Dynamic Nodes (Priority 3) 🔄

**Pattern:** `gha-macos15-x64`, `gha-ubuntu2404-x64`, `gha-macos15-x64-f9c5bdcd`

**Format:** `gha-os-arch` or `gha-os-arch-uniqueid`

**Regex:** `^gha-(?P<os>macos\d+|ubuntu\d+|windows)-(?P<arch>x64|arm64|aarch64)(?:-(?P<uid>[a-z0-9]+))?$`

**Extraction:**
- Provider: `github-actions` (static)
- Function: `test` (static, GHA nodes are test nodes)
- OS: `{os}` (macos15, ubuntu2404, windows)
- Architecture: `{arch}` (x64, arm64, aarch64)
- UID: `{uid}` (optional unique identifier)
- **Is Dynamic:** `true`

**Category:** Dynamic Nodes → Test Function

### 4. Docker Static Nodes (Priority 5)

**Pattern:** `test-docker-ubuntu2404-x64-1`, `build-docker-alpine320-x64-2`

**Format:** `function-docker-os-arch-number`

**Regex:** `^(?P<function>build|test)-docker-(?P<os>[a-z0-9]+)-(?P<arch>[a-z0-9]+)-(?P<num>\d+)$`

**Extraction:**
- Provider: `docker` (static)
- Function: `{function}` (build or test)
- OS: `{os}` (ubuntu2404, alpine320, etc.)
- Architecture: `{arch}` (x64, aarch64, etc.)

### 5. Standard 5-Part Nodes (Priority 10)

**Pattern:** `test-azure-win11-x64-1`, `build-osuosl-aix72-ppc64-1`

**Format:** `function-provider-os-arch-number`

**Regex:** `^(?P<function>build|test|dockerhost|infra)-(?P<provider>[a-z0-9]+)-(?P<os>[a-z0-9]+)-(?P<arch>[a-z0-9]+)-(?P<num>\d+)$`

**Extraction:**
- Provider: `{provider}` (azure, osuosl, macincloud, etc.)
- Function: `{function}` (build, test, dockerhost, infra)
- OS: `{os}` (win11, aix72, ubuntu2404, etc.)
- Architecture: `{arch}` (x64, ppc64, aarch64, etc.)

### 6. Controller Nodes (Priority 0)

**Pattern:** `Built-In Node`, `master`

**Regex:** `^(Built-In Node|master)$`

**Extraction:**
- Provider: `controller` (static)
- Function: `infrastructure` (static - controller treated as infrastructure)
- OS: empty
- Architecture: `x64` (static - configurable for future changes)

**Note:** The Jenkins controller/master node is treated as infrastructure with linux OS and x64 architecture. These values can be changed in the configuration file if your controller runs on a different OS or architecture.

## Default Values for Special Nodes

Some node types have default OS and architecture values that can be customized in the configuration:

### Controller/Master Nodes
- **Default OS**: `linux`
- **Default Architecture**: `x64`
- **Configurable**: Yes, edit `controller_builtin` pattern in `config/node_patterns.json`

### Service Nodes
- **Default OS**: `linux`
- **Default Architecture**: `x64`
- **Configurable**: Yes, edit `service_nodes` pattern in `config/node_patterns.json`
- **Applies to**: `jenkins-*`, `worker*`, `eclipse-*`, `trss-*` nodes

These defaults ensure all nodes have valid OS and architecture values for reporting purposes.

## Environment Configuration

Add to your `.env` file:

```bash
# Node Naming Pattern Configuration
# Path to JSON file containing node naming patterns
NODE_PATTERNS_CONFIG=./config/node_patterns.json
```

## Usage in Code

### Using the Pattern Matcher

```python
from src.node_pattern_matcher import get_pattern_matcher

# Get the global pattern matcher instance
matcher = get_pattern_matcher()

# Match a node name and get all metadata
metadata = matcher.match("build-linux-x64-21bf53")
print(f"Provider: {metadata.provider}")      # azure
print(f"Function: {metadata.function}")      # build
print(f"OS: {metadata.os}")                  # linux
print(f"Architecture: {metadata.architecture}")  # x64

# Or extract individual components
provider = matcher.get_provider("test-orka-macos14-arm64")  # orka
function = matcher.get_function("gha-macos15-x64")          # test
os = matcher.get_os("test-azure-win11-x64-1")               # win11
arch = matcher.get_architecture("build-osuosl-aix72-ppc64-1")  # ppc64
```

### Using Helper Functions

The existing helper functions in `main.py` now use the pattern matcher internally:

```python
from main import (
    extract_provider_from_name,
    extract_os_from_name,
    extract_architecture_from_name,
    get_node_category
)

provider = extract_provider_from_name("build-linux-x64-21bf53")  # azure
os = extract_os_from_name("test-orka-macos14-arm64")             # macos14
arch = extract_architecture_from_name("gha-ubuntu2404-x64")      # x64
category = get_node_category("test-azure-win11-x64-1")           # Test Nodes
```

## Adding New Patterns

To add support for a new node naming pattern:

1. Edit `config/node_patterns.json`
2. Add a new pattern object to the `patterns` array
3. Set an appropriate priority (lower = higher priority)
4. Define the regex with named capture groups
5. Specify how to extract provider, function, OS, and architecture
6. Add a description for documentation
7. Test with sample node names

Example:

```json
{
  "name": "my_custom_pattern",
  "regex": "^custom-(?P<function>build|test)-(?P<os>[a-z0-9]+)-(?P<arch>[a-z0-9]+)$",
  "priority": 4,
  "provider": "my-provider",
  "function": "{function}",
  "os": "{os}",
  "architecture": "{arch}",
  "description": "Custom node naming pattern"
}
```

## Testing

Run the pattern matching tests:

```bash
cd jenkins-capacity-report
python tests/test_node_patterns.py
```

This will test all configured patterns against sample node names and report any failures.

## Troubleshooting

### Pattern Not Matching

1. Check regex syntax - use a regex tester like regex101.com
2. Verify named groups are correctly defined: `(?P<name>...)`
3. Ensure priority is set correctly (lower numbers tried first)
4. Check that the regex is case-insensitive (patterns use `re.IGNORECASE`)

### Wrong Metadata Extracted

1. Verify template substitution syntax: `{group_name}`
2. Check that group names in templates match regex named groups
3. Ensure static values don't have curly braces

### Fallback Being Used

If nodes are matching the fallback pattern instead of a specific pattern:

1. Check that the pattern's regex matches the node name
2. Verify the pattern priority is lower than competing patterns
3. Test the regex independently to ensure it works

## Architecture Normalization

The system automatically normalizes architecture names for consistency:

- `x64`, `x86_64`, `amd64` → `x64`
- `arm64`, `aarch64` → `aarch64`
- `arm32`, `aarch32`, `armv7l`, `armv7` → `aarch32`
- `ppc64`, `ppc64be` → `ppc64`
- `riscv`, `riscv64` → `riscv64`

This ensures consistent reporting regardless of the naming convention used in node names.

## Made with Bob

## Dynamic Nodes

Dynamic nodes are automatically provisioned and deprovisioned nodes from cloud providers. They are identified by the `is_dynamic` flag in their pattern configuration and are grouped into a separate "Dynamic Nodes" category with subcategories by function (build/test).

### What Makes a Node Dynamic?

A node is considered dynamic if:
1. Its pattern in `node_patterns.json` has `"is_dynamic": true`
2. It matches one of the dynamic provider patterns (Azure, Orka, GitHub Actions)
3. It is automatically provisioned/deprovisioned by the cloud provider

### Dynamic Providers

The following providers are configured as dynamic:

#### Azure Dynamic Nodes
- **Pattern:** `build-linux-x64-21bf53`, `test-windows-x64-abc123`
- **Format:** `function-os-arch-uniqueid`
- **Functions:** build, test
- **Unique ID:** 6-character alphanumeric identifier

#### Orka Dynamic Nodes
- **Pattern:** `build-orka-macos14-arm64`, `test-orka-macos15-x64`
- **Format:** `function-orka-os-arch`
- **Functions:** build, test
- **Provider:** Orka (macOS virtualization)

#### GitHub Actions Nodes
- **Pattern:** `gha-macos15-x64`, `gha-macos15-x64-f9c5bdcd`
- **Format:** `gha-os-arch[-uniqueid]`
- **Functions:** test (all GHA nodes are test nodes)
- **Unique ID:** Optional alphanumeric identifier

### Categorization Hierarchy

Dynamic nodes are displayed in reports with the following hierarchy:

```
Dynamic Nodes (total count)
├── Build Function (build nodes count)
│   ├── Provider: AZURE (count)
│   │   ├── build-linux-x64-21bf53
│   │   └── build-windows-x64-abc123
│   └── Provider: ORKA (count)
│       └── build-orka-macos14-arm64
└── Test Function (test nodes count)
    ├── Provider: AZURE (count)
    │   └── test-linux-x64-xyz789
    ├── Provider: GITHUB-ACTIONS (count)
    │   ├── gha-macos15-x64
    │   └── gha-macos15-x64-f9c5bdcd
    └── Provider: ORKA (count)
        └── test-orka-macos15-x64
```

### Static vs Dynamic Nodes

**Static Nodes:**
- Permanently provisioned infrastructure
- Named with provider in the name: `test-azure-win11-x64-1`
- Categorized as "Build Nodes", "Test Nodes", etc.
- Typically have a number suffix indicating instance

**Dynamic Nodes:**
- Automatically provisioned on-demand
- Named with unique identifiers: `build-linux-x64-21bf53`
- Categorized as "Dynamic Nodes" with function subcategories
- May be ephemeral (short-lived)

### Configuration

To mark a pattern as dynamic, add `"is_dynamic": true` to the pattern definition in `config/node_patterns.json`:

```json
{
  "name": "azure_dynamic",
  "regex": "^(?P<function>build|test)-(?P<os>linux|windows|macos\\d*)-(?P<arch>x64|aarch64|arm64)-(?P<uid>[a-z0-9]{6})$",
  "priority": 1,
  "provider": "azure",
  "function": "{function}",
  "os": "{os}",
  "architecture": "{arch}",
  "is_dynamic": true,
  "description": "Azure dynamically provisioned nodes"
}
```

### Testing

Run the dynamic node categorization tests:

```bash
cd jenkins-capacity-report
python tests/test_node_patterns.py
```

The test suite includes:
- Pattern matching for dynamic nodes
- `is_dynamic` flag verification
- Category assignment validation
- Function subcategory verification

### Benefits of Dynamic Node Categorization

1. **Clear Separation**: Distinguishes between static infrastructure and dynamic capacity
2. **Function Visibility**: Shows build vs test capacity separately for dynamic nodes
3. **Provider Tracking**: Identifies which cloud providers are being used for dynamic capacity
4. **Capacity Planning**: Helps understand dynamic vs static resource allocation
5. **Cost Analysis**: Enables tracking of cloud-provisioned resources separately
