#!/usr/bin/env bash
# Follow journald for successful SSH logins and push a notification for each.
# Matches on the message text (Accepted … for … from …) so it works whether the
# log comes from sshd or sshd-session.
set -uo pipefail
HOST="$(hostnamectl --static 2>/dev/null || hostname)"; HOST="${HOST%%.*}"

journalctl -f -n0 -o cat --grep 'Accepted .* for ' 2>/dev/null | while IFS= read -r line; do
  case "$line" in
    Accepted*)
      method="$(awk '{print $2}' <<<"$line")"
      user="$(awk '{for(i=1;i<=NF;i++) if($i=="for"){print $(i+1); exit}}' <<<"$line")"
      ip="$(awk '{for(i=1;i<=NF;i++) if($i=="from"){print $(i+1); exit}}' <<<"$line")"
      /usr/local/sbin/bedrock-notify \
        "SSH login · ${HOST}" \
        "${user:-?} from ${ip:-?} (${method:-?}) · $(date '+%d.%m %H:%M')" 0
      ;;
  esac
done
