#!/usr/bin/env bash

# SOLEN-META:
# name: backups/maintenance
# summary: Run Kopia repository maintenance (quick by default) for the configured repo
# requires: kopia,sudo
# tags: backup,kopia,maintenance
# verbs: prune,maintain
# since: 0.2.0
# breaking: false
# outputs: status, summary, actions
# root: false (uses sudo when repo under /var)

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $(basename "$0") [--dest <root>] [--quick|--full] [--dry-run] [--json] [--yes]

Determines the Kopia repo from dest (default: /var/backups/solen/kopia-repo filesystem repo),
or uses S3 configuration via environment variables like in backups/run.

Environment (S3 optional):
  SOLEN_KOPIA_S3_BUCKET, SOLEN_KOPIA_S3_REGION, [SOLEN_KOPIA_S3_PREFIX], [SOLEN_KOPIA_S3_ENDPOINT]
  KOPIA_PASSWORD or KOPIA_PASSWORD_FILE
EOF
}

dest_root="/var/backups/solen"
mode="quick"

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --dest) dest_root="${2:-/var/backups/solen}"; shift 2 ;;
    --quick) mode="quick"; shift ;;
    --full) mode="full"; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) solen_err "unknown option: $1"; usage; exit 1 ;;
    *) break ;;
  esac
done

if [[ $SOLEN_FLAG_DRYRUN -eq 0 || $SOLEN_FLAG_YES -eq 1 ]]; then
  if ! command -v kopia >/dev/null 2>&1; then
    solen_err "kopia not installed"
    [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "kopia not installed" "" "\"code\":2"
    exit 2
  fi
fi

repo_kind=filesystem
repo_path="${dest_root%/}/kopia-repo"
if [[ -n "${SOLEN_KOPIA_S3_BUCKET:-}" ]]; then repo_kind=s3; fi

KOPIA_PASSWORD_FILE_DEFAULT="${HOME}/.serverutils/kopia-password"
if [[ -z "${KOPIA_PASSWORD:-}" && -z "${KOPIA_PASSWORD_FILE:-}" ]]; then
  export KOPIA_PASSWORD_FILE="$KOPIA_PASSWORD_FILE_DEFAULT"
fi

actions=""
SUDO=""; [[ "$repo_kind" == filesystem && "$repo_path" == /var/* ]] && SUDO="sudo -E"
if [[ "$repo_kind" == filesystem ]]; then
  actions+=$"$SUDO kopia repository connect filesystem --path \"$repo_path\" 2>/dev/null || $SUDO kopia repository create filesystem --path \"$repo_path\"\n"
else
  region="${SOLEN_KOPIA_S3_REGION:-${AWS_REGION:-}}"; endpoint_opt=""; [[ -n "${SOLEN_KOPIA_S3_ENDPOINT:-}" ]] && endpoint_opt=" --endpoint=${SOLEN_KOPIA_S3_ENDPOINT}"
  actions+=$"kopia repository connect s3 --bucket \"${SOLEN_KOPIA_S3_BUCKET}\" --prefix \"${SOLEN_KOPIA_S3_PREFIX:-solen}\" --region \"${region}\"${endpoint_opt} 2>/dev/null || \\\n+kopia repository create s3 --bucket \"${SOLEN_KOPIA_S3_BUCKET}\" --prefix \"${SOLEN_KOPIA_S3_PREFIX:-solen}\" --region \"${region}\"${endpoint_opt}\n"
fi
if [[ "$mode" == "quick" ]]; then
  actions+=$"$SUDO kopia maintenance run --quick\n"
else
  actions+=$"$SUDO kopia maintenance run --full\n"
fi

summary="kopia maintenance (${mode}) on ${repo_kind} repo"

if [[ $SOLEN_FLAG_DRYRUN -eq 1 || $SOLEN_FLAG_YES -eq 0 ]]; then
  if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
    solen_json_record ok "dry-run: $summary" "$actions" "\"would_change\":1"
  else
    solen_info "dry-run enforced (use --yes to apply)"
    printf '%s' "$actions"
  fi
  exit 0
fi

changed=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ "$line" == \#* ]]; then continue; fi
  solen_info "$line"
  set +e
  bash -c "$line"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then changed=$((changed+1)); else solen_warn "step failed (rc=$rc): $line"; fi
done <<< "$actions"

maint_info=""
packs="" contents="" errors=0 compaction_mentions=0
set +e
maint_info=$($SUDO env KOPIA_PASSWORD_FILE="${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}" kopia maintenance info 2>/dev/null)
rc_info=$?
stats_json=$($SUDO env KOPIA_PASSWORD_FILE="${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}" kopia content stats --json 2>/dev/null)
rc_stats=$?
set -e
if [[ $rc_info -eq 0 && -n "$maint_info" ]]; then
  errors=$(printf '%s\n' "$maint_info" | grep -i 'error' | wc -l | tr -d ' ')
  compaction_mentions=$(printf '%s\n' "$maint_info" | grep -i 'compact' | wc -l | tr -d ' ')
fi
if [[ $rc_stats -eq 0 && -n "$stats_json" ]]; then
  packs=$(printf '%s' "$stats_json" | sed -n 's/.*"packCount"\s*:\s*\([0-9]\+\).*/\1/p' | head -n1)
  contents=$(printf '%s' "$stats_json" | sed -n 's/.*"contentCount"\s*:\s*\([0-9]\+\).*/\1/p' | head -n1)
fi

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  metrics="\"changed\":${changed},\"mode\":\"${mode}\",\"repo_kind\":\"${repo_kind}\""
  [[ -n "$packs" ]] && metrics="$metrics,\"packCount\":${packs}"
  [[ -n "$contents" ]] && metrics="$metrics,\"contentCount\":${contents}"
  metrics="$metrics,\"compaction_mentions\":${compaction_mentions},\"errors\":${errors}"
  solen_json_record ok "$summary" "$actions" "${metrics}"
else
  extra=""
  [[ -n "$packs" ]] && extra="$extra packs=$packs"
  [[ -n "$contents" ]] && extra="$extra contents=$contents"
  [[ "$compaction_mentions" != "0" ]] && extra="$extra compaction_mentions=$compaction_mentions"
  [[ "$errors" != "0" ]] && extra="$extra errors=$errors"
  solen_ok "$summary (changed=${changed}${extra})"
fi
exit 0
