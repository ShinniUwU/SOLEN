#!/usr/bin/env bash

# SOLEN-META:
# name: shell/setup
# summary: Optional shell polish (zsh + starship) with guarded stubs (dry-run by default)
# requires: bash,sudo
# tags: shell,zsh,starship
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
Usage: $(basename "$0") [--install|--uninstall] [--yes] [--json]

Installs zsh/starship (if available) and prints guarded stub lines to add to ~/.zshrc or ~/.bashrc.
Uninstall removes guarded stubs only; packages are not erased.
EOF
}

do_install=1
if [[ "${1:-}" == "--uninstall" ]]; then do_install=0; shift; fi
while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in -h|--help) usage; exit 0 ;; --) shift; break ;; -*) solen_err "unknown: $1"; usage; exit 1 ;; *) break;; esac
done

pm_detect || true
pm="$(pm_name)"

actions=()
add() { actions+=("$1"); }

if [[ $do_install -eq 1 ]]; then
  # Plan pkgs
  pkgs=(zsh starship)
  if [[ "$pm" != "unknown" ]]; then
    add "$(pm_update_plan)"
    add "$(pm_install_plan "${pkgs[@]}")"
  fi
  # Plan stubs
  add "# Append to ~/.zshrc (guarded):"
  add "#   # SOLEN: begin"
  add "#   export STARSHIP_CONFIG=\"$HOME/.config/solen/starship.toml\""
  add "#   command -v starship >/dev/null 2>&1 && eval \"\$(starship init zsh)\""
  add "#   # SOLEN: end"
  add "# Append to ~/.bashrc (guarded): same pattern using bash"
else
  # Uninstall — remove guarded stubs
  add "sed -i '/^# SOLEN: begin/,/^# SOLEN: end/d' \"$HOME/.zshrc\" 2>/dev/null || true"
  add "sed -i '/^# SOLEN: begin/,/^# SOLEN: end/d' \"$HOME/.bashrc\" 2>/dev/null || true"
fi

summary="$([[ $do_install -eq 1 ]] && echo setup || echo cleanup) shell (pm=${pm})"

if [[ $SOLEN_FLAG_DRYRUN -eq 1 || $SOLEN_FLAG_YES -eq 0 ]]; then
  if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
    solen_json_record ok "dry-run: $summary" "$(printf '%s\n' "${actions[@]}")" "\"would_change\":${#actions[@]}"
  else
    solen_info "dry-run enforced (use --yes to apply)"
    printf '%s\n' "${actions[@]}"
  fi
  exit 0
fi

changed=0
for line in "${actions[@]}"; do
  [[ "$line" == \#* ]] && continue
  solen_info "$line"
  set +e
  bash -lc "$line"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then changed=$((changed+1)); else solen_warn "step failed rc=$rc: $line"; fi
done

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "$summary" "$(printf '%s\n' "${actions[@]}")" "\"changed\":${changed}"
else
  solen_ok "$summary (changed=${changed})"
fi
exit 0

