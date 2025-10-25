#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

pass=0
fail=0
skip=0

check_cmd() {
  local key="$1"; local expected_op="$2"
  set +e
  out=$(SOLEN_NO_TUI=1 SOLEN_PLAIN=1 TERM=dumb ./serverutils run "$key" -- --json 2>/dev/null)
  rc=$?
  set -e
  # Filter JSON lines only
  json_lines=$(printf '%s\n' "$out" | grep -E '^{"')
  if [[ "$key" == docker/* ]]; then
    # docker may be unavailable; accept rc=2 as skip
    if [[ $rc -eq 2 ]]; then
      echo "[SKIP] $key (docker not available)"
      skip=$((skip+1))
      return 0
    fi
  fi
  if [[ -z "$json_lines" ]]; then
    echo "[FAIL] $key: no JSON output"
    echo "$out"
    fail=$((fail+1))
    return 1
  fi
  # Validate first JSON line shape and op
  first=$(printf '%s\n' "$json_lines" | head -n1)
  # Basic envelope keys present
  echo "$first" | jq -e '(.status|type=="string") and (.summary|type=="string") and (.ts|type=="string") and (.host|type=="string") and ((has("details")) or (has("metrics")))' >/dev/null || {
    echo "[FAIL] $key: envelope keys missing or wrong types"; echo "$first"; fail=$((fail+1)); return 1; }
  # op: optional but if present, must match expected
  if echo "$first" | jq -e 'has("op")' >/dev/null; then
    opv=$(echo "$first" | jq -r '.op')
    if [[ "$opv" != "$expected_op" ]]; then
      echo "[FAIL] $key: op '$opv' != '$expected_op'"; fail=$((fail+1)); return 1
    fi
  fi
  # Exit code: accept 0 only (WARNs are ok with rc=0)
  if [[ $rc -ne 0 ]]; then
    echo "[FAIL] $key: exit code $rc"; fail=$((fail+1)); return 1
  fi
  # Per-script schema (optional): require at least one line to satisfy all expressions
  schema_path="docs/fixtures/${key}/schema.json"
  if [[ -f "$schema_path" ]]; then
    exprs=$(jq -cr '.expressions // []' "$schema_path")
    if [[ "$exprs" != "[]" ]]; then
      ok_line=0
      while IFS= read -r line; do
        all_ok=1
        while IFS= read -r expr; do
          jq -e "$expr" <<<"$line" >/dev/null 2>&1 || { all_ok=0; break; }
        done < <(jq -cr '.[]' <<<"$exprs")
        if [[ $all_ok -eq 1 ]]; then ok_line=1; break; fi
      done <<< "$json_lines"
      if [[ $ok_line -ne 1 ]]; then
        echo "[FAIL] $key: no JSON line satisfied schema expressions"
        fail=$((fail+1)); return 1
      fi
    fi
  fi
  echo "[OK] $key"
  pass=$((pass+1))
}

# Smoke commands
./serverutils banner >/dev/null 2>&1 || true
./serverutils list >/dev/null 2>&1

check_cmd inventory/host-info inventory
check_cmd health/check health
check_cmd network/network-info network
check_cmd security/baseline-check security
check_cmd docker/list-docker-info docker || true

echo "---"
echo "pass=$pass skip=$skip fail=$fail"
if [[ $fail -gt 0 ]]; then exit 1; else exit 0; fi
