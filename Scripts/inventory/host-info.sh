#!/usr/bin/env bash

# SOLEN-META:
# name: inventory/host-info
# summary: Fast host inventory (OS, kernel, CPU/mem, disks, nics, docker, services)
# requires: awk,uname,ip,lsblk
# tags: inventory,info
# verbs: info
# since: 0.1.0
# breaking: false
# outputs: status, summary, metrics, details
# root: false

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $(basename "$0") [--json]

Collects a quick snapshot of host information, read-only and fast (<1s):
  - OS, kernel, uptime, CPU cores, memory totals
  - Disks and mounts counts, root usage
  - Network interfaces + default route
  - Docker presence + containers summary (if available)
  - Services (sshd, cron, docker) state if systemd present
EOF
}

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in -h|--help) usage; exit 0 ;; --) shift; break ;; -*) solen_err "unknown: $1"; usage; exit 1 ;; *) break ;; esac
done

# OS/kernel/uptime
os() {
  if command -v lsb_release >/dev/null 2>&1; then lsb_release -ds 2>/dev/null | sed 's/"//g';
  elif [[ -r /etc/os-release ]]; then . /etc/os-release; echo "${PRETTY_NAME:-$NAME $VERSION_ID}"; else uname -s; fi
}
kernel() { uname -r; }
uptime_h() {
  if [[ -r /proc/uptime ]]; then awk '{s=int($1); d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60); printf "%dd %dh %dm", d,h,m }' /proc/uptime; else echo "unknown"; fi
}

# CPU/mem
cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1)
read mem_total_k mem_avail_k < <(awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo 2>/dev/null)
mem_total_m=$(( mem_total_k/1024 ))
mem_avail_m=$(( mem_avail_k/1024 ))
mem_used_m=$(( mem_total_m - mem_avail_m ))

# Disks
disk_root_pct=$(df -P -BG / 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5+0}')
mounts_count=$(awk 'BEGIN{c=0} /^\/dev\//{c++} END{print c}' /proc/mounts 2>/dev/null || echo 0)
disks_count=$(lsblk -dn -o TYPE 2>/dev/null | awk '$1=="disk"{c++} END{print c+0}')

# Network
default_iface=""; gateway=""; ip4=""; ip6=""
if command -v ip >/dev/null 2>&1; then
  if ip route 2>/dev/null | grep -q '^default'; then
    default_iface=$(ip route | awk '/^default/{print $5; exit}')
    gateway=$(ip route | awk '/^default/{print $3; exit}')
    ip4=$(ip -4 -o addr show dev "$default_iface" 2>/dev/null | awk '{print $4; exit}')
    ip6=$(ip -6 -o addr show dev "$default_iface" 2>/dev/null | awk '{print $4; exit}')
  fi
fi

# Docker
docker_present=0; containers_total=0; containers_running=0; containers_unhealthy=0
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker_present=1
  containers_total=$(docker ps -a -q 2>/dev/null | wc -l | awk '{print $1+0}')
  containers_running=$(docker ps -q 2>/dev/null | wc -l | awk '{print $1+0}')
  containers_unhealthy=$(docker ps --format '{{.Status}}' 2>/dev/null | grep -i '\(unhealthy\)' | wc -l | awk '{print $1+0}')
fi

# Services (systemd)
svc_sshd="unknown"; svc_cron="unknown"; svc_docker="unknown"
if command -v systemctl >/dev/null 2>&1; then
  systemctl is-active --quiet ssh || true; [[ $? -eq 0 ]] && svc_sshd="active" || svc_sshd="inactive"
  systemctl is-active --quiet sshd || true; [[ $? -eq 0 ]] && svc_sshd="active" || true
  systemctl is-active --quiet cron || true; [[ $? -eq 0 ]] && svc_cron="active" || svc_cron="inactive"
  systemctl is-active --quiet docker || true; [[ $? -eq 0 ]] && svc_docker="active" || svc_docker="inactive"
fi

host="$(solen_host)"; oss="$(os)"; kern="$(kernel)"; up="$(uptime_h)"
summary="${oss}; ${cores}c/${mem_total_m}Mi; disks ${disks_count}, mounts ${mounts_count}; net ${default_iface:-none}; docker ${containers_running}/${containers_total}"

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  metrics_kv="\"metrics\":{\"cores\":${cores},\"mem_total_mi\":${mem_total_m},\"mem_used_mi\":${mem_used_m},\"disk_root_used_pct\":${disk_root_pct},\"disks\":${disks_count},\"mounts\":${mounts_count},\"containers_total\":${containers_total},\"containers_running\":${containers_running},\"containers_unhealthy\":${containers_unhealthy}}"
  details=$(cat <<D
"details":{
  "os":"$(printf '%s' "$oss" | sed 's/\\/\\\\/g; s/"/\\"/g')",
  "kernel":"$kern",
  "uptime":"$up",
  "network":{
    "default_iface":"${default_iface:-}",
    "gateway":"${gateway:-}",
    "ipv4":"${ip4:-}",
    "ipv6":"${ip6:-}"
  },
  "services":{
    "sshd":"$svc_sshd","cron":"$svc_cron","docker":"$svc_docker"
  }
}
D
)
  solen_json_record ok "$summary" "" "${metrics_kv},${details}"
else
  solen_head "Host"
  echo "$host — $oss (kernel $kern, uptime $up)"
  solen_head "CPU/Mem"
  echo "cores: $cores, mem: ${mem_used_m}/${mem_total_m} Mi"
  solen_head "Disks"
  echo "/ used: ${disk_root_pct}% ; disks: ${disks_count}, mounts: ${mounts_count}"
  solen_head "Network"
  echo "iface: ${default_iface:-none}, gateway: ${gateway:-}, ipv4: ${ip4:-}, ipv6: ${ip6:-}"
  solen_head "Docker"
  echo "present: $docker_present, running: ${containers_running}/${containers_total}, unhealthy: ${containers_unhealthy}"
  solen_head "Services"
  echo "sshd: $svc_sshd, cron: $svc_cron, docker: $svc_docker"
  solen_ok "inventory complete"
fi
exit 0
if [[ ${SOLEN_FLAG_JSON:-0} -eq 1 ]]; then
  # Emit an initial JSON record so validators see JSON immediately
  solen_json_record ok "begin: inventory" "" ""
fi
