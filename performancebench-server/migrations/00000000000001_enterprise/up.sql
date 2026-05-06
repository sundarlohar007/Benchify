-- up.sql: Enterprise v3.5 — SSO, RBAC 5 roles, audit
-- Migrates existing members → viewers, expands role CHECK, adds SSO fields

-- 1. Migrate existing members to viewers (per D-04: default role = viewer)
UPDATE users SET role = 'viewer' WHERE role = 'member';

-- 2. Expand role CHECK to 5 roles (admin, manager, operator, viewer, auditor)
-- Drop old constraint and add new one
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('admin', 'manager', 'operator', 'viewer', 'auditor'));

-- 3. Change role default from 'member' to 'viewer'
ALTER TABLE users ALTER COLUMN role SET DEFAULT 'viewer';

-- 4. Make password_hash nullable (SSO users have no password)
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;

-- 5. Add SSO identity columns
ALTER TABLE users ADD COLUMN sso_provider VARCHAR(50);
ALTER TABLE users ADD COLUMN sso_subject VARCHAR(255);
ALTER TABLE users ADD COLUMN auth_source VARCHAR(20) NOT NULL DEFAULT 'local';
ALTER TABLE users ADD CONSTRAINT users_auth_source_check CHECK (auth_source IN ('local', 'oidc', 'saml', 'ldap'));

-- 6. Index for JIT SSO lookup (find existing user by provider + subject)
CREATE INDEX idx_users_sso_subject ON users(sso_provider, sso_subject);

-- 7. SSO provider configurations table
CREATE TABLE sso_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_type VARCHAR(10) NOT NULL CHECK (provider_type IN ('oidc', 'saml', 'ldap')),
    name VARCHAR(255) NOT NULL,
    config JSONB NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
