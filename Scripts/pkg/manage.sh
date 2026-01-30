#!/usr/bin/env bash
# SOLEN-META:
# name: pkg/manage
# summary: Unified package management (apt+dnf): check/update/upgrade/autoremove
# requires: apt-get,dnf (any)
# tags: packages,apt,dnf,updates
# verbs: check,update,upgrade,autoremove
# outputs: status,summary,metrics
# root: false
# since: 0.1.0
# breaking: false

set -Eeuo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $(basename "$0") {check|update|upgrade|autoremove} [--dry-run] [--json] [--yes] [--manager apt|dnf]

Commands:
  check       Check for available updates
  update      Update package lists (apt update / dnf makecache)
  upgrade     Install available upgrades
  autoremove  Remove unused dependencies

Options:
  --dry-run        Preview actions without executing
  --json           Output JSON format
  --yes            Execute changes (default is dry-run)
  --manager <mgr>  Force package manager (apt or dnf), default auto-detect
EOF
}

MANAGER="auto"
CMD="${1:-}"
shift || true

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --manager) MANAGER="${2:-auto}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) solen_err "unknown option: $1"; usage; exit 1 ;;
    *) shift ;;
  esac
done

detect() {
  [[ "$MANAGER" != "auto" ]] && echo "$MANAGER" && return
  if command -v apt-get > /dev/null 2>&1; then
    echo apt
    return
  fi
  if command -v dnf > /dev/null 2>&1; then
    echo dnf
    return
  fi
  echo none
}

pkg_check_apt() {
  local out cnt sz reboot
  if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
    sudo -n true > /dev/null 2>&1 || true
    out=$(apt-get -s upgrade 2> /dev/null || true)
  else
    sudo apt-get update > /dev/null 2>&1 || true
    out=$(apt-get -s upgrade 2> /dev/null || true)
  fi
  cnt=$(printf "%s\n" "$out" | awk '/^Inst /{c++} END{print c+0}')
  sz=$(printf "%s\n" "$out" | awk -F'[() ]+' '/^Inst /{for(i=1;i<=NF;i++) if($i=="size") s=$(i+1)} END{printf "%.0f", s+0}')
  reboot=0
  [[ -f /var/run/reboot-required ]] && reboot=1
  solen_json_record ok "updates available: ${cnt}" "" "\"metrics\":{\"packages\":$cnt,\"size_kb\":$sz,\"reboot\":$([[ $reboot -eq 1 ]] && echo true || echo false)}"
}

pkg_check_dnf() {
  local out cnt reboot
  if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
    out=$(dnf -q check-update || true)
  else
    dnf -q makecache > /dev/null 2>&1 || true
    out=$(dnf -q check-update || true)
  fi
  cnt=$(printf "%s\n" "$out" | awk '/^\S+\.\S+\s+\S+\s+\S+$/ {c++} END{print c+0}')
  reboot=0
  if command -v needs-restarting > /dev/null 2>&1; then
    needs-restarting -r > /dev/null 2>&1 || reboot=$?
    [[ "$reboot" -ne 0 ]] && reboot=1
  fi
  solen_json_record ok "updates available: ${cnt}" "" "\"metrics\":{\"packages\":$cnt,\"reboot\":$([[ $reboot -eq 1 ]] && echo true || echo false)}"
}

pkg_run_apt() {
  local verb="$1"
  case "$verb" in
    update)
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "would run: apt-get update" "apt-get update" "\"would_change\":1" || solen_info "[dry-run] would run: apt-get update"
      else
        sudo apt-get update
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "apt-get update complete" "apt-get update" "\"changed\":1" || solen_ok "apt-get update complete"
      fi
      ;;
    upgrade)
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "would run: apt-get -y upgrade" "apt-get -y upgrade" "\"would_change\":1" || solen_info "[dry-run] would run: apt-get -y upgrade"
      else
        sudo apt-get -y upgrade
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "apt-get upgrade complete" "apt-get -y upgrade" "\"changed\":1" || solen_ok "apt-get upgrade complete"
      fi
      ;;
    autoremove)
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "would run: apt-get -y autoremove" "apt-get -y autoremove" "\"would_change\":1" || solen_info "[dry-run] would run: apt-get -y autoremove"
      else
        sudo apt-get -y autoremove
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "apt-get autoremove complete" "apt-get -y autoremove" "\"changed\":1" || solen_ok "apt-get autoremove complete"
      fi
      ;;
  esac
}

pkg_run_dnf() {
  local verb="$1"
  case "$verb" in
    update)
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "would run: dnf makecache" "dnf makecache" "\"would_change\":1" || solen_info "[dry-run] would run: dnf makecache"
      else
        sudo dnf -y makecache
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "dnf makecache complete" "dnf makecache" "\"changed\":1" || solen_ok "dnf makecache complete"
      fi
      ;;
    upgrade)
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "would run: dnf -y upgrade" "dnf -y upgrade" "\"would_change\":1" || solen_info "[dry-run] would run: dnf -y upgrade"
      else
        sudo dnf -y upgrade
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "dnf upgrade complete" "dnf -y upgrade" "\"changed\":1" || solen_ok "dnf upgrade complete"
      fi
      ;;
    autoremove)
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "would run: dnf -y autoremove" "dnf -y autoremove" "\"would_change\":1" || solen_info "[dry-run] would run: dnf -y autoremove"
      else
        sudo dnf -y autoremove
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "dnf autoremove complete" "dnf -y autoremove" "\"changed\":1" || solen_ok "dnf autoremove complete"
      fi
      ;;
  esac
}

mgr=$(detect)
if [[ "$mgr" == "none" ]]; then
  msg="no package manager (apt/dnf) found"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "$msg" "" "\"code\":2" || solen_err "$msg"
  exit 2
fi

case "$CMD" in
  check)
    [[ "$mgr" == "apt" ]] && pkg_check_apt || pkg_check_dnf
    ;;
  update|upgrade|autoremove)
    [[ "$mgr" == "apt" ]] && pkg_run_apt "$CMD" || pkg_run_dnf "$CMD"
    ;;
  "")
    usage
    exit 1
    ;;
  *)
    solen_err "unknown command: $CMD"
    usage >&2
    exit 1
    ;;
esac
