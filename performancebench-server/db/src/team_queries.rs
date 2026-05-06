use diesel::prelude::*;
use diesel_async::RunQueryDsl;
use models::team::{
    TeamMembership, TeamOrg, TeamOrgResponse, TeamProject, TeamProjectResponse,
    NewTeamMembership, NewTeamOrg, NewTeamProject,
};
use uuid::Uuid;

use crate::connection::DbPool;
use crate::schema::{team_membership, team_orgs, team_projects, users};

type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// Generate a URL-safe slug from a name: lowercase, replace spaces with hyphens,
/// remove non-alphanumeric/hyphen characters.
pub fn generate_slug(name: &str) -> String {
    name.to_lowercase()
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '-' })
        .collect::<String>()
        .split('-')
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}

// ── Organization CRUD ──

pub async fn create_org(
    pool: &DbPool,
    name: &str,
    description: Option<&str>,
    created_by: Uuid,
) -> DbResult<TeamOrg> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();
    let slug = generate_slug(name);

    let row = NewTeamOrg {
        id: Uuid::new_v4(),
        name: name.to_string(),
        slug,
        description: description.map(|s| s.to_string()),
        is_active: true,
        settings: serde_json::json!({}),
        created_by,
        created_at: now,
        updated_at: now,
    };

    let org = diesel::insert_into(team_orgs::table)
        .values(&row)
        .get_result::<TeamOrg>(&mut *client)
        .await?;
    Ok(org)
}

pub async fn get_org_by_id(pool: &DbPool, org_id: Uuid) -> DbResult<Option<TeamOrg>> {
    let mut client = pool.get().await?;
    let result = team_orgs::table
        .find(org_id)
        .first::<TeamOrg>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

pub async fn get_org_by_slug(pool: &DbPool, slug: &str) -> DbResult<Option<TeamOrg>> {
    let mut client = pool.get().await?;
    let result = team_orgs::table
        .filter(team_orgs::slug.eq(slug))
        .first::<TeamOrg>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

/// List organizations where the given user is a member.
pub async fn list_orgs(
    pool: &DbPool,
    user_id: Uuid,
    offset: i64,
    limit: i64,
) -> DbResult<(Vec<TeamOrgResponse>, i64)> {
    let mut client = pool.get().await?;

    // Org IDs where user is a member
    let member_org_ids = team_membership::table
        .filter(team_membership::user_id.eq(user_id))
        .select(team_membership::org_id)
        .distinct();

    // Count
    let total: i64 = team_orgs::table
        .filter(team_orgs::id.eq_any(member_org_ids.clone()))
        .count()
        .get_result(&mut *client)
        .await?;

    // Data
    let orgs = team_orgs::table
        .filter(team_orgs::id.eq_any(member_org_ids))
        .order(team_orgs::created_at.desc())
        .offset(offset)
        .limit(limit)
        .load::<TeamOrg>(&mut *client)
        .await?;

    // For each org, get member count
    let mut responses: Vec<TeamOrgResponse> = Vec::new();
    for org in orgs {
        let member_count: i64 = team_membership::table
            .filter(team_membership::org_id.eq(org.id))
            .count()
            .get_result(&mut *client)
            .await?;

        let mut resp = TeamOrgResponse::from(&org);
        resp.member_count = Some(member_count);
        responses.push(resp);
    }

    Ok((responses, total))
}

pub async fn update_org(
    pool: &DbPool,
    org_id: Uuid,
    name: Option<&str>,
    description: Option<&str>,
    is_active: Option<bool>,
) -> DbResult<TeamOrg> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();

    let target = team_orgs::table.find(org_id);

    // Build updates incrementally
    if let Some(n) = name {
        let slug = generate_slug(n);
        let org = diesel::update(target)
            .set((
                team_orgs::name.eq(n),
                team_orgs::slug.eq(slug),
                team_orgs::updated_at.eq(now),
            ))
            .get_result::<TeamOrg>(&mut *client)
            .await?;
        return Ok(org);
    }

    // Partial update without name change
    let mut updates: Vec<Box<dyn diesel::query_builder::AstPass<diesel::pg::Pg>>> = Vec::new();
    // Instead, use a simpler approach:
    // Re-fetch, re-set fields, update
    let existing = team_orgs::table
        .find(org_id)
        .first::<TeamOrg>(&mut *client)
        .await?;

    let new_desc = description.map(|d| Some(d.to_string())).unwrap_or_else(|| existing.description.clone());
    let new_active = is_active.unwrap_or(existing.is_active);

    let org = diesel::update(team_orgs::table.find(org_id))
        .set((
            team_orgs::description.eq(new_desc),
            team_orgs::is_active.eq(new_active),
            team_orgs::updated_at.eq(now),
        ))
        .get_result::<TeamOrg>(&mut *client)
        .await?;
    Ok(org)
}

pub async fn delete_org(pool: &DbPool, org_id: Uuid) -> DbResult<()> {
    let mut client = pool.get().await?;
    diesel::delete(team_orgs::table.find(org_id))
        .execute(&mut *client)
        .await?;
    Ok(())
}

// ── Project CRUD ──

pub async fn create_project(
    pool: &DbPool,
    org_id: Uuid,
    name: &str,
    description: Option<&str>,
    created_by: Uuid,
) -> DbResult<TeamProject> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();
    let slug = generate_slug(name);

    let row = NewTeamProject {
        id: Uuid::new_v4(),
        org_id,
        name: name.to_string(),
        slug,
        description: description.map(|s| s.to_string()),
        is_active: true,
        created_by,
        created_at: now,
        updated_at: now,
    };

    let project = diesel::insert_into(team_projects::table)
        .values(&row)
        .get_result::<TeamProject>(&mut *client)
        .await?;
    Ok(project)
}

pub async fn get_project_by_id(pool: &DbPool, project_id: Uuid) -> DbResult<Option<TeamProject>> {
    let mut client = pool.get().await?;
    let result = team_projects::table
        .find(project_id)
        .first::<TeamProject>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

pub async fn list_projects(
    pool: &DbPool,
    org_id: Uuid,
    offset: i64,
    limit: i64,
) -> DbResult<(Vec<TeamProjectResponse>, i64)> {
    let mut client = pool.get().await?;

    let base = team_projects::table.filter(team_projects::org_id.eq(org_id));

    let total: i64 = base.clone().count().get_result(&mut *client).await?;

    let projects = base
        .order(team_projects::created_at.desc())
        .offset(offset)
        .limit(limit)
        .load::<TeamProject>(&mut *client)
        .await?;

    let responses: Vec<TeamProjectResponse> = projects.iter().map(TeamProjectResponse::from).collect();

    Ok((responses, total))
}

pub async fn update_project(
    pool: &DbPool,
    project_id: Uuid,
    name: Option<&str>,
    description: Option<&str>,
    is_active: Option<bool>,
) -> DbResult<TeamProject> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();

    if let Some(n) = name {
        let slug = generate_slug(n);
        let project = diesel::update(team_projects::table.find(project_id))
            .set((
                team_projects::name.eq(n),
                team_projects::slug.eq(slug),
                team_projects::updated_at.eq(now),
            ))
            .get_result::<TeamProject>(&mut *client)
            .await?;
        return Ok(project);
    }

    let existing = team_projects::table
        .find(project_id)
        .first::<TeamProject>(&mut *client)
        .await?;

    let new_desc = description.map(|d| Some(d.to_string())).unwrap_or_else(|| existing.description.clone());
    let new_active = is_active.unwrap_or(existing.is_active);

    let project = diesel::update(team_projects::table.find(project_id))
        .set((
            team_projects::description.eq(new_desc),
            team_projects::is_active.eq(new_active),
            team_projects::updated_at.eq(now),
        ))
        .get_result::<TeamProject>(&mut *client)
        .await?;
    Ok(project)
}

pub async fn delete_project(pool: &DbPool, project_id: Uuid) -> DbResult<()> {
    let mut client = pool.get().await?;
    diesel::delete(team_projects::table.find(project_id))
        .execute(&mut *client)
        .await?;
    Ok(())
}

// ── Membership CRUD ──

pub async fn add_member(
    pool: &DbPool,
    org_id: Uuid,
    user_id: Uuid,
    role: &str,
) -> DbResult<TeamMembership> {
    let mut client = pool.get().await?;
    let now = chrono::Utc::now().naive_utc();

    let row = NewTeamMembership {
        id: Uuid::new_v4(),
        user_id,
        org_id,
        role: role.to_string(),
        joined_at: now,
    };

    let membership = diesel::insert_into(team_membership::table)
        .values(&row)
        .get_result::<TeamMembership>(&mut *client)
        .await?;
    Ok(membership)
}

pub async fn remove_member(pool: &DbPool, org_id: Uuid, user_id: Uuid) -> DbResult<()> {
    let mut client = pool.get().await?;
    diesel::delete(
        team_membership::table
            .filter(team_membership::org_id.eq(org_id))
            .filter(team_membership::user_id.eq(user_id)),
    )
    .execute(&mut *client)
    .await?;
    Ok(())
}

pub async fn update_member_role(
    pool: &DbPool,
    org_id: Uuid,
    user_id: Uuid,
    new_role: &str,
) -> DbResult<TeamMembership> {
    let mut client = pool.get().await?;

    let membership = diesel::update(
        team_membership::table
            .filter(team_membership::org_id.eq(org_id))
            .filter(team_membership::user_id.eq(user_id)),
    )
    .set(team_membership::role.eq(new_role))
    .get_result::<TeamMembership>(&mut *client)
    .await?;
    Ok(membership)
}

pub async fn list_members(
    pool: &DbPool,
    org_id: Uuid,
    offset: i64,
    limit: i64,
) -> DbResult<(Vec<(TeamMembership, String, Option<String>)>, i64)> {
    let mut client = pool.get().await?;

    let base = team_membership::table
        .filter(team_membership::org_id.eq(org_id))
        .inner_join(users::table);

    let total: i64 = base
        .clone()
        .count()
        .get_result(&mut *client)
        .await?;

    let results = base
        .select((
            TeamMembership::as_select(),
            users::email,
            users::display_name,
        ))
        .order(team_membership::joined_at.asc())
        .offset(offset)
        .limit(limit)
        .load::<(TeamMembership, String, Option<String>)>(&mut *client)
        .await?;

    Ok((results, total))
}

pub async fn get_member(
    pool: &DbPool,
    org_id: Uuid,
    user_id: Uuid,
) -> DbResult<Option<TeamMembership>> {
    let mut client = pool.get().await?;
    let result = team_membership::table
        .filter(team_membership::org_id.eq(org_id))
        .filter(team_membership::user_id.eq(user_id))
        .first::<TeamMembership>(&mut *client)
        .await
        .optional()?;
    Ok(result)
}

// ── Tests ──

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_slug_simple() {
        assert_eq!(generate_slug("My Organization"), "my-organization");
    }

    #[test]
    fn test_generate_slug_special_chars() {
        assert_eq!(generate_slug("ACME Corp!"), "acme-corp");
    }

    #[test]
    fn test_generate_slug_multiple_spaces() {
        assert_eq!(generate_slug("  Hello   World  "), "hello-world");
    }

    #[test]
    fn test_generate_slug_single_word() {
        assert_eq!(generate_slug("Benchify"), "benchify");
    }

    #[test]
    fn test_generate_slug_all_special() {
        assert_eq!(generate_slug("!@#$%"), "");
    }
}
