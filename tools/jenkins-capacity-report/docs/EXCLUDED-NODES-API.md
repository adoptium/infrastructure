# Excluded Nodes API with Reasons

This document describes the API endpoints for managing excluded nodes with exclusion reasons.

## Overview

The excluded nodes feature now supports tracking reasons for why nodes are excluded. This helps maintain documentation and context for exclusions.

## API Endpoints

### 1. Get All Excluded Nodes

**Endpoint:** `GET /api/excluded-nodes`

**Description:** Retrieves all excluded nodes with their reasons.

**Response:**
```json
{
  "excluded_nodes": ["node1", "node2"],
  "excluded_nodes_with_reasons": {
    "node1": "Hardware failure",
    "node2": "Maintenance scheduled"
  },
  "count": 2
}
```

### 2. Add Excluded Node

**Endpoint:** `POST /api/excluded-nodes/add`

**Description:** Adds a node to the excluded list with an optional reason.

**Request Body:**
```json
{
  "node_name": "node1",
  "reason": "Hardware failure"
}
```

**Response:**
```json
{
  "success": true,
  "added": true,
  "node_name": "node1",
  "reason": "Hardware failure",
  "message": "Node 'node1' added to excluded list"
}
```

**Notes:**
- `reason` is optional. If not provided, an empty string is stored.
- If the node is already excluded, `added` will be `false`.

### 3. Remove Excluded Node

**Endpoint:** `POST /api/excluded-nodes/remove`

**Description:** Removes a node from the excluded list and deletes its reason.

**Request Body:**
```json
{
  "node_name": "node1"
}
```

**Response:**
```json
{
  "success": true,
  "removed": true,
  "node_name": "node1",
  "message": "Node 'node1' removed from excluded list and reason deleted"
}
```

**Notes:**
- When a node is removed, its exclusion reason is automatically deleted.

### 4. Set/Update Exclusion Reason

**Endpoint:** `POST /api/excluded-nodes/set-reason`

**Description:** Sets or updates the exclusion reason for an already excluded node.

**Request Body:**
```json
{
  "node_name": "node1",
  "reason": "Updated reason: Extended maintenance"
}
```

**Response:**
```json
{
  "success": true,
  "node_name": "node1",
  "reason": "Updated reason: Extended maintenance",
  "message": "Updated exclusion reason for node 'node1'"
}
```

**Error Response (404):**
```json
{
  "error": "Node 'node1' is not in the excluded list"
}
```

**Notes:**
- The node must already be in the excluded list.
- Use this endpoint to add or update reasons for nodes that were excluded without a reason.

### 5. Get Exclusion Reason

**Endpoint:** `GET /api/excluded-nodes/get-reason/<node_name>`

**Description:** Retrieves the exclusion reason for a specific node.

**Response:**
```json
{
  "node_name": "node1",
  "reason": "Hardware failure",
  "is_excluded": true
}
```

**Error Response (404):**
```json
{
  "error": "Node 'node1' is not in the excluded list"
}
```

### 6. Clear All Excluded Nodes

**Endpoint:** `POST /api/excluded-nodes/clear`

**Description:** Clears all excluded nodes and their reasons.

**Response:**
```json
{
  "success": true,
  "cleared_count": 5,
  "message": "Cleared 5 nodes from excluded list"
}
```

## Data Storage

Excluded nodes and their reasons are stored in `data/excluded_nodes.json` with the following format:

```json
{
  "excluded_nodes": {
    "node1": "Hardware failure",
    "node2": "Maintenance scheduled",
    "node3": ""
  }
}
```

## Backward Compatibility

The system supports loading old format files (list of node names) and automatically converts them to the new format (dictionary with reasons). Nodes loaded from the old format will have empty reasons.

## Usage Examples

### Using curl

```bash
# Add a node with a reason
curl -X POST http://localhost:5000/api/excluded-nodes/add \
  -H "Content-Type: application/json" \
  -d '{"node_name": "broken-node-1", "reason": "Disk failure"}'

# Update the reason for an excluded node
curl -X POST http://localhost:5000/api/excluded-nodes/set-reason \
  -H "Content-Type: application/json" \
  -d '{"node_name": "broken-node-1", "reason": "Disk failure - RMA in progress"}'

# Get all excluded nodes with reasons
curl http://localhost:5000/api/excluded-nodes

# Get reason for a specific node
curl http://localhost:5000/api/excluded-nodes/get-reason/broken-node-1

# Remove a node (deletes the reason too)
curl -X POST http://localhost:5000/api/excluded-nodes/remove \
  -H "Content-Type: application/json" \
  -d '{"node_name": "broken-node-1"}'
```

### Using JavaScript/Fetch

```javascript
// Add a node with a reason
async function addExcludedNode(nodeName, reason) {
  const response = await fetch('/api/excluded-nodes/add', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ node_name: nodeName, reason: reason })
  });
  return await response.json();
}

// Update reason for an excluded node
async function updateExclusionReason(nodeName, reason) {
  const response = await fetch('/api/excluded-nodes/set-reason', {
    method: 'POST',
    headers: { 'Content-Type': application/json' },
    body: JSON.stringify({ node_name: nodeName, reason: reason })
  });
  return await response.json();
}

// Get all excluded nodes with reasons
async function getExcludedNodes() {
  const response = await fetch('/api/excluded-nodes');
  return await response.json();
}
```

## Best Practices

1. **Always provide a reason** when excluding a node to maintain documentation.
2. **Update reasons** as the situation changes (e.g., from "Hardware failure" to "Hardware failure - RMA submitted").
3. **Use descriptive reasons** that explain why the node is excluded and any relevant context.
4. **Review excluded nodes regularly** to ensure they're still relevant and reasons are up to date.

## Migration from Old Format

If you have an existing `data/excluded_nodes.json` file in the old format (list of node names), it will be automatically converted to the new format on first load. All existing nodes will have empty reasons, which you can then update using the `set-reason` endpoint.