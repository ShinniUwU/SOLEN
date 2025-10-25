#!/usr/bin/env bash
# SOLEN-META:
# name: services/ensure
# summary: Ensure systemd services (status/ensure-enabled/ensure-running/restart-if-failed)
# tags: services,systemd
# verbs: status,ensure-enabled,ensure-running,restart-if-failed
# outputs: status,summary,metrics
# root: false
# since: 0.1.0
# breaking: false
set -Eeuo pipefail

JSON=${SOLEN_JSON:-0}
NOOP=${SOLEN_NOOP:-0}
UNIT=""
CMD="${1:-status}"
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --unit)
      UNIT="${2:-}"
      shift
      ;;
    --json) JSON=1 ;;
    --dry-run) NOOP=1 ;;
  esac
  shift || true
done

host() { hostname 2> /dev/null || uname -n; }
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
j() { printf '%s\n' "$1"; }

if ! command -v systemctl > /dev/null 2>&1; then
  j "{\"status\":\"warn\",\"summary\":\"non-systemd host (degraded)\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
  exit 3
fi

[ -n "$UNIT" ] || {
  echo "Usage: $0 {status|ensure-enabled|ensure-running|restart-if-failed} --unit <name>"
  exit 1
}

is_active() { systemctl is-active --quiet "$UNIT"; }
is_enabled() { systemctl is-enabled --quiet "$UNIT"; }

case "$CMD" in
  status)
    act="inactive"
    is_active && act="active"
    ena="disabled"
    is_enabled && ena="enabled"
    j "{\"status\":\"ok\",\"summary\":\"$UNIT $act,$ena\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
    ;;
  ensure-enabled)
    if is_enabled; then
      j "{\"status\":\"ok\",\"summary\":\"$UNIT already enabled\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
    else
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would enable $UNIT\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo systemctl enable "$UNIT" && j "{\"status\":\"ok\",\"summary\":\"enabled $UNIT\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      fi
    fi
    ;;
  ensure-running)
    if ! is_enabled; then
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would enable $UNIT\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo systemctl enable "$UNIT" > /dev/null
      fi
    fi
    if is_active; then
      j "{\"status\":\"ok\",\"summary\":\"$UNIT already running\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
    else
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would start $UNIT\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo systemctl start "$UNIT" && j "{\"status\":\"ok\",\"summary\":\"started $UNIT\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      fi
    fi
    ;;
  restart-if-failed)
    if systemctl --quiet is-failed "$UNIT"; then
      if [ "$NOOP" = "1" ]; then
        j "{\"status\":\"ok\",\"summary\":\"would restart $UNIT (failed)\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      else
        sudo systemctl restart "$UNIT" && j "{\"status\":\"ok\",\"summary\":\"restarted $UNIT (was failed)\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
      fi
    else
      j "{\"status\":\"ok\",\"summary\":\"$UNIT not failed\",\"ts\":\"$(ts)\",\"host\":\"$(host)\"}"
    fi
    ;;
  *)
    echo "Usage: $0 {status|ensure-enabled|ensure-running|restart-if-failed} --unit <name>" >&2
    exit 1
    ;;
esac
