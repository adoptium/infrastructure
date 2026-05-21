"""Module for managing excluded nodes list."""

import json
import logging
from pathlib import Path
from typing import Set, List, Dict, Optional
from threading import Lock

logger = logging.getLogger(__name__)


class ExcludedNodesManager:
    """Manages the list of excluded nodes with persistent storage and exclusion reasons."""
    
    def __init__(self, storage_file: str = "data/excluded_nodes.json"):
        """Initialize the excluded nodes manager.
        
        Args:
            storage_file: Path to the JSON file for storing excluded nodes
        """
        self.storage_file = Path(storage_file)
        self._lock = Lock()
        self._excluded_nodes: Set[str] = set()
        self._exclusion_reasons: Dict[str, str] = {}
        self._load()
    
    def _load(self):
        """Load excluded nodes from storage file."""
        try:
            if self.storage_file.exists():
                with open(self.storage_file, 'r') as f:
                    data = json.load(f)
                    # Support both old format (list) and new format (dict with reasons)
                    if isinstance(data.get('excluded_nodes'), list):
                        # Old format - just a list of node names
                        self._excluded_nodes = set(data.get('excluded_nodes', []))
                        self._exclusion_reasons = {}
                    else:
                        # New format - dict with reasons
                        nodes_data = data.get('excluded_nodes', {})
                        self._excluded_nodes = set(nodes_data.keys())
                        self._exclusion_reasons = nodes_data.copy()
                    logger.info(f"Loaded {len(self._excluded_nodes)} excluded nodes from {self.storage_file}")
            else:
                logger.info(f"No excluded nodes file found at {self.storage_file}, starting with empty list")
        except Exception as e:
            logger.error(f"Error loading excluded nodes: {e}")
            self._excluded_nodes = set()
            self._exclusion_reasons = {}
    
    def _save(self):
        """Save excluded nodes to storage file."""
        try:
            with open(self.storage_file, 'w') as f:
                json.dump({
                    'excluded_nodes': self._exclusion_reasons
                }, f, indent=2, sort_keys=True)
            logger.info(f"Saved {len(self._excluded_nodes)} excluded nodes to {self.storage_file}")
        except Exception as e:
            logger.error(f"Error saving excluded nodes: {e}")
    
    def add(self, node_name: str, reason: Optional[str] = None) -> bool:
        """Add a node to the excluded list.
        
        Args:
            node_name: Name of the node to exclude
            reason: Optional reason for exclusion
            
        Returns:
            True if node was added, False if already excluded
        """
        with self._lock:
            if node_name in self._excluded_nodes:
                return False
            self._excluded_nodes.add(node_name)
            self._exclusion_reasons[node_name] = reason or ""
            self._save()
            logger.info(f"Added node '{node_name}' to excluded list with reason: {reason}")
            return True
    
    def remove(self, node_name: str) -> bool:
        """Remove a node from the excluded list and delete its reason.
        
        Args:
            node_name: Name of the node to remove from exclusion
            
        Returns:
            True if node was removed, False if not in excluded list
        """
        with self._lock:
            if node_name not in self._excluded_nodes:
                return False
            self._excluded_nodes.remove(node_name)
            # Delete the reason when node is included
            if node_name in self._exclusion_reasons:
                del self._exclusion_reasons[node_name]
            self._save()
            logger.info(f"Removed node '{node_name}' from excluded list and deleted its reason")
            return True
    
    def set_reason(self, node_name: str, reason: str) -> bool:
        """Set or update the exclusion reason for a node.
        
        Args:
            node_name: Name of the excluded node
            reason: Reason for exclusion
            
        Returns:
            True if reason was set, False if node is not excluded
        """
        with self._lock:
            if node_name not in self._excluded_nodes:
                return False
            self._exclusion_reasons[node_name] = reason
            self._save()
            logger.info(f"Updated exclusion reason for node '{node_name}': {reason}")
            return True
    
    def get_reason(self, node_name: str) -> Optional[str]:
        """Get the exclusion reason for a node.
        
        Args:
            node_name: Name of the node
            
        Returns:
            The exclusion reason, or None if node is not excluded
        """
        with self._lock:
            return self._exclusion_reasons.get(node_name)
    
    def is_excluded(self, node_name: str) -> bool:
        """Check if a node is excluded.
        
        Args:
            node_name: Name of the node to check
            
        Returns:
            True if node is excluded, False otherwise
        """
        return node_name in self._excluded_nodes
    
    def get_all(self) -> List[str]:
        """Get all excluded node names.
        
        Returns:
            Sorted list of excluded node names
        """
        with self._lock:
            return sorted(list(self._excluded_nodes))
    
    def get_all_with_reasons(self) -> Dict[str, str]:
        """Get all excluded nodes with their reasons.
        
        Returns:
            Dictionary mapping node names to exclusion reasons
        """
        with self._lock:
            return self._exclusion_reasons.copy()
    
    def clear(self) -> int:
        """Clear all excluded nodes and their reasons.
        
        Returns:
            Number of nodes that were excluded
        """
        with self._lock:
            count = len(self._excluded_nodes)
            self._excluded_nodes.clear()
            self._exclusion_reasons.clear()
            self._save()
            logger.info(f"Cleared {count} nodes from excluded list")
            return count


# Global instance
_manager = None


def get_excluded_nodes_manager() -> ExcludedNodesManager:
    """Get the global excluded nodes manager instance."""
    global _manager
    if _manager is None:
        _manager = ExcludedNodesManager()
    return _manager

# Made with Bob
