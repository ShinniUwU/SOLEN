#!/usr/bin/env bash

# SOLEN-META:
# name: update/apply
# summary: Download and atomically apply an update from the selected channel
# requires: bash,curl,jq,tar
# tags: update,install,rollback
# verbs: install
# since: 0.3.0
# breaking: false

set -Eeuo pipefail

BASE_URL="${SOLEN_BASE_URL:-https://solen.shinni.dev}"
CHANNEL="${SOLEN_CHANNEL:-stable}"
YES=0
ROLLBACK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel) CHANNEL="$2"; shift 2 ;;
    --yes|-y) YES=1; shift ;;
    --rollback) ROLLBACK=1; shift ;;
    -h|--help)
      cat << EOF
Usage: $(basename "$0") [--channel stable|rc|nightly] [--yes] [--rollback]

Applies the latest update for the selected channel after verifying checksum.
Atomically swaps the persistent install and keeps a backup for rollback.
EOF
      exit 0 ;;
    --) shift; break ;;
    *) shift ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 2; }; }
need curl; need jq; need tar; command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || { echo "Need sha256 tool" >&2; exit 2; }
if command -v openssl >/dev/null 2>&1; then OPENSSL=openssl; else OPENSSL=""; fi

persist_base="${XDG_DATA_HOME:-$HOME/.local/share}/solen"
mkdir -p "$persist_base"
latest_dir="$persist_base/latest"

if [[ $ROLLBACK -eq 1 ]]; then
  # Rollback to previous snapshot if present
  if [[ -d "$persist_base/latest-prev" ]]; then
    ts="$(date -u +%s)"
    mv "$latest_dir" "$persist_base/latest-failed-$ts" || true
    mv "$persist_base/latest-prev" "$latest_dir"
    echo "Rolled back to previous version"
    exit 0
  else
    echo "No previous snapshot to rollback" >&2; exit 1
  fi
fi

manifest_url="${BASE_URL}/releases/manifest-${CHANNEL}.json"
tmp_manifest="$(mktemp)"
if ! curl -fsSL --max-time 6 "$manifest_url" -o "$tmp_manifest"; then
  echo "Cannot fetch manifest" >&2; exit 3
fi

version="$(jq -r '.version' "$tmp_manifest")"
url="$(jq -r '.url' "$tmp_manifest")"
sha="$(jq -r '.sha256' "$tmp_manifest")"
breaking="$(jq -r '.breaking // false' "$tmp_manifest")"
sig_algo="$(jq -r '.sig_algo // empty' "$tmp_manifest")"
sig_b64="$(jq -r '.sig_b64 // empty' "$tmp_manifest")"
date_iso="$(jq -r '.date // empty' "$tmp_manifest")"
[[ -n "$version" && -n "$url" && -n "$sha" ]] || { echo "Invalid manifest" >&2; exit 3; }

echo "Plan: update to $version ($CHANNEL)${breaking:+, breaking=$breaking}"
if [[ $YES -ne 1 ]]; then
  echo "Dry-run (use --yes to apply)"; rm -f "$tmp_manifest"; exit 0
fi

work="$(mktemp -d -t solen.up.XXXXXX)"
trap 'rm -rf "$work"' EXIT INT TERM
tarball="$work/solen.tar.gz"

curl -fsSL "$url" -o "$tarball"
# Optional manifest signature verification
if [[ -n "$sig_b64" ]]; then
  if [[ -n "${SOLEN_SIGN_PUBKEY_PEM:-}" && -n "$OPENSSL" ]]; then
    sig_file="$work/manifest.sig"; printf '%s' "$sig_b64" | base64 -d > "$sig_file"
    data_str="${version}|${sha}|${url}|${date_iso}|${CHANNEL}"
    if ! printf '%s' "$data_str" | $OPENSSL dgst -sha256 -verify <(printf '%s' "$SOLEN_SIGN_PUBKEY_PEM") -signature "$sig_file" >/dev/null 2>&1; then
      echo "Manifest signature verification failed" >&2; exit 4
    fi
  elif [[ "${SOLEN_REQUIRE_SIGNATURE:-0}" = "1" ]]; then
    echo "Signature required but verification not possible (missing pubkey or openssl)" >&2; exit 4
  fi
fi
actual="$(sha256sum "$tarball" 2>/dev/null | awk '{print $1}')"
if [[ -z "$actual" ]]; then actual="$(shasum -a 256 "$tarball" | awk '{print $1}')"; fi
if [[ "$actual" != "$sha" ]]; then
  echo "Checksum mismatch" >&2
  echo " expected: $sha" >&2
  echo "   actual: $actual" >&2
  exit 4
fi

stage="$work/stage"
mkdir -p "$stage"
tar -xzf "$tarball" -C "$stage"

# If tarball contains a top-level folder, descend one level
if [[ -x "$stage/serverutils" && -d "$stage/Scripts" ]]; then
  newroot="$stage"
else
  newroot="$(find "$stage" -maxdepth 2 -type f -name serverutils -printf '%h\n' | head -n1)"
fi
[[ -n "$newroot" ]] || { echo "Invalid tar layout" >&2; exit 5; }

# Atomically swap persistent root; keep previous for rollback
ts="$(date -u +%s)"
backup="$persist_base/latest-prev"
rm -rf "$backup" || true
if [[ -d "$latest_dir" ]]; then
  mv "$latest_dir" "$backup"
fi
mkdir -p "$latest_dir"
cp -a "$newroot/." "$latest_dir/"

echo "Applied $version to $latest_dir (backup at $backup)"
rm -f "$tmp_manifest"
exit 0
