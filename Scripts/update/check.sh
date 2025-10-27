#!/usr/bin/env bash

# SOLEN-META:
# name: update/check
# summary: Check remote channel manifest and cache latest version info (quiet)
# requires: bash,curl,jq
# tags: update,manifest
# verbs: info
# since: 0.3.0
# breaking: false
# outputs: status,summary,actions

set -Eeuo pipefail

BASE_URL="${SOLEN_BASE_URL:-https://solen.shinni.dev}"
CHANNEL="${SOLEN_CHANNEL:-stable}"
QUIET=0
JSON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel) CHANNEL="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--channel stable|rc|nightly] [--quiet] [--json]"; exit 0 ;;
    --) shift; break ;;
    *) shift ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 2; }; }
need curl; need jq

MAN_URL="${BASE_URL}/releases/manifest-${CHANNEL}.json"
CACHEDIR="${XDG_STATE_HOME:-$HOME/.local/state}/solen"
mkdir -p "$CACHEDIR"
CACHEFILE="${CACHEDIR}/update-cache.json"

tmp="$(mktemp)"
checked_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
if ! curl -fsSL --max-time 4 "$MAN_URL" -o "$tmp"; then
  [[ $QUIET -eq 1 ]] || echo "No update info (network)" >&2
  printf '{"version":"","channel":"%s","checked_at":"%s"}\n' "$CHANNEL" "$checked_at" > "$CACHEFILE.tmp" || true
  mv "$CACHEFILE.tmp" "$CACHEFILE" 2>/dev/null || true
  rm -f "$tmp"
  exit 0
fi

# Validate minimal shape
if ! jq -e '.version and .url and .sha256' "$tmp" >/dev/null 2>&1; then
  [[ $QUIET -eq 1 ]] || echo "Invalid manifest" >&2
  printf '{"version":"","channel":"%s","checked_at":"%s"}\n' "$CHANNEL" "$checked_at" > "$CACHEFILE.tmp" || true
  mv "$CACHEFILE.tmp" "$CACHEFILE" 2>/dev/null || true
  rm -f "$tmp"; exit 0
fi

jq --arg ch "$CHANNEL" --arg ts "$checked_at" \
  '.channel=$ch | .checked_at=$ts' "$tmp" > "$CACHEFILE.tmp" && mv "$CACHEFILE.tmp" "$CACHEFILE"
rm -f "$tmp"

if [[ $JSON -eq 1 ]]; then
  cat "$CACHEFILE"
else
  ver="$(jq -r '.version' "$CACHEFILE")"
  echo "cached latest ($CHANNEL): $ver"
fi
exit 0
