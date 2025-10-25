#!/usr/bin/env bash
# SOLEN remote bootstrap (auditable, verify-by-default)
# Usage:
#   bash <(curl -sL https://solen.shinni.dev/run.sh) [installer flags...]
# Examples:
#   bash <(curl -sL https://solen.shinni.dev/run.sh) --user --with-motd --yes
#   bash <(curl -sL https://solen.shinni.dev/run.sh) --global --with-motd --units system --yes
#   curl -sL https://solen.shinni.dev/run.sh | bash -s -- --user --with-motd --yes
set -Eeuo pipefail

### configurable defaults
BASE_URL="${SOLEN_BASE_URL:-https://solen.shinni.dev}"
RELEASE="${SOLEN_RELEASE:-latest}"          # "latest" or "v0.2.0"
TARBALL_NAME="solen-${RELEASE}.tar.gz"      # becomes "solen-latest.tar.gz" by default
TARBALL_URL="${BASE_URL}/releases/${TARBALL_NAME}"
CHECKSUM_URL="${TARBALL_URL}.sha256"        # contains "<sha256>  <filename>"

# flags for this bootstrap (not passed to installer)
NO_VERIFY=0
SRC_URL=""
KEEP=0

print_boot_usage() {
  cat <<EOF
SOLEN bootstrap
Fetches a release tarball, verifies SHA-256 (default), extracts locally, then runs:
  ./serverutils install [your flags...]

Bootstrap-only flags:
  --release <vX.Y.Z|latest>   Release to fetch (default: latest)
  --source <url>              Override tarball URL (skips BASE_URL layout)
  --no-verify                 Skip SHA256 verification (not recommended)
  --keep                      Keep the extracted directory (don't auto-clean)
  -h, --help                  Show this help

All other flags are forwarded to the installer unchanged, e.g.:
  --user|--global, --with-motd, --with-zsh, --with-starship,
  --copy-shell-assets, --units user|system, --uninstall, --uninstall-everything,
  --show-plan, --yes

Examples:
  bash <(curl -sL ${BASE_URL}/run.sh) --user --with-motd --yes
  bash <(curl -sL ${BASE_URL}/run.sh) --global --with-motd --units system --yes
EOF
}

# Parse bootstrap flags; leave unknowns for installer
BOOT_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) RELEASE="$2"; shift 2 ;;
    --source) SRC_URL="$2"; shift 2 ;;
    --no-verify) NO_VERIFY=1; shift ;;
    --keep) KEEP=1; shift ;;
    -h|--help) print_boot_usage; exit 0 ;;
    --) shift; break ;;
    *) BOOT_ARGS+=("$1"); shift ;;
  esac
done
# anything after -- is forwarded untouched
INSTALL_ARGS=("${BOOT_ARGS[@]}")
if [[ $# -gt 0 ]]; then
  INSTALL_ARGS+=("$@")
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1" >&2; exit 2; }; }
need uname
if command -v curl >/dev/null 2>&1; then FETCH="curl -fsSL"; elif command -v wget >/dev/null 2>&1; then FETCH="wget -qO-"; else
  echo "Need curl or wget" >&2; exit 2
fi
need tar
need sha256sum || need shasum

# resolve URLs
if [[ -n "$SRC_URL" ]]; then
  TARBALL_URL="$SRC_URL"
  CHECKSUM_URL=""
else
  TARBALL_NAME="solen-${RELEASE}.tar.gz"
  TARBALL_URL="${BASE_URL}/releases/${TARBALL_NAME}"
  CHECKSUM_URL="${TARBALL_URL}.sha256"
fi

echo "==> SOLEN bootstrap"
echo "    tarball : $TARBALL_URL"
[[ $NO_VERIFY -eq 0 && -n "$CHECKSUM_URL" ]] && echo "    checksum: $CHECKSUM_URL (will verify)" || echo "    checksum: (skipped)"
echo "    install : ./serverutils install ${INSTALL_ARGS[*]:-}"

# temp workdir
WORKDIR="$(mktemp -d -t solen.XXXXXX)"
cleanup() { [[ $KEEP -eq 1 ]] || rm -rf "$WORKDIR"; }
trap cleanup EXIT INT TERM

TARBALL_PATH="${WORKDIR}/solen.tar.gz"
echo "==> Downloading tarball..."
if [[ "$FETCH" == curl* ]]; then
  curl -fsSL "$TARBALL_URL" -o "$TARBALL_PATH"
else
  wget -qO "$TARBALL_PATH" "$TARBALL_URL"
fi

if [[ $NO_VERIFY -eq 0 && -n "$CHECKSUM_URL" ]]; then
  echo "==> Verifying SHA-256..."
  SUMFILE="${WORKDIR}/solen.sha256"
  if [[ "$FETCH" == curl* ]]; then
    curl -fsSL "$CHECKSUM_URL" -o "$SUMFILE"
  else
    wget -qO "$SUMFILE" "$CHECKSUM_URL"
  fi
  # normalize expected format "<sha256>  <filename>"
  EXPECTED="$(awk '{print $1}' "$SUMFILE")"
  ACTUAL="$(sha256sum "$TARBALL_PATH" 2>/dev/null | awk '{print $1}')"
  if [[ -z "$ACTUAL" ]]; then ACTUAL="$(shasum -a 256 "$TARBALL_PATH" | awk '{print $1}')"; fi
  if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    echo "Checksum mismatch!" >&2
    echo "  expected: $EXPECTED" >&2
    echo "  actual  : $ACTUAL" >&2
    exit 3
  fi
  echo "    OK"
fi

echo "==> Extracting..."
EXTRACT_DIR="${WORKDIR}/solen"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$TARBALL_PATH" -C "$EXTRACT_DIR"

# find repo root (supports tarballs that contain a top-level folder or flat)
if [[ -x "${EXTRACT_DIR}/serverutils" && -d "${EXTRACT_DIR}/Scripts" ]]; then
  ROOT="${EXTRACT_DIR}"
else
  ROOT="$(find "$EXTRACT_DIR" -maxdepth 2 -type f -name serverutils -printf '%h\n' | head -n1 || true)"
fi
[[ -n "$ROOT" && -x "$ROOT/serverutils" && -d "$ROOT/Scripts" ]] || { echo "Invalid tarball layout (serverutils/Scripts not found)" >&2; exit 4; }

echo "==> Running installer (dry-run unless --yes provided)..."
# Give installer a stable root (the updated serverutils also follows symlinks)
(
  cd "$ROOT"
  # Pass through whatever flags the user specified
  ./serverutils install "${INSTALL_ARGS[@]}"
)

echo "==> Done."
echo "    To uninstall per-user:   serverutils install --uninstall --user --yes"
echo "    To uninstall systemwide: sudo serverutils install --uninstall --global --yes"
