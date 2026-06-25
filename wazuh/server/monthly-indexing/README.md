# Wazuh Monthly Index Configuration

## Overview

By default, Wazuh creates **daily** OpenSearch/Elasticsearch indices in the format:

```
wazuh-alerts-4.x-YYYY.MM.DD
```

This runbook documents the changes made to switch to **monthly** indices:

```
wazuh-alerts-4.x-YYYY.MM
```

This reduces index proliferation and simplifies storage management for lower-volume environments.

---

## Changes Required

Two changes are needed:

1. **Index template** — Re-apply the `wazuh` template to ensure correct index settings
2. **Filebeat ingest pipeline** — Change `index_name_format` from daily to monthly

> **Note:** `filebeat.yml` does not need to be changed. The index name is determined entirely by the `date_index_name` processor in the ingest pipeline, which overrides any index name set in Filebeat's output configuration.

---

## Step 1 — Apply the Index Template

Push a legacy index template to the Wazuh indexer. This overwrites the default `wazuh` template to ensure the correct index settings are applied.

```bash
curl -k -u admin:<password> \
  -X PUT "https://127.0.0.1:9200/_template/wazuh" \
  -H "Content-Type: application/json" \
  -d '{
    "order": 0,
    "version": 1,
    "index_patterns": [
      "wazuh-alerts-4.x-*",
      "wazuh-archives-4.x-*",
      "wazuh-alerts-4.x-2*"
    ],
    "settings": {
      "index": {
        "mapping": {
          "total_fields": {
            "limit": "10000"
          }
        },
        "refresh_interval": "5s",
        "number_of_shards": "3",
        "auto_expand_replicas": "0-1",
        "number_of_replicas": "0"
      }
    }
  }'
```

> **Note:** Replace `<password>` with the OpenSearch admin password. This uses the legacy `_template` API (not `_index_template`). The template name `wazuh` matches the default Wazuh template name, so this effectively replaces it in place.

---

## Step 2 — Edit the Filebeat Ingest Pipeline

**File:** `/usr/share/filebeat/module/wazuh/alerts/ingest/pipeline.json`

Locate the `date_index_name` processor and change `index_name_format` from `yyyy.MM.dd` to `yyyy.MM`.

**Before (daily):**
```json
{
  "date_index_name": {
    "field": "timestamp",
    "date_rounding": "d",
    "index_name_prefix": "{{fields.index_prefix}}",
    "index_name_format": "yyyy.MM.dd",
    "ignore_failure": false
  }
}
```

**After (monthly):**
```json
{
  "date_index_name": {
    "field": "timestamp",
    "date_rounding": "d",
    "index_name_prefix": "{{fields.index_prefix}}",
    "index_name_format": "yyyy.MM",
    "ignore_failure": false
  }
}
```

> **Note:** Only `index_name_format` changes — `date_rounding` stays as `"d"`. The format `yyyy.MM` produces index names like `wazuh-alerts-4.x-2026.06`.

---

## Step 3 — Restart Filebeat

Apply the changes:

```bash
sudo systemctl restart filebeat
sudo systemctl status filebeat
```

Check logs to confirm it is writing to the correct monthly index:

```bash
sudo journalctl -u filebeat -f
```

---

## Verification

Confirm monthly indices are being created in the indexer:

```bash
curl -k -u admin:<password> \
  -X GET "https://127.0.0.1:9200/_cat/indices/wazuh-alerts-4.x-*?v&s=index"
```

You should see index names in the form `wazuh-alerts-4.x-2026.06` rather than `wazuh-alerts-4.x-2026.06.01`.

---

## Rollback

To revert to daily indexing, reverse both changes and restart Filebeat.

### 1 — Restore the pipeline

Edit `/usr/share/filebeat/module/wazuh/alerts/ingest/pipeline.json` and change `index_name_format` back to `yyyy.MM.dd`:

```json
{
  "date_index_name": {
    "field": "timestamp",
    "date_rounding": "d",
    "index_name_prefix": "{{fields.index_prefix}}",
    "index_name_format": "yyyy.MM.dd",
    "ignore_failure": false
  }
}
```

### 2 — Restore the index template

Re-apply the default Wazuh template with the original `version` value so it is recognised as a rollback:

```bash
curl -k -u admin:<password> \
  -X PUT "https://127.0.0.1:9200/_template/wazuh" \
  -H "Content-Type: application/json" \
  -d '{
    "order": 0,
    "version": 1,
    "index_patterns": [
      "wazuh-alerts-4.x-*",
      "wazuh-archives-4.x-*",
      "wazuh-alerts-4.x-2*"
    ],
    "settings": {
      "index": {
        "mapping": {
          "total_fields": {
            "limit": "10000"
          }
        },
        "refresh_interval": "5s",
        "number_of_shards": "3",
        "auto_expand_replicas": "0-1",
        "number_of_replicas": "0"
      }
    }
  }'
```

### 3 — Restart Filebeat

```bash
sudo systemctl restart filebeat
sudo systemctl status filebeat
```

> **Note:** Existing monthly indices are not affected — only new alerts will go into daily indices going forward.

---

## Notes

- Existing daily indices are **not affected** — they remain as-is. Only new alerts will go into monthly indices.
- If the Wazuh dashboard index pattern does not match `wazuh-alerts-4.x-*` already, no changes are needed there.
- These changes survive Filebeat service restarts but **not** Filebeat package upgrades — `pipeline.json` may be overwritten on upgrade. Re-apply Step 2 after any Filebeat upgrade.
- `filebeat.yml` does not need to be modified. The `date_index_name` processor in the pipeline controls the final index name and takes precedence over the output index setting in Filebeat.
