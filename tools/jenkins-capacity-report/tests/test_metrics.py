#!/usr/bin/env python3
"""Test script for metrics tracking functionality."""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent))

from src.metrics_tracker import get_metrics_tracker


def test_metrics_tracker():
    """Test the metrics tracker functionality."""
    print("Testing Metrics Tracker...")
    print("-" * 50)
    
    # Get tracker instance
    tracker = get_metrics_tracker("data/test_metrics_history.json")
    
    # Clear any existing test data
    tracker.clear_history()
    print("✓ Cleared test history")
    
    # Record a test snapshot
    snapshot = tracker.record_snapshot(
        total_nodes=100,
        online_nodes=95,
        offline_nodes=5,
        excluded_nodes=10,
        total_executors=400,
        busy_executors=300,
        idle_executors=100,
        utilization_percentage=75.0
    )
    print(f"✓ Recorded snapshot: {snapshot.timestamp}")
    print(f"  - Total Nodes: {snapshot.total_nodes}")
    print(f"  - Online: {snapshot.online_nodes} ({snapshot.online_percentage}%)")
    print(f"  - Offline: {snapshot.offline_nodes} ({snapshot.offline_percentage}%)")
    print(f"  - Excluded: {snapshot.excluded_nodes}")
    print(f"  - Utilization: {snapshot.utilization_percentage}%")
    
    # Record another snapshot
    snapshot2 = tracker.record_snapshot(
        total_nodes=102,
        online_nodes=98,
        offline_nodes=4,
        excluded_nodes=10,
        total_executors=408,
        busy_executors=320,
        idle_executors=88,
        utilization_percentage=78.43
    )
    print(f"\n✓ Recorded second snapshot: {snapshot2.timestamp}")
    
    # Get all snapshots
    all_snapshots = tracker.get_all_snapshots()
    print(f"\n✓ Retrieved {len(all_snapshots)} snapshots")
    
    # Get recent snapshots
    recent = tracker.get_recent_snapshots(limit=10)
    print(f"✓ Retrieved {len(recent)} recent snapshots")
    
    # Get statistics
    stats = tracker.get_statistics()
    print(f"\n✓ Statistics:")
    print(f"  - Total Snapshots: {stats['total_snapshots']}")
    print(f"  - Avg Online %: {stats['avg_online_percentage']}%")
    print(f"  - Avg Utilization: {stats['avg_utilization']}%")
    print(f"  - Max Nodes: {stats['max_nodes']}")
    print(f"  - Min Nodes: {stats['min_nodes']}")
    
    # Get latest snapshot
    latest = tracker.get_latest_snapshot()
    if latest:
        print(f"\n✓ Latest snapshot timestamp: {latest.timestamp}")
    else:
        print("\n✗ No latest snapshot found")
    
    # Clean up test file
    Path("data/test_metrics_history.json").unlink(missing_ok=True)
    print("\n✓ Cleaned up test file")
    
    print("\n" + "=" * 50)
    print("All tests passed! ✓")
    print("=" * 50)


if __name__ == "__main__":
    try:
        test_metrics_tracker()
    except Exception as e:
        print(f"\n✗ Test failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

# Made with Bob
