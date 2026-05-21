# Role-Based Access Control (RBAC) Guide

## Overview

The Jenkins Capacity Report application now includes a comprehensive Role-Based Access Control (RBAC) system that provides secure, multi-user access with different permission levels.

## Features

- **Three-tier role system**: viewer, operator, and admin
- **Token-based authentication**: Secure session management with configurable timeouts
- **User management**: Create, modify, and delete user accounts
- **Audit logging**: Track who makes changes to excluded nodes
- **Password management**: Users can change their own passwords
- **Session management**: Automatic session expiration and logout

## Roles and Permissions

### Viewer Role

**Description**: Read-only access to all data

**Permissions**:
- View all dashboard data
- View excluded nodes and their reasons
- View node details and statistics
- View metrics history
- View cloud statistics
- View label summaries

**Cannot**:
- Modify excluded nodes
- Create or manage users
- Change system settings

### Operator Role

**Description**: Can manage excluded nodes

**Permissions**:
- All viewer permissions
- Add nodes to excluded list
- Remove nodes from excluded list
- Update exclusion reasons
- Change own password

**Cannot**:
- Clear all excluded nodes (bulk operation)
- Create or manage users
- Change other users' passwords or roles

### Admin Role

**Description**: Full system access

**Permissions**:
- All operator permissions
- Clear all excluded nodes (bulk operation)
- Create new users
- Delete users (except themselves)
- Modify user roles
- Disable/enable user accounts
- View all users

## Configuration

### Environment Variables

Add these to your `.env` file:

```bash
# RBAC Configuration
RBAC_ENABLED=true
SESSION_TIMEOUT_MINUTES=480
FLASK_SECRET_KEY=your_secret_key_here_change_this_in_production
```

### Generate Secret Key

Generate a secure secret key:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

### Disable RBAC (Optional)

To disable RBAC and allow unrestricted access:

```bash
RBAC_ENABLED=false
```

When RBAC is disabled, all API endpoints are accessible without authentication.

## Initial Setup

### 1. Create Initial Admin User

Use the provided script to create your first admin user:

```bash
cd jenkins-capacity-report
python scripts/create_admin_user.py
```

You'll be prompted for:
- Username
- Password
- Email (optional)

### 2. Start the Application

```bash
python web_app.py
```

### 3. Login

Use the authentication API to login and get a token.

## API Authentication

### Login

**Endpoint**: `POST /api/auth/login`

**Request**:
```json
{
  "username": "admin",
  "password": "your_password"
}
```

**Response**:
```json
{
  "success": true,
  "token": "your_session_token_here",
  "user": {
    "username": "admin",
    "role": "admin",
    "email": "admin@example.com"
  },
  "message": "Welcome, admin!"
}
```

### Using the Token

Include the token in subsequent requests using one of these methods:

**1. Authorization Header (Recommended)**:
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:5000/api/excluded-nodes
```

**2. X-Auth-Token Header**:
```bash
curl -H "X-Auth-Token: YOUR_TOKEN" http://localhost:5000/api/excluded-nodes
```

**3. Query Parameter**:
```bash
curl "http://localhost:5000/api/excluded-nodes?auth_token=YOUR_TOKEN"
```

### Logout

**Endpoint**: `POST /api/auth/logout`

**Headers**: Include authentication token

**Response**:
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

## User Management API

### Get Current User Info

**Endpoint**: `GET /api/auth/me`

**Authentication**: Required

**Response**:
```json
{
  "user": {
    "username": "admin",
    "role": "admin",
    "email": "admin@example.com",
    "created_at": "2026-04-14T10:00:00Z",
    "last_login": "2026-04-14T14:00:00Z",
    "enabled": true
  }
}
```

### Change Password

**Endpoint**: `POST /api/auth/change-password`

**Authentication**: Required

**Request**:
```json
{
  "current_password": "old_password",
  "new_password": "new_password"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Password changed successfully. Please log in again."
}
```

**Note**: All sessions are invalidated after password change.

### List Users (Admin Only)

**Endpoint**: `GET /api/users`

**Authentication**: Admin role required

**Response**:
```json
{
  "users": [
    {
      "username": "admin",
      "role": "admin",
      "email": "admin@example.com",
      "created_at": "2026-04-14T10:00:00Z",
      "last_login": "2026-04-14T14:00:00Z",
      "enabled": true
    }
  ],
  "count": 1
}
```

### Create User (Admin Only)

**Endpoint**: `POST /api/users/create`

**Authentication**: Admin role required

**Request**:
```json
{
  "username": "newuser",
  "password": "secure_password",
  "role": "operator",
  "email": "newuser@example.com"
}
```

**Response**:
```json
{
  "success": true,
  "username": "newuser",
  "role": "operator",
  "message": "User newuser created successfully"
}
```

### Delete User (Admin Only)

**Endpoint**: `DELETE /api/users/<username>`

**Authentication**: Admin role required

**Response**:
```json
{
  "success": true,
  "message": "User newuser deleted successfully"
}
```

**Restrictions**:
- Cannot delete yourself
- Cannot delete the last admin user

### Update User Role (Admin Only)

**Endpoint**: `PUT /api/users/<username>/role`

**Authentication**: Admin role required

**Request**:
```json
{
  "role": "admin"
}
```

**Response**:
```json
{
  "success": true,
  "username": "newuser",
  "new_role": "admin",
  "message": "Role updated to admin for user newuser"
}
```

### Disable User (Admin Only)

**Endpoint**: `POST /api/users/<username>/disable`

**Authentication**: Admin role required

**Response**:
```json
{
  "success": true,
  "message": "User newuser disabled successfully"
}
```

**Note**: Disabled users cannot login. All their sessions are invalidated.

### Enable User (Admin Only)

**Endpoint**: `POST /api/users/<username>/enable`

**Authentication**: Admin role required

**Response**:
```json
{
  "success": true,
  "message": "User newuser enabled successfully"
}
```

## Protected Endpoints

### Excluded Nodes Management

| Endpoint | Method | Required Role | Description |
|----------|--------|---------------|-------------|
| `/api/excluded-nodes` | GET | None (optional auth) | View excluded nodes |
| `/api/excluded-nodes/get-reason/<node>` | GET | None (optional auth) | Get exclusion reason |
| `/api/excluded-nodes/add` | POST | operator, admin | Add excluded node |
| `/api/excluded-nodes/remove` | POST | operator, admin | Remove excluded node |
| `/api/excluded-nodes/set-reason` | POST | operator, admin | Update exclusion reason |
| `/api/excluded-nodes/clear` | POST | admin | Clear all excluded nodes |

### Example: Add Excluded Node with Authentication

```bash
# Login first
TOKEN=$(curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"operator1","password":"password"}' \
  | jq -r '.token')

# Add excluded node
curl -X POST http://localhost:5000/api/excluded-nodes/add \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"node_name":"broken-node-1","reason":"Hardware failure"}'
```

## RBAC Status and Information

### Check RBAC Status

**Endpoint**: `GET /api/rbac/status`

**Response**:
```json
{
  "rbac_enabled": true,
  "message": "RBAC is enabled"
}
```

### Get Role Descriptions

**Endpoint**: `GET /api/rbac/roles`

**Response**:
```json
{
  "roles": {
    "viewer": {
      "description": "Read-only access to all data",
      "permissions": [...]
    },
    "operator": {
      "description": "Can manage excluded nodes",
      "permissions": [...]
    },
    "admin": {
      "description": "Full system access",
      "permissions": [...]
    }
  },
  "rbac_enabled": true
}
```

## Security Best Practices

### 1. Strong Passwords

- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, and symbols
- Avoid common words or patterns

### 2. Secret Key Management

- Generate a unique secret key for production
- Never commit the secret key to version control
- Rotate the secret key periodically

### 3. Session Timeout

- Default: 8 hours (480 minutes)
- Adjust based on your security requirements
- Shorter timeouts = more secure but less convenient

### 4. HTTPS

- Always use HTTPS in production
- Tokens are sent with each request
- HTTP exposes tokens to interception

### 5. User Management

- Create separate accounts for each user
- Use the principle of least privilege
- Regularly review user accounts and roles
- Disable accounts for users who no longer need access

### 6. Audit Logging

- Review logs regularly for suspicious activity
- All excluded node changes are logged with username
- Monitor failed login attempts

## Troubleshooting

### Cannot Login

**Problem**: Authentication fails with valid credentials

**Solutions**:
1. Check if RBAC is enabled: `GET /api/rbac/status`
2. Verify user exists and is enabled
3. Check password is correct
4. Review application logs for errors

### Token Expired

**Problem**: API returns 401 after some time

**Solution**: Session has expired. Login again to get a new token.

### Permission Denied

**Problem**: API returns 403 Forbidden

**Solutions**:
1. Check your role: `GET /api/auth/me`
2. Verify the endpoint requires your role level
3. Review role permissions: `GET /api/rbac/roles`

### Lost Admin Access

**Problem**: No admin users can login

**Solution**: Use the `scripts/create_admin_user.py` script to create a new admin user. The script can be run even if other admin users exist.

## Migration from Non-RBAC

If you're upgrading from a version without RBAC:

1. **Backup your data**: Copy `data/excluded_nodes.json` and `data/metrics_history.json`
2. **Update configuration**: Add RBAC settings to `.env`
3. **Create admin user**: Run `python scripts/create_admin_user.py`
4. **Test with RBAC disabled**: Set `RBAC_ENABLED=false` to verify everything works
5. **Enable RBAC**: Set `RBAC_ENABLED=true`
6. **Create user accounts**: Create accounts for all users who need access
7. **Update scripts/tools**: Add authentication to any scripts that use the API

## Data Storage

### User Data

Stored in `data/users.json`:
```json
{
  "users": {
    "username": {
      "password_hash": "hashed_password",
      "role": "admin",
      "email": "user@example.com",
      "created_at": "2026-04-14T10:00:00Z",
      "created_by": "system",
      "last_login": "2026-04-14T14:00:00Z",
      "enabled": true
    }
  }
}
```

**Security Notes**:
- Passwords are hashed using werkzeug's PBKDF2-SHA256
- Never store plain text passwords
- Backup this file securely
- Restrict file permissions: `chmod 600 data/users.json`

### Session Data

Sessions are stored in memory and are lost when the application restarts. Users will need to login again after a restart.

## Support

For issues or questions:
1. Check this guide
2. Review application logs
3. Check the API documentation in `EXCLUDED-NODES-API.md`
4. Contact your system administrator

---

Made with Bob