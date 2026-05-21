"""Node naming pattern matcher for extracting node metadata."""

import json
import re
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class NodeMetadata:
    """Metadata extracted from a node name."""
    provider: str
    function: str
    os: str
    architecture: str
    pattern_name: str
    is_dynamic: bool = False
    
    def __repr__(self):
        return f"NodeMetadata(provider='{self.provider}', function='{self.function}', os='{self.os}', arch='{self.architecture}', pattern='{self.pattern_name}', dynamic={self.is_dynamic})"


class NodePattern:
    """Represents a single node naming pattern."""
    
    def __init__(self, name: str, regex: str, priority: int, provider: str,
                 function: str, os: str, architecture: str, is_dynamic: bool = False,
                 description: str = ""):
        self.name = name
        self.regex_str = regex
        self.priority = priority
        self.provider_template = provider
        self.function_template = function
        self.os_template = os
        self.architecture_template = architecture
        self.is_dynamic = is_dynamic
        self.description = description
        
        # Compile regex for performance
        try:
            self.compiled_regex = re.compile(regex, re.IGNORECASE)
        except re.error as e:
            logger.error(f"Failed to compile regex for pattern '{name}': {e}")
            raise
    
    def match(self, node_name: str) -> Optional[Dict[str, str]]:
        """
        Try to match the node name against this pattern.
        
        Args:
            node_name: Name of the node to match
            
        Returns:
            Dictionary of matched groups if successful, None otherwise
        """
        match = self.compiled_regex.match(node_name)
        if match:
            return match.groupdict()
        return None
    
    def extract_metadata(self, node_name: str, groups: Dict[str, str]) -> NodeMetadata:
        """
        Extract metadata from matched groups using templates.
        
        Args:
            node_name: Original node name
            groups: Dictionary of matched regex groups
            
        Returns:
            NodeMetadata instance
        """
        def resolve_template(template: str, groups: Dict[str, str]) -> str:
            """Resolve a template string using matched groups."""
            if not template:
                return ""
            
            # If template contains {group_name}, substitute with matched value
            result = template
            for key, value in groups.items():
                placeholder = f"{{{key}}}"
                if placeholder in result:
                    result = result.replace(placeholder, value or "")
            
            return result
        
        provider = resolve_template(self.provider_template, groups)
        function = resolve_template(self.function_template, groups)
        os = resolve_template(self.os_template, groups)
        architecture = resolve_template(self.architecture_template, groups)
        
        return NodeMetadata(
            provider=provider,
            function=function,
            os=os,
            architecture=architecture,
            pattern_name=self.name,
            is_dynamic=self.is_dynamic
        )
    
    def __repr__(self):
        return f"NodePattern(name='{self.name}', priority={self.priority})"


class NodePatternMatcher:
    """Matches node names against configured patterns to extract metadata."""
    
    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize the pattern matcher.
        
        Args:
            config_path: Path to JSON configuration file. If None, uses default.
        """
        self.patterns: List[NodePattern] = []
        self.fallback: Dict[str, str] = {}
        
        if config_path is None:
            config_path = "./config/node_patterns.json"
        
        self.config_path = Path(config_path)
        self._load_patterns()
    
    def _load_patterns(self):
        """Load patterns from configuration file."""
        try:
            if not self.config_path.exists():
                logger.warning(f"Pattern config file not found: {self.config_path}")
                self._load_default_patterns()
                return
            
            with open(self.config_path, 'r') as f:
                config = json.load(f)
            
            # Load patterns
            patterns_data = config.get('patterns', [])
            for pattern_data in patterns_data:
                try:
                    pattern = NodePattern(
                        name=pattern_data['name'],
                        regex=pattern_data['regex'],
                        priority=pattern_data.get('priority', 100),
                        provider=pattern_data.get('provider', 'other'),
                        function=pattern_data.get('function', 'other'),
                        os=pattern_data.get('os', ''),
                        architecture=pattern_data.get('architecture', ''),
                        is_dynamic=pattern_data.get('is_dynamic', False),
                        description=pattern_data.get('description', '')
                    )
                    self.patterns.append(pattern)
                except (KeyError, re.error) as e:
                    logger.error(f"Failed to load pattern '{pattern_data.get('name', 'unknown')}': {e}")
                    continue
            
            # Sort patterns by priority (lower number = higher priority)
            self.patterns.sort(key=lambda p: p.priority)
            
            # Load fallback
            self.fallback = config.get('fallback', {
                'provider': 'other',
                'function': 'other',
                'os': 'unknown',
                'architecture': 'unknown'
            })
            
            logger.info(f"Loaded {len(self.patterns)} node naming patterns from {self.config_path}")
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse pattern config file: {e}")
            self._load_default_patterns()
        except Exception as e:
            logger.error(f"Unexpected error loading patterns: {e}")
            self._load_default_patterns()
    
    def _load_default_patterns(self):
        """Load minimal default patterns as fallback."""
        logger.info("Loading default patterns")
        
        # Standard 5-part pattern
        self.patterns.append(NodePattern(
            name="standard_5part",
            regex=r"^(?P<function>build|test|dockerhost|infra)-(?P<provider>[a-z0-9]+)-(?P<os>[a-z0-9]+)-(?P<arch>[a-z0-9]+)-(?P<num>\d+)$",
            priority=10,
            provider="{provider}",
            function="{function}",
            os="{os}",
            architecture="{arch}",
            description="Standard 5-part naming pattern"
        ))
        
        self.fallback = {
            'provider': 'other',
            'function': 'other',
            'os': 'unknown',
            'architecture': 'unknown'
        }
    
    def match(self, node_name: str) -> NodeMetadata:
        """
        Match a node name against all patterns and extract metadata.
        
        Args:
            node_name: Name of the node to match
            
        Returns:
            NodeMetadata instance with extracted information
        """
        # Try each pattern in priority order
        for pattern in self.patterns:
            groups = pattern.match(node_name)
            if groups is not None:
                metadata = pattern.extract_metadata(node_name, groups)
                logger.debug(f"Matched '{node_name}' with pattern '{pattern.name}': {metadata}")
                return metadata
        
        # No pattern matched, use fallback
        logger.debug(f"No pattern matched for '{node_name}', using fallback")
        return NodeMetadata(
            provider=self.fallback.get('provider', 'other'),
            function=self.fallback.get('function', 'other'),
            os=self.fallback.get('os', 'unknown'),
            architecture=self.fallback.get('architecture', 'unknown'),
            pattern_name='fallback'
        )
    
    def get_provider(self, node_name: str) -> str:
        """Extract provider from node name."""
        return self.match(node_name).provider
    
    def get_function(self, node_name: str) -> str:
        """Extract function from node name."""
        return self.match(node_name).function
    
    def get_os(self, node_name: str) -> str:
        """Extract OS from node name."""
        return self.match(node_name).os
    
    def get_architecture(self, node_name: str) -> str:
        """Extract architecture from node name."""
        return self.match(node_name).architecture
    
    def list_patterns(self) -> List[Tuple[str, int, str]]:
        """
        Get list of loaded patterns.
        
        Returns:
            List of tuples (name, priority, description)
        """
        return [(p.name, p.priority, p.description) for p in self.patterns]


# Global instance for easy access
_pattern_matcher: Optional[NodePatternMatcher] = None


def get_pattern_matcher(config_path: Optional[str] = None) -> NodePatternMatcher:
    """
    Get or create the global NodePatternMatcher instance.
    
    Args:
        config_path: Path to configuration file (only used on first call)
        
    Returns:
        NodePatternMatcher instance
    """
    global _pattern_matcher
    if _pattern_matcher is None:
        _pattern_matcher = NodePatternMatcher(config_path)
    return _pattern_matcher


# Made with Bob