# Health Check Scripts

Fast health monitoring with configurable thresholds.

---

## `check.sh`

Fast health checks with thresholds and rollup (root, disk, load, mem, services, docker).

### Purpose

Performs quick system health probes and compares results against configurable thresholds defined in `config/solen-health.yaml`. Returns an aggregated status (ok/warn/error) based on the most severe finding.

### Usage

```bash
../../serverutils run health/check -- [--dry-run] [--json]
```

**Options**:
- `--dry-run`: Preview check without executing (default)
- `--json`: Output JSON format

### Thresholds

Configure thresholds in `config/solen-health.yaml`:

```yaml
thresholds:
  disk_root_pct:
    warn: 85   # Warn when root disk usage exceeds 85%
    error: 95  # Error when exceeds 95%
  load15_per_core:
    warn: 1.0  # 15-min load average per core
    error: 2.0
  mem_pressure_pct:
    warn: 70
    error: 85

services:
  allow: ["sshd", "cron", "docker"]
```

### Checks Performed

| Check | Description |
|-------|-------------|
| Root disk | Percentage used on `/` |
| Load average | 15-minute load per CPU core |
| Memory | Percentage of memory used |
| Services | Status of monitored systemd services |
| Docker | Container health (if Docker present) |

### Dependencies

* `df`: Disk usage
* `awk`: Data processing
* `systemctl`: Service checks (optional)
* `docker`: Container checks (optional)
* `yq`: YAML parsing (optional, uses awk fallback)

### Example Output (JSON)

```json
{
  "status": "ok",
  "summary": "health ok: disk 45%, load 0.3/core, mem 52%",
  "ts": "2024-01-15T10:30:00Z",
  "host": "myserver",
  "metrics": {
    "disk_root_pct": 45,
    "load15_per_core": 0.3,
    "mem_pct": 52,
    "services_ok": 3,
    "containers_unhealthy": 0
  }
}
```

---
