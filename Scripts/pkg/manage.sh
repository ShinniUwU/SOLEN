#!/usr/bin/env bash
# SOLEN-META:
# name: pkg/manage
# summary: Unified package management (apt+dnf): check/update/upgrade/autoremove
# tags: packages,apt,dnf,updates
# verbs: check,update,upgrade,autoremove
# outputs: status,summary,metrics
# root: false
# since: 0.1.0
# breaking: false
set -Eeuo pipefail

JSON=${SOLEN_JSON:-0}
NOOP=${SOLEN_NOOP:-0}
YES=${SOLEN_ASSUME_YES:-0}
MANAGER="auto"
CMD="${1:-}"
shift || true

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --dry-run) NOOP=1 ;;
    --yes) YES=1 ;;
    --manager)
      MANAGER="${2:-auto}"
      shift
      ;;
    *) ;;
  esac
  shift || true
done

host() { hostname 2> /dev/null || uname -n; }
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
j() { printf '%s\n' "$1"; }

detect() {
  [ "$MANAGER" != "auto" ] && echo "$MANAGER" && return
  if command -v apt-get > /dev/null 2>&1; then
    echo apt
    return
  fi
  if command -v dnf > /dev/null 2>&1; then
    echo dnf
    return
  fi
  echo none
}

pkg_check_apt() {
  if [ "$NOOP" = "1" ]; then
    sudo -n true > /dev/null 2>&1 || true
    out=$(apt-get -s upgrade 2> /dev/null || true)
  else
    sudo apt-get update > /dev/null 2>&1 || true
    out=$(apt-get -s upgrade 2> /dev/null || true)
  fi
  cnt=$(printf "%s\n" "$out" | awk '/^Inst /{c++} END{print c+0}')
  sz=$(printf "%s\n" "$out" | awk -F'[() ]+' '/^Inst /{for(i=1;i<=NF;i++) if($i=="size") s=$(i+1)} END{printf "%.0f", s+0}')
  reboot=0
  [ -f /var/run/reboot-required ] && reboot=1
  j "{\"status\":\"ok\",\"summary\":\"updates available: ${cnt}\",\"ts\":\"$(ts)\",\"host\":\"$(host)\",\"metrics\":{\"packages\":$cnt,\"size_kb\":$sz,\"reboot\":$reboot}}"
}

pkg_check_dnf() {
  # dnf check-update returns 100 when updates available; parse list count
  if [ "$NOOP" = "1" ]; then
    out=$(dnf -q check-update || true)
  else
    dnf -q makecache > /dev/null 2>&1 || true
    out=$(dnf -q check-update || true)
  fi
  cnt=$(printf "%s\n" "$out" | awk '/^\S+\.\S+\s+\S+\s+\S+$/ {c++} END{print c+0}')
  reboot=0
  command -v needs-restarting > /dev/null 2>&1 && needs-restarting -r > /dev/null 2>&1 || reboot=$?
  [ "$reboot" -ne 0 ] && reboot=1
  j "{\"status\":\"ok\",\"summary\":\"updates available: ${cnt}\",\"ts\":\"$(ts)\",\"host\":\"$(host)\",\"metrics\":{\"packages\":$cnt,\"reboot\":$reboot}}"
}

pkg_run_apt() {
  local verb="$1"
  case "$verb" in
    update)
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would run: apt-get update\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo apt-get update && j "{\"status\":\"ok\",\"summary\":\"apt-get update complete\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      fi
      ;;
    upgrade)
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would run: apt-get -y upgrade\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo apt-get -y upgrade && j "{\"status\":\"ok\",\"summary\":\"apt-get upgrade complete\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      fi
      ;;
    autoremove)
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would run: apt-get -y autoremove\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo apt-get -y autoremove && j "{\"status\":\"ok\",\"summary\":\"apt-get autoremove complete\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      fi
      ;;
  esac
}

pkg_run_dnf() {
  local verb="$1"
  case "$verb" in
    update)
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would run: dnf makecache\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo dnf -y makecache && j "{\"status\":\"ok\",\"summary\":\"dnf makecache complete\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      fi
      ;;
    upgrade)
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would run: dnf -y upgrade\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo dnf -y upgrade && j "{\"status\":\"ok\",\"summary\":\"dnf upgrade complete\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      fi
      ;;
    autoremove)
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would run: dnf -y autoremove\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo dnf -y autoremove && j "{\"status\":\"ok\",\"summary\":\"dnf autoremove complete\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      fi
      ;;
  esac
}

mgr=$(detect)
[ "$mgr" = "none" ] && {
  j "{\"status\":\"error\",\"summary\":\"no package manager (apt/dnf) found\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
  exit 2
}

case "$CMD" in
  check)
    [ "$mgr" = "apt" ] && pkg_check_apt || pkg_check_dnf
    ;;
  update | upgrade | autoremove)
    [ "$mgr" = "apt" ] && pkg_run_apt "$CMD" || pkg_run_dnf "$CMD"
    ;;
  *)
    echo "Usage: $0 {check|update|upgrade|autoremove} [--dry-run] [--json] [--manager apt|dnf]" >&2
    exit 1
    ;;
esac
