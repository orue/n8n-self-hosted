# n8n Self-Hosted — Podman Quadlets

> Production-ready, rootless n8n deployment on Linux using **Podman Quadlets** + **systemd**.
> Queue-based worker architecture with PostgreSQL and Redis. No Docker, no root.

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/n8n-io/n8n/blob/master/LICENSE.md)
[![Podman](https://img.shields.io/badge/Podman-%3E%3D4.4-892CA0)](https://podman.io)
[![n8n](https://img.shields.io/badge/n8n-latest-EA4B71)](https://n8n.io)
[![systemd](https://img.shields.io/badge/systemd-Quadlets-black)](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)

---

## Table of Contents

- [n8n Self-Hosted — Podman Quadlets](#n8n-self-hosted--podman-quadlets)
  - [Table of Contents](#table-of-contents)
  - [Architecture](#architecture)
  - [Requirements](#requirements)
  - [Quick Start](#quick-start)
    - [1. Clone and configure](#1-clone-and-configure)
    - [2. Run setup](#2-run-setup)
    - [3. Open n8n](#3-open-n8n)
  - [Auto-Start on Reboot](#auto-start-on-reboot)
  - [Service Management](#service-management)
  - [Updating n8n](#updating-n8n)
  - [Backup \& Restore](#backup--restore)
    - [Create a backup](#create-a-backup)
    - [Restore](#restore)
    - [Automate backups with cron](#automate-backups-with-cron)
  - [Scaling Workers](#scaling-workers)
  - [Security Hardening](#security-hardening)
  - [Troubleshooting](#troubleshooting)
    - [`Failed to enable unit: Unit … is transient or generated`](#failed-to-enable-unit-unit--is-transient-or-generated)
    - [`n8n-main` keeps restarting](#n8n-main-keeps-restarting)
    - [Permission error: `EACCES /home/node/.n8n/config`](#permission-error-eacces-homenoden8nconfig)
    - [Reset everything](#reset-everything)
  - [Directory Structure](#directory-structure)
  - [Additional Resources](#additional-resources)
  - [License](#license)

---

## Architecture

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./images/n8n-self-hosted-dark.png">
  <img alt="n8n-self-hosted" src="./images/n8n-self-hosted-light.png">
</picture>


| Unit (systemd)       | ContainerName        | Image                | Role                                          |
| -------------------- | -------------------- | -------------------- | --------------------------------------------- |
| `n8n-postgres`       | `postgres`           | `postgres:15-alpine` | Workflow data, credentials, execution history |
| `n8n-redis`          | `redis`              | `redis:7-alpine`     | Bull job queue (AOF persistence)              |
| `n8n-main`           | `n8n-main`           | `n8nio/n8n:latest`   | Web UI, REST API, webhook receiver            |
| `n8n-worker@1`, `@2` | `n8n-worker-1`, `-2` | `n8nio/n8n:latest`   | Execute queued workflow jobs                  |

**Why Podman Quadlets?**
Quadlets are systemd unit files managed by Podman's built-in generator — no Docker daemon, no docker-compose, no root. Containers run as your own user and restart automatically like any other systemd service.

---

## Requirements

| Requirement     | Notes                                                       |
| --------------- | ----------------------------------------------------------- |
| Linux + systemd | Ubuntu 24.04 LTS recommended                                |
| Podman >= 4.4   | Built-in Quadlet generator                                  |
| Rootless Podman | Entries in `/etc/subuid` & `/etc/subgid`                    |
| `openssl`       | For generating `N8N_ENCRYPTION_KEY` (usually pre-installed) |

> **macOS / Windows:** Quadlets require Linux + systemd and cannot run in a VM-based Podman Desktop session without a full Linux environment.

---

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/YOUR_USERNAME/n8n-deployment.git
cd n8n-deployment

cp .env.example .env
nano .env   # set passwords, host, timezone
```

**Required variables in `.env`:**

| Variable                 | Description                                                     |
| ------------------------ | --------------------------------------------------------------- |
| `POSTGRES_PASSWORD`      | Strong password for the PostgreSQL database                     |
| `DB_POSTGRESDB_PASSWORD` | **Must match** `POSTGRES_PASSWORD` — used by n8n to connect     |
| `N8N_PASSWORD`           | Your n8n admin login password                                   |
| `N8N_HOST`               | Server IP or domain (e.g. `192.168.1.100` or `n8n.example.com`) |
| `N8N_SECURE_COOKIE`      | `false` for HTTP · `true` when behind an HTTPS reverse proxy    |
| `N8N_ENCRYPTION_KEY`     | Leave blank — auto-generated on first run and saved to `.env`   |
| `TIMEZONE`               | Your local timezone (e.g. `America/New_York`)                   |

### 2. Run setup

```bash
./setup.sh
```

The script will:

1. Validate Podman version and rootless configuration
2. Create local `data/` directories
3. Install Quadlet unit files → `~/.config/containers/systemd/`
4. Auto-generate `N8N_ENCRYPTION_KEY` if not set
5. Enable linger for boot persistence (`loginctl enable-linger`)
6. Start services in order: `postgres` → `redis` → `n8n-main` → workers

> **First run:** PostgreSQL initialisation takes up to 2 minutes. The n8n image pull
> may take several minutes. Subsequent starts are fast (seconds).

### 3. Open n8n

```
http://YOUR_SERVER_IP:5678
```

Log in with the `N8N_USER` / `N8N_PASSWORD` values from `.env`.

---

## Auto-Start on Reboot

Boot persistence is built in. During setup, two things are configured automatically:

1. **`WantedBy=default.target`** in each Quadlet unit — tells systemd to start these services when the user's session target is reached.

2. **`loginctl enable-linger <user>`** — allows your systemd user session to start at boot even without an interactive login.

**Verify it's working:**

```bash
# Check linger status
loginctl show-user "$(whoami)" | grep Linger

# Simulate a reboot (stop all services, then reload — don't actually reboot)
systemctl --user stop n8n-main 'n8n-worker@1' 'n8n-worker@2' n8n-redis n8n-postgres
systemctl --user daemon-reload
systemctl --user start n8n-postgres n8n-redis n8n-main 'n8n-worker@1' 'n8n-worker@2'
```

> **Note:** Never use `systemctl --user enable` on Quadlet units — they are transient/generated
> and read-only. Boot persistence comes from `WantedBy=default.target`, not from `enable`.

---

## Service Management

```bash
# Status overview
systemctl --user is-active n8n-postgres n8n-redis n8n-main 'n8n-worker@1' 'n8n-worker@2'

# Full health check (containers + logs scan)
./podman/scripts/health-check.sh

# Start / stop / restart
systemctl --user start   n8n-main.service
systemctl --user stop    n8n-main.service
systemctl --user restart n8n-main.service

# Live logs
journalctl --user -u n8n-main --follow
journalctl --user -u 'n8n-worker@1' --lines=50 --no-pager

# All n8n units at once
systemctl --user list-units 'n8n-*'
```

---

## Updating n8n

```bash
./podman/scripts/update.sh
```

This will:

1. Prompt to run a backup first
2. Pull the latest `n8nio/n8n` image
3. Gracefully stop workers, then `n8n-main`
4. Start everything back up
5. Show before/after version numbers

**Pin to a specific version:**

```bash
./podman/scripts/update.sh --image n8nio/n8n:1.75.0
```

> To revert, run `update.sh --image n8nio/n8n:<previous-version>`.

---

## Backup & Restore

### Create a backup

```bash
./podman/scripts/backup.sh
```

Backups are written to `backups/n8n_backup_<timestamp>/` and include:

| File              | Contents                                         |
| ----------------- | ------------------------------------------------ |
| `postgres.dump`   | Full PostgreSQL dump (custom format, compressed) |
| `n8n_data.tar.gz` | n8n data directory (custom nodes, key cache)     |
| `.env.backup`     | Copy of your environment file (permissions: 600) |
| `backup_info.txt` | Metadata + restore instructions                  |

The last **7 backups** are retained automatically. Override with `--retention N`:

```bash
./podman/scripts/backup.sh --retention 14
```

### Restore

```bash
# 1. Stop n8n (leave postgres running)
systemctl --user stop n8n-main 'n8n-worker@1' 'n8n-worker@2'

# 2. Restore the database
podman exec -i postgres pg_restore -U n8n -d n8n --clean \
    < backups/n8n_backup_<timestamp>/postgres.dump

# 3. Restore n8n data directory
tar -xzf backups/n8n_backup_<timestamp>/n8n_data.tar.gz -C data

# 4. Restart n8n
systemctl --user start n8n-main 'n8n-worker@1' 'n8n-worker@2'
```

### Automate backups with cron

```bash
# Daily backup at 2 AM, keep last 14
crontab -e
# Add:
0 2 * * * /path/to/n8n-deployment/podman/scripts/backup.sh --retention 14 >> /var/log/n8n-backup.log 2>&1
```

---

## Scaling Workers

Start additional worker instances on demand:

```bash
systemctl --user start 'n8n-worker@3.service'
```

> Instances beyond `@1` and `@2` do not auto-start after reboot. To make them permanent,
> add the corresponding `start` call to `podman/scripts/setup-quadlets.sh`.

Stop a worker:

```bash
systemctl --user stop 'n8n-worker@2.service'
```

---

## Security Hardening

| Recommendation                                    | Status                                               |
| ------------------------------------------------- | ---------------------------------------------------- |
| Never commit `.env` to Git                        | `.gitignore` enforces this                           |
| `N8N_ENCRYPTION_KEY` set explicitly               | Auto-generated by `setup.sh` if blank                |
| Strong, unique passwords                          | Set in `.env`                                        |
| Containers run rootless (no root daemon)          | Podman default                                       |
| `UserNS=keep-id` prevents UID remapping surprises | Set in all n8n containers                            |
| HTTPS + reverse proxy                             | Set `N8N_SECURE_COOKIE=true` + configure nginx/Caddy |
| Firewall: restrict port 5678 to trusted IPs       | Recommended for production                           |
| Keep images updated                               | Use `update.sh` regularly                            |

**Reverse proxy example (Caddy):**

```caddyfile
n8n.example.com {
    reverse_proxy localhost:5678
}
```

Then set in `.env`:

```
N8N_HOST=n8n.example.com
N8N_PROTOCOL=https
N8N_SECURE_COOKIE=true
WEBHOOK_URL=https://n8n.example.com/
```

---

## Troubleshooting

### `Failed to enable unit: Unit … is transient or generated`

Never use `systemctl --user enable` on Quadlet units. They are generated at daemon-reload time
and are read-only. Boot persistence is automatic via `WantedBy=default.target`.

### `n8n-main` keeps restarting

```bash
journalctl --user -xeu n8n-main.service --no-pager | tail -50
podman logs n8n-main
```

Common causes:

- **`CHANGE_ME` still in `.env`** — setup.sh rejects this, but check manually
- **`DB_POSTGRESDB_PASSWORD` mismatch** — must equal `POSTGRES_PASSWORD` exactly
- **PostgreSQL not ready** — first run takes up to 2 min; re-run `setup.sh` if it timed out

### Permission error: `EACCES /home/node/.n8n/config`

The `UserNS=keep-id:uid=1000,gid=1000` line in the n8n container units maps the container's
`node` user (uid 1000) to your host user. If this is missing, the volume will be owned by a
high UID (~100000+) that n8n can't write to. Re-run `./setup.sh` to reinstall unit files.

### Reset everything

```bash
systemctl --user stop n8n-main 'n8n-worker@1' 'n8n-worker@2' n8n-redis n8n-postgres
podman volume rm n8n-data n8n-postgres n8n-redis 2>/dev/null || true
rm -f ~/.config/containers/systemd/n8n-*.{network,volume,container}
systemctl --user daemon-reload
./setup.sh
```

---

## Directory Structure

```
.
├── setup.sh                        # Entry point → delegates to setup-quadlets.sh
├── .env                            # Secrets (gitignored — copy from .env.example)
├── .env.example                    # Template
├── backups/                        # Backup storage (gitignored)
├── data/                           # Bind-mount data (gitignored)
│   ├── n8n/                        # n8n config, credentials, custom nodes
│   ├── postgres/                   # PostgreSQL data files
│   └── redis/                      # Redis AOF journal
└── podman/
    ├── README.md                   # Quadlet reference
    ├── quadlets/                   # systemd unit files
    │   ├── n8n-network.network     # Shared bridge network
    │   ├── n8n-postgres.volume     # Bind-mount: data/postgres
    │   ├── n8n-redis.volume        # Bind-mount: data/redis
    │   ├── n8n-data.volume         # Bind-mount: data/n8n
    │   ├── n8n-postgres.container  # PostgreSQL 15
    │   ├── n8n-redis.container     # Redis 7 (AOF)
    │   ├── n8n-main.container      # n8n UI + API
    │   └── n8n-worker@.container   # Worker template (@1, @2, …)
    └── scripts/
        ├── setup-quadlets.sh       # Install & start all services
        ├── update.sh               # Update n8n to a new version
        ├── backup.sh               # Backup DB, data, and config
        └── health-check.sh         # Check service + container health

```

---

## Additional Resources

- [n8n Documentation](https://docs.n8n.io)
- [n8n Community Forum](https://community.n8n.io)
- [Podman Quadlet Reference](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Rootless Podman Setup Guide](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)

---

## License

n8n is [fair-code](https://faircode.io) licensed. See the [n8n license](https://github.com/n8n-io/n8n/blob/master/LICENSE.md) for details.
The deployment scripts and configuration in this repository are released under the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).
