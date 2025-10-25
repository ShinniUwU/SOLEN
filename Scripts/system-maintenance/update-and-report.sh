#!/usr/bin/env bash

# SOLEN-META:
# name: system-maintenance/update-and-report
# summary: Update apt indexes, fix broken deps, upgrade packages, and report recent upgrades
# requires: apt,sudo,grep,awk
# tags: apt,update
# verbs: update,upgrade
# since: 0.1.0
# breaking: false
# outputs: status, summary
# root: false (uses sudo when required)

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $0 [--dry-run] [--json] [--yes]

Refresh apt indexes, attempt fix-broken, upgrade packages, and report recently upgraded packages.
EOF
}

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then
    shift
    continue
  fi
  case "$1" in -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    break
    ;;
  -*)
    echo "unknown option: $1" >&2
    usage
    exit 1
    ;;
  *) break ;; esac
done

if ! command -v apt > /dev/null 2>&1; then
  solen_err "apt not found"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "apt not found" "" "\"code\":2"
  exit 2
fi

actions=$(
  cat << A
sudo apt update
sudo apt --fix-broken install -y
sudo apt upgrade -y
A
)

if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
  solen_info "dry-run: would execute"
  printf '%s\n' "$actions"
  echo "would change 3 items"
  if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
    solen_json_record ok "would update packages" "$actions" "\"would_change\":3"
  fi
  exit 0
fi

solen_info "updating package indexes"
set +e
sudo apt update
rc1=$?
set -e
if [[ $rc1 -ne 0 ]]; then
  solen_err "apt update failed"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "apt update failed" "$actions" "\"code\":10"
  exit 10
fi

solen_info "attempting fix-broken install"
set +e
sudo apt --fix-broken install -y
rc2=$?
set -e
if [[ $rc2 -ne 0 ]]; then
  solen_warn "fix-broken encountered issues"
fi

solen_info "upgrading packages"
set +e
sudo apt upgrade -y
rc3=$?
set -e
if [[ $rc3 -ne 0 ]]; then
  solen_err "apt upgrade failed"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "apt upgrade failed" "$actions" "\"code\":10"
  exit 10
fi

solen_ok "packages updated"

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "packages updated" "$actions" "\"changed\":1"
else
  if [[ ${SOLEN_FLAG_PLAIN:-0} -eq 1 ]]; then
    echo "Recently upgraded packages:"
  else
    echo -e "\n📦 Recently upgraded packages:\n"
  fi
  if [[ -f /var/log/dpkg.log ]]; then
    grep " upgrade " /var/log/dpkg.log | awk '{print $1, $2, $4}' | tail -n 20 || true
  fi
fi
exit 0
