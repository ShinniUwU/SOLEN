#!/usr/bin/env bash

# SOLEN-META:
# name: motd/collect
# summary: Collect host metrics for MOTD (JSON only)
# requires: awk,sed,df
# tags: motd,metrics
# verbs: info
# since: 0.2.0
# breaking: false
# outputs: status,summary,metrics,details
# root: false

set -Eeuo pipefail

host() { hostname 2>/dev/null || uname -n; }
kernel() { uname -r; }
uptime_str() {
  if [ -r /proc/uptime ]; then
    awk '{s=int($1); d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60); printf "%dd %dh %dm", d,h,m }' /proc/uptime
  else
    uptime | sed 's/.*up \([^,]*\), .*/\1/' || echo "unknown"
  fi
}
os_name() {
  if [ -r /etc/os-release ]; then . /etc/os-release; echo "${PRETTY_NAME:-$NAME $VERSION_ID}"; else uname -s; fi
}
cpu_loads() { awk '{print $1,$2,$3}' /proc/loadavg 2>/dev/null; }
cpu_cores() { getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1; }
mem() {
  awk '/MemTotal:/{t=$2/1024} /MemAvailable:/{a=$2/1024} END{u=t-a;p=(t>0?u*100/t:0); printf "%.0f %.0f %.0f %.1f\n", u,a,t,p }' /proc/meminfo
}
swap() { awk '/SwapTotal:/{t=$2/1024} /SwapFree:/{f=$2/1024} END{u=t-f;p=(t>0?u*100/t:0); printf "%.0f %.0f %.1f\n", u,t,p }' /proc/meminfo; }
disk_root() { df -P -BG / | awk 'NR==2{gsub("G","",$2);gsub("G","",$3);gsub("%","",$5); printf "%.1f %.1f %.0f\n", $3,$2,$5 }'; }

loads=$(cpu_loads || echo "0 0 0")
l1=$(awk '{print $1}' <<<"$loads"); l5=$(awk '{print $2}' <<<"$loads"); l15=$(awk '{print $3}' <<<"$loads")
cores=$(cpu_cores)
read mem_used mem_avail mem_total mem_pct < <(mem)
read swap_used swap_total swap_pct < <(swap)
read d_used d_total d_pct < <(disk_root || echo "0 0 0")

summary="$(host) — $(os_name); load ${l1}/${l5}/${l15} on ${cores} cores; mem ${mem_used}Mi/${mem_total}Mi; root ${d_pct}%"
printf '{"status":"ok","summary":"%s","ts":"%s","host":"%s","metrics":{"load1":%s,"load5":%s,"load15":%s,"cores":%s,"mem_used_mi":%s,"mem_total_mi":%s,"mem_used_pct":%s,"swap_used_mi":%s,"swap_total_mi":%s,"swap_used_pct":%s,"disk_root_used_pct":%s},"details":{"os":"%s","kernel":"%s","uptime":"%s"}}\n' \
  "$(echo "$summary" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$(host)" \
  "$l1" "$l5" "$l15" "$cores" "$mem_used" "$mem_total" "$mem_pct" "$swap_used" "$swap_total" "${swap_pct:-0}" "${d_pct:-0}" \
  "$(os_name)" "$(kernel)" "$(uptime_str)"

