#!/usr/bin/env bash

# SOLEN-META:
# name: network/network-info
# summary: Show IPs, listening ports, and a simple connectivity check
# requires: ip,ss,ping
# tags: network,inventory,check
# verbs: info,check
# since: 0.1.0
# breaking: false
# outputs: status, details.interfaces[], details.ports[], metrics.connectivity
# root: false

# Strict mode
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $0 [--dry-run] [--json]

Show network interfaces, listening ports, and a quick connectivity check. Read-only.
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

gateway=""
default_iface=""
if command -v ip > /dev/null 2>&1; then
  # Detect default route
  if ip route show default 2> /dev/null | grep -q '^default'; then
    gateway=$(ip route show default | awk '/^default/ {print $3; exit}')
    default_iface=$(ip route show default | awk '/^default/ {print $5; exit}')
  fi
else
  solen_err "ip tool not found (install iproute2)"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "ip not found" "" "\"code\":2"
  exit 2
fi

ifaces_tmp=$(mktemp)
ports_tmp=$(mktemp)
trap 'rm -f "$ifaces_tmp" "$ports_tmp"' EXIT

ip -brief address show > "$ifaces_tmp" 2> /dev/null || true

ports_available=0
if command -v ss > /dev/null 2>&1; then
  ss -tulnp 2> /dev/null > "$ports_tmp" && ports_available=1 || ports_available=0
fi

# Connectivity
gateway_ok="false"
rtt_ms=""
if [[ -n "$gateway" ]]; then
  if ping -c 1 -W 1 "$gateway" > /dev/null 2>&1; then
    gateway_ok="true"
    # Try to measure RTT quickly
    rtt_ms=$(ping -c 1 -W 1 "$gateway" 2> /dev/null | awk -F'/' '/^rtt/ {print $5; exit}')
  fi
fi

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  any_ok=0
  # Interfaces
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # format: IFACE STATE ADDRS...
    name=$(awk '{print $1}' <<< "$line")
    state=$(awk '{print $2}' <<< "$line")
    addrs=$(echo "$line" | cut -d' ' -f3-)
    # mac
    mac=$(ip link show dev "$name" 2> /dev/null | awk '/link\// {print $2; exit}')
    is_default="false"
    [[ "$name" == "$default_iface" ]] && is_default="true"
    summary="iface ${name} ${state}"
    details=$(cat <<D
"details":{"interface":{"name":"$(solen_json_escape "$name")","state":"$(solen_json_escape "$state")","mac":"$(solen_json_escape "${mac:-}")","addr":"$(solen_json_escape "$addrs")","default_route":$is_default}}
D
)
    solen_json_record_full ok "$summary" "$details"
    any_ok=$((any_ok+1))
  done < "$ifaces_tmp"

  # Ports (if available)
  ports_count=0
  if [[ $ports_available -eq 1 ]]; then
    # skip header lines, print protocol, local address:port, process (if present)
    awk 'NR>1 {print}' "$ports_tmp" | while IFS= read -r pline; do
      [[ -z "$pline" ]] && continue
      proto=$(awk '{print $1}' <<< "$pline")
      localaddr=$(awk '{print $5}' <<< "$pline")
      proc=$(awk -F 'users:\(\("' '{print $2}' <<< "$pline" | awk -F '"' '{print $1}' 2> /dev/null)
      ports_count=$((ports_count + 1))
      summary="port ${proto} ${localaddr}"
      details=$(cat <<D
"details":{"port":{"proto":"$proto","local":"$localaddr","process":"$(solen_json_escape "${proc:-}")"}}
D
)
      solen_json_record_full ok "$summary" "$details"
    done
  fi

  # Rollup
  up_count=$(awk '{print $2}' "$ifaces_tmp" | grep -c '^UP$' || true)
  total_count=$(wc -l < "$ifaces_tmp")
  rollup="interfaces: ${up_count} up / ${total_count} total; default route via ${gateway:-unknown}; listening ports: ${ports_count}; connectivity: gateway $([[ $gateway_ok == "true" ]] && echo OK || echo FAIL)"
  metrics_kv="\"if_up\":${up_count},\"if_total\":${total_count},\"listening\":${ports_count},\"gateway_ok\":$([[ $gateway_ok == "true" ]] && echo true || echo false)"
  if [[ -n "$rtt_ms" ]]; then metrics_kv+=" ,\"rtt_ms\":${rtt_ms}"; fi
  solen_json_record ok "$rollup" "" "$metrics_kv"
  if [[ $any_ok -gt 0 ]]; then
    exit 0
  else
    solen_json_record error "no interfaces enumerated" "" "\"code\":2"
    exit 2
  fi
else
  solen_head "IP Addresses"
  cat "$ifaces_tmp"
  solen_head "Listening Ports (TCP/UDP)"
  if [[ $ports_available -eq 1 ]]; then cat "$ports_tmp"; else solen_warn "ss not found"; fi
  solen_head "Connectivity"
  if [[ "$gateway_ok" == "true" ]]; then solen_ok "gateway reachable"; else solen_warn "gateway unreachable"; fi
  solen_ok "network information retrieval finished"
fi

exit 0
