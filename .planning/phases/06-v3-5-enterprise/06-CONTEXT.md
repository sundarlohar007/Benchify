# Phase 6: v3.5 Enterprise — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Enterprise server features: SSO (OIDC+SAML+LDAP), RBAC (5 roles), audit logging, on-prem deployment (Docker + bare metal). 9 requirements. 2 days. Final phase — builds on Phase 3 Rust/Axum server.
</domain>

<decisions>
## Implementation Decisions

### SSO + Auth

- **D-01:** Full SSO coverage — OIDC (Google Workspace, Okta, Auth0, Azure AD, Keycloak) + SAML 2.0 (ADFS, PingFederate) + LDAP. Configurable in Settings → Auth. Existing JWT+bcrypt remains as fallback local auth.
- **D-02:** SSO config via dashboard and/or config file. OIDC: client_id, client_secret, issuer_url, scopes. SAML: metadata XML URL or upload, entity_id, ACS URL. LDAP: server URL, bind DN, search base, attribute mapping.

### RBAC

- **D-03:** 5 roles: admin (full access), manager (user+team mgmt), operator (read+write sessions, no user mgmt), viewer (read-only), auditor (read-only + audit log access). Enforced via Axum middleware extractor.
- **D-04:** Roles stored in users table (role_id FK). Default role: viewer. Admin promotes users via dashboard. Matches Phase 3 API token scope pattern (read/write/admin → maps to viewer/operator/admin).

### Audit + On-Prem

- **D-05:** Audit events in PostgreSQL `audit_events` table. All CRUD operations, auth events, config changes logged. Manual retention — admin manages via dashboard. Export to CSV/JSON.
- **D-06:** No license enforcement — MIT honor system. Consistent with project philosophy.
- **D-07:** On-prem: Docker Compose (primary, extends Phase 3) + bare metal install script (systemd service, manual PostgreSQL setup). Helm chart for Kubernetes optional.
- **D-08:** Air-gapped deployment: offline Docker images (docker save/load), offline migration bundles, manual dependency checklist.

### Claude's Discretion

- OIDC crate selection (openidconnect-rs vs oauth2)
- SAML crate selection and SAMLResponse validation
- LDAP crate and connection pooling
- RBAC middleware extractor design and role hierarchy
- audit_events table schema and event taxonomy
- Bare metal install script structure
- Helm chart values and templates
- Dashboard SSO configuration UI layout

</decisions>

<canonical_refs>
## Canonical References

- `UNIFIED-SPEC.md` — §44-49 (Enterprise spec)
- `.planning/REQUIREMENTS.md` — Enterprise requirements
- `.planning/ROADMAP.md` — Phase 6 scope
- `.planning/phases/03-v2-0-team-server-web-dashboard/03-CONTEXT.md` — Server foundation (D-01 through D-51)
- `performancebench-server/` — Existing Rust/Axum server (auth, routes, middleware)
</canonical_refs>

<specifics>
- Enterprise features are additive to Phase 3 server — no breaking changes to existing API
- SSO is enterprise table stakes — must support at least one major provider per protocol
- RBAC must be enforced at middleware level, not per-route (DRY principle)
- Audit must cover all mutating operations + auth events
- On-prem deploy must work without internet access (air-gapped)
</specifics>

<deferred>
None.
</deferred>

---
*Phase: 6-v3.5 Enterprise*
*Context gathered: 2026-05-06*
