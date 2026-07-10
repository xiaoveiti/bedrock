#!/usr/bin/env bash
# 40-docker - Docker Engine + compose plugin from Docker's official repo.
set -euo pipefail
source "$BEDROCK_DIR/lib/common.sh"

if have docker && docker compose version >/dev/null 2>&1; then
  log "docker already installed ($(docker --version))"
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt_install ca-certificates curl gnupg

install -m0755 -d /etc/apt/keyrings
if [ ! -s /etc/apt/keyrings/docker.asc ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi

. /etc/os-release
write_if_changed /etc/apt/sources.list.d/docker.list <<EOF || true
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable
EOF

apt-get update -qq
apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

# Optionally let a non-root user run docker.
if [ -n "${DOCKER_USER:-}" ] && id "$DOCKER_USER" >/dev/null 2>&1; then
  usermod -aG docker "$DOCKER_USER" && log "added $DOCKER_USER to the docker group (re-login to take effect)"
fi

log "docker installed: $(docker --version)"
