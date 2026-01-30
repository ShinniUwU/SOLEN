# Service Management Scripts

Systemd service management utilities.

---

## `ensure.sh`

Ensure systemd services (status/ensure-enabled/ensure-running/restart-if-failed).

### Purpose

Provides idempotent service management operations. Each command checks the current state before taking action, making it safe to run repeatedly.

### Usage

```bash
../../serverutils run services/ensure -- <command> --unit <name> [options]
```

**Commands**:
- `status`: Show unit active/enabled state
- `ensure-enabled`: Enable unit if not already enabled
- `ensure-running`: Enable and start unit if not running
- `restart-if-failed`: Restart unit only if in failed state

**Options**:
- `--unit <name>`: Systemd unit name (required)
- `--dry-run`: Preview actions (default)
- `--json`: Output JSON format
- `--yes`: Execute changes

### Examples

```bash
# Check service status
serverutils run services/ensure -- status --unit docker --json

# Ensure service is enabled (dry-run)
serverutils run services/ensure -- ensure-enabled --unit nginx

# Start service if not running
serverutils run services/ensure -- ensure-running --unit nginx --yes

# Restart only if failed
serverutils run services/ensure -- restart-if-failed --unit myapp --yes
```

### Dependencies

* `systemctl`: Required (exits gracefully on non-systemd hosts)
* `sudo`: For enable/start/restart operations

### Example Output (JSON)

```json
{
  "status": "ok",
  "summary": "nginx active,enabled",
  "ts": "2024-01-15T10:30:00Z",
  "host": "myserver",
  "metrics": {
    "active": true,
    "enabled": true
  }
}
```

### Non-systemd Hosts

On systems without systemd, the script exits with status 3 and a warning:

```json
{
  "status": "warn",
  "summary": "non-systemd host (degraded)"
}
```

### Security

Unit names are validated to only allow alphanumeric characters, dashes, underscores, dots, and @ symbols. This prevents command injection through malicious unit names.

---
