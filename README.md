# N8N Deployment with Workers

Self-hosted N8N workflow automation with queue-based worker architecture.

## Architecture

- **PostgreSQL**: Data persistence
- **Redis**: Queue management
- **N8N Main**: Web UI and API server
- **N8N Workers**: Workflow execution (2 workers, scalable)

## Quick Start

### 1. Initial Setup

```bash
./scripts/setup.sh
```

This will:

- Create necessary directories
- Set proper permissions
- Copy `.env.example` to `.env`
- Pull Docker images

### 2. Configure Environment

Edit `.env` and set your values:

```bash
nano .env
```

**Required changes:**

- `POSTGRES_PASSWORD`: Strong database password
- `N8N_PASSWORD`: Your N8N login password
- `N8N_HOST`: Your server IP address or domain

### 3. Start N8N

```bash
docker compose up -d
```

### 4. Access N8N

Open browser: `http://YOUR_SERVER_IP:5678`

Login with credentials from `.env` file.

## Management Commands

### Start/Stop

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart
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
docker stats
```

### Backup & Restore

```bash
# Create backup
./scripts/backup.sh

# Backups are stored in: ./backups/
```

## Scaling Workers

Edit `docker-compose.yml` and add more worker services, or scale dynamically:

```bash
docker compose up -d --scale n8n-worker-1=4
```

## Troubleshooting

### Check container logs

```bash
docker compose logs n8n-main
```

### Restart specific service

```bash
docker compose restart n8n-main
```

### Reset everything

```bash
docker compose down -v
rm -rf data/*
./scripts/setup.sh
```

## Security Notes

- Never commit `.env` file to Git
- Use strong passwords
- Consider using HTTPS with reverse proxy
- Regularly backup your data
- Keep Docker images updated

## Directory Structure

```
.
├── docker-compose.yml      # Docker services definition
├── .env                    # Environment variables (not in git)
├── .env.example           # Template for .env
├── data/                  # Persistent data (not in git)
│   ├── n8n/              # N8N workflows and credentials
│   ├── postgres/         # Database files
│   └── redis/            # Redis data
├── backups/              # Backup storage (not in git)
├── scripts/              # Management scripts
│   ├── setup.sh         # Initial setup
│   ├── backup.sh        # Backup automation
│   └── health-check.sh  # System health check
└── README.md            # This file
```

## Additional Resources

- [N8N Documentation](https://docs.n8n.io)
- [N8N Community](https://community.n8n.io)
- [Docker Documentation](https://docs.docker.com)

## License

See N8N license at: https://github.com/n8n-io/n8n/blob/master/LICENSE.md
