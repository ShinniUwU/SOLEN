#!/usr/bin/env bash

# SOLEN-META:
# name: docker/list-docker-info
# summary: List Docker containers and images
# requires: docker
# tags: docker,inventory
# verbs: info
# since: 0.1.0
# breaking: false
# outputs: status, details.containers[], details.images[], summary
# root: false

# Strict mode
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--json]

List Docker containers and images on this host. Read-only.
EOF
}

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in -h|--help) usage; exit 0 ;; --) shift; break ;; -*) solen_err "unknown option: $1"; usage; exit 1 ;; *) break;; esac
done

# Optional policy token: docker-introspection
if ! solen_policy_allows_service_restart "docker"; then
  # reuse service gate only for example, or check generic token if available
  :
fi

# Policy token gate (optional)
if ! solen_policy_allows_token "docker-introspection"; then
  solen_warn "policy refused: docker-introspection"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "policy refused: docker-introspection" "" "\"code\":4"
  exit 4
fi

if ! command -v docker >/dev/null 2>&1; then
  solen_err "docker not found"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "docker not accessible (install or add user to docker group)" "" "\"code\":2"
  exit 2
fi

if ! docker info >/dev/null 2>&1; then
  solen_err "cannot connect to Docker daemon"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "docker not accessible (daemon or permissions)" "" "\"code\":2"
  exit 2
fi

# Gather containers
containers_tmp=$(mktemp)
images_tmp=$(mktemp)
trap 'rm -f "$containers_tmp" "$images_tmp"' EXIT

# columns: name id image status ports runningfor compose_project
docker ps -a --format '{{.Names}}\t{{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.RunningFor}}\t{{.Label "com.docker.compose.project"}}' >"$containers_tmp" || true
docker images --format '{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}' >"$images_tmp" || true

# Build NDJSON output or human output

containers_total=0; running=0; exited=0; unhealthy=0
images_total=0; images_dangling=0

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  # Emit per-container records
  while IFS=$'\t' read -r name id image status ports runningfor compose; do
    [[ -z "$name" ]] && continue
    containers_total=$((containers_total+1))
    state="unknown"; health=""
    if [[ "$status" == Up* ]]; then state="running"; running=$((running+1)); fi
    if [[ "$status" == Exited* ]]; then state="exited"; exited=$((exited+1)); fi
    if echo "$status" | grep -qi '(unhealthy)'; then health="unhealthy"; unhealthy=$((unhealthy+1)); fi
    if echo "$status" | grep -qi '(healthy)'; then health="healthy"; fi
    id_short="${id:0:12}"
    # details record
    summary="container ${name} ${state}"
    metrics="\"container\":1"
    actions=""
    printf '{"status":"%s","summary":"%s","ts":"%s","host":"%s","details":{"container":{"name":"%s","id_short":"%s","image":"%s","status":"%s","state":"%s","health":"%s","ports":"%s","compose_project":"%s","age":"%s"}}}\n' \
      "ok" "$(solen_json_escape "$summary")" "$(solen_ts)" "$(solen_host)" \
      "$(solen_json_escape "$name")" "$id_short" "$(solen_json_escape "$image")" "$(solen_json_escape "$status")" "$state" "$health" "$(solen_json_escape "$ports")" "$(solen_json_escape "${compose:-}")" "$(solen_json_escape "$runningfor")"
  done <"$containers_tmp"

  # Emit per-image records
  while IFS=$'\t' read -r repo tag id size_h; do
    [[ -z "$id" ]] && continue
    images_total=$((images_total+1))
    id_short="${id#sha256:}"; id_short="${id_short:0:12}"
    dangling=false; [[ "$repo" == "<none>" || "$tag" == "<none>" ]] && dangling=true && images_dangling=$((images_dangling+1))
    # convert size to bytes
    size_bytes=0
    if [[ "$size_h" =~ ^([0-9.]+)([KMG]B)$ ]]; then
      num=${BASH_REMATCH[1]}; unit=${BASH_REMATCH[2]}
      case "$unit" in KB) mul=1024;; MB) mul=$((1024*1024));; GB) mul=$((1024*1024*1024));; *) mul=1;; esac
      size_bytes=$(awk -v n="$num" -v m="$mul" 'BEGIN{ printf "%.0f", n*m }')
    fi
    summary="image ${repo}:${tag}"
    printf '{"status":"%s","summary":"%s","ts":"%s","host":"%s","details":{"image":{"repo":"%s","tag":"%s","id_short":"%s","size_bytes":%s,"dangling":%s}}}\n' \
      "ok" "$(solen_json_escape "$summary")" "$(solen_ts)" "$(solen_host)" \
      "$(solen_json_escape "$repo")" "$(solen_json_escape "$tag")" "$id_short" "$size_bytes" "$dangling"
  done <"$images_tmp"

  # Rollup line
  rollup="containers: ${containers_total} (running ${running}, unhealthy ${unhealthy}, exited ${exited}); images: ${images_total} (dangling ${images_dangling})"
  metrics_kv="\"containers_total\":${containers_total},\"running\":${running},\"unhealthy\":${unhealthy},\"exited\":${exited},\"images_total\":${images_total},\"images_dangling\":${images_dangling}"
  solen_json_record ok "$rollup" "" "$metrics_kv"
  exit 0
else
  solen_head "Running Containers"
  printf "%s\n" "NAMES\tIMAGE\tSTATUS\tPORTS"
  awk -F '\t' '{printf "%s\t%s\t%s\t%s\n", $1,$3,$4,$5}' "$containers_tmp" || true
  solen_head "Docker Images"
  printf "%s\n" "REPO\tTAG\tID\tSIZE"
  awk -F '\t' '{printf "%s\t%s\t%s\t%s\n", $1,$2,$3,$4}' "$images_tmp" || true
  solen_ok "docker information retrieval finished"
fi

exit 0

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
