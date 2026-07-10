#!/usr/bin/env bash
# Shared helpers for bedrock modules.

_c_grn=$'\033[1;32m'; _c_ylw=$'\033[1;33m'; _c_red=$'\033[1;31m'; _c_dim=$'\033[2m'; _c_off=$'\033[0m'

log()  { printf '%s[bedrock]%s %s\n'  "$_c_grn" "$_c_off" "$*"; }
warn() { printf '%s[bedrock] WARN:%s %s\n' "$_c_ylw" "$_c_off" "$*" >&2; }
die()  { printf '%s[bedrock] ERROR:%s %s\n' "$_c_red" "$_c_off" "$*" >&2; exit 1; }
hr()   { printf '%s%s%s\n' "$_c_dim" "--------------------------------------------------------" "$_c_off"; }

require_root() { [ "$(id -u)" -eq 0 ] || die "run as root (sudo)."; }
have()         { command -v "$1" >/dev/null 2>&1; }

# One-time backup of the pre-bedrock version of a file (skips if we already have
# one, so repeated runs don't pile up copies). Always returns 0.
backup_once() {
  if [ -f "$1" ] && ! compgen -G "$1.bedrock.bak.*" >/dev/null 2>&1; then
    cp -a "$1" "$1.bedrock.bak.$(date +%Y%m%d%H%M%S)" && log "backup: $1.bedrock.bak.*"
  fi
  return 0
}

apt_install() { DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"; }

# Write stdin to a file only if the content differs - keeps runs idempotent and
# avoids needless service restarts. Returns 0 if changed, 1 if unchanged.
write_if_changed() {
  local dest="$1" tmp; tmp="$(mktemp)"
  cat > "$tmp"
  if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"; return 1
  fi
  install -D -m "${2:-0644}" "$tmp" "$dest"; rm -f "$tmp"; return 0
}
