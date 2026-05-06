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

-- ============================================================
-- 8. Audit Events (V35-06)
-- ============================================================
CREATE TABLE audit_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(50) NOT NULL,
    event_category VARCHAR(30) NOT NULL CHECK (event_category IN ('auth', 'session', 'user', 'config', 'team', 'export', 'system')),
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_email VARCHAR(255),
    target_type VARCHAR(50),
    target_id UUID,
    details JSONB NOT NULL DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_audit_events_event_type ON audit_events(event_type);
CREATE INDEX idx_audit_events_event_category ON audit_events(event_category);
CREATE INDEX idx_audit_events_actor_id ON audit_events(actor_id);
CREATE INDEX idx_audit_events_created_at ON audit_events(created_at DESC);
CREATE INDEX idx_audit_events_target ON audit_events(target_type, target_id);

-- ============================================================
-- 9. Team Organizations (V35-09)
-- ============================================================
CREATE TABLE team_orgs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    settings JSONB NOT NULL DEFAULT '{}',
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_team_orgs_slug ON team_orgs(slug);

-- Team Projects (V35-09)
CREATE TABLE team_projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID NOT NULL REFERENCES team_orgs(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(org_id, slug)
);
CREATE INDEX idx_team_projects_org_id ON team_projects(org_id);

-- Team Membership (V35-09)
CREATE TABLE team_membership (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    org_id UUID NOT NULL REFERENCES team_orgs(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'viewer' CHECK (role IN ('admin', 'manager', 'operator', 'viewer', 'auditor')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, org_id)
);
CREATE INDEX idx_team_membership_user_id ON team_membership(user_id);
CREATE INDEX idx_team_membership_org_id ON team_membership(org_id);

-- Add team_project_id FK to sessions (backward compatible — nullable, existing sessions get NULL)
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS team_project_id UUID REFERENCES team_projects(id);
CREATE INDEX IF NOT EXISTS idx_sessions_team_project_id ON sessions(team_project_id);
