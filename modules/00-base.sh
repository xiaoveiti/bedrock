#!/usr/bin/env bash
# 00-base - packages, timezone, automatic security updates.
set -euo pipefail
source "$BEDROCK_DIR/lib/common.sh"

export DEBIAN_FRONTEND=noninteractive
log "apt update"
apt-get update -qq

PKGS="${BASE_PACKAGES:-curl ca-certificates gnupg git tmux htop unattended-upgrades chrony}"
log "install: $PKGS"
apt_install $PKGS

# Timezone
if [ -n "${TIMEZONE:-}" ] && [ "$(cat /etc/timezone 2>/dev/null || true)" != "$TIMEZONE" ]; then
  log "timezone -> $TIMEZONE"
  timedatectl set-timezone "$TIMEZONE"
fi

# Cap the journal so logs can never fill the disk.
if [ -n "${JOURNALD_MAX_USE:-}" ]; then
  if printf '[Journal]\nSystemMaxUse=%s\n' "$JOURNALD_MAX_USE" | write_if_changed /etc/systemd/journald.conf.d/10-bedrock.conf; then
    systemctl restart systemd-journald || true
    log "journald SystemMaxUse -> $JOURNALD_MAX_USE"
  fi
fi

# Unattended security upgrades (auto-apply Debian security updates)
if [ "${UNATTENDED_UPGRADES:-1}" = "1" ]; then
  write_if_changed /etc/apt/apt.conf.d/20auto-upgrades <<'EOF' && log "enabled unattended-upgrades" || true
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
  systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
fi

# needrestart: restart services automatically after library upgrades (no prompt).
apt_install needrestart >/dev/null 2>&1 || true
if write_if_changed /etc/needrestart/conf.d/bedrock.conf <<'EOF' >/dev/null
$nrconf{restart} = 'a';
EOF
then log "needrestart -> auto"; fi

# Auto-reboot after unattended security upgrades (e.g. new kernel), off-peak.
if [ -n "${AUTO_REBOOT_TIME:-}" ]; then
  {
    echo 'Unattended-Upgrade::Automatic-Reboot "true";'
    echo 'Unattended-Upgrade::Automatic-Reboot-WithUsers "true";'
    printf 'Unattended-Upgrade::Automatic-Reboot-Time "%s";\n' "$AUTO_REBOOT_TIME"
  } | write_if_changed /etc/apt/apt.conf.d/51bedrock-reboot >/dev/null && log "auto-reboot at $AUTO_REBOOT_TIME" || true
fi

# Swapfile - prevents OOM kills on small boxes. Skips if any swap is already on.
if [ -n "${SWAP_SIZE:-}" ] && ! swapon --noheadings --show=NAME | grep -q .; then
  if [ ! -f /swapfile ]; then
    log "creating ${SWAP_SIZE} swapfile"
    fallocate -l "$SWAP_SIZE" /swapfile || die "fallocate failed - set SWAP_SIZE like 2G on a supported fs"
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
  fi
  swapon /swapfile 2>/dev/null || true
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  log "swap active (${SWAP_SIZE})"
fi

log "base done"
