# bedrock

![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Debian%2012%20%7C%2013-A81D33?logo=debian&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

Minimal, idempotent server bootstrap for fresh Debian boxes. Clone it, set a
per-server config, run it - and re-run any time to roll changes out.

## Quick start

```bash
apt install -y git
git clone https://github.com/xiaoveiti/bedrock /opt/bedrock
cd /opt/bedrock
cp config.example.sh config.sh          # edit: hostname, ssh port, fail2ban…
# put your Pushover secrets on the server (NOT in git):
install -D -m600 secret.env.example /opt/secrets/bedrock/secret.env
$EDITOR /opt/secrets/bedrock/secret.env

./bootstrap.sh                          # run all modules
./bootstrap.sh 20-fail2ban              # …or just one module
```

Everything is **idempotent** - safe to run repeatedly. `git pull && ./bootstrap.sh`
rolls improvements onto existing servers.

## Layout

| Path | What |
|------|------|
| `bootstrap.sh` | orchestrator - runs the modules listed in `config.sh` |
| `lib/common.sh` | shared shell helpers |
| `modules/*.sh` | one file per concern, run in order |
| `files/` | assets the modules install |
| `config.example.sh` -> `config.sh` | per-server settings (gitignored) |
| `secret.env.example` -> `/opt/secrets/bedrock/secret.env` | secrets (gitignored, chmod 600) |

## Modules

- **00-base** - packages, timezone, automatic security updates (+ optional
  off-peak auto-reboot), `needrestart` in auto mode, journald size cap, and an
  optional swapfile.
- **05-ssh-keys** - install authorized keys (runs before hardening so key-only
  can't lock you out). Appends, never wipes.
- **10-hardening** - hostname, SSH port (handles `ssh.socket`), key-only auth,
  root policy, plus `MaxAuthTries` / `LoginGraceTime` / no X11 forwarding. SSH
  changes only apply with `SSH_APPLY="yes"`, and only after `sshd -t` passes, so
  a run can't silently lock you out.
- **15-firewall** - ufw, deny-incoming default. Detects the real SSH port(s) and
  allows them first. Only enables with `FIREWALL_APPLY="yes"`.
- **20-fail2ban** - SSH brute-force protection (journald backend). Takes over an
  existing install; your old `jail.local` is backed up first.
- **30-login-notify** - systemd service that sends a Pushover push on every
  successful SSH login (user + source IP), read straight from journald.
- **40-docker** - Docker Engine + compose plugin from Docker's official repo.
- **50-msmtp** - route system/cron mail through an external SMTP relay
  (send-only). Self-skips unless `SMTP_HOST` is set; password from `secret.env`.

Monitoring (telegraf/influxdb/grafana) is intentionally **not** here - that
belongs in its own Docker stack. bedrock just gets the host ready.

Two safety gates default to off - `SSH_APPLY` and `FIREWALL_APPLY` - so a first
run configures things without risking lock-out. Set them to `"yes"` once the SSH
port is confirmed.

## Configuration - where variables live

Two files, both per-server and **gitignored**:

- **`config.sh`** (copy of `config.example.sh`, in the repo dir) - all
  non-secret settings. Fully commented; edit and you're done.
- **`/opt/secrets/bedrock/secret.env`** (copy of `secret.env.example`) - secrets
  only, `root:root` `600`, same convention as the Docker stacks
  (`/opt/secrets/<app>/.env`).

### `config.sh`

| Module | Variable | Example | Meaning |
|--------|----------|---------|---------|
| - | `MODULES` | `(00-base 10-hardening …)` | which modules run, in order |
| 00-base | `TIMEZONE` | `Europe/Berlin` | system timezone |
| 00-base | `AUTO_REBOOT_TIME` | `04:00` | auto-reboot after security updates (empty = off) |
| 00-base | `JOURNALD_MAX_USE` | `500M` | cap journal size |
| 00-base | `SWAP_SIZE` | `2G` | create a swapfile (empty = skip) |
| 05-ssh-keys | `SSH_KEYS_USER` | `root` | who the keys belong to |
| 05-ssh-keys | `SSH_AUTHORIZED_KEYS` | `("ssh-ed25519 … you")` | public keys to authorize |
| 10-hardening | `BEDROCK_HOSTNAME` | `coco-cloud` | set the hostname (empty = leave) |
| 10-hardening | `SSH_APPLY` | `yes` | **gate** - actually change SSH |
| 10-hardening | `SSH_PORT` | `52066` | SSH port (handles `ssh.socket`) |
| 10-hardening | `SSH_PASSWORD_AUTH` | `no` | `no` = key-only |
| 10-hardening | `SSH_ROOT_LOGIN` | `prohibit-password` | or `no` |
| 15-firewall | `FIREWALL_APPLY` | `yes` | **gate** - actually enable ufw |
| 15-firewall | `FIREWALL_TCP_ALLOW` | `80 443` | extra open TCP ports |
| 20-fail2ban | `FAIL2BAN_BANTIME` / `…FINDTIME` / `…MAXRETRY` | `1h` / `10m` / `5` | ban policy |
| 20-fail2ban | `FAIL2BAN_IGNOREIP` | `1.2.3.4` | never ban these IPs |
| 20-fail2ban | `FAIL2BAN_PUSHOVER` | `1` | Pushover ping on ban |
| 20-fail2ban | `FAIL2BAN_RECIDIVE` | `1` | long-ban repeat offenders |
| 30-login-notify | `LOGIN_NOTIFY_ENABLE` | `1` | push on SSH login |
| 40-docker | `DOCKER_USER` | `deploy` | add a user to the docker group |
| 50-msmtp | `SMTP_HOST` / `SMTP_PORT` / `SMTP_TLS` | `mx…net` / `587` / `starttls` | relay |
| 50-msmtp | `SMTP_USER` / `SMTP_FROM` / `MAIL_TO` | | login / from / where root mail goes |

### `/opt/secrets/bedrock/secret.env`

| Variable | Used by | Meaning |
|----------|---------|---------|
| `PUSHOVER_USER` | login-notify, fail2ban | your Pushover user key |
| `PUSHOVER_TOKEN` | login-notify, fail2ban | Pushover application token |
| `SMTP_PASS` | 50-msmtp | SMTP relay password |

## Notifications (Pushover)

`login-notify` and the optional fail2ban ban action send via [Pushover](https://pushover.net).
You need two values:

- **`PUSHOVER_USER`** - your account/user key (top of the pushover.net dashboard).
  Identifies *who* receives.
- **`PUSHOVER_TOKEN`** - an *Application* token (pushover.net -> *Create an
  Application*, e.g. "bedrock"). Identifies *the sender* (name + icon shown on
  the push).

One "bedrock" application token is reused across **all** your servers - the
hostname is included in each message, so you always know which box it came from.

## Secrets

Secrets live at `/opt/secrets/bedrock/secret.env` (root, `600`) - the same place
the Docker stacks keep theirs (`/opt/secrets/<app>/.env`). The repo only ships a
template. Safe to make the repo public: no secrets or server-specifics are
committed (`config.sh` and `secret.env` are gitignored).

```bash
install -D -m600 secret.env.example /opt/secrets/bedrock/secret.env
$EDITOR /opt/secrets/bedrock/secret.env      # PUSHOVER_USER + PUSHOVER_TOKEN
```
