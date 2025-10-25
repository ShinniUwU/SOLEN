# SOLEN MOTD (System Summary)

A calm, minimal system summary with a European‑industrial vibe, aligned with SOLEN branding.

- Uses the SOLEN banner from `asciiart.ascii`.
- Professional, legible, and constrained to 80 columns.
- Fast: targets < 150 ms on a typical VM.

## What it shows

- Hostname, OS, Kernel, Uptime
- CPU load (1/5/15), cores, 15m load per core
- Memory: used / cache / available (with simple `[#####-----]` bar)
- Swap: used / total (with bar)
- Disk: `/` and `/boot` used / total (with bar)
- Network: default interface, IPv4, IPv6 if present (degrades if `ip` missing)

## Usage

Run directly:

```
Scripts/motd/solen-motd.sh
Scripts/motd/solen-motd.sh --plain   # no colors/emojis
Scripts/motd/solen-motd.sh --json    # one-line JSON (no other output)
```

From the SOLEN runner:

```
./serverutils run motd/solen-motd
```

## Enable Automatically (Interactive Shells)

Keep it modular: do not paste the script inline. Add a tiny wrapper that only runs in interactive shells.

- Bash — append to `~/.bashrc`:
  `[[ $- == *i* ]] && serverutils run motd/solen-motd -- --plain`

- Zsh — append to `~/.zshrc`:
  `[[ $- == *i* ]] && serverutils run motd/solen-motd -- --plain`

- Fish — append to `~/.config/fish/config.fish`:
  `if status is-interactive`
  `    serverutils run motd/solen-motd -- --plain`
  `end`

Reload: `exec $SHELL`. Remove the one line to disable.

Tip: `serverutils setup-motd` prints the above snippet for copy‑paste.

## Toggling

- Plain mode: set `SOLEN_PLAIN=1`.
- Disable entirely: set `SOLEN_MOTD_DISABLE=1` in your shell profile.
- JSON piping: `Scripts/motd/solen-motd.sh --json >> ~/.local/share/solen/motd.ndjson`.
- Quiet idea (optional): `serverutils run motd/solen-motd -- --plain --quiet` — keep ready for later if you want reduced output.

## Systemd examples (optional)

User service that appends JSON to an NDJSON log:

```
~/.config/systemd/user/solen-motd.service:
[Unit]
Description=SOLEN MOTD JSON Emit

[Service]
Type=oneshot
ExecStart=%h/Downloads/ServerUtils/Scripts/motd/solen-motd.sh --json
StandardOutput=append:%h/.local/share/solen/motd.ndjson
StandardError=journal
Environment=SOLEN_PLAIN=1

~/.config/systemd/user/solen-motd.timer:
[Unit]
Description=Run SOLEN MOTD every 15 minutes

[Timer]
OnBootSec=30s
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
```

Enable:

```
systemctl --user daemon-reload
systemctl --user enable --now solen-motd.timer

## Admin use (SSH/system‑wide)

### System-Wide SSH MOTD (for admins)

Opt‑in, modular, and easy to disable. Two primary options:

1) Debian/Ubuntu (update‑motd)

Create `/etc/update-motd.d/90-solen` and make it executable:

#!/bin/sh
[ -x /usr/local/bin/serverutils ] || exit 0
[ -t 1 ] || exit 0
serverutils run motd/solen-motd -- --plain

chmod +x /etc/update-motd.d/90-solen

Notes: pam_motd will call this at login. The `[ -t 1 ]` guard avoids output for non-interactive SSH commands (e.g., `ssh host 'uptime'`).

2) Red Hat/Fedora or systems without update‑motd

Create `/etc/profile.d/solen-motd.sh`:

[ "$PS1" ] && [ -x /usr/local/bin/serverutils ] && serverutils run motd/solen-motd -- --plain

This triggers only for interactive shells.

Disable by removing the file.

Performance: the MOTD is designed to run under ~200ms. Avoid heavy calls here; keep inventory/docker queries out of the login path unless you accept the latency. ASCII/banner remains optional; use `--plain` or future `--quiet` for minimal output.

## Troubleshooting

- No output at login
  - Ensure the snippet was added to the right file (`~/.bashrc`, `~/.zshrc`, or `~/.config/fish/config.fish`).
  - Reload your shell (`exec $SHELL`) or start a new terminal.
  - Confirm `serverutils` is in `PATH` (install runner with `./serverutils install-runner --user`).
- Output appears during scripts/CI
  - Use the interactive guards exactly as shown (`[[ $- == *i* ]]` for bash/zsh; `status is-interactive` for fish).
- SSH non‑interactive prints text
  - For Debian/Ubuntu update‑motd, include `[ -t 1 ] || exit 0` in `/etc/update-motd.d/90-solen`.
- Too verbose
  - Use `--plain` (recommended), and consider the future `--quiet` mode if added.
```

## Screenshot

> Placeholder – insert a screenshot showing the banner and box layout.
