-- down.sql: Revert enterprise migration

-- Remove team_project_id FK from sessions
ALTER TABLE sessions DROP COLUMN IF EXISTS team_project_id;

-- Remove team tables
DROP TABLE IF EXISTS team_membership CASCADE;
DROP TABLE IF EXISTS team_projects CASCADE;
DROP TABLE IF EXISTS team_orgs CASCADE;

-- Remove audit events table
DROP TABLE IF EXISTS audit_events CASCADE;

-- Remove SSO configs table
DROP TABLE IF EXISTS sso_configs CASCADE;

-- Remove SSO identity columns from users
ALTER TABLE users DROP COLUMN IF EXISTS sso_provider;
ALTER TABLE users DROP COLUMN IF EXISTS sso_subject;
ALTER TABLE users DROP COLUMN IF EXISTS auth_source;

-- Restore password_hash NOT NULL (only safe if no SSO users created)
ALTER TABLE users ALTER COLUMN password_hash SET NOT NULL;

-- Restore original role CHECK (admin, member only)
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('admin', 'member'));

-- Restore role default
ALTER TABLE users ALTER COLUMN role SET DEFAULT 'member';

-- Migrate viewers back to members
UPDATE users SET role = 'member' WHERE role IN ('viewer', 'manager', 'operator', 'auditor');
