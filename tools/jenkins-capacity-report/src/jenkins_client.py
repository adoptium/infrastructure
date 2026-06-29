"""Jenkins API client for extracting node and capacity data."""

import logging
from typing import List, Optional, Dict, Any
import requests
from requests.auth import HTTPBasicAuth

from .models import JenkinsNode, CapacitySummary

logger = logging.getLogger(__name__)


class JenkinsClient:
    """Client for interacting with Jenkins API."""
    
    def __init__(self, url: str, username: str, api_token: str):
        """
        Initialize Jenkins client.
        
        Args:
            url: Jenkins instance URL
            username: Jenkins username
            api_token: Jenkins API token
        """
        self.url = url.rstrip('/')
        self.auth = HTTPBasicAuth(username, api_token)
        self.session = requests.Session()
        self.session.auth = self.auth
        
    def _make_request(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Make a request to Jenkins API.
        
        Args:
            endpoint: API endpoint path
            params: Optional query parameters
            
        Returns:
            JSON response as dictionary
            
        Raises:
            requests.exceptions.RequestException: If request fails
        """
        url = f"{self.url}/{endpoint.lstrip('/')}"
        logger.debug(f"Making request to: {url}")
        
        try:
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Request failed: {e}")
            raise
    
    def get_computer_info(self) -> Dict[str, Any]:
        """
        Get information about all computers (nodes) in Jenkins.
        
        Returns:
            Dictionary containing computer information
        """
        # Use the computer API with tree parameter to get specific fields
        # Include monitorData to get Java version information
        tree_params = (
            "computer[displayName,description,numExecutors,idle,offline,"
            "temporarilyOffline,offlineCause[description],executors[idle,currentExecutable],"
            "assignedLabels[name],monitorData[*]]"
        )
        
        return self._make_request(
            "/computer/api/json",
            params={"tree": tree_params}
        )
    
    def _extract_java_version(self, monitor_data: Dict[str, Any]) -> Optional[str]:
        """
        Extract Java version from monitor data.
        
        Args:
            monitor_data: Monitor data from Jenkins API
            
        Returns:
            Java version string or None if not available
        """
        if not monitor_data:
            return None
        
        # Try different possible keys for Java version monitor
        # Note: hudson.plugin.versioncolumn.JVMVersionMonitor is from the Version Column Plugin
        possible_keys = [
            "hudson.plugin.versioncolumn.JVMVersionMonitor",  # Version Column Plugin (most common)
            "hudson.node_monitors.JVMVersionMonitor",
            "hudson.node_monitors.JavaVersionMonitor",
            "JVMVersionMonitor",
            "JavaVersionMonitor"
        ]
        
        for key in possible_keys:
            if key in monitor_data:
                version_data = monitor_data[key]
                # Handle different response formats
                if isinstance(version_data, dict):
                    # May have 'version' or 'value' key
                    version = version_data.get("version") or version_data.get("value")
                    if version:
                        return self._parse_java_version(str(version))
                elif isinstance(version_data, str):
                    # Direct string value (most common format)
                    return self._parse_java_version(version_data)
        
        return None
    
    def _parse_java_version(self, version_string: str) -> Optional[str]:
        """
        Parse and normalize Java version string.
        
        Args:
            version_string: Raw Java version string
            
        Returns:
            Normalized version string (e.g., "11", "17", "8") or None
        """
        if not version_string:
            return None
        
        # Extract major version from various formats:
        # "1.8.0_352" -> "8"
        # "11.0.16" -> "11"
        # "17.0.5+8" -> "17"
        # "OpenJDK 64-Bit Server VM (17.0.5+8)" -> "17"
        
        import re
        
        # Try to find version pattern
        # Match patterns like "1.8", "11.0", "17.0", etc.
        match = re.search(r'(\d+)\.(\d+)', version_string)
        if match:
            major = match.group(1)
            minor = match.group(2)
            
            # Handle old Java versioning (1.8 -> 8, 1.7 -> 7)
            if major == "1":
                return minor
            else:
                return major
        
        # Fallback: try to find any number at the start
        match = re.search(r'^(\d+)', version_string)
        if match:
            return match.group(1)
        
        # Return original if we can't parse it
        return version_string
    
    def parse_node_data(self, computer_data: Dict[str, Any]) -> JenkinsNode:
        """
        Parse raw computer data into a JenkinsNode model.
        
        Args:
            computer_data: Raw computer data from Jenkins API
            
        Returns:
            JenkinsNode instance
        """
        # Extract labels
        labels = [label["name"] for label in computer_data.get("assignedLabels", [])]
        
        # Calculate executor statistics
        executors = computer_data.get("executors", [])
        num_executors = computer_data.get("numExecutors", 0)
        busy_executors = sum(1 for ex in executors if not ex.get("idle", True))
        idle_executors = num_executors - busy_executors
        
        # Get offline cause if available
        offline_cause = None
        if computer_data.get("offlineCause"):
            offline_cause = computer_data["offlineCause"].get("description")
        
        # Extract Java version from monitor data
        java_version = self._extract_java_version(computer_data.get("monitorData", {}))
        
        return JenkinsNode(
            name=computer_data.get("displayName", ""),
            description=computer_data.get("description"),
            num_executors=num_executors,
            labels=labels,
            offline=computer_data.get("offline", False),
            offline_cause=offline_cause,
            idle=computer_data.get("idle", True),
            temporarily_offline=computer_data.get("temporarilyOffline", False),
            java_version=java_version,
            busy_executors=busy_executors,
            idle_executors=idle_executors
        )
    
    def get_all_nodes(self) -> List[JenkinsNode]:
        """
        Get all Jenkins nodes with their capacity information.
        
        Returns:
            List of JenkinsNode instances
        """
        logger.info("Fetching all Jenkins nodes...")
        computer_info = self.get_computer_info()
        
        nodes = []
        for computer in computer_info.get("computer", []):
            try:
                node = self.parse_node_data(computer)
                nodes.append(node)
                logger.debug(f"Parsed node: {node.name}")
            except Exception as e:
                logger.error(f"Failed to parse node data: {e}")
                continue
        
        logger.info(f"Successfully fetched {len(nodes)} nodes")
        return nodes
    
    def calculate_capacity_summary(self, nodes: List[JenkinsNode]) -> CapacitySummary:
        """
        Calculate capacity summary from list of nodes.
        
        Args:
            nodes: List of JenkinsNode instances
            
        Returns:
            CapacitySummary instance
        """
        total_nodes = len(nodes)
        online_nodes = sum(1 for node in nodes if not node.offline)
        offline_nodes = total_nodes - online_nodes
        
        total_executors = sum(node.num_executors for node in nodes)
        busy_executors = sum(node.busy_executors for node in nodes)
        idle_executors = sum(node.idle_executors for node in nodes)
        
        utilization_percentage = (busy_executors / total_executors * 100) if total_executors > 0 else 0.0
        
        # Calculate label-based summary
        labels_summary: Dict[str, Dict[str, int]] = {}
        for node in nodes:
            for label in node.labels:
                if label not in labels_summary:
                    labels_summary[label] = {
                        "nodes": 0,
                        "executors": 0,
                        "busy": 0,
                        "idle": 0,
                        "online_nodes": 0
                    }
                
                labels_summary[label]["nodes"] += 1
                labels_summary[label]["executors"] += node.num_executors
                labels_summary[label]["busy"] += node.busy_executors
                labels_summary[label]["idle"] += node.idle_executors
                if not node.offline:
                    labels_summary[label]["online_nodes"] += 1
        
        return CapacitySummary(
            total_nodes=total_nodes,
            online_nodes=online_nodes,
            offline_nodes=offline_nodes,
            total_executors=total_executors,
            busy_executors=busy_executors,
            idle_executors=idle_executors,
            utilization_percentage=round(utilization_percentage, 2),
            labels_summary=labels_summary
        )
    
    def get_capacity_report(self) -> tuple[List[JenkinsNode], CapacitySummary]:
        """
        Get complete capacity report including all nodes and summary.
        
        Returns:
            Tuple of (nodes list, capacity summary)
        """
        nodes = self.get_all_nodes()
        summary = self.calculate_capacity_summary(nodes)
        return nodes, summary

# Made with Bob
