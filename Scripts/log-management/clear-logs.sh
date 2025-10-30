#!/usr/bin/env bash

# SOLEN-META:
# name: log-management/clear-logs
# summary: Vacuum journald by size/time and optionally truncate configured logs
# requires: journalctl,sudo
# tags: logs,cleanup,maintenance
# verbs: fix
# since: 0.1.0
# breaking: false
# outputs: status, summary, actions[]
# root: true

# Strict mode
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $0 [--dry-run] [--json] [--yes]

Vacuum journald by size/time and optionally truncate configured log files.
Requires: journalctl (for vacuum), sudo/root for actual changes.
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
    solen_err "unknown option: $1"
    usage
    exit 1
    ;;
  *) break ;; esac
done

# --- Configuration ---
JOURNALD_VACUUM_SIZE="100M" # Keep logs up to this total size
JOURNALD_VACUUM_TIME="7d"   # Keep logs up to this age (e.g., 3d, 7d, 2weeks)

TRUNCATE_LOGS=( # List of log files to truncate (set size to 0)
  # "/var/log/syslog"      # Example: uncomment or add logs you want truncated
  # "/var/log/nginx/access.log"
  # "/var/log/nginx/error.log"
)

# --- Colors (Optional) ---
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'
COLOR_RED='\033[0;31m'

# --- Helper Functions ---
echoinfo() {
  echo -e "${COLOR_CYAN}ℹ️  $1${COLOR_RESET}"
}

echook() {
  echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"
}

echowarn() {
  echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"
}

echoerror() {
  echo -e "${COLOR_RED}❌ $1${COLOR_RESET}" >&2
}

# --- Sanity Checks ---
if [[ $EUID -ne 0 && $SOLEN_FLAG_DRYRUN -ne 1 ]]; then
  solen_warn "needs root (use sudo)"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "needs root" "" "\"code\":2"
  exit 2
fi

# --- Main Logic ---
solen_info "starting log cleanup"

# 1. Clean Journald Logs
changed_count=0
actions_list=""

if command -v journalctl > /dev/null 2>&1; then
  solen_info "vacuum journald (time ${JOURNALD_VACUUM_TIME}, size ${JOURNALD_VACUUM_SIZE})"
  actions_list+="journalctl --vacuum-size=${JOURNALD_VACUUM_SIZE} --vacuum-time=${JOURNALD_VACUUM_TIME}
"
  if [[ $SOLEN_FLAG_DRYRUN -ne 1 ]]; then
    journalctl --vacuum-size=${JOURNALD_VACUUM_SIZE} --vacuum-time=${JOURNALD_VACUUM_TIME}
    changed_count=$((changed_count + 1))
  fi
else
  solen_warn "journalctl not found, skipping vacuum"
fi

# 2. Truncate Specific Log Files
if [ ${#TRUNCATE_LOGS[@]} -gt 0 ]; then
  solen_info "truncate configured log files"
  for log_file in "${TRUNCATE_LOGS[@]}"; do
    if [ -f "$log_file" ]; then
      # Policy check per file
      if ! solen_policy_allows_prune_path "$log_file"; then
        if [[ ${SOLEN_FLAG_DRYRUN:-0} -eq 1 || ${SOLEN_FLAG_YES:-0} -eq 0 ]]; then
          solen_warn "policy would deny truncating (dry-run): $log_file"
          actions_list+="truncate -s 0 $log_file\n"
          continue
        else
          solen_warn "policy denies truncating: $log_file"
          [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "policy denies truncating $log_file" "truncate -s 0 $log_file" "\"code\":4"
          exit 4
        fi
      fi
      actions_list+="truncate -s 0 $log_file
"
      if [[ $SOLEN_FLAG_DRYRUN -ne 1 ]]; then
        : "${USE_SUDO:=}"
        [[ $EUID -ne 0 ]] && USE_SUDO="sudo" || USE_SUDO=""
        $USE_SUDO truncate -s 0 "$log_file"
        changed_count=$((changed_count + 1))
        solen_ok "truncated $log_file"
      else
        solen_info "would truncate $log_file"
      fi
    else
      solen_warn "log not found: ${log_file}"
    fi
  done
else
  solen_info "no specific logs configured for truncation"
fi

echo # Newline for spacing

if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
  echo "would change $changed_count items"
fi

solen_ok "log cleanup finished"
if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "log cleanup finished" "$actions_list" "\"changed\":$changed_count"
fi

exit 0
