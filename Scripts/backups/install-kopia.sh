#!/usr/bin/env bash

# SOLEN-META:
# name: backups/install-kopia
# summary: Install Kopia CLI via apt/dnf or download static binary
# requires: curl,tar,sudo
# tags: backup,kopia,install
# verbs: install
# since: 0.2.0
# breaking: false
# outputs: status, summary, actions
# root: false (uses sudo for system install)

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $(basename "$0") [--method auto|apt|dnf|binary] [--dest <bindir>] [--version <v>] [--dry-run] [--json] [--yes]

Install Kopia CLI:
  - auto (default): apt on Debian/Ubuntu; dnf on Fedora/RHEL; else binary download
  - apt/dnf: install package via system manager
  - binary: download release tarball and install kopia to dest (default: /usr/local/bin or ~/.local/bin)

Environment:
  KOPIA_VERSION     Version tag (e.g., v0.17.0). If not set, latest is used for binary method.

Safety:
  - Dry-run by default if --yes not provided.
EOF
}

method="auto"
dest=""
version="${KOPIA_VERSION:-}"

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --method) method="${2:-auto}"; shift 2 ;;
    --dest) dest="${2:-}"; shift 2 ;;
    --version) version="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) solen_err "unknown option: $1"; usage; exit 1 ;;
    *) break ;;
  esac
done

pick_method() {
  case "$method" in
    apt|dnf|binary) echo "$method" ; return ;;
    auto)
      if command -v apt >/dev/null 2>&1; then echo apt; return; fi
      if command -v dnf >/dev/null 2>&1; then echo dnf; return; fi
      echo binary; return ;;
    *) echo binary ;;
  esac
}

chosen="$(pick_method)"

# Destination selection for binary install
if [[ -z "$dest" ]]; then
  if [[ ${EUID:-$(id -u 2>/dev/null || echo 1000)} -eq 0 ]]; then dest="/usr/local/bin"; else dest="${HOME}/.local/bin"; fi
fi

arch() {
  uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/; s/armv7l/arm/; s/armv6l/arm/; s/i386/386/; s/i686/386/'
}

latest_version_cmd='curl -fsSL https://api.github.com/repos/kopia/kopia/releases/latest | sed -n "s/^  \"tag_name\": \"\\(.*\\)\",$/\1/p"'
if [[ -z "$version" && "$chosen" == "binary" ]]; then
  version_cmd="$latest_version_cmd"
  version_line=$(bash -c "$version_cmd" 2>/dev/null || true)
  if [[ -n "$version_line" ]]; then version="$version_line"; fi
fi
[[ -n "$version" ]] || version="v0.17.0"

tarname="kopia-${version#v}-linux-$(arch).tar.gz"
url="https://github.com/kopia/kopia/releases/download/${version}/${tarname}"

actions=""
case "$chosen" in
  apt)
    actions+=$'sudo apt update\n'
    actions+=$'sudo apt install -y kopia\n'
    ;;
  dnf)
    actions+=$'sudo dnf -y install kopia\n'
    ;;
  binary)
    actions+=$"mkdir -p \"$dest\"\n"
    actions+=$"curl -fsSL -o /tmp/${tarname} \"${url}\"\n"
    actions+=$"tar -C /tmp -xzf /tmp/${tarname}\n"
    actions+=$"install -m 0755 /tmp/kopia-${version#v}-linux-$(arch)/kopia \"$dest/kopia\"\n"
    actions+=$"rm -rf /tmp/${tarname} /tmp/kopia-${version#v}-linux-$(arch)\n"
    ;;
esac

summary="install kopia via ${chosen} (to ${dest})"

if [[ $SOLEN_FLAG_DRYRUN -eq 1 || $SOLEN_FLAG_YES -eq 0 ]]; then
  if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
    solen_json_record ok "dry-run: $summary" "$actions" "\"would_change\":1"
  else
    solen_info "dry-run enforced (use --yes to apply)"
    printf '%s' "$actions"
  fi
  exit 0
fi

changed=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ "$line" == \#* ]]; then continue; fi
  solen_info "$line"
  set +e
  bash -c "$line"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then changed=$((changed+1)); else solen_warn "step failed (rc=$rc): $line"; fi
done <<< "$actions"

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "$summary" "$actions" "\"changed\":${changed}"
else
  solen_ok "$summary (changed=${changed})"
fi
exit 0

