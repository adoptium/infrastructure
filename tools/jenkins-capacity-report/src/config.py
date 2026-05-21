"""Configuration management for Jenkins Capacity Analyzer."""

import os
import logging
from typing import Optional
from dotenv import load_dotenv

# Set up logging
logger = logging.getLogger(__name__)

# Load environment variables from .env file
load_dotenv(override=True)
logger.info("Loaded .env file")


class Config:
    """Configuration class for Jenkins connection."""
    
    def __init__(
        self,
        jenkins_url: Optional[str] = None,
        username: Optional[str] = None,
        api_token: Optional[str] = None,
        cloud_config_file: Optional[str] = None,
        metrics_snapshot_interval: Optional[int] = None,
        metrics_auto_record: Optional[bool] = None,
        rbac_enabled: Optional[bool] = None,
        session_timeout_minutes: Optional[int] = None,
        flask_secret_key: Optional[str] = None,
        node_patterns_config: Optional[str] = None
    ):
        """
        Initialize configuration.
        
        Args:
            jenkins_url: Jenkins instance URL (overrides env var)
            username: Jenkins username (overrides env var)
            api_token: Jenkins API token (overrides env var)
            cloud_config_file: Path to clouds.xml file (overrides env var)
            metrics_snapshot_interval: Interval in minutes for automatic snapshots (overrides env var)
            metrics_auto_record: Enable/disable automatic snapshot recording (overrides env var)
            rbac_enabled: Enable/disable role-based access control (overrides env var)
            session_timeout_minutes: Session timeout in minutes (overrides env var)
            flask_secret_key: Flask secret key for sessions (overrides env var)
            node_patterns_config: Path to node patterns JSON file (overrides env var)
        """
        self.jenkins_url = jenkins_url or os.getenv("JENKINS_URL")
        self.username = username or os.getenv("JENKINS_USERNAME")
        self.api_token = api_token or os.getenv("JENKINS_API_TOKEN")
        self.cloud_config_file = cloud_config_file or os.getenv("CLOUD_CONFIG_FILE", "./data/clouds.xml.live")
        self.node_patterns_config = node_patterns_config or os.getenv("NODE_PATTERNS_CONFIG", "./config/node_patterns.json")
        logger.info(f"Config initialized with cloud_config_file: {self.cloud_config_file}")
        logger.info(f"Config initialized with node_patterns_config: {self.node_patterns_config}")
        
        # Metrics configuration
        self.metrics_snapshot_interval = metrics_snapshot_interval or int(os.getenv("METRICS_SNAPSHOT_INTERVAL", "60"))
        self.metrics_auto_record = metrics_auto_record if metrics_auto_record is not None else os.getenv("METRICS_AUTO_RECORD", "true").lower() == "true"
        
        # RBAC configuration
        self.rbac_enabled = rbac_enabled if rbac_enabled is not None else os.getenv("RBAC_ENABLED", "true").lower() == "true"
        self.session_timeout_minutes = session_timeout_minutes or int(os.getenv("SESSION_TIMEOUT_MINUTES", "480"))
        self.flask_secret_key = flask_secret_key or os.getenv("FLASK_SECRET_KEY", "change-this-secret-key-in-production")
        
        self._validate()
    
    def _validate(self):
        """Validate that all required configuration is present."""
        if not self.jenkins_url:
            raise ValueError("JENKINS_URL must be set in environment or passed to Config")
        if not self.username:
            raise ValueError("JENKINS_USERNAME must be set in environment or passed to Config")
        if not self.api_token:
            raise ValueError("JENKINS_API_TOKEN must be set in environment or passed to Config")
    
    @classmethod
    def from_env(cls) -> "Config":
        """
        Create configuration from environment variables.
        
        Returns:
            Config instance
        """
        return cls()

# Made with Bob
