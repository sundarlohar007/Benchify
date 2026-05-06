# Benchify Server — Air-Gapped Deployment Checklist

This guide covers manual deployment of the Benchify server on a host with **no internet access**. All artifacts must be pre-downloaded on an internet-connected machine and transferred to the air-gapped host via USB drive, isolated network transfer, or sneakernet.

**Target OS:** Ubuntu 24.04+ or Debian 12+

---

## Section 1: Prerequisites (Internet-Connected Machine)

Before starting, prepare these on a machine with internet access:

| Item | Description |
|------|-------------|
| Benchify source | Git clone of `https://github.com/sundarlohar007/Benchify` |
| Docker | Docker Engine 24+ installed (if using Docker deployment) |
| USB drive | At least 4 GB free space for artifact transfer |
| `cargo` | Rust toolchain (rustup) if building from source |

---

## Section 2: Offline Docker Images

### 2.1 Pull & Save Images (Internet-Connected Machine)

```bash
# Create images directory
mkdir -p benchify-offline/images

# Pull required images
docker pull postgres:17-alpine
docker pull nginx:alpine
docker pull certbot/certbot
docker pull rust:1.93-alpine   # Builder image (if building in Docker)

# Save images to tar files
docker save postgres:17-alpine -o benchify-offline/images/postgres-17-alpine.tar
docker save nginx:alpine        -o benchify-offline/images/nginx-alpine.tar
docker save certbot/certbot     -o benchify-offline/images/certbot.tar
docker save rust:1.93-alpine     -o benchify-offline/images/rust-builder.tar
```

### 2.2 Load Images (Air-Gapped Host)

```bash
# Transfer benchify-offline/images/ to air-gapped host, then:
docker load -i /path/to/images/postgres-17-alpine.tar
docker load -i /path/to/images/nginx-alpine.tar
docker load -i /path/to/images/certbot.tar
docker load -i /path/to/images/rust-builder.tar

# Verify
docker images | grep -E "postgres|nginx|certbot|rust"
```

### 2.3 Deploy with Docker Compose

```bash
# Copy docker-compose.prod.yml and deploy/nginx.conf to air-gapped host
# Replace benchify.example.com with your internal hostname/IP in nginx.conf
# Then:
docker compose -f docker-compose.prod.yml up -d
```

**Note:** Let's Encrypt will NOT work in air-gapped mode (requires internet). Use self-signed certificates or an internal CA instead. Update nginx.conf to point to internal certificate paths.

---

## Section 3: Offline Rust Build

### 3.1 Pre-fetch Cargo Dependencies (Internet-Connected Machine)

```bash
# In the Benchify repository root:
cd performancebench-server

# Vendor all dependencies
cargo vendor

# Create cargo config to use vendored deps
mkdir -p .cargo
cat > .cargo/config.toml <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOF

# Verify vendor directory exists
ls -la vendor/
# Should contain directories for all crate dependencies
```

### 3.2 Build on Air-Gapped Host

```bash
# Transfer the entire performancebench-server directory (including vendor/) to air-gapped host

# Copy .cargo/config.toml from the transferred directory
mkdir -p ~/.cargo
cp .cargo/config.toml ~/.cargo/config.toml

# Build (uses vendored dependencies, no network access)
cd performancebench-server
cargo build --release --frozen

# The binary will be at: target/release/server
```

### 3.3 Dependency Verification

Verify all critical dependencies are vendored:
```bash
# Check for common crate sources
ls vendor/ | wc -l     # Should be > 100 crates

# Key crates to verify:
ls vendor/axum/
ls vendor/tokio/
ls vendor/diesel/
ls vendor/serde/
ls vendor/jsonwebtoken/
ls vendor/openidconnect/
ls vendor/ldap3/
```

---

## Section 4: Offline Migrations

### 4.1 Copy Migration Files

```bash
# On internet-connected machine:
cp -r performancebench-server/migrations/ benchify-offline/migrations/

# Transfer to air-gapped host and copy to server directory:
cp -r /path/to/migrations/ /opt/benchify/migrations/
chown -R benchify:benchify /opt/benchify/migrations/
```

### 4.2 Run Migrations

Migrations run automatically when the server starts. Verify:
```bash
sudo journalctl -u performancebench-server | grep "migrations"
# Expected: "Database migrations complete"
```

### 4.3 Manual Migration Verification

If migrations fail to run automatically, apply manually:
```bash
# Check which migrations have been applied
sudo -u postgres psql -d benchify -c "SELECT * FROM __diesel_schema_migrations;"

# Expected output should include:
#  00000000000000
#  00000000000001
```

---

## Section 5: Manual System Package Install

### 5.1 Download .deb Packages (Internet-Connected Machine)

For **Ubuntu 24.04**:
```bash
mkdir -p benchify-offline/debs

# Download all required packages and their dependencies
apt-get download postgresql-17 postgresql-client-17 nginx certbot python3-certbot-nginx curl

# Or use apt-offline or apt-cacher-ng for dependency resolution
# Recommended: create an apt-offline bundle
sudo apt install apt-offline
apt-offline set /tmp/apt-offline.sig --install-packages \
    postgresql-17 nginx certbot python3-certbot-nginx curl libssl-dev libpq-dev
```

For **Debian 12**:
```bash
# Same packages, adjust version numbers as needed
apt-get download postgresql-16 postgresql-client-16 nginx certbot python3-certbot-nginx curl
```

### 5.2 Install .deb Packages (Air-Gapped Host)

```bash
# Transfer benchify-offline/debs/ to air-gapped host, then:
cd /path/to/debs
sudo dpkg -i *.deb

# Fix any missing dependencies
sudo apt-get install -f -y 2>/dev/null || true
# (This will fail if dependencies are missing — add them to the download list)
```

### 5.3 Verify Package Installation

```bash
postgres --version  # Should be 17.x
nginx -v            # Should be 1.24+
certbot --version   # Should be 2.x+
```

---

## Section 6: Verification Checklist

After deployment, verify the following:

### 6.1 Service Status
- [ ] `sudo systemctl status performancebench-server` shows "active (running)"
- [ ] `sudo systemctl status postgresql` shows "active (running)"
- [ ] `sudo systemctl status nginx` shows "active (running)"

### 6.2 Health Check
```bash
curl http://localhost:3000/health
# Expected: {"status": "ok"}
```

### 6.3 Database Connectivity
```bash
sudo -u postgres psql -d benchify -c "\dt"
# Should list all tables including: users, sessions, audit_events, team_orgs, etc.
```

### 6.4 Authentication
- [ ] Open the server URL in a browser
- [ ] Log in with admin credentials (check logs for auto-created admin password)
- [ ] Verify the dashboard loads without errors

### 6.5 SSO Configuration (if applicable)
- [ ] Navigate to Admin Dashboard > SSO Settings
- [ ] Configure an OIDC provider (if offline IDP available)
- [ ] Test SSO login flow

### 6.6 Audit Log
- [ ] Log in and out a few times
- [ ] Navigate to `/api/v1/audit/events` (requires admin role)
- [ ] Verify audit events are recorded

### 6.7 Data Integrity
- [ ] Upload a test session
- [ ] Verify session data appears in the dashboard
- [ ] Check that metric data is stored correctly

---

## Section 7: Troubleshooting

### 7.1 "Connection refused" on server port
- **Check:** `sudo systemctl status performancebench-server`
- **Fix:** `sudo journalctl -u performancebench-server -n 50` to view logs
- **Common cause:** Database connection string wrong in `/opt/benchify/.env`

### 7.2 "Relation does not exist" errors
- Migrations may not have run. Apply manually:
  ```bash
  cd /opt/benchify
  # Check in server logs: "Running migrations..." message
  ```
- Verify `migrations/` directory exists and is readable by the `benchify` user.

### 7.3 JWT validation errors
- **Common cause:** Clock skew between host and JWT issuer
- **Fix:** Ensure `ntp` or `chrony` is running (even in air-gapped, set hardware clock accurately):
  ```bash
  sudo hwclock --show
  sudo date -s "YYYY-MM-DD HH:MM:SS"
  ```

### 7.4 Missing CA certificates
- TLS verification failures (even internal TLS)
- **Fix:** Copy CA certificates from internet-connected machine:
  ```bash
  # On internet-connected machine:
  cp /etc/ssl/certs/ca-certificates.crt benchify-offline/ca-certs/
  # On air-gapped host:
  sudo cp benchify-offline/ca-certs/ca-certificates.crt /etc/ssl/certs/
  ```

### 7.5 Docker DNS resolution issues
- If `server` or `db` container names don't resolve
- **Fix:** Ensure containers are on the same Docker network:
  ```bash
  docker compose -f docker-compose.prod.yml down
  docker compose -f docker-compose.prod.yml up -d
  ```

### 7.6 Vendor directory missing crates
- If `cargo build --frozen` fails with missing crate errors:
  ```bash
  # Verify the vendored Cargo.lock matches:
  diff <(cargo metadata --format-version=1 --no-deps 2>/dev/null | jq '.packages[].name') <(ls vendor/ | sort)
  
  # Common missing crates: libsqlite3-sys, openssl-sys (system deps)
  # Install build dependencies from Section 5
  sudo apt-get install -f -y
  ```

### 7.7 Let's Encrypt in Air-Gapped Environments
- **Warning:** Let's Encrypt requires internet access for ACME challenges
- **Workaround:** Use self-signed certificates or internal CA
  ```bash
  # Generate self-signed cert (valid for 365 days):
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/benchify.key \
    -out /etc/nginx/ssl/benchify.crt \
    -subj "/CN=benchify.internal"
  
  # Update nginx.conf to use self-signed paths
  ```
- For internal CA: copy root CA cert to air-gapped host and sign CSR manually

---

## Appendix A: SHA-256 Checksums

After transferring files, verify integrity:

```bash
# On internet-connected machine, generate checksums:
cd benchify-offline
find . -type f -exec sha256sum {} \; > SHA256SUMS.txt

# On air-gapped host, verify:
cd /path/to/transferred/benchify-offline
sha256sum -c SHA256SUMS.txt | grep -v "OK$"   # Should show no failures
```

## Appendix B: Quick Reference — Minimum File List

Minimum files to transfer for deployment:

```
benchify-offline/
  images/
    postgres-17-alpine.tar        (Docker deployment)
    nginx-alpine.tar               (Docker deployment)
    certbot.tar                   (Docker deployment, TLS)
  debs/
    postgresql-17_*.deb           (Bare metal)
    nginx_*.deb                   (Bare metal)
  source/
    performancebench-server/      (Full source + vendor/ dir)
  config/
    docker-compose.prod.yml
    deploy/nginx.conf
    deploy/performancebench-server.service
    deploy/install.sh
  migrations/
    (all migration SQL files)
  SHA256SUMS.txt
```
