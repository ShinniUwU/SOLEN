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

installed_ver="$(./serverutils version 2>/dev/null || true)"
installed_ver="${installed_ver%% *}"
CACHEFILE="${XDG_STATE_HOME:-$HOME/.local/state}/solen/update-cache.json"
latest_ver=""; channel="stable"; checked_at=""
if [[ -f "$CACHEFILE" ]]; then
  latest_ver="$(jq -r '.version // ""' "$CACHEFILE" 2>/dev/null || true)"
  channel="$(jq -r '.channel // "stable"' "$CACHEFILE" 2>/dev/null || true)"
  checked_at="$(jq -r '.checked_at // ""' "$CACHEFILE" 2>/dev/null || true)"
fi

cmp_semver() { # echo -1,0,1
  awk -v A="$1" -v B="$2" 'BEGIN{n=split(A,a,".");m=split(B,b,"."); for(i=1;i<= (n>m?n:m); i++){aa=(i<=n?a[i]:0);bb=(i<=m?b[i]:0); if(aa+0<bb+0){print -1; exit} if(aa+0>bb+0){print 1; exit}} print 0}'
}

update_available=0
if [[ -n "$latest_ver" && -n "$installed_ver" ]]; then
  if [[ "$(cmp_semver "$installed_ver" "$latest_ver")" -lt 0 ]]; then update_available=1; fi
fi

if [[ $JSON -eq 1 ]]; then
  jq -n --arg inst "$installed_ver" --arg latest "$latest_ver" --arg ch "$channel" --arg ts "$checked_at" --argjson upd $update_available \
    '{installed:$inst, latest:$latest, channel:$ch, checked_at:$ts, update_available:$upd}'
else
  if [[ $update_available -eq 1 ]]; then
    echo "· solen: update available — ${installed_ver:-unknown} → ${latest_ver} (run: serverutils update --apply)"
  else
    echo "solen up-to-date (${installed_ver:-unknown})"
  fi
fi
exit 0

