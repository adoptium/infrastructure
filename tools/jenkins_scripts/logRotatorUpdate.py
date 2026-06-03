#!/usr/bin/env python3
"""
Jenkins logRotator Configuration Tool

Safely configure logRotator settings in Jenkins job config.xml files.
Supports both <logRotator> and <jenkins.model.BuildDiscarderProperty> formats.

Features:
1. Set removeLastBuild=true
2. Ensure daysToKeep and artifactDaysToKeep are set (default: 30)
3. Create logRotator if missing with sensible defaults
4. Validate only one logRotator definition exists
5. Support both XML formats (direct logRotator and BuildDiscarderProperty)

NO EXTERNAL DEPENDENCIES - Uses only Python standard library.
Requires: Python 3.6+

Author: Adoptium Infrastructure Team
Version: 2.1.0
"""

import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
import argparse
import re
import fnmatch
import uuid

# Default logRotator configuration values
DEFAULT_DAYS_TO_KEEP = 365
DEFAULT_NUM_TO_KEEP = 5
DEFAULT_ARTIFACT_DAYS_TO_KEEP = 365
DEFAULT_ARTIFACT_NUM_TO_KEEP = 5
DEFAULT_REMOVE_LAST_BUILD = 'true'

def backup_file(config_path, backup_dir, jenkins_home):
    """
    Create a backup of the config file preserving directory structure.
    
    Args:
        config_path: Full path to the config.xml file
        backup_dir: Root directory for backups
        jenkins_home: Jenkins home directory (to calculate relative path)
    
    Returns:
        Path to the backup file
    """
    # Calculate relative path from jenkins_home
    rel_path = os.path.relpath(config_path, jenkins_home)
    
    # Create backup path preserving structure
    backup_path = os.path.join(backup_dir, rel_path)
    
    # Create parent directories if needed
    os.makedirs(os.path.dirname(backup_path), exist_ok=True)
    
    # Copy file
    with open(config_path, 'r') as src:
        with open(backup_path, 'w') as dst:
            dst.write(src.read())
    
    return backup_path

def find_all_logrotators(root):
    """
    Find all logRotator elements in both formats.
    Returns list of tuples: (element, format_type)
    """
    logrotators = []
    
    # Format 1: Direct <logRotator> element under <properties>
    for elem in root.iter('logRotator'):
        logrotators.append((elem, 'direct'))
    
    # Format 2: <strategy class="hudson.tasks.LogRotator"> inside BuildDiscarderProperty
    for elem in root.iter('strategy'):
        if elem.get('class') == 'hudson.tasks.LogRotator':
            # Check if it's inside BuildDiscarderProperty
            for p in root.iter():
                if elem in list(p):
                    if 'BuildDiscarder' in p.tag:
                        logrotators.append((elem, 'build_discarder'))
                        break
    
    return logrotators

def ensure_element(parent, tag, default_value):
    """
    Ensure an element exists with a value, create or update if needed.
    
    Returns:
        tuple: (changed: bool, action: str)
    """
    elem = parent.find(tag)
    if elem is None:
        elem = ET.SubElement(parent, tag)
        elem.text = str(default_value)
        return True, 'created'
    elif elem.text is None or elem.text.strip() == '' or elem.text == '-1':
        elem.text = str(default_value)
        return True, 'set'
    return False, 'unchanged'

def create_logrotator(root):
    """Create a new logRotator element (direct format under properties)."""
    properties = root.find('properties')
    if properties is None:
        properties = ET.SubElement(root, 'properties')
    
    logrotator = ET.SubElement(properties, 'logRotator')
    
    # Set default values
    ET.SubElement(logrotator, 'daysToKeep').text = str(DEFAULT_DAYS_TO_KEEP)
    ET.SubElement(logrotator, 'numToKeep').text = str(DEFAULT_NUM_TO_KEEP)
    ET.SubElement(logrotator, 'artifactDaysToKeep').text = str(DEFAULT_ARTIFACT_DAYS_TO_KEEP)
    ET.SubElement(logrotator, 'artifactNumToKeep').text = str(DEFAULT_ARTIFACT_NUM_TO_KEEP)
    ET.SubElement(logrotator, 'removeLastBuild').text = DEFAULT_REMOVE_LAST_BUILD
    
    return logrotator, 'direct'

def validate_single_logrotator(root):
    """
    Validate that exactly one logRotator definition exists.
    Returns: (is_valid: bool, count: int, message: str)
    """
    logrotators = find_all_logrotators(root)
    count = len(logrotators)
    
    if count == 0:
        return False, 0, "No logRotator found (expected 1)"
    elif count == 1:
        return True, 1, "Single logRotator found"
    else:
        formats = [fmt for _, fmt in logrotators]
        return False, count, f"Multiple logRotators found: {formats}"

def configure_logrotator(config_path, backup_dir, jenkins_home, dry_run=False):
    """
    Configure logRotator settings in a Jenkins job config.xml.
    
    Args:
        config_path: Path to config.xml file
        backup_dir: Directory for backups
        jenkins_home: Jenkins home directory
        dry_run: If True, don't write changes
    
    Returns:
        dict with status information
    """
    result = {
        'path': config_path,
        'modified': False,
        'created_logrotator': False,
        'format': None,
        'changes': [],
        'error': None,
        'backup': None,
        'before': {},
        'after': {}
    }
    
    try:
        # Read original file to detect XML version and preserve character entities
        with open(config_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
        
        # Detect XML version
        first_line = original_content.split('\n')[0]
        xml_version = '1.0'  # default
        if 'version=' in first_line:
            if 'version="1.1"' in first_line or "version='1.1'" in first_line:
                xml_version = '1.1'
        
        # Find and replace character entities with unique placeholders
        # This is necessary because some job descriptions contain escape characters
        # for things like newline (&#xd;), which ElementTree would decode during parsing
        # and not re-encode when writing, causing them to become literal characters.
        # Pattern matches &#x followed by hex digits and semicolon (e.g., &#xd; &#xa;)
        entity_pattern = re.compile(r'&#x([0-9a-fA-F]+);')
        entity_map = {}  # Maps placeholder to original entity
        
        def replace_entity(match):
            entity = match.group(0)  # e.g., '&#xd;'
            if entity not in entity_map:
                # Create unique placeholder that won't appear in XML
                placeholder = f'__XMLENTITY_{uuid.uuid4().hex[:8]}_{match.group(1)}__'
                entity_map[placeholder] = entity
            else:
                # Find existing placeholder for this entity
                placeholder = [k for k, v in entity_map.items() if v == entity][0]
            return placeholder
        
        modified_content = entity_pattern.sub(replace_entity, original_content)
        
        # Write temporary file with placeholders
        temp_path = config_path + '.tmp'
        with open(temp_path, 'w', encoding='utf-8') as f:
            f.write(modified_content)
        
        # Parse XML from temporary file
        tree = ET.parse(temp_path)
        root = tree.getroot()
        
        # Clean up temp file
        os.remove(temp_path)
        
        # Find all logRotator elements (both formats)
        logrotators = find_all_logrotators(root)
        
        if len(logrotators) == 0:
            # No logRotator - create one with defaults
            logrotator, format_type = create_logrotator(root)
            result['created_logrotator'] = True
            result['modified'] = True
            result['format'] = format_type
            result['changes'].append(f'Created logRotator ({format_type})')
            
            # Record after state
            result['after'] = {
                'daysToKeep': str(DEFAULT_DAYS_TO_KEEP),
                'numToKeep': str(DEFAULT_NUM_TO_KEEP),
                'artifactDaysToKeep': str(DEFAULT_ARTIFACT_DAYS_TO_KEEP),
                'artifactNumToKeep': str(DEFAULT_ARTIFACT_NUM_TO_KEEP),
                'removeLastBuild': DEFAULT_REMOVE_LAST_BUILD
            }
        elif len(logrotators) == 1:
            # Single logRotator - update it
            logrotator, format_type = logrotators[0]
            result['format'] = format_type
            
            # Record current state
            for field in ['daysToKeep', 'numToKeep', 'artifactDaysToKeep', 'artifactNumToKeep', 'removeLastBuild']:
                elem = logrotator.find(field)
                result['before'][field] = elem.text if elem is not None else None
            
            # Ensure daysToKeep and artifactDaysToKeep have values
            days_changed, days_action = ensure_element(logrotator, 'daysToKeep', DEFAULT_DAYS_TO_KEEP)
            if days_changed:
                result['modified'] = True
                result['changes'].append(f'daysToKeep {days_action}: {DEFAULT_DAYS_TO_KEEP}')
            
            artifact_days_changed, artifact_days_action = ensure_element(logrotator, 'artifactDaysToKeep', DEFAULT_ARTIFACT_DAYS_TO_KEEP)
            if artifact_days_changed:
                result['modified'] = True
                result['changes'].append(f'artifactDaysToKeep {artifact_days_action}: {DEFAULT_ARTIFACT_DAYS_TO_KEEP}')
            
            # Ensure numToKeep and artifactNumToKeep exist
            num_changed, num_action = ensure_element(logrotator, 'numToKeep', DEFAULT_NUM_TO_KEEP)
            if num_changed:
                result['modified'] = True
                result['changes'].append(f'numToKeep {num_action}: {DEFAULT_NUM_TO_KEEP}')
            
            artifact_num_changed, artifact_num_action = ensure_element(logrotator, 'artifactNumToKeep', DEFAULT_ARTIFACT_NUM_TO_KEEP)
            if artifact_num_changed:
                result['modified'] = True
                result['changes'].append(f'artifactNumToKeep {artifact_num_action}: {DEFAULT_ARTIFACT_NUM_TO_KEEP}')
            
            # Set removeLastBuild=true
            remove_last_build = logrotator.find('removeLastBuild')
            
            if remove_last_build is not None:
                if remove_last_build.text != DEFAULT_REMOVE_LAST_BUILD:
                    remove_last_build.text = DEFAULT_REMOVE_LAST_BUILD
                    result['modified'] = True
                    result['changes'].append(f'removeLastBuild set to {DEFAULT_REMOVE_LAST_BUILD}')
            else:
                # Add new element after artifactNumToKeep
                artifact_num = logrotator.find('artifactNumToKeep')
                if artifact_num is not None:
                    children = list(logrotator)
                    index = children.index(artifact_num) + 1
                    remove_last_build = ET.Element('removeLastBuild')
                    remove_last_build.text = DEFAULT_REMOVE_LAST_BUILD
                    logrotator.insert(index, remove_last_build)
                else:
                    remove_last_build = ET.SubElement(logrotator, 'removeLastBuild')
                    remove_last_build.text = DEFAULT_REMOVE_LAST_BUILD
                
                result['modified'] = True
                result['changes'].append('removeLastBuild created: true')
            
            # Record after state
            for field in ['daysToKeep', 'numToKeep', 'artifactDaysToKeep', 'artifactNumToKeep', 'removeLastBuild']:
                elem = logrotator.find(field)
                result['after'][field] = elem.text if elem is not None else None
        else:
            # Multiple logRotators - ERROR
            formats = [fmt for _, fmt in logrotators]
            result['error'] = f'Multiple logRotator definitions found ({len(logrotators)}): {formats}. Manual intervention required.'
            return result
        
        # Validate only one logRotator exists after modifications
        if result['modified']:
            is_valid, count, message = validate_single_logrotator(root)
            if not is_valid:
                result['error'] = f'Validation failed: {message}. Changes not saved.'
                result['modified'] = False
                return result
        
        if result['modified'] and not dry_run:
            # Create backup
            result['backup'] = backup_file(config_path, backup_dir, jenkins_home)
            
            # Write modified XML preserving original version and encoding
            import io
            output = io.BytesIO()
            tree.write(output, encoding='UTF-8', xml_declaration=False)
            xml_content = output.getvalue().decode('UTF-8')
            
            # Restore character entities from placeholders
            for placeholder, entity in entity_map.items():
                xml_content = xml_content.replace(placeholder, entity)
            
            # Write with correct XML declaration
            with open(config_path, 'w', encoding='UTF-8') as f:
                f.write(f'<?xml version="{xml_version}" encoding="UTF-8"?>')
                f.write(xml_content)
        
        return result
        
    except Exception as e:
        result['error'] = str(e)
        return result

def process_job(job_path, job_name, backup_dir, jenkins_home, dry_run=False, verbose=False):
    """Process a single job directory."""
    config_path = os.path.join(job_path, 'config.xml')
    
    if not os.path.exists(config_path):
        return None
    
    result = configure_logrotator(config_path, backup_dir, jenkins_home, dry_run=dry_run)
    
    if verbose or result['error'] or result['modified']:
        print(f"\n{'='*80}")
        print(f"Job: {job_name}")
        print(f"{'='*80}")
        
        if result['error']:
            if result.get('archive_required'):
                print(f"🗄️  ARCHIVE: {result['error']}")
            else:
                print(f"❌ Error: {result['error']}")
        elif result['modified']:
            if result['created_logrotator']:
                print(f"✅ Created logRotator ({result['format']})")
            else:
                print(f"✅ Modified logRotator ({result['format']})")
            
            if result['backup']:
                print(f"   Backup: {os.path.basename(result['backup'])}")
            
            print(f"\nChanges:")
            for change in result['changes']:
                print(f"  - {change}")
            
            if result['before']:
                print(f"\nBefore:")
                for k, v in result['before'].items():
                    print(f"  {k}: {v}")
            
            print(f"\nAfter:")
            for k, v in result['after'].items():
                print(f"  {k}: {v}")
        else:
            print(f"ℹ️  No changes needed ({result['format']})")
    
    return result

def matches_pattern(job_name, pattern):
    """Check if job name matches the pattern (glob or regex)."""
    if job_name == pattern:
        return True
    if fnmatch.fnmatch(job_name, pattern):
        return True
    try:
        if re.match(pattern, job_name):
            return True
    except re.error:
        pass
    return False

def find_matching_jobs(jobs_dir, pattern):
    """Find all jobs matching the pattern."""
    matching_jobs = []
    for root, dirs, files in os.walk(jobs_dir):
        if 'config.xml' in files:
            rel_path = os.path.relpath(root, jobs_dir)
            job_name = rel_path.replace(os.sep, '/')
            if matches_pattern(job_name, pattern):
                matching_jobs.append((root, job_name))
    return matching_jobs

def main():
    parser = argparse.ArgumentParser(
        description='Configure logRotator settings in Jenkins job configs',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Features:
  1. Set removeLastBuild=true
  2. Ensure daysToKeep and artifactDaysToKeep are set (default: 365)
  3. Create logRotator if missing with sensible defaults
  4. Support both logRotator and BuildDiscarderProperty formats
  5. Validate only one logRotator definition exists
  6. Create backups preserving directory structure

Examples:
# Test on single job
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins-configs \\
    --pattern "my-job" --verbose --dry-run

# Update all Test* jobs
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins-configs \\
    --pattern "Test*"

# Update all jobs
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins-configs

# List matching jobs without processing
python3 logRotatorUpdate.py /home/jenkins/.jenkins /backup/jenkins-configs \\
    --pattern "Test*" --list-matches
        """
    )
    parser.add_argument('jenkins_home', help='Path to JENKINS_HOME directory')
    parser.add_argument('backup_dir', help='Directory for backups (preserves folder structure)')
    parser.add_argument('--pattern', help='Process jobs matching this pattern (glob or regex)')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without modifying files')
    parser.add_argument('--verbose', action='store_true', help='Show details for all jobs')
    parser.add_argument('--list-matches', action='store_true', help='List matching jobs without processing')
    
    args = parser.parse_args()
    
    jobs_dir = os.path.join(args.jenkins_home, 'jobs')
    
    if not os.path.exists(jobs_dir):
        print(f"❌ Error: Jobs directory not found: {jobs_dir}")
        sys.exit(1)
    
    print("="*80)
    print("Jenkins logRotator Configuration Tool")
    print("="*80)
    print(f"Python: {sys.version.split()[0]}")
    print(f"Jenkins Home: {args.jenkins_home}")
    if args.pattern:
        print(f"Pattern: {args.pattern}")
    if args.dry_run:
        print("Mode: DRY RUN")
    print("="*80)
    
    # Find matching jobs
    if args.pattern:
        matching_jobs = find_matching_jobs(jobs_dir, args.pattern)
        print(f"\nFound {len(matching_jobs)} matching jobs")
    else:
        matching_jobs = [(os.path.join(jobs_dir, j), j) for j in os.listdir(jobs_dir) if os.path.isdir(os.path.join(jobs_dir, j))]
        if not args.list_matches:
            print(f"\nFound {len(matching_jobs)} jobs")
    
    # If list-matches mode, just list and exit
    if args.list_matches:
        print(f"\nMatching jobs:")
        for _, job_name in sorted(matching_jobs, key=lambda x: x[1]):
            print(f"  {job_name}")
        return
    
    # Process jobs
    stats = {
        'total': 0,
        'modified': 0,
        'created': 0,
        'skipped': 0,
        'errors': 0,
        'multiple_logrotators': 0,
        'fields': {
            'daysToKeep': {'count': 0, 'jobs': []},
            'artifactDaysToKeep': {'count': 0, 'jobs': []},
            'numToKeep': {'count': 0, 'jobs': []},
            'artifactNumToKeep': {'count': 0, 'jobs': []},
            'removeLastBuild': {'count': 0, 'jobs': []}
        }
    }
    
    for job_path, job_name in matching_jobs:
        stats['total'] += 1
        result = process_job(job_path, job_name, args.backup_dir, args.jenkins_home,
                           dry_run=args.dry_run, verbose=args.verbose)
        
        if result is None:
            continue
        
        if result['error']:
            stats['errors'] += 1
            if 'Multiple logRotator' in result['error']:
                stats['multiple_logrotators'] += 1
            if not args.verbose:
                print(f"❌ {job_name}: {result['error']}")
        elif result['modified']:
            # Track field changes
            for change in result['changes']:
                for field in stats['fields'].keys():
                    if field in change:
                        stats['fields'][field]['count'] += 1
                        stats['fields'][field]['jobs'].append(job_name)
                        break
            
            if result['created_logrotator']:
                stats['created'] += 1
                if not args.verbose:
                    print(f"✅ {job_name} (created {result['format']})")
            else:
                stats['modified'] += 1
                if not args.verbose:
                    changes_summary = ', '.join(result['changes'][:2])
                    if len(result['changes']) > 2:
                        changes_summary += f" +{len(result['changes'])-2} more"
                    print(f"✅ {job_name} ({changes_summary})")
        else:
            stats['skipped'] += 1
        
        if stats['total'] % 100 == 0 and not args.verbose:
            print(f"Progress: {stats['total']} jobs...")
    
    # Summary
    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    print(f"Total jobs: {stats['total']}")
    print(f"✅ Modified: {stats['modified']}")
    print(f"✅ Created: {stats['created']} (new logRotator)")
    print(f"⏭️  Skipped: {stats['skipped']} (no changes needed)")
    print(f"❌ Errors: {stats['errors']}")
    if stats['multiple_logrotators'] > 0:
        print(f"⚠️  Multiple logRotators: {stats['multiple_logrotators']} (manual fix required)")
    
    # Field change statistics with default values
    field_defaults = {
        'daysToKeep': '365',
        'artifactDaysToKeep': '365',
        'numToKeep': '5',
        'artifactNumToKeep': '5',
        'removeLastBuild': 'true'
    }
    
    if any(data['count'] > 0 for data in stats['fields'].values()):
        print("\nField Changes:")
        for field, data in stats['fields'].items():
            if data['count'] > 0:
                default = field_defaults[field]
                print(f"  {field} set to {default}: {data['count']} jobs")
    
    # Show jobs with significant changes by field (excluding removeLastBuild)
    has_significant_changes = False
    for field, data in stats['fields'].items():
        if field != 'removeLastBuild' and data['count'] > 0:
            has_significant_changes = True
            break
    
    if has_significant_changes:
        print(f"\nJobs with retention policy changes:")
        for field, data in stats['fields'].items():
            if field != 'removeLastBuild' and data['count'] > 0:
                default = field_defaults[field]
                print(f"\n  {field} set to {default} ({data['count']} jobs):")
                for job in sorted(data['jobs']):
                    print(f"    - {job}")
    
    print("="*80)
    
    if args.dry_run:
        print("\n⚠️  DRY RUN - No changes were made")
        print("Run without --dry-run to apply changes")

if __name__ == '__main__':
    main()

# Made with Bob
