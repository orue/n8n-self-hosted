#!/bin/bash

# N8N Deployment Setup Script
# This script prepares the environment for N8N deployment

set -e

echo "=========================================="
echo "N8N Deployment Setup"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "Project directory: $PROJECT_DIR"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker first: https://docs.docker.com/engine/install/"
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not available${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is installed${NC}"
echo ""

# Create necessary directories
echo "Creating directory structure..."
mkdir -p data/n8n
mkdir -p data/postgres
mkdir -p data/redis
mkdir -p backups
mkdir -p config

echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# Set proper permissions for N8N data directory
echo "Setting permissions..."
sudo chown -R 1000:1000 data/n8n
echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    echo "Creating .env from .env.example..."
    
    if [ ! -f .env.example ]; then
        echo -e "${RED}Error: .env.example not found${NC}"
        exit 1
    fi
    
    cp .env.example .env
    
    echo -e "${YELLOW}⚠ IMPORTANT: Edit .env file and set your passwords and configuration${NC}"
    echo ""
    echo "You need to set:"
    echo "  - POSTGRES_PASSWORD"
    echo "  - N8N_PASSWORD"
    echo "  - N8N_HOST (your server IP or domain)"
    echo ""
    echo "Run: nano .env"
    echo ""
    
    read -p "Do you want to edit .env now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} .env
    fi
else
    echo -e "${GREEN}✓ .env file exists${NC}"
fi

# Set .env permissions
chmod 600 .env
echo -e "${GREEN}✓ .env permissions set to 600${NC}"
echo ""

# Validate .env file
echo "Validating .env configuration..."
if grep -q "CHANGE_ME" .env; then
    echo -e "${RED}Error: Please update all CHANGE_ME values in .env file${NC}"
    exit 1
fi

if grep -q "POSTGRES_PASSWORD=\s*$" .env; then
    echo -e "${RED}Error: POSTGRES_PASSWORD is empty${NC}"
    exit 1
fi

echo -e "${GREEN}✓ .env validation passed${NC}"
echo ""

# Pull Docker images
echo "Pulling Docker images..."
docker compose pull
echo -e "${GREEN}✓ Images pulled${NC}"
echo ""

echo "=========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review your .env file: nano .env"
echo "2. Start N8N: docker compose up -d"
echo "3. View logs: docker compose logs -f"
echo "4. Access N8N at: http://\$(grep N8N_HOST .env | cut -d '=' -f2):5678"
echo ""
echo "Useful commands:"
echo "  - Start: docker compose up -d"
echo "  - Stop: docker compose down"
echo "  - Logs: docker compose logs -f"
echo "  - Status: docker compose ps"
echo "  - Backup: ./scripts/backup.sh"
echo ""
