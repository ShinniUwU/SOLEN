# SOLEN Installer (Local & Auditable)

Guiding principles
- No curl | bash at runtime. The installer prints a plan and only applies with --yes.
- Cross‑distro: supports apt, dnf, pacman, zypper with consistent UX.
- Always dry‑run by default; emits NDJSON via the runner’s audit log.

Usage
- Show plan (dry‑run):
  - `serverutils install --show-plan [--with-motd] [--with-zsh] [--with-starship] [--user|--global]`
- Apply:
  - `serverutils install --with-motd --with-zsh --with-starship --user --yes`
- Uninstall runner symlinks:
  - `serverutils install --uninstall --user --yes`

Examples
- Copy shell assets and install user units (plan only):
  - `serverutils install --show-plan --with-motd --with-zsh --with-starship --copy-shell-assets --units user --user`
- Install globally and register system units:
  - `serverutils install --with-motd --units system --global --yes`

What it does
- Installs the SOLEN runner (user or global).
- Optionally installs zsh and starship via your package manager.
- Suggests a small, reversible MOTD snippet (no files auto‑edited).
- Leaves configs and system files untouched unless explicitly requested.

Rollback
- Installer changes are limited to package installation and runner symlinks.
- Remove runner symlinks with `serverutils install --uninstall`.
- Systemd units can be removed with `serverutils install-units --user|--global`.

Notes
- The installer is implemented as a SOLEN script at `Scripts/install/install.sh` and uses `Scripts/lib/pm.sh` for cross‑distro helpers.
