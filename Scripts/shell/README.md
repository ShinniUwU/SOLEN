# Shell Setup Scripts

Optional shell polish and configuration.

---

## `setup.sh`

Optional shell polish (zsh + starship) with guarded stubs (dry-run by default).

### Purpose

Installs and configures Zsh with Starship prompt for an enhanced shell experience. Uses guarded marker blocks in rc files that can be cleanly removed.

### Usage

```bash
../../serverutils run shell/setup -- [options]
```

**Options**:
- `--install`: Install Zsh and Starship
- `--uninstall`: Remove shell customizations
- `--dry-run`: Preview actions (default)
- `--json`: Output JSON format
- `--yes`: Execute changes

### What Gets Installed

| Component | Description |
|-----------|-------------|
| Zsh | Z Shell with enhanced features |
| Starship | Cross-shell prompt with Git integration |
| Configuration | Guarded blocks in ~/.zshrc |

### Installation Steps

1. Installs Zsh via system package manager
2. Downloads and installs Starship prompt
3. Configures ~/.zshrc with:
   - Starship initialization
   - PATH additions
   - Common aliases
4. Optionally sets Zsh as default shell

### Examples

```bash
# Preview what would be installed
serverutils run shell/setup -- --install --dry-run

# Install shell polish
serverutils run shell/setup -- --install --yes

# Remove shell customizations
serverutils run shell/setup -- --uninstall --yes
```

### Dependencies

* `bash`: Required
* `sudo`: For package installation
* `curl`: For Starship download
* Package manager: apt, dnf, pacman, or zypper

### Configuration Blocks

The script manages configuration using marker blocks:

```bash
# --- SOLEN-SHELL-BEGIN ---
eval "$(starship init zsh)"
export PATH="$HOME/.local/bin:$PATH"
# --- SOLEN-SHELL-END ---
```

These blocks can be cleanly removed with `--uninstall`.

### Uninstallation

The uninstall process:
1. Removes marker blocks from rc files
2. Does NOT uninstall Zsh or Starship packages
3. Does NOT change default shell

To fully remove:
```bash
# Remove configuration
serverutils run shell/setup -- --uninstall --yes

# Manually uninstall packages if desired
sudo apt remove zsh starship  # Debian/Ubuntu
```

---
