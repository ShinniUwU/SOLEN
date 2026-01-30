# Inventory Scripts

Fast read-only host information gathering.

---

## `host-info.sh`

Fast host inventory (OS, kernel, CPU/mem, disks, nics, docker, services).

### Purpose

Collects a quick snapshot of host information in under 1 second. Entirely read-only - makes no changes to the system. Useful for inventory systems, monitoring dashboards, or quick system overview.

### Usage

```bash
../../serverutils run inventory/host-info -- [--json]
```

**Options**:
- `--json`: Output JSON format (for automation)

### Information Collected

| Category | Details |
|----------|---------|
| OS | Distribution name, version |
| Kernel | Linux kernel version |
| Uptime | Days, hours, minutes |
| CPU | Core count |
| Memory | Total and used (MiB) |
| Disks | Count, mount count, root usage % |
| Network | Default interface, gateway, IPv4/IPv6 |
| Docker | Container count (total, running, unhealthy) |
| Services | Status of sshd, cron, docker |

### Dependencies

* `awk`: Data processing
* `uname`: Kernel info
* `ip`: Network info (iproute2)
* `lsblk`: Disk enumeration
* `docker`: Container info (optional)
* `systemctl`: Service status (optional)

### Example Output (Human)

```
--- Host ---
myserver — Ubuntu 22.04.3 LTS (kernel 5.15.0-91-generic, uptime 15d 3h 42m)
--- CPU/Mem ---
cores: 4, mem: 2048/8192 Mi
--- Disks ---
/ used: 45% ; disks: 2, mounts: 5
--- Network ---
iface: eth0, gateway: 192.168.1.1, ipv4: 192.168.1.100/24, ipv6: fe80::1/64
--- Docker ---
present: 1, running: 3/5, unhealthy: 0
--- Services ---
sshd: active, cron: active, docker: active
```

### Example Output (JSON)

```json
{
  "status": "ok",
  "summary": "Ubuntu 22.04.3 LTS; 4c/8192Mi; disks 2, mounts 5; net eth0; docker 3/5",
  "ts": "2024-01-15T10:30:00Z",
  "host": "myserver",
  "metrics": {
    "cores": 4,
    "mem_total_mi": 8192,
    "mem_used_mi": 2048,
    "disk_root_used_pct": 45,
    "disks": 2,
    "mounts": 5,
    "containers_total": 5,
    "containers_running": 3,
    "containers_unhealthy": 0
  },
  "details": {
    "os": "Ubuntu 22.04.3 LTS",
    "kernel": "5.15.0-91-generic",
    "uptime": "15d 3h 42m",
    "network": {
      "default_iface": "eth0",
      "gateway": "192.168.1.1",
      "ipv4": "192.168.1.100/24",
      "ipv6": "fe80::1/64"
    },
    "services": {
      "sshd": "active",
      "cron": "active",
      "docker": "active"
    }
  }
}
```

---
