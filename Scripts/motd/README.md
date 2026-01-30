# MOTD Scripts

Message of the Day system summary and metrics collection.

---

## `solen-motd.sh`

SOLEN system summary (fast MOTD) with --json and --plain.

### Purpose

Displays a compact system summary suitable for login MOTD. Shows host info, resource usage, updates available, and service status in a visually appealing format.

### Usage

```bash
../../serverutils run motd/solen-motd -- [options]
```

**Options**:
- `--full`: Show extended information
- `--plain`: No colors or formatting
- `--json`: Output JSON format
- `--quiet`: Minimal output

### Integration

To enable MOTD on login, install via:

```bash
./serverutils run install/install -- --with-motd --yes
```

This creates `/etc/update-motd.d/90-solen` which runs solen-motd.sh on each login.

### Manual Integration

Add to shell rc file:

```bash
# Show SOLEN MOTD on interactive login
if [[ $- == *i* ]] && command -v serverutils >/dev/null; then
  serverutils run motd/solen-motd 2>/dev/null || true
fi
```

### Example Output

```
╭─────────────────────────────────────────────────────────╮
│  myserver                    Ubuntu 22.04 │ up 15d 3h  │
├─────────────────────────────────────────────────────────┤
│  CPU  ████████░░░░░░░░░░░░  42%  │  MEM  ██████░░░░  52%│
│  DISK ████████████░░░░░░░░  65%  │  LOAD 0.42/core      │
├─────────────────────────────────────────────────────────┤
│  Updates: 12 available        │  Docker: 3/5 running   │
│  Services: sshd cron docker   │  Firewall: ufw active  │
╰─────────────────────────────────────────────────────────╯
```

### Dependencies

* Standard POSIX utilities
* `systemctl`: Service status (optional)
* `docker`: Container status (optional)

---

## `collect.sh`

Collect host metrics for MOTD (JSON only).

### Purpose

Gathers system metrics in JSON format for consumption by monitoring systems or custom MOTD implementations. Outputs only JSON, no human-readable format.

### Usage

```bash
../../serverutils run motd/collect -- --json
```

### Output

```json
{
  "status": "ok",
  "summary": "metrics collected",
  "ts": "2024-01-15T10:30:00Z",
  "host": "myserver",
  "metrics": {
    "cpu_pct": 42,
    "mem_pct": 52,
    "disk_root_pct": 65,
    "load15_per_core": 0.42,
    "updates_available": 12,
    "containers_running": 3,
    "containers_total": 5
  }
}
```

### Use Cases

- Custom MOTD scripts consuming JSON
- Monitoring system integration
- Dashboard data collection
- Scheduled metric snapshots

---
