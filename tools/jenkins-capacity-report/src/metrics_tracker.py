"""Historical metrics tracking for Jenkins capacity data."""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
from threading import Lock
from collections import defaultdict

logger = logging.getLogger(__name__)


@dataclass
class MetricsSnapshot:
    """Represents a snapshot of Jenkins capacity metrics at a point in time."""
    timestamp: str
    total_nodes: int
    online_nodes: int
    offline_nodes: int
    excluded_nodes: int
    online_percentage: float
    offline_percentage: float
    total_executors: int
    busy_executors: int
    idle_executors: int
    utilization_percentage: float
    # Build nodes metrics
    build_nodes_total: int = 0
    build_nodes_online: int = 0
    build_nodes_offline: int = 0
    build_nodes_excluded: int = 0
    build_nodes_online_percentage: float = 0.0
    build_nodes_offline_percentage: float = 0.0
    # Test nodes metrics
    test_nodes_total: int = 0
    test_nodes_online: int = 0
    test_nodes_offline: int = 0
    test_nodes_excluded: int = 0
    test_nodes_online_percentage: float = 0.0
    test_nodes_offline_percentage: float = 0.0
    # Infrastructure nodes metrics
    infra_nodes_total: int = 0
    infra_nodes_online: int = 0
    infra_nodes_offline: int = 0
    infra_nodes_excluded: int = 0
    infra_nodes_online_percentage: float = 0.0
    infra_nodes_offline_percentage: float = 0.0
    # Docker host nodes metrics
    docker_host_nodes_total: int = 0
    docker_host_nodes_online: int = 0
    docker_host_nodes_offline: int = 0
    docker_host_nodes_excluded: int = 0
    docker_host_nodes_online_percentage: float = 0.0
    docker_host_nodes_offline_percentage: float = 0.0
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert snapshot to dictionary."""
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'MetricsSnapshot':
        """Create snapshot from dictionary."""
        # Handle old snapshots that don't have the new fields
        defaults = {
            'build_nodes_total': 0,
            'build_nodes_online': 0,
            'build_nodes_offline': 0,
            'build_nodes_excluded': 0,
            'build_nodes_online_percentage': 0.0,
            'build_nodes_offline_percentage': 0.0,
            'test_nodes_total': 0,
            'test_nodes_online': 0,
            'test_nodes_offline': 0,
            'test_nodes_excluded': 0,
            'test_nodes_online_percentage': 0.0,
            'test_nodes_offline_percentage': 0.0,
            'infra_nodes_total': 0,
            'infra_nodes_online': 0,
            'infra_nodes_offline': 0,
            'infra_nodes_excluded': 0,
            'infra_nodes_online_percentage': 0.0,
            'infra_nodes_offline_percentage': 0.0,
            'docker_host_nodes_total': 0,
            'docker_host_nodes_online': 0,
            'docker_host_nodes_offline': 0,
            'docker_host_nodes_excluded': 0,
            'docker_host_nodes_online_percentage': 0.0,
            'docker_host_nodes_offline_percentage': 0.0,
        }
        # Merge defaults with provided data
        merged_data = {**defaults, **data}
        return cls(**merged_data)


class MetricsTracker:
    """Manages historical metrics data storage and retrieval."""
    
    def __init__(self, data_file: str = "data/metrics_history.json"):
        """
        Initialize metrics tracker.
        
        Args:
            data_file: Path to the JSON file for storing metrics history
        """
        self.data_file = Path(data_file)
        self._lock = Lock()
        self._ensure_data_file()
    
    def _ensure_data_file(self):
        """Ensure the data file exists."""
        if not self.data_file.exists():
            self._write_data([])
            logger.info(f"Created new metrics history file: {self.data_file}")
    
    def _read_data(self) -> List[Dict[str, Any]]:
        """Read metrics data from file."""
        try:
            with open(self.data_file, 'r') as f:
                return json.load(f)
        except json.JSONDecodeError:
            logger.error(f"Failed to parse {self.data_file}, returning empty list")
            return []
        except Exception as e:
            logger.error(f"Error reading metrics data: {e}")
            return []
    
    def _write_data(self, data: List[Dict[str, Any]]):
        """Write metrics data to file."""
        try:
            with open(self.data_file, 'w') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            logger.error(f"Error writing metrics data: {e}")
            raise
    
    def record_snapshot(
        self,
        total_nodes: int,
        online_nodes: int,
        offline_nodes: int,
        excluded_nodes: int,
        total_executors: int,
        busy_executors: int,
        idle_executors: int,
        utilization_percentage: float,
        build_nodes_total: int = 0,
        build_nodes_online: int = 0,
        build_nodes_offline: int = 0,
        build_nodes_excluded: int = 0,
        test_nodes_total: int = 0,
        test_nodes_online: int = 0,
        test_nodes_offline: int = 0,
        test_nodes_excluded: int = 0,
        infra_nodes_total: int = 0,
        infra_nodes_online: int = 0,
        infra_nodes_offline: int = 0,
        infra_nodes_excluded: int = 0,
        docker_host_nodes_total: int = 0,
        docker_host_nodes_online: int = 0,
        docker_host_nodes_offline: int = 0,
        docker_host_nodes_excluded: int = 0
    ) -> MetricsSnapshot:
        """
        Record a new metrics snapshot.
        
        Args:
            total_nodes: Total number of nodes (excluding excluded nodes)
            online_nodes: Number of online nodes
            offline_nodes: Number of offline nodes
            excluded_nodes: Number of excluded nodes
            total_executors: Total number of executors
            busy_executors: Number of busy executors
            idle_executors: Number of idle executors
            utilization_percentage: Executor utilization percentage
            build_nodes_total: Total build nodes (excluding excluded)
            build_nodes_online: Online build nodes
            build_nodes_offline: Offline build nodes
            build_nodes_excluded: Excluded build nodes
            test_nodes_total: Total test nodes (excluding excluded)
            test_nodes_online: Online test nodes
            test_nodes_offline: Offline test nodes
            test_nodes_excluded: Excluded test nodes
            infra_nodes_total: Total infrastructure nodes (excluding excluded)
            infra_nodes_online: Online infrastructure nodes
            infra_nodes_offline: Offline infrastructure nodes
            infra_nodes_excluded: Excluded infrastructure nodes
            docker_host_nodes_total: Total docker host nodes (excluding excluded)
            docker_host_nodes_online: Online docker host nodes
            docker_host_nodes_offline: Offline docker host nodes
            docker_host_nodes_excluded: Excluded docker host nodes
            
        Returns:
            The created MetricsSnapshot
        """
        # Calculate overall percentages (excluding excluded nodes from the calculation)
        active_total = online_nodes + offline_nodes
        online_percentage = (online_nodes / active_total * 100) if active_total > 0 else 0.0
        offline_percentage = (offline_nodes / active_total * 100) if active_total > 0 else 0.0
        
        # Calculate build nodes percentages
        build_active_total = build_nodes_online + build_nodes_offline
        build_online_percentage = (build_nodes_online / build_active_total * 100) if build_active_total > 0 else 0.0
        build_offline_percentage = (build_nodes_offline / build_active_total * 100) if build_active_total > 0 else 0.0
        
        # Calculate test nodes percentages
        test_active_total = test_nodes_online + test_nodes_offline
        test_online_percentage = (test_nodes_online / test_active_total * 100) if test_active_total > 0 else 0.0
        test_offline_percentage = (test_nodes_offline / test_active_total * 100) if test_active_total > 0 else 0.0
        
        # Calculate infrastructure nodes percentages
        infra_active_total = infra_nodes_online + infra_nodes_offline
        infra_online_percentage = (infra_nodes_online / infra_active_total * 100) if infra_active_total > 0 else 0.0
        infra_offline_percentage = (infra_nodes_offline / infra_active_total * 100) if infra_active_total > 0 else 0.0
        
        # Calculate docker host nodes percentages
        docker_host_active_total = docker_host_nodes_online + docker_host_nodes_offline
        docker_host_online_percentage = (docker_host_nodes_online / docker_host_active_total * 100) if docker_host_active_total > 0 else 0.0
        docker_host_offline_percentage = (docker_host_nodes_offline / docker_host_active_total * 100) if docker_host_active_total > 0 else 0.0
        
        snapshot = MetricsSnapshot(
            timestamp=datetime.now().isoformat(),
            total_nodes=total_nodes,
            online_nodes=online_nodes,
            offline_nodes=offline_nodes,
            excluded_nodes=excluded_nodes,
            online_percentage=round(online_percentage, 2),
            offline_percentage=round(offline_percentage, 2),
            total_executors=total_executors,
            busy_executors=busy_executors,
            idle_executors=idle_executors,
            utilization_percentage=utilization_percentage,
            build_nodes_total=build_nodes_total,
            build_nodes_online=build_nodes_online,
            build_nodes_offline=build_nodes_offline,
            build_nodes_excluded=build_nodes_excluded,
            build_nodes_online_percentage=round(build_online_percentage, 2),
            build_nodes_offline_percentage=round(build_offline_percentage, 2),
            test_nodes_total=test_nodes_total,
            test_nodes_online=test_nodes_online,
            test_nodes_offline=test_nodes_offline,
            test_nodes_excluded=test_nodes_excluded,
            test_nodes_online_percentage=round(test_online_percentage, 2),
            test_nodes_offline_percentage=round(test_offline_percentage, 2),
            infra_nodes_total=infra_nodes_total,
            infra_nodes_online=infra_nodes_online,
            infra_nodes_offline=infra_nodes_offline,
            infra_nodes_excluded=infra_nodes_excluded,
            infra_nodes_online_percentage=round(infra_online_percentage, 2),
            infra_nodes_offline_percentage=round(infra_offline_percentage, 2),
            docker_host_nodes_total=docker_host_nodes_total,
            docker_host_nodes_online=docker_host_nodes_online,
            docker_host_nodes_offline=docker_host_nodes_offline,
            docker_host_nodes_excluded=docker_host_nodes_excluded,
            docker_host_nodes_online_percentage=round(docker_host_online_percentage, 2),
            docker_host_nodes_offline_percentage=round(docker_host_offline_percentage, 2)
        )
        
        with self._lock:
            data = self._read_data()
            data.append(snapshot.to_dict())
            self._write_data(data)
        
        logger.info(f"Recorded metrics snapshot at {snapshot.timestamp}")
        return snapshot
    
    def get_all_snapshots(self) -> List[MetricsSnapshot]:
        """
        Get all recorded metrics snapshots.
        
        Returns:
            List of MetricsSnapshot objects, ordered by timestamp (oldest first)
        """
        with self._lock:
            data = self._read_data()
        
        return [MetricsSnapshot.from_dict(item) for item in data]
    
    def get_recent_snapshots(self, limit: int = 100) -> List[MetricsSnapshot]:
        """
        Get the most recent metrics snapshots.
        
        Args:
            limit: Maximum number of snapshots to return
            
        Returns:
            List of MetricsSnapshot objects, ordered by timestamp (newest first)
        """
        snapshots = self.get_all_snapshots()
        return list(reversed(snapshots[-limit:]))
    
    def get_latest_snapshot(self) -> Optional[MetricsSnapshot]:
        """
        Get the most recent metrics snapshot.
        
        Returns:
            Latest MetricsSnapshot or None if no snapshots exist
        """
        snapshots = self.get_all_snapshots()
        return snapshots[-1] if snapshots else None
    
    def get_statistics(self) -> Dict[str, Any]:
        """
        Calculate statistics from all snapshots.
        
        Returns:
            Dictionary containing statistical information
        """
        snapshots = self.get_all_snapshots()
        
        if not snapshots:
            return {
                'total_snapshots': 0,
                'first_recorded': None,
                'last_recorded': None,
                'avg_online_percentage': 0.0,
                'avg_utilization': 0.0,
                'max_nodes': 0,
                'min_nodes': 0
            }
        
        return {
            'total_snapshots': len(snapshots),
            'first_recorded': snapshots[0].timestamp,
            'last_recorded': snapshots[-1].timestamp,
            'avg_online_percentage': round(
                sum(s.online_percentage for s in snapshots) / len(snapshots), 2
            ),
            'avg_utilization': round(
                sum(s.utilization_percentage for s in snapshots) / len(snapshots), 2
            ),
            'max_nodes': max(s.total_nodes for s in snapshots),
            'min_nodes': min(s.total_nodes for s in snapshots),
            'avg_online_nodes': round(
                sum(s.online_nodes for s in snapshots) / len(snapshots), 2
            ),
            'avg_offline_nodes': round(
                sum(s.offline_nodes for s in snapshots) / len(snapshots), 2
            )
        }
    
    def get_current_month_snapshots(self) -> List[MetricsSnapshot]:
        """
        Get snapshots for the current month only.
        
        Returns:
            List of MetricsSnapshot objects from current month
        """
        current_month = datetime.now().strftime("%Y-%m")
        all_snapshots = self.get_all_snapshots()
        
        current_month_snapshots = []
        for snapshot in all_snapshots:
            try:
                dt = datetime.fromisoformat(snapshot.timestamp.replace('Z', '+00:00'))
                snapshot_month = dt.strftime("%Y-%m")
                if snapshot_month == current_month:
                    current_month_snapshots.append(snapshot)
            except (ValueError, AttributeError):
                logger.warning(f"Failed to parse timestamp: {snapshot.timestamp}")
                continue
        
        return current_month_snapshots
    
    def archive_and_cleanup(self) -> Dict[str, Any]:
        """
        Archive completed months and clean up metrics_history.json.
        Only keeps current month's snapshots in the main file.
        
        Returns:
            Dictionary with archiving results
        """
        from src.archive_manager import get_archive_manager
        
        archive_manager = get_archive_manager()
        current_month = datetime.now().strftime("%Y-%m")
        
        with self._lock:
            all_data = self._read_data()
            
            # Group snapshots by month
            by_month = defaultdict(list)
            for snapshot_dict in all_data:
                try:
                    dt = datetime.fromisoformat(snapshot_dict['timestamp'].replace('Z', '+00:00'))
                    month = dt.strftime("%Y-%m")
                    by_month[month].append(snapshot_dict)
                except (ValueError, AttributeError, KeyError) as e:
                    logger.warning(f"Skipping invalid snapshot: {e}")
                    continue
            
            # Archive completed months (not current month)
            archived_months = []
            total_archived_snapshots = 0
            
            for month, snapshots in sorted(by_month.items()):
                if month < current_month:
                    try:
                        archive_manager.archive_month(month, snapshots)
                        archived_months.append(month)
                        total_archived_snapshots += len(snapshots)
                        logger.info(f"Archived {len(snapshots)} snapshots for {month}")
                    except Exception as e:
                        logger.error(f"Failed to archive {month}: {e}")
            
            # Keep only current month's snapshots
            current_month_data = by_month.get(current_month, [])
            self._write_data(current_month_data)
            
            logger.info(f"Archiving complete: {len(archived_months)} month(s), "
                       f"{total_archived_snapshots} snapshots archived, "
                       f"{len(current_month_data)} snapshots retained")
        
        return {
            'archived_months': archived_months,
            'snapshots_archived': total_archived_snapshots,
            'current_month_snapshots': len(current_month_data)
        }
    
    def get_archived_summary(self) -> List[Dict[str, Any]]:
        """
        Get summary of all archived months.
        
        Returns:
            List of MonthlyArchive dictionaries
        """
        from src.archive_manager import get_archive_manager
        
        archive_manager = get_archive_manager()
        archives = archive_manager.load_all_archives()
        
        return [archive.to_dict() for archive in archives]
    
    def clear_history(self) -> int:
        """
        Clear all metrics history.
        
        Returns:
            Number of snapshots cleared
        """
        with self._lock:
            data = self._read_data()
            count = len(data)
            self._write_data([])
        
        logger.info(f"Cleared {count} metrics snapshots")
        return count


# Singleton instance
_metrics_tracker_instance = None
_instance_lock = Lock()


def get_metrics_tracker(data_file: str = "data/metrics_history.json") -> MetricsTracker:
    """
    Get the singleton MetricsTracker instance.
    
    Args:
        data_file: Path to the JSON file for storing metrics history
        
    Returns:
        MetricsTracker instance
    """
    global _metrics_tracker_instance
    
    if _metrics_tracker_instance is None:
        with _instance_lock:
            if _metrics_tracker_instance is None:
                _metrics_tracker_instance = MetricsTracker(data_file)
    
    return _metrics_tracker_instance


# Made with Bob