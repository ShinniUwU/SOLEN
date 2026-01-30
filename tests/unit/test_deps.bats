#!/usr/bin/env bats
# Unit tests for Scripts/lib/deps.sh

setup() {
  load '../setup.bash'
  load_solen_lib
  load_deps_lib
}

# =============================================================================
# solen_require_cmds
# =============================================================================

@test "solen_require_cmds succeeds with available command" {
  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_cmds bash'
  [[ "$status" -eq 0 ]]
}

@test "solen_require_cmds succeeds with multiple available commands" {
  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_cmds bash cat ls'
  [[ "$status" -eq 0 ]]
}

@test "solen_require_cmds fails with missing command" {
  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_cmds nonexistent_command_xyz'
  [[ "$status" -eq 2 ]]
}

@test "solen_require_cmds reports missing command name" {
  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_cmds nonexistent_command_xyz 2>&1'
  [[ "$output" == *"nonexistent_command_xyz"* ]]
}

@test "solen_require_cmds fails if any command missing" {
  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_cmds bash nonexistent_xyz'
  [[ "$status" -eq 2 ]]
}

# =============================================================================
# solen_require_root
# =============================================================================

@test "solen_require_root fails when not root" {
  # Skip if actually running as root
  [[ $EUID -ne 0 ]] || skip "Test must not run as root"

  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_root'
  [[ "$status" -eq 1 ]]
}

@test "solen_require_root reports error message" {
  [[ $EUID -ne 0 ]] || skip "Test must not run as root"

  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_root 2>&1'
  [[ "$output" == *"root"* ]]
}

# =============================================================================
# solen_require_file
# =============================================================================

@test "solen_require_file succeeds with existing file" {
  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_file "/etc/passwd"'
  [[ "$status" -eq 0 ]]
}

@test "solen_require_file fails with missing file" {
  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_file "/nonexistent/file/xyz"'
  [[ "$status" -eq 2 ]]
}

@test "solen_require_file reports file path" {
  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_file "/nonexistent/file/xyz" 2>&1'
  [[ "$output" == *"/nonexistent/file/xyz"* ]]
}

@test "solen_require_file includes description in error" {
  run bash -c 'source "$SOLEN_ROOT/Scripts/lib/solen.sh"; source "$SOLEN_ROOT/Scripts/lib/deps.sh"; solen_init_flags; solen_require_file "/nonexistent" "configuration file" 2>&1'
  [[ "$output" == *"configuration file"* ]]
}
