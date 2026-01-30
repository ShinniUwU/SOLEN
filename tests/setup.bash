#!/usr/bin/env bash
# Common setup for SOLEN bats tests

# Project root directory
export SOLEN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$SOLEN_ROOT:$PATH"

# Ensure clean environment
unset SOLEN_FLAG_YES SOLEN_FLAG_JSON SOLEN_FLAG_DRYRUN
unset SOLEN_JSON SOLEN_NOOP

# Source SOLEN libraries
load_solen_lib() {
  source "$SOLEN_ROOT/Scripts/lib/solen.sh"
  solen_init_flags
}

load_deps_lib() {
  source "$SOLEN_ROOT/Scripts/lib/deps.sh"
}

# Skip test if command not available
skip_unless_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || skip "Command '$cmd' not available"
}

# Skip test if not running as root
skip_unless_root() {
  [[ $EUID -eq 0 ]] || skip "Test requires root"
}

# Skip test if systemd not available
skip_unless_systemd() {
  command -v systemctl >/dev/null 2>&1 || skip "systemd not available"
}

# Compare JSON output structure (keys only, ignoring values)
compare_json_structure() {
  local actual="$1"
  local expected="$2"

  # Extract and sort keys
  local actual_keys=$(echo "$actual" | jq -S 'keys' 2>/dev/null || echo "[]")
  local expected_keys=$(echo "$expected" | jq -S 'keys' 2>/dev/null || echo "[]")

  [[ "$actual_keys" == "$expected_keys" ]]
}

# Validate JSON is well-formed
is_valid_json() {
  echo "$1" | jq -e . >/dev/null 2>&1
}

# Extract field from JSON
json_field() {
  local json="$1"
  local field="$2"
  echo "$json" | jq -r ".$field" 2>/dev/null
}

# Assert JSON field equals expected value
assert_json_field() {
  local json="$1"
  local field="$2"
  local expected="$3"
  local actual=$(json_field "$json" "$field")
  [[ "$actual" == "$expected" ]] || {
    echo "Expected $field='$expected', got '$actual'" >&2
    return 1
  }
}

# Create a temporary directory for test artifacts
setup_temp_dir() {
  TEST_TEMP_DIR=$(mktemp -d)
  export TEST_TEMP_DIR
}

# Clean up temporary directory
teardown_temp_dir() {
  [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}
