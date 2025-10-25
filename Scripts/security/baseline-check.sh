#!/usr/bin/env bash

# SOLEN-META:
# name: security/baseline-check
# summary: Read-only security baseline: sshd, firewall, fail2ban, timesync, sysctl, sudoers
# requires: awk,grep,sed
# tags: security,baseline,check
# verbs: check,info
# since: 0.1.0
# breaking: false
# outputs: status, summary, metrics, details
# root: false

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage: $(basename "$0") [--json]

Checks common security posture items non-destructively:
  - sshd: PermitRootLogin, PasswordAuthentication
  - firewall: ufw/nftables/iptables presence
  - fail2ban: service state
  - timesync: NTP/chrony active
  - sysctl: ASLR (randomize_va_space)
  - sudoers: users in sudo/wheel groups
EOF
}

while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then shift; continue; fi
  case "$1" in -h|--help) usage; exit 0; ;; --) shift; break ;; -*) solen_err "unknown: $1"; usage; exit 1;; *) break;; esac
done

# sshd config
sshd_present=0; sshd_root_login="unknown"; sshd_password_auth="unknown"
if command -v sshd >/dev/null 2>&1 || command -v systemctl >/dev/null 2>&1; then
  if [[ -r /etc/ssh/sshd_config ]]; then
    sshd_present=1
    # last effective values (ignore comments), strip inline comments
    sshd_root_login=$(awk 'BEGIN{v=""} /^[[:space:]]*#/ {next} /PermitRootLogin/{v=$2} END{if(v=="")print "unset";else print v}' /etc/ssh/sshd_config)
    sshd_password_auth=$(awk 'BEGIN{v=""} /^[[:space:]]*#/ {next} /PasswordAuthentication/{v=$2} END{if(v=="")print "unset";else print v}' /etc/ssh/sshd_config)
  fi
fi

# firewall
fw="none"; fw_enabled=0
if command -v ufw >/dev/null 2>&1; then
  fw="ufw"
  if ufw status 2>/dev/null | grep -qi '^status: active'; then fw_enabled=1; fi
elif command -v nft >/dev/null 2>&1; then
  fw="nftables"
  if nft list ruleset 2>/dev/null | grep -q 'table'; then fw_enabled=1; fi
elif command -v iptables >/dev/null 2>&1; then
  fw="iptables"
  if iptables -S 2>/dev/null | grep -q '^-P'; then fw_enabled=1; fi
fi

# fail2ban
f2b_present=0; f2b_active=0
if command -v fail2ban-client >/dev/null 2>&1; then f2b_present=1; fi
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet fail2ban 2>/dev/null; then f2b_active=1; fi

# timesync
timesync="unknown"
if command -v timedatectl >/dev/null 2>&1; then
  if timedatectl status 2>/dev/null | grep -qi 'system clock synchronized: yes'; then timesync="synchronized"; else timesync="unsynced"; fi
fi

# ASLR
aslr=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo 0)

# sudoers groups
sudo_users=""
for g in sudo wheel; do
  if getent group "$g" >/dev/null 2>&1; then
    users=$(getent group "$g" | awk -F: '{print $4}')
    if [[ -n "$users" ]]; then sudo_users+="$g: $users "; fi
  fi
done

# Grade
issues=0
[[ "$sshd_root_login" != "no" ]] && issues=$((issues+1))
[[ "$sshd_password_auth" != "no" ]] && issues=$((issues+1))
[[ $fw_enabled -ne 1 ]] && issues=$((issues+1))
[[ "$timesync" != "synchronized" ]] && issues=$((issues+1))
[[ "$aslr" -lt 2 ]] && issues=$((issues+1))

status="ok"; [[ $issues -gt 0 ]] && status="warn"
summary="sshd root:${sshd_root_login} passauth:${sshd_password_auth}; fw:${fw}$( [[ $fw_enabled -eq 1 ]] && echo :on || echo :off ); fail2ban:$([[ $f2b_active -eq 1 ]] && echo on || echo off); time:${timesync}; aslr:${aslr}"

if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  # details object inline
  printf '{"status":"%s","summary":"%s","ts":"%s","host":"%s","metrics":{"issues":%d},"details":{"sshd":{"present":%s,"permit_root_login":"%s","password_auth":"%s"},"firewall":{"kind":"%s","enabled":%s},"fail2ban":{"present":%s,"active":%s},"timesync":"%s","sysctl":{"randomize_va_space":%s},"sudoers":"%s"}}\n' \
    "$status" "$(solen_json_escape "$summary")" "$(solen_ts)" "$(solen_host)" "$issues" \
    "$([[ $sshd_present -eq 1 ]] && echo true || echo false)" "$sshd_root_login" "$sshd_password_auth" \
    "$fw" "$([[ $fw_enabled -eq 1 ]] && echo true || echo false)" \
    "$([[ $f2b_present -eq 1 ]] && echo true || echo false)" "$([[ $f2b_active -eq 1 ]] && echo true || echo false)" \
    "$timesync" "$aslr" "$(solen_json_escape "$sudo_users")"
else
  case "$status" in ok) solen_ok "$summary" ;; warn) solen_warn "$summary" ;; *) solen_err "$summary" ;; esac
fi
exit 0

