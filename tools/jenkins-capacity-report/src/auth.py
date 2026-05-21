"""Module for authentication and session management."""

import logging
import secrets
from datetime import datetime, timedelta
from typing import Optional, Dict
from threading import Lock
from functools import wraps
from flask import request, jsonify, g

from .user_manager import get_user_manager

logger = logging.getLogger(__name__)


class SessionManager:
    """Manages user sessions with token-based authentication."""
    
    def __init__(self, session_timeout_minutes: int = 480):  # 8 hours default
        """Initialize the session manager.
        
        Args:
            session_timeout_minutes: Session timeout in minutes
        """
        self.session_timeout = timedelta(minutes=session_timeout_minutes)
        self._sessions: Dict[str, Dict] = {}
        self._lock = Lock()
    
    def create_session(self, username: str) -> str:
        """Create a new session for a user.
        
        Args:
            username: Username
            
        Returns:
            Session token
        """
        with self._lock:
            token = secrets.token_urlsafe(32)
            self._sessions[token] = {
                'username': username,
                'created_at': datetime.utcnow(),
                'last_activity': datetime.utcnow()
            }
            logger.info(f"Created session for user '{username}'")
            return token
    
    def validate_session(self, token: str) -> Optional[str]:
        """Validate a session token and return the username.
        
        Args:
            token: Session token
            
        Returns:
            Username if session is valid, None otherwise
        """
        with self._lock:
            if token not in self._sessions:
                return None
            
            session = self._sessions[token]
            
            # Check if session has expired
            if datetime.utcnow() - session['last_activity'] > self.session_timeout:
                logger.info(f"Session expired for user '{session['username']}'")
                del self._sessions[token]
                return None
            
            # Update last activity
            session['last_activity'] = datetime.utcnow()
            return session['username']
    
    def invalidate_session(self, token: str) -> bool:
        """Invalidate a session.
        
        Args:
            token: Session token
            
        Returns:
            True if session was invalidated, False if token not found
        """
        with self._lock:
            if token in self._sessions:
                username = self._sessions[token]['username']
                del self._sessions[token]
                logger.info(f"Invalidated session for user '{username}'")
                return True
            return False
    
    def invalidate_user_sessions(self, username: str) -> int:
        """Invalidate all sessions for a user.
        
        Args:
            username: Username
            
        Returns:
            Number of sessions invalidated
        """
        with self._lock:
            tokens_to_remove = [
                token for token, session in self._sessions.items()
                if session['username'] == username
            ]
            for token in tokens_to_remove:
                del self._sessions[token]
            
            if tokens_to_remove:
                logger.info(f"Invalidated {len(tokens_to_remove)} sessions for user '{username}'")
            return len(tokens_to_remove)
    
    def get_active_sessions(self) -> Dict[str, Dict]:
        """Get all active sessions.
        
        Returns:
            Dictionary of active sessions (token -> session info)
        """
        with self._lock:
            # Clean up expired sessions
            now = datetime.utcnow()
            expired_tokens = [
                token for token, session in self._sessions.items()
                if now - session['last_activity'] > self.session_timeout
            ]
            for token in expired_tokens:
                del self._sessions[token]
            
            # Return copy of active sessions
            return {
                token: {
                    'username': session['username'],
                    'created_at': session['created_at'].isoformat() + 'Z',
                    'last_activity': session['last_activity'].isoformat() + 'Z'
                }
                for token, session in self._sessions.items()
            }
    
    def cleanup_expired_sessions(self):
        """Remove all expired sessions."""
        with self._lock:
            now = datetime.utcnow()
            expired_tokens = [
                token for token, session in self._sessions.items()
                if now - session['last_activity'] > self.session_timeout
            ]
            for token in expired_tokens:
                username = self._sessions[token]['username']
                del self._sessions[token]
                logger.debug(f"Cleaned up expired session for user '{username}'")
            
            if expired_tokens:
                logger.info(f"Cleaned up {len(expired_tokens)} expired sessions")


# Global instance
_session_manager = None


def get_session_manager() -> SessionManager:
    """Get the global session manager instance."""
    global _session_manager
    if _session_manager is None:
        _session_manager = SessionManager()
    return _session_manager


def get_auth_token() -> Optional[str]:
    """Extract authentication token from request.
    
    Checks for token in:
    1. Authorization header (Bearer token)
    2. X-Auth-Token header
    3. auth_token cookie
    4. auth_token query parameter
    
    Returns:
        Authentication token or None
    """
    # Check Authorization header
    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.startswith('Bearer '):
        return auth_header[7:]
    
    # Check X-Auth-Token header
    token = request.headers.get('X-Auth-Token')
    if token:
        return token
    
    # Check cookie
    token = request.cookies.get('auth_token')
    if token:
        return token
    
    # Check query parameter
    token = request.args.get('auth_token')
    if token:
        return token
    
    return None


def authenticate_request() -> Optional[str]:
    """Authenticate the current request and return username.
    
    Returns:
        Username if authenticated, None otherwise
    """
    token = get_auth_token()
    if not token:
        return None
    
    session_manager = get_session_manager()
    return session_manager.validate_session(token)


def require_auth(f):
    """Decorator to require authentication for an endpoint.
    
    Sets g.current_user to the authenticated username.
    Returns 401 if not authenticated.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        username = authenticate_request()
        if not username:
            return jsonify({
                'error': 'Authentication required',
                'message': 'Please provide a valid authentication token'
            }), 401
        
        # Store current user in Flask's g object
        g.current_user = username
        
        # Get user info and store role
        user_manager = get_user_manager()
        user = user_manager.get_user(username)
        if user:
            g.current_user_role = user.get('role')
        else:
            # User was deleted after session was created
            return jsonify({
                'error': 'User not found',
                'message': 'Your user account no longer exists'
            }), 401
        
        return f(*args, **kwargs)
    
    return decorated_function


def optional_auth(f):
    """Decorator for optional authentication.
    
    Sets g.current_user if authenticated, but doesn't require it.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        username = authenticate_request()
        g.current_user = username
        g.current_user_role = None
        
        if username:
            user_manager = get_user_manager()
            user = user_manager.get_user(username)
            if user:
                g.current_user_role = user.get('role')
        
        return f(*args, **kwargs)
    
    return decorated_function


def get_current_user() -> Optional[str]:
    """Get the current authenticated user from Flask's g object.
    
    Returns:
        Username or None if not authenticated
    """
    return getattr(g, 'current_user', None)


def get_current_user_role() -> Optional[str]:
    """Get the current authenticated user's role from Flask's g object.
    
    Returns:
        User role or None if not authenticated
    """
    return getattr(g, 'current_user_role', None)

# Made with Bob