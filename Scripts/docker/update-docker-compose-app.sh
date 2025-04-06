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

# --- Safety Warning ---
echowarn "!!!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echowarn "This script pulls the latest images and restarts Docker containers"
echowarn "defined in a docker-compose.yml file. This can potentially break"
echowarn "your application if the new image has breaking changes or issues."
echowarn "USE WITH CAUTION and ensure you have backups or rollback plans."
echowarn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo

# --- Argument Parsing ---
if [ $# -ne 1 ]; then
	echoerror "Usage: $0 <path_to_docker_compose_directory>"
	exit 1
fi

TARGET_DIR="$1"

# --- Sanity Checks ---
command -v docker-compose >/dev/null 2>&1 || {
	echoerror "Error: docker-compose command not found. Is it installed and in your PATH?"
	exit 1
}

if [ ! -d "$TARGET_DIR" ]; then
	echoerror "Target directory not found: $TARGET_DIR"
	exit 1
fi

COMPOSE_FILE="${TARGET_DIR}/docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ] && [ ! -f "${TARGET_DIR}/docker-compose.yaml" ]; then
	# Allow for .yaml extension as well
	COMPOSE_FILE="${TARGET_DIR}/docker-compose.yaml"
	if [ ! -f "$COMPOSE_FILE" ]; then
		echoerror "docker-compose.yml (or .yaml) not found in: $TARGET_DIR"
		exit 1
	fi
fi

# Check docker daemon connectivity
if ! docker info >/dev/null 2>&1; then
	echoerror "Cannot connect to the Docker daemon. Is the docker daemon running?"
	exit 1
fi

# --- Confirmation (Optional but Recommended) ---
read -r -p "Are you sure you want to update the stack in '${TARGET_DIR}'? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
	echoinfo "Aborted by user."
	exit 0
fi

# --- Main Logic ---
echoinfo "🚀 Starting Docker Compose update for: ${TARGET_DIR}"

ORIGINAL_DIR=$(pwd)
cd "$TARGET_DIR" || {
	echoerror "Could not change directory to $TARGET_DIR"
	exit 1
}

HAS_ERRORS=0

echoinfo "   -> 🚢 Pulling latest images defined in ${COMPOSE_FILE}..."
if docker-compose pull; then
	echook "      Image pull completed (or images were up-to-date)."
else
	echoerror "      Image pull failed."
	HAS_ERRORS=1
fi

if [ $HAS_ERRORS -eq 0 ]; then
	echoinfo "   -> 🔄 Restarting application stack using 'docker-compose up -d'..."
	if docker-compose up -d; then
		echook "      Application stack restarted successfully."
	else
		echoerror "      Failed to restart application stack."
		HAS_ERRORS=1
	fi
fi

# Return to original directory
cd "$ORIGINAL_DIR" || echowarn "Could not return to original directory: $ORIGINAL_DIR"

echo # Newline for spacing

if [ $HAS_ERRORS -eq 0 ]; then
	echook "✨ Docker Compose update process finished successfully!"
	exit 0
else
	echoerror "❌ Docker Compose update process finished with errors."
	exit 1
fi
