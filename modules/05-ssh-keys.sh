#!/usr/bin/env bash
# 05-ssh-keys - install authorized SSH keys BEFORE hardening flips to key-only,
# so you can never lock yourself out. Appends (never wipes) existing keys.
set -euo pipefail
source "$BEDROCK_DIR/lib/common.sh"
# Sourced here (not just via env) because SSH_AUTHORIZED_KEYS is an array.
# shellcheck disable=SC1091
source "$BEDROCK_DIR/config.sh"

user="${SSH_KEYS_USER:-root}"
mapfile -t keys < <(printf '%s\n' "${SSH_AUTHORIZED_KEYS[@]:-}")
{ [ "${#keys[@]}" -gt 0 ] && [ -n "${keys[0]:-}" ]; } || { warn "no SSH_AUTHORIZED_KEYS set - skipping"; exit 0; }

home="$(getent passwd "$user" | cut -d: -f6)"
[ -n "$home" ] || die "user '$user' not found"
ak="$home/.ssh/authorized_keys"
install -d -m700 -o "$user" -g "$user" "$home/.ssh"
[ -f "$ak" ] || : > "$ak"
chmod 600 "$ak"; chown "$user:$user" "$ak"

added=0
for k in "${keys[@]}"; do
  [ -n "$k" ] || continue
  grep -qxF "$k" "$ak" || { printf '%s\n' "$k" >> "$ak"; added=$((added + 1)); }
done
log "ssh-keys: ${added} new key(s) added for ${user}"
