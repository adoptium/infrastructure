# Dynamic Nodes Categorization Implementation Plan

## Overview

This document outlines the plan to add a "Dynamic Nodes" category that groups dynamically provisioned nodes (Azure, Orka, GitHub Actions) with subcategories for build and test functions.

## Current State

### Existing Categories
1. **Static Docker Nodes** - Docker container nodes
2. **Infrastructure Nodes** - Controller, service, and infrastructure nodes
3. **Build Nodes** - Static build nodes (e.g., `build-azure-win11-x64-1`)
4. **Test Nodes** - Static test nodes (e.g., `test-azure-win11-x64-1`)
5. **Docker Host Nodes** - Physical/virtual machines hosting Docker
6. **Other Nodes** - Unmatched nodes

### Dynamic Node Patterns (to be grouped)
- **Azure Dynamic**: `build-linux-x64-21bf53`, `test-windows-x64-abc123`
- **Orka Dynamic**: `build-orka-macos14-arm64`, `test-orka-macos15-x64`
- **GitHub Actions**: `gha-macos15-x64`, `gha-ubuntu2404-x64-f9c5bdcd`

## Proposed Changes

### 1. Add `is_dynamic` Field to NodeMetadata

**File**: `jenkins-capacity-report/src/node_pattern_matcher.py`

Add a new field to the `NodeMetadata` dataclass:

```python
@dataclass
class NodeMetadata:
    """Metadata extracted from a node name."""
    provider: str
    function: str
    os: str
    architecture: str
    pattern_name: str
    is_dynamic: bool = False  # NEW FIELD
```

### 2. Update Pattern Configuration

**File**: `jenkins-capacity-report/config/node_patterns.json`

Add `"is_dynamic": true` to the following patterns:
- `azure_dynamic` (priority 1)
- `orka_dynamic` (priority 2)
- `gha_dynamic` (priority 3)

Example:
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

### 3. Update NodePattern Class

**File**: `jenkins-capacity-report/src/node_pattern_matcher.py`

Modify the `NodePattern` class to handle the `is_dynamic` field:

```python
class NodePattern:
    def __init__(self, name: str, regex: str, priority: int, provider: str,
                 function: str, os: str, architecture: str, 
                 is_dynamic: bool = False, description: str = ""):
        # ... existing code ...
        self.is_dynamic = is_dynamic
    
    def extract_metadata(self, node_name: str, groups: Dict[str, str]) -> NodeMetadata:
        # ... existing code ...
        return NodeMetadata(
            provider=provider,
            function=function,
            os=os,
            architecture=architecture,
            pattern_name=self.name,
            is_dynamic=self.is_dynamic  # NEW
        )
```

### 4. Update get_node_category() Function

**File**: `jenkins-capacity-report/main.py`

Modify to return "Dynamic Nodes" for dynamic providers:

```python
def get_node_category(node_name):
    """
    Determine the category of a node based on its name using pattern matcher.
    """
    matcher = get_pattern_matcher()
    metadata = matcher.match(node_name)
    function = metadata.function
    provider = metadata.provider
    is_dynamic = metadata.is_dynamic
    
    # Check if this is a dynamic node first
    if is_dynamic:
        return 'Dynamic Nodes'
    
    # Map function to category for static nodes
    if provider == 'docker':
        return 'Static Docker Nodes'
    elif function == 'build':
        return 'Build Nodes'
    elif function == 'test':
        return 'Test Nodes'
    # ... rest of existing logic ...
```

### 5. Update categorize_nodes_by_function_and_provider()

**File**: `jenkins-capacity-report/main.py`

Modify to handle dynamic nodes with build/test subcategories:

```python
def categorize_nodes_by_function_and_provider(nodes):
    """
    Categorize nodes by their function, OS type, architecture, and specific OS.
    For dynamic nodes, create subcategories by function (build/test).
    """
    categories = {}
    
    for node in nodes:
        name = node.name.lower()
        matcher = get_pattern_matcher()
        metadata = matcher.match(node.name)
        
        provider = metadata.provider
        function = metadata.function
        is_dynamic = metadata.is_dynamic
        
        node_os = extract_os_from_name(node.name)
        node_os_type = get_os_type(node_os) if node_os else 'unknown'
        node_arch = get_node_architecture(node)
        
        # Determine category
        if is_dynamic:
            category = 'Dynamic Nodes'
            # Store function as subcategory for dynamic nodes
            subcategory = f"{function.capitalize()} Function"
        else:
            # ... existing static node logic ...
            category = determine_static_category(name, provider)
            subcategory = None
        
        # Initialize category structure with subcategory support
        if category not in categories:
            categories[category] = {
                'total': 0,
                'online': 0,
                'offline': 0,
                'subcategories': {} if is_dynamic else None,
                'os_types': {} if not is_dynamic else None
            }
        
        # Handle dynamic nodes with subcategories
        if is_dynamic and subcategory:
            if subcategory not in categories[category]['subcategories']:
                categories[category]['subcategories'][subcategory] = {
                    'total': 0,
                    'online': 0,
                    'offline': 0,
                    'os_types': {}
                }
            # Update subcategory counts and os_types...
        else:
            # Handle static nodes as before...
```

### 6. Update print_node_details()

**File**: `jenkins-capacity-report/main.py`

Update the category order and display logic:

```python
def print_node_details(nodes):
    # Define category order
    category_order = [
        'Dynamic Nodes',        # NEW - placed first
        'Static Docker Nodes',
        'Infrastructure Nodes',
        'Build Nodes',
        'Test Nodes',
        'Docker Host Nodes',
        'Other Nodes'
    ]
    
    # ... existing code ...
    
    # Special handling for Dynamic Nodes category
    if category == 'Dynamic Nodes':
        # Group by function (build/test) then by provider
        for function in ['build', 'test']:
            function_nodes = [n for n in category_nodes 
                            if get_pattern_matcher().match(n.name).function == function]
            if function_nodes:
                print(f"\n  {function.capitalize()} Function ({len(function_nodes)} nodes)")
                # Group by provider within function
                # ... display logic ...
```

### 7. Update Tests

**File**: `jenkins-capacity-report/tests/test_node_patterns.py`

Add test cases to verify dynamic node categorization:

```python
def test_dynamic_node_categorization():
    """Test that dynamic nodes are properly categorized."""
    matcher = NodePatternMatcher("./config/node_patterns.json")
    
    # Test Azure dynamic nodes
    metadata = matcher.match("build-linux-x64-21bf53")
    assert metadata.is_dynamic == True
    assert metadata.provider == "azure"
    assert metadata.function == "build"
    
    # Test Orka dynamic nodes
    metadata = matcher.match("test-orka-macos14-arm64")
    assert metadata.is_dynamic == True
    assert metadata.provider == "orka"
    assert metadata.function == "test"
    
    # Test GitHub Actions nodes
    metadata = matcher.match("gha-macos15-x64-f9c5bdcd")
    assert metadata.is_dynamic == True
    assert metadata.provider == "github-actions"
    assert metadata.function == "test"
    
    # Test static nodes are NOT dynamic
    metadata = matcher.match("test-azure-win11-x64-1")
    assert metadata.is_dynamic == False
```

### 8. Update Documentation

**File**: `jenkins-capacity-report/docs/NODE-NAMING-PATTERNS.md`

Add section explaining dynamic node categorization:

```markdown
## Dynamic Nodes

Dynamic nodes are automatically provisioned and deprovisioned nodes from cloud providers. They are grouped into a single "Dynamic Nodes" category with subcategories by function (build/test).

### Dynamic Providers
- **Azure**: `build-linux-x64-21bf53`, `test-windows-x64-abc123`
- **Orka**: `build-orka-macos14-arm64`, `test-orka-macos15-x64`
- **GitHub Actions**: `gha-macos15-x64`, `gha-ubuntu2404-x64-f9c5bdcd`

### Categorization
Dynamic nodes are displayed separately from static nodes:
- **Dynamic Nodes**
  - Build Function
    - Azure: build-linux-x64-21bf53, ...
    - Orka: build-orka-macos14-arm64, ...
  - Test Function
    - GitHub Actions: gha-macos15-x64-f9c5bdcd, ...
    - Orka: test-orka-macos15-x64, ...
```

## Implementation Order

1. ✅ Update `NodeMetadata` dataclass with `is_dynamic` field
2. ✅ Update `NodePattern` class to handle `is_dynamic`
3. ✅ Update `node_patterns.json` configuration
4. ✅ Modify `get_node_category()` function
5. ✅ Update `categorize_nodes_by_function_and_provider()`
6. ✅ Update `print_node_details()` display logic
7. ✅ Add tests for dynamic categorization
8. ✅ Update documentation

## Testing Strategy

1. Run existing tests to ensure no regression
2. Add new tests for dynamic node identification
3. Test with sample data containing mix of static and dynamic nodes
4. Verify report output shows correct categorization
5. Verify CSV export includes correct categories

## Rollback Plan

If issues arise:
1. The `is_dynamic` field defaults to `False`, so existing behavior is preserved
2. Configuration changes are isolated to `node_patterns.json`
3. Can revert by removing `is_dynamic` fields from config
4. Code changes are backward compatible

## Made with Bob