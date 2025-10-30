#!/usr/bin/env bash
# Minimal policy helpers for SOLEN
# Looks for a YAML policy file and answers allow/deny queries.
#
# Policy resolution precedence (first found wins):
#   1) $SOLEN_POLICY (set to /dev/null to disable policy)
#   2) $HOME/.serverutils/policy.yaml
#   3) /etc/solen/policy.yaml
#
# Behavior:
# - If no policy file is present, all checks allow by default (return 0).
# - If a list exists under allow.* for a given check, membership is required.
# - deny.* lists override and force a deny when matched.

__SOLEN_POLICY_LOADED=0
__SOLEN_POLICY_FILE=""
declare -a _SOLEN_ALLOW_TOKENS
declare -a _SOLEN_ALLOW_SERV_RESTART
declare -a _SOLEN_ALLOW_PATHS_PRUNE
declare -a _SOLEN_DENY_SERV_RESTART
declare -a _SOLEN_DENY_PATHS_PRUNE

solen__policy_path() {
  local p=""
  if [[ -n "${SOLEN_POLICY:-}" ]]; then
    [[ "${SOLEN_POLICY}" == "/dev/null" ]] && echo "" && return 0
    [[ -r "${SOLEN_POLICY}" ]] && echo "${SOLEN_POLICY}" && return 0
  fi
  if [[ -r "${HOME}/.serverutils/policy.yaml" ]]; then
    echo "${HOME}/.serverutils/policy.yaml"; return 0
  fi
  if [[ -r "/etc/solen/policy.yaml" ]]; then
    echo "/etc/solen/policy.yaml"; return 0
  fi
  echo ""
}

solen__arr_contains() { # arrname value
  local __arr_name="$1"; shift
  local needle="$1"; shift || true
  local v
  # shellcheck disable=SC1087,SC2128
  for v in ${!__arr_name[@]}; do :; done >/dev/null 2>&1 || true
  # iterate using indirect expansion
  local -n __arr_ref="${__arr_name}"
  for v in "${__arr_ref[@]}"; do
    [[ "$v" == "$needle" ]] && return 0
  done
  return 1
}

solen__path_has_prefix() { # haystack_path candidate_prefix
  local path="$1"; local pref="$2"
  [[ -z "$path" || -z "$pref" ]] && return 1
  case "$path" in
    "$pref"|"$pref"/*) return 0 ;;
  esac
  return 1
}

solen__read_inline_list() { # input like: key: ["a", "b", c]
  local line="$1"
  local inside="${line#*[}"
  inside="${inside%]*}"
  # split by comma
  local IFS=,
  read -r -a parts <<< "$inside"
  for it in "${parts[@]}"; do
    it="${it## }"; it="${it%% }"
    it="${it%\r}"
    it="${it%\n}"
    it="${it%\,}"
    it="${it#\"}"; it="${it%\"}"
    it="${it#\'}"; it="${it%\'}"
    [[ -n "$it" ]] && printf '%s\n' "$it"
  done
}

solen__policy_load_awk() {
  local f="$1"
  local mode="" sub=""
  while IFS= read -r line; do
    # normalize tabs
    case "$line" in $'\t'*) line="${line//$'\t'/  }" ;; esac
    # state transitions
    if [[ "$line" =~ ^[[:space:]]*allow: ]]; then mode="allow"; sub=""; continue; fi
    if [[ "$line" =~ ^[[:space:]]*deny: ]]; then mode="deny"; sub=""; continue; fi
    if [[ "$line" =~ ^[[:space:]]*services: ]]; then sub="services"; continue; fi
    if [[ "$line" =~ ^[[:space:]]*paths: ]]; then sub="paths"; continue; fi
    if [[ "$line" =~ ^[[:space:]]*tokens: ]]; then
      if [[ "$line" =~ \[.*\] ]]; then
        while IFS= read -r item; do _SOLEN_ALLOW_TOKENS+=("$item"); done < <(solen__read_inline_list "$line")
        continue
      fi
      # read multi-line list that follows under allow: tokens:
      while IFS= read -r nxt; do
        [[ ! "$nxt" =~ ^[[:space:]]*-[[:space:]] ]] && { line="$nxt"; break; }
        nxt="${nxt#*- }"; nxt="${nxt## }"; nxt="${nxt%% }"; nxt="${nxt#\"}"; nxt="${nxt%\"}"; nxt="${nxt#\'}"; nxt="${nxt%\'}"
        [[ -n "$nxt" ]] && _SOLEN_ALLOW_TOKENS+=("$nxt")
      done
      continue
    fi
    # services.restart / services.enable
    if [[ "$mode" == "allow" && "$sub" == "services" && "$line" =~ ^[[:space:]]*restart: ]]; then
      if [[ "$line" =~ \[.*\] ]]; then
        while IFS= read -r item; do _SOLEN_ALLOW_SERV_RESTART+=("$item"); done < <(solen__read_inline_list "$line")
      else
        while IFS= read -r nxt; do
          [[ ! "$nxt" =~ ^[[:space:]]*-[[:space:]] ]] && { line="$nxt"; break; }
          nxt="${nxt#*- }"; nxt="${nxt## }"; nxt="${nxt%% }"; nxt="${nxt#\"}"; nxt="${nxt%\"}"; nxt="${nxt#\'}"; nxt="${nxt%\'}"
          [[ -n "$nxt" ]] && _SOLEN_ALLOW_SERV_RESTART+=("$nxt")
        done
      fi
      continue
    fi
    # paths.prune
    if [[ "$sub" == "paths" && "$line" =~ ^[[:space:]]*prune: ]]; then
      local arrname="_SOLEN_ALLOW_PATHS_PRUNE"
      if [[ "$mode" == "deny" ]]; then arrname="_SOLEN_DENY_PATHS_PRUNE"; fi
      if [[ "$line" =~ \[.*\] ]]; then
        while IFS= read -r item; do eval "$arrname+=(\"\$item\")"; done < <(solen__read_inline_list "$line")
      else
        while IFS= read -r nxt; do
          [[ ! "$nxt" =~ ^[[:space:]]*-[[:space:]] ]] && { line="$nxt"; break; }
          nxt="${nxt#*- }"; nxt="${nxt## }"; nxt="${nxt%% }"; nxt="${nxt#\"}"; nxt="${nxt%\"}"; nxt="${nxt#\'}"; nxt="${nxt%\'}"
          [[ -n "$nxt" ]] && eval "$arrname+=(\"\$nxt\")"
        done
      fi
      continue
    fi
    # deny.services.restart
    if [[ "$mode" == "deny" && "$sub" == "services" && "$line" =~ ^[[:space:]]*restart: ]]; then
      if [[ "$line" =~ \[.*\] ]]; then
        while IFS= read -r item; do _SOLEN_DENY_SERV_RESTART+=("$item"); done < <(solen__read_inline_list "$line")
      else
        while IFS= read -r nxt; do
          [[ ! "$nxt" =~ ^[[:space:]]*-[[:space:]] ]] && { line="$nxt"; break; }
          nxt="${nxt#*- }"; nxt="${nxt## }"; nxt="${nxt%% }"; nxt="${nxt#\"}"; nxt="${nxt%\"}"; nxt="${nxt#\'}"; nxt="${nxt%\'}"
          [[ -n "$nxt" ]] && _SOLEN_DENY_SERV_RESTART+=("$nxt")
        done
      fi
      continue
    fi
  done < "$f"
}

solen__policy_load() {
  [[ $__SOLEN_POLICY_LOADED -eq 1 ]] && return 0
  __SOLEN_POLICY_FILE="$(solen__policy_path)"
  if [[ -z "$__SOLEN_POLICY_FILE" || ! -r "$__SOLEN_POLICY_FILE" ]]; then
    __SOLEN_POLICY_LOADED=1; return 0
  fi
  # Clear arrays
  _SOLEN_ALLOW_TOKENS=()
  _SOLEN_ALLOW_SERV_RESTART=()
  _SOLEN_ALLOW_PATHS_PRUNE=()
  _SOLEN_DENY_SERV_RESTART=()
  _SOLEN_DENY_PATHS_PRUNE=()
  if command -v yq >/dev/null 2>&1; then
    # allow tokens
    while IFS= read -r t; do [[ -n "$t" && "$t" != "null" ]] && _SOLEN_ALLOW_TOKENS+=("$t"); done < <(yq -r '.allow.tokens[]? // empty' "$__SOLEN_POLICY_FILE" 2>/dev/null)
    # services.restart allow/deny
    while IFS= read -r s; do [[ -n "$s" && "$s" != "null" ]] && _SOLEN_ALLOW_SERV_RESTART+=("$s"); done < <(yq -r '.allow.services.restart[]? // empty' "$__SOLEN_POLICY_FILE" 2>/dev/null)
    while IFS= read -r s; do [[ -n "$s" && "$s" != "null" ]] && _SOLEN_DENY_SERV_RESTART+=("$s"); done < <(yq -r '.deny.services.restart[]? // empty' "$__SOLEN_POLICY_FILE" 2>/dev/null)
    # paths.prune allow/deny
    while IFS= read -r p; do [[ -n "$p" && "$p" != "null" ]] && _SOLEN_ALLOW_PATHS_PRUNE+=("$p"); done < <(yq -r '.allow.paths.prune[]? // empty' "$__SOLEN_POLICY_FILE" 2>/dev/null)
    while IFS= read -r p; do [[ -n "$p" && "$p" != "null" ]] && _SOLEN_DENY_PATHS_PRUNE+=("$p"); done < <(yq -r '.deny.paths.prune[]? // empty' "$__SOLEN_POLICY_FILE" 2>/dev/null)
  else
    solen__policy_load_awk "$__SOLEN_POLICY_FILE"
  fi
  __SOLEN_POLICY_LOADED=1
}

solen_policy_allows_token() { # token
  local token="$1"
  solen__policy_load
  # No policy => allow
  if [[ -z "$__SOLEN_POLICY_FILE" ]]; then return 0; fi
  # If allow list is empty or missing, allow
  local count=${#_SOLEN_ALLOW_TOKENS[@]}
  if (( count == 0 )); then return 0; fi
  solen__arr_contains _SOLEN_ALLOW_TOKENS "$token"
}

solen_policy_allows_service_restart() { # service
  local svc="$1"
  solen__policy_load
  if [[ -z "$__SOLEN_POLICY_FILE" ]]; then return 0; fi
  # deny overrides
  if solen__arr_contains _SOLEN_DENY_SERV_RESTART "$svc"; then return 1; fi
  local count=${#_SOLEN_ALLOW_SERV_RESTART[@]}
  if (( count == 0 )); then return 0; fi
  solen__arr_contains _SOLEN_ALLOW_SERV_RESTART "$svc"
}

solen_policy_allows_prune_path() { # path
  local path="$1"
  solen__policy_load
  if [[ -z "$__SOLEN_POLICY_FILE" ]]; then return 0; fi
  # deny overrides
  local p
  for p in "${_SOLEN_DENY_PATHS_PRUNE[@]}"; do
    if solen__path_has_prefix "$path" "$p"; then return 1; fi
  done
  local count=${#_SOLEN_ALLOW_PATHS_PRUNE[@]}
  if (( count == 0 )); then return 0; fi
  for p in "${_SOLEN_ALLOW_PATHS_PRUNE[@]}"; do
    if solen__path_has_prefix "$path" "$p"; then return 0; fi
  done
  return 1
}

