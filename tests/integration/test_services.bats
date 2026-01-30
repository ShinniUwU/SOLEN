#!/usr/bin/env bats
# Integration tests for services/ensure.sh

setup() {
  load '../setup.bash'
}

# =============================================================================
# Basic Execution
# =============================================================================

@test "services/ensure shows usage without arguments" {
  run "$SOLEN_ROOT/Scripts/services/ensure.sh"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "services/ensure --help shows usage" {
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "services/ensure requires --unit flag" {
  skip_unless_systemd
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# Unit Name Validation
# =============================================================================

@test "services/ensure rejects invalid unit name with semicolon" {
  skip_unless_systemd
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit "foo;bar"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Invalid unit name"* ]]
}

@test "services/ensure rejects invalid unit name with space" {
  skip_unless_systemd
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit "foo bar"
  [[ "$status" -eq 1 ]]
}

@test "services/ensure rejects invalid unit name with slash" {
  skip_unless_systemd
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit "foo/bar"
  [[ "$status" -eq 1 ]]
}

@test "services/ensure accepts valid unit name with dash" {
  skip_unless_systemd
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit "my-service"
  # May fail for other reasons but not validation
  [[ "$output" != *"Invalid unit name"* ]]
}

@test "services/ensure accepts valid unit name with underscore" {
  skip_unless_systemd
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit "my_service"
  [[ "$output" != *"Invalid unit name"* ]]
}

@test "services/ensure accepts valid unit name with dot" {
  skip_unless_systemd
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit "my.service"
  [[ "$output" != *"Invalid unit name"* ]]
}

@test "services/ensure accepts valid unit name with @" {
  skip_unless_systemd
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit "my@instance"
  [[ "$output" != *"Invalid unit name"* ]]
}

# =============================================================================
# Status Command
# =============================================================================

@test "services/ensure status works for existing service" {
  skip_unless_systemd
  # cron or crond should exist on most systems
  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit cron
  if [[ "$status" -ne 0 ]]; then
    run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit crond
  fi
  # At least one should work or we're on a non-standard system
  [[ "$status" -eq 0 ]] || skip "Neither cron nor crond service found"
}

@test "services/ensure status --json produces valid JSON" {
  skip_unless_systemd
  skip_unless_command jq

  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit cron --json
  if [[ "$status" -ne 0 ]]; then
    run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit crond --json
  fi
  [[ "$status" -eq 0 ]] || skip "No suitable service found"
  echo "$output" | jq -e . >/dev/null
}

@test "services/ensure status --json has metrics" {
  skip_unless_systemd
  skip_unless_command jq

  run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit cron --json
  if [[ "$status" -ne 0 ]]; then
    run "$SOLEN_ROOT/Scripts/services/ensure.sh" status --unit crond --json
  fi
  [[ "$status" -eq 0 ]] || skip "No suitable service found"

  active=$(echo "$output" | jq -e '.metrics.active')
  enabled=$(echo "$output" | jq -e '.metrics.enabled')
  [[ "$active" == "true" ]] || [[ "$active" == "false" ]]
  [[ "$enabled" == "true" ]] || [[ "$enabled" == "false" ]]
}

# =============================================================================
# Non-systemd Graceful Degradation
# =============================================================================

@test "services/ensure exits gracefully on non-systemd" {
  # This test verifies the script handles missing systemctl gracefully
  # We can't easily test this on a systemd system without mocking
  skip "Cannot test non-systemd behavior on systemd system"
}

# =============================================================================
# Dry-run Mode
# =============================================================================

@test "services/ensure ensure-enabled --dry-run does not modify system" {
  skip_unless_systemd

  run "$SOLEN_ROOT/Scripts/services/ensure.sh" ensure-enabled --unit cron --dry-run
  if [[ "$status" -ne 0 ]]; then
    run "$SOLEN_ROOT/Scripts/services/ensure.sh" ensure-enabled --unit crond --dry-run
  fi

  # Should succeed without actually enabling anything
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"already enabled"* ]] || [[ "$output" == *"dry-run"* ]] || [[ "$output" == *"would enable"* ]]
}
