"""Archive manager for monthly metrics rollup and storage."""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
from collections import defaultdict
from threading import Lock

logger = logging.getLogger(__name__)


@dataclass
class MonthlyArchive:
    """Complete monthly archive with comprehensive statistics."""
    month: str  # Format: "2026-04"
    start_date: str  # ISO format of first snapshot
    end_date: str  # ISO format of last snapshot
    snapshot_count: int
    
    # Overall Statistics - Complete Set
    avg_total_nodes: float
    min_total_nodes: int
    max_total_nodes: int
    avg_online_nodes: float
    avg_offline_nodes: float
    avg_excluded_nodes: float
    avg_online_percentage: float
    min_online_percentage: float
    max_online_percentage: float
    avg_offline_percentage: float
    
    # Executor Statistics
    avg_total_executors: float
    avg_busy_executors: float
    avg_idle_executors: float
    avg_utilization_percentage: float
    min_utilization_percentage: float
    max_utilization_percentage: float
    
    # Build Nodes - Complete Statistics
    build_nodes_avg_total: float
    build_nodes_avg_online: float
    build_nodes_avg_offline: float
    build_nodes_avg_excluded: float
    build_nodes_avg_online_percentage: float
    build_nodes_min_online_percentage: float
    build_nodes_max_online_percentage: float
    
    # Test Nodes - Complete Statistics
    test_nodes_avg_total: float
    test_nodes_avg_online: float
    test_nodes_avg_offline: float
    test_nodes_avg_excluded: float
    test_nodes_avg_online_percentage: float
    test_nodes_min_online_percentage: float
    test_nodes_max_online_percentage: float
    
    # Infrastructure Nodes - Complete Statistics
    infra_nodes_avg_total: float
    infra_nodes_avg_online: float
    infra_nodes_avg_offline: float
    infra_nodes_avg_excluded: float
    infra_nodes_avg_online_percentage: float
    infra_nodes_min_online_percentage: float
    infra_nodes_max_online_percentage: float
    
    # Docker Host Nodes - Complete Statistics
    docker_host_nodes_avg_total: float
    docker_host_nodes_avg_online: float
    docker_host_nodes_avg_offline: float
    docker_host_nodes_avg_excluded: float
    docker_host_nodes_avg_online_percentage: float
    docker_host_nodes_min_online_percentage: float
    docker_host_nodes_max_online_percentage: float
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert archive to dictionary."""
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'MonthlyArchive':
        """Create archive from dictionary."""
        return cls(**data)


class ArchiveManager:
    """Manages monthly metrics archiving and retrieval."""
    
    def __init__(self, archive_dir: str = "data/archive"):
        """
        Initialize archive manager.
        
        Args:
            archive_dir: Directory for storing archive files
        """
        self.archive_dir = Path(archive_dir)
        self._lock = Lock()
        self._ensure_archive_dir()
    
    def _ensure_archive_dir(self):
        """Ensure the archive directory exists."""
        self.archive_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"Archive directory ready: {self.archive_dir}")
    
    def get_archive_path(self, month: str) -> Path:
        """
        Get the path to an archive file for a specific month.
        
        Args:
            month: Month in YYYY-MM format
            
        Returns:
            Path to the archive file
        """
        return self.archive_dir / f"metrics_{month}.json"
    
    def get_month_from_timestamp(self, timestamp: str) -> str:
        """
        Extract month (YYYY-MM) from ISO timestamp.
        
        Args:
            timestamp: ISO format timestamp
            
        Returns:
            Month string in YYYY-MM format
        """
        try:
            dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            return dt.strftime("%Y-%m")
        except (ValueError, AttributeError) as e:
            logger.error(f"Failed to parse timestamp {timestamp}: {e}")
            return ""
    
    def calculate_monthly_summary(self, snapshots: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Calculate comprehensive statistics for a month of snapshots.
        Includes ALL metrics: averages, minimums, maximums for every field.
        
        Args:
            snapshots: List of snapshot dictionaries
            
        Returns:
            Dictionary with comprehensive statistics
        """
        if not snapshots:
            return {}
        
        n = len(snapshots)
        
        # Helper functions for safe calculations
        def safe_avg(values):
            return round(sum(values) / len(values), 2) if values else 0.0
        
        def safe_min(values):
            return round(min(values), 2) if values else 0.0
        
        def safe_max(values):
            return round(max(values), 2) if values else 0.0
        
        def safe_int_min(values):
            return min(values) if values else 0
        
        def safe_int_max(values):
            return max(values) if values else 0
        
        return {
            # Overall statistics
            'avg_total_nodes': safe_avg([s['total_nodes'] for s in snapshots]),
            'min_total_nodes': safe_int_min([s['total_nodes'] for s in snapshots]),
            'max_total_nodes': safe_int_max([s['total_nodes'] for s in snapshots]),
            'avg_online_nodes': safe_avg([s['online_nodes'] for s in snapshots]),
            'avg_offline_nodes': safe_avg([s['offline_nodes'] for s in snapshots]),
            'avg_excluded_nodes': safe_avg([s['excluded_nodes'] for s in snapshots]),
            'avg_online_percentage': safe_avg([s['online_percentage'] for s in snapshots]),
            'min_online_percentage': safe_min([s['online_percentage'] for s in snapshots]),
            'max_online_percentage': safe_max([s['online_percentage'] for s in snapshots]),
            'avg_offline_percentage': safe_avg([s['offline_percentage'] for s in snapshots]),
            
            # Executor statistics
            'avg_total_executors': safe_avg([s['total_executors'] for s in snapshots]),
            'avg_busy_executors': safe_avg([s['busy_executors'] for s in snapshots]),
            'avg_idle_executors': safe_avg([s['idle_executors'] for s in snapshots]),
            'avg_utilization_percentage': safe_avg([s['utilization_percentage'] for s in snapshots]),
            'min_utilization_percentage': safe_min([s['utilization_percentage'] for s in snapshots]),
            'max_utilization_percentage': safe_max([s['utilization_percentage'] for s in snapshots]),
            
            # Build nodes - complete stats
            'build_nodes_avg_total': safe_avg([s['build_nodes_total'] for s in snapshots]),
            'build_nodes_avg_online': safe_avg([s['build_nodes_online'] for s in snapshots]),
            'build_nodes_avg_offline': safe_avg([s['build_nodes_offline'] for s in snapshots]),
            'build_nodes_avg_excluded': safe_avg([s['build_nodes_excluded'] for s in snapshots]),
            'build_nodes_avg_online_percentage': safe_avg([s['build_nodes_online_percentage'] for s in snapshots]),
            'build_nodes_min_online_percentage': safe_min([s['build_nodes_online_percentage'] for s in snapshots]),
            'build_nodes_max_online_percentage': safe_max([s['build_nodes_online_percentage'] for s in snapshots]),
            
            # Test nodes - complete stats
            'test_nodes_avg_total': safe_avg([s['test_nodes_total'] for s in snapshots]),
            'test_nodes_avg_online': safe_avg([s['test_nodes_online'] for s in snapshots]),
            'test_nodes_avg_offline': safe_avg([s['test_nodes_offline'] for s in snapshots]),
            'test_nodes_avg_excluded': safe_avg([s['test_nodes_excluded'] for s in snapshots]),
            'test_nodes_avg_online_percentage': safe_avg([s['test_nodes_online_percentage'] for s in snapshots]),
            'test_nodes_min_online_percentage': safe_min([s['test_nodes_online_percentage'] for s in snapshots]),
            'test_nodes_max_online_percentage': safe_max([s['test_nodes_online_percentage'] for s in snapshots]),
            
            # Infrastructure nodes - complete stats
            'infra_nodes_avg_total': safe_avg([s['infra_nodes_total'] for s in snapshots]),
            'infra_nodes_avg_online': safe_avg([s['infra_nodes_online'] for s in snapshots]),
            'infra_nodes_avg_offline': safe_avg([s['infra_nodes_offline'] for s in snapshots]),
            'infra_nodes_avg_excluded': safe_avg([s['infra_nodes_excluded'] for s in snapshots]),
            'infra_nodes_avg_online_percentage': safe_avg([s['infra_nodes_online_percentage'] for s in snapshots]),
            'infra_nodes_min_online_percentage': safe_min([s['infra_nodes_online_percentage'] for s in snapshots]),
            'infra_nodes_max_online_percentage': safe_max([s['infra_nodes_online_percentage'] for s in snapshots]),
            
            # Docker host nodes - complete stats
            'docker_host_nodes_avg_total': safe_avg([s['docker_host_nodes_total'] for s in snapshots]),
            'docker_host_nodes_avg_online': safe_avg([s['docker_host_nodes_online'] for s in snapshots]),
            'docker_host_nodes_avg_offline': safe_avg([s['docker_host_nodes_offline'] for s in snapshots]),
            'docker_host_nodes_avg_excluded': safe_avg([s['docker_host_nodes_excluded'] for s in snapshots]),
            'docker_host_nodes_avg_online_percentage': safe_avg([s['docker_host_nodes_online_percentage'] for s in snapshots]),
            'docker_host_nodes_min_online_percentage': safe_min([s['docker_host_nodes_online_percentage'] for s in snapshots]),
            'docker_host_nodes_max_online_percentage': safe_max([s['docker_host_nodes_online_percentage'] for s in snapshots]),
        }
    
    def archive_month(self, month: str, snapshots: List[Dict[str, Any]]) -> MonthlyArchive:
        """
        Archive a month's worth of snapshots.
        
        Args:
            month: Month in YYYY-MM format
            snapshots: List of snapshot dictionaries for the month
            
        Returns:
            MonthlyArchive object
        """
        if not snapshots:
            raise ValueError(f"No snapshots provided for month {month}")
        
        # Sort snapshots by timestamp
        sorted_snapshots = sorted(snapshots, key=lambda s: s['timestamp'])
        
        # Calculate comprehensive statistics
        summary = self.calculate_monthly_summary(sorted_snapshots)
        
        # Create archive object
        archive = MonthlyArchive(
            month=month,
            start_date=sorted_snapshots[0]['timestamp'],
            end_date=sorted_snapshots[-1]['timestamp'],
            snapshot_count=len(sorted_snapshots),
            **summary
        )
        
        # Prepare archive file data
        archive_data = {
            'month': archive.month,
            'start_date': archive.start_date,
            'end_date': archive.end_date,
            'snapshot_count': archive.snapshot_count,
            'summary': summary,
            'snapshots': sorted_snapshots
        }
        
        # Write to archive file
        archive_path = self.get_archive_path(month)
        with self._lock:
            with open(archive_path, 'w') as f:
                json.dump(archive_data, f, indent=2)
        
        logger.info(f"Archived {len(sorted_snapshots)} snapshots for {month} to {archive_path}")
        return archive
    
    def load_archive(self, month: str) -> Optional[MonthlyArchive]:
        """
        Load an archived month.
        
        Args:
            month: Month in YYYY-MM format
            
        Returns:
            MonthlyArchive object or None if not found
        """
        archive_path = self.get_archive_path(month)
        
        if not archive_path.exists():
            return None
        
        try:
            with open(archive_path, 'r') as f:
                data = json.load(f)
            
            # Extract summary data for MonthlyArchive
            archive_dict = {
                'month': data['month'],
                'start_date': data['start_date'],
                'end_date': data['end_date'],
                'snapshot_count': data['snapshot_count'],
                **data['summary']
            }
            
            return MonthlyArchive.from_dict(archive_dict)
        except Exception as e:
            logger.error(f"Failed to load archive for {month}: {e}")
            return None
    
    def load_all_archives(self) -> List[MonthlyArchive]:
        """
        Load all archived months.
        
        Returns:
            List of MonthlyArchive objects, sorted by month (newest first)
        """
        archives = []
        
        # Find all archive files
        archive_files = sorted(self.archive_dir.glob("metrics_*.json"), reverse=True)
        
        for archive_file in archive_files:
            # Extract month from filename (metrics_2026-04.json -> 2026-04)
            month = archive_file.stem.replace('metrics_', '')
            archive = self.load_archive(month)
            if archive:
                archives.append(archive)
        
        return archives
    
    def get_archived_months(self) -> List[str]:
        """
        Get list of archived months.
        
        Returns:
            List of month strings in YYYY-MM format, sorted newest first
        """
        archive_files = sorted(self.archive_dir.glob("metrics_*.json"), reverse=True)
        return [f.stem.replace('metrics_', '') for f in archive_files]
    
    def archive_exists(self, month: str) -> bool:
        """
        Check if an archive exists for a specific month.
        
        Args:
            month: Month in YYYY-MM format
            
        Returns:
            True if archive exists, False otherwise
        """
        return self.get_archive_path(month).exists()


# Singleton instance
_archive_manager_instance = None
_instance_lock = Lock()


def get_archive_manager(archive_dir: str = "data/archive") -> ArchiveManager:
    """
    Get the singleton ArchiveManager instance.
    
    Args:
        archive_dir: Directory for storing archive files
        
    Returns:
        ArchiveManager instance
    """
    global _archive_manager_instance
    
    if _archive_manager_instance is None:
        with _instance_lock:
            if _archive_manager_instance is None:
                _archive_manager_instance = ArchiveManager(archive_dir)
    
    return _archive_manager_instance


# Made with Bob