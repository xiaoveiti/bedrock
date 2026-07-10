#!/usr/bin/env bash
# 10-hardening - hostname + SSH (port, key-only, root policy).
# SSH changes only apply when SSH_APPLY=yes, and never before validating the
# config, so a run can't silently lock you out.
set -euo pipefail
source "$BEDROCK_DIR/lib/common.sh"

# -- Hostname -----------------------------------------------------------------
if [ -n "${BEDROCK_HOSTNAME:-}" ]; then
  cur="$(hostnamectl --static 2>/dev/null || hostname)"
  if [ "$cur" != "$BEDROCK_HOSTNAME" ]; then
    hostnamectl set-hostname "$BEDROCK_HOSTNAME"
    if grep -q '^127\.0\.1\.1' /etc/hosts; then
      sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t${BEDROCK_HOSTNAME}/" /etc/hosts
    else
      printf '127.0.1.1\t%s\n' "$BEDROCK_HOSTNAME" >> /etc/hosts
    fi
    log "hostname -> $BEDROCK_HOSTNAME"
  else
    log "hostname already $BEDROCK_HOSTNAME"
  fi
fi

# -- SSH ----------------------------------------------------------------------
apply_ssh() {
  local port="${SSH_PORT:-}"
  local socket_activated=no changed_sshd=0 changed_socket=0
  systemctl is-enabled ssh.socket >/dev/null 2>&1 && socket_activated=yes
  [ "$socket_activated" = yes ] && log "sshd is socket-activated (ssh.socket) -> port set on the socket unit"

  # 1) Firewall FIRST - never move the port before it's reachable.
  if [ -n "$port" ] && have ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "${port}/tcp" >/dev/null 2>&1 && log "ufw: allowed ${port}/tcp"
  fi

  # 2) sshd_config drop-in: auth hardening (+ Port when NOT socket-activated)
  {
    echo "# Managed by bedrock."
    [ -n "$port" ] && [ "$socket_activated" = no ] && echo "Port $port"
    echo "PasswordAuthentication ${SSH_PASSWORD_AUTH:-no}"
    echo "KbdInteractiveAuthentication no"
    echo "PermitRootLogin ${SSH_ROOT_LOGIN:-prohibit-password}"
    echo "MaxAuthTries ${SSH_MAX_AUTH_TRIES:-3}"
    echo "LoginGraceTime ${SSH_LOGIN_GRACE:-30}"
    echo "X11Forwarding no"
  } | write_if_changed /etc/ssh/sshd_config.d/10-bedrock.conf && changed_sshd=1 || changed_sshd=0

  # 3) socket drop-in: Port (when socket-activated)
  if [ -n "$port" ] && [ "$socket_activated" = yes ]; then
    printf '[Socket]\nListenStream=\nListenStream=%s\n' "$port" \
      | write_if_changed /etc/systemd/system/ssh.socket.d/10-bedrock-port.conf && changed_socket=1 || changed_socket=0
  fi

  # 4) Validate BEFORE touching the running service.
  if ! sshd -t 2>/tmp/bedrock-sshd-test; then
    warn "sshd -t failed - nothing restarted:"; sed 's/^/    /' /tmp/bedrock-sshd-test >&2
    die "aborting SSH change (invalid config)."
  fi

  # 5) Apply.
  if [ "$changed_socket" = 1 ]; then
    systemctl daemon-reload
    systemctl restart ssh.socket && log "ssh.socket restarted -> listening on ${port}"
  fi
  if [ "$changed_sshd" = 1 ]; then
    systemctl reload ssh 2>/dev/null || systemctl restart ssh 2>/dev/null || true
    log "sshd config applied"
  fi
  [ "$changed_sshd" = 0 ] && [ "$changed_socket" = 0 ] && log "SSH already as configured"

  if [ -n "$port" ] && { [ "$changed_socket" = 1 ] || [ "$changed_sshd" = 1 ]; }; then
    hr
    warn "SSH is now on port ${port}."
    warn "-> OPEN A SECOND TERMINAL AND TEST NOW, before closing this session:"
    warn "     ssh -p ${port} ${SUDO_USER:-<user>}@<this-host>"
    warn "  If it fails, your current session is still open to fix it."
    hr
  fi
}

if [ "${SSH_APPLY:-no}" = "yes" ]; then
  apply_ssh
else
  warn "SSH changes skipped (SSH_APPLY != yes)."
  warn "Set SSH_APPLY=\"yes\" in config.sh once you've set SSH_PORT and understood the lock-out note."
fi

log "hardening done"
