# SOLEN (ServerUtils) 🛠️

<p align="center">
  <img src="./solen_logo.png" alt="SOLEN Logo" width="420" />
</p>

Welcome to SOLEN (ServerUtils). This is a growing collection of handy shell scripts designed to simplify common tasks on self-hosted servers, especially **Debian-based systems** (like those in Proxmox LXCs).

Think of these as simple tools to automate repetitive jobs and keep things running smoothly.

> Deprecation notice: The suite is being rebranded from “ServerUtils” to “SOLEN”.
> The runner remains `serverutils` for now; a `solen` alias will be introduced later.
> We will keep the `serverutils` name available until 1.0 for compatibility.

## New: Central Runner CLI

Use the `serverutils` runner to list, search, and run any script in this repo. You can also install it (and optional per‑script shortcuts) for permanent access.

Quick start (temporary use):

```
./serverutils list
./serverutils run docker/list-docker-info
./serverutils run network-info   # fuzzy match will prompt if ambiguous
```

Install the runner permanently:

```
# User install (recommended)
./serverutils install-runner --user
# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Or install globally (needs sudo)
./serverutils install-runner --global
```

Optional: install per‑script shortcuts (symlinks) like `su-docker-list-docker-info` into your bin directory:

```
./serverutils install-scripts --user --prefix su-
# then you can call, for example:
su-docker-list-docker-info
```

The runner maintains a minimal audit log in `.serverutils/audit.log` of executed commands.
You can override the log path with `SOLEN_AUDIT_LOG` or `SOLEN_AUDIT_DIR`.

---

## SOLEN Standards (v0.1)

We’re standardizing flags, output, and safety across scripts. See `docs/SOLEN_SPEC.md` for full details.

- Unified flags & env: `--dry-run`, `--json`, `--yes` and env mirrors `SOLEN_NOOP=1`, `SOLEN_JSON=1`, `SOLEN_ASSUME_YES=1`.
- Exit codes: `0=ok`, `1=user error`, `2=env/deps`, `3=partial`, `4=refused (policy)`, `>=10=script-specific`.
- JSON contract: consistent fields (`status`, `summary`, `details`, `metrics`, `actions`, `logs`, `ts`, `host`). NDJSON for multi-record output. Schema: `docs/json-schema/solen.script.schema.json`.
- Dry-run protocol: print exact commands/targets; end with `would change N items`.
- Policy & audit: sample policy at `config/solen-policy.example.yaml`; audit lines go to `.serverutils/audit.log`.
  Override path with `SOLEN_AUDIT_LOG` or `SOLEN_AUDIT_DIR`. For production, configure log rotation.

We’re branding the toolkit as “SOLEN”, versioning as `SOLEN x.y.z` with a codename.

Banner: `asciiart.ascii` (single-line). Version: `SOLEN 0.1.0 — Aegir`.

### Privilege model

- Scripts marked `root: true` require root, typically via `sudo`. Others may still run privileged steps (e.g., apt) with `sudo` when needed.
- The suite favors least privilege and will request elevation only for specific operations.
- For terminals without Unicode/ANSI, set `SOLEN_PLAIN=1` to suppress emojis and styling.

## What's Inside? 📂

All the scripts live inside the [`Scripts/`](./Scripts/) directory, organized into categories. Each category folder contains:

1.  The script(s).
2.  A `README.md` explaining **exactly how to use each script** in that category (including usage, examples, and dependencies).

**Available Categories:**

| Category                                           | Description                                                  |
| :------------------------------------------------- | :----------------------------------------------------------- |
| [`docker/`](./Scripts/docker/)                     | Utilities for managing Docker containers and images. 🐳      |
| [`log-management/`](./Scripts/log-management/)     | Scripts for cleaning and managing system logs. 🪵            |
| [`network/`](./Scripts/network/)                   | Tools for checking network status and information. 🌐        |
| [`inventory/`](./Scripts/inventory/)               | Fast read-only host inventory. 📋                           |
| [`security/`](./Scripts/security/)                 | Baseline security checks and firewall status. 🔐             |
| [`system-maintenance/`](./Scripts/system-maintenance/) | Scripts for general system updates and upkeep. 🔧            |

You can list all scripts and their categories at any time with:

```
./serverutils list
```

---

## Capabilities Table

| Key | Verbs | Needs root | Tags | Outputs | Since | --json | --dry-run |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `docker/list-docker-info` | info | no | docker, inventory | details.containers, details.images, summary | 0.1.0 | yes | yes |
| `docker/update-docker-compose-app` | ensure, fix | no (needs docker perms) | docker, update, deploy | summary, actions | 0.1.0 | yes | yes |
| `log-management/clear-logs` | fix | yes | logs, cleanup, maintenance | summary | 0.1.0 | yes | yes |
| `network/network-info` | info, check | no | network, inventory | details.interfaces, details.ports, metrics.connectivity | 0.1.0 | yes | yes |
| `system-maintenance/cleanup-system` | fix | yes | apt, cleanup, maintenance | summary | 0.1.0 | planned | planned |
| `system-maintenance/update-and-report` | update, upgrade | no (uses sudo) | apt, update | summary | 0.1.0 | yes | yes |
| `backups/run` | backup | no | backup, retention | metrics.rollup | 0.1.0 | yes | yes |
| `health/check` | check | no | health, monitoring | metrics.rollup | 0.1.0 | yes | yes |
| `inventory/host-info` | info | no | inventory | metrics, details | 0.1.0 | yes | n/a |
| `security/baseline-check` | check,info | no | security, baseline | details, metrics.issues | 0.1.0 | yes | n/a |
| `security/firewall-status` | info,check | no | security, firewall | details.kind, details.enabled | 0.1.0 | yes | n/a |

Docs:
- Backups scaffold: `docs/BACKUPS.md`
- Playbooks: `docs/PLAYBOOKS.md`

Notes:
- Root requirement “no” assumes the user has the necessary privileges (e.g., in the `docker` group) when applicable.
- As we standardize, scripts will adopt `--dry-run`, `--json`, and the exit code framework.

## Getting Started

1.  Browse the [`Scripts/`](./Scripts/) directory and find a category/script that looks interesting.
2.  Read the `README.md` *inside that category's folder* for detailed usage instructions.
3.  Run the scripts! (Use with caution, especially if your environment differs significantly from Debian on Proxmox LXC).

### Optional: Show SOLEN MOTD at login

Add a one‑liner to your shell config (bash/zsh/fish) to display the SOLEN summary when opening a terminal. See docs/MOTD.md for copy‑paste snippets and guidance (interactive only; safe for scripts/CI).
You can also run `serverutils setup-motd` to print the snippet for your shell.

## Want to Contribute? ✨

Found a bug? Have an idea for a new script? Contributions are welcome!

* **Ideas & Bugs:** Please open an [Issue](https://github.com/ShinniUwU/ServerUtils/issues).
* **Code Contributions:** Check out our simple **[Contributing Guide](CONTRIBUTING.md)** to see how you can add your own scripts or improvements using our GitHub Flow process.
* **Be Nice:** Please follow our [Code of Conduct](CODE_OF_CONDUCT.md).

Let's build a useful toolkit together!
