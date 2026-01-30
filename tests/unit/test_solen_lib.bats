#!/usr/bin/env bats
# Unit tests for Scripts/lib/solen.sh

setup() {
  load '../setup.bash'
  load_solen_lib
}

# =============================================================================
# Timestamp and Host Functions
# =============================================================================

@test "solen_ts returns valid ISO 8601 timestamp" {
  result=$(solen_ts)
  # Format: YYYY-MM-DDTHH:MM:SSZ
  [[ "$result" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "solen_host returns non-empty hostname" {
  result=$(solen_host)
  [[ -n "$result" ]]
}

@test "solen_host matches system hostname" {
  result=$(solen_host)
  expected=$(hostname 2>/dev/null || uname -n)
  [[ "$result" == "$expected" ]]
}

# =============================================================================
# Flag Initialization
# =============================================================================

@test "solen_init_flags sets SOLEN_FLAG_YES to 0" {
  unset SOLEN_FLAG_YES
  solen_init_flags
  [[ "$SOLEN_FLAG_YES" == "0" ]]
}

@test "solen_init_flags sets SOLEN_FLAG_JSON to 0" {
  unset SOLEN_FLAG_JSON
  solen_init_flags
  [[ "$SOLEN_FLAG_JSON" == "0" ]]
}

@test "solen_init_flags sets SOLEN_FLAG_DRYRUN to 1 by default" {
  unset SOLEN_FLAG_DRYRUN SOLEN_FLAG_YES
  solen_init_flags
  [[ "$SOLEN_FLAG_DRYRUN" == "1" ]]
}

@test "solen_init_flags respects existing SOLEN_FLAG_YES=1" {
  SOLEN_FLAG_YES=1
  solen_init_flags
  [[ "$SOLEN_FLAG_DRYRUN" == "0" ]]
}

# =============================================================================
# Flag Parsing
# =============================================================================

@test "solen_parse_common_flag handles --json" {
  solen_init_flags
  solen_parse_common_flag "--json"
  [[ "$SOLEN_FLAG_JSON" == "1" ]]
}

@test "solen_parse_common_flag handles --yes" {
  solen_init_flags
  solen_parse_common_flag "--yes"
  [[ "$SOLEN_FLAG_YES" == "1" ]]
  [[ "$SOLEN_FLAG_DRYRUN" == "0" ]]
}

@test "solen_parse_common_flag handles -y" {
  solen_init_flags
  solen_parse_common_flag "-y"
  [[ "$SOLEN_FLAG_YES" == "1" ]]
  [[ "$SOLEN_FLAG_DRYRUN" == "0" ]]
}

@test "solen_parse_common_flag handles --dry-run" {
  solen_init_flags
  SOLEN_FLAG_DRYRUN=0
  solen_parse_common_flag "--dry-run"
  [[ "$SOLEN_FLAG_DRYRUN" == "1" ]]
}

@test "solen_parse_common_flag returns 1 for unknown flag" {
  solen_init_flags
  run solen_parse_common_flag "--unknown"
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# JSON Escaping
# =============================================================================

@test "solen_json_escape handles plain text" {
  result=$(solen_json_escape "hello world")
  [[ "$result" == "hello world" ]]
}

@test "solen_json_escape escapes quotes" {
  result=$(solen_json_escape 'hello "world"')
  [[ "$result" == 'hello \"world\"' ]]
}

@test "solen_json_escape escapes backslashes" {
  result=$(solen_json_escape 'path\to\file')
  [[ "$result" == 'path\\to\\file' ]]
}

@test "solen_json_escape handles mixed escapes" {
  result=$(solen_json_escape 'say "hello\nworld"')
  [[ "$result" == 'say \"hello\\nworld\"' ]]
}

# =============================================================================
# JSON Record Generation
# =============================================================================

@test "solen_json_record produces valid JSON" {
  skip_unless_command jq
  result=$(solen_json_record "ok" "test summary" "" "")
  echo "$result" | jq -e . >/dev/null
}

@test "solen_json_record includes status field" {
  skip_unless_command jq
  result=$(solen_json_record "ok" "test summary" "" "")
  status_val=$(echo "$result" | jq -r '.status')
  [[ "$status_val" == "ok" ]]
}

@test "solen_json_record includes summary field" {
  skip_unless_command jq
  result=$(solen_json_record "ok" "my summary" "" "")
  summary=$(echo "$result" | jq -r '.summary')
  [[ "$summary" == "my summary" ]]
}

@test "solen_json_record includes timestamp" {
  skip_unless_command jq
  result=$(solen_json_record "ok" "test" "" "")
  ts=$(echo "$result" | jq -r '.ts')
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

@test "solen_json_record includes host" {
  skip_unless_command jq
  result=$(solen_json_record "ok" "test" "" "")
  host=$(echo "$result" | jq -r '.host')
  [[ -n "$host" ]]
}

@test "solen_json_record includes empty actions array by default" {
  skip_unless_command jq
  result=$(solen_json_record "ok" "test" "" "")
  actions=$(echo "$result" | jq -c '.actions')
  [[ "$actions" == "[]" ]]
}

@test "solen_json_record converts actions text to array" {
  skip_unless_command jq
  result=$(solen_json_record "ok" "test" $'action1\naction2' "")
  actions=$(echo "$result" | jq -c '.actions')
  [[ "$actions" == '["action1","action2"]' ]]
}

@test "solen_json_record includes extra fields" {
  skip_unless_command jq
  result=$(solen_json_record "ok" "test" "" '"extra_field":"value"')
  extra=$(echo "$result" | jq -r '.extra_field')
  [[ "$extra" == "value" ]]
}

# =============================================================================
# Message Functions (output only - just verify they don't error)
# =============================================================================

@test "solen_info runs without error" {
  run solen_info "test message"
  [[ "$status" -eq 0 ]]
}

@test "solen_ok runs without error" {
  run solen_ok "test message"
  [[ "$status" -eq 0 ]]
}

@test "solen_warn runs without error" {
  run solen_warn "test message"
  [[ "$status" -eq 0 ]]
}

@test "solen_err runs without error" {
  run solen_err "test message"
  [[ "$status" -eq 0 ]]
}

@test "solen_head runs without error" {
  run solen_head "Section"
  [[ "$status" -eq 0 ]]
}
