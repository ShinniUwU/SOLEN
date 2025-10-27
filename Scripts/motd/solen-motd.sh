#!/usr/bin/env bash
# SOLEN-META:
# name: motd/solen-motd
# Non-interactive fast path:
# - suppress pretty output for CI/cron/TERM=dumb
# - still allow explicit JSON output when requested
if [[ -n "${SOLEN_NO_TUI:-}" || "${TERM:-}" == "dumb" || ! -t 1 ]]; then
  if [[ "${1:-}" == "--json" ]]; then
    :
  else
    exit 0
  fi
fi
# summary: SOLEN system summary (fast MOTD) with --json and --plain
# tags: motd,summary,inventory
# verbs: info
# outputs: status,summary,details,metrics
# root: false
# since: 0.1.0
# breaking: false

set -Eeuo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Optional cross‑distro helpers for updates count
if [ -f "${THIS_DIR}/../lib/pm.sh" ]; then . "${THIS_DIR}/../lib/pm.sh"; fi

PLAIN=${SOLEN_PLAIN:-0}
JSON=${SOLEN_JSON:-0}
FULL=0
QUIET=0
WIDTH_MAX=80

# parse flags (keep backward compatible)
for arg in "$@"; do
  case "$arg" in
    --plain) PLAIN=1 ;;
    --json) JSON=1 ;;
    --full) FULL=1 ;;
    --quiet) QUIET=1 ;;
  esac
done

# non-interactive suppression (pretty output)
NONINT=0
# Consider non-interactive only when there's no TTY or TERM is dumb, or explicitly disabled.
# Do NOT rely on $- (scripts run in non-interactive shells but still print to TTY for MOTD).
if [ "${SOLEN_NO_TUI:-0}" = "1" ] || [ "${TERM:-}" = "dumb" ] || ! [ -t 1 ]; then
  NONINT=1
fi

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
  # Try CWD, then repo root alongside serverutils
  if [ -f "asciiart.ascii" ]; then
    cat asciiart.ascii | trim80
    return 0
  fi
  local root
  root="$(cd "${THIS_DIR}/../.." 2>/dev/null && pwd)"
  if [ -n "$root" ] && [ -f "$root/asciiart.ascii" ]; then
    cat "$root/asciiart.ascii" | trim80
  fi
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

color_for_pct() {
  # echo color code based on pct thresholds
  local p="${1:-0}"
  if awk -v x="$p" 'BEGIN{exit !(x<50)}'; then printf "%s" "$C_OK"; 
  elif awk -v x="$p" 'BEGIN{exit !(x<80)}'; then printf "%s" "$C_WARN"; 
  else printf "%s" "$C_ERR"; fi
}

bar() {
  # Fancy unicode bar with color (if not plain)
  local pct="$1" width="${2:-22}"
  [ -z "$pct" ] && pct=0
  local fill=$(awk -v p="$pct" -v w="$width" "BEGIN{ if(p<0)p=0; if(p>100)p=100; printf \"%d\", int(p*w/100+0.5) }")
  [ "$fill" -gt "$width" ] && fill="$width"
  local filled_char unf_char
  if [ "$PLAIN" != "1" ]; then filled_char="█"; unf_char="░"; else filled_char="#"; unf_char="-"; fi
  local i
  local col
  col=$(color_for_pct "$pct")
  printf "["
  if [ "$PLAIN" != "1" ]; then printf "%s" "$col"; fi
  for i in $(seq 1 "$fill"); do printf "%s" "$filled_char"; done
  if [ "$PLAIN" != "1" ]; then printf "%s" "$C_RESET"; fi
  for i in $(seq $((fill + 1)) "$width"); do printf "%s" "$unf_char"; done
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

  # CPU line with colored loads
  local l15_per_core
  l15_per_core=$(awk -v l="$l15" -v c="$cores" 'BEGIN{ if(c<1)c=1; printf "%.2f", l/c }')
  local c1 c5 c15
  c1=$(color_for_pct $(awk -v l="$l1" -v c="$cores" 'BEGIN{ if(c<1)c=1; printf "%.0f", (l*100)/c }'))
  c5=$(color_for_pct $(awk -v l="$l5" -v c="$cores" 'BEGIN{ if(c<1)c=1; printf "%.0f", (l*100)/c }'))
  c15=$(color_for_pct $(awk -v l="$l15" -v c="$cores" 'BEGIN{ if(c<1)c=1; printf "%.0f", (l*100)/c }'))
  printf "%sCPU%s:  load %s%s%s/%s%s%s/%s%s%s  cores %s%s%s  15m/core %s%s%s\n" \
    "$C_KEY" "$C_RESET" \
    "$c1" "$l1" "$C_RESET" \
    "$c5" "$l5" "$C_RESET" \
    "$c15" "$l15" "$C_RESET" \
    "$C_VAL" "$cores" "$C_RESET" \
    "$C_VAL" "$l15_per_core" "$C_RESET"

  # Memory line
  local used_g total_g avail_g
  used_g=$(to_gib "$used_m"); total_g=$(to_gib "$total_m"); avail_g=$(to_gib "$avail_m")
  printf "%s %s %s %s %s\n" "${C_KEY}Mem${C_RESET}:" "${C_VAL}${used_g}G${C_RESET}/${C_VAL}${total_g}G${C_RESET} avail ${C_VAL}${avail_g}G${C_RESET}" "$(bar "$mem_pct" 24)" "${C_DIM}" "${mem_pct%%%}%${C_RESET}" | awk '{printf "%s %-32s %-24s %s%s\n", $1, $2, $3, $4, $5}'

  # Swap line (if any)
  if [ "${swap_total_m:-0}" != "0" ]; then
    local swap_used_g swap_total_g
    swap_used_g=$(to_gib "$swap_used_m"); swap_total_g=$(to_gib "$swap_total_m")
    printf "%s %s %s %s %s\n" "${C_KEY}Swap${C_RESET}:" "${C_VAL}${swap_used_g}G${C_RESET}/${C_VAL}${swap_total_g}G${C_RESET}" "$(bar "$swap_pct" 24)" "${C_DIM}" "${swap_pct%%%}%${C_RESET}" | awk '{printf "%s %-32s %-24s %s%s\n", $1, $2, $3, $4, $5}'
  fi

  # Disks (top mounts)
  list_mounts() {
    df -P -BG | awk 'NR>1 && $1!~/(tmpfs|overlay|devtmpfs)/{gsub("G","",$2); gsub("G","",$3); gsub("%","",$5); printf "%s %s %s %s\n", $6,$3,$2,$5 }'
  }
  local printed=0
  while read -r mnt used total pct; do
    [ -z "$mnt" ] && continue
    printf "%s %s %s %s %s\n" "${C_KEY}Disk${C_RESET}:" "$(printf "%-5s %s%sG%s/%s%sG%s" "$mnt" "$C_VAL" "$used" "$C_RESET" "$C_VAL" "$total" "$C_RESET")" "$(bar "$pct" 24)" "${C_DIM}" "${pct%%%}%${C_RESET}" | awk '{printf "%s %-32s %-24s %s%s\n", $1, $2, $3, $4, $5}'
    printed=$((printed+1))
    [ $printed -ge 3 ] && break
  done < <(list_mounts)

  # Last login (best-effort)
  last_line=""
  if command -v last >/dev/null 2>&1; then
    last_line=$(last -n 2 -R -w "$USER" 2>/dev/null | grep -v 'wtmp begins' | head -n1 | sed 's/  \+/ /g')
  fi
  if [ -n "$last_line" ]; then
    w "${C_KEY}Last login${C_RESET}: ${C_VAL}${last_line}${C_RESET}"
  fi

  # Network
  local net_line
  net_line="${C_KEY}Net${C_RESET}:  iface ${C_VAL}${def}${C_RESET}  ${C_DIM}IPv4${C_RESET} ${C_VAL}${if4:-none}${C_RESET}  ${C_DIM}IPv6${C_RESET} ${C_VAL}${if6:-none}${C_RESET}"
  w "$net_line"

  # Soft update reminder (read cached info only; no network here)
  local cache="${XDG_STATE_HOME:-$HOME/.local/state}/solen/update-cache.json"
  if [ -f "$cache" ]; then
    local inst latest upd ch
    inst=$("${THIS_DIR}/../../serverutils" version 2>/dev/null | awk '{print $1}')
    latest=$(jq -r '.version // empty' "$cache" 2>/dev/null || true)
    ch=$(jq -r '.channel // "stable"' "$cache" 2>/dev/null || true)
    # SemVer compare with basic pre-release handling: rc/nightly < final
    if [ -n "$inst" ] && [ -n "$latest" ]; then
      inst_main="${inst%%-*}"; latest_main="${latest%%-*}"
      inst_pre="${inst#${inst_main}}"; latest_pre="${latest#${latest_main}}"
      cmp_main=$(awk -v A="$inst_main" -v B="$latest_main" 'BEGIN{n=split(A,a,".");m=split(B,b,"."); for(i=1;i<= (n>m?n:m); i++){aa=(i<=n?a[i]:0);bb=(i<=m?b[i]:0); if(aa+0<bb+0){print -1; exit} if(aa+0>bb+0){print 1; exit}} print 0}')
      if [ "$cmp_main" -lt 0 ]; then cmp=-1
      elif [ "$cmp_main" -gt 0 ]; then cmp=1
      else
        # Same main; treat pre-release as lower than final
        if [ -n "$inst_pre" ] && [ -z "$latest_pre" ]; then cmp=-1
        elif [ -z "$inst_pre" ] && [ -n "$latest_pre" ]; then cmp=1
        else cmp=0; fi
      fi
      if [ "$cmp" -lt 0 ]; then
        # Show at most once per day per version
        local stamp_dir="${XDG_STATE_HOME:-$HOME/.local/state}/solen"
        local stamp_file="$stamp_dir/update-notify.json"
        mkdir -p "$stamp_dir" 2>/dev/null || true
        local today; today=$(date -u +%F)
        # Additionally, suppress if checked very recently (< 1h)
        local checked_recent=0; last_check="$(jq -r '.checked_at // empty' "$cache" 2>/dev/null || true)"
        if [ -n "$last_check" ]; then
          if [ $(( $(date -u +%s) - $(date -u -d "$last_check" +%s 2>/dev/null || echo 0) )) -lt 3600 ]; then checked_recent=1; fi
        fi
        local stamped_ver stamped_date
        if [ -f "$stamp_file" ]; then
          stamped_ver=$(jq -r '.version // empty' "$stamp_file" 2>/dev/null || true)
          stamped_date=$(jq -r '.date // empty' "$stamp_file" 2>/dev/null || true)
        fi
        if { [ "$stamped_ver" != "$latest" ] || [ "$stamped_date" != "$today" ]; } && [ $checked_recent -eq 0 ]; then
          w "${C_DIM}· solen: update available — ${inst} → ${latest} (${ch}); run ${C_VAL}serverutils update --apply${C_RESET}"
          printf '{"version":"%s","date":"%s"}\n' "$latest" "$today" > "$stamp_file" 2>/dev/null || true
        fi
      fi
    fi
  fi
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

  # Optional extras: updates, services, containers
  local updates=""
  if command -v pm_detect >/dev/null 2>&1; then pm_detect || true; fi
  if command -v pm_check_updates_count >/dev/null 2>&1; then updates=$(pm_check_updates_count 2>/dev/null || echo 0); fi

  local services_json="[]" services_file
  if [ -f "$HOME/.config/solen/services" ]; then services_file="$HOME/.config/solen/services"; elif [ -f "/etc/solen/services" ]; then services_file="/etc/solen/services"; fi
  if [ -n "${services_file:-}" ]; then
    mapfile -t _lines < <(grep -v '^[[:space:]]*#' "$services_file" | sed '/^$/d')
    if [ ${#_lines[@]} -gt 0 ]; then
      local first=1
      services_json="["
      for ln in "${_lines[@]}"; do
        label="${ln%%;*}"; target="${ln#*;}"
        status="down"
        if printf '%s' "$target" | grep -q '\.'; then
          systemctl is-active --quiet "$target" 2>/dev/null && status="up"
        else
          pgrep -f "$target" >/dev/null 2>&1 && status="up"
        fi
        esc_label=$(printf '%s' "$label" | sed 's/\\/\\\\/g; s/"/\\"/g')
        [ $first -eq 0 ] && services_json+=" ," || first=0
        services_json+="{\"label\":\"$esc_label\",\"status\":\"$status\"}"
      done
      services_json+="]"
    fi
  fi

  local docker_json podman_json
  docker_json=""; podman_json=""
  if command -v docker >/dev/null 2>&1; then
    dr=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    dt=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    dnames=$(docker ps --format '{{.Names}}' 2>/dev/null | head -n 3 | paste -sd, -)
    docker_json=$(printf '{"running":%s,"total":%s,"top":[%s]}' "$dr" "$dt" "$(printf '%s' "$dnames" | sed 's/\([^,]*\)/"\1"/g')")
  fi
  if command -v podman >/dev/null 2>&1; then
    pr=$(podman ps -q 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    pt=$(podman ps -aq 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    pnames=$(podman ps --format '{{.Names}}' 2>/dev/null | head -n 3 | paste -sd, -)
    podman_json=$(printf '{"running":%s,"total":%s,"top":[%s]}' "$pr" "$pt" "$(printf '%s' "$pnames" | sed 's/\([^,]*\)/"\1"/g')")
  fi

  if [ -n "$docker_json" ] || [ -n "$podman_json" ] || [ -n "$updates" ] || [ "$services_json" != "[]" ]; then
    printf '{"status":"ok","summary":"%s","ts":"%s","host":"%s","metrics":{"load1":%s,"load5":%s,"load15":%s,"cores":%s,"load15_per_core":%s,"mem_used_mi":%s,"mem_total_mi":%s,"mem_used_pct":%s,"swap_used_mi":%s,"swap_total_mi":%s,"swap_used_pct":%s,"disk_root_used_pct":%s},"details":{"default_iface":"%s","ipv4":"%s","ipv6":"%s","os":"%s","kernel":"%s","uptime":"%s"%s%s%s%s}}\n' \
      "$(echo "$summary" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$host" \
      "$l1" "$l5" "$l15" "$cores" "$l15_per_core" "$used_m" "$total_m" "$mem_pct" "$swap_used_m" "$swap_total_m" "${swap_pct:-0}" "${droot_pct:-0}" \
      "${def:-unknown}" "${if4:-}" "${if6:-}" "$os" "$kernel" "$up" \
      "$( [ -n "$updates" ] && printf ',"updates":%s' "$updates" )" \
      "$( [ -n "$docker_json" ] && printf ',"docker":%s' "$docker_json" )" \
      "$( [ -n "$podman_json" ] && printf ',"podman":%s' "$podman_json" )" \
      "$( [ "$services_json" != "[]" ] && printf ',"services":%s' "$services_json" )"
  else
    printf '{"status":"ok","summary":"%s","ts":"%s","host":"%s","metrics":{"load1":%s,"load5":%s,"load15":%s,"cores":%s,"load15_per_core":%s,"mem_used_mi":%s,"mem_total_mi":%s,"mem_used_pct":%s,"swap_used_mi":%s,"swap_total_mi":%s,"swap_used_pct":%s,"disk_root_used_pct":%s},"details":{"default_iface":"%s","ipv4":"%s","ipv6":"%s","os":"%s","kernel":"%s","uptime":"%s"}}\n' \
      "$(echo "$summary" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$host" \
      "$l1" "$l5" "$l15" "$cores" "$l15_per_core" "$used_m" "$total_m" "$mem_pct" "$swap_used_m" "$swap_total_m" "${swap_pct:-0}" "${droot_pct:-0}" \
      "${def:-unknown}" "${if4:-}" "${if6:-}" "$os" "$kernel" "$up"
  fi
}

main() {
  if [ "$JSON" = "1" ]; then
    print_json
    return
  fi
  # Pretty output gating in non-interactive
  if [ $NONINT -eq 1 ]; then
    return
  fi
  if [ $QUIET -eq 1 ]; then
    local host os cpu l1 l5 l15 used_m total_m upcnt
    host="$(_host)"; os="$(_os)"; cpu="$(_cpu)"
    l1=$(awk '{print $1}' <<<"$cpu"); l5=$(awk '{print $2}' <<<"$cpu"); l15=$(awk '{print $3}' <<<"$cpu")
    read used_m _c _a total_m _p < <(_mem)
    upcnt=""
    if command -v pm_detect >/dev/null 2>&1 && command -v pm_check_updates_count >/dev/null 2>&1; then pm_detect || true; upcnt=$(pm_check_updates_count 2>/dev/null || echo 0); fi
    printf "%s — load %s/%s/%s; mem %sMi/%sMi%s\n" "$host" "$l1" "$l5" "$l15" "$used_m" "$total_m" "${upcnt:+; updates ${upcnt}}"
    return
  fi
  print_human
  if [ $FULL -eq 1 ]; then
    # Services panel
    local services_file
    if [ -f "$HOME/.config/solen/services" ]; then services_file="$HOME/.config/solen/services"; elif [ -f "/etc/solen/services" ]; then services_file="/etc/solen/services"; fi
    if [ -n "${services_file:-}" ]; then
      w "${C_TITLE}""Services""${C_RESET}"
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        printf '%s' "$line" | grep -q '^#' && continue
        label="${line%%;*}"; target="${line#*;}"
        status="down"; sym="✗"; col="$C_ERR"
        if printf '%s' "$target" | grep -q '\.'; then
          systemctl is-active --quiet "$target" 2>/dev/null && { status="up"; sym="✓"; col="$C_OK"; }
        else
          pgrep -f "$target" >/dev/null 2>&1 && { status="up"; sym="✓"; col="$C_OK"; }
        fi
        w "  ${label}: ${col}${sym}${C_RESET} ${status}"
      done < "$services_file"
    fi
    # Containers
    if command -v docker >/dev/null 2>&1; then
      dr=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ' || echo 0)
      dt=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ' || echo 0)
      w "${C_TITLE}""Docker""${C_RESET}: running ${C_VAL}${dr}${C_RESET}/${C_VAL}${dt}${C_RESET}"
      docker ps --format '{{.Names}}' 2>/dev/null | head -n3 | awk '{printf "  - %s\n", $0}'
    fi
    if command -v podman >/dev/null 2>&1; then
      pr=$(podman ps -q 2>/dev/null | wc -l | tr -d ' ' || echo 0)
      pt=$(podman ps -aq 2>/dev/null | wc -l | tr -d ' ' || echo 0)
      w "${C_TITLE}""Podman""${C_RESET}: running ${C_VAL}${pr}${C_RESET}/${C_VAL}${pt}${C_RESET}"
      podman ps --format '{{.Names}}' 2>/dev/null | head -n3 | awk '{printf "  - %s\n", $0}'
    fi
    # Updates
    upcnt=""
    if command -v pm_detect >/dev/null 2>&1 && command -v pm_check_updates_count >/dev/null 2>&1; then pm_detect || true; upcnt=$(pm_check_updates_count 2>/dev/null || echo 0); fi
    if [ -n "$upcnt" ]; then w "${C_TITLE}""Updates""${C_RESET}: ${C_VAL}${upcnt}${C_RESET}"; fi
  fi
}

main "$@"
