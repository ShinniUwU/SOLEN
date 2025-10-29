# **SOLEN (ServerUtils) 🛠️**

<p align="center">
  <img src="./solen_logo.png" alt="SOLEN Logo" width="420" />
</p>

SOLEN is a modular sysadmin toolkit — a curated collection of shell utilities designed to automate and standardize maintenance across **Debian-based systems** (Proxmox LXCs, VPSs, or bare metal).
Every script follows a common format for safe dry-runs, JSON output, and unified logging — all orchestrated through the **`serverutils`** runner.

> ⚙️ **Note:** The project is transitioning from “ServerUtils” to **SOLEN**.
> The runner binary remains `serverutils` until v1.0 (with a `solen` alias coming soon).

---

## 🚀 **Quick Start**

Install via one command (per‑user, with MOTD, safe by default):

```bash
bash <(curl -sL https://solen.shinni.dev/run.sh) --user --with-motd --yes
```

What this does
- Downloads a verified release, installs a persistent copy under `~/.local/share/solen/latest`, and puts `serverutils` on your PATH (`~/.local/bin`).
- Adds a guarded MOTD snippet for your shell (bash/zsh/fish). You’ll see a colored system summary on new shells.
- Launches a TUI once (skip with `--no-tui`).

System‑wide install (admins):

```bash
bash <(curl -sL https://solen.shinni.dev/run.sh) --global --with-motd --yes
```

This also installs an `/etc/update-motd.d/90-solen` hook on Debian/Ubuntu/Proxmox so SSH logins show the full MOTD.

Open the runner any time:

```bash
serverutils           # TUI
serverutils list      # scripts with summaries
```

Developers — clone instead of curl:

```bash
git clone https://github.com/ShinniUwU/SOLEN.git
cd SOLEN
./serverutils list
```

---

## 🧠 **About the Runner**

The `serverutils` CLI discovers and executes any SOLEN script in the `Scripts/` tree.

| Example                                             | Description                   |
| :-------------------------------------------------- | :---------------------------- |
| `serverutils list`                                  | Lists all registered scripts  |
| `serverutils run <name>`                            | Runs a script (fuzzy-matched) |
| `serverutils run security/baseline-check -- --json` | Passes flags to scripts       |
| `serverutils search health`                         | Searches scripts by keyword   |

**Audit logs** are written to `~/.serverutils/audit.log`.
Override with `SOLEN_AUDIT_LOG` or `SOLEN_AUDIT_DIR`.

### Updates you can trust (quiet, atomic, rollback)

- Check quietly (reads channel manifest; caches result under `~/.local/state/solen`):

```bash
serverutils update             # same as: update check
serverutils status             # one‑liner update status
```

- Apply an update (verifies checksum and optional signature, swaps atomically, keeps rollback):

```bash
serverutils update apply --yes
serverutils update --rollback   # instant rollback to previous
```

- Channels: `stable` (default), `rc`, `nightly` — set via `SOLEN_CHANNEL`.

- Background weekly check (user):

```bash
serverutils install-units --user
systemctl --user daemon-reload
systemctl --user enable --now solen-update-check.timer
```

Security:
- Manifests include sha256 and can be signed in CI. To enforce verification, set `SOLEN_SIGN_PUBKEY_PEM` (PEM public key)
  and optional `SOLEN_REQUIRE_SIGNATURE=1` on hosts.
- Updates stage to a temp dir, copy into `~/.local/share/solen/latest`, and keep `latest-prev` for rollback.

---

## 📐 **SOLEN Standards (v0.1)**

Each script implements consistent arguments, exit codes, and JSON output.

**Flags & Environment**

```
--dry-run, --json, --yes
SOLEN_NOOP=1, SOLEN_JSON=1, SOLEN_ASSUME_YES=1
```

**Exit Codes**

```
0 = ok
1 = usage error
2 = missing dependency or environment
3 = partial success
4 = refused (policy)
>=10 = script-specific
```

**JSON Contract**
Every output line follows this schema:

```json
{
  "status": "ok|warn|error",
  "summary": "short text",
  "host": "hostname",
  "ts": "timestamp",
  "details": {},
  "metrics": {},
  "op": "category" // optional
}
```

Multi-record outputs use **NDJSON**.
Schema reference: [`docs/json-schema/solen.script.schema.json`](./docs/json-schema/solen.script.schema.json)

---

## 🔒 **Privilege Model**

* Scripts declare if they need root (`root: true` in metadata).
* Most only request elevation for specific actions (e.g., apt, systemctl).
* Designed around **least privilege**: everything runs safely as non-root unless required.
* For minimal terminals, set `SOLEN_PLAIN=1` to disable emojis and colors.

---

## 🧩 **Categories**

Scripts live in [`Scripts/`](./Scripts/), organized by domain:

| Category                                               | Description                      |
| :----------------------------------------------------- | :------------------------------- |
| [`docker/`](./Scripts/docker/)                         | Manage containers & images 🐳    |
| [`log-management/`](./Scripts/log-management/)         | Clean and rotate logs 🪵         |
| [`network/`](./Scripts/network/)                       | Show IPs, ports, connectivity 🌐 |
| [`inventory/`](./Scripts/inventory/)                   | Read-only host snapshot 📋       |
| [`security/`](./Scripts/security/)                     | Baseline & firewall checks 🔐    |
| [`system-maintenance/`](./Scripts/system-maintenance/) | Updates, cleanup, apt tasks 🔧   |

List everything:

```bash
serverutils list
```

---

## 🧾 **Capabilities Overview**

| Key                                  | Verbs  | Root | Tags               | Outputs                    | Since | `--json` | `--dry-run` |
| :----------------------------------- | :----- | :--- | :----------------- | :------------------------- | :---- | :------- | :---------- |
| docker/list-docker-info              | info   | no   | docker, inventory  | details.containers, images | 0.1.0 | ✅        | ✅           |
| docker/update-docker-compose-app     | ensure | no*  | docker, deploy     | summary, actions           | 0.1.0 | ✅        | ✅           |
| network/network-info                 | info   | no   | network, inventory | interfaces, ports          | 0.1.0 | ✅        | ✅           |
| health/check                         | check  | no   | health, monitoring | metrics.rollup             | 0.1.0 | ✅        | ✅           |
| backups/run                          | backup | no   | backup, retention  | metrics.rollup             | 0.1.0 | ✅        | ✅           |
| inventory/host-info                  | info   | no   | inventory          | details                    | 0.1.0 | ✅        | —           |
| security/baseline-check              | check  | no   | security           | details, metrics.issues    | 0.1.0 | ✅        | —           |
| security/firewall-status             | check  | no   | security, firewall | details.kind, enabled      | 0.1.0 | ✅        | —           |
| log-management/clear-logs            | fix    | yes  | logs, cleanup      | summary                    | 0.1.0 | ✅        | ✅           |
| system-maintenance/update-and-report | update | no*  | apt, update        | summary                    | 0.1.0 | ✅        | ✅           |

---

## 🪄 **Show MOTD on Login (Optional)**

The installer writes guarded blocks to bash/zsh/fish rc files so new shells show a colored system summary.
System‑wide installs also add `/etc/update-motd.d/90-solen` for SSH logins.

**Bash / Zsh**

```bash
[[ $- == *i* ]] && serverutils run motd/solen-motd -- --full
```

**Fish**

```fish
if status is-interactive
    serverutils run motd/solen-motd -- --full
end
```

Or let the runner print a tailored snippet:

```bash
serverutils setup-motd
```

Tips
- Hooks run the runner with `SOLEN_RUN_QUIET=1` to hide extra chatter.
- Prefer monochrome? replace `--full` with `--plain`.
- See [`docs/MOTD.md`](./docs/MOTD.md) for details and system-wide setup.

---

## 📚 **Docs**

| File                                                                                       | Purpose                           |
| :----------------------------------------------------------------------------------------- | :-------------------------------- |
| [`docs/FIRST5.md`](./docs/FIRST5.md)                                                       | First 5 minutes demo flow         |
| [`docs/LOGGING.md`](./docs/LOGGING.md)                                                     | Log paths and rotation            |
| [`docs/PLAYBOOKS.md`](./docs/PLAYBOOKS.md)                                                 | Security posture & automation     |
| [`docs/MOTD.md`](./docs/MOTD.md)                                                           | Auto-MOTD setup & SSH integration |
| [`docs/json-schema/solen.script.schema.json`](./docs/json-schema/solen.script.schema.json) | JSON contract                     |

---

## 💡 **Tips**

* `SOLEN_JSON=1` forces JSON mode (useful for CI).
* `SOLEN_NOOP=1` forces dry-run behavior globally.
* `SOLEN_LOG_DIR=/path` overrides the default log base (`/var/log/solen` or `~/.local/share/solen`).
* `SOLEN_ASSUME_YES=1` bypasses confirmation prompts.

---

## 🤝 **Contributing**

Found a bug or want to extend the toolkit?

* 🧠 Ideas & Bugs → [Open an Issue](https://github.com/ShinniUwU/SOLEN/issues)
* 💻 Code → see [CONTRIBUTING.md](./CONTRIBUTING.md)
* 🌈 Conduct → follow [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)

---

> **SOLEN 0.1.0 — “Aegir”**
> Built for admins who want speed, structure, and safety.
