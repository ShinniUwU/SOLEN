#!/usr/bin/env bash

# SOLEN-META:
# name: health/check
# summary: Fast health checks with rollup (scaffold)
# requires: df,awk
# tags: health,monitoring
# verbs: check
# since: 0.1.0
# breaking: false
# outputs: status, summary, metrics
# root: false

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run] [--json]

Performs fast health checks. This is a scaffold with placeholder metrics.
EOF
}

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in -h|--help) usage; exit 0 ;; --) shift; break ;; -*) echo "unknown option: $1" >&2; usage; exit 1 ;; *) break;; esac
done

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  # Rollup with placeholder metrics
  solen_json_record ok "health OK: disk 0%, load 0/core, services green" "" "\"disk_root_pct\":0,\"load15_per_core\":0,\"mem_pressure_pct\":0,\"unhealthy_containers\":0,\"failed_services\":0"
else
  solen_ok "health OK: disk 0%, load 0/core, services green"
fi
exit 0

