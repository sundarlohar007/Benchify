# Benchify Enterprise — Deployment Guide

**Version:** 3.5.0 | **License:** MIT | **Last Updated:** 2026-05-06

Free, open-source mobile + desktop performance profiler. This guide covers enterprise deployment: SSO (OIDC/SAML/LDAP), RBAC (5 roles), audit logging, team management, Jira integration, and on-premises deployment options.

---

## 1. Overview

Benchify Enterprise extends the open-source profiler with:

- **Single Sign-On:** OIDC (Google, Okta, Auth0, Azure AD, Keycloak), SAML 2.0 (ADFS, PingFederate), LDAP
- **Role-Based Access Control:** 5 roles (admin, manager, operator, viewer, auditor) enforced at middleware level
- **Audit Logging:** 28 event types across 7 categories with CSV/JSON export, 30+ day retention
- **Team Management:** Multi-org, multi-project hierarchy with membership and slug-based URLs
- **Jira Integration:** Create Jira issues from session detail with pre-filled ADF-formatted performance data
- **Thread CPU Profiling:** Per-thread CPU breakdown for PC sessions (requires root/admin access)

All data stays local — no cloud telemetry, no phoning home.

---

## 2. Deployment Options

| Option | Best For | Complexity | TLS | PostgreSQL |
|--------|----------|------------|-----|------------|
| **A: Docker Compose** | Quick setup, small teams | Low | Built-in (nginx + certbot) | Containerized (managed) |
| **B: Bare Metal** | Dedicated servers, performance-critical | Medium | Manual (nginx + certbot) | Manual (postgres apt) |
| **C: Kubernetes** | K8s-native teams, auto-scaling | Medium-High | Ingress + cert-manager | Bitnami subchart or external |
| **D: Air-Gapped** | No-internet environments | High | Self-signed or internal CA | Pre-downloaded packages |

**Recommendation:** Docker Compose (Option A) for most teams. It provides the fastest path to a production-ready deployment with TLS, PostgreSQL, and auto-renewing certificates.

---

## 3. Option A: Docker Compose

### Prerequisites

- Docker 24+ and Docker Compose v2
- Domain name pointing to your server (for TLS)
- Ports 80 and 443 open in firewall

### Step-by-Step

```bash
# 1. Clone the repository
git clone https://github.com/sundarlohar007/Benchify.git
cd Benchify/performancebench-server

# 2. Copy and configure environment
cp .env.example .env
# Edit .env and set:
#   DATABASE_URL=postgres://benchify:YOUR_STRONG_PASSWORD@db:5432/benchify
#   JWT_SECRET=$(openssl rand -hex 32)
#   SSO_ENABLED=true           # (optional)
#   SSO_REDIRECT_BASE_URL=https://benchify.example.com

# 3. Generate secrets
echo "JWT_SECRET=$(openssl rand -hex 32)" >> .env

# 4. Start services
docker compose -f docker-compose.prod.yml up -d

# 5. Verify deployment
curl https://benchify.example.com/health
# Expected: {"status":"ok"}

# 6. First login
# The initial admin account is auto-created on first startup.
# Check logs for the auto-generated password:
docker compose logs benchify-server | grep "admin password"
```

### TLS Setup

The production Docker Compose file includes nginx as a reverse proxy and certbot for Let's Encrypt auto-renewal. Ensure ports 80 and 443 are accessible from the internet for ACME challenge verification.

### Upgrading

```bash
docker compose pull
docker compose up -d
```

### Backup

```bash
docker compose exec db pg_dump -U benchify benchify > backup_$(date +%Y%m%d).sql
```

---

## 4. Option B: Bare Metal (Ubuntu 24.04)

### Prerequisites

- Ubuntu 24.04 LTS (or Debian 12)
- sudo access
- Domain name (optional — localhost works for testing)
- 2 GB RAM minimum, 10 GB disk

### Automated Install

```bash
# Run the install script
curl -fsSL https://raw.githubusercontent.com/sundarlohar007/Benchify/main/performancebench-server/deploy/install.sh | sudo bash

# Or with flags:
sudo bash deploy/install.sh \
  --domain benchify.example.com \
  --data-dir /data/benchify \
  --binary ./target/release/performancebench-server
```

The installer is idempotent — safe to re-run. It handles:

1. System package installation (PostgreSQL, nginx, certbot)
2. Database user and database creation
3. Binary installation to `/opt/benchify/`
4. systemd service creation and enablement
5. nginx reverse proxy with TLS configuration
6. Firewall (UFW) rules for ports 80, 443
7. Log rotation via journald

### Manual Setup

If the automated installer isn't desired:

```bash
# 1. Install dependencies
sudo apt update && sudo apt install -y postgresql nginx certbot python3-certbot-nginx

# 2. Create database
sudo -u postgres psql -c "CREATE USER benchify WITH PASSWORD 'strong-password';"
sudo -u postgres psql -c "CREATE DATABASE benchify OWNER benchify;"

# 3. Deploy binary
sudo mkdir -p /opt/benchify
sudo cp performancebench-server /opt/benchify/
sudo cp .env.example /opt/benchify/.env
# Edit /opt/benchify/.env with your configuration

# 4. Install systemd service
sudo cp deploy/performancebench-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now performancebench-server

# 5. Configure nginx
sudo cp deploy/nginx.conf /etc/nginx/sites-available/benchify
sudo ln -s /etc/nginx/sites-available/benchify /etc/nginx/sites-enabled/
sudo certbot --nginx -d benchify.example.com
sudo systemctl reload nginx
```

### First Login

The admin account is auto-created. Retrieve the password:

```bash
sudo journalctl -u performancebench-server | grep "admin password"
```

Change it on first login.

---

## 5. Option C: Kubernetes (Helm)

### Prerequisites

- Kubernetes 1.28+
- Helm 3.14+
- kubectl configured
- (Optional) cert-manager for TLS automation

### Step-by-Step

```bash
# 1. Add Helm repository (or use local chart)
cd Benchify/performancebench-server

# 2. Create values override
cat > my-values.yaml << EOF
ingress:
  enabled: true
  host: benchify.example.com
  tls:
    - secretName: benchify-tls
      hosts:
        - benchify.example.com

postgresql:
  auth:
    password: "$(openssl rand -base64 32)"

server:
  jwtSecret: "$(openssl rand -hex 32)"
  sso:
    enabled: true
    redirectBaseUrl: "https://benchify.example.com"
EOF

# 3. Install chart
helm install benchify ./deploy/helm \
  --values my-values.yaml \
  --namespace benchify \
  --create-namespace

# 4. Wait for deployment
kubectl -n benchify rollout status deployment/benchify

# 5. Verify
kubectl -n benchify port-forward svc/benchify 3000:3000
curl http://localhost:3000/health
```

### TLS with cert-manager

Add these annotations to your values:

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
```

### Database Options

**Embedded PostgreSQL (default):** The chart includes a Bitnami PostgreSQL subchart for quick setup. Not recommended for production — use an external managed database instead.

**External PostgreSQL:**

```yaml
postgresql:
  enabled: false
  external:
    host: "your-rds-instance.aws.com"
    port: 5432
```

### Resource Recommendations

| Environment | CPU Request | Memory Request | Storage |
|-------------|-------------|----------------|---------|
| Dev/Test | 250m | 256Mi | 10Gi |
| Production (small) | 500m | 512Mi | 50Gi |
| Production (large) | 1000m | 1Gi | 100Gi |

---

## 6. Option D: Air-Gapped Deployment

For environments without internet access. See `deploy/airgap-checklist.md` for the complete 7-section checklist.

### Summary of Approach

1. **Pre-download artifacts** on an internet-connected machine:
   - Docker images: `docker pull ghcr.io/sundarlohar007/benchify-server:latest && docker save`
   - Rust dependencies: `cargo vendor`
   - System packages (.deb): PostgreSQL, nginx, certbot (if using internal CA)
   - Migration files from the repository

2. **Transfer via USB/network share** to the air-gapped machine.

3. **Manual setup:**
   - Install system packages from .deb files
   - Load Docker images: `docker load < benchify-server.tar`
   - Set up PostgreSQL manually (create user, database, run migrations)
   - Configure self-signed certificates or internal CA
   - Start services

4. **Verify:** SHA-256 checksums on all transferred files, health check endpoint, test SSO login.

---

## 7. Post-Deployment Configuration

### First Admin Login

1. Navigate to `https://your-domain.com`
2. Log in with the auto-generated admin credentials (check logs)
3. **Change the admin password immediately:**
   - Go to Settings → Profile
   - Enter new password (minimum 8 characters)

### Configuring SSO

1. Go to Settings → SSO (admin only)
2. Click **Add Provider**
3. Select provider type:
   - **OIDC:** Enter issuer URL, client ID, client secret, scopes
   - **SAML:** Enter IdP SSO URL, IdP entity ID, SP entity ID
   - **LDAP:** Enter server URL, bind DN, search base
4. Set attribute mapping (email, display name)
5. Toggle **Active** on
6. Test login at `/auth/sso/{provider}/login`

### Setting Up RBAC Roles

Go to Admin → Users (admin only). Each user has a role:

| Role | Access Level |
|------|-------------|
| **Admin** | Full access — manage users, SSO, audit, teams, all sessions |
| **Manager** | Manage users and teams, view all sessions |
| **Operator** | Read/write sessions, no user management |
| **Viewer** | Read-only access to sessions, trends, reports (default for new SSO users) |
| **Auditor** | Read-only + audit log access |

### Connecting Desktop Profiler

1. Go to Settings → API Tokens
2. Create a new token with **write** scope
3. Copy the token (only shown once)
4. In the desktop profiler app, enter the server URL and paste the token
5. Uploaded sessions appear in the Sessions page

---

## 8. Security Hardening Checklist

- [ ] **Rotate JWT_SECRET:** Use `openssl rand -hex 32` — never use the default
- [ ] **Strong PostgreSQL password:** Minimum 16 characters, no dictionary words
- [ ] **Enable TLS:** Required for production. Let's Encrypt via certbot or ingress controller
- [ ] **Restrict CORS origins:** Set `CORS_ALLOWED_ORIGINS` to your specific domain, not wildcard
- [ ] **Configure firewall (UFW):**
  ```bash
  sudo ufw default deny incoming
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw allow 22/tcp  # SSH
  sudo ufw enable
  ```
- [ ] **Database backups:** Schedule `pg_dump` cron job
  ```bash
  # Daily backup at 2 AM
  0 2 * * * pg_dump -U benchify benchify | gzip > /backups/benchify_$(date +\%Y\%m\%d).sql.gz
  ```
- [ ] **Audit log retention:** Go to Admin → Audit → Purge Events. Set retention to 90 days for compliance.
- [ ] **SSO session timeout:** JWT access tokens expire after 1 hour. Refresh tokens last 7 days. Adjust in SSO provider settings if needed.
- [ ] **Rate limiting:** Enable ingress-level rate limiting for `/auth/login` endpoint (20 req/min per IP).
- [ ] **Container security:** Run as non-root (UID 1000, set in Helm values). Drop all capabilities.
- [ ] **Environment isolation:** Use separate databases for dev/staging/production.

---

## 9. Troubleshooting

### Database Connection Refused

```
Error: could not connect to server: Connection refused
```

- Ensure PostgreSQL is running: `sudo systemctl status postgresql`
- Check `DATABASE_URL` in `.env` matches the actual host/port/credentials
- For Docker: ensure the `db` service is healthy: `docker compose ps`

### Port Conflicts

```
Error: Address already in use (os error 98)
```

- Check what's using port 3000: `sudo lsof -i :3000`
- Stop conflicting service or change `PORT` in `.env`

### TLS Certificate Errors

```
SSL certificate problem: unable to get local issuer certificate
```

- Verify certbot completed: `sudo certbot certificates`
- Check expiry: `sudo certbot renew --dry-run`
- For self-signed certs in development: set `NODE_TLS_REJECT_UNAUTHORIZED=0` (not for production)

### SSO Redirect URI Mismatch

```
Error: redirect_uri_mismatch
```

- Ensure `SSO_REDIRECT_BASE_URL` matches the redirect URI registered in your IdP
- OIDC callback path: `{base_url}/auth/sso/oidc/callback`
- SAML ACS path: `{base_url}/auth/sso/saml/acs`

### WebSocket Connection Fails

```
WebSocket connection to 'wss://...' failed
```

- Ensure ingress/nginx proxy-read-timeout is set to 3600 (Helm chart includes this by default)
- For nginx config: add `proxy_read_timeout 3600s;` in the location block
- Verify firewall allows WebSocket upgrade headers

---

## 10. Upgrading

### Docker Compose

```bash
cd performancebench-server
docker compose pull
docker compose -f docker-compose.prod.yml up -d
# Monitor logs for migration completion
docker compose logs -f benchify-server
```

### Bare Metal

```bash
# 1. Stop the service
sudo systemctl stop performancebench-server

# 2. Replace the binary
sudo cp ./target/release/performancebench-server /opt/benchify/

# 3. Run database migrations (automatic on startup with diesel)
# Or manually: DATABASE_URL=... diesel migration run

# 4. Start the service
sudo systemctl start performancebench-server

# 5. Verify
sudo systemctl status performancebench-server
curl http://localhost:3000/health
```

### Kubernetes

```bash
helm upgrade benchify ./deploy/helm \
  --values my-values.yaml \
  --namespace benchify
```

### Database Migration Safety

**Always backup before upgrading:**

```bash
# Docker
docker compose exec db pg_dump -U benchify benchify > backup_pre_upgrade.sql

# Bare metal
sudo -u postgres pg_dump benchify > backup_pre_upgrade.sql
```

Migrations run automatically on server startup. If a migration fails, restore from backup and investigate the error in the server logs.

---

## Support

- **GitHub Issues:** https://github.com/sundarlohar007/Benchify/issues
- **Project Documentation:** https://github.com/sundarlohar007/Benchify
- **Specification:** `UNIFIED-SPEC.md` (309KB behavioral spec)

---

*Benchify is MIT-licensed. No license enforcement, no telemetry, no cloud dependency. Your data stays on your infrastructure.*
