"""Module for managing users with role-based access control."""

import json
import logging
from pathlib import Path
from typing import Dict, List, Optional
from threading import Lock
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash

logger = logging.getLogger(__name__)


class UserManager:
    """Manages users with persistent storage and role-based access control."""
    
    # Valid roles in order of privilege
    ROLES = ['viewer', 'operator', 'admin']
    
    def __init__(self, storage_file: str = "data/users.json"):
        """Initialize the user manager.
        
        Args:
            storage_file: Path to the JSON file for storing users
        """
        self.storage_file = Path(storage_file)
        self._lock = Lock()
        self._users: Dict[str, Dict] = {}
        self._load()
    
    def _load(self):
        """Load users from storage file."""
        try:
            if self.storage_file.exists():
                with open(self.storage_file, 'r') as f:
                    data = json.load(f)
                    self._users = data.get('users', {})
                    logger.info(f"Loaded {len(self._users)} users from {self.storage_file}")
            else:
                logger.info(f"No users file found at {self.storage_file}, starting with empty list")
                self._users = {}
        except Exception as e:
            logger.error(f"Error loading users: {e}")
            self._users = {}
    
    def _save(self):
        """Save users to storage file."""
        try:
            with open(self.storage_file, 'w') as f:
                json.dump({
                    'users': self._users
                }, f, indent=2, sort_keys=True)
            logger.info(f"Saved {len(self._users)} users to {self.storage_file}")
        except Exception as e:
            logger.error(f"Error saving users: {e}")
    
    def create_user(self, username: str, password: str, role: str, 
                   email: Optional[str] = None, created_by: Optional[str] = None) -> bool:
        """Create a new user.
        
        Args:
            username: Username (must be unique)
            password: Plain text password (will be hashed)
            role: User role (viewer, operator, or admin)
            email: Optional email address
            created_by: Username of the user creating this account
            
        Returns:
            True if user was created, False if username already exists
        """
        with self._lock:
            if username in self._users:
                logger.warning(f"Attempted to create duplicate user: {username}")
                return False
            
            if role not in self.ROLES:
                logger.error(f"Invalid role '{role}' for user {username}")
                return False
            
            self._users[username] = {
                'password_hash': generate_password_hash(password),
                'role': role,
                'email': email or '',
                'created_at': datetime.utcnow().isoformat() + 'Z',
                'created_by': created_by or 'system',
                'last_login': None,
                'enabled': True
            }
            self._save()
            logger.info(f"Created user '{username}' with role '{role}'")
            return True
    
    def authenticate(self, username: str, password: str) -> bool:
        """Authenticate a user with username and password.
        
        Args:
            username: Username
            password: Plain text password
            
        Returns:
            True if authentication successful, False otherwise
        """
        with self._lock:
            if username not in self._users:
                logger.warning(f"Authentication failed: user '{username}' not found")
                return False
            
            user = self._users[username]
            
            if not user.get('enabled', True):
                logger.warning(f"Authentication failed: user '{username}' is disabled")
                return False
            
            if check_password_hash(user['password_hash'], password):
                # Update last login time
                user['last_login'] = datetime.utcnow().isoformat() + 'Z'
                self._save()
                logger.info(f"User '{username}' authenticated successfully")
                return True
            
            logger.warning(f"Authentication failed: invalid password for user '{username}'")
            return False
    
    def get_user(self, username: str) -> Optional[Dict]:
        """Get user information (without password hash).
        
        Args:
            username: Username
            
        Returns:
            User information dict or None if user doesn't exist
        """
        with self._lock:
            if username not in self._users:
                return None
            
            user = self._users[username].copy()
            # Remove sensitive information
            user.pop('password_hash', None)
            user['username'] = username
            return user
    
    def get_user_role(self, username: str) -> Optional[str]:
        """Get the role of a user.
        
        Args:
            username: Username
            
        Returns:
            User role or None if user doesn't exist
        """
        with self._lock:
            if username not in self._users:
                return None
            return self._users[username].get('role')
    
    def list_users(self) -> List[Dict]:
        """List all users (without password hashes).
        
        Returns:
            List of user information dicts
        """
        with self._lock:
            users = []
            for username, user_data in self._users.items():
                user = user_data.copy()
                user.pop('password_hash', None)
                user['username'] = username
                users.append(user)
            return sorted(users, key=lambda x: x['username'])
    
    def update_password(self, username: str, new_password: str) -> bool:
        """Update a user's password.
        
        Args:
            username: Username
            new_password: New plain text password (will be hashed)
            
        Returns:
            True if password was updated, False if user doesn't exist
        """
        with self._lock:
            if username not in self._users:
                return False
            
            self._users[username]['password_hash'] = generate_password_hash(new_password)
            self._save()
            logger.info(f"Updated password for user '{username}'")
            return True
    
    def update_role(self, username: str, new_role: str, updated_by: Optional[str] = None) -> bool:
        """Update a user's role.
        
        Args:
            username: Username
            new_role: New role (viewer, operator, or admin)
            updated_by: Username of the user making this change
            
        Returns:
            True if role was updated, False if user doesn't exist or invalid role
        """
        with self._lock:
            if username not in self._users:
                return False
            
            if new_role not in self.ROLES:
                logger.error(f"Invalid role '{new_role}'")
                return False
            
            old_role = self._users[username]['role']
            self._users[username]['role'] = new_role
            self._save()
            logger.info(f"Updated role for user '{username}' from '{old_role}' to '{new_role}' by {updated_by or 'system'}")
            return True
    
    def delete_user(self, username: str, deleted_by: Optional[str] = None) -> bool:
        """Delete a user.
        
        Args:
            username: Username to delete
            deleted_by: Username of the user performing the deletion
            
        Returns:
            True if user was deleted, False if user doesn't exist
        """
        with self._lock:
            if username not in self._users:
                return False
            
            del self._users[username]
            self._save()
            logger.info(f"Deleted user '{username}' by {deleted_by or 'system'}")
            return True
    
    def enable_user(self, username: str) -> bool:
        """Enable a user account.
        
        Args:
            username: Username to enable
            
        Returns:
            True if user was enabled, False if user doesn't exist
        """
        with self._lock:
            if username not in self._users:
                return False
            
            self._users[username]['enabled'] = True
            self._save()
            logger.info(f"Enabled user '{username}'")
            return True
    
    def disable_user(self, username: str) -> bool:
        """Disable a user account.
        
        Args:
            username: Username to disable
            
        Returns:
            True if user was disabled, False if user doesn't exist
        """
        with self._lock:
            if username not in self._users:
                return False
            
            self._users[username]['enabled'] = False
            self._save()
            logger.info(f"Disabled user '{username}'")
            return True
    
    def user_exists(self, username: str) -> bool:
        """Check if a user exists.
        
        Args:
            username: Username to check
            
        Returns:
            True if user exists, False otherwise
        """
        return username in self._users
    
    def get_user_count(self) -> int:
        """Get the total number of users.
        
        Returns:
            Number of users
        """
        return len(self._users)


# Global instance
_manager = None


def get_user_manager() -> UserManager:
    """Get the global user manager instance."""
    global _manager
    if _manager is None:
        _manager = UserManager()
    return _manager

# Made with Bob