# Installation Scripts

Cross-distro installer for SOLEN with optional shell enhancements.

---

## `install.sh`

Cross-distro installer with show-plan and optional MOTD/Zsh/Starship.

### Purpose

Installs SOLEN to either user scope (`~/.local/bin`) or system-wide (`/opt/solen`). Supports optional installation of shell polish (Zsh + Starship prompt) and MOTD integration.

### Usage

```bash
# Show what would be installed (dry-run is default)
./install.sh --show-plan

# Install to user home
./install.sh --user --yes

# Install system-wide with MOTD integration
sudo ./install.sh --global --with-motd --yes

# Full installation with shell polish
./install.sh --user --with-zsh --with-starship --with-motd --yes

# Uninstall
./install.sh --uninstall --yes
```

**Options**:
- `--user`: Install to `~/.local/bin` (default)
- `--global`: Install to `/opt/solen` (requires root)
- `--with-motd`: Enable MOTD integration via `/etc/update-motd.d/`
- `--with-zsh`: Install Zsh and set as default shell
- `--with-starship`: Install Starship prompt
- `--show-plan`: Show installation plan without executing
- `--uninstall`: Remove SOLEN installation
- `--dry-run`: Preview actions (default)
- `--yes`: Execute the installation

### What Gets Installed

| Scope | Location | Description |
|-------|----------|-------------|
| User | `~/.local/bin/serverutils` | Main CLI runner |
| User | `~/.local/share/solen/Scripts/` | Script library |
| Global | `/opt/solen/` | Complete installation |
| MOTD | `/etc/update-motd.d/90-solen` | MOTD hook |

### Shell Integration

The installer adds PATH configuration to shell rc files:

```bash
# --- SOLEN-BEGIN ---
export PATH="$HOME/.local/bin:$PATH"
# --- SOLEN-END ---
```

### Dependencies

* `bash`: Required
* `sudo`: For global install or MOTD setup
* Package manager: `apt-get`, `dnf`, `pacman`, or `zypper`

### Example

```bash
# Preview what will be installed
./install.sh --user --with-motd --show-plan

# Execute installation
./install.sh --user --with-motd --yes
```

---
