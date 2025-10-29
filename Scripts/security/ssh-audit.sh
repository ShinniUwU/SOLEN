#!/usr/bin/env bash

# SOLEN-META:
# name: security/ssh-audit
# summary: Audit sshd_config for risky settings and emit JSON
# requires: awk,grep,sed
# tags: security,ssh,audit
# verbs: audit,info
# since: 0.2.0
# breaking: false
# outputs: status, summary, details, metrics
# root: false

set -Eeuo pipefail

conf="/etc/ssh/sshd_config"
if [[ ! -r "$conf" ]]; then
  printf '{"status":"error","summary":"sshd_config not readable","ts":"%s","host":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname 2>/dev/null || uname -n)"
  exit 2
fi

val() {
  local key="$1"; awk -v k="^\\s*"$key"\\b" 'BEGIN{v="unset"} /^[[:space:]]*#/ {next} $0~k{v=$2} END{print v}' "$conf"
}

permit_root=$(val PermitRootLogin)
password_auth=$(val PasswordAuthentication)
pubkey_auth=$(val PubkeyAuthentication)
ciphers=$(awk 'BEGIN{v=""} /^[[:space:]]*#/ {next} /Ciphers/{for(i=2;i<=NF;i++){printf (i==2?"%s":" %s"),$i}}' "$conf")
macs=$(awk 'BEGIN{v=""} /^[[:space:]]*#/ {next} /MACs/{for(i=2;i<=NF;i++){printf (i==2?"%s":" %s"),$i}}' "$conf")
kex=$(awk 'BEGIN{v=""} /^[[:space:]]*#/ {next} /KexAlgorithms/{for(i=2;i<=NF;i++){printf (i==2?"%s":" %s"),$i}}' "$conf")

weak=0
summary_parts=()
[[ "$permit_root" != "no" ]] && weak=$((weak+1)) && summary_parts+=("PermitRootLogin=$permit_root")
[[ "$password_auth" != "no" ]] && weak=$((weak+1)) && summary_parts+=("PasswordAuthentication=$password_auth")
if printf '%s' "$ciphers" | grep -qiE '(arcfour|rc4|des)'; then weak=$((weak+1)); summary_parts+=("weak-cipher"); fi
if printf '%s' "$macs" | grep -qiE '(hmac-md5|umac-96)'; then weak=$((weak+1)); summary_parts+=("weak-mac"); fi
if printf '%s' "$kex" | grep -qiE 'diffie-hellman-group1-sha1'; then weak=$((weak+1)); summary_parts+=("weak-kex"); fi

status="ok"; [[ $weak -gt 0 ]] && status="warn"
summary="ssh audit: ${status}; ${summary_parts[*]:-ok}"

printf '{"status":"%s","summary":"%s","ts":"%s","host":"%s","details":{"PermitRootLogin":"%s","PasswordAuthentication":"%s","PubkeyAuthentication":"%s","ciphers":"%s","macs":"%s","kex":"%s"},"metrics":{"issues":%d}}\n' \
  "$status" "$(printf '%s' "$summary" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname 2>/dev/null || uname -n)" \
  "$permit_root" "$password_auth" "$pubkey_auth" "$(printf '%s' "$ciphers" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$(printf '%s' "$macs" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$(printf '%s' "$kex" | sed 's/\\/\\\\/g; s/"/\\"/g')" "$weak"

exit 0

