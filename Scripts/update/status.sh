#!/usr/bin/env bash

# SOLEN-META:
# name: update/status
# summary: Show installed version and cached latest (soft reminder)
# requires: bash,jq
# tags: update,info
# verbs: info
# since: 0.3.0
# breaking: false

set -Eeuo pipefail

JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in --json) JSON=1; shift ;; -h|--help) echo "Usage: $(basename "$0") [--json]"; exit 0 ;; *) shift;; esac
done

installed_ver=""
if command -v serverutils >/dev/null 2>&1; then
  installed_ver="$(serverutils version 2>/dev/null || true)"
fi
if [[ -z "$installed_ver" ]]; then
  THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd "${THIS_DIR}/../.." && pwd)"
  if [[ -x "${ROOT_DIR}/serverutils" ]]; then
    installed_ver="$("${ROOT_DIR}/serverutils" version 2>/dev/null || true)"
  fi
fi
# Keep full version string (no truncation of +buildmetadata)
installed_ver="${installed_ver%% *}"
CACHEFILE="${XDG_STATE_HOME:-$HOME/.local/state}/solen/update-cache.json"
latest_ver=""; channel="stable"; checked_at=""; breaking=false
if [[ -f "$CACHEFILE" ]]; then
  latest_ver="$(jq -r '.latest_version // .version // ""' "$CACHEFILE" 2>/dev/null || true)"
  channel="$(jq -r '.channel // "stable"' "$CACHEFILE" 2>/dev/null || true)"
  checked_at="$(jq -r '.ts // .checked_at // ""' "$CACHEFILE" 2>/dev/null || true)"
  breaking="$(jq -r '.breaking // false' "$CACHEFILE" 2>/dev/null || echo false)"
fi

update_available=0
if [[ -n "$latest_ver" && -n "$installed_ver" ]]; then
  if [[ "$installed_ver" != "$latest_ver" ]]; then update_available=1; fi
fi

host="$(hostname 2>/dev/null || uname -n)"
if [[ $JSON -eq 1 ]]; then
  status="ok"; summary="solen up-to-date"
  if [[ $update_available -eq 1 ]]; then summary="update available — ${installed_ver:-unknown} → ${latest_ver}"; fi
  jq -n --arg inst "$installed_ver" --arg latest "$latest_ver" --arg ch "$channel" --arg ts "$checked_at" --arg host "$host" --arg sum "$summary" --argjson brk ${breaking:-false} \
    --argjson upd $update_available '{installed_version:$inst, latest_version:$latest, channel:$ch, breaking:$brk, ts:$ts, host:$host, status:"ok", summary:$sum, update_available:$upd}'
else
  if [[ $update_available -eq 1 ]]; then
    echo "· solen: update available — ${installed_ver:-unknown} → ${latest_ver} (run: serverutils update --apply)"
  else
    echo "solen up-to-date (${installed_ver:-unknown})"
  fi
fi
exit 0
