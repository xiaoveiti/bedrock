# bedrock - per-server config. Copy to config.sh (gitignored) and edit.
# shellcheck disable=SC2034

# Which modules to run, in order. (50-msmtp self-skips unless SMTP_HOST is set.)
MODULES=(00-base 05-ssh-keys 10-hardening 15-firewall 20-fail2ban 30-login-notify 40-docker 50-msmtp)

# -- 00-base ------------------------------------------------------------------
TIMEZONE="Europe/Berlin"
BASE_PACKAGES="curl ca-certificates gnupg git tmux htop unattended-upgrades chrony"
UNATTENDED_UPGRADES="1"
AUTO_REBOOT_TIME="04:00"          # auto-reboot after security updates (empty = off)
JOURNALD_MAX_USE="500M"          # cap journal size (empty = leave default)
SWAP_SIZE=""                     # e.g. "2G" to create a swapfile (empty = skip)

# -- 05-ssh-keys --------------------------------------------------------------
SSH_KEYS_USER="root"
SSH_AUTHORIZED_KEYS=(
  # "ssh-ed25519 AAAA... you@laptop"
)

# -- 10-hardening -------------------------------------------------------------
BEDROCK_HOSTNAME=""              # e.g. "coco-cloud" (empty = leave unchanged)
SSH_APPLY="no"                  # "yes" to actually change SSH - read the lock-out note first!
SSH_PORT=""                     # e.g. "52066" (empty = leave unchanged)
SSH_PASSWORD_AUTH="no"          # "no" = key-only login
SSH_ROOT_LOGIN="prohibit-password"   # or "no" to forbid root over SSH entirely

# -- 15-firewall --------------------------------------------------------------
FIREWALL_APPLY="no"             # "yes" to actually enable ufw (verify SSH port first!)
FIREWALL_TCP_ALLOW="80 443"     # extra TCP ports to open
FIREWALL_EXTRA=""               # raw ufw rules, e.g. "from 1.2.3.4 to any port 5432"

# -- 20-fail2ban --------------------------------------------------------------
FAIL2BAN_BANTIME="1h"
FAIL2BAN_FINDTIME="10m"
FAIL2BAN_MAXRETRY="5"
FAIL2BAN_IGNOREIP=""            # your own IPs, space-separated (never ban yourself)
FAIL2BAN_PUSHOVER="0"           # "1" = Pushover ping on every ban (needs secret.env)
FAIL2BAN_RECIDIVE="1"           # "1" = long-ban repeat offenders
FAIL2BAN_RECIDIVE_BANTIME="1w"
FAIL2BAN_RECIDIVE_FINDTIME="1d"
FAIL2BAN_RECIDIVE_MAXRETRY="3"

# -- 30-login-notify ----------------------------------------------------------
LOGIN_NOTIFY_ENABLE="1"         # Pushover push on every successful SSH login

# -- 40-docker ----------------------------------------------------------------
DOCKER_USER=""                  # optional: user to add to the docker group

# -- 50-msmtp (external SMTP relay; skips if SMTP_HOST empty) ------------------
SMTP_HOST=""                    # e.g. "smtp.your-provider.tld"
SMTP_PORT="587"                 # 587 = STARTTLS, 465 = SMTPS
SMTP_TLS="starttls"             # "starttls" (587) or "smtps" (465)
SMTP_USER=""                    # SMTP login
SMTP_FROM=""                    # From: address (empty = root@<host>)
MAIL_TO=""                      # forward root/cron mail here (empty = off)
# SMTP_PASS goes in /opt/secrets/bedrock/secret.env, not here.
