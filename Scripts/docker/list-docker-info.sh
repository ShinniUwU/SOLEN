#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# --- Colors (Optional) ---
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_CYAN='\033[0;36m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'

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

echoerror() {
	echo -e "${COLOR_RED}❌ $1${COLOR_RESET}" >&2
}

# --- Sanity Checks ---
command -v docker >/dev/null 2>&1 || {
	echoerror "Error: docker command not found. Is Docker installed and in your PATH?"
	exit 1
}

# Check docker daemon connectivity
if ! docker info >/dev/null 2>&1; then
	echoerror "Cannot connect to the Docker daemon. Is the docker daemon running?"
	exit 1
fi

# --- Main Logic ---
echoinfo "🐳ℹ️ Gathering Docker information..."

# 1. Running Containers
echoheader "Running Containers"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || echoerror "Could not list running containers."

# 2. Images
echoheader "Docker Images"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" || echoerror "Could not list Docker images."

echo # Newline for spacing

echook "✨ Docker information retrieval finished!"

exit 0
