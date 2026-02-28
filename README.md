# N8N Deployment with Workers

Self-hosted N8N workflow automation with queue-based worker architecture.

## Architecture

- **PostgreSQL**: Data persistence
- **Redis**: Queue management
- **N8N Main**: Web UI and API server
- **N8N Workers**: Workflow execution (2 workers, scalable)

## Runtime Support

| Scenario | Host | Tool | Recommended |
|----------|------|------|-------------|
| Podman Quadlets | Linux + systemd | native systemd units | **Yes — Linux production** |
| Docker / podman-compose | Linux / macOS | `docker compose` / `podman compose` | macOS or Docker hosts |

> **Ubuntu 24.04 LTS:** `./init-project.sh` auto-detects Linux+systemd and defaults to Quadlets.
> Pass `--runtime=compose` to force compose instead.

---

## Quick Start

### Option A — Podman Quadlets (Recommended on Linux + systemd)

> Native systemd unit files managed by Podman — the recommended production approach on Ubuntu 24.04+ and any Linux host with systemd.

#### Prerequisites

- Podman >= 4.4
- Rootless Podman configured (`/etc/subuid` and `/etc/subgid` entries)
- systemd user session active

#### 1. Setup

```bash
./init-project.sh
```

On Linux+systemd this auto-selects Quadlets. Or run explicitly:

```bash
./init-project.sh --runtime=quadlets
```

This will:
1. Validate Podman version and rootless configuration
2. Create data directories
3. Install Quadlet unit files to `~/.config/containers/systemd/`
4. Enable linger for boot persistence
5. Start services in order: postgres → redis → n8n-main → workers

#### 2. Configure Environment

Edit `.env` before the first start:

```bash
nano .env
```

**Required changes:**

- `POSTGRES_PASSWORD`: Strong database password
- `N8N_PASSWORD`: Your N8N login password
- `N8N_HOST`: Your server IP address or domain
- `N8N_SECURE_COOKIE`: Set `false` for HTTP, `true` when behind an HTTPS reverse proxy

#### 3. Access N8N

Open browser: `http://YOUR_SERVER_IP:5678`

#### 4. Managing Quadlet Services

```bash
# Check status
systemctl --user is-active n8n-postgres n8n-redis n8n-main 'n8n-worker@1' 'n8n-worker@2'

# Start / Stop / Restart
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

---

### Option B — Docker or Podman (compose)

> Use this on macOS, Docker hosts, or when you explicitly prefer compose over Quadlets.

#### 1. Initial Setup

```bash
./init-project.sh --runtime=compose
```

The script auto-detects whether Docker or Podman is available.

#### 2. Configure Environment

```bash
nano .env
```

**Required changes:** `POSTGRES_PASSWORD`, `N8N_PASSWORD`, `N8N_HOST`, `N8N_SECURE_COOKIE`

#### 3. Start N8N

```bash
# Docker
docker compose up -d

# Podman
podman compose up -d
```

#### 4. Access N8N

Open browser: `http://YOUR_SERVER_IP:5678`

---

## Management Commands (Option B — compose)

### Start/Stop

```bash
# Start
docker compose up -d        # or: podman compose up -d

# Stop
docker compose down         # or: podman compose down

# Restart
docker compose restart      # or: podman compose restart
```

### Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f n8n-main
docker compose logs -f n8n-worker-1
```

### Status

```bash
# Container status
docker compose ps

# Health check
./scripts/health-check.sh

# Resource usage
docker stats      # or: podman stats
```

### Backup & Restore

```bash
# Create backup (Option A — Quadlets)
./podman/scripts/backup.sh

# Create backup (Option B — compose)
./scripts/backup.sh

# Backups are stored in: ./backups/
```

## Scaling Workers

For Option A (Quadlets), start additional worker instances:

```bash
systemctl --user start 'n8n-worker@3.service'
systemctl --user enable 'n8n-worker@3.service'   # persist across reboots
```

For Option B (compose), scale dynamically:

```bash
docker compose up -d --scale n8n-worker-1=4
```

## Troubleshooting

### Check container logs

```bash
# Option A — Quadlets
journalctl --user -u n8n-main --no-pager

# Option B — compose
docker compose logs n8n-main
```

### Restart specific service

```bash
# Option A — Quadlets
systemctl --user restart n8n-main.service

# Option B — compose
docker compose restart n8n-main
```

### Reset everything (Option B — compose)

```bash
docker compose down -v
rm -rf data/*
./init-project.sh --runtime=compose
```

## Security Notes

- Never commit `.env` file to Git
- Use strong passwords
- Consider using HTTPS with a reverse proxy (set `N8N_SECURE_COOKIE=true`)
- Regularly backup your data
- Keep container images updated

## Directory Structure

```
.
├── docker-compose.yml      # Services definition (compose)
├── init-project.sh         # Entry point: auto-detects Quadlets on Linux+systemd
├── .env                    # Environment variables (not in git)
├── .env.example            # Template for .env
├── data/                   # Persistent data (not in git)
│   ├── n8n/               # N8N workflows and credentials
│   ├── postgres/          # Database files
│   └── redis/             # Redis data
├── backups/               # Backup storage (not in git)
├── scripts/               # Option B (compose) management scripts
│   ├── setup.sh          # Initial setup (runtime-aware)
│   ├── backup.sh         # Backup automation
│   └── health-check.sh   # System health check
└── podman/                # Option A (Quadlets)
    ├── README.md          # Quadlet-specific documentation
    ├── quadlets/          # Systemd unit files
    └── scripts/           # Quadlet management scripts
        ├── setup-quadlets.sh
        ├── backup.sh
        └── health-check.sh
```

## Additional Resources

- [N8N Documentation](https://docs.n8n.io)
- [N8N Community](https://community.n8n.io)
- [Docker Documentation](https://docs.docker.com)
- [Podman Documentation](https://docs.podman.io)
- [Podman Quadlet Guide](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)

## License

See N8N license at: https://github.com/n8n-io/n8n/blob/master/LICENSE.md
