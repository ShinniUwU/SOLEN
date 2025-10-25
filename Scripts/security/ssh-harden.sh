#!/usr/bin/env bash

# SOLEN-META:
# name: security/ssh-harden
# summary: Harden sshd_config (no root login, no passwords, optional custom port) and safely reload
# requires: sshd,systemctl,sudo
# tags: security,ssh,harden
# verbs: audit,apply
# since: 0.2.0
# breaking: false
# outputs: status, summary, actions
# root: false (uses sudo)

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $(basename "$0") [--port N] [--permit-root no|prohibit-password|yes] [--password-auth no|yes] [--allow-groups g1,g2] \
                         [--max-auth-tries N] [--permit-empty-passwords no|yes] [--skip-preflight] \
                         [--restart] [--dry-run] [--json] [--yes]

Applies a hardened sshd_config:
  - PermitRootLogin no (default; configurable)
  - PasswordAuthentication no (default; configurable)
  - PubkeyAuthentication yes
  - Optional custom Port and AllowGroups
  - Optional MaxAuthTries and PermitEmptyPasswords

Safety:
  - Dry-run by default if --yes not provided.
  - Backups original to /etc/ssh/sshd_config.<ts>.bak
  - Validates with 'sshd -t -f <tmp>' before applying.
  - Preflight: if disabling password auth, ensure at least one authorized_keys exists (override with --skip-preflight)
  - Policy gates: tokens 'ssh-config-apply' and service restart allowance for ssh/sshd.
EOF
}

port=""
permit_root="no"
password_auth="no"
allow_groups=""
do_restart=0
skip_preflight=0
max_auth_tries=""
permit_empty=""
do_rollback=0

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --port) port="${2:-}"; shift 2 ;;
    --permit-root) permit_root="${2:-no}"; shift 2 ;;
    --password-auth) password_auth="${2:-no}"; shift 2 ;;
    --allow-groups) allow_groups="${2:-}"; shift 2 ;;
    --max-auth-tries) max_auth_tries="${2:-}"; shift 2 ;;
    --permit-empty-passwords) permit_empty="${2:-no}"; shift 2 ;;
    --skip-preflight) skip_preflight=1; shift ;;
    --rollback) do_rollback=1; shift ;;
    --restart) do_restart=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) solen_err "unknown option: $1"; usage; exit 1 ;;
    *) break ;;
  esac
done

if ! solen_policy_allows_token "ssh-config-apply"; then
  msg="policy refused: ssh-config-apply"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "$msg" "" "\"code\":4" || solen_err "$msg"
  exit 4
fi

# Rollback: restore latest backup and exit
if [[ $do_rollback -eq 1 ]]; then
  latest="$(ls -1t /etc/ssh/sshd_config.*.bak 2>/dev/null | head -n1 || true)"
  if [[ -z "$latest" ]]; then
    solen_err "no backup files found to rollback"
    [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "no backup for rollback" "" "\"code\":2"
    exit 2
  fi
  actions=$(cat <<A
sudo install -m 0644 "$latest" "/etc/ssh/sshd_config"
if systemctl status ssh >/dev/null 2>&1; then sudo systemctl reload ssh || sudo systemctl restart ssh; else sudo systemctl reload sshd || sudo systemctl restart sshd; fi
A
  )
  if [[ $SOLEN_FLAG_DRYRUN -eq 1 || $SOLEN_FLAG_YES -eq 0 ]]; then
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record ok "dry-run: rollback to $(basename "$latest")" "$actions" "\"would_change\":1"
    else
      solen_info "dry-run enforced (use --yes to apply)"
      printf '%s' "$actions"
    fi
    exit 0
  fi
  changed=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    solen_info "$line"
    set +e
    bash -c "$line"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then changed=$((changed+1)); else solen_warn "step failed rc=$rc: $line"; fi
  done <<< "$actions"
  if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
    solen_json_record ok "rollback applied" "$actions" "\"changed\":${changed},\"rolled_back\":true"
  else
    solen_ok "rollback applied (changed=${changed})"
  fi
  exit 0
fi

conf="/etc/ssh/sshd_config"
[[ -r "$conf" ]] || { solen_err "not readable: $conf"; [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "missing sshd_config" "" "\"code\":2"; exit 2; }

ts="$(date -u +%Y%m%d-%H%M%S)"
tmp="/tmp/solen.sshd_config.${ts}.$$.tmp"
backup="/etc/ssh/sshd_config.${ts}.bak"

# Prepare desired directives
declare -a set_lines
[[ -n "$port" ]] && set_lines+=("Port ${port}")
set_lines+=("PermitRootLogin ${permit_root}")
set_lines+=("PasswordAuthentication ${password_auth}")
set_lines+=("PubkeyAuthentication yes")
set_lines+=("KbdInteractiveAuthentication no")
set_lines+=("ChallengeResponseAuthentication no")
if [[ -n "$allow_groups" ]]; then
  # Collapse commas/whitespace to spaces
  groups_norm=$(echo "$allow_groups" | sed 's/,/ /g; s/\s\+/ /g')
  set_lines+=("AllowGroups ${groups_norm}")
fi
if [[ -n "$max_auth_tries" ]]; then
  set_lines+=("MaxAuthTries ${max_auth_tries}")
fi
if [[ -n "$permit_empty" ]]; then
  set_lines+=("PermitEmptyPasswords ${permit_empty}")
fi

# Preflight: ensure at least one authorized key when disabling password auth
if [[ $SOLEN_FLAG_DRYRUN -eq 0 && $SOLEN_FLAG_YES -eq 1 && $skip_preflight -eq 0 && "$password_auth" == "no" ]]; then
  keys_ok=0
  cand=("/root/.ssh/authorized_keys")
  if [[ -n "${SUDO_USER:-}" ]]; then cand+=("/home/${SUDO_USER}/.ssh/authorized_keys"); fi
  cand+=("/home/${USER}/.ssh/authorized_keys")
  for p in /home/*/.ssh/authorized_keys; do [[ -e "$p" ]] && cand+=("$p"); done
  for f in "${cand[@]}"; do
    set +e
    sudo sh -c "test -s '$f' && grep -vE '^(#|\s*$)' '$f' >/dev/null 2>&1"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then keys_ok=1; break; fi
  done
  if [[ $keys_ok -ne 1 ]]; then
    msg="preflight failed: disabling password auth but no non-empty authorized_keys found (use --skip-preflight to override)"
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record error "$msg" "" "\"code\":12"
    else
      solen_err "$msg"
    fi
    rm -f "$tmp" || true
    exit 12
  fi
fi

# Build actions script (for dry-run display)
actions=$(cat <<A
sudo cp "$conf" "$backup"
sudo install -m 0644 "$tmp" "$conf"
test -x /usr/sbin/sshd && sudo /usr/sbin/sshd -t -f "$tmp"
if systemctl status ssh >/dev/null 2>&1; then sudo systemctl reload ssh || sudo systemctl restart ssh; else sudo systemctl reload sshd || sudo systemctl restart sshd; fi
A
)

# Construct new config (comment out existing directives, append desired)
awk -v port="$port" 'BEGIN{OFS=FS} {print $0}' "$conf" > "$tmp"
for d in "PermitRootLogin" "PasswordAuthentication" "PubkeyAuthentication" "KbdInteractiveAuthentication" "ChallengeResponseAuthentication" "AllowGroups" "Port"; do
  sed -i -E "s/^\s*${d}\b.*/# &/" "$tmp"
done
{
  echo ""
  echo "# --- Managed by SOLEN security/ssh-harden ---"
  for ln in "${set_lines[@]}"; do
    echo "$ln"
  done
} >> "$tmp"

# Validate prospective config (skip in dry-run to avoid sudo prompts)
if [[ $SOLEN_FLAG_DRYRUN -eq 0 && $SOLEN_FLAG_YES -eq 1 ]]; then
  if command -v sshd >/dev/null 2>&1; then
    set +e
    sudo sshd -t -f "$tmp"
    rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
      solen_err "validation failed (sshd -t)"
      [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "sshd -t validation failed" "" "\"code\":10"
      rm -f "$tmp" || true
      exit 10
    fi
  fi
fi

summary="sshd hardened (root=${permit_root}, passwords=${password_auth}${port:+, port=$port}${allow_groups:+, groups=$allow_groups}${max_auth_tries:+, MaxAuthTries=$max_auth_tries}${permit_empty:+, PermitEmptyPasswords=$permit_empty})"

if [[ $SOLEN_FLAG_DRYRUN -eq 1 || $SOLEN_FLAG_YES -eq 0 ]]; then
  if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
    solen_json_record ok "dry-run: $summary" "$actions" "\"would_change\":1"
  else
    solen_info "dry-run enforced (use --yes to apply)"
    printf '%s' "$actions"
  fi
  rm -f "$tmp" || true
  exit 0
fi

# Apply changes
sudo cp "$conf" "$backup"
sudo install -m 0644 "$tmp" "$conf"
rm -f "$tmp" || true

# Reload/restart if requested and allowed
did_restart=0
if [[ $do_restart -eq 1 ]]; then
  svc="ssh"
  if ! systemctl list-unit-files | grep -q '^ssh\.service'; then svc="sshd"; fi
  if solen_policy_allows_service_restart "$svc"; then
    set +e
    if systemctl status "$svc" >/dev/null 2>&1; then
      sudo systemctl reload "$svc" || sudo systemctl restart "$svc"
    else
      sudo systemctl restart "$svc"
    fi
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then did_restart=1; fi
  else
    solen_warn "policy did not allow restarting service '$svc'"
  fi
fi

metrics=\"\\"restarted\\\":$([[ $did_restart -eq 1 ]] && echo true || echo false)\"
if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "$summary" "sudo edit sshd_config; test; ${do_restart:+restart}" "{${metrics}}"
else
  solen_ok "$summary${do_restart:+ (reload attempted)}"
fi
exit 0
