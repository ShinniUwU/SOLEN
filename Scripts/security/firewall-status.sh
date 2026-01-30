#!/usr/bin/env bash

# SOLEN-META:
# name: security/firewall-status
# summary: Show firewall status across ufw/nftables/iptables (read-only)
# requires: ufw,nft,iptables (any)
# tags: security,firewall,info
# verbs: info,check
# since: 0.1.0
# breaking: false
# outputs: status, summary, details
# root: false

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  echo "Usage: $(basename "$0") [--json]"
}

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in -h|--help) usage; exit 0 ;; --) shift; break ;; -*) solen_err "unknown: $1"; usage; exit 1 ;; *) break ;; esac
done

kind="none"; enabled=false; details=""
if command -v ufw >/dev/null 2>&1; then
  kind="ufw"
  out=$(ufw status verbose 2>/dev/null || true)
  grep -qi '^status: active' <<< "$out" && enabled=true || enabled=false
  details="$out"
elif command -v nft >/dev/null 2>&1; then
  kind="nftables"
  out=$(nft list ruleset 2>/dev/null || true)
  grep -q 'table' <<< "$out" && enabled=true || enabled=false
  details="$out"
elif command -v iptables >/dev/null 2>&1; then
  kind="iptables"
  out=$(iptables -S 2>/dev/null || true)
  grep -q '^-P' <<< "$out" && enabled=true || enabled=false
  details="$out"
fi

summary="${kind} $( $enabled && echo enabled || echo disabled)"
if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  details_json=$(printf '%s' "$details" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | sed '$ s/\\n$//')
  printf '{"status":"ok","summary":"%s","ts":"%s","host":"%s","details":{"kind":"%s","enabled":%s,"raw":"%s"}}\n' \
    "$summary" "$(solen_ts)" "$(solen_host)" "$kind" "$enabled" "$details_json"
else
  if $enabled; then solen_ok "$summary"; else solen_warn "$summary"; fi
fi
exit 0

