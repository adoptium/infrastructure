#!/usr/bin/env python3
"""Script to reset a user's password."""

import sys
import getpass
import json
from pathlib import Path
from werkzeug.security import generate_password_hash
from datetime import datetime

# Add the app root directory to the path so we can import our modules
sys.path.insert(0, str(Path(__file__).parent.parent))


def main():
    """Main function to reset a user's password."""
    print("=" * 60)
    print("Jenkins Capacity Report - Reset User Password")
    print("=" * 60)
    print()
    
    users_file = Path(__file__).parent.parent / "data" / "users.json"
    
    if not users_file.exists():
        print(f"Error: Users file not found at {users_file}")
        print("Please create a user first using create_admin_user.py")
        return
    
    # Load users
    with open(users_file, 'r') as f:
        data = json.load(f)
        users = data.get('users', {})
    
    if not users:
        print("Error: No users exist in the system")
        print("Please create a user first using create_admin_user.py")
        return
    
    print("Existing users:")
    for username, user_data in users.items():
        print(f"  - {username} ({user_data.get('role', 'unknown')})")
    print()
    
    # Get username
    username = input("Enter username to reset password for: ").strip()
    
    if username not in users:
        print(f"Error: User '{username}' does not exist")
        return
    
    # Get new password
    while True:
        password = getpass.getpass("Enter new password: ")
        
        if not password:
            print("Error: Password cannot be empty")
            continue
        
        if len(password) < 8:
            print("Error: Password must be at least 8 characters long")
            continue
        
        password_confirm = getpass.getpass("Confirm new password: ")
        
        if password != password_confirm:
            print("Error: Passwords do not match")
            continue
        
        break
    
    # Reset the password
    print()
    print("Resetting password...")
    
    try:
        users[username]['password_hash'] = generate_password_hash(password)
        
        # Save back to file
        with open(users_file, 'w') as f:
            json.dump(data, f, indent=2, sort_keys=True)
        
        print()
        print("=" * 60)
        print("SUCCESS!")
        print("=" * 60)
        print(f"Password for user '{username}' has been reset successfully!")
        print()
        print("You can now login with the new password.")
        print("=" * 60)
    except Exception as e:
        print()
        print(f"Error: Failed to reset password: {e}")
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
