#!/usr/bin/env bash

# SOLEN-META:
# name: docker/update-docker-compose-app
# summary: Pull latest images and restart a Docker Compose stack in a directory
# requires: docker,docker-compose
# tags: docker,update,deploy
# verbs: ensure,fix
# since: 0.1.0
# breaking: false
# outputs: status, summary, actions[]
# root: false

# Strict mode
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--json] [--yes] <path_to_compose_dir>

Pull latest images and restart a Docker Compose app in the given directory.
Requires: docker, docker-compose
EOF
}

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) solen_err "unknown option: $1"; usage; exit 1 ;;
    *) break ;;
  esac
done

if [[ $# -lt 1 ]]; then
  solen_err "missing target directory"
  usage
  exit 1
fi

TARGET_DIR="$1"

# Dependencies and env checks
if ! command -v docker-compose >/dev/null 2>&1; then
  solen_err "docker-compose not found"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "docker-compose not found" "" "\"code\":2"
  exit 2
fi
if ! command -v docker >/dev/null 2>&1; then
  solen_err "docker not found"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "docker not found" "" "\"code\":2"
  exit 2
fi
if [[ ! -d "$TARGET_DIR" ]]; then
  solen_err "target directory not found: $TARGET_DIR"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "target directory not found" "" "\"code\":1"
  exit 1
fi

COMPOSE_FILE="${TARGET_DIR}/docker-compose.yml"
if [[ ! -f "$COMPOSE_FILE" ]]; then
  COMPOSE_FILE="${TARGET_DIR}/docker-compose.yaml"
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    solen_err "compose file not found in: $TARGET_DIR"
    [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "compose file not found" "" "\"code\":1"
    exit 1
  fi
fi

# Policy: service restart requires allow for 'docker'
if ! solen_policy_allows_service_restart "docker"; then
  local_msg="policy denies restarting docker services"
  solen_warn "$local_msg"
  if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
    solen_json_record error "$local_msg" "docker-compose pull\ndocker-compose up -d" "\"code\":4"
  fi
  exit 4
fi

# Build actions list
actions=$(cat <<ACTIONS
cd "$TARGET_DIR"
docker-compose -f "$COMPOSE_FILE" pull
docker-compose -f "$COMPOSE_FILE" up -d
ACTIONS
)

if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
  solen_info "dry-run: would execute"
  printf '%s\n' "$actions"
  echo "would change 2 items"
  if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
    solen_json_record ok "would update compose app at $TARGET_DIR" "$actions" "\"would_change\":2"
  fi
  exit 0
fi

# Confirmation
if [[ $SOLEN_FLAG_YES -ne 1 ]]; then
  read -r -p "Proceed to update stack in '${TARGET_DIR}'? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    solen_info "aborted by user"
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record warn "aborted by user" "" "\"code\":1"
    fi
    exit 1
  fi
fi

solen_info "pulling latest images"
set +e
(
  cd "$TARGET_DIR" && docker-compose -f "$COMPOSE_FILE" pull
)
rc_pull=$?
set -e

if [[ $rc_pull -ne 0 ]]; then
  solen_err "image pull failed"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "image pull failed" "$actions" "\"code\":10"
  exit 10
fi

solen_info "restarting stack"
set +e
(
  cd "$TARGET_DIR" && docker-compose -f "$COMPOSE_FILE" up -d
)
rc_up=$?
set -e

if [[ $rc_up -ne 0 ]]; then
  solen_err "stack restart failed"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "stack restart failed" "$actions" "\"code\":10"
  exit 10
fi

solen_ok "compose app updated"
if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "compose app updated at $TARGET_DIR" "$actions" "\"changed\":2"
fi
exit 0

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
