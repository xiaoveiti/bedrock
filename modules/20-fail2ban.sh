#!/usr/bin/env bash
# 20-fail2ban - brute-force protection for SSH. Takes over any existing install
# idempotently (your old jail.local is backed up first).
set -euo pipefail
source "$BEDROCK_DIR/lib/common.sh"

export DEBIAN_FRONTEND=noninteractive
have fail2ban-client || { log "installing fail2ban"; apt-get update -qq; apt_install fail2ban; }

# bedrock-managed jail. backend=systemd -> reads journald directly (Debian 13).
backup_once /etc/fail2ban/jail.local
{
  echo "# Managed by bedrock - edit config.sh, not this file."
  echo "[DEFAULT]"
  echo "backend  = systemd"
  echo "bantime  = ${FAIL2BAN_BANTIME:-1h}"
  echo "findtime = ${FAIL2BAN_FINDTIME:-10m}"
  echo "maxretry = ${FAIL2BAN_MAXRETRY:-5}"
  echo "ignoreip = 127.0.0.1/8 ::1 ${FAIL2BAN_IGNOREIP:-}"
  if [ "${FAIL2BAN_PUSHOVER:-0}" = "1" ]; then
    echo "action   = %(action_)s"
    echo "           bedrock-pushover"
  fi
  echo
  echo "[sshd]"
  echo "enabled = true"
  echo "port    = ${SSH_PORT:-ssh}"
  if [ "${FAIL2BAN_RECIDIVE:-1}" = "1" ]; then
    # Repeat offenders (banned several times) get a long ban.
    echo
    echo "[recidive]"
    echo "enabled  = true"
    echo "bantime  = ${FAIL2BAN_RECIDIVE_BANTIME:-1w}"
    echo "findtime = ${FAIL2BAN_RECIDIVE_FINDTIME:-1d}"
    echo "maxretry = ${FAIL2BAN_RECIDIVE_MAXRETRY:-3}"
  fi
} | write_if_changed /etc/fail2ban/jail.local && log "wrote jail.local" || log "jail.local already current"

# Optional: Pushover ping whenever an IP is banned.
if [ "${FAIL2BAN_PUSHOVER:-0}" = "1" ]; then
  install -D -m755 "$BEDROCK_DIR/files/bin/bedrock-notify" /usr/local/sbin/bedrock-notify
  [ -f /opt/secrets/bedrock/secret.env ] || warn "FAIL2BAN_PUSHOVER=1 but /opt/secrets/bedrock/secret.env is missing."
  write_if_changed /etc/fail2ban/action.d/bedrock-pushover.conf <<'EOF' || true
[Definition]
actionban = /usr/local/sbin/bedrock-notify "fail2ban ban" "Banned <ip> · jail <name>" 1
EOF
fi

# Validate the config before (re)starting so a typo can't leave fail2ban down.
if fail2ban-client -t >/tmp/bedrock-f2b-test 2>&1; then
  systemctl enable fail2ban >/dev/null 2>&1 || true
  systemctl restart fail2ban
  log "fail2ban active - sshd jail on port ${SSH_PORT:-ssh}"
else
  warn "fail2ban config test failed - not restarted:"; sed 's/^/    /' /tmp/bedrock-f2b-test >&2
  die "aborting (fail2ban config invalid)."
fi
