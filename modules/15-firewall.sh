#!/usr/bin/env bash
# 15-firewall - ufw with a deny-incoming default. Detects the ACTUAL SSH port(s)
# (incl. socket-activated) and allows them first, so enabling can't lock you out.
# Guarded by FIREWALL_APPLY="yes" because enabling a firewall wrong = lock-out.
set -euo pipefail
source "$BEDROCK_DIR/lib/common.sh"

export DEBIAN_FRONTEND=noninteractive
have ufw || { log "installing ufw"; apt-get update -qq; apt_install ufw; }

# Collect SSH ports from every source that might hold the real one.
detect_ssh_ports() {
  {
    [ -n "${SSH_PORT:-}" ] && echo "$SSH_PORT"
    sshd -T 2>/dev/null | awk '/^port /{print $2}'
    systemctl show ssh.socket -p Listen 2>/dev/null | tr ' ' '\n' | grep -oE ':[0-9]+$' | tr -d ':'
  } | grep -E '^[0-9]+$' | sort -un
}

mapfile -t ssh_ports < <(detect_ssh_ports)
if [ "${#ssh_ports[@]}" -eq 0 ]; then
  ssh_ports=(22)
  warn "could not detect the SSH port - falling back to 22. Set SSH_PORT in config.sh to be safe."
fi
log "SSH ports to allow: ${ssh_ports[*]}"

ufw default deny incoming  >/dev/null
ufw default allow outgoing >/dev/null
for p in "${ssh_ports[@]}"; do ufw allow "${p}/tcp" >/dev/null; done
for p in ${FIREWALL_TCP_ALLOW:-80 443}; do ufw allow "${p}/tcp" >/dev/null; done
for r in ${FIREWALL_EXTRA:-}; do ufw allow "$r" >/dev/null; done

if [ "${FIREWALL_APPLY:-no}" = "yes" ]; then
  ufw --force enable >/dev/null
  log "ufw enabled:"; ufw status verbose | sed 's/^/    /'
else
  warn "Rules staged but ufw NOT enabled (FIREWALL_APPLY != yes)."
  warn "Verify the SSH port above is correct, then set FIREWALL_APPLY=\"yes\" and re-run: ./bootstrap.sh 15-firewall"
fi
