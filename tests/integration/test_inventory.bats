#!/usr/bin/env bats
# Integration tests for inventory/host-info.sh

setup() {
  load '../setup.bash'
}

# =============================================================================
# Basic Execution
# =============================================================================

@test "inventory/host-info runs without error" {
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh"
  [[ "$status" -eq 0 ]]
}

@test "inventory/host-info --help shows usage" {
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

# =============================================================================
# JSON Output
# =============================================================================

@test "inventory/host-info --json produces valid JSON" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | jq -e . >/dev/null
}

@test "inventory/host-info --json has status field" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  status_val=$(echo "$output" | jq -r '.status')
  [[ "$status_val" == "ok" ]]
}

@test "inventory/host-info --json has summary field" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  summary=$(echo "$output" | jq -r '.summary')
  [[ -n "$summary" ]]
}

@test "inventory/host-info --json has metrics object" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  metrics=$(echo "$output" | jq -e '.metrics')
  [[ -n "$metrics" ]]
}

@test "inventory/host-info --json metrics has cores" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  cores=$(echo "$output" | jq -r '.metrics.cores')
  [[ "$cores" =~ ^[0-9]+$ ]]
  [[ "$cores" -ge 1 ]]
}

@test "inventory/host-info --json metrics has mem_total_mi" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  mem=$(echo "$output" | jq -r '.metrics.mem_total_mi')
  [[ "$mem" =~ ^[0-9]+$ ]]
  [[ "$mem" -gt 0 ]]
}

@test "inventory/host-info --json metrics has disk_root_used_pct" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  disk=$(echo "$output" | jq -r '.metrics.disk_root_used_pct')
  [[ "$disk" =~ ^[0-9]+$ ]]
  [[ "$disk" -ge 0 ]] && [[ "$disk" -le 100 ]]
}

@test "inventory/host-info --json has details object" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  details=$(echo "$output" | jq -e '.details')
  [[ -n "$details" ]]
}

@test "inventory/host-info --json details has os" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  os=$(echo "$output" | jq -r '.details.os')
  [[ -n "$os" ]]
}

@test "inventory/host-info --json details has kernel" {
  skip_unless_command jq
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh" --json
  kernel=$(echo "$output" | jq -r '.details.kernel')
  [[ -n "$kernel" ]]
}

# =============================================================================
# Human-Readable Output
# =============================================================================

@test "inventory/host-info shows Host section" {
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh"
  [[ "$output" == *"Host"* ]]
}

@test "inventory/host-info shows CPU/Mem section" {
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh"
  [[ "$output" == *"CPU"* ]] || [[ "$output" == *"Mem"* ]]
}

@test "inventory/host-info shows Disks section" {
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh"
  [[ "$output" == *"Disk"* ]]
}

@test "inventory/host-info shows Network section" {
  run "$SOLEN_ROOT/Scripts/inventory/host-info.sh"
  [[ "$output" == *"Network"* ]]
}
