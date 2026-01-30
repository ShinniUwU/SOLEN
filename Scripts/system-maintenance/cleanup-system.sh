#!/usr/bin/env bash

# SOLEN-META:
# name: system-maintenance/cleanup-system
# summary: Clean apt caches and remove unused dependencies
# requires: apt,sudo
# tags: apt,cleanup,maintenance
# verbs: fix
# since: 0.1.0
# breaking: false
# outputs: status, summary
# root: true

# Strict mode
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${THIS_DIR}/../lib/solen.sh" ]; then . "${THIS_DIR}/../lib/solen.sh"; fi
type solen_init_flags >/dev/null 2>&1 || solen_init_flags() { : "${SOLEN_FLAG_YES:=0}"; : "${SOLEN_FLAG_JSON:=0}"; : "${SOLEN_FLAG_DRYRUN:=1}"; [ "$SOLEN_FLAG_YES" = 1 ] && SOLEN_FLAG_DRYRUN=0 || true; }
type solen_parse_common_flag >/dev/null 2>&1 || solen_parse_common_flag() { case "$1" in --yes|-y) SOLEN_FLAG_YES=1; SOLEN_FLAG_DRYRUN=0; return 0;; --dry-run) SOLEN_FLAG_DRYRUN=1; return 0;; --json) SOLEN_FLAG_JSON=1; return 0;; esac; return 1; }
type solen_info >/dev/null 2>&1 || solen_info(){ echo -e "\033[0;36mℹ️  $*\033[0m"; }
type solen_ok   >/dev/null 2>&1 || solen_ok(){ echo -e "\033[0;32m✅ $*\033[0m"; }
type solen_warn >/dev/null 2>&1 || solen_warn(){ echo -e "\033[0;33m⚠️  $*\033[0m"; }
type solen_json_record >/dev/null 2>&1 || solen_json_record(){ printf '{"status":"%s","summary":"%s","ts":"%s","host":"%s","actions":%s%s}\n' "$1" "$2" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname 2>/dev/null || uname -n)" "[]" ""; }

solen_init_flags

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; else break; fi
done

# --- Configuration ---
# Add any needed configuration variables here

# --- Colors (Optional) ---
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'

# --- Helper Functions ---
echoinfo() {
  echo -e "${COLOR_CYAN}ℹ️  $1${COLOR_RESET}"
}

echook() {
  echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"
}

echowarn() {
  echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"
}

# --- Sanity / Dry-run planning ---
command -v apt > /dev/null 2>&1 || { echo >&2 "Error: apt command not found. This script requires a Debian-based system."; exit 1; }

actions=$'apt clean\napt autoclean -y\napt autoremove -y\n'
if [[ ${SOLEN_FLAG_DRYRUN:-0} -eq 1 ]]; then
  solen_info "[dry-run] Would execute:"
  printf '%s\n' "$actions"
  echo "would change 3 items"
  if [[ ${SOLEN_FLAG_JSON:-0} -eq 1 ]]; then
    actions_clean=$(printf '%s\n' "$actions" | sed '/^$/d')
    solen_json_record ok "would clean apt caches and unused packages" "$actions_clean" "\"would_change\":3"
  fi
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echowarn "This script needs to be run as root (use sudo)."
  exit 1
fi

# --- Main Logic ---
echoinfo "🧹 Starting system cleanup..."

echoinfo "   -> Cleaning apt package cache (apt clean)..."
apt clean
echook "   apt cache cleaned."

echoinfo "   -> Removing obsolete deb-packages (apt autoclean)..."
apt autoclean -y
echook "   Obsolete packages removed."

echoinfo "   -> Removing unused dependencies (apt autoremove)..."
apt autoremove -y
echook "   Unused dependencies removed."

echo # Newline for spacing

echook "✨ System cleanup finished!"

exit 0
