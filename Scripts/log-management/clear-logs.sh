#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# --- Configuration ---
JOURNALD_VACUUM_SIZE="100M" # Keep logs up to this total size
JOURNALD_VACUUM_TIME="7d"  # Keep logs up to this age (e.g., 3d, 7d, 2weeks)

TRUNCATE_LOGS=(         # List of log files to truncate (set size to 0)
  # "/var/log/syslog"      # Example: uncomment or add logs you want truncated
  # "/var/log/nginx/access.log"
  # "/var/log/nginx/error.log"
)

# --- Colors (Optional) ---
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'
COLOR_RED='\033[0;31m'

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

echoerror() {
  echo -e "${COLOR_RED}❌ $1${COLOR_RESET}" >&2
}

# --- Sanity Checks ---
if [[ $EUID -ne 0 ]]; then
   echowarn "This script needs to be run as root (use sudo)."
   exit 1
fi

# --- Main Logic ---
echoinfo "🗑️ Starting log cleanup..."

# 1. Clean Journald Logs
if command -v journalctl >/dev/null 2>&1; then
  # Updated echo message to reflect both conditions
  echoinfo "   -> Cleaning journald logs (if older than ${JOURNALD_VACUUM_TIME} or total size > ${JOURNALD_VACUUM_SIZE})..."
  # Updated journalctl command with both flags
  journalctl --vacuum-size=${JOURNALD_VACUUM_SIZE} --vacuum-time=${JOURNALD_VACUUM_TIME}
  echook "   Journald logs cleaned based on size/time limits."
else
  echowarn "   journalctl command not found, skipping journald cleanup."
fi

# 2. Truncate Specific Log Files
if [ ${#TRUNCATE_LOGS[@]} -gt 0 ]; then
  echoinfo "   -> Truncating specific log files (setting size to 0)..."
  for log_file in "${TRUNCATE_LOGS[@]}"; do
    if [ -f "$log_file" ]; then
      echoinfo "      Truncating ${log_file}..."
      # Use sudo here in case the script isn't run as root but needs to truncate system logs
      sudo truncate -s 0 "$log_file"
      echook "      ${log_file} truncated."
    else
      echowarn "      Log file not found, skipping: ${log_file}"
    fi
  done
else
  echoinfo "   -> No specific log files configured for truncation."
fi

echo # Newline for spacing

echook "✨ Log cleanup finished!"

exit 0
