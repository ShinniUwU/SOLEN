# Shared Libraries

Core helper functions and utilities used across SOLEN scripts.

---

## `solen.sh`

Core helper functions for SOLEN scripts.

### Purpose

Provides standardized utilities for flag parsing, JSON output, styled messages, and policy integration. All scripts should source this library for consistent behavior.

### Usage

```bash
#!/usr/bin/env bash
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

# Parse arguments
while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  # ... handle script-specific flags
done

# Output JSON or human-readable
if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "completed successfully" "" ""
else
  solen_ok "completed successfully"
fi
```

### Functions

| Function | Description |
|----------|-------------|
| `solen_init_flags` | Initialize standard flags (YES, JSON, DRYRUN) |
| `solen_parse_common_flag` | Parse --yes, --json, --dry-run flags |
| `solen_ts` | Return ISO 8601 timestamp |
| `solen_host` | Return hostname |
| `solen_info` | Blue info message |
| `solen_ok` | Green success message |
| `solen_warn` | Yellow warning message |
| `solen_err` | Red error message (to stderr) |
| `solen_head` | Blue section header |
| `solen_json_escape` | Escape string for JSON |
| `solen_json_record` | Emit standardized JSON record |
| `solen_json_record_full` | Emit JSON with custom details |

### Standard Flags

| Flag | Variable | Default | Description |
|------|----------|---------|-------------|
| `--yes` | `SOLEN_FLAG_YES` | 0 | Skip confirmation prompts |
| `--json` | `SOLEN_FLAG_JSON` | 0 | Output JSON format |
| `--dry-run` | `SOLEN_FLAG_DRYRUN` | 1 | Preview without executing |

---

## `deps.sh`

Dependency validation helpers.

### Purpose

Provides functions to validate that required commands, files, or permissions are available before script execution.

### Functions

| Function | Description |
|----------|-------------|
| `solen_require_cmds` | Exit if any command is missing |
| `solen_require_root` | Exit if not running as root |
| `solen_require_file` | Exit if file doesn't exist |

### Usage

```bash
. "${THIS_DIR}/../lib/deps.sh"

# Check required commands
solen_require_cmds docker jq curl

# Check root access
solen_require_root

# Check config file exists
solen_require_file "/etc/myapp/config.yaml" "configuration"
```

---

## `policy.sh`

Policy-based access control.

### Purpose

Implements YAML-based policy enforcement for controlling which operations scripts can perform. Reads policy from `config/solen-policy.yaml`.

### Functions

| Function | Description |
|----------|-------------|
| `solen_policy_allows_token` | Check if token is allowed |
| `solen_policy_allows_service_restart` | Check if service can be restarted |
| `solen_policy_allows_prune_path` | Check if path can be pruned |

### Policy Tokens

| Token | Used By | Purpose |
|-------|---------|---------|
| `ssh-config-apply` | ssh-harden.sh | Allow SSH config changes |
| `firewall-apply` | firewall-apply.sh | Allow firewall changes |
| `docker-introspection` | list-docker-info.sh | Allow Docker inspection |
| `backup-profile:<name>` | backups/run.sh | Allow backup profile |

---

## `pm.sh`

Package manager abstraction.

### Purpose

Provides cross-distro package management functions supporting apt, dnf, pacman, and zypper.

### Functions

| Function | Description |
|----------|-------------|
| `pm_detect` | Detect available package manager |
| `pm_name` | Return package manager name |
| `pm_update_plan` | Return update command |
| `pm_install_plan` | Return install command for packages |
| `pm_upgrade_plan` | Return upgrade command |

---

## `edit.sh`

File editing helpers with marker blocks.

### Purpose

Provides safe file modification using marker blocks that can be inserted, updated, or removed without affecting other content.

### Functions

| Function | Description |
|----------|-------------|
| `solen_insert_marker_block` | Insert content between markers |
| `solen_remove_marker_block` | Remove content between markers |

### Usage

```bash
. "${THIS_DIR}/../lib/edit.sh"

# Add configuration block
solen_insert_marker_block ~/.bashrc \
  "# --- SOLEN-BEGIN ---" \
  "# --- SOLEN-END ---" \
  'export PATH="$HOME/.local/bin:$PATH"'

# Remove configuration block
solen_remove_marker_block ~/.bashrc \
  "# --- SOLEN-BEGIN ---" \
  "# --- SOLEN-END ---"
```

---
