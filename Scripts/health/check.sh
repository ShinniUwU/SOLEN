#!/usr/bin/env bash

# SOLEN-META:
# name: health/check
# summary: Fast health checks with thresholds and rollup (root,disk,load,mem,services,docker)
# requires: df,awk,systemctl (optional),docker (optional)
# tags: health,monitoring
# verbs: check
# since: 0.1.0
# breaking: false
# outputs: status, summary, metrics
# root: false

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $(basename "$0") [--dry-run] [--json]

Perform fast health checks using simple system probes and configurable thresholds (config/solen-health.yaml).
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

# --- thresholds and helpers ---
ROOT_DIR="$(cd "${THIS_DIR}/../.." && pwd)"
HEALTH_CFG="${ROOT_DIR}/config/solen-health.yaml"

num() { awk '{printf (NF? $1: 0)}' 2>/dev/null; }
thres_or() {
  # $1 key path (e.g., thresholds.disk_root_pct.warn) $2 default
  local key="$1" def="$2"
  [[ -r "$HEALTH_CFG" ]] || { printf '%s' "$def"; return; }
  if command -v yq >/dev/null 2>&1; then
    # translate dots to YAML path and try to read
    local val
    val=$(yq -r ".. | select(has(\"thresholds\")) | .thresholds | .${key#thresholds.} // empty" "$HEALTH_CFG" 2>/dev/null | head -n1)
    if [[ -n "${val:-}" && "${val}" != "null" ]]; then printf '%s' "$val"; return; fi
  fi
  awk -v key="$key" -v def="$def" '
    function trim(s){ gsub(/^\s+|\s+$/, "", s); return s }
    BEGIN{FS=":"}
    { line=$0 }
    /thresholds:/ {t=1}
    t && /disk_root_pct:/ {scope="disk_root_pct"}
    t && /load15_per_core:/ {scope="load15_per_core"}
    t && /mem_pressure_pct:/ {scope="mem_pressure_pct"}
    t && scope && /warn:/ { w=trim($2) }
    t && scope && /error:/ { e=trim($2) }
    END {
      split(key, parts, ".");
      if(parts[2]=="disk_root_pct"){ if(parts[3]=="warn") print (w?w:def); else if(parts[3]=="error") print (e?e:def); else print def }
      else if(parts[2]=="load15_per_core"){ if(parts[3]=="warn") print (w?w:def); else if(parts[3]=="error") print (e?e:def); else print def }
      else if(parts[2]=="mem_pressure_pct"){ if(parts[3]=="warn") print (w?w:def); else if(parts[3]=="error") print (e?e:def); else print def }
    }
  ' "$HEALTH_CFG"
}

load1=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)
load5=$(awk '{print $2}' /proc/loadavg 2>/dev/null || echo 0)
load15=$(awk '{print $3}' /proc/loadavg 2>/dev/null || echo 0)
cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1)
if ! [[ "$cores" =~ ^[0-9]+$ ]]; then cores=1; fi
load15_per_core=$(awk -v l="$load15" -v c="$cores" 'BEGIN{ if(c<1)c=1; printf "%.2f", l/c }')

# memory: used percent via MemAvailable
read mem_total_k mem_avail_k < <(awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo 2>/dev/null)
mem_total_m=$(awk -v k="$mem_total_k" 'BEGIN{ printf "%.0f", k/1024 }')
mem_avail_m=$(awk -v k="$mem_avail_k" 'BEGIN{ printf "%.0f", k/1024 }')
mem_used_m=$(( mem_total_m - mem_avail_m ))
mem_pressure_pct=$(awk -v u="$mem_used_m" -v t="$mem_total_m" 'BEGIN{ if(t<=0){print 0}else{printf "%.1f", (u*100)/t} }')

# disk root percent
disk_root_pct=$(df -P -BG / 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5+0}' || echo 0)

# services allow list (optional)
services_allow=()
if [[ -r "$HEALTH_CFG" ]]; then
  # supports YAML inline list: services: allow: ["sshd", "cron"]
  inline=$(awk '/services:/,0{ if($0 ~ /allow:/){ print; exit } }' "$HEALTH_CFG" | awk -F'\[' '{print $2}' | awk -F']' '{print $1}')
  if [[ -n "$inline" ]]; then
    # split by comma
    IFS=',' read -r -a services_allow <<< "${inline}"
    # strip quotes/spaces
    for i in "${!services_allow[@]}"; do services_allow[$i]="$(echo "${services_allow[$i]}" | sed "s/'//g; s/\"//g; s/^ *//; s/ *$//")"; done
  fi
fi

failed_services=0
if command -v systemctl >/dev/null 2>&1 && [[ ${#services_allow[@]} -gt 0 ]]; then
  for s in "${services_allow[@]}"; do
    [[ -z "$s" ]] && continue
    if systemctl is-enabled --quiet "$s" 2>/dev/null; then
      if ! systemctl is-active --quiet "$s" 2>/dev/null; then
        failed_services=$((failed_services+1))
      fi
    fi
  done
fi

unhealthy_containers=0
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  unhealthy_containers=$(docker ps --format '{{.Status}}' 2>/dev/null | grep -i '\(unhealthy\)' | wc -l | awk '{print $1+0}')
fi

# thresholds
thr_disk_warn=$(thres_or thresholds.disk_root_pct.warn 85 | num)
thr_disk_err=$(thres_or thresholds.disk_root_pct.error 95 | num)
thr_load_warn=$(thres_or thresholds.load15_per_core.warn 1.0)
thr_load_err=$(thres_or thresholds.load15_per_core.error 2.0)
thr_mem_warn=$(thres_or thresholds.mem_pressure_pct.warn 70)
thr_mem_err=$(thres_or thresholds.mem_pressure_pct.error 85)

# status computation
st="ok"
violations=()
cmp() { awk -v a="$1" -v b="$2" 'BEGIN{ if(a>b) exit 0; else exit 1 }'; }
if cmp "$disk_root_pct" "$thr_disk_err" || cmp "$load15_per_core" "$thr_load_err" || cmp "$mem_pressure_pct" "$thr_mem_err" || [[ $failed_services -gt 0 ]] || [[ $unhealthy_containers -gt 0 ]]; then
  st="error"
elif cmp "$disk_root_pct" "$thr_disk_warn" || cmp "$load15_per_core" "$thr_load_warn" || cmp "$mem_pressure_pct" "$thr_mem_warn"; then
  st="warn"
fi

summary="disk ${disk_root_pct}%, load ${load15_per_core}/core, mem ${mem_pressure_pct}%, svc_failed ${failed_services}, containers_unhealthy ${unhealthy_containers}"

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record "$st" "$summary" "" \
    "\"metrics\":{\"disk_root_pct\":${disk_root_pct},\"load15_per_core\":${load15_per_core},\"mem_pressure_pct\":${mem_pressure_pct},\"unhealthy_containers\":${unhealthy_containers},\"failed_services\":${failed_services},\"cores\":${cores},\"load15\":${load15}}"
else
  case "$st" in ok) solen_ok "$summary" ;; warn) solen_warn "$summary" ;; *) solen_err "$summary" ;; esac
fi
exit $([[ "$st" = "ok" ]] && echo 0 || ([[ "$st" = "warn" ]] && echo 0 || echo 1))
