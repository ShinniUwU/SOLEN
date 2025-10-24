# SOLEN Specification

This document standardizes flags, outputs, exit codes, metadata, and safety rules for all SOLEN scripts. It is implementation‑agnostic and applies to Bash/POSIX scripts as well as future Python plugins.

## Unified Flags and Environment

- Precedence: CLI flags > environment > defaults
- Flags: `--dry-run`, `--json`, `--yes`
- Environment mirrors (used when flags aren’t supported):
  - `SOLEN_NOOP=1` (dry run)
  - `SOLEN_JSON=1` (JSON output)
  - `SOLEN_ASSUME_YES=1` (non‑interactive approval)
  - `SOLEN_VERBOSE=1` (more debug details)
  - `SOLEN_PLAIN=1` (ASCII only; suppress emojis/ANSI)

Rules:
- Scripts must not fail if unknown flags are present; they should ignore or degrade safely.
- Env vars take effect even if flags are not supported by the script.

## Exit Codes

- `0` = ok
- `1` = user error (bad args, invalid input)
- `2` = environment/dependency missing
- `3` = partial success (some actions succeeded)
- `4` = action refused by policy
- `>=10` = script‑specific codes

Examples:
- `1` user error: missing required argument, invalid path.
- `2` env/deps: required tool not installed, no permission to read.
- `3` partial: some services restarted, others failed; some files pruned, others locked.
- `4` refused: policy denies restarting `docker` on this host.

## JSON Contract

All scripts must support `--json` (or `SOLEN_JSON=1`). For multi‑record streams, output newline‑delimited JSON (NDJSON). Minimal schema:

```json
{
  "status": "ok|warn|error",
  "summary": "one line human summary",
  "details": {},
  "metrics": {},
  "actions": ["..."],
  "logs": ["line", "line"],
  "ts": "RFC3339 UTC",
  "host": "hostname"
}
```

Notes:
- `details` is an object for structured fields.
- `metrics` is a flat object of numbers (e.g., `disk_used_pct`, `containers_healthy`).
- For multi‑record output, each record must be a single line.
 - For multi‑record output, include a final rollup line with totals and status.

## Dry‑Run Protocol

- With `--dry-run`/`SOLEN_NOOP=1` scripts must not mutate state.
- Print exact commands and paths that would be modified.
- Keep a running counter of creates/modifies/deletes; end with: `would change N items`.

## Audit Lines

- Emit one NDJSON record per high‑level action (using the JSON schema above).
- Also print a short human line for grepability.
- The runner appends these to `.serverutils/audit.log`.
 - Audit log path can be overridden via `SOLEN_AUDIT_LOG` or `SOLEN_AUDIT_DIR`.

## CLI/UX Verbs and Addressing

- Verbs: `list`, `info`, `check`, `fix`, `ensure`, `backup`, `restore`.
- Addressing: scripts are addressable by `category/name`, bare `name`, and alias (from metadata header).
- Destructive actions require `--yes` or `SOLEN_ASSUME_YES=1` and must explain what is destroyed and how to undo.

## Script Metadata Header

Each script includes a header block after the shebang:

```
# SOLEN-META:
# name: docker/list-docker-info
# summary: List containers/images and basic health
# requires: docker
# tags: docker,inventory
# verbs: info
# outputs: status, details.containers[], details.images[]
# root: false
# since: 0.1.0
# breaking: false
```

`serverutils list --json` may surface this metadata in the future.

## Inventory v1 (Minimum Lovable)

- OS/kernel/uptime, CPU/mem totals, disks and mounts (`lsblk`), NICs (`ip -j`), docker containers (if present), LXC guests (if tools present), service highlights (`sshd`, `cron`, `docker`).
- Human summary: e.g., `Debian 12, 8c/16G, 2 disks, 3 mounts, 2 NICs, Docker: 6 containers (5 healthy)`.
- Constraints: runs <1s, no root required, degrades gracefully.

## Package Abstraction (Apt + Dnf)

Modes: `check` (list updates), `update` (refresh indexes), `upgrade` (apply), `security` (if supported), `autoremove`.

Dry‑run must show concrete package actions, estimated size, and whether reboot is required.

## Services Management

- Verbs: `status`, `ensure-enabled`, `ensure-running`, `restart-if-failed`.
- On non‑systemd hosts: return `status=warn` instead of hard error.

## Backups and Restore

- Profiles in YAML: `name`, `sources`, `exclude`, `dest`, `retention_days`, `pre/post hooks`.
- Commands: `backup run <profile>`, `backup prune <profile>`.
- Dry‑run prints file lists, bytes to transfer/delete.

## Monitoring and Health (Fast Checks)

- Disk space thresholds, load average vs cores, memory pressure, critical services status, container health counts, time sync drift.
- Non‑zero exit when failing checks.

## Observability Hooks

- Webhook sinks (Slack/Discord/etc.) via config.
- Prefer a single `--json` stream; shipping to Prometheus/Loki handled by a sidecar.

## Governance and Safety

- Policy file defines allow/deny (services that may be restarted, prunable paths, etc.).
- Scripts read policy and may exit `4` (refused) when not allowed.
- Change journal: append NDJSON to `.serverutils/audit.log` and rotate to `/var/log/solen/` when present.

## Distro and Env Resilience

- Always check tool presence (`command -v`).
- If missing, degrade with `status=warn` and suggest how to enable it.
- Prefer small adapters per platform (e.g., `pkg/apt`, `pkg/dnf`).

## Testing and Quality Gates

- Golden JSON fixtures for `--json` outputs.
- Smoke tests in containers for Debian and Fedora.
- Pre‑commit: scripts must respond to `--help`, `--json`, and `--dry-run`.

## Roadmap (Outcome‑based)

1. Standardize flags + JSON + exit codes.
2. Inventory v1 with clear summary and counts.
3. Package abstraction (apt+dnf) with `check/update/upgrade`.
4. Service ensure for allow‑listed units.
5. Backups v1 with profiles + retention (dry‑run first).
6. Health v1 (fast checks + actionable summaries).
7. Webhook sink for errors/warnings.
8. Policy file + refuse dangerous ops without explicit allow.
