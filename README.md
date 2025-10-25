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

### 1. Clone and enter the repo

```bash
git clone https://github.com/ShinniUwU/SOLEN.git
cd SOLEN
```

### 2. Make the runner executable

```bash
chmod +x serverutils
```

### 3. Run it locally (no install needed)

```bash
./serverutils list
./serverutils run motd/solen-motd -- --plain
./serverutils run health/check
```

### 4. (Optional) Install globally or per-user

```bash
# User install (recommended)
./serverutils install-runner --user
export PATH="$HOME/.local/bin:$PATH"

# Or system-wide (requires sudo)
sudo ./serverutils install-runner --global
```

Now you can invoke it from anywhere:

```bash
serverutils list
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

To display the SOLEN system summary when opening a terminal:

**Bash / Zsh**

```bash
[[ $- == *i* ]] && serverutils run motd/solen-motd -- --plain
```

**Fish**

```fish
if status is-interactive
    serverutils run motd/solen-motd -- --plain
end
```

Or run:

```bash
serverutils setup-motd
```

It prints the snippet for your shell — no files modified automatically.
See [`docs/MOTD.md`](./docs/MOTD.md) for system-wide SSH setup.

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
