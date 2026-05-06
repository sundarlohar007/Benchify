#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Benchify (PerformanceBench) Server — Bare Metal Install Script
# =============================================================================
# Single-command setup for Ubuntu 24.04+ or Debian 12+.
# Installs PostgreSQL 17, nginx, certbot, Rust server binary, systemd service.
#
# Usage:
#   bash install.sh                                    # Default HTTP-only setup
#   bash install.sh --domain benchify.example.com      # With Let's Encrypt TLS
#   bash install.sh --no-tls --data-dir /srv/benchify  # Custom data directory
#   bash install.sh --help                             # Show usage
# =============================================================================

# ── Color helpers ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

step()      { echo -e "${BLUE}[STEP]${NC} $*"; }
success()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn()      { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()     { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Defaults ──
DOMAIN=""
NO_TLS=false
DATA_DIR="/opt/benchify"
SERVER_BINARY="./target/release/server"

# ── Usage ──
usage() {
    cat <<EOF
Benchify Server Install Script

Usage: bash install.sh [OPTIONS]

Options:
  --domain <domain>     Domain name for Let's Encrypt TLS (e.g., benchify.example.com)
  --no-tls              Skip TLS setup, HTTP-only mode
  --data-dir <path>     Installation directory (default: /opt/benchify)
  --binary <path>       Path to server binary (default: ./target/release/server)
  --help                Show this help message

Environment Variables:
  POSTGRES_USER         Database user (default: benchify)
  POSTGRES_PASSWORD     Database password (auto-generated if not set)
  POSTGRES_DB           Database name (default: benchify)
  JWT_SECRET            JWT signing secret (auto-generated if not set)

Examples:
  bash install.sh --domain benchify.example.com
  bash install.sh --no-tls --binary /tmp/performancebench-server
EOF
    exit 0
}

# ── Parse arguments ──
while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)     DOMAIN="$2"; shift 2 ;;
        --no-tls)     NO_TLS=true; shift ;;
        --data-dir)   DATA_DIR="$2"; shift 2 ;;
        --binary)     SERVER_BINARY="$2"; shift 2 ;;
        --help)       usage ;;
        *)            error "Unknown option: $1. Use --help for usage." ;;
    esac
done

# ── Step 1: Detect OS ──
step "Detecting operating system..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        error "Unsupported OS: $ID. Benchify requires Ubuntu 24.04+ or Debian 12+."
    fi
    if [[ "$ID" == "ubuntu" && "${VERSION_ID%.*}" -lt 24 ]]; then
        error "Ubuntu $VERSION_ID is too old. Benchify requires Ubuntu 24.04+."
    fi
    if [[ "$ID" == "debian" && "${VERSION_ID%.*}" -lt 12 ]]; then
        error "Debian $VERSION_ID is too old. Benchify requires Debian 12+."
    fi
    success "OS detected: $NAME $VERSION_ID"
else
    error "Cannot detect OS. /etc/os-release not found."
fi

# ── Step 2: Install system packages ──
step "Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    postgresql-17 \
    nginx \
    certbot \
    python3-certbot-nginx \
    curl \
    libssl-dev \
    libpq-dev

# Ensure PostgreSQL is running
sudo systemctl enable postgresql
sudo systemctl start postgresql
success "System packages installed"

# ── Step 3: Configure PostgreSQL ──
step "Configuring PostgreSQL..."
PG_USER="${POSTGRES_USER:-benchify}"
PG_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -hex 32)}"
PG_DB="${POSTGRES_DB:-benchify}"

# Create user if not exists
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PG_USER'" | grep -q 1; then
    success "PostgreSQL user '$PG_USER' already exists"
else
    sudo -u postgres psql -c "CREATE USER \"$PG_USER\" WITH PASSWORD '$PG_PASSWORD';"
    success "PostgreSQL user '$PG_USER' created"
fi

# Create database if not exists
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$PG_DB'" | grep -q 1; then
    success "PostgreSQL database '$PG_DB' already exists"
else
    sudo -u postgres psql -c "CREATE DATABASE \"$PG_DB\" OWNER \"$PG_USER\";"
    success "PostgreSQL database '$PG_DB' created"
fi
success "PostgreSQL configured"

# ── Step 4: Create system user ──
step "Creating system user 'benchify'..."
if id "benchify" &>/dev/null; then
    success "System user 'benchify' already exists"
else
    sudo useradd -r -s /bin/false benchify
    success "System user 'benchify' created"
fi

# ── Step 5: Create directory structure ──
step "Creating directory structure at $DATA_DIR..."
sudo mkdir -p "$DATA_DIR/bin"
sudo mkdir -p "$DATA_DIR/uploads"
sudo mkdir -p "$DATA_DIR/migrations"
sudo chown -R benchify:benchify "$DATA_DIR"
success "Directory structure created"

# ── Step 6: Install server binary ──
step "Installing server binary..."
if [ -f "$SERVER_BINARY" ]; then
    sudo cp "$SERVER_BINARY" "$DATA_DIR/server"
    sudo chmod +x "$DATA_DIR/server"
    sudo chown benchify:benchify "$DATA_DIR/server"
    success "Server binary copied from $SERVER_BINARY"
elif [ -n "${GITHUB_RELEASE_URL:-}" ]; then
    # Download from GitHub Releases (when available)
    TEMP_DIR=$(mktemp -d)
    curl -sSL "$GITHUB_RELEASE_URL" -o "$TEMP_DIR/server.tar.gz"
    tar -xzf "$TEMP_DIR/server.tar.gz" -C "$TEMP_DIR"
    sudo cp "$TEMP_DIR/server" "$DATA_DIR/server"
    sudo chmod +x "$DATA_DIR/server"
    sudo chown benchify:benchify "$DATA_DIR/server"
    rm -rf "$TEMP_DIR"
    success "Server binary downloaded from GitHub Releases"
else
    warn "Server binary not found at $SERVER_BINARY"
    warn "Build the server first: cd performancebench-server && cargo build --release"
    warn "Then copy target/release/server to $DATA_DIR/server"
    warn "Or set GITHUB_RELEASE_URL environment variable for automatic download"
fi

# ── Step 7: Copy migrations ──
step "Copying database migrations..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_SRC="${SCRIPT_DIR}/../migrations"
if [ -d "$MIGRATIONS_SRC" ]; then
    sudo cp -r "$MIGRATIONS_SRC"/* "$DATA_DIR/migrations/"
    sudo chown -R benchify:benchify "$DATA_DIR/migrations"
    success "Migrations copied from $MIGRATIONS_SRC"
else
    warn "Migrations directory not found at $MIGRATIONS_SRC"
    warn "Migrations will need to be copied manually"
fi

# ── Step 8: Create environment file ──
step "Creating environment configuration..."
JWT_SECRET="${JWT_SECRET:-$(openssl rand -hex 32)}"

if [ -f "$DATA_DIR/.env" ]; then
    success "Environment file already exists at $DATA_DIR/.env"
else
    sudo tee "$DATA_DIR/.env" > /dev/null <<ENVEOF
# Benchify Server Configuration
# Generated by install.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")

HOST=0.0.0.0
PORT=3000

# Database
DATABASE_URL=postgres://${PG_USER}:${PG_PASSWORD}@localhost:5432/${PG_DB}

# JWT signing secret (auto-generated)
JWT_SECRET=${JWT_SECRET}

# TLS (managed by nginx — leave these empty)
# TLS_CERT_PATH=
# TLS_KEY_PATH=

# SSO (configure via admin dashboard)
SSO_ENABLED=false
SSO_REDIRECT_BASE_URL=https://${DOMAIN:-benchify.example.com}

ENVEOF
    sudo chown benchify:benchify "$DATA_DIR/.env"
    sudo chmod 600 "$DATA_DIR/.env"
    success "Environment file created at $DATA_DIR/.env"
    success "  Database user: $PG_USER"
    success "  Database name: $PG_DB"
    success "  JWT secret:    (generated, stored in .env)"
fi

# ── Step 9: Install systemd service ──
step "Installing systemd service..."
SYSTEMD_SRC="${SCRIPT_DIR}/performancebench-server.service"
if [ -f "$SYSTEMD_SRC" ]; then
    sudo cp "$SYSTEMD_SRC" /etc/systemd/system/performancebench-server.service
    sudo sed -i "s|/opt/benchify|$DATA_DIR|g" /etc/systemd/system/performancebench-server.service
    sudo systemctl daemon-reload
    sudo systemctl enable performancebench-server
    success "Systemd service installed and enabled"
else
    # Create service from template
    sudo tee /etc/systemd/system/performancebench-server.service > /dev/null <<UNITEOF
[Unit]
Description=PerformanceBench Server
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=benchify
Group=benchify
WorkingDirectory=${DATA_DIR}
ExecStart=${DATA_DIR}/server
Restart=on-failure
RestartSec=5
EnvironmentFile=${DATA_DIR}/.env
StandardOutput=journal
StandardError=journal
SyslogIdentifier=performancebench-server

[Install]
WantedBy=multi-user.target
UNITEOF
    sudo systemctl daemon-reload
    sudo systemctl enable performancebench-server
    success "Systemd service created and enabled"
fi

# ── Step 10: Configure nginx ──
step "Configuring nginx..."
NGINX_SRC="${SCRIPT_DIR}/nginx.conf"
if [ -f "$NGINX_SRC" ] && [ -n "$DOMAIN" ] && [ "$NO_TLS" = false ]; then
    sudo cp "$NGINX_SRC" /etc/nginx/conf.d/benchify.conf
    sudo sed -i "s/benchify.example.com/$DOMAIN/g" /etc/nginx/conf.d/benchify.conf
    sudo mkdir -p /var/www/certbot
    success "nginx configured with domain: $DOMAIN"
else
    # Create minimal nginx config (HTTP-only)
    sudo tee /etc/nginx/conf.d/benchify.conf > /dev/null <<NGINXEOF
server {
    listen 80;
    server_name ${DOMAIN:-_};
    client_max_body_size 500M;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
    location /ws/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400s;
    }
}
NGINXEOF
    if [ "$NO_TLS" = true ]; then
        warn "nginx configured in HTTP-only mode (no TLS)"
    else
        success "nginx configured (HTTP-only)"
    fi
fi

# Test nginx config
if sudo nginx -t 2>/dev/null; then
    sudo systemctl enable nginx
    sudo systemctl restart nginx
    success "nginx restarted"
else
    warn "nginx config test failed — check /etc/nginx/conf.d/benchify.conf"
fi

# ── Step 11: Configure Let's Encrypt (if domain provided) ──
if [ -n "$DOMAIN" ] && [ "$NO_TLS" = false ]; then
    step "Obtaining Let's Encrypt certificate for $DOMAIN..."
    if sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@${DOMAIN#*.}" 2>/dev/null; then
        success "Let's Encrypt certificate obtained for $DOMAIN"
    else
        warn "certbot failed. You can manually obtain a certificate later:"
        warn "  sudo certbot --nginx -d $DOMAIN"
    fi
else
    warn "Skipping TLS certificate (no domain provided or --no-tls specified)"
fi

# ── Step 12: Start server ──
step "Starting Benchify server..."
if [ -f "$DATA_DIR/server" ]; then
    sudo systemctl start performancebench-server
    sleep 2
    if sudo systemctl is-active --quiet performancebench-server; then
        success "Benchify server started successfully"
    else
        warn "Server failed to start. Check logs:"
        warn "  sudo journalctl -u performancebench-server -n 50"
    fi
else
    warn "Server binary not found — skipping service start"
    warn "Place the server binary at: $DATA_DIR/server"
    warn "Then run: sudo systemctl start performancebench-server"
fi

# ── Step 13: Print summary ──
echo ""
echo "======================================================================"
echo -e " ${GREEN}Benchify Server Installation Complete${NC}"
echo "======================================================================"
echo ""
echo "  Installation directory: $DATA_DIR"
echo "  Database:               postgres://${PG_USER}@localhost:5432/${PG_DB}"
if [ -n "$DOMAIN" ] && [ "$NO_TLS" = false ]; then
    echo "  URL:                    https://$DOMAIN"
    echo "  Health check:           https://$DOMAIN/health"
else
    echo "  URL:                    http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):3000"
    echo "  Health check:           http://localhost:3000/health"
fi
echo "  Service:                performancebench-server"
echo ""
echo "  Commands:"
echo "    Status:     sudo systemctl status performancebench-server"
echo "    Restart:    sudo systemctl restart performancebench-server"
echo "    Logs:       sudo journalctl -u performancebench-server -f"
echo ""
echo "  Next steps:"
echo "    1. Open the URL in your browser"
echo "    2. Log in with the auto-created admin account:"
echo "       Email:    admin@localhost"
echo "       Password: (check logs: sudo journalctl -u performancebench-server | grep auto_admin_created)"
echo "    3. CHANGE THE ADMIN PASSWORD immediately"
echo "    4. Configure SSO via Admin Dashboard if needed"
echo ""
