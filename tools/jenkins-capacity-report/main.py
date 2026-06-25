#!/usr/bin/env python3
"""Main entry point for Jenkins Capacity Analyzer."""

import logging
import json
import csv
import sys
from datetime import datetime
from pathlib import Path

from src.config import Config
from src.jenkins_client import JenkinsClient
from src.cloud_parser import parse_clouds_xml
from src.node_pattern_matcher import get_pattern_matcher

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('logs/jenkins_capacity.log')
    ]
)

logger = logging.getLogger(__name__)


def save_to_json(data: dict, filename: str):
    """
    Save data to JSON file.
    
    Args:
        data: Data to save
        filename: Output filename
    """
    output_path = Path(filename)
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2, default=str)
    logger.info(f"Data saved to {output_path}")


def extract_os_from_name(node_name):
    """
    Extract operating system from node name using pattern matcher.
    
    Args:
        node_name: Name of the node
        
    Returns:
        Operating system name or empty string
    
    Examples:
        test-docker-ubuntu2404-x64-1 -> ubuntu2404
        test-azure-win11-x64-1 -> win11
        build-osuosl-aix72-ppc64-1 -> aix72
        build-linux-x64-21bf53 -> linux (Azure dynamic)
        test-orka-macos14-arm64 -> macos14 (Orka dynamic)
    """
    matcher = get_pattern_matcher()
    os_name = matcher.get_os(node_name)
    
    return os_name if os_name else ''


def get_os_type(node_os):
    """
    Determine the OS type from the OS name.
    
    Args:
        node_os: Operating system name
        
    Returns:
        OS type (windows, mac, linux, aix, solaris) or 'UNKNOWN: <os_name>' for undefined types
    """
    if not node_os:
        return 'unknown'
    
    os_lower = node_os.lower()
    
    # Windows variants
    if os_lower.startswith('win'):
        return 'windows'
    
    # macOS variants
    if os_lower.startswith('macos'):
        return 'mac'
    
    # Generic linux (for dynamic nodes that just specify "linux")
    if os_lower == 'linux':
        return 'linux'
    
    # Linux distributions and variants
    linux_distros = [
        'ubuntu', 'rhel', 'centos', 'fedora', 'alpine',
        'debian', 'sles', 'opensuse', 'ubi', 'rocky',
        'alma', 'oracle', 'amazon', 'armv7l', 'armv8', 'vagrant'
    ]
    if any(os_lower.startswith(distro) for distro in linux_distros):
        return 'linux'
    
    # AIX
    if os_lower.startswith('aix'):
        return 'aix'
    
    # Solaris
    if os_lower.startswith('solaris'):
        return 'solaris'
    
    # Special cases for infrastructure/service nodes
    if os_lower in ['machine', 'worker']:
        return 'UNKNOWN: ' + node_os
    
    # If we can't classify it, return UNKNOWN with the OS name
    return f'UNKNOWN: {node_os}'


def extract_architecture_from_name(node_name):
    """
    Extract architecture from node name using pattern matcher.
    
    Args:
        node_name: Name of the node
        
    Returns:
        Architecture name or empty string
    
    Examples:
        test-docker-ubuntu2404-x64-1 -> x64
        build-osuosl-aix72-ppc64-1 -> ppc64
        test-azure-rhel8-aarch64-1 -> aarch64
        build-linux-x64-21bf53 -> x64 (Azure dynamic)
        test-orka-macos14-arm64 -> aarch64 (Orka dynamic)
    """
    matcher = get_pattern_matcher()
    arch = matcher.get_architecture(node_name)
    
    # Normalize architecture names for consistency
    if arch in ['x64', 'x86_64', 'amd64']:
        return 'x64'
    elif arch in ['aarch64', 'arm64']:
        return 'aarch64'
    elif arch in ['aarch32', 'arm32', 'armv7l', 'armv7']:
        return 'aarch32'
    elif arch in ['ppc64', 'ppc64be']:
        return 'ppc64'
    elif arch in ['ppc64le']:
        return 'ppc64le'
    elif arch in ['s390x']:
        return 's390x'
    elif arch in ['riscv64', 'riscv']:
        return 'riscv64'
    elif arch in ['riscv32']:
        return 'riscv32'
    
    return arch if arch else ''


def extract_architecture_from_labels(node):
    """
    Extract architecture from node labels.
    Looks for labels starting with 'hw.arch.' or direct architecture labels.
    
    Args:
        node: JenkinsNode instance
        
    Returns:
        Architecture name or empty string
    """
    # First check for hw.arch.xxx labels
    for label in node.labels:
        if label.startswith('hw.arch.'):
            # Extract the architecture after 'hw.arch.'
            # e.g., 'hw.arch.x86' -> 'x86', 'hw.arch.aarch64' -> 'aarch64'
            arch = label.replace('hw.arch.', '')
            
            # Normalize architecture names
            if arch in ['x86', 'x86_64', 'amd64']:
                return 'x64'
            elif arch in ['aarch64', 'arm64']:
                return 'aarch64'
            elif arch in ['aarch32', 'arm32']:
                return 'aarch32'
            elif arch in ['ppc64', 'ppc64be']:
                return 'ppc64'
            elif arch in ['ppc64le']:
                return 'ppc64le'
            elif arch in ['s390x']:
                return 's390x'
            elif arch in ['riscv', 'riscv64']:
                return 'riscv64'
            elif arch in ['riscv32']:
                return 'riscv32'
            else:
                return arch
    
    # Check for direct architecture labels
    arch_labels = {
        'x64', 'x86_64', 'amd64',
        'aarch64', 'arm64', 'armv8',
        'aarch32', 'arm32', 'armv7l', 'armv7',
        'ppc64', 'ppc64be',
        'ppc64le',
        's390x',
        'riscv64', 'riscv',
        'riscv32'
    }
    
    for label in node.labels:
        if label.lower() in arch_labels:
            label_lower = label.lower()
            
            # Normalize
            if label_lower in ['x64', 'x86_64', 'amd64']:
                return 'x64'
            elif label_lower in ['aarch64', 'arm64', 'armv8']:
                return 'aarch64'
            elif label_lower in ['aarch32', 'arm32', 'armv7l', 'armv7']:
                return 'aarch32'
            elif label_lower in ['ppc64', 'ppc64be']:
                return 'ppc64'
            elif label_lower in ['ppc64le']:
                return 'ppc64le'
            elif label_lower in ['s390x']:
                return 's390x'
            elif label_lower in ['riscv64', 'riscv']:
                return 'riscv64'
            elif label_lower in ['riscv32']:
                return 'riscv32'
    
    return ''


def get_node_architecture(node):
    """
    Get the architecture for a node, trying multiple methods.
    
    Args:
        node: JenkinsNode instance
        
    Returns:
        Architecture name or 'unknown'
    """
    # Try extracting from node name first (4th element)
    arch = extract_architecture_from_name(node.name)
    if arch:
        return arch
    
    # Try extracting from labels
    arch = extract_architecture_from_labels(node)
    if arch:
        return arch
    
    return 'unknown'


def extract_container_host(node):
    """
    Extract container host from node labels.
    Looks for labels starting with 'hw.dockerhost.'
    
    Args:
        node: JenkinsNode instance
        
    Returns:
        Container host name or empty string
    """
    for label in node.labels:
        if label.startswith('hw.dockerhost.'):
            # Extract the dockerhost name after 'hw.dockerhost.'
            # e.g., 'hw.dockerhost.dockerhost-azure-ubuntu2204-x64-1' -> 'dockerhost-azure-ubuntu2204-x64-1'
            parts = label.split('.', 2)
            if len(parts) >= 3:
                return parts[2]
    return ''


def save_nodes_to_csv(nodes, filename: str):
    """
    Save nodes to CSV file with node name, function, provider, OS, OS Type, architecture, Java version, container host, status.
    
    Args:
        nodes: List of JenkinsNode instances
        filename: Output filename
    """
    output_path = Path(filename)
    
    with open(output_path, 'w', newline='') as f:
        writer = csv.writer(f)
        
        # Write header
        writer.writerow(['Node Name', 'Node Function', 'Node Provider', 'OS', 'OS Type', 'Architecture', 'Java Version', 'Container Host', 'Status', 'Online'])
        
        # Write node data
        for node in sorted(nodes, key=lambda n: n.name):
            node_function = get_node_category(node.name)
            node_provider = extract_provider_from_name(node.name)
            node_os = extract_os_from_name(node.name)
            node_arch = get_node_architecture(node)
            java_version = node.java_version or 'N/A'
            container_host = extract_container_host(node)
            status = 'offline' if node.offline else 'online'
            online = 'no' if node.offline else 'yes'
            
            # Only add OS Type for non-service and non-infrastructure nodes
            if node_function not in ['Service Nodes', 'Infrastructure Nodes']:
                node_os_type = get_os_type(node_os)
            else:
                node_os_type = ''
            
            writer.writerow([
                node.name,
                node_function,
                node_provider,
                node_os,
                node_os_type,
                node_arch,
                java_version,
                container_host,
                status,
                online
            ])
    
    logger.info(f"CSV data saved to {output_path}")


def save_cloud_capacity_to_csv(clouds, filename: str):
    """
    Save cloud capacity data to CSV file.
    
    Args:
        clouds: List of CloudConfig instances
        filename: Output filename
    """
    output_path = Path(filename)
    
    with open(output_path, 'w', newline='') as f:
        writer = csv.writer(f)
        
        # Write header
        writer.writerow(['Cloud Name', 'Cloud Type', 'Total Templates', 'Template Category', 'Category Count', 'Max Executors'])
        
        # Write cloud data
        for cloud in sorted(clouds, key=lambda c: c.name):
            max_executors = 'Unlimited' if cloud.instance_cap == -1 else str(cloud.instance_cap)
            template_count = cloud.get_template_count()
            categories = cloud.get_templates_by_category()
            
            if categories:
                # Write first row with cloud info and first category
                first_category = True
                for category, count in sorted(categories.items()):
                    if first_category:
                        writer.writerow([
                            cloud.name,
                            cloud.cloud_type,
                            template_count,
                            category.capitalize(),
                            count,
                            max_executors
                        ])
                        first_category = False
                    else:
                        # Subsequent rows for additional categories
                        writer.writerow([
                            '',
                            '',
                            '',
                            category.capitalize(),
                            count,
                            ''
                        ])
            else:
                # No templates
                writer.writerow([
                    cloud.name,
                    cloud.cloud_type,
                    0,
                    '',
                    '',
                    max_executors
                ])
    
    logger.info(f"Cloud capacity CSV saved to {output_path}")


def extract_provider_from_name(node_name):
    """
    Extract provider name from node name using pattern matcher.
    
    Args:
        node_name: Name of the node
        
    Returns:
        Provider name or 'other'
    """
    matcher = get_pattern_matcher()
    provider = matcher.get_provider(node_name)
    
    # Normalize common provider names for backward compatibility
    if provider in ['aws', 'azure', 'ibmcloud', 'osuosl', 'marist', 'digitalocean',
                    'macincloud', 'macstadium', 'rise', 'skytap', 'hetzner', 'rhibmcloud',
                    'docker', 'sxa', 'haroon', 'podman', 'orka', 'github-actions']:
        return provider
    
    return provider if provider else 'other'


def categorize_nodes_by_function_and_provider(nodes):
    """
    Categorize nodes by their function, OS type, architecture, and specific OS.
    For dynamic nodes, adds function subcategories (build/test).
    Hierarchy: Function → [Function Subcategory for dynamic] → OS Type → Architecture → Specific OS
    
    Args:
        nodes: List of JenkinsNode instances
        
    Returns:
        Dictionary with hierarchical categorization
    """
    categories = {}
    matcher = get_pattern_matcher()
    
    for node in nodes:
        name = node.name.lower()
        metadata = matcher.match(node.name)
        provider = metadata.provider
        function = metadata.function
        is_dynamic = metadata.is_dynamic
        
        node_os = extract_os_from_name(node.name)
        node_os_type = get_os_type(node_os) if node_os else 'unknown'
        node_arch = get_node_architecture(node)
        
        # Determine category using the updated get_node_category function
        category = get_node_category(node.name)
        
        # For dynamic nodes, track the function subcategory
        function_subcategory = None
        if is_dynamic and function in ['build', 'test']:
            function_subcategory = f"{function.capitalize()} Function"
        
        # Initialize category structure
        if category not in categories:
            categories[category] = {
                'total': 0,
                'online': 0,
                'offline': 0,
                'functions': {} if is_dynamic else None,  # Only for dynamic nodes
                'os_types': {} if not is_dynamic else None  # Only for static nodes
            }
        
        # Handle dynamic nodes with function subcategories
        if is_dynamic and function_subcategory:
            # Initialize function subcategory
            if function_subcategory not in categories[category]['functions']:
                categories[category]['functions'][function_subcategory] = {
                    'total': 0,
                    'online': 0,
                    'offline': 0,
                    'os_types': {}
                }
            
            # Update category-level counts
            categories[category]['total'] += 1
            if node.offline:
                categories[category]['offline'] += 1
            else:
                categories[category]['online'] += 1
            
            # Update function subcategory counts
            categories[category]['functions'][function_subcategory]['total'] += 1
            if node.offline:
                categories[category]['functions'][function_subcategory]['offline'] += 1
            else:
                categories[category]['functions'][function_subcategory]['online'] += 1
            
            # Initialize OS type structure under function
            if node_os_type not in categories[category]['functions'][function_subcategory]['os_types']:
                categories[category]['functions'][function_subcategory]['os_types'][node_os_type] = {
                    'total': 0,
                    'online': 0,
                    'offline': 0,
                    'architectures': {}
                }
            
            # Initialize architecture structure
            if node_arch not in categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures']:
                categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch] = {
                    'total': 0,
                    'online': 0,
                    'offline': 0,
                    'specific_os': {}
                }
            
            # Initialize specific OS structure
            if node_os not in categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch]['specific_os']:
                categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os] = {
                    'total': 0,
                    'online': 0,
                    'offline': 0,
                    'nodes': []
                }
            
            # Update counts at all levels
            categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['total'] += 1
            categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch]['total'] += 1
            categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os]['total'] += 1
            categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os]['nodes'].append(node.name)
            
            if node.offline:
                categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['offline'] += 1
                categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch]['offline'] += 1
                categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os]['offline'] += 1
            else:
                categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['online'] += 1
                categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch]['online'] += 1
                categories[category]['functions'][function_subcategory]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os]['online'] += 1
        
        else:
            # Handle static nodes (existing logic)
            # Initialize OS type structure
            if node_os_type not in categories[category]['os_types']:
                categories[category]['os_types'][node_os_type] = {
                    'total': 0,
                    'online': 0,
                    'offline': 0,
                    'architectures': {}
                }
            
            # Initialize architecture structure
            if node_arch not in categories[category]['os_types'][node_os_type]['architectures']:
                categories[category]['os_types'][node_os_type]['architectures'][node_arch] = {
                    'total': 0,
                    'online': 0,
                    'offline': 0,
                    'specific_os': {}
                }
            
            # Initialize specific OS structure
            if node_os not in categories[category]['os_types'][node_os_type]['architectures'][node_arch]['specific_os']:
                categories[category]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os] = {
                    'total': 0,
                    'online': 0,
                    'offline': 0,
                    'nodes': []
                }
            
            # Update counts at all levels
            categories[category]['total'] += 1
            categories[category]['os_types'][node_os_type]['total'] += 1
            categories[category]['os_types'][node_os_type]['architectures'][node_arch]['total'] += 1
            categories[category]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os]['total'] += 1
            categories[category]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os]['nodes'].append(node.name)
            
            if node.offline:
                categories[category]['offline'] += 1
                categories[category]['os_types'][node_os_type]['offline'] += 1
                categories[category]['os_types'][node_os_type]['architectures'][node_arch]['offline'] += 1
                categories[category]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os]['offline'] += 1
            else:
                categories[category]['online'] += 1
                categories[category]['os_types'][node_os_type]['online'] += 1
                categories[category]['os_types'][node_os_type]['architectures'][node_arch]['online'] += 1
                categories[category]['os_types'][node_os_type]['architectures'][node_arch]['specific_os'][node_os]['online'] += 1
    
    return categories


def generate_function_os_arch_summary(nodes):
    """
    Generate a summary table of nodes by function, OS type, and architecture.
    
    Args:
        nodes: List of JenkinsNode instances
        
    Returns:
        List of dictionaries with function, os_type, arch, count, online, offline
    """
    summary_data = {}
    
    for node in nodes:
        category = get_node_category(node.name)
        node_os = extract_os_from_name(node.name)
        node_os_type = get_os_type(node_os) if node_os else 'unknown'
        node_arch = get_node_architecture(node)
        
        # Create a unique key for this combination
        key = (category, node_os_type, node_arch)
        
        if key not in summary_data:
            summary_data[key] = {
                'function': category,
                'os_type': node_os_type,
                'arch': node_arch,
                'count': 0,
                'online': 0,
                'offline': 0
            }
        
        summary_data[key]['count'] += 1
        if node.offline:
            summary_data[key]['offline'] += 1
        else:
            summary_data[key]['online'] += 1
    
    # Convert to list and sort by function, os_type, arch
    result = list(summary_data.values())
    result.sort(key=lambda x: (x['function'], x['os_type'], x['arch']))
    
    return result


def print_summary(summary, nodes):
    """
    Print capacity summary to console.
    
    Args:
        summary: CapacitySummary instance
        nodes: List of JenkinsNode instances
    """
    print("\n" + "="*60)
    print("JENKINS CAPACITY SUMMARY")
    print("="*60)
    print(f"\nNodes:")
    print(f"  Total:   {summary.total_nodes}")
    print(f"  Online:  {summary.online_nodes}")
    print(f"  Offline: {summary.offline_nodes}")
    
    # Categorize and display nodes by function and provider
    categories = categorize_nodes_by_function_and_provider(nodes)
    
    # Print quick stats table with static docker nodes categorized by function
    print(f"\nQuick Stats by Function:")
    print(f"  {'Node Function':<25} {'Total':<8} {'Online':<8} {'Offline':<8}")
    print(f"  {'-'*25} {'-'*8} {'-'*8} {'-'*8}")
    
    # Separate static docker nodes by their function prefix
    static_docker_nodes = [n for n in nodes if get_node_category(n.name) == 'Static Docker Nodes']
    build_docker_stats = {'total': 0, 'online': 0, 'offline': 0}
    test_docker_stats = {'total': 0, 'online': 0, 'offline': 0}
    
    for node in static_docker_nodes:
        if node.name.lower().startswith('build-'):
            build_docker_stats['total'] += 1
            if node.offline:
                build_docker_stats['offline'] += 1
            else:
                build_docker_stats['online'] += 1
        elif node.name.lower().startswith('test-'):
            test_docker_stats['total'] += 1
            if node.offline:
                test_docker_stats['offline'] += 1
            else:
                test_docker_stats['online'] += 1
    
    # Display Build Nodes with subcategories
    if 'Build Nodes' in categories:
        build_stats = categories['Build Nodes']
        # Combine Build Nodes and build-docker stats
        combined_total = build_stats['total'] + build_docker_stats['total']
        combined_online = build_stats['online'] + build_docker_stats['online']
        combined_offline = build_stats['offline'] + build_docker_stats['offline']
        
        print(f"  {'Build Nodes':<25} {combined_total:<8} {combined_online:<8} {combined_offline:<8}")
        
        # Show non-docker build nodes
        if build_stats['total'] > 0:
            print(f"    └─ {'Non-Docker':<21} {build_stats['total']:<8} {build_stats['online']:<8} {build_stats['offline']:<8}")
        
        # Show static docker build nodes
        if build_docker_stats['total'] > 0:
            print(f"    └─ {'Static Docker':<21} {build_docker_stats['total']:<8} {build_docker_stats['online']:<8} {build_docker_stats['offline']:<8}")
    
    # Display Test Nodes with subcategories
    if 'Test Nodes' in categories:
        test_stats = categories['Test Nodes']
        # Combine Test Nodes and test-docker stats
        combined_total = test_stats['total'] + test_docker_stats['total']
        combined_online = test_stats['online'] + test_docker_stats['online']
        combined_offline = test_stats['offline'] + test_docker_stats['offline']
        
        print(f"  {'Test Nodes':<25} {combined_total:<8} {combined_online:<8} {combined_offline:<8}")
        
        # Show non-docker test nodes
        if test_stats['total'] > 0:
            print(f"    └─ {'Non-Docker':<21} {test_stats['total']:<8} {test_stats['online']:<8} {test_stats['offline']:<8}")
        
        # Show static docker test nodes
        if test_docker_stats['total'] > 0:
            print(f"    └─ {'Static Docker':<21} {test_docker_stats['total']:<8} {test_docker_stats['online']:<8} {test_docker_stats['offline']:<8}")
    
    # Display other categories
    other_categories = [
        'Docker Host Nodes',
        'Controller Nodes',
        'Infrastructure Nodes',
        'Service Nodes',
        'Other Nodes'
    ]
    
    for category in other_categories:
        if category in categories:
            stats = categories[category]
            print(f"  {category:<25} {stats['total']:<8} {stats['online']:<8} {stats['offline']:<8}")
    
    # Print new summary table: Function, OS Type, Architecture breakdown
    print(f"\nNodes by Function, OS Type, and Architecture:")
    print(f"  {'Function':<25} {'OS Type':<15} {'Architecture':<15} {'Count':<8} {'Online':<8} {'Offline':<8}")
    print(f"  {'-'*25} {'-'*15} {'-'*15} {'-'*8} {'-'*8} {'-'*8}")
    
    func_os_arch_summary = generate_function_os_arch_summary(nodes)
    for entry in func_os_arch_summary:
        print(f"  {entry['function']:<25} {entry['os_type']:<15} {entry['arch']:<15} {entry['count']:<8} {entry['online']:<8} {entry['offline']:<8}")
    
    print(f"\nNodes by Function:")
    print(f"  {'Category':<25} {'Total':<8} {'Online':<8} {'%':<7} {'Offline':<8} {'%':<7}")
    print(f"  {'-'*25} {'-'*8} {'-'*8} {'-'*7} {'-'*8} {'-'*7}")
    
    # Main categories (exclude Controller, Infrastructure, Service)
    main_category_order = [
        'Static Docker Nodes',
        'Build Nodes',
        'Test Nodes',
        'Docker Host Nodes',
        'Other Nodes'
    ]
    
    # Special categories (Controller, Infrastructure, Service)
    special_category_order = [
        'Controller Nodes',
        'Infrastructure Nodes',
        'Service Nodes'
    ]
    
    # Display main categories with full hierarchy
    for category in main_category_order:
        if category in categories:
            stats = categories[category]
            online_pct = (stats['online'] / stats['total'] * 100) if stats['total'] > 0 else 0
            offline_pct = (stats['offline'] / stats['total'] * 100) if stats['total'] > 0 else 0
            print(f"  {category:<25} {stats['total']:<8} {stats['online']:<8} {online_pct:<6.1f}% {stats['offline']:<8} {offline_pct:<6.1f}%")
            
            # Show OS Type breakdown (2nd tier)
            if stats.get('os_types'):
                for os_type, os_type_stats in sorted(stats['os_types'].items()):
                    online_pct = (os_type_stats['online'] / os_type_stats['total'] * 100) if os_type_stats['total'] > 0 else 0
                    offline_pct = (os_type_stats['offline'] / os_type_stats['total'] * 100) if os_type_stats['total'] > 0 else 0
                    print(f"    └─ {os_type:<21} {os_type_stats['total']:<8} {os_type_stats['online']:<8} {online_pct:<6.1f}% {os_type_stats['offline']:<8} {offline_pct:<6.1f}%")
                    
                    # Show Architecture breakdown (3rd tier)
                    if os_type_stats.get('architectures'):
                        for arch, arch_stats in sorted(os_type_stats['architectures'].items()):
                            online_pct = (arch_stats['online'] / arch_stats['total'] * 100) if arch_stats['total'] > 0 else 0
                            offline_pct = (arch_stats['offline'] / arch_stats['total'] * 100) if arch_stats['total'] > 0 else 0
                            print(f"       └─ {arch:<18} {arch_stats['total']:<8} {arch_stats['online']:<8} {online_pct:<6.1f}% {arch_stats['offline']:<8} {offline_pct:<6.1f}%")
                            
                            # Show Specific OS breakdown (4th tier)
                            if arch_stats.get('specific_os'):
                                for specific_os, specific_os_stats in sorted(arch_stats['specific_os'].items()):
                                    online_pct = (specific_os_stats['online'] / specific_os_stats['total'] * 100) if specific_os_stats['total'] > 0 else 0
                                    offline_pct = (specific_os_stats['offline'] / specific_os_stats['total'] * 100) if specific_os_stats['total'] > 0 else 0
                                    print(f"          └─ {specific_os:<15} {specific_os_stats['total']:<8} {specific_os_stats['online']:<8} {online_pct:<6.1f}% {specific_os_stats['offline']:<8} {offline_pct:<6.1f}%")
    
    # Display special categories (Controller, Infrastructure, Service) in separate section
    print(f"\n{'='*60}")
    print("CONTROLLER, INFRASTRUCTURE & SERVICE NODES")
    print(f"{'='*60}\n")
    
    for category in special_category_order:
        if category in categories:
            stats = categories[category]
            print(f"{category}: {stats['total']} nodes ({stats['online']} online, {stats['offline']} offline)")
            print(f"  {'Node Name':<40} {'Executors':<12} {'Status':<10}")
            print(f"  {'-'*40} {'-'*12} {'-'*10}")
            
            # Get all nodes for this category
            category_nodes = [n for n in nodes if get_node_category(n.name) == category]
            for node in sorted(category_nodes, key=lambda n: n.name):
                status = "OFFLINE" if node.offline else "ONLINE"
                print(f"  {node.name:<40} {node.num_executors:<12} {status:<10}")
            print()
    
    print("="*60 + "\n")


def get_node_category(node_name):
    """
    Determine the category of a node based on its name using pattern matcher.
    
    Args:
        node_name: Name of the node
        
    Returns:
        Category name
    """
    matcher = get_pattern_matcher()
    metadata = matcher.match(node_name)
    function = metadata.function
    provider = metadata.provider
    is_dynamic = metadata.is_dynamic
    
    # Check if this is a dynamic node first
    if is_dynamic:
        return 'Dynamic Nodes'
    
    # Map function to category for static nodes
    if provider == 'docker':
        return 'Static Docker Nodes'
    elif function == 'build':
        return 'Build Nodes'
    elif function == 'test':
        return 'Test Nodes'
    elif function == 'dockerhost':
        return 'Docker Host Nodes'
    elif function in ['infrastructure', 'infra', 'controller', 'service']:
        # Consolidate infrastructure, controller, and service nodes into single category
        return 'Infrastructure Nodes'
    else:
        return 'Other Nodes'


def print_node_details(nodes):
    """
    Print detailed node information grouped by function and provider.
    For dynamic nodes, groups by function (build/test) then by provider.
    
    Args:
        nodes: List of JenkinsNode instances
    """
    matcher = get_pattern_matcher()
    
    # Group nodes by category, function (for dynamic), and provider
    categorized_nodes = {}
    for node in nodes:
        category = get_node_category(node.name)
        metadata = matcher.match(node.name)
        provider = metadata.provider
        function = metadata.function
        is_dynamic = metadata.is_dynamic
        
        if category not in categorized_nodes:
            categorized_nodes[category] = {
                'is_dynamic': is_dynamic,
                'functions': {} if is_dynamic else None,
                'providers': {} if not is_dynamic else None
            }
        
        if is_dynamic:
            # Group by function first, then provider
            if function not in categorized_nodes[category]['functions']:
                categorized_nodes[category]['functions'][function] = {}
            
            if provider not in categorized_nodes[category]['functions'][function]:
                categorized_nodes[category]['functions'][function][provider] = []
            
            categorized_nodes[category]['functions'][function][provider].append(node)
        else:
            # Group by provider only
            if provider not in categorized_nodes[category]['providers']:
                categorized_nodes[category]['providers'][provider] = []
            
            categorized_nodes[category]['providers'][provider].append(node)
    
    # Define category order (Dynamic Nodes first, then Static Docker Nodes)
    category_order = [
        'Dynamic Nodes',
        'Static Docker Nodes',
        'Infrastructure Nodes',
        'Build Nodes',
        'Test Nodes',
        'Docker Host Nodes',
        'Other Nodes'
    ]
    
    print("\nDETAILED NODE INFORMATION")
    print("="*100)
    
    # Print nodes by category
    for category in category_order:
        if category not in categorized_nodes:
            continue
        
        category_data = categorized_nodes[category]
        is_dynamic = category_data['is_dynamic']
        
        # Count total nodes in category
        if is_dynamic:
            total_category_nodes = sum(
                len(nodes_list)
                for function_providers in category_data['functions'].values()
                for nodes_list in function_providers.values()
            )
        else:
            total_category_nodes = sum(len(nodes_list) for nodes_list in category_data['providers'].values())
        
        print(f"\n{category} ({total_category_nodes} nodes)")
        print("="*100)
        
        if is_dynamic:
            # Print dynamic nodes grouped by function, then provider
            for function in sorted(category_data['functions'].keys()):
                function_providers = category_data['functions'][function]
                function_total = sum(len(nodes_list) for nodes_list in function_providers.values())
                
                print(f"\n  {function.capitalize()} Function ({function_total} nodes)")
                print("  " + "="*96)
                
                for provider in sorted(function_providers.keys()):
                    provider_nodes = sorted(function_providers[provider], key=lambda n: n.name)
                    
                    print(f"\n    Provider: {provider.upper()} ({len(provider_nodes)} nodes)")
                    print("    " + "-"*94)
                    print(f"    {'Node Name':<28} {'Type':<10} {'Arch':<10} {'OS':<15} {'Status':<12} {'Executors':<12} {'Busy':<8} {'Idle':<8}")
                    print("    " + "-"*134)
                    
                    for node in provider_nodes:
                        status = "OFFLINE" if node.offline else "ONLINE"
                        if node.temporarily_offline:
                            status += " (TEMP)"
                        
                        node_os = extract_os_from_name(node.name)
                        node_os_type = get_os_type(node_os)
                        node_arch = get_node_architecture(node)
                        
                        print(f"    {node.name:<28} {node_os_type:<10} {node_arch:<10} {node_os:<15} {status:<12} {node.num_executors:<12} "
                              f"{node.busy_executors:<8} {node.idle_executors:<8}")
                        
                        if node.offline_cause:
                            print(f"      └─ Offline reason: {node.offline_cause}")
        else:
            # Print static nodes grouped by provider
            for provider in sorted(category_data['providers'].keys()):
                provider_nodes = sorted(category_data['providers'][provider], key=lambda n: n.name)
                
                print(f"\n  Provider: {provider.upper()} ({len(provider_nodes)} nodes)")
                print("  " + "-"*96)
            
            # For Static Docker Nodes, show Node Name, Type, Arch, OS, Container Host, and Status
            if category == 'Static Docker Nodes':
                print(f"  {'Node Name':<28} {'Type':<10} {'Arch':<10} {'OS':<15} {'Container Host':<30} {'Status':<12}")
                print("  " + "-"*116)
                
                for node in provider_nodes:
                    status = "OFFLINE" if node.offline else "ONLINE"
                    if node.temporarily_offline:
                        status += " (TEMP)"
                    
                    node_os = extract_os_from_name(node.name)
                    node_os_type = get_os_type(node_os)
                    node_arch = get_node_architecture(node)
                    container_host = extract_container_host(node)
                    
                    print(f"  {node.name:<28} {node_os_type:<10} {node_arch:<10} {node_os:<15} {container_host:<30} {status:<12}")
                    
                    if node.offline_cause:
                        print(f"    └─ Offline reason: {node.offline_cause}")
            
            # For Build, Test, and Docker Host Nodes, show Node Name, Type, Arch, OS, Container Host (blank), and Status
            elif category in ['Build Nodes', 'Test Nodes', 'Docker Host Nodes']:
                print(f"  {'Node Name':<28} {'Type':<10} {'Arch':<10} {'OS':<15} {'Container Host':<30} {'Status':<12} {'Executors':<12} {'Busy':<8} {'Idle':<8}")
                print("  " + "-"*136)
                
                for node in provider_nodes:
                    status = "OFFLINE" if node.offline else "ONLINE"
                    if node.temporarily_offline:
                        status += " (TEMP)"
                    
                    node_os = extract_os_from_name(node.name)
                    node_os_type = get_os_type(node_os)
                    node_arch = get_node_architecture(node)
                    container_host = ""  # Blank for non-docker nodes
                    
                    print(f"  {node.name:<28} {node_os_type:<10} {node_arch:<10} {node_os:<15} {container_host:<30} {status:<12} {node.num_executors:<12} "
                          f"{node.busy_executors:<8} {node.idle_executors:<8}")
                    
                    if node.offline_cause:
                        print(f"    └─ Offline reason: {node.offline_cause}")
            
            else:
                # Standard display for other categories (Controller, Infrastructure, Service, Other)
                print(f"  {'Node Name':<28} {'Status':<12} {'Executors':<12} {'Busy':<8} {'Idle':<8} {'Labels'}")
                print("  " + "-"*96)
                
                for node in provider_nodes:
                    status = "OFFLINE" if node.offline else "ONLINE"
                    if node.temporarily_offline:
                        status += " (TEMP)"
                    
                    labels_str = ", ".join(node.labels[:3])  # Show first 3 labels
                    if len(node.labels) > 3:
                        labels_str += f" (+{len(node.labels)-3} more)"
                    
                    print(f"  {node.name:<28} {status:<12} {node.num_executors:<12} "
                          f"{node.busy_executors:<8} {node.idle_executors:<8} {labels_str}")
                    
                    if node.offline_cause:
                        print(f"    └─ Offline reason: {node.offline_cause}")
    
    print("\n" + "="*100 + "\n")


def print_cloud_capacity(clouds):
    """
    Print cloud capacity information to console.
    
    Args:
        clouds: List of CloudConfig instances
    """
    if not clouds:
        return
    
    print("\n" + "="*60)
    print("CLOUD PROVIDER CAPACITY")
    print("="*60)
    print(f"\n  {'Cloud Provider':<25} {'Type':<20} {'Templates':<12} {'Max Executors':<15}")
    print(f"  {'-'*25} {'-'*20} {'-'*12} {'-'*15}")
    
    for cloud in sorted(clouds, key=lambda c: c.name.lower()):
        max_executors = 'Unlimited' if cloud.instance_cap == -1 else str(cloud.instance_cap)
        template_count = str(cloud.get_template_count())
        print(f"  {cloud.name:<25} {cloud.cloud_type:<20} {template_count:<12} {max_executors:<15}")
        
        # Print template breakdown by category
        categories = cloud.get_templates_by_category()
        for category, count in sorted(categories.items()):
            print(f"    └─ {category.capitalize() + ' Templates':<21} {'':<20} {count:<12}")
    
    print()


def print_cloud_template_details(clouds):
    """
    Print detailed cloud template information to console.
    
    Args:
        clouds: List of CloudConfig instances
    """
    if not clouds:
        return
    
    print("\n" + "="*80)
    print("CLOUD TEMPLATE DETAILS")
    print("="*80)
    
    for cloud in sorted(clouds, key=lambda c: c.name.lower()):
        print(f"\n{'='*80}")
        print(f"Cloud: {cloud.name} ({cloud.cloud_type})")
        print(f"Max Instances: {'Unlimited' if cloud.instance_cap == -1 else cloud.instance_cap}")
        print(f"Total Templates: {cloud.get_template_count()}")
        print(f"{'='*80}")
        
        if not cloud.templates:
            print("  No templates configured")
            continue
        
        # Print table header
        print(f"\n  {'Template Name':<35} {'Image':<30} {'OS Type':<10} {'Arch':<10} {'Exec':<6} {'Labels'}")
        print(f"  {'-'*35} {'-'*30} {'-'*10} {'-'*10} {'-'*6} {'-'*50}")
        
        # Print each template
        for template in sorted(cloud.templates, key=lambda t: t.name_prefix):
            # Truncate image name if too long
            image = template.image[:28] + '..' if len(template.image) > 30 else template.image
            
            # Truncate labels if too long
            labels = template.label_string[:48] + '..' if len(template.label_string) > 50 else template.label_string
            if not labels:
                labels = "(no labels)"
            
            print(f"  {template.name_prefix:<35} {image:<30} {template.os_type:<10} {template.architecture:<10} {template.num_executors:<6} {labels}")
    
    print()


def main():
    """Main function to run the capacity analyzer."""
    try:
        logger.info("Starting Jenkins Capacity Analyzer")
        
        # Load configuration
        config = Config.from_env()
        logger.info(f"Connecting to Jenkins at {config.jenkins_url}")
        
        # Create Jenkins client
        client = JenkinsClient(
            url=config.jenkins_url,
            username=config.username,
            api_token=config.api_token
        )
        
        # Get capacity report
        logger.info("Fetching capacity data...")
        nodes, summary = client.get_capacity_report()
        
        # Load cloud capacity data
        clouds_xml_path = Path(config.cloud_config_file)
        clouds = []
        if clouds_xml_path.exists():
            logger.info(f"Loading cloud capacity data from {clouds_xml_path}...")
            clouds = parse_clouds_xml(str(clouds_xml_path))
            logger.info(f"Found {len(clouds)} cloud providers")
        else:
            logger.warning(f"Cloud configuration file not found: {clouds_xml_path}")
            logger.warning("Cloud capacity reporting will be disabled.")
            logger.warning("To enable cloud capacity reporting:")
            logger.warning("  1. Run tools/extract_clouds_config.sh on your Jenkins server")
            logger.warning("  2. Copy the generated clouds.xml file to this directory")
            logger.warning("  3. Update CLOUD_CONFIG_FILE in your .env file")
            print("\n" + "="*80)
            print("⚠️  WARNING: Cloud configuration file not found!")
            print("="*80)
            print(f"Expected location: {clouds_xml_path}")
            print("\nCloud capacity reporting is disabled.")
            print("\nTo enable cloud capacity reporting:")
            print("  1. On your Jenkins server, run: tools/extract_clouds_config.sh")
            print("  2. Copy the generated clouds.xml file to this directory")
            print("  3. Update CLOUD_CONFIG_FILE in your .env file if needed")
            print("="*80 + "\n")
        
        # Print results
        print_summary(summary, nodes)
        if clouds:
            print_cloud_capacity(clouds)
            print_cloud_template_details(clouds)
        print_node_details(nodes)
        
        # Save to files
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save nodes data to JSON
        nodes_data = [node.model_dump() for node in nodes]
        save_to_json(nodes_data, f"data/jenkins_nodes_{timestamp}.json")
        
        # Save summary data to JSON with cloud capacity
        summary_data = summary.model_dump()
        if clouds:
            summary_data['cloud_capacity'] = [
                {
                    'name': cloud.name,
                    'type': cloud.cloud_type,
                    'template_count': cloud.get_template_count(),
                    'templates_by_category': cloud.get_templates_by_category(),
                    'max_executors': 'Unlimited' if cloud.instance_cap == -1 else cloud.instance_cap
                }
                for cloud in clouds
            ]
        save_to_json(summary_data, f"data/jenkins_summary_{timestamp}.json")
        
        # Save nodes to CSV
        save_nodes_to_csv(nodes, f"data/jenkins_nodes_{timestamp}.csv")
        
        # Save cloud capacity to CSV
        if clouds:
            save_cloud_capacity_to_csv(clouds, f"data/jenkins_cloud_capacity_{timestamp}.csv")
        
        logger.info("Analysis complete!")
        
    except Exception as e:
        logger.error(f"Error running capacity analyzer: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()

# Made with Bob
