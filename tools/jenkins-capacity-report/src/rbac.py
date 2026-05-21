"""Module for role-based access control (RBAC)."""

import logging
from functools import wraps
from typing import List, Optional
from flask import jsonify

from .auth import get_current_user, get_current_user_role, require_auth
from .user_manager import get_user_manager

logger = logging.getLogger(__name__)


# Role hierarchy (higher index = more privileges)
ROLE_HIERARCHY = ['viewer', 'operator', 'admin']


def has_role(user_role: str, required_roles: List[str]) -> bool:
    """Check if a user role satisfies the required roles.
    
    Args:
        user_role: The user's role
        required_roles: List of acceptable roles
        
    Returns:
        True if user has one of the required roles, False otherwise
    """
    return user_role in required_roles


def has_minimum_role(user_role: str, minimum_role: str) -> bool:
    """Check if a user has at least the minimum required role.
    
    Args:
        user_role: The user's role
        minimum_role: The minimum required role
        
    Returns:
        True if user has at least the minimum role, False otherwise
    """
    try:
        user_level = ROLE_HIERARCHY.index(user_role)
        min_level = ROLE_HIERARCHY.index(minimum_role)
        return user_level >= min_level
    except ValueError:
        return False


def require_role(allowed_roles: List[str]):
    """Decorator to require specific roles for an endpoint.
    
    Args:
        allowed_roles: List of roles that are allowed to access the endpoint
        
    Example:
        @require_role(['admin'])
        def admin_only_endpoint():
            pass
        
        @require_role(['operator', 'admin'])
        def operator_or_admin_endpoint():
            pass
    """
    def decorator(f):
        @wraps(f)
        @require_auth  # First ensure user is authenticated
        def decorated_function(*args, **kwargs):
            current_role = get_current_user_role()
            current_user = get_current_user()
            
            if not current_role:
                logger.warning(f"User '{current_user}' has no role assigned")
                return jsonify({
                    'error': 'Access denied',
                    'message': 'Your account has no role assigned'
                }), 403
            
            if not has_role(current_role, allowed_roles):
                logger.warning(
                    f"User '{current_user}' with role '{current_role}' "
                    f"attempted to access endpoint requiring roles: {allowed_roles}"
                )
                return jsonify({
                    'error': 'Access denied',
                    'message': f'This endpoint requires one of the following roles: {", ".join(allowed_roles)}',
                    'your_role': current_role,
                    'required_roles': allowed_roles
                }), 403
            
            return f(*args, **kwargs)
        
        return decorated_function
    return decorator


def require_minimum_role(minimum_role: str):
    """Decorator to require a minimum role level for an endpoint.
    
    Args:
        minimum_role: The minimum role required (viewer, operator, or admin)
        
    Example:
        @require_minimum_role('operator')
        def operator_or_higher_endpoint():
            # Accessible by operator and admin
            pass
    """
    def decorator(f):
        @wraps(f)
        @require_auth  # First ensure user is authenticated
        def decorated_function(*args, **kwargs):
            current_role = get_current_user_role()
            current_user = get_current_user()
            
            if not current_role:
                logger.warning(f"User '{current_user}' has no role assigned")
                return jsonify({
                    'error': 'Access denied',
                    'message': 'Your account has no role assigned'
                }), 403
            
            if not has_minimum_role(current_role, minimum_role):
                logger.warning(
                    f"User '{current_user}' with role '{current_role}' "
                    f"attempted to access endpoint requiring minimum role: {minimum_role}"
                )
                return jsonify({
                    'error': 'Access denied',
                    'message': f'This endpoint requires at least {minimum_role} role',
                    'your_role': current_role,
                    'minimum_required_role': minimum_role
                }), 403
            
            return f(*args, **kwargs)
        
        return decorated_function
    return decorator


def require_admin(f):
    """Decorator to require admin role for an endpoint.
    
    Shorthand for @require_role(['admin'])
    """
    return require_role(['admin'])(f)


def require_operator_or_admin(f):
    """Decorator to require operator or admin role for an endpoint.
    
    Shorthand for @require_role(['operator', 'admin'])
    """
    return require_role(['operator', 'admin'])(f)


def can_modify_user(actor_username: str, target_username: str) -> tuple[bool, Optional[str]]:
    """Check if an actor can modify a target user.
    
    Rules:
    - Admins can modify any user except themselves (for safety)
    - Users can modify their own password
    - Users cannot modify their own role
    - Users cannot modify other users
    
    Args:
        actor_username: Username of the user performing the action
        target_username: Username of the user being modified
        
    Returns:
        Tuple of (can_modify: bool, reason: Optional[str])
    """
    user_manager = get_user_manager()
    
    actor = user_manager.get_user(actor_username)
    target = user_manager.get_user(target_username)
    
    if not actor:
        return False, f"Actor user '{actor_username}' not found"
    
    if not target:
        return False, f"Target user '{target_username}' not found"
    
    actor_role = actor.get('role')
    
    # Admins can modify other users
    if actor_role == 'admin' and actor_username != target_username:
        return True, None
    
    # Users can modify themselves (password only, not role)
    if actor_username == target_username:
        return True, None
    
    return False, "You don't have permission to modify this user"


def can_delete_user(actor_username: str, target_username: str) -> tuple[bool, Optional[str]]:
    """Check if an actor can delete a target user.
    
    Rules:
    - Only admins can delete users
    - Admins cannot delete themselves
    - Cannot delete the last admin user
    
    Args:
        actor_username: Username of the user performing the action
        target_username: Username of the user being deleted
        
    Returns:
        Tuple of (can_delete: bool, reason: Optional[str])
    """
    user_manager = get_user_manager()
    
    actor = user_manager.get_user(actor_username)
    target = user_manager.get_user(target_username)
    
    if not actor:
        return False, f"Actor user '{actor_username}' not found"
    
    if not target:
        return False, f"Target user '{target_username}' not found"
    
    actor_role = actor.get('role')
    target_role = target.get('role')
    
    # Only admins can delete users
    if actor_role != 'admin':
        return False, "Only administrators can delete users"
    
    # Cannot delete yourself
    if actor_username == target_username:
        return False, "You cannot delete your own account"
    
    # Check if this is the last admin
    if target_role == 'admin':
        all_users = user_manager.list_users()
        admin_count = sum(1 for u in all_users if u.get('role') == 'admin')
        if admin_count <= 1:
            return False, "Cannot delete the last administrator account"
    
    return True, None


def get_role_permissions() -> dict:
    """Get a description of permissions for each role.
    
    Returns:
        Dictionary describing role permissions
    """
    return {
        'viewer': {
            'description': 'Read-only access to all data',
            'permissions': [
                'View excluded nodes',
                'View node details',
                'View metrics and statistics',
                'View cloud statistics',
                'View all dashboard data'
            ]
        },
        'operator': {
            'description': 'Can manage excluded nodes',
            'permissions': [
                'All viewer permissions',
                'Add nodes to excluded list',
                'Remove nodes from excluded list',
                'Update exclusion reasons',
                'Modify own password'
            ]
        },
        'admin': {
            'description': 'Full system access',
            'permissions': [
                'All operator permissions',
                'Clear all excluded nodes',
                'Create new users',
                'Delete users',
                'Modify user roles',
                'View all users',
                'Disable/enable user accounts'
            ]
        }
    }

# Made with Bob