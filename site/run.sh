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

# Determine desired scope from forwarded flags (default: user) and ensure flag is passed through
SCOPE="user"; HAVE_SCOPE_FLAG=0
for a in "${INSTALL_ARGS[@]}"; do
  case "$a" in --global) SCOPE="global"; HAVE_SCOPE_FLAG=1 ;; --user) SCOPE="user"; HAVE_SCOPE_FLAG=1 ;; esac
done
if [[ $HAVE_SCOPE_FLAG -eq 0 ]]; then
  INSTALL_ARGS+=("--${SCOPE}")
fi

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

ensure_min_libs() {
  local libdir="$1/Scripts/lib"
  mkdir -p "$libdir"
  # Only write files if missing (do not overwrite if present)
  if [[ ! -f "$libdir/solen.sh" ]]; then
    cat > "$libdir/solen.sh" <<'LIB'
#!/usr/bin/env bash
solen_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
solen_host() { hostname 2>/dev/null || uname -n; }
solen_init_flags() { : "${SOLEN_FLAG_YES:=0}"; : "${SOLEN_FLAG_JSON:=${SOLEN_JSON:-0}}"; : "${SOLEN_FLAG_DRYRUN:=1}"; [ "$SOLEN_FLAG_YES" = 1 ] && SOLEN_FLAG_DRYRUN=0 || true; }
solen_parse_common_flag() { case "$1" in --yes|-y) SOLEN_FLAG_YES=1; SOLEN_FLAG_DRYRUN=0; return 0;; --dry-run) SOLEN_FLAG_DRYRUN=1; return 0;; --json) SOLEN_FLAG_JSON=1; return 0;; esac; return 1; }
solen_info() { echo -e "\033[0;36mℹ️  $*\033[0m"; }
solen_ok()   { echo -e "\033[0;32m✅ $*\033[0m"; }
solen_warn() { echo -e "\033[0;33m⚠️  $*\033[0m"; }
solen_err()  { echo -e "\033[0;31m❌ $*\033[0m" 1>&2; }
solen_json_record() {
  local status="$1" summary="$2" actions_text="${3:-}" extra="${4:-}" host; host=$(hostname 2>/dev/null || uname -n)
  _esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
  local actions_json="[]"; if [ -n "$actions_text" ]; then actions_json="["; local first=1; while IFS= read -r l; do [ -z "$l" ] && continue; local e; e="$(_esc "$l")"; [ $first -eq 0 ] && actions_json+=" ," || first=0; actions_json+="\"$e\""; done <<EOF
${actions_text}
EOF
  actions_json+="]"; fi
  printf '{"status":"%s","summary":"%s","ts":"%s","host":"%s","actions":%s%s}\n' \
    "$(_esc "$status")" "$(_esc "$summary")" "$(solen_ts)" "$(_esc "$host")" "$actions_json" "${extra:+,${extra}}"
}
LIB
    chmod +x "$libdir/solen.sh" || true
  fi
  if [[ ! -f "$libdir/edit.sh" ]]; then
    cat > "$libdir/edit.sh" <<'LIB'
#!/usr/bin/env bash
solen_insert_marker_block() {
  local file="$1" begin="$2" end="$3" content="$4" tmp
  mkdir -p "$(dirname "$file")" 2>/dev/null || true; touch "$file"
  tmp="${file}.tmp.$$"; awk -v b="$begin" -v e="$end" 'BEGIN{inblk=0} index($0,b)==1{inblk=1;next} index($0,e)==1{inblk=0;next} !inblk{print $0}' "$file" > "$tmp" && mv "$tmp" "$file"
  tail -c1 "$file" >/dev/null 2>&1 || echo >> "$file"
  { echo "$begin"; printf "%s\n" "$content"; echo "$end"; } >> "$file"
}
solen_remove_marker_block() {
  local file="$1" begin="$2" end="$3" tmp; [ -f "$file" ] || return 0
  tmp="${file}.tmp.$$"; awk -v b="$begin" -v e="$end" 'BEGIN{inblk=0} index($0,b)==1{inblk=1;next} index($0,e)==1{inblk=0;next} !inblk{print $0}' "$file" > "$tmp" && mv "$tmp" "$file"
}
LIB
    chmod +x "$libdir/edit.sh" || true
  fi
  if [[ ! -f "$libdir/pm.sh" ]]; then
    cat > "$libdir/pm.sh" <<'LIB'
#!/usr/bin/env bash
__SOLEN_PM="unknown"
pm_detect() { if command -v apt-get >/dev/null 2>&1; then __SOLEN_PM=apt; elif command -v dnf >/dev/null 2>&1; then __SOLEN_PM=dnf; elif command -v pacman >/dev/null 2>&1; then __SOLEN_PM=pacman; elif command -v zypper >/dev/null 2>&1; then __SOLEN_PM=zypper; else __SOLEN_PM=unknown; fi; }
pm_name() { echo "$__SOLEN_PM"; }
pm_update_plan() { case "$__SOLEN_PM" in apt) echo "sudo apt-get update -y";; dnf) echo "sudo dnf -y makecache";; pacman) echo "sudo pacman -Sy --noconfirm";; zypper) echo "sudo zypper -n refresh";; *) echo "# pm update (unsupported)";; esac; }
pm_install_plan() { case "$__SOLEN_PM" in apt) echo "sudo apt-get install -y $*";; dnf) echo "sudo dnf -y install $*";; pacman) echo "sudo pacman -S --noconfirm $*";; zypper) echo "sudo zypper -n install $*";; *) echo "# pm install $* (unsupported)";; esac; }
pm_check_updates_count() { case "$__SOLEN_PM" in apt) (apt-get -s upgrade 2>/dev/null | awk '/^Inst /{c++} END{print c+0}') || echo 0 ;; dnf) (dnf -q check-update 2>/dev/null | awk 'END{print NR+0}') || echo 0 ;; pacman) (checkupdates 2>/dev/null | wc -l | tr -d ' ') || echo 0 ;; zypper) (zypper -q list-updates 2>/dev/null | awk 'NR>2{c++} END{print c+0}') || echo 0 ;; *) echo 0 ;; esac; }
LIB
    chmod +x "$libdir/pm.sh" || true
  fi
}

# Ensure libs exist before running installer or update checks
ensure_min_libs "$PERSIST_DIR"

echo "==> Running installer (dry-run unless --yes provided)"
( cd "$PERSIST_DIR" && ./serverutils install "${INSTALL_ARGS[@]}" )

# Prime update cache quietly (non-fatal)
if command -v jq >/dev/null 2>&1; then
  ( cd "$PERSIST_DIR" && Scripts/update/check.sh --quiet || true )
fi

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
