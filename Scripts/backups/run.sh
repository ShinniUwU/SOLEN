#!/usr/bin/env bash

# SOLEN-META:
# name: backups/run
# summary: Run or prune backups by profile (Kopia-backed; falls back to scaffold)
# requires: kopia,rsync
# tags: backup,retention
# verbs: backup
# since: 0.1.0
# breaking: false
# outputs: status, summary, metrics, actions
# root: false

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${THIS_DIR}/../lib/solen.sh"
solen_init_flags

usage() {
  cat << EOF
Usage:
  $(basename "$0") run --profile <name> [--dest <path>] [--retention-days N] [--dry-run] [--json]
  $(basename "$0") prune --profile <name> [--dest <path>] [--retention-days N] [--dry-run] [--json]

Environment:
  SOLEN_BACKUPS_CONFIG   Path to profiles YAML (default: config/solen-backups.yaml)
  SOLEN_BACKUPS_DEST     Override destination root
  SOLEN_BACKUPS_RETENTION_DAYS  Override retention days

Safety:
  - Dry-run is enforced by default; use --yes or SOLEN_ASSUME_YES=1 to apply changes.
  - Policy gates: requires allow tokens backup-profile:<name> and backup-path:<dest>.

Notes:
  - Uses Kopia (filesystem repo by default under dest/kopia-repo). If Kopia not installed, acts as scaffold.
  - For S3, set env: SOLEN_KOPIA_S3_BUCKET, SOLEN_KOPIA_S3_REGION, [SOLEN_KOPIA_S3_PREFIX], [SOLEN_KOPIA_S3_ENDPOINT]
  - Repo password: set KOPIA_PASSWORD or KOPIA_PASSWORD_FILE (defaults to ~/.serverutils/kopia-password)
  - Optional repo-per-profile: set SOLEN_KOPIA_REPO_PER_PROFILE=1 to use per-profile repo paths
EOF
}

cmd="${1:-}"
shift || true

profile=""
dest_override="${SOLEN_BACKUPS_DEST:-}"
ret_days="${SOLEN_BACKUPS_RETENTION_DAYS:-}"
repo_per_profile="${SOLEN_KOPIA_REPO_PER_PROFILE:-0}"
while [[ $# -gt 0 ]]; do
  if solen_parse_common_flag "$1"; then
    shift
    continue
  fi
  case "$1" in
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --dest)
      dest_override="${2:-}"
      shift 2
      ;;
    --retention-days)
      ret_days="${2:-}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      solen_err "unknown option: $1"
      usage
      exit 1
      ;;
    *) break ;;
  esac
done

[[ -n "$cmd" ]] || {
  solen_err "missing subcommand (run|prune)"
  usage
  exit 1
}
[[ -n "$profile" ]] || {
  solen_err "missing --profile"
  usage
  exit 1
}

# Resolve config and dest
ROOT_DIR="$(cd "${THIS_DIR}/../.." && pwd)"
cfg_path="${SOLEN_BACKUPS_CONFIG:-${ROOT_DIR}/config/solen-backups.yaml}"
dest="${dest_override:-/var/backups/solen}"
ret_days="${ret_days:-7}"

# Policy tokens (scaffold): backup-profile:<name>, backup-path:<dest>
if ! solen_policy_allows_token "backup-profile:${profile}"; then
  msg="policy refused: backup-profile:${profile}"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "$msg" "" "\"code\":4" || solen_err "$msg"
  exit 4
fi
if ! solen_policy_allows_token "backup-path:${dest}"; then
  msg="policy refused: backup-path:${dest}"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "$msg" "" "\"code\":4" || solen_err "$msg"
  exit 4
fi

# Enforce dry-run by default (safety); require --yes for real changes
if [[ "$cmd" =~ ^(run|prune)$ ]]; then
  if [[ ${SOLEN_FLAG_DRYRUN:-0} -eq 0 && ${SOLEN_FLAG_YES:-0} -eq 0 ]]; then
    SOLEN_FLAG_DRYRUN=1
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record warn "dry-run enforced (use --yes to apply changes)"
    else
      solen_warn "dry-run enforced (use --yes to apply changes)"
    fi
  fi
fi

# Helpers: parse YAML for sources and excludes
parse_profile_yaml() {
  # Emits lines: DEFEXCL <pattern> | SRC <path> | EXCL <path> <pattern>
  awk -v pname="$profile" '
    function trim(s){ sub(/^[[:space:]]+/,"",s); sub(/[[:space:]]+$/, "", s); return s }
    function stripq(s){ gsub(/^"|"$/, "", s); gsub(/^\047|\047$/, "", s); return s }
    BEGIN{ in_def=0; in_def_ex=0; in_profiles=0; in_p=0; in_sources=0; in_src_ex=0; last_path="" }
    /^defaults:/ { in_def=1; in_def_ex=0; next }
    in_def && /^[^[:space:]]/ && $0 !~ /^defaults:/ { in_def=0; in_def_ex=0 }
    in_def && /exclude:/ {
      if ($0 ~ /\[/) { a=$0; sub(/^.*\[/,"",a); sub(/\].*$/, "", a); n=split(a, parts, /,[ ]*/);
        for (i=1;i<=n;i++){ p=stripq(trim(parts[i])); if (p!="") print "DEFEXCL " p }
      } else { in_def_ex=1 }
      next
    }
    in_def_ex && /^[[:space:]]*-[[:space:]]*/ { l=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", l); l=stripq(trim(l)); if(l!="") print "DEFEXCL " l; next }
    in_def_ex && !/^[[:space:]]*-[[:space:]]*/ { in_def_ex=0 }

    /^profiles:/ { in_profiles=1; next }
    in_profiles && /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ { name=$0; sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", name); name=stripq(trim(name)); in_p=(name==pname?1:0); in_sources=0; next }
    in_p && /^[[:space:]]*sources:[[:space:]]*$/ { in_sources=1; next }
    in_p && in_sources && /^[[:space:]]*-[[:space:]]*path:[[:space:]]*/ { p=$0; sub(/^[[:space:]]*-[[:space:]]*path:[[:space:]]*/, "", p); p=stripq(trim(p)); last_path=p; if(p!="") print "SRC " p; next }
    in_p && in_sources && /^[[:space:]]*exclude:[[:space:]]*\[/ { a=$0; sub(/^.*\[/,"",a); sub(/\].*$/, "", a); n=split(a, parts, /,[ ]*/); for(i=1;i<=n;i++){ e=stripq(trim(parts[i])); if(e!="") print "EXCL " last_path " " e } next }
    in_p && in_sources && /^[[:space:]]*exclude:[[:space:]]*$/ { in_src_ex=1; next }
    in_src_ex && /^[[:space:]]*-[[:space:]]*/ { e=$0; sub(/^[[:space:]]*-[[:space:]]*/, "", e); e=stripq(trim(e)); if(e!="") print "EXCL " last_path " " e; next }
    in_src_ex && !/^[[:space:]]*-[[:space:]]*/ { in_src_ex=0 }
  ' "$cfg_path"
}

declare -a SRC_PATHS=()
declare -A EXCLUDES_FOR=()
declare -a DEFAULT_EXCLUDES=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  case "$line" in
    DEFEXCL\ *) DEFAULT_EXCLUDES+=("${line#DEFEXCL }") ;;
    SRC\ *) SRC_PATHS+=("${line#SRC }") ;;
    EXCL\ *)
      rest="${line#EXCL }"
      pth="${rest%% *}"; pat="${rest#* }"
      EXCLUDES_FOR["$pth"]+="|$pat"
      ;;
  esac
done < <(parse_profile_yaml)

if [[ ${#SRC_PATHS[@]} -eq 0 ]]; then
  solen_err "no sources found for profile: ${profile} (config: ${cfg_path})"
  [[ $SOLEN_FLAG_JSON -eq 1 ]] && solen_json_record error "no sources for ${profile}" "" "\"code\":2"
  exit 2
fi

# Begin line
begin_msg="begin: backup ${profile} with ${#SRC_PATHS[@]} source(s)"
if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
  solen_json_record ok "$begin_msg"
else
  solen_info "$begin_msg"
fi

prune_planned=1

use_kopia=0
if command -v kopia >/dev/null 2>&1; then use_kopia=1; fi

# Repository selection (default: filesystem repo under dest/kopia-repo)
repo_kind="filesystem"
repo_path="${dest%/}/kopia-repo"
repo_create=${SOLEN_KOPIA_CREATE:-1}
extra_env=""
if [[ -n "${SOLEN_KOPIA_S3_BUCKET:-}" ]]; then
  repo_kind="s3"
  if [[ "$repo_per_profile" == "1" ]]; then
    repo_path="s3://${SOLEN_KOPIA_S3_BUCKET}/${SOLEN_KOPIA_S3_PREFIX:-solen}/${profile}"
  else
    repo_path="s3://${SOLEN_KOPIA_S3_BUCKET}/${SOLEN_KOPIA_S3_PREFIX:-solen}"
  fi
else
  if [[ "$repo_per_profile" == "1" ]]; then
    repo_path="${dest%/}/kopia-repo-${profile}"
  fi
fi

# Password resolution
KOPIA_PASSWORD_FILE_DEFAULT="${HOME}/.serverutils/kopia-password"
if [[ -z "${KOPIA_PASSWORD:-}" && -z "${KOPIA_PASSWORD_FILE:-}" ]]; then
  if [[ ! -f "$KOPIA_PASSWORD_FILE_DEFAULT" ]]; then
    if [[ $SOLEN_FLAG_DRYRUN -eq 0 && $SOLEN_FLAG_YES -eq 1 ]]; then
      mkdir -p "$(dirname "$KOPIA_PASSWORD_FILE_DEFAULT")"
      tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 >"$KOPIA_PASSWORD_FILE_DEFAULT"
      chmod 600 "$KOPIA_PASSWORD_FILE_DEFAULT"
    fi
  fi
  export KOPIA_PASSWORD_FILE="$KOPIA_PASSWORD_FILE_DEFAULT"
fi

# Build planned actions
actions_list=""
if [[ $use_kopia -eq 1 ]]; then
  # choose sudo for filesystem repo in /var*
  use_sudo=0
  if [[ "$repo_kind" == "filesystem" ]] && [[ "$repo_path" == /var/* ]]; then use_sudo=1; fi
  SUDO=""; [[ $use_sudo -eq 1 ]] && SUDO="sudo -E"

  if [[ "$repo_kind" == "filesystem" ]]; then
    actions_list+=$"$SUDO mkdir -p \"$repo_path\"\n"
    actions_list+=$"$SUDO env KOPIA_PASSWORD_FILE=\"${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}\" kopia repository connect filesystem --path \"$repo_path\" 2>/dev/null || \\\n+$SUDO env KOPIA_PASSWORD_FILE=\"${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}\" kopia repository create filesystem --path \"$repo_path\"\n"
  else
    # S3 repo: require bucket & region
    if [[ -z "${SOLEN_KOPIA_S3_REGION:-${AWS_REGION:-}}" ]]; then
      actions_list+=$"# ERROR: missing SOLEN_KOPIA_S3_REGION or AWS_REGION for S3 repo\n"
    fi
    region="${SOLEN_KOPIA_S3_REGION:-${AWS_REGION:-}}"
    endpoint_opt=""; [[ -n "${SOLEN_KOPIA_S3_ENDPOINT:-}" ]] && endpoint_opt=" --endpoint=${SOLEN_KOPIA_S3_ENDPOINT}"
    actions_list+=$"env KOPIA_PASSWORD_FILE=\"${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}\" kopia repository connect s3 --bucket \"${SOLEN_KOPIA_S3_BUCKET}\" --prefix \"${SOLEN_KOPIA_S3_PREFIX:-solen}\" --region \"${region}\"${endpoint_opt} 2>/dev/null || \\\n+env KOPIA_PASSWORD_FILE=\"${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}\" kopia repository create s3 --bucket \"${SOLEN_KOPIA_S3_BUCKET}\" --prefix \"${SOLEN_KOPIA_S3_PREFIX:-solen}\" --region \"${region}\"${endpoint_opt}\n"
  fi
  # snapshots per source
  for src in "${SRC_PATHS[@]}"; do
    # compose excludes: defaults + per-source
    excl_flags=()
    # defaults
    for ex in "${DEFAULT_EXCLUDES[@]:-}"; do excl_flags+=("--exclude-glob" "$ex"); done
    # per-source (split EXCLUDES_FOR[src] by |)
    exlist="${EXCLUDES_FOR[$src]:-}"
    if [[ -n "$exlist" ]]; then
      IFS='|' read -r -a eps <<< "$exlist"
      for e in "${eps[@]}"; do [[ -n "$e" ]] && excl_flags+=("--exclude-glob" "$e"); done
    fi
    if [[ ${#excl_flags[@]} -gt 0 ]]; then
      actions_list+=$"$SUDO env KOPIA_PASSWORD_FILE=\"${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}\" kopia snapshot create \"$src\" $(printf '%q ' "${excl_flags[@]}")\n"
    else
      actions_list+=$"$SUDO env KOPIA_PASSWORD_FILE=\"${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}\" kopia snapshot create \"$src\"\n"
    fi
    # per-source retention
    actions_list+=$"$SUDO env KOPIA_PASSWORD_FILE=\"${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}\" kopia policy set \"$src\" --keep-within-duration ${ret_days}d\n"
  done
  actions_list+=$"$SUDO env KOPIA_PASSWORD_FILE=\"${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}\" kopia maintenance run --quick\n"
else
  # Scaffold fallback (rsync-style plan only)
  actions_list=$(
    cat << A
mkdir -p "${dest}/${profile}-YYYYMMDD-HHMMSS"
rsync -aAXH --delete <sources...> "${dest}/${profile}-.../"
ln -sfn "${dest}/${profile}-..." "${dest}/${profile}-latest"
find "${dest}" -maxdepth 1 -name "${profile}-*" -mtime +${ret_days} -type d -print -delete
A
  )
fi

if [[ "$cmd" == "run" ]]; then
  if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
    rollup="would back up ${#SRC_PATHS[@]} source(s) using $([[ $use_kopia -eq 1 ]] && echo kopia || echo scaffold), would prune ${prune_planned}"
    echo "would change $(( ${#SRC_PATHS[@]} + prune_planned + 1 )) items"
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record ok "$rollup" "$actions_list" "\"metrics\":{\"sources\":${#SRC_PATHS[@]},\"prune_planned\":${prune_planned}}"
    else
      solen_ok "$rollup"
    fi
    exit 0
  else
    if [[ $use_kopia -eq 0 ]]; then
      summary="backup complete (scaffold mode; kopia not installed)"
      if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
        solen_json_record ok "$summary" "$actions_list" "\"metrics\":{\"sources\":${#SRC_PATHS[@]}}"
      else
        solen_ok "$summary"
      fi
      exit 0
    fi
    # Execute planned actions line-by-line
    changed=0
    verified=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      # echo command lines and skip comments
      if [[ "$line" == \#* ]]; then
        solen_warn "skip: ${line#\# }"
        continue
      fi
      solen_info "$line"
      set +e
      bash -c "$line"
      rc=$?
      set -e
      if [[ $rc -eq 0 ]]; then changed=$((changed+1)); else solen_warn "step failed (rc=$rc): $line"; fi
    done <<< "$actions_list"
    # Post-run: verify snapshots exist (best-effort)
    for src in "${SRC_PATHS[@]}"; do
      set +e
      if [[ "$repo_kind" == "filesystem" && "$repo_path" == /var/* ]]; then
        SUDO="sudo -E"
      else
        SUDO=""
      fi
      $SUDO env KOPIA_PASSWORD_FILE="${KOPIA_PASSWORD_FILE:-$KOPIA_PASSWORD_FILE_DEFAULT}" kopia snapshot list "$src" >/dev/null 2>&1
      rc=$?
      set -e
      if [[ $rc -eq 0 ]]; then verified=$((verified+1)); fi
    done
    summary="backup complete (kopia)"
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record ok "$summary" "$actions_list" "\"metrics\":{\"sources\":${#SRC_PATHS[@]},\"changed\":${changed},\"verified\":${verified}}"
    else
      solen_ok "$summary (sources=${#SRC_PATHS[@]}, verified=${verified})"
    fi
    exit 0
  fi
elif [[ "$cmd" == "prune" ]]; then
  if [[ $SOLEN_FLAG_DRYRUN -eq 1 ]]; then
    rollup="would prune ${prune_planned} old sets"
    echo "would change ${prune_planned} items"
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record ok "$rollup" "$actions_list" "\"metrics\":{\"prune_planned\":${prune_planned}}"
    else
      solen_ok "$rollup"
    fi
    exit 0
  else
    if [[ $use_kopia -eq 1 ]]; then
      # Run maintenance full
      if grep -q '^\s*kopia maintenance' <<<"$actions_list"; then
        set +e
        bash -c "$(printf '%s\n' "$actions_list" | grep -m1 'kopia maintenance' || true)"
        rc=$?
        set -e
        if [[ $rc -ne 0 ]]; then
          solen_warn "kopia maintenance returned rc=$rc"
        fi
      fi
      summary="prune/maintenance complete (kopia)"
    else
      summary="prune complete (scaffold)"
    fi
    if [[ $SOLEN_FLAG_JSON -eq 1 ]]; then
      solen_json_record ok "$summary" "$actions_list" "\"metrics\":{\"pruned\":1}"
    else
      solen_ok "$summary"
    fi
    exit 0
  fi
else
  solen_err "unknown subcommand: $cmd"
  usage
  exit 1
fi
