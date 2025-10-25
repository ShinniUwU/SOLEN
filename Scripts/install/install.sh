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
. "${THIS_DIR}/../lib/edit.sh"
. "${THIS_DIR}/../lib/pm.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $(basename "$0") [--show-plan] [--yes] [--uninstall] [--uninstall-everything] [--with-motd] [--with-zsh] [--with-starship] [--copy-shell-assets] [--units user|system] [--user|--global]

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
scope_set=0
do_uninstall=0
do_uninstall_all=0
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
    --user) scope="user"; scope_set=1; shift ;;
    --global) scope="global"; scope_set=1; shift ;;
    --uninstall) do_uninstall=1; shift ;;
    --uninstall-everything) do_uninstall_all=1; shift ;;
    --show-plan) show_plan=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) solen_err "unknown option: $1"; usage; exit 1 ;;
    *) break ;;
  esac
done

pm_detect || true
pm="$(pm_name)"

interactive_select_scope_if_missing() {
  if [[ $scope_set -eq 0 && -t 0 && -t 1 ]]; then
    echo "Select install scope:"
    echo "  [1] Per-user (no root)"
    echo "  [2] System-wide (root)"
    read -rp "Choice [1/2]: " ch || true
    if [[ "$ch" == "2" ]]; then scope="global"; else scope="user"; fi
  fi
}

plan_lines=()
add() { plan_lines+=("$1"); }

link_runner_user() {
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(cd "${THIS_DIR}/../.." && pwd)/serverutils" "$HOME/.local/bin/serverutils"
  ln -sf "$HOME/.local/bin/serverutils" "$HOME/.local/bin/solen"
}
link_runner_global() {
  sudo ln -sf "$(cd "${THIS_DIR}/../.." && pwd)/serverutils" /usr/local/bin/serverutils
  sudo ln -sf /usr/local/bin/serverutils /usr/local/bin/solen
}

path_check_msg() {
  if command -v serverutils >/dev/null 2>&1; then
    solen_ok "serverutils on PATH"
  else
    solen_warn "serverutils not on PATH in current shell; open a new shell or source your rc file"
  fi
}

install_motd_hooks_user() {
  local shshell
  shshell="${SHELL##*/}"
  case "$shshell" in
    bash)
      solen_insert_marker_block "$HOME/.bashrc" "# >>> SOLEN MOTD_BASH (do not edit) >>>" "# <<< SOLEN MOTD_BASH (managed) <<<" "$(cat "${THIS_DIR}/../../asset/shell/hooks/motd_bash.sh")"
      if [[ -f "$HOME/.bash_profile" ]] && ! grep -Fq ">>> SOLEN BASH_PROFILE_INCLUDE" "$HOME/.bash_profile"; then
        solen_insert_marker_block "$HOME/.bash_profile" "# >>> SOLEN BASH_PROFILE_INCLUDE (do not edit) >>>" "# <<< SOLEN BASH_PROFILE_INCLUDE (managed) <<<" "$(cat "${THIS_DIR}/../../asset/shell/hooks/bash_profile_include.sh")"
      fi
      ;;
    zsh)
      solen_insert_marker_block "$HOME/.zshrc" "# >>> SOLEN MOTD_ZSH (do not edit) >>>" "# <<< SOLEN MOTD_ZSH (managed) <<<" "$(cat "${THIS_DIR}/../../asset/shell/hooks/motd_zsh.sh")"
      ;;
    fish)
      mkdir -p "$HOME/.config/fish"
      solen_insert_marker_block "$HOME/.config/fish/config.fish" "# >>> SOLEN MOTD_FISH (do not edit) >>>" "# <<< SOLEN MOTD_FISH (managed) <<<" "$(cat "${THIS_DIR}/../../asset/shell/hooks/motd_fish.fish")"
      ;;
    *)
      solen_insert_marker_block "$HOME/.bashrc" "# >>> SOLEN MOTD_BASH (do not edit) >>>" "# <<< SOLEN MOTD_BASH (managed) <<<" "$(cat "${THIS_DIR}/../../asset/shell/hooks/motd_bash.sh")"
      ;;
  esac
}

install_motd_hooks_global() {
  echo "$(cat "${THIS_DIR}/../../asset/shell/hooks/profile.d_solen.sh")" | sudo tee /etc/profile.d/solen.sh >/dev/null
  if command -v fish >/dev/null 2>&1; then
    echo "$(cat "${THIS_DIR}/../../asset/shell/hooks/conf.d_solen.fish")" | sudo tee /etc/fish/conf.d/solen.fish >/dev/null
  fi
}

uninstall_user_markers() {
  for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish" "$HOME/.bash_profile"; do
    [[ -f "$f" ]] || continue
    solen_remove_marker_block "$f" "# >>> SOLEN MOTD_BASH (do not edit) >>>" "# <<< SOLEN MOTD_BASH (managed) <<<" || true
    solen_remove_marker_block "$f" "# >>> SOLEN MOTD_ZSH (do not edit) >>>" "# <<< SOLEN MOTD_ZSH (managed) <<<" || true
    solen_remove_marker_block "$f" "# >>> SOLEN MOTD_FISH (do not edit) >>>" "# <<< SOLEN MOTD_FISH (managed) <<<" || true
    solen_remove_marker_block "$f" "# >>> SOLEN BASH_PROFILE_INCLUDE (do not edit) >>>" "# <<< SOLEN BASH_PROFILE_INCLUDE (managed) <<<" || true
  done
}

interactive_select_scope_if_missing

if [[ $do_uninstall -eq 1 || $do_uninstall_all -eq 1 ]]; then
  add "Uninstall runner ($scope)"
  if [[ $scope == "global" ]]; then
    add "sudo rm -f /usr/local/bin/serverutils /usr/local/bin/solen"
  else
    add "rm -f \"$HOME/.local/bin/serverutils\" \"$HOME/.local/bin/solen\""
  fi
  if [[ $do_uninstall_all -eq 1 ]]; then
    # Units and assets removal plan
    if [[ "$scope" == "global" ]]; then
      add "sudo systemctl disable --now solen-kopia-maintenance-system.timer || true"
      add "sudo systemctl disable --now solen-backups-system@etc.timer || true # adjust profile names"
      add "sudo rm -f /etc/systemd/system/solen-*.service /etc/systemd/system/solen-*.timer || true"
      add "sudo systemctl daemon-reload || true"
      add "sudo rm -rf /etc/solen || true"
    else
      add "systemctl --user disable --now solen-kopia-maintenance.timer || true"
      add "systemctl --user disable --now solen-backups@etc.timer || true # adjust profile names"
      add "rm -rf \"$HOME/.config/systemd/user/solen-*\" || true"
      add "systemctl --user daemon-reload || true"
      add "rm -rf \"$HOME/.config/solen\" || true"
    fi
  fi
else
  # Install path
  add "Install runner ($scope)"
  if [[ $scope == "global" ]]; then
    add "link /usr/local/bin/serverutils -> repo/serverutils"
    add "link /usr/local/bin/solen -> /usr/local/bin/serverutils"
  else
    add "mkdir -p \"$HOME/.local/bin\""
    add "link \"$HOME/.local/bin/serverutils\" -> repo/serverutils"
    add "link \"$HOME/.local/bin/solen\" -> \"$HOME/.local/bin/serverutils\""
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
    if [[ "$scope" == "global" ]]; then
      add "write /etc/profile.d/solen.sh (interactive guard)"
      add "write /etc/fish/conf.d/solen.fish (if fish exists)"
    else
      add "edit ~/.rc to add SOLEN MOTD markers (per shell) with backup"
      add "edit ~/.bash_profile to include .bashrc once (if needed)"
    fi
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
  case "$cmd" in
    link\ *)
      if [[ "$scope" == "global" ]]; then link_runner_global; else link_runner_user; fi
      changed=$((changed+1))
      ;;
    mkdir\ -p\ *)
      eval "$cmd" && changed=$((changed+1)) || true
      ;;
    write\ /etc/profile.d/*)
      install_motd_hooks_global; changed=$((changed+1)) ;;
    edit\ ~/.rc*)
      install_motd_hooks_user; changed=$((changed+1)); ;;
    edit\ ~/.bash_profile*)
      install_motd_hooks_user; ;;
    sudo*|./serverutils*|systemctl*|rm*|\#*)
      set +e; bash -lc "$cmd"; rc=$?; set -e; [[ $rc -eq 0 ]] && changed=$((changed+1)) || true ;;
    *)
      : ;;
  esac
done

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "installer applied ($scope)" "$(printf '%s\n' "${plan_lines[@]}")" "\"changed\":${changed}"
else
  solen_ok "installer applied ($scope) changed=${changed}"
  path_check_msg
fi
exit 0
