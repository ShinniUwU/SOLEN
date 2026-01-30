# Package Management Scripts

Unified package management abstraction for apt and dnf.

---

## `manage.sh`

Unified package management (apt+dnf): check/update/upgrade/autoremove.

### Purpose

Provides a consistent interface for package management across Debian-based (apt) and Red Hat-based (dnf) systems. Auto-detects the available package manager or allows explicit selection.

### Usage

```bash
../../serverutils run pkg/manage -- <command> [options]
```

**Commands**:
- `check`: Check for available updates
- `update`: Update package lists (apt update / dnf makecache)
- `upgrade`: Install available upgrades
- `autoremove`: Remove unused dependencies

**Options**:
- `--dry-run`: Preview actions (default)
- `--json`: Output JSON format
- `--yes`: Execute changes
- `--manager apt|dnf`: Force specific package manager

### Examples

```bash
# Check for updates (read-only)
serverutils run pkg/manage -- check --json

# Preview upgrade
serverutils run pkg/manage -- upgrade --dry-run

# Execute upgrade
serverutils run pkg/manage -- upgrade --yes

# Remove unused packages
serverutils run pkg/manage -- autoremove --yes
```

### Dependencies

* `apt-get` or `dnf`: At least one must be available
* `sudo`: For update/upgrade/autoremove operations

### Example Output (JSON)

```json
{
  "status": "ok",
  "summary": "updates available: 12",
  "ts": "2024-01-15T10:30:00Z",
  "host": "myserver",
  "metrics": {
    "packages": 12,
    "size_kb": 45000,
    "reboot": false
  }
}
```

### Package Manager Detection

1. Checks for explicit `--manager` flag
2. Auto-detects: apt-get > dnf > none
3. Exits with error if no package manager found

---
