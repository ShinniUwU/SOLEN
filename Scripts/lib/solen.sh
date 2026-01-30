#!/usr/bin/env bash
# Minimal SOLEN shared helpers for scripts

# Do NOT set -e/-u here; these files are sourced by scripts that manage shell opts

solen_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
solen_host() { hostname 2>/dev/null || uname -n; }

# Flags: default to verify-by-default, dry-run unless --yes is given
solen_init_flags() {
  : "${SOLEN_FLAG_YES:=0}"
  : "${SOLEN_FLAG_JSON:=${SOLEN_JSON:-0}}"
  : "${SOLEN_FLAG_DRYRUN:=1}"
  if [ "${SOLEN_FLAG_YES}" = "1" ]; then SOLEN_FLAG_DRYRUN=0; fi
}

# Parse a common flag; echo nothing, return 0 if handled
solen_parse_common_flag() {
  case "$1" in
    --yes|-y) SOLEN_FLAG_YES=1; SOLEN_FLAG_DRYRUN=0; return 0 ;;
    --dry-run) SOLEN_FLAG_DRYRUN=1; return 0 ;;
    --json) SOLEN_FLAG_JSON=1; return 0 ;;
  esac
  return 1
}

# Styled messages
solen_info() { echo -e "\033[0;36mℹ️  $*\033[0m"; }
solen_ok()   { echo -e "\033[0;32m✅ $*\033[0m"; }
solen_warn() { echo -e "\033[0;33m⚠️  $*\033[0m"; }
solen_err()  { echo -e "\033[0;31m❌ $*\033[0m" 1>&2; }

# Section header for human-readable output
solen_head() { echo -e "\033[0;34m--- $* ---\033[0m"; }

# Minimal JSON string escaper
solen_json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# Emit a single JSON record with optional extra fields
# Usage: solen_json_record <status> <summary> <actions_text> <extra_json_fields>
solen_json_record() {
  local status="$1" summary="$2" actions_text="${3:-}" extra="${4:-}"
  # Escape JSON
  _esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
  local host; host="$(solen_host)"
  # Convert actions_text (newline-separated) to JSON array
  local actions_json="[]"
  if [ -n "$actions_text" ]; then
    actions_json="["
    local first=1
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local e; e="$(_esc "$line")"
      if [ $first -eq 0 ]; then actions_json+=" ,"; else first=0; fi
      actions_json+="\"$e\""
    done <<EOF
${actions_text}
EOF
    actions_json+="]"
  fi
  printf '{"status":"%s","summary":"%s","ts":"%s","host":"%s","actions":%s%s}\n' \
    "$(_esc "$status")" "$(_esc "$summary")" "$(solen_ts)" "$(_esc "$host")" "$actions_json" \
    "${extra:+,${extra}}"
}

# Convenience: emit a JSON record with a ready-made details fragment
# Usage: solen_json_record_full <status> <summary> <details_json_fragment>
solen_json_record_full() {
  local status="$1" summary="$2" details_fragment="$3"
  solen_json_record "$status" "$summary" "" "$details_fragment"
}

# Try to source policy helpers if available; otherwise permissive fallbacks
__SOLEN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${__SOLEN_LIB_DIR}/policy.sh" ]; then
  . "${__SOLEN_LIB_DIR}/policy.sh"
else
  solen_policy_allows_token() { return 0; }
  solen_policy_allows_service_restart() { return 0; }
  solen_policy_allows_prune_path() { return 0; }
fi
