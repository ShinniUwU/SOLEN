#!/usr/bin/env bash

# SOLEN-META:
# name: backups/run
# summary: Run or prune backups by profile (scaffold)
# requires: rsync
# tags: backup,retention
# verbs: backup
# since: 0.1.0
# breaking: false
# outputs: status, summary, metrics, actions
# root: false

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage:
  $(basename "$0") run --profile <name> [--dest <path>] [--retention-days N] [--dry-run] [--json]
  $(basename "$0") prune --profile <name> [--dest <path>] [--retention-days N] [--dry-run] [--json]

Environment:
  SOLEN_BACKUPS_CONFIG   Path to profiles YAML (default: config/solen-backups.yaml)
  SOLEN_BACKUPS_DEST     Override destination root
  SOLEN_BACKUPS_RETENTION_DAYS  Override retention days

Safety:
  - Dry-run is enforced by default; use --yes or SOLEN_ASSUME_YES=1 to apply changes.
  - Policy gates: requires allow tokens backup-profile:<name> and backup-path:<dest>.

Note: This is a scaffold. No copy or prune is performed yet.
EOF
}

cmd="${1:-}"
shift || true

profile=""
dest_override="${SOLEN_BACKUPS_DEST:-}"
ret_days="${SOLEN_BACKUPS_RETENTION_DAYS:-}"
while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then
    shift
    continue
  fi
  case "$1" in
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --dest)
      dest_override="${2:-}"
      shift 2
      ;;
    --retention-days)
      ret_days="${2:-}"
      shift 2
      ;;
    -h | --help)
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
    *) break ;;
  esac
done

[[ -n "$cmd" ]] || {
  solen_err "missing subcommand (run|prune)"
  usage
  exit 1
}
[[ -n "$profile" ]] || {
  solen_err "missing --profile"
  usage
  exit 1
}

# Resolve config and dest (scaffold defaults)
ROOT_DIR="$(cd "${THIS_DIR}/../.." && pwd)"
cfg_path="${SOLEN_BACKUPS_CONFIG:-${ROOT_DIR}/config/solen-backups.yaml}"
dest="${dest_override:-/var/backups/solen}"
ret_days="${ret_days:-7}"

# Policy tokens (scaffold): backup-profile:<name>, backup-path:<dest>
if ! solen_policy_allows_token "backup-profile:${profile}"; then
  msg="policy refused: backup-profile:${profile}"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "$msg" "" "\"code\":4" || solen_err "$msg"
  exit 4
fi
if ! solen_policy_allows_token "backup-path:${dest}"; then
  msg="policy refused: backup-path:${dest}"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "$msg" "" "\"code\":4" || solen_err "$msg"
  exit 4
fi

# Enforce dry-run by default (safety); require --yes for real changes
if [[ "$cmd" =~ ^(run|prune)$ ]]; then
  if [[ ${SOLEN_FLAG_DRYRUN:-0} -eq 0 && ${SOLEN_FLAG_YES:-0} -eq 0 ]]; then
    SOLEN_FLAG_DRYRUN=1
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record warn "dry-run enforced (use --yes to apply changes)"
    else
      solen_warn "dry-run enforced (use --yes to apply changes)"
    fi
  fi
fi

# Begin line
begin_msg="begin: backup ${profile} at ${dest}"
if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "$begin_msg"
else
  solen_info "$begin_msg"
fi

# Scaffold plan (dummy numbers and actions)
sources_count=3
bytes_planned=123456789
files_planned=4200
prune_planned=1
actions_list=$(
  cat << A
mkdir -p "${dest}/${profile}-YYYYMMDD-HHMMSS"
rsync -aAXH --delete <sources...> "${dest}/${profile}-.../"
ln -sfn "${dest}/${profile}-..." "${dest}/${profile}-latest"
find "${dest}" -maxdepth 1 -name "${profile}-*" -mtime +${ret_days} -type d -print -delete
A
)

if [[ "$cmd" == "run" ]]; then
  if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
    rollup="would back up ${sources_count} sources (≈${bytes_planned} planned), would prune ${prune_planned}"
    echo "would change $((sources_count + prune_planned + 1)) items"
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record ok "$rollup" "$actions_list" "\"metrics\":{\"files_planned\":${files_planned},\"bytes_planned\":${bytes_planned},\"prune_planned\":${prune_planned}}"
    else
      solen_ok "$rollup"
    fi
    exit 0
  else
    # Real run is not implemented in scaffold
    summary="backup complete (scaffold; no changes performed)"
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record ok "$summary" "$actions_list" "\"metrics\":{\"files_copied\":0,\"bytes_copied\":0,\"pruned\":0}"
    else
      solen_ok "$summary"
    fi
    exit 0
  fi
elif [[ "$cmd" == "prune" ]]; then
  if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
    rollup="would prune ${prune_planned} old sets"
    echo "would change ${prune_planned} items"
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record ok "$rollup" "$actions_list" "\"metrics\":{\"prune_planned\":${prune_planned}}"
    else
      solen_ok "$rollup"
    fi
    exit 0
  else
    summary="prune complete (scaffold; no changes performed)"
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record ok "$summary" "$actions_list" "\"metrics\":{\"pruned\":0}"
    else
      solen_ok "$summary"
    fi
    exit 0
  fi
else
  solen_err "unknown subcommand: $cmd"
  usage
  exit 1
fi
