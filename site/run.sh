#!/usr/bin/env bash
set -Eeuo pipefail

# SOLEN remote bootstrap (persistent install root)
# Usage:
#   bash <(curl -sL https://solen.shinni.dev/run.sh) [installer flags...]

BASE_URL="${SOLEN_BASE_URL:-https://solen.shinni.dev}"
RELEASE="${SOLEN_RELEASE:-latest}"
TARBALL_URL="${BASE_URL}/releases/solen-${RELEASE}.tar.gz"
CHECKSUM_URL="${TARBALL_URL}.sha256"

NO_VERIFY=0; SRC_URL=""; KEEP=0; SHOW_TUI=1

# parse bootstrap flags (unknowns are forwarded to installer)
BOOT_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) RELEASE="$2"; shift 2;;
    --source) SRC_URL="$2"; shift 2;;
    --no-verify) NO_VERIFY=1; shift;;
    --keep) KEEP=1; shift;;
    --no-tui) SHOW_TUI=0; shift;;
    --tui) SHOW_TUI=1; shift;;
    -h|--help)
      echo "usage: bash <(curl -sL ${BASE_URL}/run.sh) [--release vX.Y.Z|latest] [--source URL] [--no-verify] [--keep] -- [installer flags]"; exit 0;;
    --) shift; break;;
    *) BOOT_ARGS+=("$1"); shift;;
  esac
done
INSTALL_ARGS=("${BOOT_ARGS[@]}"); [[ $# -gt 0 ]] && INSTALL_ARGS+=("$@")

# Determine desired scope from forwarded flags (default: user)
SCOPE="user"
for a in "${INSTALL_ARGS[@]}"; do
  case "$a" in --global) SCOPE="global" ;; --user) SCOPE="user" ;; esac
done

# Default to enabling MOTD unless explicitly provided
has_with_motd=0
for a in "${INSTALL_ARGS[@]}"; do
  if [[ "$a" == "--with-motd" ]]; then has_with_motd=1; break; fi
done
if [[ $has_with_motd -eq 0 ]]; then
  INSTALL_ARGS+=("--with-motd")
fi

# Track whether --yes was supplied (for optional prompt)
HAS_YES=0
for a in "${INSTALL_ARGS[@]}"; do
  [[ "$a" == "--yes" ]] && HAS_YES=1
done

need(){ command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 2; }; }
need tar; command -v curl >/dev/null || command -v wget >/dev/null || { echo "need curl or wget" >&2; exit 2; }
command -v sha256sum >/dev/null || command -v shasum >/dev/null || { echo "need sha256sum or shasum" >&2; exit 2; }

[[ -n "$SRC_URL" ]] && TARBALL_URL="$SRC_URL" && CHECKSUM_URL=""

WORKDIR="$(mktemp -d -t solen.XXXXXX)"; cleanup(){ [[ $KEEP -eq 1 ]] || rm -rf "$WORKDIR"; }; trap cleanup EXIT INT TERM

TARBALL_PATH="${WORKDIR}/solen.tar.gz"
if command -v curl >/dev/null; then curl -fsSL "$TARBALL_URL" -o "$TARBALL_PATH"; else wget -qO "$TARBALL_PATH" "$TARBALL_URL"; fi

if [[ $NO_VERIFY -eq 0 && -n "$CHECKSUM_URL" ]]; then
  SUMFILE="${WORKDIR}/solen.sha256"
  if command -v curl >/dev/null; then curl -fsSL "$CHECKSUM_URL" -o "$SUMFILE"; else wget -qO "$SUMFILE" "$CHECKSUM_URL"; fi
  EXPECTED="$(awk '{print $1}' "$SUMFILE")"
  ACTUAL="$( (sha256sum "$TARBALL_PATH" 2>/dev/null || shasum -a 256 "$TARBALL_PATH") | awk '{print $1}')"
  [[ "$EXPECTED" == "$ACTUAL" ]] || { echo "checksum mismatch" >&2; exit 3; }
fi

EXTRACT_DIR="${WORKDIR}/solen"; mkdir -p "$EXTRACT_DIR"; tar -xzf "$TARBALL_PATH" -C "$EXTRACT_DIR"

# locate repo root in tarball
ROOT=""
if [[ -x "${EXTRACT_DIR}/serverutils" && -d "${EXTRACT_DIR}/Scripts" ]]; then ROOT="${EXTRACT_DIR}"; else ROOT="$(find "$EXTRACT_DIR" -maxdepth 2 -type f -name serverutils -printf '%h\n' | head -n1)"; fi
[[ -n "${ROOT}" && -x "$ROOT/serverutils" && -d "$ROOT/Scripts" ]] || { echo "invalid tarball layout" >&2; exit 4; }

# Copy to persistent install root so symlinks remain valid after cleanup
if [[ "$SCOPE" == "global" ]]; then
  PERSIST_BASE="/usr/local/share/solen"; PERSIST_DIR="${PERSIST_BASE}/${RELEASE}"
  echo "==> Preparing persistent install root (global): ${PERSIST_DIR}"
  sudo mkdir -p "$PERSIST_DIR"
  sudo rm -rf "${PERSIST_DIR:?}"/*
  sudo cp -a "$ROOT/." "$PERSIST_DIR/"
else
  PERSIST_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/solen"; PERSIST_DIR="${PERSIST_BASE}/${RELEASE}"
  echo "==> Preparing persistent install root (user): ${PERSIST_DIR}"
  mkdir -p "$PERSIST_DIR"
  rm -rf "${PERSIST_DIR:?}"/*
  cp -a "$ROOT/." "$PERSIST_DIR/"
fi

echo "==> Running installer (dry-run unless --yes provided)"
( cd "$PERSIST_DIR" && ./serverutils install "${INSTALL_ARGS[@]}" )

# If interactive and not disabled, launch TUI from the persistent root
if [[ $SHOW_TUI -eq 1 && -t 1 && "${SOLEN_NO_TUI:-0}" != "1" ]]; then
  ( cd "$PERSIST_DIR" && ./serverutils tui )
fi

# If interactive and user didn't pass --yes, offer to apply now
if [[ $HAS_YES -eq 0 && -t 0 && -t 1 ]]; then
  read -r -p "Apply installer changes now? [y/N]: " __ans || true
  if [[ "${__ans}" =~ ^[Yy]$ ]]; then
    echo "==> Applying installer changes (--yes)"
    ( cd "$PERSIST_DIR" && ./serverutils install "${INSTALL_ARGS[@]}" --yes )
  fi
fi
