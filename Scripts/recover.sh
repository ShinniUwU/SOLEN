#!/usr/bin/env bash

# SOLEN-META:
# name: recover
# summary: Recover last-known-good SSH/Firewall/MOTD state (best-effort, dry-run by default)
# requires: bash,systemctl
# tags: recover,rollback
# verbs: recover
# since: 0.2.0
# outputs: status, summary, actions
# root: false (uses sudo when required)

set -Eeuo pipefail

target=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    ssh) target="ssh"; shift ;;
    firewall) target="firewall"; shift ;;
    motd) target="motd"; shift ;;
    --yes) SOLEN_FLAG_YES=1; shift ;;
    --json) SOLEN_FLAG_JSON=1; shift ;;
    --dry-run) SOLEN_FLAG_DRYRUN=1; shift ;;
    -h|--help) echo "Usage: recover <ssh|firewall|motd> [--dry-run] [--yes] [--json]"; exit 0 ;;
    *) break ;;
  esac
done

actions=()
add(){ actions+=("$1"); }

case "$target" in
  ssh)
    add "serverutils run security/ssh-harden -- --rollback"
    ;;
  firewall)
    add "sudo ufw --force disable || true"
    add "sudo nft flush ruleset || true"
    add "sudo iptables -P INPUT ACCEPT; sudo iptables -F || true"
    add "sudo ip6tables -P INPUT ACCEPT; sudo ip6tables -F || true"
    ;;
  motd)
    add "# Remove system-wide MOTD wrappers if any (update-motd/profile.d)"
    add "sudo rm -f /etc/update-motd.d/90-solen /etc/profile.d/solen-motd.sh || true"
    ;;
  *) echo "Usage: recover <ssh|firewall|motd>"; exit 1 ;;
esac

if [[ ${SOLEN_FLAG_DRYRUN:-1} -eq 1 && ${SOLEN_FLAG_YES:-0} -eq 0 ]]; then
  if [[ ${SOLEN_FLAG_JSON:-0} -eq 1 ]]; then
    printf '{"status":"ok","summary":"dry-run: recover %s","ts":"%s","host":"%s","actions":[%s]}\n' \
      "$target" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname 2>/dev/null || uname -n)" \
      "$(printf '%s\n' "${actions[@]}" | awk 'BEGIN{f=1}{gsub(/\\/,"\\\\");gsub(/"/,"\\\""); printf (f?"\"%s\"":" ,\"%s\""),$0; f=0} END{}')"
  else
    printf 'Dry-run: recover %s\n' "$target"; printf '%s\n' "${actions[@]}"
  fi
  exit 0
fi

changed=0
for cmd in "${actions[@]}"; do
  [[ "$cmd" == \#* ]] && continue
  echo "$cmd"
  set +e; bash -lc "$cmd"; rc=$?; set -e
  [[ $rc -eq 0 ]] && changed=$((changed+1)) || true
done

if [[ ${SOLEN_FLAG_JSON:-0} -eq 1 ]]; then
  printf '{"status":"ok","summary":"recovered %s","ts":"%s","host":"%s","changed":%d}\n' \
    "$target" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(hostname 2>/dev/null || uname -n)" "$changed"
else
  echo "Recovered $target (changed=$changed)"
fi
exit 0

