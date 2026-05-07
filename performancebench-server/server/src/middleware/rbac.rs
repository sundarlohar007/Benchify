use axum::extract::{Request, State};
use axum::middleware::Next;
use axum::response::Response;
use std::str::FromStr;

use crate::error::AppError;
use crate::state::AppState;
use crate::utils::jwt::AuthUser;

/// RBAC role enumeration with hierarchy support.
///
/// Hierarchy: Admin > Manager > Operator > Viewer
/// Auditor is a leaf role — has access to audit endpoints only.
/// Admin satisfies ALL roles including Auditor.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub enum Role {
    Viewer = 0,
    Auditor = 1,
    Operator = 2,
    Manager = 3,
    Admin = 4,
}

impl Role {
    /// Check if this role satisfies the required minimum role.
    /// Admin satisfies everything. Auditor only satisfies Auditor (leaf role).
    pub fn satisfies(&self, required: &Role) -> bool {
        match self {
            Role::Admin => true,
            Role::Auditor => required == &Role::Auditor,
            _ => self >= required,
        }
    }
}

impl std::fmt::Display for Role {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Role::Admin => write!(f, "admin"),
            Role::Manager => write!(f, "manager"),
            Role::Operator => write!(f, "operator"),
            Role::Viewer => write!(f, "viewer"),
            Role::Auditor => write!(f, "auditor"),
        }
    }
}

impl FromStr for Role {
    type Err = AppError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "admin" => Ok(Role::Admin),
            "manager" => Ok(Role::Manager),
            "operator" => Ok(Role::Operator),
            "viewer" => Ok(Role::Viewer),
            "auditor" => Ok(Role::Auditor),
            _ => Err(AppError::Validation(format!(
                "Invalid role: {}. Valid roles: admin, manager, operator, viewer, auditor",
                s
            ))),
        }
    }
}

/// Validate that a role name string is one of the 5 valid roles.
pub fn parse_role(s: &str) -> Result<Role, AppError> {
    Role::from_str(s)
}

/// Axum middleware factory that enforces a minimum role requirement.
///
/// Returns a closure suitable for `axum::middleware::from_fn_with_state`.
/// Must be placed AFTER `auth_middleware` in the middleware stack.
///
/// Usage:
/// ```ignore
/// .route_layer(from_fn_with_state(state.clone(), rbac::require_role(Role::Admin)))
/// ```
///
/// On insufficient role: returns 403 Forbidden.
/// On missing AuthUser (no prior auth): returns 401 Unauthorized.
pub fn require_role(
    required_role: Role,
) -> impl Fn(
    State<AppState>,
    Request,
    Next,
) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<Response, AppError>> + Send>>
+ Clone {
    move |State(_state): State<AppState>, mut request: Request, next: Next| {
        let required_role = required_role.clone();
        Box::pin(async move {
            let auth_user = request
                .extensions()
                .get::<AuthUser>()
                .ok_or(AppError::Unauthorized)?;

            let user_role = Role::from_str(&auth_user.role)?;

            if !user_role.satisfies(&required_role) {
                return Err(AppError::Forbidden);
            }

            Ok(next.run(request).await)
        })
    }
}

/// Convenience: require Admin role middleware.
pub fn require_admin() -> impl Fn(
    State<AppState>,
    Request,
    Next,
) -> std::pin::Pin<
    Box<dyn std::future::Future<Output = Result<Response, AppError>> + Send>,
> + Clone {
    require_role(Role::Admin)
}
