#!/usr/bin/env python3
"""Script to create an initial admin user for the Jenkins Capacity Report application."""

import sys
import getpass
from pathlib import Path

# Add the app root directory to the path so we can import our modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.user_manager import get_user_manager


def validate_password(password: str) -> tuple[bool, str]:
    """Validate password strength.
    
    Args:
        password: Password to validate
        
    Returns:
        Tuple of (is_valid, message)
    """
    if len(password) < 8:
        return False, "Password must be at least 8 characters long"
    
    if len(password) < 12:
        print("Warning: Password is less than 12 characters. Consider using a longer password.")
    
    return True, "Password is valid"


def main():
    """Main function to create an admin user."""
    print("=" * 60)
    print("Jenkins Capacity Report - Create Admin User")
    print("=" * 60)
    print()
    
    user_manager = get_user_manager()
    
    # Check if any users exist
    existing_users = user_manager.list_users()
    if existing_users:
        print(f"Note: {len(existing_users)} user(s) already exist in the system:")
        for user in existing_users:
            print(f"  - {user['username']} ({user['role']})")
        print()
        
        response = input("Do you want to create another admin user? (yes/no): ").strip().lower()
        if response not in ['yes', 'y']:
            print("Aborted.")
            return
        print()
    
    # Get username
    while True:
        username = input("Enter username for admin user: ").strip()
        
        if not username:
            print("Error: Username cannot be empty")
            continue
        
        if user_manager.user_exists(username):
            print(f"Error: User '{username}' already exists")
            continue
        
        break
    
    # Get password
    while True:
        password = getpass.getpass("Enter password: ")
        
        if not password:
            print("Error: Password cannot be empty")
            continue
        
        is_valid, message = validate_password(password)
        if not is_valid:
            print(f"Error: {message}")
            continue
        
        password_confirm = getpass.getpass("Confirm password: ")
        
        if password != password_confirm:
            print("Error: Passwords do not match")
            continue
        
        break
    
    # Get email (optional)
    email = input("Enter email (optional, press Enter to skip): ").strip()
    
    # Create the user
    print()
    print("Creating admin user...")
    
    try:
        if user_manager.create_user(username, password, 'admin', email, 'setup_script'):
            print()
            print("=" * 60)
            print("SUCCESS!")
            print("=" * 60)
            print(f"Admin user '{username}' created successfully!")
            print()
            print("You can now:")
            print("1. Start the application: python web_app.py")
            print("2. Login using the credentials you just created")
            print("3. Create additional users through the web interface or API")
            print()
            print("For more information, see RBAC-GUIDE.md")
            print("=" * 60)
        else:
            print()
            print("Error: Failed to create user (user may already exist)")
            sys.exit(1)
    except Exception as e:
        print()
        print(f"Error: Failed to create user: {e}")
        sys.exit(1)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print()
        print("Aborted by user.")
        sys.exit(1)
    except Exception as e:
        print()
        print(f"Unexpected error: {e}")
        sys.exit(1)

# Made with Bob