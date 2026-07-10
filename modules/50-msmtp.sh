#!/usr/bin/env bash
# 50-msmtp - send-only system/cron mail via an external SMTP relay.
# Self-skips unless SMTP_HOST is set. Only the password comes from secret.env.
set -euo pipefail
source "$BEDROCK_DIR/lib/common.sh"

[ -n "${SMTP_HOST:-}" ] || { log "SMTP_HOST not set - skipping msmtp"; exit 0; }

# Password from the secrets file (never config.sh / git).
[ -f /opt/secrets/bedrock/secret.env ] && . /opt/secrets/bedrock/secret.env
[ -n "${SMTP_PASS:-}" ] || warn "SMTP_PASS missing in /opt/secrets/bedrock/secret.env - auth will fail until set."

export DEBIAN_FRONTEND=noninteractive
# Install each piece if missing (msmtp may already be present without the mta or
# the mail command, which is exactly the case on a migrated box).
have msmtp                     || { apt-get update -qq; apt_install msmtp ca-certificates; }
command -v sendmail >/dev/null || apt_install msmtp-mta
command -v mail >/dev/null     || apt_install mailutils

# 587 = STARTTLS, 465 = implicit TLS (SMTPS).
port="${SMTP_PORT:-587}"
starttls="on"; [ "${SMTP_TLS:-starttls}" = "smtps" ] && starttls="off"
from="${SMTP_FROM:-root@$(hostname -f 2>/dev/null || hostname)}"

# -- /etc/msmtprc (0600 - holds the password) ---------------------------------
backup_once /etc/msmtprc
backup_once /etc/aliases
{
  echo "# Managed by bedrock."
  echo "defaults"
  echo "auth           on"
  echo "tls            on"
  echo "tls_starttls   ${starttls}"
  echo "tls_trust_file /etc/ssl/certs/ca-certificates.crt"
  # Always send with the relay's own address below, ignoring root@host that
  # mail/cron/fail2ban pass. Keeps SPF valid so mail lands in the inbox.
  echo "allow_from_override off"
  echo "logfile        /var/log/msmtp.log"
  echo "aliases        /etc/aliases"
  echo
  echo "account        default"
  echo "host           ${SMTP_HOST}"
  echo "port           ${port}"
  echo "from           ${from}"
  echo "user           ${SMTP_USER:-}"
  echo "password       ${SMTP_PASS:-}"
} | write_if_changed /etc/msmtprc 600 && log "wrote /etc/msmtprc" || log "/etc/msmtprc already current"

# -- /etc/aliases - route local mail (root, cron, daemons) to a real inbox -----
if [ -n "${MAIL_TO:-}" ]; then
  {
    echo "# Managed by bedrock."
    echo "mailer-daemon: ${MAIL_TO}"
    echo "postmaster:    ${MAIL_TO}"
    echo "root:          ${MAIL_TO}"
    echo "default:       ${MAIL_TO}"
  } | write_if_changed /etc/aliases 644 && log "wrote /etc/aliases -> ${MAIL_TO}" || log "/etc/aliases already current"
fi

log "msmtp ready (relay ${SMTP_HOST}:${port}).  Test:  echo body | mail -s 'bedrock test' you@example.com"
