#!/usr/bin/env bash

# Strict mode
set -euo pipefail

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

# --- Sanity Checks ---
if [[ $EUID -ne 0 ]]; then
   echowarn "This script needs to be run as root (use sudo)."
   exit 1
fi

command -v apt >/dev/null 2>&1 || { echo >&2 "Error: apt command not found. This script requires a Debian-based system."; exit 1; }

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
