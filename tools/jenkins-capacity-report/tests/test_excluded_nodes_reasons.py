#!/usr/bin/env python3
"""Test script for excluded nodes with reasons functionality."""

import sys
import os
import json
from pathlib import Path

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from excluded_nodes import ExcludedNodesManager


def test_excluded_nodes_with_reasons():
    """Test the excluded nodes manager with reasons."""
    
    # Use a test file
    test_file = "data/test_excluded_nodes.json"
    
    # Clean up any existing test file
    if Path(test_file).exists():
        Path(test_file).unlink()
    
    print("=" * 60)
    print("Testing Excluded Nodes with Reasons")
    print("=" * 60)
    
    # Create manager
    manager = ExcludedNodesManager(storage_file=test_file)
    
    # Test 1: Add node with reason
    print("\n1. Adding node 'test-node-1' with reason...")
    result = manager.add('test-node-1', 'Hardware failure')
    print(f"   Added: {result}")
    print(f"   Reason: {manager.get_reason('test-node-1')}")
    assert result == True
    assert manager.get_reason('test-node-1') == 'Hardware failure'
    
    # Test 2: Add node without reason
    print("\n2. Adding node 'test-node-2' without reason...")
    result = manager.add('test-node-2')
    print(f"   Added: {result}")
    print(f"   Reason: '{manager.get_reason('test-node-2')}'")
    assert result == True
    assert manager.get_reason('test-node-2') == ''
    
    # Test 3: Try to add duplicate node
    print("\n3. Trying to add duplicate node 'test-node-1'...")
    result = manager.add('test-node-1', 'Different reason')
    print(f"   Added: {result}")
    assert result == False
    
    # Test 4: Update reason for existing node
    print("\n4. Updating reason for 'test-node-2'...")
    result = manager.set_reason('test-node-2', 'Maintenance scheduled')
    print(f"   Updated: {result}")
    print(f"   New reason: {manager.get_reason('test-node-2')}")
    assert result == True
    assert manager.get_reason('test-node-2') == 'Maintenance scheduled'
    
    # Test 5: Get all nodes with reasons
    print("\n5. Getting all excluded nodes with reasons...")
    all_nodes = manager.get_all_with_reasons()
    print(f"   Nodes: {json.dumps(all_nodes, indent=2)}")
    assert len(all_nodes) == 2
    assert 'test-node-1' in all_nodes
    assert 'test-node-2' in all_nodes
    
    # Test 6: Remove node (should delete reason)
    print("\n6. Removing node 'test-node-1'...")
    result = manager.remove('test-node-1')
    print(f"   Removed: {result}")
    print(f"   Is excluded: {manager.is_excluded('test-node-1')}")
    print(f"   Reason: {manager.get_reason('test-node-1')}")
    assert result == True
    assert not manager.is_excluded('test-node-1')
    assert manager.get_reason('test-node-1') is None
    
    # Test 7: Try to set reason for non-excluded node
    print("\n7. Trying to set reason for non-excluded node...")
    result = manager.set_reason('test-node-1', 'Should fail')
    print(f"   Updated: {result}")
    assert result == False
    
    # Test 8: Verify persistence
    print("\n8. Testing persistence...")
    print("   Creating new manager instance...")
    manager2 = ExcludedNodesManager(storage_file=test_file)
    all_nodes2 = manager2.get_all_with_reasons()
    print(f"   Loaded nodes: {json.dumps(all_nodes2, indent=2)}")
    assert len(all_nodes2) == 1
    assert 'test-node-2' in all_nodes2
    assert all_nodes2['test-node-2'] == 'Maintenance scheduled'
    
    # Test 9: Clear all nodes
    print("\n9. Clearing all nodes...")
    count = manager2.clear()
    print(f"   Cleared count: {count}")
    print(f"   Remaining nodes: {manager2.get_all()}")
    assert count == 1
    assert len(manager2.get_all()) == 0
    assert len(manager2.get_all_with_reasons()) == 0
    
    # Clean up test file
    if Path(test_file).exists():
        Path(test_file).unlink()
    
    print("\n" + "=" * 60)
    print("✓ All tests passed!")
    print("=" * 60)


if __name__ == '__main__':
    try:
        test_excluded_nodes_with_reasons()
    except AssertionError as e:
        print(f"\n✗ Test failed: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

# Made with Bob
