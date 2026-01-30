#!/usr/bin/env bash
# SOLEN-META:
# name: services/ensure
# summary: Ensure systemd services (status/ensure-enabled/ensure-running/restart-if-failed)
# requires: systemctl
# tags: services,systemd
# verbs: status,ensure-enabled,ensure-running,restart-if-failed
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
Usage: $(basename "$0") {status|ensure-enabled|ensure-running|restart-if-failed} --unit <name> [--dry-run] [--json] [--yes]

Commands:
  status             Show unit active/enabled state
  ensure-enabled     Enable unit if not already enabled
  ensure-running     Enable and start unit if not running
  restart-if-failed  Restart unit only if in failed state

Options:
  --unit <name>  Systemd unit name (required)
  --dry-run      Preview actions without executing
  --json         Output JSON format
  --yes          Execute changes (default is dry-run)
EOF
}

UNIT=""
CMD="${1:-status}"
shift || true

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --unit) UNIT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) solen_err "unknown option: $1"; usage; exit 1 ;;
    *) shift ;;
  esac
done

if ! command -v systemctl > /dev/null 2>&1; then
  msg="non-systemd host (degraded)"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record warn "$msg" "" "" || solen_warn "$msg"
  exit 3
fi

[[ -n "$UNIT" ]] || {
  usage
  exit 1
}

# Validate unit name (alphanumeric, dash, underscore, dot, @ only)
if ! [[ "$UNIT" =~ ^[a-zA-Z0-9_@.-]+$ ]]; then
  msg="Invalid unit name. Only alphanumeric, dash, underscore, dot, and @ allowed."
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "$msg" "" "\"code\":1" || solen_err "$msg"
  exit 1
fi

is_active() { systemctl is-active --quiet "$UNIT"; }
is_enabled() { systemctl is-enabled --quiet "$UNIT"; }

case "$CMD" in
  status)
    act="inactive"; is_active && act="active"
    ena="disabled"; is_enabled && ena="enabled"
    summary="$UNIT $act,$ena"
    [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "" "\"metrics\":{\"active\":$([[ $act == active ]] && echo true || echo false),\"enabled\":$([[ $ena == enabled ]] && echo true || echo false)}" || solen_ok "$summary"
    ;;
  ensure-enabled)
    if is_enabled; then
      summary="$UNIT already enabled"
      [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "" "" || solen_ok "$summary"
    else
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        summary="would enable $UNIT"
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "sudo systemctl enable $UNIT" "\"would_change\":1" || solen_info "[dry-run] $summary"
      else
        sudo systemctl enable "$UNIT"
        summary="enabled $UNIT"
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "sudo systemctl enable $UNIT" "\"changed\":1" || solen_ok "$summary"
      fi
    fi
    ;;
  ensure-running)
    actions=""
    if ! is_enabled; then
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        actions+="sudo systemctl enable $UNIT"$'\n'
      else
        sudo systemctl enable "$UNIT" > /dev/null
        actions+="sudo systemctl enable $UNIT"$'\n'
      fi
    fi
    if is_active; then
      summary="$UNIT already running"
      [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "$actions" "" || solen_ok "$summary"
    else
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        actions+="sudo systemctl start $UNIT"
        summary="would start $UNIT"
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "$actions" "\"would_change\":1" || solen_info "[dry-run] $summary"
      else
        sudo systemctl start "$UNIT"
        actions+="sudo systemctl start $UNIT"
        summary="started $UNIT"
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "$actions" "\"changed\":1" || solen_ok "$summary"
      fi
    fi
    ;;
  restart-if-failed)
    if systemctl --quiet is-failed "$UNIT"; then
      if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
        summary="would restart $UNIT (failed)"
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "sudo systemctl restart $UNIT" "\"would_change\":1" || solen_info "[dry-run] $summary"
      else
        sudo systemctl restart "$UNIT"
        summary="restarted $UNIT (was failed)"
        [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "sudo systemctl restart $UNIT" "\"changed\":1" || solen_ok "$summary"
      fi
    else
      summary="$UNIT not failed"
      [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record ok "$summary" "" "" || solen_ok "$summary"
    fi
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
