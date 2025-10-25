#!/usr/bin/env bash

# SOLEN-META:
# name: install/install
# summary: Cross-distro installer with show-plan and optional MOTD/Zsh/Starship
# requires: bash,sudo
# tags: install,bootstrap,packages
# verbs: install,uninstall
# since: 0.2.0
# breaking: false
# outputs: status, summary, actions
# root: false (uses sudo when required)

set -Eeuo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
. "${THIS_DIR}/../lib/pm.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $(basename "$0") [--show-plan] [--yes] [--uninstall] [--with-motd] [--with-zsh] [--with-starship] [--copy-shell-assets] [--units user|system] [--user|--global]

Guiding principles:
  - stay local & auditable, always dry-run unless --yes
  - cross-distro (apt/dnf/pacman/zypper) with a visible plan

Installs:
  - SOLEN runner (user or global)
  - Optional: MOTD snippet, Zsh, Starship (if packages available)
  - Optional: systemd units for backups/health (use serverutils install-units)

Uninstall:
  - Removes runner symlink(s) and leaves config files untouched
EOF
}

with_motd=0
with_zsh=0
with_starship=0
scope="user"
do_uninstall=0
show_plan=0
copy_shell_assets=0
units_scope=""

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --with-motd) with_motd=1; shift ;;
    --with-zsh) with_zsh=1; shift ;;
    --with-starship) with_starship=1; shift ;;
    --copy-shell-assets) copy_shell_assets=1; shift ;;
    --units)
      units_scope="${2:-}"
      case "$units_scope" in user|system) ;; *) solen_err "--units requires 'user' or 'system'"; exit 1 ;; esac
      shift 2 ;;
    --user) scope="user"; shift ;;
    --global) scope="global"; shift ;;
    --uninstall) do_uninstall=1; shift ;;
    --show-plan) show_plan=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) solen_err "unknown option: $1"; usage; exit 1 ;;
    *) break ;;
  esac
done

pm_detect || true
pm="$(pm_name)"

plan_lines=()
add() { plan_lines+=("$1"); }

if [[ $do_uninstall -eq 1 ]]; then
  add "Uninstall runner ($scope)"
  if [[ $scope == "global" ]]; then
    add "sudo rm -f /usr/local/bin/serverutils /usr/local/bin/solen"
  else
    add "rm -f \"$HOME/.local/bin/serverutils\" \"$HOME/.local/bin/solen\""
  fi
  # No package removal to avoid collateral damage
else
  # Install path
  add "Install runner ($scope)"
  if [[ $scope == "global" ]]; then
    add "sudo ./serverutils install-runner --global"
  else
    add "./serverutils install-runner --user"
  fi

  # Packages
  pkgs=(curl jq)
  [[ $with_zsh -eq 1 ]] && pkgs+=(zsh)
  [[ $with_starship -eq 1 ]] && pkgs+=(starship)
  if [[ "$pm" != "unknown" && ${#pkgs[@]} -gt 0 ]]; then
    add "$(pm_update_plan)"
    add "$(pm_install_plan "${pkgs[@]}")"
  fi

  # MOTD – suggest snippet only (no forced edits)
  if [[ $with_motd -eq 1 ]]; then
    add "# To enable MOTD for current user: append to ~/.bashrc or ~/.zshrc:"
    add "#   [[ \$- == *i* ]] && serverutils run motd/solen-motd -- --plain"
  fi

  # Copy shell assets
  if [[ $copy_shell_assets -eq 1 ]]; then
    if [[ "$scope" == "global" ]]; then
      add "sudo mkdir -p /etc/solen"
      add "sudo install -m 0644 asset/shell/* /etc/solen/"
    else
      add "mkdir -p \"$HOME/.config/solen\""
      add "install -m 0644 asset/shell/* \"$HOME/.config/solen/\""
    fi
  fi

  # Units installation/enabling
  if [[ -n "$units_scope" ]]; then
    if [[ "$units_scope" == "user" ]]; then
      add "./serverutils install-units --user"
      add "systemctl --user daemon-reload"
      add "systemctl --user enable --now solen-kopia-maintenance.timer"
      add "# Per-profile backups timer: systemctl --user enable --now solen-backups@etc.timer"
    else
      add "sudo ./serverutils install-units --global"
      add "sudo systemctl daemon-reload"
      add "sudo systemctl enable --now solen-kopia-maintenance-system.timer"
      add "# Per-profile backups timer: sudo systemctl enable --now solen-backups-system@etc.timer"
    fi
  fi
fi

summary="installer plan (${pm:-unknown}): ${#plan_lines[@]} step(s)"

if [[ $SOLEN_FLAG_DRYRUN -eq 1 || $SOLEN_FLAG_YES -eq 0 || $show_plan -eq 1 ]]; then
  actions=$(printf "%s\n" "${plan_lines[@]}")
  if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
    solen_json_record ok "dry-run: $summary" "$actions" "\"would_change\":${#plan_lines[@]}"
  else
    solen_info "dry-run enforced (use --yes to apply)"
    printf '%s\n' "$actions"
  fi
  exit 0
fi

changed=0
for cmd in "${plan_lines[@]}"; do
  [[ "$cmd" == \#* ]] && continue
  solen_info "$cmd"
  set +e
  bash -lc "$cmd"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then changed=$((changed+1)); else solen_warn "step failed rc=$rc: $cmd"; fi
done

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "installer applied ($scope)" "$(printf '%s\n' "${plan_lines[@]}")" "\"changed\":${changed}"
else
  solen_ok "installer applied ($scope) changed=${changed}"
fi
exit 0
