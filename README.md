# N8N Deployment

Self-hosted N8N workflow automation with queue-based worker architecture, deployed via Podman Quadlets on Linux + systemd.

## Architecture

- **PostgreSQL** — data persistence
- **Redis** — queue management
- **N8N Main** — web UI and API server (port 5678)
- **N8N Workers** — workflow execution (2 workers, scalable)

## Requirements

- Linux host with systemd (Ubuntu 24.04 LTS recommended)
- Podman >= 4.4
- Rootless Podman configured (`/etc/subuid` and `/etc/subgid` entries)

## Setup

### 1. Configure Environment

```bash
cp .env.example .env
nano .env
```

**Required changes:**

- `POSTGRES_PASSWORD` — strong database password
- `N8N_PASSWORD` — your N8N login password
- `N8N_HOST` — your server IP address or domain
- `N8N_SECURE_COOKIE` — `false` for HTTP, `true` behind an HTTPS reverse proxy

### 2. Run Setup

```bash
./setup.sh
```

This will:

1. Validate Podman version and rootless configuration
2. Create data directories
3. Install Quadlet unit files to `~/.config/containers/systemd/`
4. Enable linger for boot persistence
5. Start services in order: postgres → redis → n8n-main → workers

> **First run:** PostgreSQL initialisation takes up to 2 minutes. The n8n image pull
> may take several minutes depending on your connection. Subsequent starts are fast.

### 3. Access N8N

Open browser: `http://YOUR_SERVER_IP:5678`

---

## Service Management

```bash
# Check status
systemctl --user is-active n8n-postgres n8n-redis n8n-main 'n8n-worker@1' 'n8n-worker@2'

# Start / stop / restart
systemctl --user start n8n-main.service
systemctl --user stop n8n-main.service
systemctl --user restart n8n-main.service

# View logs
journalctl --user -u n8n-main --lines=30 --no-pager
journalctl --user -u 'n8n-worker@1' --follow

# Health check
./podman/scripts/health-check.sh

# Backup
./podman/scripts/backup.sh
```

## Scaling Workers

Start additional worker instances:

```bash
systemctl --user start 'n8n-worker@3.service'
```

> Extra instances beyond `@1` and `@2` do not auto-start after reboot. To make them
> permanent, add the corresponding `start` call to `podman/scripts/setup-quadlets.sh`.

---

## Troubleshooting

### `Failed to enable unit: Unit … is transient or generated`

Quadlet units live in a read-only generated directory. **Never use `systemctl enable`** on them.
Boot persistence is automatic via `WantedBy=default.target` + `loginctl enable-linger`.
Use `systemctl --user start` to bring units up manually.

### `n8n-main.service` fails or keeps restarting

Check the logs:

```bash
journalctl --user -xeu n8n-main.service --no-pager | tail -50
podman logs n8n-main
```

Common causes:

- **Wrong `.env` values** — verify `POSTGRES_PASSWORD`, `N8N_USER`, `N8N_PASSWORD` are set correctly
- **Database not ready** — postgres takes up to 2 minutes on first run; re-run setup if it timed out early

### Reset everything

```bash
systemctl --user stop n8n-main 'n8n-worker@1' 'n8n-worker@2' n8n-redis n8n-postgres
podman volume rm n8n-data n8n-postgres n8n-redis
rm ~/.config/containers/systemd/n8n-*.{network,volume,container}
systemctl --user daemon-reload
./setup.sh
```

---

## Backup & Restore

```bash
./podman/scripts/backup.sh
```

Backups are written to `backups/` and include a full PostgreSQL dump, N8N data, and a copy of `.env`.
The last 7 backups are retained automatically.

---

## Security Notes

- Never commit `.env` to Git
- Use strong passwords
- Consider HTTPS with a reverse proxy (`N8N_SECURE_COOKIE=true`)
- Keep container images updated with periodic `podman pull n8nio/n8n:latest` + restart

---

## Directory Structure

```text
.
├── setup.sh                # Entry point
├── .env                    # Environment variables (not in git)
├── .env.example            # Template for .env
├── backups/                # Backup storage (not in git)
├── data/                   # Persistent data (not in git)
└── podman/
    ├── README.md           # Quadlet reference documentation
    ├── quadlets/           # Systemd unit files
    │   ├── n8n-network.network
    │   ├── n8n-postgres.volume
    │   ├── n8n-redis.volume
    │   ├── n8n-data.volume
    │   ├── n8n-postgres.container
    │   ├── n8n-redis.container
    │   ├── n8n-main.container
    │   └── n8n-worker@.container
    └── scripts/
        ├── setup-quadlets.sh
        ├── backup.sh
        └── health-check.sh
```

---

## Additional Resources

- [N8N Documentation](https://docs.n8n.io)
- [Podman Quadlet Guide](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)

## License

See [N8N license](https://github.com/n8n-io/n8n/blob/master/LICENSE.md).
