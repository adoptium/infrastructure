"""Tests for node pattern matching."""

import sys
import os
from pathlib import Path

# Add parent directory to path to import modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.node_pattern_matcher import NodePatternMatcher
from main import get_node_category


def test_node_patterns():
    """Test node pattern matching with various node name formats."""
    
    # Initialize pattern matcher
    matcher = NodePatternMatcher("./config/node_patterns.json")
    
    # Test cases: (node_name, expected_provider, expected_function, expected_os, expected_arch)
    test_cases = [
        # New Azure dynamic nodes (build-azure-<os>-<arch>-<hex>)
        ("build-azure-linux-x64-df7db0", "azure", "build", "linux", "x64"),
        ("test-azure-linux-aarch64-3f9a1c", "azure", "test", "linux", "aarch64"),
        ("build-azure-windows-x64-a1b2c3", "azure", "build", "windows", "x64"),
        ("test-azure-windows-x64-fe9023", "azure", "test", "windows", "x64"),

        # Legacy Azure dynamic nodes (build-<os>-<arch>-<hex>) — kept for backward compat
        ("build-linux-x64-21bf53", "azure", "build", "linux", "x64"),
        ("test-linux-x64-abc123", "azure", "test", "linux", "x64"),
        ("test-windows-x64-xyz789", "azure", "test", "windows", "x64"),
        ("build-linux-aarch64-def456", "azure", "build", "linux", "aarch64"),
        
        # Orka dynamic nodes
        ("build-orka-macos14-arm64", "orka", "build", "macos14", "aarch64"),
        ("test-orka-macos14-arm64", "orka", "test", "macos14", "aarch64"),
        ("test-orka-macos15-x64", "orka", "test", "macos15", "x64"),
        ("test-orka-macos15-arm64", "orka", "test", "macos15", "aarch64"),
        
        # GitHub Actions dynamic nodes
        ("gha-macos15-x64", "github-actions", "test", "macos15", "x64"),
        ("gha-macos15-x64-f9c5bdcd", "github-actions", "test", "macos15", "x64"),
        ("gha-ubuntu2404-x64", "github-actions", "test", "ubuntu2404", "x64"),
        ("gha-windows-x64", "github-actions", "test", "windows", "x64"),
        
        # Standard 5-part nodes
        ("test-azure-win11-x64-1", "azure", "test", "win11", "x64"),
        ("build-osuosl-aix72-ppc64-1", "osuosl", "build", "aix72", "ppc64"),
        ("test-docker-ubuntu2404-x64-1", "docker", "test", "ubuntu2404", "x64"),
        ("build-macincloud-macos14-arm64-1", "macincloud", "build", "macos14", "aarch64"),
        
        # Docker host nodes
        ("dockerhost-azure-ubuntu2204-x64-1", "azure", "dockerhost", "ubuntu2204", "x64"),
        ("dockerhost-azure-win2022-x64-1-amd", "azure", "dockerhost", "win2022", "x64"),
        ("dockerhost-azure-win2022-x64-2-amd", "azure", "dockerhost", "win2022", "x64"),
        ("dockerhost-azure-win2022-x64-3-intel", "azure", "dockerhost", "win2022", "x64"),
        
        # Infrastructure nodes
        ("infra-azure-ubuntu2204-x64-1", "azure", "infrastructure", "ubuntu2204", "x64"),
        ("infra-ibmcloud-vagrant-x64-1-jenkins", "ibmcloud", "infrastructure", "vagrant", "x64"),
        ("infra-ibmcloud-vagrant-x64-1-vagrant1", "ibmcloud", "infrastructure", "vagrant", "x64"),
        ("infra-ibmcloud-vagrant-x64-1-vagrant2", "ibmcloud", "infrastructure", "vagrant", "x64"),
        
        # Docker nodes with host suffix
        ("test-docker-rhel7-s390x-RH8host", "docker", "test", "rhel7", "s390x"),
        
        # Nodes with multi-part suffix (armv7l will be normalized to aarch32 by extract_architecture_from_name)
        ("test-sxa-ubuntu2004-armv7l-odroid-2", "sxa", "test", "ubuntu2004", "armv7l"),
        
        # Controller nodes (treated as infrastructure with linux/x64)
        ("Built-In Node", "controller", "infrastructure", "linux", "x64"),
        ("master", "controller", "infrastructure", "linux", "x64"),
        
        # Service nodes (default to linux/x64)
        ("jenkins-hetzner-worker", "service", "service", "linux", "x64"),
        ("eclipse-codesign-machine", "service", "service", "linux", "x64"),
        ("trss-node", "service", "service", "linux", "x64"),
    ]
    
    print("\n" + "="*100)
    print("NODE PATTERN MATCHING TESTS")
    print("="*100)
    print(f"{'Node Name':<40} {'Provider':<18} {'Function':<15} {'OS':<15} {'Arch':<10} {'Status':<10}")
    print("-"*100)
    
    passed = 0
    failed = 0
    
    for node_name, exp_provider, exp_function, exp_os, exp_arch in test_cases:
        metadata = matcher.match(node_name)
        
        # Normalize architecture for comparison
        actual_arch = metadata.architecture
        if actual_arch == 'arm64':
            actual_arch = 'aarch64'
        
        # Check if all fields match
        provider_match = metadata.provider == exp_provider
        function_match = metadata.function == exp_function
        os_match = metadata.os == exp_os
        arch_match = actual_arch == exp_arch
        
        all_match = provider_match and function_match and os_match and arch_match
        status = "✓ PASS" if all_match else "✗ FAIL"
        
        if all_match:
            passed += 1
        else:
            failed += 1
        
        print(f"{node_name:<40} {metadata.provider:<18} {metadata.function:<15} {metadata.os:<15} {actual_arch:<10} {status:<10}")
        
        if not all_match:
            print(f"  Expected: provider={exp_provider}, function={exp_function}, os={exp_os}, arch={exp_arch}")
            print(f"  Got:      provider={metadata.provider}, function={metadata.function}, os={metadata.os}, arch={actual_arch}")
    
    print("-"*100)
    print(f"Results: {passed} passed, {failed} failed out of {len(test_cases)} tests")
    print("="*100 + "\n")
    
    # Print loaded patterns
    print("\nLoaded Patterns:")
    print("-"*100)
    for name, priority, description in matcher.list_patterns():
        print(f"  [{priority:2d}] {name:<20} - {description}")
    print()
    
    return failed == 0


def test_dynamic_node_categorization():
    """Test that dynamic nodes are properly identified and categorized."""
    
    print("\n" + "="*100)
    print("DYNAMIC NODE CATEGORIZATION TESTS")
    print("="*100)
    
    matcher = NodePatternMatcher("./config/node_patterns.json")
    
    # Test cases: (node_name, expected_is_dynamic, expected_provider, expected_function, expected_category)
    test_cases = [
        # New Azure dynamic nodes
        ("build-azure-linux-x64-df7db0", True, "azure", "build", "Dynamic Nodes"),
        ("test-azure-linux-aarch64-3f9a1c", True, "azure", "test", "Dynamic Nodes"),
        ("build-azure-windows-x64-a1b2c3", True, "azure", "build", "Dynamic Nodes"),
        ("test-azure-windows-x64-fe9023", True, "azure", "test", "Dynamic Nodes"),

        # Legacy Azure dynamic nodes
        ("build-linux-x64-21bf53", True, "azure", "build", "Dynamic Nodes"),
        ("test-linux-x64-abc123", True, "azure", "test", "Dynamic Nodes"),
        ("test-windows-x64-xyz789", True, "azure", "test", "Dynamic Nodes"),
        
        # Orka dynamic nodes
        ("build-orka-macos14-arm64", True, "orka", "build", "Dynamic Nodes"),
        ("test-orka-macos14-arm64", True, "orka", "test", "Dynamic Nodes"),
        ("test-orka-macos15-x64", True, "orka", "test", "Dynamic Nodes"),
        
        # GitHub Actions dynamic nodes
        ("gha-macos15-x64", True, "github-actions", "test", "Dynamic Nodes"),
        ("gha-macos15-x64-f9c5bdcd", True, "github-actions", "test", "Dynamic Nodes"),
        ("gha-ubuntu2404-x64", True, "github-actions", "test", "Dynamic Nodes"),
        
        # Static nodes should NOT be dynamic
        ("test-azure-win11-x64-1", False, "azure", "test", "Test Nodes"),
        ("build-osuosl-aix72-ppc64-1", False, "osuosl", "build", "Build Nodes"),
        ("test-docker-ubuntu2404-x64-1", False, "docker", "test", "Static Docker Nodes"),
        ("dockerhost-azure-ubuntu2204-x64-1", False, "azure", "dockerhost", "Docker Host Nodes"),
    ]
    
    print(f"{'Node Name':<40} {'Is Dynamic':<12} {'Provider':<18} {'Function':<12} {'Category':<20} {'Status':<10}")
    print("-"*100)
    
    passed = 0
    failed = 0
    
    for node_name, exp_is_dynamic, exp_provider, exp_function, exp_category in test_cases:
        metadata = matcher.match(node_name)
        category = get_node_category(node_name)
        
        # Check if all fields match
        is_dynamic_match = metadata.is_dynamic == exp_is_dynamic
        provider_match = metadata.provider == exp_provider
        function_match = metadata.function == exp_function
        category_match = category == exp_category
        
        all_match = is_dynamic_match and provider_match and function_match and category_match
        status = "✓ PASS" if all_match else "✗ FAIL"
        
        if all_match:
            passed += 1
        else:
            failed += 1
        
        is_dynamic_str = "Yes" if metadata.is_dynamic else "No"
        print(f"{node_name:<40} {is_dynamic_str:<12} {metadata.provider:<18} {metadata.function:<12} {category:<20} {status:<10}")
        
        if not all_match:
            print(f"  Expected: is_dynamic={exp_is_dynamic}, provider={exp_provider}, function={exp_function}, category={exp_category}")
            print(f"  Got:      is_dynamic={metadata.is_dynamic}, provider={metadata.provider}, function={metadata.function}, category={category}")
    
    print("-"*100)
    print(f"Results: {passed} passed, {failed} failed out of {len(test_cases)} tests")
    print("="*100 + "\n")
    
    return failed == 0


if __name__ == "__main__":
    success1 = test_node_patterns()
    success2 = test_dynamic_node_categorization()
    sys.exit(0 if (success1 and success2) else 1)

# Made with Bob
