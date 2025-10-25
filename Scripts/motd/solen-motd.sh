#!/usr/bin/env bash
# SOLEN-META:
# name: motd/solen-motd
# summary: SOLEN system summary (fast MOTD) with --json and --plain
# tags: motd,summary,inventory
# verbs: info
# outputs: status,summary,details,metrics
# root: false
# since: 0.1.0
# breaking: false

set -Eeuo pipefail

PLAIN=${SOLEN_PLAIN:-0}
JSON=${SOLEN_JSON:-0}
WIDTH_MAX=80

for arg in "$@"; do
  case "$arg" in
    --plain) PLAIN=1 ;;
    --json) JSON=1 ;;
  esac
done

C_RESET=""
C_TITLE=""
C_KEY=""
C_VAL=""
C_DIM=""
C_OK=""
C_WARN=""
C_ERR=""

if [ "$PLAIN" != "1" ] && [ -t 1 ]; then
  C_RESET=$'\033[0m'
  C_TITLE=$'\033[1;36m'
  C_KEY=$'\033[38;5;245m'
  C_VAL=$'\033[1;37m'
  C_DIM=$'\033[2m'
  C_OK=$'\033[32m'
  C_WARN=$'\033[33m'
  C_ERR=$'\033[31m'
fi

w() { printf "%s\n" "$*"; }
trim80() { awk -v W="$WIDTH_MAX" '{s=$0; if(length(s)>W){printf "%s…\n", substr(s,1,W-1)} else print s }'; }
center() {
  # center to terminal width but cap at WIDTH_MAX
  local s="$1" cols="${COLUMNS:-80}"
  [ "$cols" -gt "$WIDTH_MAX" ] && cols="$WIDTH_MAX"
  local len=${#s}
  if [ "$len" -ge "$cols" ]; then
    w "$s" | trim80
    return
  fi
  local pad=$(((cols - len) / 2))
  printf "%*s%s\n" "$pad" "" "$s"
}

read_banner() {
  if [ -f "asciiart.ascii" ]; then
    cat asciiart.ascii | trim80
  elif [ -f "./asciiart.ascii" ]; then
    cat ./asciiart.ascii | trim80
  else return 0; fi
}

# --- data collectors (fast) ---
_host() { hostname 2> /dev/null || uname -n; }
_kernel() { uname -r; }
_uptime() {
  if [ -r /proc/uptime ]; then
    awk '{s=int($1); d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60);
      printf "%dd %dh %dm", d,h,m }' /proc/uptime
  else
    uptime | sed 's/.*up \([^,]*\), .*/\1/' || echo "unknown"
  fi
}
_os() {
  if command -v lsb_release > /dev/null 2>&1; then
    lsb_release -ds 2> /dev/null | sed 's/"//g'
  elif [ -r /etc/os-release ]; then
    . /etc/os-release
    echo "${PRETTY_NAME:-$NAME $VERSION_ID}"
  else
    uname -s
  fi
}
_cpu() {
  local loads cores
  loads=$(cat /proc/loadavg 2> /dev/null | awk '{print $1,$2,$3}')
  cores=$(getconf _NPROCESSORS_ONLN 2> /dev/null || nproc 2> /dev/null || echo 1)
  printf "%s %s\n" "$loads" "$cores"
}
_mem() {
  awk '
    BEGIN{used=0;cached=0;avail=0;total=0}
    /MemTotal:/ {total=$2/1024}
    /MemAvailable:/ {avail=$2/1024}
    /Cached:/ {cached=$2/1024}
    END{
      used=total-avail;
      pct=(total>0? (used*100/total):0);
      printf "%.0f %.0f %.0f %.0f %.1f\n", used,cached,avail,total,pct
    }' /proc/meminfo
}
_swap() {
  awk '
    /SwapTotal:/ {t=$2/1024}
    /SwapFree:/ {f=$2/1024}
    END{
      u=t-f; pct=(t>0? (u*100/t):0);
      printf "%.0f %.0f %.1f\n", u,t,pct
    }' /proc/meminfo
}
_disk_line() {
  # mount used total pct
  df -P -BG "$1" 2> /dev/null | awk 'NR==2{gsub("G","",$2);gsub("G","",$3);gsub("%","",$5);
    printf "%s %.1f %.1f %.1f\n", $6,$3,$2,$5 }'
}
_net() {
  if command -v ip > /dev/null 2>&1; then
    local def if4 if6
    def=$(ip route 2> /dev/null | awk '/^default/{print $5; exit}')
    if4=$(ip -4 -o addr show dev "$def" 2> /dev/null | awk '{print $4; exit}')
    if6=$(ip -6 -o addr show dev "$def" 2> /dev/null | awk '{print $4; exit}')
    printf "%s|%s|%s\n" "${def:-unknown}" "${if4:-}" "${if6:-}"
  else
    printf "degraded||\n"
  fi
}

bar() {
  # bar PCT width (handles floats)
  local pct="$1" width="${2:-20}"
  [ -z "$pct" ] && pct=0
  # compute fill with awk to support floats
  local fill=$(awk -v p="$pct" -v w="$width" "BEGIN{ if(p<0)p=0; if(p>100)p=100; printf \"%d\", int(p*w/100) }")
  [ "$fill" -gt "$width" ] && fill="$width"
  printf "["
  printf "%0.s#" $(seq 1 "$fill")
  printf "%0.s-" $(seq $((fill + 1)) "$width")
  printf "]"
}

# --- formatting helpers ---
to_gib() { awk -v m="$1" 'BEGIN{ printf "%.1f", m/1024 }'; }
pct_of() { awk -v a="$1" -v b="$2" 'BEGIN{ if(b==0){print 0}else{printf "%.1f", (a*100)/b} }'; }
pad2() { printf "%2s" "$1"; }

print_human() {
  # Banner (if present)
  read_banner || true

  # Header
  local host os kernel up
  host="$(_host)"; os="$(_os)"; kernel="$(_kernel)"; up="$(_uptime)"
  local cpu loads l1 l5 l15 cores
  cpu="$(_cpu)"; l1=$(awk '{print $1}' <<<"$cpu"); l5=$(awk '{print $2}' <<<"$cpu"); l15=$(awk '{print $3}' <<<"$cpu"); cores=$(awk '{print $4}' <<<"$cpu")
  local mem used_m cached_m avail_m total_m mem_pct
  read used_m cached_m avail_m total_m mem_pct < <(_mem)
  local swap swap_used_m swap_total_m swap_pct
  read swap_used_m swap_total_m swap_pct < <(_swap)
  local droot_mount droot_used_g droot_total_g droot_pct
  read droot_mount droot_used_g droot_total_g droot_pct < <(_disk_line / || echo "/ 0 0 0")
  local dboot_mount dboot_used_g dboot_total_g dboot_pct
  read dboot_mount dboot_used_g dboot_total_g dboot_pct < <(_disk_line /boot || echo "/boot 0 0 0")
  local net def if4 if6
  IFS='|' read -r def if4 if6 < <(_net)

  local title
  title="${C_TITLE}SOLEN System Summary${C_RESET}"
  center "$title"
  w "${C_KEY}Host${C_RESET}: ${C_VAL}${host}${C_RESET}"
  w "${C_KEY}OS${C_RESET}:   ${C_VAL}${os}${C_RESET}  ${C_DIM}kernel${C_RESET} ${kernel}  ${C_DIM}uptime${C_RESET} ${up}"

  # CPU line
  local l15_per_core
  l15_per_core=$(awk -v l="$l15" -v c="$cores" 'BEGIN{ if(c<1)c=1; printf "%.2f", l/c }')
  w "${C_KEY}CPU${C_RESET}:  load ${C_VAL}${l1}${C_RESET}/${C_VAL}${l5}${C_RESET}/${C_VAL}${l15}${C_RESET}  cores ${C_VAL}${cores}${C_RESET}  15m/core ${C_VAL}${l15_per_core}${C_RESET}"

  # Memory line
  local used_g total_g avail_g
  used_g=$(to_gib "$used_m"); total_g=$(to_gib "$total_m"); avail_g=$(to_gib "$avail_m")
  printf "%s %s %s %s %s\n" "${C_KEY}Mem${C_RESET}:" "${C_VAL}${used_g}G${C_RESET}/${C_VAL}${total_g}G${C_RESET} avail ${C_VAL}${avail_g}G${C_RESET}" "$(bar "$mem_pct" 20)" "${C_DIM}" "${mem_pct%%%}%${C_RESET}" | awk '{printf "%s %-28s %-22s %s%s\n", $1, $2, $3, $4, $5}'

  # Swap line (if any)
  if [ "${swap_total_m:-0}" != "0" ]; then
    local swap_used_g swap_total_g
    swap_used_g=$(to_gib "$swap_used_m"); swap_total_g=$(to_gib "$swap_total_m")
    printf "%s %s %s %s %s\n" "${C_KEY}Swap${C_RESET}:" "${C_VAL}${swap_used_g}G${C_RESET}/${C_VAL}${swap_total_g}G${C_RESET}" "$(bar "$swap_pct" 20)" "${C_DIM}" "${swap_pct%%%}%${C_RESET}" | awk '{printf "%s %-28s %-22s %s%s\n", $1, $2, $3, $4, $5}'
  fi

  # Disks
  if [ "${droot_total_g:-0}" != "0" ]; then
    printf "%s %s %s %s %s\n" "${C_KEY}Disk${C_RESET}:" "/    ${C_VAL}${droot_used_g}G${C_RESET}/${C_VAL}${droot_total_g}G${C_RESET}" "$(bar "$droot_pct" 20)" "${C_DIM}" "${droot_pct%%%}%${C_RESET}" | awk '{printf "%s %-28s %-22s %s%s\n", $1, $2, $3, $4, $5}'
  fi
  if [ "${dboot_total_g:-0}" != "0" ]; then
    printf "%s %s %s %s %s\n" "${C_KEY}Disk${C_RESET}:" "/boot ${C_VAL}${dboot_used_g}G${C_RESET}/${C_VAL}${dboot_total_g}G${C_RESET}" "$(bar "$dboot_pct" 20)" "${C_DIM}" "${dboot_pct%%%}%${C_RESET}" | awk '{printf "%s %-28s %-22s %s%s\n", $1, $2, $3, $4, $5}'
  fi

  # Network
  local net_line
  net_line="${C_KEY}Net${C_RESET}:  iface ${C_VAL}${def}${C_RESET}  ${C_DIM}IPv4${C_RESET} ${C_VAL}${if4:-none}${C_RESET}  ${C_DIM}IPv6${C_RESET} ${C_VAL}${if6:-none}${C_RESET}"
  w "$net_line"
}

print_json() {
  local host os kernel up
  host="$(_host)"; os="$(_os)"; kernel="$(_kernel)"; up="$(_uptime)"
  local cpu l1 l5 l15 cores
  cpu="$(_cpu)"; l1=$(awk '{print $1}' <<<"$cpu"); l5=$(awk '{print $2}' <<<"$cpu"); l15=$(awk '{print $3}' <<<"$cpu"); cores=$(awk '{print $4}' <<<"$cpu")
  local mem used_m cached_m avail_m total_m mem_pct
  read used_m cached_m avail_m total_m mem_pct < <(_mem)
  local swap_used_m swap_total_m swap_pct
  read swap_used_m swap_total_m swap_pct < <(_swap)
  local _m _u _t droot_pct
  read _m _u _t droot_pct < <(_disk_line / || echo "/ 0 0 0")
  local def if4 if6
  IFS='|' read -r def if4 if6 < <(_net)
  local l15_per_core
  l15_per_core=$(awk -v l="$l15" -v c="$cores" 'BEGIN{ if(c<1)c=1; printf "%.2f", l/c }')

  local summary
  summary="${host} — ${os}; load ${l1}/${l5}/${l15} on ${cores} cores; mem ${used_m}Mi/${total_m}Mi; root ${droot_pct}%"
  # Emit single JSON record
  printf '{"status":"ok","summary":"%s","ts":"%s","host":"%s","metrics":{"load1":%s,"load5":%s,"load15":%s,"cores":%s,"load15_per_core":%s,"mem_used_mi":%s,"mem_total_mi":%s,"mem_used_pct":%s,"swap_used_mi":%s,"swap_total_mi":%s,"swap_used_pct":%s,"disk_root_used_pct":%s},"details":{"default_iface":"%s","ipv4":"%s","ipv6":"%s","os":"%s","kernel":"%s","uptime":"%s"}}\n' \
    "$(echo "$summary" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$host" \
    "$l1" "$l5" "$l15" "$cores" "$l15_per_core" "$used_m" "$total_m" "$mem_pct" "$swap_used_m" "$swap_total_m" "${swap_pct:-0}" "${droot_pct:-0}" \
    "${def:-unknown}" "${if4:-}" "${if6:-}" "$os" "$kernel" "$up"
}

main() {
  if [ "$JSON" = "1" ]; then
    print_json
  else
    print_human
  fi
}

main "$@"
