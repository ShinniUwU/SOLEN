# SOLEN Logging

SOLEN writes NDJSON records and an audit log to a single log home with clear
precedence and a safe user fallback.

- System/root: `/var/log/solen`
- User sessions: `~/.local/share/solen`
- Override (both modes): set `SOLEN_LOG_DIR=/path/to/logs`
- Runner audit explicit overrides: `SOLEN_AUDIT_LOG` (file) or `SOLEN_AUDIT_DIR`

The runner prints the resolved audit log path the first time it writes in a
session, for easy discovery:

```
ℹ️  audit log: /var/log/solen/audit.log
```

Systemd units
- User units append to `%h/.local/share/solen/*.ndjson`
- Global (system) units append to `/var/log/solen/*.ndjson` and ensure the
  directory exists (`ExecStartPre=/usr/bin/env mkdir -p /var/log/solen`)

Log rotation

If you use `/var/log/solen`, add a simple logrotate rule at `/etc/logrotate.d/solen`:

```
/var/log/solen/*.ndjson /var/log/solen/audit.log {
  daily
  rotate 14
  compress
  missingok
  notifempty
  copytruncate
}
```

NDJSON Structure

See `docs/json-schema/solen.script.schema.json` for the schema. Scripts emit a
unified envelope with fields: `status`, `summary`, `ts`, `host`, optional `op`,
optional `details`, `metrics`, `actions`.
