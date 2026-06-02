#!/usr/bin/env python3
"""Flask web application for Jenkins Capacity Analyzer."""

import logging
import os
from datetime import datetime
from flask import Flask, render_template, jsonify, request, g
from pathlib import Path
from werkzeug.middleware.proxy_fix import ProxyFix
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.triggers.cron import CronTrigger
import atexit

from src.config import Config
from src.jenkins_client import JenkinsClient
from src.cloud_parser import parse_clouds_xml
from src.excluded_nodes import get_excluded_nodes_manager
from src.metrics_tracker import get_metrics_tracker
from src.user_manager import get_user_manager
from src.auth import get_session_manager, require_auth, optional_auth, get_current_user, get_current_user_role
from src.rbac import (
    require_role, require_admin, require_operator_or_admin,
    can_modify_user, can_delete_user, get_role_permissions
)
from main import (
    categorize_nodes_by_function_and_provider,
    get_node_category,
    extract_provider_from_name,
    extract_os_from_name,
    get_os_type,
    get_node_architecture,
    extract_container_host
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('logs/web_app.log')
    ]
)

logger = logging.getLogger(__name__)

app = Flask(__name__)

# Load configuration
config = Config.from_env()

# Configure Flask secret key for session management
app.config['SECRET_KEY'] = config.flask_secret_key

# Initialize session manager with configured timeout
session_manager = get_session_manager()
if config.session_timeout_minutes:
    from datetime import timedelta
    session_manager.session_timeout = timedelta(minutes=config.session_timeout_minutes)

# Add custom Jinja2 filter for timestamp formatting
@app.template_filter('format_timestamp')
def format_timestamp(timestamp_str):
    """Format ISO timestamp to DD-MM-YYYY HH:MI:SS format."""
    try:
        # Parse ISO format timestamp (e.g., "2026-03-31T08:25:21.615")
        dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
        # Format as DD-MM-YYYY HH:MI:SS
        return dt.strftime('%d-%m-%Y %H:%M:%S')
    except (ValueError, AttributeError):
        # If parsing fails, return original string
        return timestamp_str

# Configure application for subdirectory deployment
# This allows the app to work correctly when deployed under a path like /jenkins-capacity
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

# Get the application root from environment variable (set by WSGI)
# This will be set to /jenkins-capacity when deployed in a subdirectory
APPLICATION_ROOT = os.environ.get('APPLICATION_ROOT', '')
if APPLICATION_ROOT:
    app.config['APPLICATION_ROOT'] = APPLICATION_ROOT

# Initialize background scheduler for automatic metrics recording
scheduler = BackgroundScheduler()
scheduler_started = False


def calculate_category_metrics(all_nodes, excluded_nodes):
    """Calculate metrics for specific node categories (build, test, infrastructure, docker hosts).
    
    Args:
        all_nodes: List of all JenkinsNode instances
        excluded_nodes: List of excluded JenkinsNode instances
        
    Returns:
        Dictionary with category-specific metrics
    """
    # Separate nodes by category
    build_nodes_all = []
    test_nodes_all = []
    infra_nodes_all = []
    docker_host_nodes_all = []
    
    for node in all_nodes:
        category = get_node_category(node.name)
        # Include static docker nodes with build- or test- prefix
        if category == 'Build Nodes' or (category == 'Static Docker Nodes' and node.name.lower().startswith('build-')):
            build_nodes_all.append(node)
        elif category == 'Test Nodes' or (category == 'Static Docker Nodes' and node.name.lower().startswith('test-')):
            test_nodes_all.append(node)
        elif category == 'Infrastructure Nodes':
            infra_nodes_all.append(node)
        elif category == 'Docker Host Nodes':
            docker_host_nodes_all.append(node)
    
    # Separate excluded nodes by category
    manager = get_excluded_nodes_manager()
    build_excluded = [n for n in build_nodes_all if manager.is_excluded(n.name)]
    test_excluded = [n for n in test_nodes_all if manager.is_excluded(n.name)]
    infra_excluded = [n for n in infra_nodes_all if manager.is_excluded(n.name)]
    docker_host_excluded = [n for n in docker_host_nodes_all if manager.is_excluded(n.name)]
    
    # Get active (non-excluded) nodes
    build_active = [n for n in build_nodes_all if not manager.is_excluded(n.name)]
    test_active = [n for n in test_nodes_all if not manager.is_excluded(n.name)]
    infra_active = [n for n in infra_nodes_all if not manager.is_excluded(n.name)]
    docker_host_active = [n for n in docker_host_nodes_all if not manager.is_excluded(n.name)]
    
    # Calculate build nodes metrics
    build_total = len(build_active)
    build_online = sum(1 for n in build_active if not n.offline)
    build_offline = build_total - build_online
    build_excluded_count = len(build_excluded)
    
    # Calculate test nodes metrics
    test_total = len(test_active)
    test_online = sum(1 for n in test_active if not n.offline)
    test_offline = test_total - test_online
    test_excluded_count = len(test_excluded)
    
    # Calculate infrastructure nodes metrics
    infra_total = len(infra_active)
    infra_online = sum(1 for n in infra_active if not n.offline)
    infra_offline = infra_total - infra_online
    infra_excluded_count = len(infra_excluded)
    
    # Calculate docker host nodes metrics
    docker_host_total = len(docker_host_active)
    docker_host_online = sum(1 for n in docker_host_active if not n.offline)
    docker_host_offline = docker_host_total - docker_host_online
    docker_host_excluded_count = len(docker_host_excluded)
    
    return {
        'build_nodes_total': build_total,
        'build_nodes_online': build_online,
        'build_nodes_offline': build_offline,
        'build_nodes_excluded': build_excluded_count,
        'test_nodes_total': test_total,
        'test_nodes_online': test_online,
        'test_nodes_offline': test_offline,
        'test_nodes_excluded': test_excluded_count,
        'infra_nodes_total': infra_total,
        'infra_nodes_online': infra_online,
        'infra_nodes_offline': infra_offline,
        'infra_nodes_excluded': infra_excluded_count,
        'docker_host_nodes_total': docker_host_total,
        'docker_host_nodes_online': docker_host_online,
        'docker_host_nodes_offline': docker_host_offline,
        'docker_host_nodes_excluded': docker_host_excluded_count
    }


def record_metrics_snapshot():
    """Background job to record metrics snapshot."""
    try:
        logger.info("Starting automatic metrics snapshot recording...")
        all_nodes, summary = get_jenkins_data()
        
        if all_nodes is None or summary is None:
            logger.error("Failed to fetch Jenkins data for metrics snapshot")
            return
        
        # Filter out excluded nodes
        active_nodes, excluded_nodes = filter_excluded_nodes(all_nodes)
        
        # Recalculate summary using only active nodes
        active_summary = recalculate_summary(active_nodes)
        
        # Calculate category-specific metrics
        category_metrics = calculate_category_metrics(all_nodes, excluded_nodes)
        
        # Record the snapshot
        tracker = get_metrics_tracker()
        snapshot = tracker.record_snapshot(
            total_nodes=active_summary.total_nodes,
            online_nodes=active_summary.online_nodes,
            offline_nodes=active_summary.offline_nodes,
            excluded_nodes=len(excluded_nodes),
            total_executors=active_summary.total_executors,
            busy_executors=active_summary.busy_executors,
            idle_executors=active_summary.idle_executors,
            utilization_percentage=active_summary.utilization_percentage,
            **category_metrics
        )
        
        logger.info(f"Metrics snapshot recorded successfully at {snapshot.timestamp}")
        logger.info(f"  Total: {snapshot.total_nodes}, Online: {snapshot.online_nodes} ({snapshot.online_percentage}%), "
                   f"Offline: {snapshot.offline_nodes} ({snapshot.offline_percentage}%), Excluded: {snapshot.excluded_nodes}")
        logger.info(f"  Build Nodes: {snapshot.build_nodes_total} (Online: {snapshot.build_nodes_online}/{snapshot.build_nodes_online_percentage}%, "
                   f"Offline: {snapshot.build_nodes_offline}/{snapshot.build_nodes_offline_percentage}%, Excluded: {snapshot.build_nodes_excluded})")
        logger.info(f"  Test Nodes: {snapshot.test_nodes_total} (Online: {snapshot.test_nodes_online}/{snapshot.test_nodes_online_percentage}%, "
                   f"Offline: {snapshot.test_nodes_offline}/{snapshot.test_nodes_offline_percentage}%, Excluded: {snapshot.test_nodes_excluded})")
        logger.info(f"  Infrastructure Nodes: {snapshot.infra_nodes_total} (Online: {snapshot.infra_nodes_online}/{snapshot.infra_nodes_online_percentage}%, "
                   f"Offline: {snapshot.infra_nodes_offline}/{snapshot.infra_nodes_offline_percentage}%, Excluded: {snapshot.infra_nodes_excluded})")
        logger.info(f"  Docker Host Nodes: {snapshot.docker_host_nodes_total} (Online: {snapshot.docker_host_nodes_online}/{snapshot.docker_host_nodes_online_percentage}%, "
                   f"Offline: {snapshot.docker_host_nodes_offline}/{snapshot.docker_host_nodes_offline_percentage}%, Excluded: {snapshot.docker_host_nodes_excluded})")
        
    except Exception as e:
        logger.error(f"Error recording automatic metrics snapshot: {e}", exc_info=True)


def auto_archive_previous_months():
    """Background job to automatically archive previous months."""
    try:
        logger.info("Starting automatic monthly archiving...")
        tracker = get_metrics_tracker()
        result = tracker.archive_and_cleanup()
        
        if result['archived_months']:
            logger.info(f"Auto-archived {len(result['archived_months'])} month(s): {', '.join(result['archived_months'])}")
            logger.info(f"  Total snapshots archived: {result['snapshots_archived']}")
            logger.info(f"  Current month snapshots retained: {result['current_month_snapshots']}")
        else:
            logger.info("No completed months to archive")
            
    except Exception as e:
        logger.error(f"Error in automatic monthly archiving: {e}", exc_info=True)


def start_metrics_scheduler():
    """Start the metrics recording scheduler if enabled."""
    global scheduler_started
    
    if scheduler_started:
        return
    
    try:
        config = Config.from_env()
        
        if not config.metrics_auto_record:
            logger.info("Automatic metrics recording is disabled (METRICS_AUTO_RECORD=false)")
            return
        
        interval_minutes = config.metrics_snapshot_interval
        logger.info(f"Starting automatic metrics recording every {interval_minutes} minutes")
        
        # Check for and archive any completed months on startup
        # This ensures archiving happens even if the scheduled job was missed
        try:
            logger.info("Checking for completed months to archive on startup...")
            tracker = get_metrics_tracker()
            result = tracker.archive_and_cleanup()
            
            if result['archived_months']:
                logger.info(f"Startup archiving: Archived {len(result['archived_months'])} month(s): {', '.join(result['archived_months'])}")
                logger.info(f"  Total snapshots archived: {result['snapshots_archived']}")
                logger.info(f"  Current month snapshots retained: {result['current_month_snapshots']}")
            else:
                logger.info("Startup archiving: No completed months to archive")
        except Exception as e:
            logger.error(f"Error during startup archiving check: {e}", exc_info=True)
        
        # Add metrics snapshot job
        scheduler.add_job(
            func=record_metrics_snapshot,
            trigger=IntervalTrigger(minutes=interval_minutes),
            id='metrics_snapshot',
            name='Record metrics snapshot',
            replace_existing=True
        )
        
        # Add monthly archiving job (runs at 00:05 on the 1st of each month)
        scheduler.add_job(
            func=auto_archive_previous_months,
            trigger=CronTrigger(day=1, hour=0, minute=5),
            id='monthly_archive',
            name='Archive previous month metrics',
            replace_existing=True
        )
        
        # Start the scheduler
        scheduler.start()
        scheduler_started = True
        
        logger.info("Metrics recording scheduler started successfully")
        logger.info("Monthly archiving scheduler configured (runs at 00:05 on 1st of each month)")
        
        # Register shutdown handler
        atexit.register(lambda: scheduler.shutdown())
        
    except Exception as e:
        logger.error(f"Failed to start metrics scheduler: {e}", exc_info=True)

    app.config['APPLICATION_ROOT'] = APPLICATION_ROOT


def get_jenkins_data():
    """Fetch Jenkins capacity data."""
    try:
        config = Config.from_env()
        client = JenkinsClient(
            url=config.jenkins_url,
            username=config.username,
            api_token=config.api_token
        )
        nodes, summary = client.get_capacity_report()
        return nodes, summary
    except Exception as e:
        logger.error(f"Error fetching Jenkins data: {e}")
        return None, None


def prepare_quick_stats(nodes, categories):
    """Prepare quick stats data for display."""
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
    
    quick_stats = []
    
    # Build Nodes
    if 'Build Nodes' in categories:
        build_stats = categories['Build Nodes']
        combined_total = build_stats['total'] + build_docker_stats['total']
        combined_online = build_stats['online'] + build_docker_stats['online']
        combined_offline = build_stats['offline'] + build_docker_stats['offline']
        
        quick_stats.append({
            'category': 'Build Nodes',
            'total': combined_total,
            'online': combined_online,
            'offline': combined_offline,
            'subcategories': [
                {'name': 'Non-Docker', **build_stats} if build_stats['total'] > 0 else None,
                {'name': 'Static Docker', **build_docker_stats} if build_docker_stats['total'] > 0 else None
            ]
        })
    
    # Test Nodes
    if 'Test Nodes' in categories:
        test_stats = categories['Test Nodes']
        combined_total = test_stats['total'] + test_docker_stats['total']
        combined_online = test_stats['online'] + test_docker_stats['online']
        combined_offline = test_stats['offline'] + test_docker_stats['offline']
        
        quick_stats.append({
            'category': 'Test Nodes',
            'total': combined_total,
            'online': combined_online,
            'offline': combined_offline,
            'subcategories': [
                {'name': 'Non-Docker', **test_stats} if test_stats['total'] > 0 else None,
                {'name': 'Static Docker', **test_docker_stats} if test_docker_stats['total'] > 0 else None
            ]
        })
    
    # Other categories
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
            quick_stats.append({
                'category': category,
                'total': stats['total'],
                'online': stats['online'],
                'offline': stats['offline'],
                'subcategories': []
            })
    
    return quick_stats


def prepare_excluded_quick_stats(excluded_nodes, categories):
    """Prepare quick stats data for excluded nodes.
    
    Args:
        excluded_nodes: List of excluded JenkinsNode instances
        categories: Dictionary of categorized nodes
        
    Returns:
        List of quick stats dictionaries for excluded nodes
    """
    # Separate static docker nodes by their function prefix
    static_docker_nodes = [n for n in excluded_nodes if get_node_category(n.name) == 'Static Docker Nodes']
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
    
    excluded_quick_stats = []
    
    # Build Nodes
    if 'Build Nodes' in categories:
        build_stats = categories['Build Nodes']
        combined_total = build_stats['total'] + build_docker_stats['total']
        combined_online = build_stats['online'] + build_docker_stats['online']
        combined_offline = build_stats['offline'] + build_docker_stats['offline']
        
        if combined_total > 0:
            excluded_quick_stats.append({
                'category': 'Build Nodes',
                'total': combined_total,
                'online': combined_online,
                'offline': combined_offline,
                'subcategories': [
                    {'name': 'Non-Docker', **build_stats} if build_stats['total'] > 0 else None,
                    {'name': 'Static Docker', **build_docker_stats} if build_docker_stats['total'] > 0 else None
                ]
            })
    
    # Test Nodes
    if 'Test Nodes' in categories:
        test_stats = categories['Test Nodes']
        combined_total = test_stats['total'] + test_docker_stats['total']
        combined_online = test_stats['online'] + test_docker_stats['online']
        combined_offline = test_stats['offline'] + test_docker_stats['offline']
        
        if combined_total > 0:
            excluded_quick_stats.append({
                'category': 'Test Nodes',
                'total': combined_total,
                'online': combined_online,
                'offline': combined_offline,
                'subcategories': [
                    {'name': 'Non-Docker', **test_stats} if test_stats['total'] > 0 else None,
                    {'name': 'Static Docker', **test_docker_stats} if test_docker_stats['total'] > 0 else None
                ]
            })
    
    # Other categories
    other_categories = [
        'Docker Host Nodes',
        'Controller Nodes',
        'Infrastructure Nodes',
        'Service Nodes',
        'Other Nodes'
    ]
    
    for category in other_categories:
        if category in categories and categories[category]['total'] > 0:
            stats = categories[category]
            excluded_quick_stats.append({
                'category': category,
                'total': stats['total'],
                'online': stats['online'],
                'offline': stats['offline'],
                'subcategories': []
            })
    
    return excluded_quick_stats


def prepare_detailed_nodes(nodes):
    """Prepare detailed node information for display."""
    categorized_nodes = {}
    for node in nodes:
        category = get_node_category(node.name)
        provider = extract_provider_from_name(node.name)
        
        if category not in categorized_nodes:
            categorized_nodes[category] = {}
        
        if provider not in categorized_nodes[category]:
            categorized_nodes[category][provider] = []
        
        node_data = {
            'name': node.name,
            'os': extract_os_from_name(node.name),
            'os_type': get_os_type(extract_os_from_name(node.name)),
            'arch': get_node_architecture(node),
            'container_host': extract_container_host(node),
            'status': 'OFFLINE' if node.offline else 'ONLINE',
            'temp_offline': node.temporarily_offline,
            'executors': node.num_executors,
            'busy': node.busy_executors,
            'idle': node.idle_executors,
            'offline_cause': node.offline_cause,
            'labels': node.labels
        }
        
        categorized_nodes[category][provider].append(node_data)
    
    # Sort nodes within each provider
    for category in categorized_nodes:
        for provider in categorized_nodes[category]:
            categorized_nodes[category][provider].sort(key=lambda n: n['name'])
    
    return categorized_nodes


def generate_function_os_arch_summary(nodes):
    """
    Generate a summary table of nodes by function, OS type, and architecture.
    
    Args:
        nodes: List of JenkinsNode instances
        
    Returns:
        List of dictionaries with function, os_type, arch, count, online, offline
    """
    from main import get_node_category, extract_os_from_name, get_os_type, get_node_architecture
    
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


def get_cloud_capacity_data():
    """Get cloud capacity data from clouds.xml file."""
    try:
        config = Config.from_env()
        clouds_xml_path = Path(config.cloud_config_file)
        
        if not clouds_xml_path.exists():
            logger.warning(f"Clouds XML file not found: {clouds_xml_path}")
            logger.warning("Cloud capacity reporting is disabled. See README.md for setup instructions.")
            return []
        
        clouds = parse_clouds_xml(str(clouds_xml_path))
        # Sort by name for consistent display
        clouds.sort(key=lambda c: c.name.lower())
        return clouds
    except Exception as e:
        logger.error(f"Error parsing clouds XML: {e}")
        return []


def is_cloud_config_available():
    """Check if cloud configuration file is available."""
    try:
        config = Config.from_env()
        clouds_xml_path = Path(config.cloud_config_file)
        exists = clouds_xml_path.exists()
        abs_path = clouds_xml_path.absolute()
        logger.info(f"Cloud config check: path='{config.cloud_config_file}', absolute='{abs_path}', exists={exists}")
        return exists
    except Exception as e:
        logger.error(f"Error checking cloud config availability: {e}")
        return False

def recalculate_summary(nodes):
    """Recalculate capacity summary for a filtered list of nodes.
    
    Args:
        nodes: List of JenkinsNode instances
        
    Returns:
        CapacitySummary object with recalculated statistics
    """
    from src.models import CapacitySummary
    
    total_nodes = len(nodes)
    online_nodes = sum(1 for n in nodes if not n.offline)
    offline_nodes = total_nodes - online_nodes
    
    total_executors = sum(n.num_executors for n in nodes if not n.offline)
    busy_executors = sum(n.busy_executors for n in nodes if not n.offline)
    idle_executors = sum(n.idle_executors for n in nodes if not n.offline)
    
    utilization = (busy_executors / total_executors * 100) if total_executors > 0 else 0.0
    
    # Recalculate labels summary
    labels_summary = {}
    for node in nodes:
        if node.offline:
            continue
        for label in node.labels:
            if label not in labels_summary:
                labels_summary[label] = {
                    'nodes': 0,
                    'executors': 0,
                    'busy': 0,
                    'idle': 0,
                    'online_nodes': 0
                }
            labels_summary[label]['nodes'] += 1
            labels_summary[label]['online_nodes'] += 1
            labels_summary[label]['executors'] += node.num_executors
            labels_summary[label]['busy'] += node.busy_executors
            labels_summary[label]['idle'] += node.idle_executors
    
    return CapacitySummary(
        total_nodes=total_nodes,
        online_nodes=online_nodes,
        offline_nodes=offline_nodes,
        total_executors=total_executors,
        busy_executors=busy_executors,
        idle_executors=idle_executors,
        utilization_percentage=round(utilization, 2),
        labels_summary=labels_summary
    )


def filter_excluded_nodes(nodes):
    """Filter out excluded nodes from the list.
    
    Args:
        nodes: List of JenkinsNode instances
        
    Returns:
        Tuple of (active_nodes, excluded_nodes)
    """
    manager = get_excluded_nodes_manager()
    active_nodes = []
    excluded_nodes = []
    
    for node in nodes:
        if manager.is_excluded(node.name):
            excluded_nodes.append(node)
        else:
            active_nodes.append(node)
    
    return active_nodes, excluded_nodes


def prepare_excluded_nodes_data(excluded_nodes):
    """Prepare excluded nodes data for display.
    
    Args:
        excluded_nodes: List of excluded JenkinsNode instances
        
    Returns:
        Dictionary with categorized excluded nodes
    """
    categorized = {}
    manager = get_excluded_nodes_manager()
    
    for node in excluded_nodes:
        category = get_node_category(node.name)
        provider = extract_provider_from_name(node.name)
        
        if category not in categorized:
            categorized[category] = {}
        
        if provider not in categorized[category]:
            categorized[category][provider] = []
        
        # Get the exclusion reason for this node
        exclusion_reason = manager.get_reason(node.name)
        
        node_data = {
            'name': node.name,
            'os': extract_os_from_name(node.name),
            'os_type': get_os_type(extract_os_from_name(node.name)),
            'arch': get_node_architecture(node),
            'container_host': extract_container_host(node),
            'status': 'OFFLINE' if node.offline else 'ONLINE',
            'temp_offline': node.temporarily_offline,
            'executors': node.num_executors,
            'busy': node.busy_executors,
            'idle': node.idle_executors,
            'offline_cause': node.offline_cause,
            'labels': node.labels,
            'exclusion_reason': exclusion_reason
        }
        
        categorized[category][provider].append(node_data)
    
    # Sort nodes within each provider
    for category in categorized:
        for provider in categorized[category]:
            categorized[category][provider].sort(key=lambda n: n['name'])
    
    return categorized



@app.route('/login')
def login_page():
    """Login page."""
    return render_template('login.html')


@app.route('/')
@optional_auth
def index():
    """Main dashboard page."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return render_template('error.html', error="Failed to fetch Jenkins data")
    
    # Filter out excluded nodes
    active_nodes, excluded_nodes = filter_excluded_nodes(all_nodes)
    
    # Recalculate summary using only active nodes
    active_summary = recalculate_summary(active_nodes)
    
    # Prepare data using only active nodes
    categories = categorize_nodes_by_function_and_provider(active_nodes)
    quick_stats = prepare_quick_stats(active_nodes, categories)
    detailed_nodes = prepare_detailed_nodes(active_nodes)
    func_os_arch_summary = generate_function_os_arch_summary(active_nodes)
    
    # Prepare excluded nodes data
    excluded_nodes_data = prepare_excluded_nodes_data(excluded_nodes)
    excluded_count = len(excluded_nodes)
    
    # Prepare quick stats for excluded nodes
    excluded_categories = categorize_nodes_by_function_and_provider(excluded_nodes)
    excluded_quick_stats = prepare_excluded_quick_stats(excluded_nodes, excluded_categories)
    
    cloud_capacity = get_cloud_capacity_data()
    cloud_config_available = is_cloud_config_available()
    
    # Get current user role for UI permissions
    current_user = get_current_user()
    current_role = get_current_user_role()
    
    return render_template(
        'dashboard.html',
        summary=active_summary,
        quick_stats=quick_stats,
        func_os_arch_summary=func_os_arch_summary,
        detailed_nodes=detailed_nodes,
        excluded_nodes=excluded_nodes_data,
        excluded_count=excluded_count,
        excluded_quick_stats=excluded_quick_stats,
        cloud_capacity=cloud_capacity,
        cloud_config_available=cloud_config_available,
        timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        current_user=current_user,
        current_role=current_role
    )


@app.route('/api/refresh')
def refresh_data():
    """API endpoint to refresh data and record metrics snapshot."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return jsonify({'error': 'Failed to fetch Jenkins data'}), 500
    
    # Filter out excluded nodes
    active_nodes, excluded_nodes = filter_excluded_nodes(all_nodes)
    
    # Recalculate summary using only active nodes
    active_summary = recalculate_summary(active_nodes)
    
    # Calculate category-specific metrics
    category_metrics = calculate_category_metrics(all_nodes, excluded_nodes)
    
    # Record metrics snapshot
    try:
        tracker = get_metrics_tracker()
        snapshot = tracker.record_snapshot(
            total_nodes=active_summary.total_nodes,
            online_nodes=active_summary.online_nodes,
            offline_nodes=active_summary.offline_nodes,
            excluded_nodes=len(excluded_nodes),
            total_executors=active_summary.total_executors,
            busy_executors=active_summary.busy_executors,
            idle_executors=active_summary.idle_executors,
            utilization_percentage=active_summary.utilization_percentage,
            **category_metrics
        )
        logger.info(f"Metrics snapshot recorded on refresh at {snapshot.timestamp}")
    except Exception as e:
        logger.error(f"Failed to record metrics snapshot on refresh: {e}")
        # Don't fail the refresh if metrics recording fails
    
    categories = categorize_nodes_by_function_and_provider(active_nodes)
    quick_stats = prepare_quick_stats(active_nodes, categories)
    
    return jsonify({
        'summary': active_summary.model_dump(),
        'quick_stats': quick_stats,
        'timestamp': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        'metrics_recorded': True
    })


@app.route('/api/metrics/record', methods=['POST'])
@require_admin
def record_metrics():
    """API endpoint to record a metrics snapshot."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return jsonify({'error': 'Failed to fetch Jenkins data'}), 500
    
    # Filter out excluded nodes
    active_nodes, excluded_nodes = filter_excluded_nodes(all_nodes)
    
    # Recalculate summary using only active nodes
    active_summary = recalculate_summary(active_nodes)
    
    # Calculate category-specific metrics
    category_metrics = calculate_category_metrics(all_nodes, excluded_nodes)
    
    # Record the snapshot
    tracker = get_metrics_tracker()
    snapshot = tracker.record_snapshot(
        total_nodes=active_summary.total_nodes,
        online_nodes=active_summary.online_nodes,
        offline_nodes=active_summary.offline_nodes,
        excluded_nodes=len(excluded_nodes),
        total_executors=active_summary.total_executors,
        busy_executors=active_summary.busy_executors,
        idle_executors=active_summary.idle_executors,
        utilization_percentage=active_summary.utilization_percentage,
        **category_metrics
    )
    
    return jsonify({
        'success': True,
        'snapshot': snapshot.to_dict(),
        'message': 'Metrics snapshot recorded successfully'
    })


@app.route('/api/metrics/snapshots')
def get_metrics_snapshots():
    """API endpoint to get metrics snapshots."""
    limit = request.args.get('limit', default=100, type=int)
    
    tracker = get_metrics_tracker()
    snapshots = tracker.get_recent_snapshots(limit=limit)
    
    return jsonify({
        'snapshots': [s.to_dict() for s in snapshots],
        'count': len(snapshots)
    })


@app.route('/api/metrics/statistics')
def get_metrics_statistics():
    """API endpoint to get metrics statistics."""
    tracker = get_metrics_tracker()
    stats = tracker.get_statistics()
    
    return jsonify(stats)


@app.route('/api/metrics/clear', methods=['POST'])
@require_admin
def clear_metrics():
    """API endpoint to clear all metrics history."""
    tracker = get_metrics_tracker()
    count = tracker.clear_history()
    
    return jsonify({
        'success': True,
        'cleared_count': count,
        'message': f'Cleared {count} metrics snapshots'
    })

# ============================================================================
# Authentication and User Management API Endpoints
# ============================================================================

@app.route('/api/auth/login', methods=['POST'])
def login():
    """API endpoint for user authentication."""
    if not config.rbac_enabled:
        return jsonify({
            'error': 'RBAC is disabled',
            'message': 'Authentication is not required when RBAC is disabled'
        }), 400
    
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({
            'error': 'Missing credentials',
            'message': 'Both username and password are required'
        }), 400
    
    user_manager = get_user_manager()
    
    if user_manager.authenticate(username, password):
        # Create session
        token = session_manager.create_session(username)
        user = user_manager.get_user(username)
        
        return jsonify({
            'success': True,
            'token': token,
            'user': {
                'username': username,
                'role': user.get('role'),
                'email': user.get('email')
            },
            'message': f'Welcome, {username}!'
        })
    else:
        return jsonify({
            'error': 'Authentication failed',
            'message': 'Invalid username or password'
        }), 401


@app.route('/api/auth/logout', methods=['POST'])
@require_auth
def logout():
    """API endpoint for user logout."""
    from src.auth import get_auth_token
    
    token = get_auth_token()
    if token:
        session_manager.invalidate_session(token)
    
    return jsonify({
        'success': True,
        'message': 'Logged out successfully'
    })


@app.route('/api/auth/me', methods=['GET'])
@require_auth
def get_current_user_info():
    """API endpoint to get current user information."""
    username = get_current_user()
    user_manager = get_user_manager()
    user = user_manager.get_user(username)
    
    if not user:
        return jsonify({
            'error': 'User not found'
        }), 404
    
    return jsonify({
        'user': user
    })


@app.route('/api/auth/change-password', methods=['POST'])
@require_auth
def change_password():
    """API endpoint to change user password."""
    data = request.get_json()
    current_password = data.get('current_password')
    new_password = data.get('new_password')
    
    if not current_password or not new_password:
        return jsonify({
            'error': 'Missing required fields',
            'message': 'Both current_password and new_password are required'
        }), 400
    
    username = get_current_user()
    user_manager = get_user_manager()
    
    # Verify current password
    if not user_manager.authenticate(username, current_password):
        return jsonify({
            'error': 'Authentication failed',
            'message': 'Current password is incorrect'
        }), 401
    
    # Update password
    if user_manager.update_password(username, new_password):
        # Invalidate all sessions for this user (force re-login)
        session_manager.invalidate_user_sessions(username)
        
        return jsonify({
            'success': True,
            'message': 'Password changed successfully. Please log in again.'
        })
    else:
        return jsonify({
            'error': 'Failed to update password'
        }), 500


@app.route('/api/users', methods=['GET'])
@require_admin
def list_users():
    """API endpoint to list all users (admin only)."""
    user_manager = get_user_manager()
    users = user_manager.list_users()
    
    return jsonify({
        'users': users,
        'count': len(users)
    })


@app.route('/api/users/create', methods=['POST'])
@require_admin
def create_user():
    """API endpoint to create a new user (admin only)."""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    role = data.get('role', 'viewer')
    email = data.get('email', '')
    
    if not username or not password:
        return jsonify({
            'error': 'Missing required fields',
            'message': 'Both username and password are required'
        }), 400
    
    if role not in ['viewer', 'operator', 'admin']:
        return jsonify({
            'error': 'Invalid role',
            'message': 'Role must be one of: viewer, operator, admin'
        }), 400
    
    user_manager = get_user_manager()
    current_user = get_current_user()
    
    if user_manager.create_user(username, password, role, email, current_user):
        return jsonify({
            'success': True,
            'username': username,
            'role': role,
            'message': f'User {username} created successfully'
        }), 201
    else:
        return jsonify({
            'error': 'User already exists',
            'message': f'Username {username} is already taken'
        }), 409


@app.route('/api/users/<username>', methods=['DELETE'])
@require_admin
def delete_user(username):
    """API endpoint to delete a user (admin only)."""
    current_user = get_current_user()
    
    # Check if deletion is allowed
    can_delete, reason = can_delete_user(current_user, username)
    if not can_delete:
        return jsonify({
            'error': 'Cannot delete user',
            'message': reason
        }), 403
    
    user_manager = get_user_manager()
    
    if user_manager.delete_user(username, current_user):
        # Invalidate all sessions for the deleted user
        session_manager.invalidate_user_sessions(username)
        
        return jsonify({
            'success': True,
            'message': f'User {username} deleted successfully'
        })
    else:
        return jsonify({
            'error': 'User not found',
            'message': f'User {username} does not exist'
        }), 404


@app.route('/api/users/<username>/role', methods=['PUT'])
@require_admin
def update_user_role(username):
    """API endpoint to update a user's role (admin only)."""
    data = request.get_json()
    new_role = data.get('role')
    
    if not new_role:
        return jsonify({
            'error': 'Missing required field',
            'message': 'role is required'
        }), 400
    
    if new_role not in ['viewer', 'operator', 'admin']:
        return jsonify({
            'error': 'Invalid role',
            'message': 'Role must be one of: viewer, operator, admin'
        }), 400
    
    user_manager = get_user_manager()
    current_user = get_current_user()
    
    # Check if user can modify this user
    can_modify, reason = can_modify_user(current_user, username)
    if not can_modify:
        return jsonify({
            'error': 'Cannot modify user',
            'message': reason
        }), 403
    
    if user_manager.update_role(username, new_role, current_user):
        return jsonify({
            'success': True,
            'username': username,
            'new_role': new_role,
            'message': f'Role updated to {new_role} for user {username}'
        })
    else:
        return jsonify({
            'error': 'User not found',
            'message': f'User {username} does not exist'
        }), 404


@app.route('/api/users/<username>/disable', methods=['POST'])
@require_admin
def disable_user(username):
    """API endpoint to disable a user account (admin only)."""
    current_user = get_current_user()
    
    if current_user == username:
        return jsonify({
            'error': 'Cannot disable own account',
            'message': 'You cannot disable your own account'
        }), 403
    
    user_manager = get_user_manager()
    
    if user_manager.disable_user(username):
        # Invalidate all sessions for the disabled user
        session_manager.invalidate_user_sessions(username)
        
        return jsonify({
            'success': True,
            'message': f'User {username} disabled successfully'
        })
    else:
        return jsonify({
            'error': 'User not found',
            'message': f'User {username} does not exist'
        }), 404


@app.route('/api/users/<username>/enable', methods=['POST'])
@require_admin
def enable_user(username):
    """API endpoint to enable a user account (admin only)."""
    user_manager = get_user_manager()
    
    if user_manager.enable_user(username):
        return jsonify({
            'success': True,
            'message': f'User {username} enabled successfully'
        })
    else:
        return jsonify({
            'error': 'User not found',
            'message': f'User {username} does not exist'
        }), 404


@app.route('/api/rbac/roles', methods=['GET'])
def get_roles():
    """API endpoint to get role descriptions and permissions."""
    return jsonify({
        'roles': get_role_permissions(),
        'rbac_enabled': config.rbac_enabled
    })


@app.route('/api/rbac/status', methods=['GET'])
def get_rbac_status():
    """API endpoint to check if RBAC is enabled."""
    return jsonify({
        'rbac_enabled': config.rbac_enabled,
        'message': 'RBAC is enabled' if config.rbac_enabled else 'RBAC is disabled - all endpoints are accessible'
    })


@app.route('/api/excluded-nodes', methods=['GET'])
@optional_auth
def get_excluded_nodes():
    """API endpoint to get all excluded nodes with their reasons."""
    manager = get_excluded_nodes_manager()
    nodes_with_reasons = manager.get_all_with_reasons()
    
    return jsonify({
        'excluded_nodes': manager.get_all(),
        'excluded_nodes_with_reasons': nodes_with_reasons,
        'count': len(manager.get_all())
    })


@app.route('/api/excluded-nodes/add', methods=['POST'])
@require_admin
def add_excluded_node():
    """API endpoint to add a node to the excluded list with an optional reason (admin only)."""
    data = request.get_json()
    node_name = data.get('node_name')
    reason = data.get('reason', '')
    
    if not node_name:
        return jsonify({'error': 'node_name is required'}), 400
    
    manager = get_excluded_nodes_manager()
    added = manager.add(node_name, reason)
    
    current_user = get_current_user()
    logger.info(f"User '{current_user}' added node '{node_name}' to excluded list")
    
    return jsonify({
        'success': True,
        'added': added,
        'node_name': node_name,
        'reason': reason,
        'message': f"Node '{node_name}' added to excluded list" if added else f"Node '{node_name}' already excluded"
    })


@app.route('/api/excluded-nodes/remove', methods=['POST'])
@require_admin
def remove_excluded_node():
    """API endpoint to remove a node from the excluded list and delete its reason (admin only)."""
    data = request.get_json()
    node_name = data.get('node_name')
    
    if not node_name:
        return jsonify({'error': 'node_name is required'}), 400
    
    manager = get_excluded_nodes_manager()
    removed = manager.remove(node_name)
    
    current_user = get_current_user()
    logger.info(f"User '{current_user}' removed node '{node_name}' from excluded list")
    
    return jsonify({
        'success': True,
        'removed': removed,
        'node_name': node_name,
        'message': f"Node '{node_name}' removed from excluded list and reason deleted" if removed else f"Node '{node_name}' not in excluded list"
    })


@app.route('/api/excluded-nodes/set-reason', methods=['POST'])
@require_admin
def set_exclusion_reason():
    """API endpoint to set or update the exclusion reason for a node (admin only)."""
    data = request.get_json()
    node_name = data.get('node_name')
    reason = data.get('reason', '')
    
    if not node_name:
        return jsonify({'error': 'node_name is required'}), 400
    
    manager = get_excluded_nodes_manager()
    
    # Check if node is excluded
    if not manager.is_excluded(node_name):
        return jsonify({
            'error': f"Node '{node_name}' is not in the excluded list"
        }), 404
    
    success = manager.set_reason(node_name, reason)
    
    current_user = get_current_user()
    logger.info(f"User '{current_user}' updated exclusion reason for node '{node_name}'")
    
    return jsonify({
        'success': success,
        'node_name': node_name,
        'reason': reason,
        'message': f"Updated exclusion reason for node '{node_name}'"
    })


@app.route('/api/excluded-nodes/get-reason/<node_name>', methods=['GET'])
@optional_auth
def get_exclusion_reason(node_name):
    """API endpoint to get the exclusion reason for a specific node."""
    manager = get_excluded_nodes_manager()
    
    if not manager.is_excluded(node_name):
        return jsonify({
            'error': f"Node '{node_name}' is not in the excluded list"
        }), 404
    
    reason = manager.get_reason(node_name)
    
    return jsonify({
        'node_name': node_name,
        'reason': reason or '',
        'is_excluded': True
    })


@app.route('/api/excluded-nodes/clear', methods=['POST'])
@require_admin
def clear_excluded_nodes():
    """API endpoint to clear all excluded nodes and their reasons (admin only)."""
    manager = get_excluded_nodes_manager()
    count = manager.clear()
    
    current_user = get_current_user()
    logger.info(f"User '{current_user}' cleared all {count} excluded nodes")
    
    return jsonify({
        'success': True,
        'cleared_count': count,
        'message': f"Cleared {count} nodes from excluded list"
    })



@app.route('/node/<node_name>')
@optional_auth
def node_detail(node_name):
    """Node detail page."""
    nodes, summary = get_jenkins_data()
    
    if nodes is None or summary is None:
        return render_template('error.html', error="Failed to fetch Jenkins data")
    
    # Find the specific node (search in all nodes, including excluded)
    detailed_nodes = prepare_detailed_nodes(nodes)
    node_data = None
    
    for category in detailed_nodes:
        for provider in detailed_nodes[category]:
            for node in detailed_nodes[category][provider]:
                if node['name'] == node_name:
                    node_data = node
                    break
            if node_data:
                break
        if node_data:
            break
    
    if node_data is None:
        return render_template('error.html', error=f"Node '{node_name}' not found")
    
    # Check if node is excluded
    manager = get_excluded_nodes_manager()
    is_excluded = manager.is_excluded(node_name)
    
    cloud_config_available = is_cloud_config_available()
    
    # Get current user role for UI permissions
    current_user = get_current_user()
    current_role = get_current_user_role()
    
    return render_template(
        'node_detail.html',
        node=node_data,
        is_excluded=is_excluded,
        current_user=current_user,
        current_role=current_role,
        cloud_config_available=cloud_config_available
    )


@app.route('/category/<category_name>')
def category_listing(category_name):
    """Category listing page showing all nodes of a specific type."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return render_template('error.html', error="Failed to fetch Jenkins data")
    
    # Filter out excluded nodes
    active_nodes, _ = filter_excluded_nodes(all_nodes)
    
    # Prepare detailed nodes
    detailed_nodes = prepare_detailed_nodes(active_nodes)
    
    # Map URL-friendly category names to actual category names
    category_mapping = {
        'build': 'Build Nodes',
        'test': 'Test Nodes',
        'docker-host': 'Docker Host Nodes',
        'controller': 'Controller Nodes',
        'infrastructure': 'Infrastructure Nodes',
        'service': 'Service Nodes',
        'other': 'Other Nodes',
        'static-docker': 'Static Docker Nodes',
        'dynamic': 'Dynamic Nodes'
    }
    
    actual_category = category_mapping.get(category_name.lower())
    
    if actual_category is None:
        return render_template('error.html', error=f"Category '{category_name}' not found")
    
    # Get nodes for this category
    category_nodes = []
    if actual_category in detailed_nodes:
        for provider in detailed_nodes[actual_category]:
            for node in detailed_nodes[actual_category][provider]:
                category_nodes.append(node)
    
    # For Build and Test nodes, also include Static Docker nodes with matching prefix
    if actual_category in ['Build Nodes', 'Test Nodes']:
        prefix = 'build-' if actual_category == 'Build Nodes' else 'test-'
        if 'Static Docker Nodes' in detailed_nodes:
            for provider in detailed_nodes['Static Docker Nodes']:
                for node in detailed_nodes['Static Docker Nodes'][provider]:
                    if node['name'].lower().startswith(prefix):
                        category_nodes.append(node)
    
    # Sort nodes by name
    category_nodes.sort(key=lambda n: n['name'])
    
    # Calculate stats
    total_nodes = len(category_nodes)
    online_nodes = sum(1 for n in category_nodes if n['status'] == 'ONLINE')
    offline_nodes = total_nodes - online_nodes
    
    cloud_config_available = is_cloud_config_available()
    return render_template(
        'category_listing.html',
        category=actual_category,
        nodes=category_nodes,
        total=total_nodes,
        online=online_nodes,
        offline=offline_nodes,
        cloud_config_available=cloud_config_available
    )


@app.route('/category/<category_name>/<subcategory>')
def subcategory_listing(category_name, subcategory):
    """Subcategory listing page showing Docker or non-Docker nodes."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return render_template('error.html', error="Failed to fetch Jenkins data")
    
    # Filter out excluded nodes
    active_nodes, _ = filter_excluded_nodes(all_nodes)
    
    # Prepare detailed nodes
    detailed_nodes = prepare_detailed_nodes(active_nodes)
    
    # Map URL-friendly category names to actual category names
    category_mapping = {
        'build': 'Build Nodes',
        'test': 'Test Nodes'
    }
    
    actual_category = category_mapping.get(category_name.lower())
    
    if actual_category is None:
        return render_template('error.html', error=f"Category '{category_name}' not found")
    
    # Validate subcategory
    if subcategory.lower() not in ['docker', 'non-docker']:
        return render_template('error.html', error=f"Subcategory '{subcategory}' not found")
    
    # Get nodes based on subcategory
    category_nodes = []
    
    if subcategory.lower() == 'docker':
        # Get Static Docker nodes with matching prefix
        prefix = 'build-' if actual_category == 'Build Nodes' else 'test-'
        if 'Static Docker Nodes' in detailed_nodes:
            for provider in detailed_nodes['Static Docker Nodes']:
                for node in detailed_nodes['Static Docker Nodes'][provider]:
                    if node['name'].lower().startswith(prefix):
                        category_nodes.append(node)
        display_category = f"{actual_category} - Static Docker"
    else:
        # Get non-Docker nodes
        if actual_category in detailed_nodes:
            for provider in detailed_nodes[actual_category]:
                for node in detailed_nodes[actual_category][provider]:
                    category_nodes.append(node)
        display_category = f"{actual_category} - Non-Docker"
    
    # Sort nodes by name
    category_nodes.sort(key=lambda n: n['name'])
    
    # Calculate stats
    total_nodes = len(category_nodes)
    online_nodes = sum(1 for n in category_nodes if n['status'] == 'ONLINE')
    offline_nodes = total_nodes - online_nodes
    
    cloud_config_available = is_cloud_config_available()
    return render_template(
        'category_listing.html',
        category=display_category,
        nodes=category_nodes,
        total=total_nodes,
        online=online_nodes,
        offline=offline_nodes,
        cloud_config_available=cloud_config_available
    )


@app.route('/filter/arch/<arch_name>')
def filter_by_arch(arch_name):
    """Filter nodes by architecture."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return render_template('error.html', error="Failed to fetch Jenkins data")
    
    # Filter out excluded nodes
    active_nodes, _ = filter_excluded_nodes(all_nodes)
    
    detailed_nodes = prepare_detailed_nodes(active_nodes)
    filtered_nodes = []
    
    for category in detailed_nodes:
        for provider in detailed_nodes[category]:
            for node in detailed_nodes[category][provider]:
                if node['arch'].lower() == arch_name.lower():
                    filtered_nodes.append(node)
    
    filtered_nodes.sort(key=lambda n: n['name'])
    
    total_nodes = len(filtered_nodes)
    online_nodes = sum(1 for n in filtered_nodes if n['status'] == 'ONLINE')
    offline_nodes = total_nodes - online_nodes
    
    return render_template(
        'category_listing.html',
        category=f"Architecture: {arch_name}",
        nodes=filtered_nodes,
        total=total_nodes,
        online=online_nodes,
        offline=offline_nodes
    )


@app.route('/filter/os/<os_name>')
def filter_by_os(os_name):
    """Filter nodes by operating system."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return render_template('error.html', error="Failed to fetch Jenkins data")
    
    # Filter out excluded nodes
    active_nodes, _ = filter_excluded_nodes(all_nodes)
    
    detailed_nodes = prepare_detailed_nodes(active_nodes)
    filtered_nodes = []
    
    for category in detailed_nodes:
        for provider in detailed_nodes[category]:
            for node in detailed_nodes[category][provider]:
                if node['os'].lower() == os_name.lower():
                    filtered_nodes.append(node)
    
    filtered_nodes.sort(key=lambda n: n['name'])
    
    total_nodes = len(filtered_nodes)
    online_nodes = sum(1 for n in filtered_nodes if n['status'] == 'ONLINE')
    offline_nodes = total_nodes - online_nodes
    
    return render_template(
        'category_listing.html',
        category=f"Operating System: {os_name}",
        nodes=filtered_nodes,
        total=total_nodes,
        online=online_nodes,
        offline=offline_nodes
    )


@app.route('/filter/os-type/<os_type>')
def filter_by_os_type(os_type):
    """Filter nodes by OS type (Linux/Windows)."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return render_template('error.html', error="Failed to fetch Jenkins data")
    
    # Filter out excluded nodes
    active_nodes, _ = filter_excluded_nodes(all_nodes)
    
    detailed_nodes = prepare_detailed_nodes(active_nodes)
    filtered_nodes = []
    
    for category in detailed_nodes:
        for provider in detailed_nodes[category]:
            for node in detailed_nodes[category][provider]:
                if node['os_type'].lower() == os_type.lower():
                    filtered_nodes.append(node)
    
    filtered_nodes.sort(key=lambda n: n['name'])
    
    total_nodes = len(filtered_nodes)
    online_nodes = sum(1 for n in filtered_nodes if n['status'] == 'ONLINE')
    offline_nodes = total_nodes - online_nodes
    
    return render_template(
        'category_listing.html',
        category=f"OS Type: {os_type}",
        nodes=filtered_nodes,
        total=total_nodes,
        online=online_nodes,
        offline=offline_nodes
    )


@app.route('/filter/status/<status>')
def filter_by_status(status):
    """Filter nodes by status (online/offline)."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return render_template('error.html', error="Failed to fetch Jenkins data")
    
    # Validate status
    if status.lower() not in ['online', 'offline']:
        return render_template('error.html', error=f"Invalid status '{status}'")
    
    # Filter out excluded nodes
    active_nodes, _ = filter_excluded_nodes(all_nodes)
    
    detailed_nodes = prepare_detailed_nodes(active_nodes)
    filtered_nodes = []
    
    for category in detailed_nodes:
        for provider in detailed_nodes[category]:
            for node in detailed_nodes[category][provider]:
                if status.lower() == 'online' and node['status'] == 'ONLINE':
                    filtered_nodes.append(node)
                elif status.lower() == 'offline' and node['status'] == 'OFFLINE':
                    filtered_nodes.append(node)
    
    filtered_nodes.sort(key=lambda n: n['name'])
    
    total_nodes = len(filtered_nodes)
    online_nodes = sum(1 for n in filtered_nodes if n['status'] == 'ONLINE')
    offline_nodes = total_nodes - online_nodes
    
    cloud_config_available = is_cloud_config_available()
    return render_template(
        'category_listing.html',
        category=f"Status: {status.upper()}",
        nodes=filtered_nodes,
        total=total_nodes,
        online=online_nodes,
        offline=offline_nodes,
        cloud_config_available=cloud_config_available
    )


@app.route('/label/<label_name>')
def label_summary(label_name):
    """Label summary page showing all nodes with a specific label."""
    all_nodes, summary = get_jenkins_data()
    
    if all_nodes is None or summary is None:
        return render_template('error.html', error="Failed to fetch Jenkins data")
    
    # Filter out excluded nodes
    active_nodes, _ = filter_excluded_nodes(all_nodes)
    
    # Filter nodes that have this label
    detailed_nodes = prepare_detailed_nodes(active_nodes)
    nodes_with_label = []
    
    for category in detailed_nodes:
        for provider in detailed_nodes[category]:
            for node in detailed_nodes[category][provider]:
                if label_name in node['labels']:
                    nodes_with_label.append(node)
    
    # Sort nodes by name
    nodes_with_label.sort(key=lambda n: n['name'])
    
    # Get label summary from the summary object
    label_stats = summary.labels_summary.get(label_name, {
        'nodes': 0,
        'executors': 0,
        'busy': 0,
        'idle': 0,
        'online_nodes': 0
    })
    
    cloud_config_available = is_cloud_config_available()
    return render_template(
        'label_summary.html',
        label=label_name,
        nodes=nodes_with_label,
        summary=label_stats,
        cloud_config_available=cloud_config_available
    )


@app.route('/cloud-statistics')
def cloud_statistics():
    """Cloud statistics page showing detailed template information."""
    try:
        clouds = get_cloud_capacity_data()
        cloud_config_available = is_cloud_config_available()
        
        return render_template(
            'cloud_statistics.html',
            clouds=clouds,
            cloud_config_available=cloud_config_available,
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        )
    except Exception as e:
        logger.error(f"Error loading cloud statistics: {e}")
        return render_template('error.html', error=f"Failed to load cloud statistics: {str(e)}")

@app.route('/metrics-history')
@optional_auth
def metrics_history():
    """Metrics history page showing historical capacity data."""
    try:
        tracker = get_metrics_tracker()
        
        # Get current month snapshots only
        current_month_snapshots = tracker.get_current_month_snapshots()
        # Reverse to show newest first
        snapshots = list(reversed(current_month_snapshots))
        
        # Calculate statistics for current month only
        if current_month_snapshots:
            statistics = {
                'total_snapshots': len(current_month_snapshots),
                'first_recorded': current_month_snapshots[0].timestamp,
                'last_recorded': current_month_snapshots[-1].timestamp,
                'avg_online_percentage': round(
                    sum(s.online_percentage for s in current_month_snapshots) / len(current_month_snapshots), 2
                ),
                'avg_utilization': round(
                    sum(s.utilization_percentage for s in current_month_snapshots) / len(current_month_snapshots), 2
                ),
                'max_nodes': max(s.total_nodes for s in current_month_snapshots),
                'min_nodes': min(s.total_nodes for s in current_month_snapshots),
                'avg_online_nodes': round(
                    sum(s.online_nodes for s in current_month_snapshots) / len(current_month_snapshots), 2
                ),
                'avg_offline_nodes': round(
                    sum(s.offline_nodes for s in current_month_snapshots) / len(current_month_snapshots), 2
                )
            }
        else:
            statistics = {
                'total_snapshots': 0,
                'first_recorded': None,
                'last_recorded': None,
                'avg_online_percentage': 0.0,
                'avg_utilization': 0.0,
                'max_nodes': 0,
                'min_nodes': 0,
                'avg_online_nodes': 0.0,
                'avg_offline_nodes': 0.0
            }
        
        # Get archived monthly summaries
        archived_months = tracker.get_archived_summary()
        
        cloud_config_available = is_cloud_config_available()
        
        # Get current online statistics by function
        current_stats = None
        if snapshots:
            # Get the most recent snapshot for current statistics
            latest_snapshot = snapshots[0]
            current_stats = {
                'build_nodes': {
                    'total': latest_snapshot.build_nodes_total,
                    'online': latest_snapshot.build_nodes_online,
                    'offline': latest_snapshot.build_nodes_offline,
                    'online_percentage': latest_snapshot.build_nodes_online_percentage
                },
                'test_nodes': {
                    'total': latest_snapshot.test_nodes_total,
                    'online': latest_snapshot.test_nodes_online,
                    'offline': latest_snapshot.test_nodes_offline,
                    'online_percentage': latest_snapshot.test_nodes_online_percentage
                },
                'infra_nodes': {
                    'total': latest_snapshot.infra_nodes_total,
                    'online': latest_snapshot.infra_nodes_online,
                    'offline': latest_snapshot.infra_nodes_offline,
                    'online_percentage': latest_snapshot.infra_nodes_online_percentage
                },
                'docker_host_nodes': {
                    'total': latest_snapshot.docker_host_nodes_total,
                    'online': latest_snapshot.docker_host_nodes_online,
                    'offline': latest_snapshot.docker_host_nodes_offline,
                    'online_percentage': latest_snapshot.docker_host_nodes_online_percentage
                }
            }
        
        # Get current user role for UI permissions
        current_user = get_current_user()
        current_role = get_current_user_role()
        
        return render_template(
            'metrics_history.html',
            snapshots=snapshots,
            statistics=statistics,
            current_stats=current_stats,
            archived_months=archived_months,
            current_month=datetime.now().strftime("%B %Y"),
            cloud_config_available=cloud_config_available,
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            current_user=current_user,
            current_role=current_role
        )
    except Exception as e:
        logger.error(f"Error loading metrics history: {e}")
        return render_template('error.html', error=f"Failed to load metrics history: {str(e)}")


@app.route('/archive-metrics', methods=['POST'])
@require_admin
def archive_metrics():
    """Manual trigger for archiving completed months."""
    try:
        tracker = get_metrics_tracker()
        result = tracker.archive_and_cleanup()
        
        return jsonify({
            'success': True,
            'archived_months': result['archived_months'],
            'snapshots_archived': result['snapshots_archived'],
            'current_month_snapshots': result['current_month_snapshots'],
            'message': f"Successfully archived {len(result['archived_months'])} month(s) with {result['snapshots_archived']} snapshots"
        })
    except Exception as e:
        logger.error(f"Error archiving metrics: {e}", exc_info=True)
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500



# Start the metrics scheduler when the app starts
start_metrics_scheduler()


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)

# Made with Bob
