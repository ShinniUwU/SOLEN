# SOLEN — First 5 Minutes

- Prerequisites
  - Debian or Fedora host; no Docker required
  - Tools: `bash`, `jq`, `curl` (optional `yq` for richer health thresholds)
  - Install runner (user): `./serverutils install-runner --user` then ensure `~/.local/bin` is in `PATH`
  - Or run from the repo: prefix commands with `./serverutils`

- Quickstart (one command)
  - `serverutils setup`
    - Copies example policy to `~/.serverutils/policy.yaml`
    - Installs user systemd units into `~/.config/systemd/user/`
    - Logs default to `~/.local/share/solen` (user sessions)
    - Shows resolved audit path the first time it writes (e.g., `audit log: ~/.local/share/solen/audit.log`)

- Inventory (prove it’s fast and structured)
  - Human: `serverutils run inventory/host-info`
    - Expect: OS, kernel, uptime, cores/mem, root disk %, mounts/disks, default route, docker presence, key services
  - JSON: `serverutils run inventory/host-info -- --json`
    - Expect: a single NDJSON record with `op: "inventory"`, `metrics` (cores, mem totals/used, disk_root_used_pct, mounts/disks) and `details.os/kernel/uptime/network/services`
    - Grep example: `tail -n1 ~/.local/share/solen/audit.log | grep inventory`

- Backups (safe by default)
  - Dry-run enforced: `serverutils run backups/run -- run --profile etc --json`
    - Expect: a `warn` record indicating dry-run enforced and a `begin:` line, then a rollup line describing planned actions
    - Policy gates: requires tokens like `backup-profile:etc` and `backup-path:/var/backups/solen` (see `config/solen-policy.example.yaml`)
  - Real changes: add `--yes` (or `SOLEN_ASSUME_YES=1`) once your policy allows it

- Health (actionable rollup)
  - JSON: `serverutils run health/check -- --json`
    - Expect: a single NDJSON rollup with `metrics.disk_root_pct`, `metrics.load15_per_core`, `metrics.mem_pressure_pct`, `metrics.failed_services`, `metrics.unhealthy_containers`
    - Thresholds: reads from `config/solen-health.yaml` (uses `yq` if present, otherwise lightweight fallback); status is `ok|warn|error`

- Security posture (read-only)
  - Baseline: `serverutils run security/baseline-check -- --json`
    - Checks: sshd root/password auth, firewall presence, fail2ban, time sync, ASLR, sudoers; status indicates `ok|warn|error`
  - Firewall: `serverutils run security/firewall-status -- --json`
    - Shows what firewall exists and if it’s enabled; read-only

- Logs (where they land)
  - User sessions: `~/.local/share/solen/*.ndjson` and audit.log
  - System units (root): `/var/log/solen/*.ndjson` (created via ExecStartPre)
  - Tail example: `tail -F ~/.local/share/solen/*.ndjson`

- Bonus (timers in user scope)
  - Install units: `serverutils install-units --user`
  - Enable: `systemctl --user daemon-reload && systemctl --user enable --now solen-health.timer`
  - Verify: `sleep 65 && tail -n1 ~/.local/share/solen/health.ndjson`

- Enabling SOLEN MOTD automatically (interactive shells)
  - Bash (`~/.bashrc`): `[[ $- == *i* ]] && serverutils run motd/solen-motd -- --plain`
  - Zsh (`~/.zshrc`): `[[ $- == *i* ]] && serverutils run motd/solen-motd -- --plain`
  - Fish (`~/.config/fish/config.fish`):
    `if status is-interactive; serverutils run motd/solen-motd -- --plain; end`
  - Tip: `serverutils setup-motd` prints a copy‑paste snippet; see docs/MOTD.md for admin/SSH options and performance notes.

- Notes
  - All commands above succeed without root (except operations that require privileges; health and inventory degrade gracefully)
  - Docker commands are skipped when the daemon is not available
  - The runner emits an audit line for each invocation; grep it to see activity quickly
