#!/usr/bin/env bash

# SOLEN-META:
# name: doctor
# summary: Quick system health: timers, backups recency, firewall/ssh posture
# requires: bash,awk,sed
# tags: health,doctor
# verbs: check,info
# since: 0.2.0
# breaking: false
# outputs: status, summary, details, metrics
# root: false

set -Eeuo pipefail

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
host() { hostname 2>/dev/null || uname -n; }

# timers (best-effort)
user_timer_active=0
system_timer_active=0
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user is-active --quiet solen-kopia-maintenance.timer 2>/dev/null && user_timer_active=1 || true
  systemctl is-active --quiet solen-kopia-maintenance-system.timer 2>/dev/null && system_timer_active=1 || true
fi

# backups recency (best-effort)
last_backup_ts=""
for f in "$HOME/.local/share/solen"/backups-*.ndjson /var/log/solen/backups-*.ndjson; do
  [ -f "$f" ] || continue
  l=$(tail -n 1 "$f" 2>/dev/null || true)
  t=$(printf '%s' "$l" | sed -n 's/.*"ts":"\([^"]\+\)".*/\1/p')
  if [ -n "$t" ]; then last_backup_ts="$t"; break; fi
done

# firewall status
fw_kind="none"; fw_enabled=false
if command -v ufw >/dev/null 2>&1; then
  fw_kind=ufw; ufw status 2>/dev/null | grep -qi '^status: active' && fw_enabled=true
elif command -v nft >/dev/null 2>&1; then
  fw_kind=nftables; nft list ruleset 2>/dev/null | grep -q 'table' && fw_enabled=true
elif command -v iptables >/dev/null 2>&1; then
  fw_kind=iptables; iptables -S 2>/dev/null | grep -q '^-P' && fw_enabled=true
fi

# ssh posture
permit_root="unknown"; password_auth="unknown"
if [ -r /etc/ssh/sshd_config ]; then
  permit_root=$(awk 'BEGIN{v="unset"} /^[[:space:]]*#/ {next} /PermitRootLogin/{v=$2} END{print v}' /etc/ssh/sshd_config)
  password_auth=$(awk 'BEGIN{v="unset"} /^[[:space:]]*#/ {next} /PasswordAuthentication/{v=$2} END{print v}' /etc/ssh/sshd_config)
fi

issues=0
[ "$permit_root" != "no" ] && issues=$((issues+1))
[ "$password_auth" != "no" ] && issues=$((issues+1))
! $fw_enabled && issues=$((issues+1))

summary="fw:${fw_kind}$( $fw_enabled && echo :on || echo :off ); ssh root:${permit_root} pass:${password_auth}; last backup:${last_backup_ts:-unknown}"
printf '{"status":"%s","summary":"%s","ts":"%s","host":"%s","metrics":{"issues":%d},"details":{"timers":{"user":%s,"system":%s},"backups":{"last_ts":"%s"},"firewall":{"kind":"%s","enabled":%s},"ssh":{"PermitRootLogin":"%s","PasswordAuthentication":"%s"}}}\n' \
  "$([ $issues -gt 0 ] && echo warn || echo ok)" "$(printf '%s' "$summary" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$(ts)" "$(host)" "$issues" \
  "$([ $user_timer_active -eq 1 ] && echo true || echo false)" "$([ $system_timer_active -eq 1 ] && echo true || echo false)" \
  "$last_backup_ts" "$fw_kind" "$($fw_enabled && echo true || echo false)" "$permit_root" "$password_auth"

exit 0

