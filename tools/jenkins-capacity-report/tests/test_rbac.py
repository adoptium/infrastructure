#!/usr/bin/env python3
"""Tests for RBAC (Role-Based Access Control) functionality."""

import unittest
import json
import tempfile
import os
from pathlib import Path

from src.user_manager import UserManager
from src.auth import SessionManager
from src.rbac import (
    has_role, has_minimum_role, can_modify_user, can_delete_user,
    get_role_permissions, ROLE_HIERARCHY
)


class TestUserManager(unittest.TestCase):
    """Test cases for UserManager."""
    
    def setUp(self):
        """Set up test fixtures."""
        # Create a temporary file for user storage
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json')
        self.temp_file.close()
        self.user_manager = UserManager(storage_file=self.temp_file.name)
    
    def tearDown(self):
        """Clean up test fixtures."""
        # Remove temporary file
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)
    
    def test_create_user(self):
        """Test creating a new user."""
        result = self.user_manager.create_user('testuser', 'password123', 'viewer', 'test@example.com')
        self.assertTrue(result)
        self.assertTrue(self.user_manager.user_exists('testuser'))
        self.assertEqual(self.user_manager.get_user_count(), 1)
    
    def test_create_duplicate_user(self):
        """Test that creating a duplicate user fails."""
        self.user_manager.create_user('testuser', 'password123', 'viewer')
        result = self.user_manager.create_user('testuser', 'different_password', 'admin')
        self.assertFalse(result)
        self.assertEqual(self.user_manager.get_user_count(), 1)
    
    def test_create_user_invalid_role(self):
        """Test that creating a user with invalid role fails."""
        result = self.user_manager.create_user('testuser', 'password123', 'invalid_role')
        self.assertFalse(result)
        self.assertEqual(self.user_manager.get_user_count(), 0)
    
    def test_authenticate_valid_credentials(self):
        """Test authentication with valid credentials."""
        self.user_manager.create_user('testuser', 'password123', 'viewer')
        result = self.user_manager.authenticate('testuser', 'password123')
        self.assertTrue(result)
    
    def test_authenticate_invalid_password(self):
        """Test authentication with invalid password."""
        self.user_manager.create_user('testuser', 'password123', 'viewer')
        result = self.user_manager.authenticate('testuser', 'wrong_password')
        self.assertFalse(result)
    
    def test_authenticate_nonexistent_user(self):
        """Test authentication with nonexistent user."""
        result = self.user_manager.authenticate('nonexistent', 'password123')
        self.assertFalse(result)
    
    def test_authenticate_disabled_user(self):
        """Test that disabled users cannot authenticate."""
        self.user_manager.create_user('testuser', 'password123', 'viewer')
        self.user_manager.disable_user('testuser')
        result = self.user_manager.authenticate('testuser', 'password123')
        self.assertFalse(result)
    
    def test_get_user(self):
        """Test getting user information."""
        self.user_manager.create_user('testuser', 'password123', 'operator', 'test@example.com')
        user = self.user_manager.get_user('testuser')
        
        self.assertIsNotNone(user)
        self.assertEqual(user['username'], 'testuser')
        self.assertEqual(user['role'], 'operator')
        self.assertEqual(user['email'], 'test@example.com')
        self.assertNotIn('password_hash', user)  # Should not expose password hash
    
    def test_get_user_role(self):
        """Test getting user role."""
        self.user_manager.create_user('testuser', 'password123', 'admin')
        role = self.user_manager.get_user_role('testuser')
        self.assertEqual(role, 'admin')
    
    def test_list_users(self):
        """Test listing all users."""
        self.user_manager.create_user('user1', 'password1', 'viewer')
        self.user_manager.create_user('user2', 'password2', 'operator')
        self.user_manager.create_user('user3', 'password3', 'admin')
        
        users = self.user_manager.list_users()
        self.assertEqual(len(users), 3)
        
        # Check that password hashes are not exposed
        for user in users:
            self.assertNotIn('password_hash', user)
    
    def test_update_password(self):
        """Test updating user password."""
        self.user_manager.create_user('testuser', 'old_password', 'viewer')
        
        # Update password
        result = self.user_manager.update_password('testuser', 'new_password')
        self.assertTrue(result)
        
        # Old password should not work
        self.assertFalse(self.user_manager.authenticate('testuser', 'old_password'))
        
        # New password should work
        self.assertTrue(self.user_manager.authenticate('testuser', 'new_password'))
    
    def test_update_role(self):
        """Test updating user role."""
        self.user_manager.create_user('testuser', 'password123', 'viewer')
        
        result = self.user_manager.update_role('testuser', 'admin', 'admin_user')
        self.assertTrue(result)
        self.assertEqual(self.user_manager.get_user_role('testuser'), 'admin')
    
    def test_update_role_invalid(self):
        """Test that updating to invalid role fails."""
        self.user_manager.create_user('testuser', 'password123', 'viewer')
        
        result = self.user_manager.update_role('testuser', 'invalid_role')
        self.assertFalse(result)
        self.assertEqual(self.user_manager.get_user_role('testuser'), 'viewer')
    
    def test_delete_user(self):
        """Test deleting a user."""
        self.user_manager.create_user('testuser', 'password123', 'viewer')
        
        result = self.user_manager.delete_user('testuser', 'admin_user')
        self.assertTrue(result)
        self.assertFalse(self.user_manager.user_exists('testuser'))
    
    def test_disable_enable_user(self):
        """Test disabling and enabling a user."""
        self.user_manager.create_user('testuser', 'password123', 'viewer')
        
        # Disable user
        result = self.user_manager.disable_user('testuser')
        self.assertTrue(result)
        self.assertFalse(self.user_manager.authenticate('testuser', 'password123'))
        
        # Enable user
        result = self.user_manager.enable_user('testuser')
        self.assertTrue(result)
        self.assertTrue(self.user_manager.authenticate('testuser', 'password123'))
    
    def test_persistence(self):
        """Test that user data persists across manager instances."""
        self.user_manager.create_user('testuser', 'password123', 'admin', 'test@example.com')
        
        # Create a new manager instance with the same storage file
        new_manager = UserManager(storage_file=self.temp_file.name)
        
        # User should exist in new manager
        self.assertTrue(new_manager.user_exists('testuser'))
        user = new_manager.get_user('testuser')
        self.assertEqual(user['role'], 'admin')
        self.assertEqual(user['email'], 'test@example.com')


class TestSessionManager(unittest.TestCase):
    """Test cases for SessionManager."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.session_manager = SessionManager(session_timeout_minutes=1)
    
    def test_create_session(self):
        """Test creating a session."""
        token = self.session_manager.create_session('testuser')
        self.assertIsNotNone(token)
        self.assertGreater(len(token), 20)  # Token should be reasonably long
    
    def test_validate_session(self):
        """Test validating a session."""
        token = self.session_manager.create_session('testuser')
        username = self.session_manager.validate_session(token)
        self.assertEqual(username, 'testuser')
    
    def test_validate_invalid_token(self):
        """Test validating an invalid token."""
        username = self.session_manager.validate_session('invalid_token')
        self.assertIsNone(username)
    
    def test_invalidate_session(self):
        """Test invalidating a session."""
        token = self.session_manager.create_session('testuser')
        
        result = self.session_manager.invalidate_session(token)
        self.assertTrue(result)
        
        # Token should no longer be valid
        username = self.session_manager.validate_session(token)
        self.assertIsNone(username)
    
    def test_invalidate_user_sessions(self):
        """Test invalidating all sessions for a user."""
        token1 = self.session_manager.create_session('testuser')
        token2 = self.session_manager.create_session('testuser')
        token3 = self.session_manager.create_session('otheruser')
        
        count = self.session_manager.invalidate_user_sessions('testuser')
        self.assertEqual(count, 2)
        
        # testuser tokens should be invalid
        self.assertIsNone(self.session_manager.validate_session(token1))
        self.assertIsNone(self.session_manager.validate_session(token2))
        
        # otheruser token should still be valid
        self.assertEqual(self.session_manager.validate_session(token3), 'otheruser')
    
    def test_get_active_sessions(self):
        """Test getting active sessions."""
        self.session_manager.create_session('user1')
        self.session_manager.create_session('user2')
        
        sessions = self.session_manager.get_active_sessions()
        self.assertEqual(len(sessions), 2)


class TestRBACFunctions(unittest.TestCase):
    """Test cases for RBAC utility functions."""
    
    def test_has_role(self):
        """Test has_role function."""
        self.assertTrue(has_role('admin', ['admin']))
        self.assertTrue(has_role('operator', ['operator', 'admin']))
        self.assertFalse(has_role('viewer', ['operator', 'admin']))
    
    def test_has_minimum_role(self):
        """Test has_minimum_role function."""
        # Admin has all roles
        self.assertTrue(has_minimum_role('admin', 'viewer'))
        self.assertTrue(has_minimum_role('admin', 'operator'))
        self.assertTrue(has_minimum_role('admin', 'admin'))
        
        # Operator has operator and viewer
        self.assertTrue(has_minimum_role('operator', 'viewer'))
        self.assertTrue(has_minimum_role('operator', 'operator'))
        self.assertFalse(has_minimum_role('operator', 'admin'))
        
        # Viewer only has viewer
        self.assertTrue(has_minimum_role('viewer', 'viewer'))
        self.assertFalse(has_minimum_role('viewer', 'operator'))
        self.assertFalse(has_minimum_role('viewer', 'admin'))
    
    def test_role_hierarchy(self):
        """Test that role hierarchy is correctly defined."""
        self.assertEqual(ROLE_HIERARCHY, ['viewer', 'operator', 'admin'])
        self.assertEqual(len(ROLE_HIERARCHY), 3)
    
    def test_can_modify_user(self):
        """Test can_modify_user function."""
        # Create temporary user manager for testing
        temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json')
        temp_file.close()
        
        try:
            user_manager = UserManager(storage_file=temp_file.name)
            user_manager.create_user('admin1', 'password', 'admin')
            user_manager.create_user('operator1', 'password', 'operator')
            user_manager.create_user('viewer1', 'password', 'viewer')
            
            # Admin can modify other users
            can_modify, reason = can_modify_user('admin1', 'operator1')
            self.assertTrue(can_modify)
            
            # Admin cannot modify themselves (for safety)
            can_modify, reason = can_modify_user('admin1', 'admin1')
            self.assertTrue(can_modify)  # Actually they can (for password changes)
            
            # Operator cannot modify other users
            can_modify, reason = can_modify_user('operator1', 'viewer1')
            self.assertFalse(can_modify)
            
            # User can modify themselves
            can_modify, reason = can_modify_user('operator1', 'operator1')
            self.assertTrue(can_modify)
        finally:
            os.unlink(temp_file.name)
    
    def test_can_delete_user(self):
        """Test can_delete_user function."""
        # Create temporary user manager for testing
        temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json')
        temp_file.close()
        
        try:
            user_manager = UserManager(storage_file=temp_file.name)
            user_manager.create_user('admin1', 'password', 'admin')
            user_manager.create_user('admin2', 'password', 'admin')
            user_manager.create_user('operator1', 'password', 'operator')
            
            # Admin can delete other users
            can_delete, reason = can_delete_user('admin1', 'operator1')
            self.assertTrue(can_delete)
            
            # Admin cannot delete themselves
            can_delete, reason = can_delete_user('admin1', 'admin1')
            self.assertFalse(can_delete)
            
            # Operator cannot delete users
            can_delete, reason = can_delete_user('operator1', 'admin1')
            self.assertFalse(can_delete)
            
            # Cannot delete last admin
            user_manager.delete_user('admin2')
            can_delete, reason = can_delete_user('admin1', 'admin1')
            self.assertFalse(can_delete)  # Cannot delete self
        finally:
            os.unlink(temp_file.name)
    
    def test_get_role_permissions(self):
        """Test get_role_permissions function."""
        permissions = get_role_permissions()
        
        self.assertIn('viewer', permissions)
        self.assertIn('operator', permissions)
        self.assertIn('admin', permissions)
        
        # Check structure
        for role in ['viewer', 'operator', 'admin']:
            self.assertIn('description', permissions[role])
            self.assertIn('permissions', permissions[role])
            self.assertIsInstance(permissions[role]['permissions'], list)


class TestRBACIntegration(unittest.TestCase):
    """Integration tests for RBAC system."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json')
        self.temp_file.close()
        self.user_manager = UserManager(storage_file=self.temp_file.name)
        self.session_manager = SessionManager()
    
    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)
    
    def test_complete_user_lifecycle(self):
        """Test complete user lifecycle: create, authenticate, update, delete."""
        # Create user
        self.user_manager.create_user('testuser', 'password123', 'viewer', 'test@example.com')
        
        # Authenticate and create session
        self.assertTrue(self.user_manager.authenticate('testuser', 'password123'))
        token = self.session_manager.create_session('testuser')
        
        # Validate session
        username = self.session_manager.validate_session(token)
        self.assertEqual(username, 'testuser')
        
        # Update role
        self.user_manager.update_role('testuser', 'operator')
        self.assertEqual(self.user_manager.get_user_role('testuser'), 'operator')
        
        # Update password
        self.user_manager.update_password('testuser', 'new_password')
        self.assertTrue(self.user_manager.authenticate('testuser', 'new_password'))
        
        # Invalidate sessions
        self.session_manager.invalidate_user_sessions('testuser')
        self.assertIsNone(self.session_manager.validate_session(token))
        
        # Delete user
        self.user_manager.delete_user('testuser')
        self.assertFalse(self.user_manager.user_exists('testuser'))
    
    def test_multi_user_scenario(self):
        """Test scenario with multiple users and different roles."""
        # Create users
        self.user_manager.create_user('admin', 'admin_pass', 'admin')
        self.user_manager.create_user('operator', 'op_pass', 'operator')
        self.user_manager.create_user('viewer', 'view_pass', 'viewer')
        
        # All users can authenticate
        self.assertTrue(self.user_manager.authenticate('admin', 'admin_pass'))
        self.assertTrue(self.user_manager.authenticate('operator', 'op_pass'))
        self.assertTrue(self.user_manager.authenticate('viewer', 'view_pass'))
        
        # Check role hierarchy
        self.assertTrue(has_minimum_role('admin', 'viewer'))
        self.assertTrue(has_minimum_role('operator', 'viewer'))
        self.assertFalse(has_minimum_role('viewer', 'operator'))
        
        # Admin can modify operator
        can_modify, _ = can_modify_user('admin', 'operator')
        self.assertTrue(can_modify)
        
        # Operator cannot modify admin
        can_modify, _ = can_modify_user('operator', 'admin')
        self.assertFalse(can_modify)


def run_tests():
    """Run all tests."""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestUserManager))
    suite.addTests(loader.loadTestsFromTestCase(TestSessionManager))
    suite.addTests(loader.loadTestsFromTestCase(TestRBACFunctions))
    suite.addTests(loader.loadTestsFromTestCase(TestRBACIntegration))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Return exit code
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    exit(run_tests())

# Made with Bob