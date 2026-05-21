# Testing the Node Exclusion Feature Locally

## Prerequisites

1. Ensure you have Python 3.8+ installed
2. Install dependencies:
   ```bash
   cd jenkins-capacity-report
   pip install -r requirements.txt
   ```

3. Configure your Jenkins credentials in `.env`:
   ```bash
   cp .env.example .env
   # Edit .env with your Jenkins URL, username, and API token
   ```

## Running the Application

### Start the Web Server

```bash
cd jenkins-capacity-report
python web_app.py
```

You should see output like:
```
 * Serving Flask app 'web_app'
 * Debug mode: on
 * Running on http://0.0.0.0:5000
```

### Access the Dashboard

Open your browser to: **http://localhost:5000**

## Testing the Exclusion Feature

### 1. View All Nodes
- Click on the **"🖥️ All Nodes"** tab
- You should see all your Jenkins nodes listed by category and provider
- Each node has an **"✕ Exclude"** button in the Action column

### 2. Exclude a Node
- Find any node in the "All Nodes" tab
- Click the **"✕ Exclude"** button next to it
- Confirm the action in the dialog
- The page will reload automatically

### 3. Verify Exclusion
After excluding a node, verify:

**In the Overview tab:**
- Total node count should decrease by 1
- Online/offline counts should adjust accordingly
- Quick stats should reflect the change

**In the Excluded Nodes tab:**
- Click the **"🚫 Excluded Nodes"** tab (should show count badge)
- Your excluded node should appear here with a red theme
- The node has an **"✓ Include"** button

**In other tabs:**
- The excluded node should NOT appear in:
  - Detailed Breakdown
  - All Nodes listing
  - Category listings
  - Filter results

### 4. Include a Node Back
- Go to the **"🚫 Excluded Nodes"** tab
- Click the **"✓ Include"** button next to the excluded node
- Confirm the action
- The page will reload and the node returns to normal reporting

### 5. Test Multiple Exclusions
- Exclude 2-3 different nodes
- Verify the count badge updates on the "Excluded Nodes" tab
- Check that all statistics exclude these nodes

### 6. Clear All Exclusions
- Go to the **"🚫 Excluded Nodes"** tab
- Click the **"Clear All Excluded Nodes"** button
- Confirm the action
- All nodes should return to active reporting

## Testing API Endpoints Directly

You can also test the API endpoints using curl:

### Get excluded nodes list
```bash
curl http://localhost:5000/api/excluded-nodes
```

### Add a node to exclusion
```bash
curl -X POST http://localhost:5000/api/excluded-nodes/add \
  -H "Content-Type: application/json" \
  -d '{"node_name": "test-node-01"}'
```

### Remove a node from exclusion
```bash
curl -X POST http://localhost:5000/api/excluded-nodes/remove \
  -H "Content-Type: application/json" \
  -d '{"node_name": "test-node-01"}'
```

### Clear all exclusions
```bash
curl -X POST http://localhost:5000/api/excluded-nodes/clear \
  -H "Content-Type: application/json"
```

## Verifying Persistence

1. Exclude a few nodes
2. Stop the web server (Ctrl+C)
3. Check that `data/excluded_nodes.json` exists in the directory
4. Restart the web server: `python web_app.py`
5. Verify the excluded nodes are still excluded (check the Excluded Nodes tab)

## Expected File Structure After Testing

```
jenkins-capacity-report/
├── data/
│   └── excluded_nodes.json      # Created automatically when you exclude nodes
├── src/
│   ├── excluded_nodes.py        # New module
│   └── ...
├── web_app.py                   # Updated with exclusion logic
└── templates/
    └── dashboard.html           # Updated with new tab and buttons
```

## Troubleshooting

### Issue: "Failed to fetch Jenkins data"
- Check your `.env` file has correct credentials
- Verify Jenkins URL is accessible
- Ensure API token is valid

### Issue: Buttons don't work
- Check browser console for JavaScript errors (F12)
- Verify you're using a modern browser (Chrome, Firefox, Edge, Safari)

### Issue: Excluded nodes still appear in counts
- Hard refresh the page (Ctrl+F5 or Cmd+Shift+R)
- Check that the exclusion was successful in the Excluded Nodes tab

### Issue: data/excluded_nodes.json not created
- Check file permissions in the data directory
- Verify the application has write access

## What to Look For

✅ **Working correctly if:**
- Excluded nodes disappear from all statistics
- Excluded Nodes tab shows correct count
- Include/Exclude buttons work with confirmation
- Page reloads after each action
- Exclusions persist after restart
- data/excluded_nodes.json file is created/updated

❌ **Problem if:**
- Excluded nodes still appear in counts
- Buttons don't trigger any action
- No confirmation dialogs appear
- data/excluded_nodes.json is not created
- Exclusions don't persist after restart

## Need Help?

If you encounter issues:
1. Check the terminal output for error messages
2. Check browser console (F12) for JavaScript errors
3. Verify all files were updated correctly
4. Ensure you're running the latest code