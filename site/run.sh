#!/usr/bin/env bash
set -Eeuo pipefail
BASE_URL="${SOLEN_BASE_URL:-https://solen.shinni.dev}"
RELEASE="${SOLEN_RELEASE:-latest}"
TARBALL_URL="${BASE_URL}/releases/solen-${RELEASE}.tar.gz"
CHECKSUM_URL="${TARBALL_URL}.sha256"
NO_VERIFY=0; SRC_URL=""; KEEP=0
# parse bootstrap flags
BOOT_ARGS=(); while [[ $# -gt 0 ]]; do case "$1" in
  --release) RELEASE="$2"; shift 2;;
  --source) SRC_URL="$2"; shift 2;;
  --no-verify) NO_VERIFY=1; shift;;
  --keep) KEEP=1; shift;;
  -h|--help) echo "usage: bash <(curl -sL ${BASE_URL}/run.sh) [installer flags]"; exit 0;;
  --) shift; break;;
  *) BOOT_ARGS+=("$1"); shift;;
esac; done
INSTALL_ARGS=("${BOOT_ARGS[@]}"); [[ $# -gt 0 ]] && INSTALL_ARGS+=("$@")
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
ROOT="$(find "$EXTRACT_DIR" -maxdepth 2 -type f -name serverutils -printf '%h\n' | head -n1)"
[[ -x "$ROOT/serverutils" && -d "$ROOT/Scripts" ]] || { echo "invalid tarball layout" >&2; exit 4; }
( cd "$ROOT" && ./serverutils install "${INSTALL_ARGS[@]}" )
