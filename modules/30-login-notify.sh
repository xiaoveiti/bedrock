#!/usr/bin/env bash
# 30-login-notify - systemd service that pushes a Pushover notification on every
# successful SSH login (reads journald, no rsyslog needed).
set -euo pipefail
source "$BEDROCK_DIR/lib/common.sh"

[ "${LOGIN_NOTIFY_ENABLE:-1}" = "1" ] || { log "login-notify disabled in config"; exit 0; }

[ -f /opt/secrets/bedrock/secret.env ] || \
  warn "/opt/secrets/bedrock/secret.env missing - create it (PUSHOVER_TOKEN/USER). Service runs but can't send until then."

install -D -m755 "$BEDROCK_DIR/files/bin/bedrock-notify"          /usr/local/sbin/bedrock-notify
install -D -m755 "$BEDROCK_DIR/files/login-notify/login-notify.sh" /usr/local/sbin/bedrock-login-notify

{
  echo "[Unit]"
  echo "Description=bedrock: Pushover notification on SSH login"
  echo "After=network-online.target systemd-journald.service"
  echo "Wants=network-online.target"
  echo
  echo "[Service]"
  echo "ExecStart=/usr/local/sbin/bedrock-login-notify"
  echo "Environment=\"LOGIN_NOTIFY_IGNORE_USERS=${LOGIN_NOTIFY_IGNORE_USERS:-}\""
  echo "Restart=always"
  echo "RestartSec=5"
  echo
  echo "[Install]"
  echo "WantedBy=multi-user.target"
} | write_if_changed /etc/systemd/system/bedrock-login-notify.service || true

systemctl daemon-reload
systemctl enable bedrock-login-notify.service >/dev/null 2>&1 || true
systemctl restart bedrock-login-notify.service
log "login-notify active (ignoring users: ${LOGIN_NOTIFY_IGNORE_USERS:-none})"
