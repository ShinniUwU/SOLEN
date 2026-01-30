#!/usr/bin/env bash
# Dependency validation helpers for SOLEN scripts

# solen_require_cmds <cmd1> [cmd2] ...
# Checks if all specified commands are available.
# Exits with code 2 if any command is missing.
#
# Usage:
#   . "${THIS_DIR}/../lib/deps.sh"
#   solen_require_cmds systemctl jq curl
#
solen_require_cmds() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    local msg="Missing dependencies: ${missing[*]}"
    if type solen_err >/dev/null 2>&1; then
      solen_err "$msg"
    else
      echo "Error: $msg" >&2
    fi
    if [[ ${SOLEN_FLAG_JSON:-0} -eq 1 ]] && type solen_json_record >/dev/null 2>&1; then
      solen_json_record error "$msg" "" "\"code\":2"
    fi
    exit 2
  fi
}

# solen_require_root
# Exits with code 1 if not running as root.
#
# Usage:
#   solen_require_root
#
solen_require_root() {
  if [[ $EUID -ne 0 ]]; then
    local msg="This script must be run as root (use sudo)"
    if type solen_err >/dev/null 2>&1; then
      solen_err "$msg"
    else
      echo "Error: $msg" >&2
    fi
    if [[ ${SOLEN_FLAG_JSON:-0} -eq 1 ]] && type solen_json_record >/dev/null 2>&1; then
      solen_json_record error "$msg" "" "\"code\":1"
    fi
    exit 1
  fi
}

# solen_require_file <file_path> [description]
# Exits with code 2 if the file doesn't exist or isn't readable.
#
# Usage:
#   solen_require_file "/etc/myconfig.yaml" "configuration file"
#
solen_require_file() {
  local file="$1"
  local desc="${2:-file}"
  if [[ ! -r "$file" ]]; then
    local msg="Required $desc not found or not readable: $file"
    if type solen_err >/dev/null 2>&1; then
      solen_err "$msg"
    else
      echo "Error: $msg" >&2
    fi
    if [[ ${SOLEN_FLAG_JSON:-0} -eq 1 ]] && type solen_json_record >/dev/null 2>&1; then
      solen_json_record error "$msg" "" "\"code\":2"
    fi
    exit 2
  fi
}
