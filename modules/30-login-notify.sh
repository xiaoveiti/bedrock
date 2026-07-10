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

write_if_changed /etc/systemd/system/bedrock-login-notify.service <<'EOF' || true
[Unit]
Description=bedrock: Pushover notification on SSH login
After=network-online.target systemd-journald.service
Wants=network-online.target

[Service]
ExecStart=/usr/local/sbin/bedrock-login-notify
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now bedrock-login-notify.service >/dev/null 2>&1 || systemctl restart bedrock-login-notify.service
log "login-notify active (systemd: bedrock-login-notify)"
