"""Data models for Jenkins nodes and capacity information."""

from typing import List, Optional
from pydantic import BaseModel, Field


class NodeLabel(BaseModel):
    """Represents a label assigned to a Jenkins node."""
    name: str


class NodeExecutor(BaseModel):
    """Represents an executor on a Jenkins node."""
    number: int
    idle: bool
    current_executable: Optional[dict] = None


class JenkinsNode(BaseModel):
    """Represents a Jenkins node with its properties."""
    name: str = Field(..., description="Node display name")
    description: Optional[str] = Field(None, description="Node description")
    num_executors: int = Field(..., description="Number of executors on this node")
    labels: List[str] = Field(default_factory=list, description="Labels assigned to the node")
    offline: bool = Field(..., description="Whether the node is offline")
    offline_cause: Optional[str] = Field(None, description="Reason for being offline")
    idle: bool = Field(..., description="Whether the node is idle")
    temporarily_offline: bool = Field(..., description="Whether the node is temporarily offline")
    
    # Additional capacity metrics
    busy_executors: int = Field(0, description="Number of busy executors")
    idle_executors: int = Field(0, description="Number of idle executors")
    
    class Config:
        """Pydantic configuration."""
        json_schema_extra = {
            "example": {
                "name": "build-node-01",
                "description": "Ubuntu 22.04 build node",
                "num_executors": 4,
                "labels": ["linux", "ubuntu", "x64"],
                "offline": False,
                "offline_cause": None,
                "idle": False,
                "temporarily_offline": False,
                "busy_executors": 2,
                "idle_executors": 2
            }
        }


class CapacitySummary(BaseModel):
    """Summary of Jenkins capacity across all nodes."""
    total_nodes: int = Field(..., description="Total number of nodes")
    online_nodes: int = Field(..., description="Number of online nodes")
    offline_nodes: int = Field(..., description="Number of offline nodes")
    total_executors: int = Field(..., description="Total number of executors")
    busy_executors: int = Field(..., description="Number of busy executors")
    idle_executors: int = Field(..., description="Number of idle executors")
    utilization_percentage: float = Field(..., description="Percentage of executors in use")
    
    # Label-based grouping
    labels_summary: dict = Field(default_factory=dict, description="Capacity grouped by labels")
    
    class Config:
        """Pydantic configuration."""
        json_schema_extra = {
            "example": {
                "total_nodes": 10,
                "online_nodes": 8,
                "offline_nodes": 2,
                "total_executors": 40,
                "busy_executors": 25,
                "idle_executors": 15,
                "utilization_percentage": 62.5,
                "labels_summary": {
                    "linux": {"nodes": 5, "executors": 20, "busy": 12},
                    "windows": {"nodes": 3, "executors": 12, "busy": 8}
                }
            }
        }

# Made with Bob
