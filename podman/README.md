# N8N Podman Quadlets

Deploy N8N using native Podman Quadlets — systemd unit files that manage containers as first-class services.

## Requirements

- **Linux host with systemd** (Quadlets do NOT work on macOS; use `./init-project.sh --runtime=compose` on macOS)
- **Podman >= 4.4** (built-in Quadlet generator)
- **Rootless Podman** configured: entries in `/etc/subuid` and `/etc/subgid`
- Active systemd user session (`loginctl enable-linger <user>` handled by setup script)

## Setup

### 1. Configure Environment

The setup script exits on first run if `.env` isn't ready — configure it first:

```bash
cp .env.example .env
nano .env
```

Set at minimum: `POSTGRES_PASSWORD`, `N8N_PASSWORD`, `N8N_HOST`, `N8N_SECURE_COOKIE`.

### 2. Run Setup

From the **project root**:

```bash
./init-project.sh --runtime=quadlets
```

Or directly:

```bash
./podman/scripts/setup-quadlets.sh
```

The script:
1. Validates Podman version and rootless configuration
2. Creates `data/n8n`, `data/postgres`, `data/redis`, `backups/`
3. Copies Quadlet files from `podman/quadlets/` to `~/.config/containers/systemd/`, substituting the absolute repo path
4. Runs `loginctl enable-linger` for boot persistence
5. Runs `systemctl --user daemon-reload` to trigger the Quadlet generator
6. Starts services in order: postgres → redis → n8n-main → workers

> **First run:** PostgreSQL initialisation takes up to 2 minutes. The n8n image pull
> may take several minutes depending on your connection. Subsequent starts are fast.

## Unit Files

| File | Type | Description |
|------|------|-------------|
| `n8n-network.network` | Network | Bridge network shared by all containers |
| `n8n-postgres.volume` | Volume | Bind-mount for PostgreSQL data |
| `n8n-redis.volume` | Volume | Bind-mount for Redis data |
| `n8n-data.volume` | Volume | Bind-mount for N8N workflows/credentials |
| `n8n-postgres.container` | Container | PostgreSQL 15 |
| `n8n-redis.container` | Container | Redis 7 |
| `n8n-main.container` | Container | N8N main (UI + API, port 5678) |
| `n8n-worker@.container` | Template | N8N worker — instances: `@1`, `@2`, `@N` |

## Service Management

```bash
# Check all N8N service status
systemctl --user list-units | grep n8n

# Is active?
systemctl --user is-active n8n-postgres n8n-redis n8n-main 'n8n-worker@1' 'n8n-worker@2'

# Start / stop / restart individual services
systemctl --user start n8n-main.service
systemctl --user stop n8n-main.service
systemctl --user restart n8n-main.service

# View logs
journalctl --user -u n8n-main --lines=50 --no-pager
journalctl --user -u 'n8n-worker@1' --follow

# Full health check
./podman/scripts/health-check.sh
```

## Scaling Workers

Start additional worker instances by incrementing the instance number:

```bash
systemctl --user start 'n8n-worker@3.service'
```

> **Note:** `systemctl enable` does not work on quadlet-generated units — they are transient.
> To make extra instances permanent, add the corresponding `start` calls to `podman/scripts/setup-quadlets.sh`.

Stop a worker:

```bash
systemctl --user stop 'n8n-worker@2.service'
```

## Backup

```bash
./podman/scripts/backup.sh
```

Backups are written to `../backups/n8n_backup_<timestamp>/` and include:
- `postgres_dump.sql` — full database dump
- `n8n_data.tar.gz` — N8N workflows and credentials
- `.env.backup` — environment file copy
- `backup_info.txt` — metadata

The last 7 backups are retained automatically.

## DNS / Hostname Note

`ContainerName=postgres` and `ContainerName=redis` are set so container hostnames match the values in `.env` and `docker-compose.yml`. No `.env` changes are needed when switching between Scenario A and Scenario B.

## SELinux Note

Volume mounts use the `:Z` flag (e.g., `Volume=n8n-data.volume:/home/node/.n8n:Z`), which relabels the volume for SELinux on RHEL/Fedora. This flag is silently ignored on non-SELinux systems.

## Uninstalling

```bash
# Stop all N8N services
systemctl --user stop n8n-main 'n8n-worker@1' 'n8n-worker@2' n8n-redis n8n-postgres

# Remove installed unit files
rm ~/.config/containers/systemd/n8n-*.{network,volume,container}

# Reload daemon (removes generated units)
systemctl --user daemon-reload
```

> **Note:** `systemctl disable` does not work on quadlet-generated units. Removing the unit
> files and reloading the daemon is the correct way to unregister them.
