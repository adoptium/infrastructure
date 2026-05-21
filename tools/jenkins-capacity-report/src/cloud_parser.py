#!/usr/bin/env python3
"""Parser for Jenkins clouds.xml configuration file."""

import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Dict, Optional
import logging

logger = logging.getLogger(__name__)


def _extract_architecture_from_name(name: str) -> str:
    """
    Extract and normalize architecture from template name (last element).
    
    Args:
        name: Template name (e.g., 'build-linux-x64', 'test-orka-macos14-arm64')
        
    Returns:
        Normalized architecture name
    """
    if not name:
        return 'unknown'
    
    parts = name.lower().split('-')
    if not parts:
        return 'unknown'
    
    # Get the last part as architecture
    arch_part = parts[-1]
    
    # Normalize architecture names to match Jenkins node architecture
    if arch_part in ['x64', 'x86_64', 'amd64']:
        return 'x64'
    elif arch_part in ['aarch64', 'arm64']:
        return 'aarch64'
    elif arch_part in ['aarch32', 'arm32', 'armv7l', 'armv7']:
        return 'aarch32'
    elif arch_part in ['ppc64', 'ppc64be']:
        return 'ppc64'
    elif arch_part in ['ppc64le']:
        return 'ppc64le'
    elif arch_part in ['s390x']:
        return 's390x'
    elif arch_part in ['riscv64', 'riscv']:
        return 'riscv64'
    elif arch_part in ['riscv32']:
        return 'riscv32'
    else:
        # If not a recognized architecture, return as-is
        return arch_part if arch_part else 'unknown'


def _get_os_type_from_string(os_string: str) -> str:
    """
    Determine the OS type from an OS string.
    
    Args:
        os_string: Operating system name or identifier
        
    Returns:
        OS type (windows, mac, linux, aix, solaris) or 'unknown'
    """
    if not os_string:
        return 'unknown'
    
    os_lower = os_string.lower()
    
    # Windows variants
    if 'win' in os_lower:
        return 'windows'
    
    # macOS variants
    if 'macos' in os_lower or 'mac' in os_lower or 'darwin' in os_lower:
        return 'mac'
    
    # Linux distributions and variants
    linux_keywords = [
        'ubuntu', 'rhel', 'centos', 'fedora', 'alpine',
        'debian', 'sles', 'opensuse', 'ubi', 'rocky',
        'alma', 'oracle', 'amazon', 'linux'
    ]
    if any(keyword in os_lower for keyword in linux_keywords):
        return 'linux'
    
    # AIX
    if 'aix' in os_lower:
        return 'aix'
    
    # Solaris
    if 'solaris' in os_lower or 'sunos' in os_lower:
        return 'solaris'
    
    return 'unknown'


class CloudTemplate:
    """Represents a cloud template configuration."""
    
    def __init__(self, name_prefix: str, category: str, image: Optional[str] = None,
                 num_executors: int = 1, label_string: Optional[str] = None, os_type: Optional[str] = None,
                 architecture: Optional[str] = None):
        self.name_prefix = name_prefix
        self.category = category  # First element of namePrefix (e.g., 'build', 'test')
        self.image = image or "N/A"
        self.num_executors = num_executors
        self.label_string = label_string or ""
        self.os_type = os_type or "unknown"
        self.architecture = architecture or "unknown"
    
    def __repr__(self):
        return f"CloudTemplate(prefix='{self.name_prefix}', category='{self.category}', image='{self.image}', executors={self.num_executors}, os_type='{self.os_type}', arch='{self.architecture}')"


class CloudConfig:
    """Represents a Jenkins cloud configuration."""
    
    def __init__(self, name: str, cloud_type: str, instance_cap: int, templates: Optional[list] = None):
        self.name = name
        self.cloud_type = cloud_type
        self.instance_cap = instance_cap
        self.templates = templates or []
    
    def __repr__(self):
        return f"CloudConfig(name='{self.name}', type='{self.cloud_type}', cap={self.instance_cap}, templates={len(self.templates)})"
    
    def get_template_count(self):
        """Get total number of templates."""
        return len(self.templates)
    
    def get_templates_by_category(self):
        """Get templates grouped by category (first element of namePrefix)."""
        categories = {}
        for template in self.templates:
            if template.category not in categories:
                categories[template.category] = 0
            categories[template.category] += 1
        return categories


def parse_clouds_xml(xml_path: str) -> List[CloudConfig]:
    """
    Parse Jenkins clouds.xml file and extract cloud configurations.
    
    Args:
        xml_path: Path to the clouds.xml file
        
    Returns:
        List of CloudConfig objects
    """
    clouds = []
    
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
        
        # Find all cloud elements (direct children of <clouds>)
        for cloud_elem in root:
            cloud_type = cloud_elem.tag.split('.')[-1]  # Get last part of class name
            
            # Extract cloud name
            name_elem = cloud_elem.find('name')
            if name_elem is None:
                logger.warning(f"Cloud element missing name: {cloud_elem.tag}")
                continue
            
            cloud_name = name_elem.text or "Unknown"
            
            # Extract templates
            templates = []
            templates_elem = cloud_elem.find('templates')
            if templates_elem is not None:
                # Find all template elements (can be different types)
                for template_elem in templates_elem:
                    name_prefix_elem = template_elem.find('namePrefix')
                    if name_prefix_elem is not None and name_prefix_elem.text:
                        name_prefix = name_prefix_elem.text
                        # Extract first element (category) from namePrefix
                        # e.g., "build-orka-macos14-arm64" -> "build"
                        parts = name_prefix.split('-')
                        category = parts[0] if parts else 'unknown'
                        
                        # Extract image name
                        image_elem = template_elem.find('image')
                        image = image_elem.text if image_elem is not None and image_elem.text else None
                        
                        # Extract number of executors
                        executors_elem = template_elem.find('numExecutors')
                        num_executors = 1
                        if executors_elem is not None and executors_elem.text:
                            try:
                                num_executors = int(executors_elem.text)
                            except ValueError:
                                logger.warning(f"Invalid numExecutors value: {executors_elem.text}")
                        
                        # Extract label string
                        label_elem = template_elem.find('labelString')
                        label_string = label_elem.text if label_elem is not None and label_elem.text else None
                        
                        # Also check for 'label' field (Kubernetes uses this)
                        if not label_string:
                            label_elem = template_elem.find('label')
                            label_string = label_elem.text if label_elem is not None and label_elem.text else None
                        
                        # Determine OS type from image name or name prefix
                        os_type = None
                        if image:
                            os_type = _get_os_type_from_string(image)
                        if os_type == 'unknown' and name_prefix:
                            os_type = _get_os_type_from_string(name_prefix)
                        
                        # Extract architecture from name prefix (last element)
                        architecture = _extract_architecture_from_name(name_prefix)
                        
                        templates.append(CloudTemplate(name_prefix, category, image, num_executors, label_string, os_type, architecture))
            
            # Also check for vmTemplates (Azure uses this)
            vm_templates_elem = cloud_elem.find('vmTemplates')
            if vm_templates_elem is not None:
                for template_elem in vm_templates_elem:
                    template_name_elem = template_elem.find('templateName')
                    if template_name_elem is not None and template_name_elem.text:
                        template_name = template_name_elem.text
                        # Extract first element (category) from template name
                        parts = template_name.split('-')
                        category = parts[0] if parts else 'unknown'
                        
                        # Extract image name - prioritize galleryImageDefinition over builtInImage
                        # galleryImageDefinition is nested inside imageReference
                        image = None
                        image_ref_elem = template_elem.find('imageReference')
                        if image_ref_elem is not None:
                            gallery_image_elem = image_ref_elem.find('galleryImageDefinition')
                            if gallery_image_elem is not None and gallery_image_elem.text:
                                image = gallery_image_elem.text
                        
                        # Fall back to builtInImage if no gallery image found
                        if not image:
                            image_elem = template_elem.find('builtInImage')
                            image = image_elem.text if image_elem is not None and image_elem.text else None
                        
                        # Extract number of executors (Azure uses noOfParallelJobs)
                        executors_elem = template_elem.find('noOfParallelJobs')
                        num_executors = 1
                        if executors_elem is not None and executors_elem.text:
                            try:
                                num_executors = int(executors_elem.text)
                            except ValueError:
                                logger.warning(f"Invalid noOfParallelJobs value: {executors_elem.text}")
                        
                        # Extract label string (Azure uses 'labels')
                        label_elem = template_elem.find('labels')
                        label_string = label_elem.text if label_elem is not None and label_elem.text else None
                        
                        # Extract OS type (Azure uses 'osType')
                        os_type_elem = template_elem.find('osType')
                        os_type = None
                        if os_type_elem is not None and os_type_elem.text:
                            os_type = _get_os_type_from_string(os_type_elem.text)
                        
                        # If osType not found, try to derive from image or template name
                        if not os_type or os_type == 'unknown':
                            if image:
                                os_type = _get_os_type_from_string(image)
                            if (not os_type or os_type == 'unknown') and template_name:
                                os_type = _get_os_type_from_string(template_name)
                        
                        # Extract architecture from template name (last element)
                        architecture = _extract_architecture_from_name(template_name)
                        
                        templates.append(CloudTemplate(template_name, category, image, num_executors, label_string, os_type, architecture))
            
            # Extract instance cap - different clouds use different fields
            instance_cap = None
            
            # Try instanceCap (used by Orka, Kubernetes, etc.)
            instance_cap_elem = cloud_elem.find('instanceCap')
            if instance_cap_elem is not None and instance_cap_elem.text:
                try:
                    instance_cap = int(instance_cap_elem.text)
                except ValueError:
                    logger.warning(f"Invalid instanceCap value for {cloud_name}: {instance_cap_elem.text}")
            
            # Try maxVirtualMachinesLimit (used by Azure)
            if instance_cap is None:
                max_vm_elem = cloud_elem.find('maxVirtualMachinesLimit')
                if max_vm_elem is not None and max_vm_elem.text:
                    try:
                        instance_cap = int(max_vm_elem.text)
                    except ValueError:
                        logger.warning(f"Invalid maxVirtualMachinesLimit for {cloud_name}: {max_vm_elem.text}")
            
            # Try containerCap (used by Docker)
            if instance_cap is None:
                container_cap_elem = cloud_elem.find('containerCap')
                if container_cap_elem is not None and container_cap_elem.text:
                    try:
                        instance_cap = int(container_cap_elem.text)
                    except ValueError:
                        logger.warning(f"Invalid containerCap for {cloud_name}: {container_cap_elem.text}")
            
            # Default to unlimited if no cap found
            if instance_cap is None:
                instance_cap = -1  # -1 represents unlimited
                logger.info(f"No instance cap found for {cloud_name}, setting to unlimited")
            
            # Handle max int value (2147483647) as unlimited
            if instance_cap == 2147483647:
                instance_cap = -1
            
            clouds.append(CloudConfig(
                name=cloud_name,
                cloud_type=cloud_type,
                instance_cap=instance_cap,
                templates=templates
            ))
            
            logger.debug(f"Parsed cloud: {cloud_name} ({cloud_type}) with cap {instance_cap}")
    
    except FileNotFoundError:
        logger.error(f"Clouds XML file not found: {xml_path}")
    except ET.ParseError as e:
        logger.error(f"Error parsing clouds XML: {e}")
    except Exception as e:
        logger.error(f"Unexpected error parsing clouds XML: {e}")
    
    return clouds


def get_cloud_summary(clouds: List[CloudConfig]) -> Dict:
    """
    Generate summary statistics for cloud configurations.
    
    Args:
        clouds: List of CloudConfig objects
        
    Returns:
        Dictionary with summary statistics
    """
    total_clouds = len(clouds)
    total_capacity = sum(c.instance_cap for c in clouds if c.instance_cap > 0)
    unlimited_clouds = sum(1 for c in clouds if c.instance_cap == -1)
    
    return {
        'total_clouds': total_clouds,
        'total_capacity': total_capacity,
        'unlimited_clouds': unlimited_clouds,
        'clouds': clouds
    }

# Made with Bob
