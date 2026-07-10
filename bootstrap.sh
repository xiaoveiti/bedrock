#!/usr/bin/env bash
# -- bedrock -------------------------------------------------------------------
# Minimal, idempotent server bootstrap. Clone onto a fresh box and run:
#
#   apt install -y git
#   git clone https://github.com/<you>/bedrock /opt/bedrock
#   cd /opt/bedrock && cp config.example.sh config.sh && cp secret.env.example secret.env
#   # edit config.sh + secret.env, then:
#   ./bootstrap.sh
#
# Re-runnable any time (each module checks before it changes anything). Pull the
# repo and re-run to roll improvements out to existing servers.
set -euo pipefail

BEDROCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BEDROCK_DIR

source "$BEDROCK_DIR/lib/common.sh"
require_root

# -- Config + secrets ---------------------------------------------------------
[ -f "$BEDROCK_DIR/config.sh" ] || die "config.sh missing - copy config.example.sh to config.sh and edit it."

# `set -a` exports everything sourced so the module subprocesses inherit it.
set -a
# shellcheck disable=SC1091
source "$BEDROCK_DIR/config.sh"
[ -f "$BEDROCK_DIR/secret.env" ] && source "$BEDROCK_DIR/secret.env"
set +a

: "${MODULES:?config.sh must define a MODULES array}"

# -- Run selected modules in order --------------------------------------------
log "bedrock on $(hostnamectl --static 2>/dev/null || hostname) - modules: ${MODULES[*]}"
only="${1:-}"   # optional: ./bootstrap.sh 20-fail2ban  -> run just one module

for m in "${MODULES[@]}"; do
  [ -n "$only" ] && [ "$m" != "$only" ] && continue
  f="$BEDROCK_DIR/modules/$m.sh"
  [ -f "$f" ] || { warn "module $m not found, skipping"; continue; }
  hr
  log "▶ module: $m"
  bash "$f"
done

hr
log " done"
