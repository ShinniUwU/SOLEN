#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# --- Configuration ---
PING_TARGET="1.1.1.1" # Host to ping for connectivity check
PING_COUNT=3

# --- Colors (Optional) ---
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_CYAN='\033[0;36m'
COLOR_BLUE='\033[0;34m'

# --- Helper Functions ---
echoinfo() {
	echo -e "${COLOR_CYAN}ℹ️  $1${COLOR_RESET}"
}

echoheader() {
	echo -e "\n${COLOR_BLUE}--- $1 ---${COLOR_RESET}"
}

echook() {
	echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"
}

echowarn() {
	echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"
}

# --- Main Logic ---
echoinfo "🌐 Gathering network information..."

# 1. IP Addresses
echoheader "IP Addresses"
ip -brief address show || echowarn "Could not retrieve IP addresses using 'ip -brief address show'."

# 2. Listening Ports
echoheader "Listening Ports (TCP/UDP)"
if command -v ss >/dev/null 2>&1; then
	ss -tulnp || echowarn "Could not retrieve listening ports using 'ss -tulnp'."
else
	echowarn "ss command not found (needed to list ports). Try installing 'iproute2'."
fi

# 3. Connectivity Check
echoheader "Connectivity Check"
echoinfo "   Pinging ${PING_TARGET} (${PING_COUNT} times)..."
if ping -c ${PING_COUNT} ${PING_TARGET} >/dev/null 2>&1; then
	echook "   Ping to ${PING_TARGET} successful."
else
	echowarn "   Ping to ${PING_TARGET} failed."
fi

echo # Newline for spacing

echook "✨ Network information retrieval finished!"

exit 0
