use ldap3::{LdapConnAsync, LdapConnSettings, Scope, SearchEntry};

/// Result of LDAP authentication.
#[derive(Debug, Clone)]
pub struct LdapUser {
    pub email: String,
    pub display_name: Option<String>,
}

/// Authenticate a user against an LDAP server.
///
/// Flow:
/// 1. Connect to LDAP server with StartTLS if using ldaps:// scheme
/// 2. Bind with service account credentials
/// 3. Search for the user by their username
/// 4. Re-bind as the found user with the provided password
/// 5. Return user attributes (email, display_name)
pub async fn ldap_authenticate(
    server_url: &str,
    bind_dn: &str,
    bind_password: &str,
    search_base: &str,
    user_filter: &str,
    username: &str,
    password: &str,
) -> Result<LdapUser, Box<dyn std::error::Error + Send + Sync>> {
    // Escape special LDAP characters in the username (RFC 4515)
    let escaped_username = escape_ldap_filter(username);
    let filter = user_filter.replace("{username}", &escaped_username);

    // Determine if StartTLS should be used
    let use_starttls = server_url.starts_with("ldaps://");

    // Connect asynchronously
    let (_, mut ldap) = LdapConnAsync::with_settings(
        LdapConnSettings::new().set_starttls(use_starttls),
        server_url,
    )
    .await
    .map_err(|e| format!("LDAP connection failed: {}", e))?;

    // Bind with service account
    ldap.simple_bind(bind_dn, bind_password)
        .await
        .map_err(|e| format!("LDAP service bind failed: {}", e))?
        .success()
        .map_err(|e| format!("LDAP service bind unsuccessful: {:?}", e))?;

    // Search for the user
    let (search_result, _res) = ldap
        .search(
            search_base,
            Scope::Subtree,
            &filter,
            vec!["mail", "displayName", "cn", "dn"],
        )
        .await
        .map_err(|e| format!("LDAP search failed: {}", e))?
        .success()
        .map_err(|e| format!("LDAP search unsuccessful: {:?}", e))?;

    let entries: Vec<SearchEntry> = search_result
        .into_iter()
        .map(|entry| SearchEntry::construct(entry))
        .collect();

    if entries.is_empty() {
        return Err("LDAP user not found".into());
    }

    let entry = &entries[0];
    let user_dn = entry.dn.clone();

    // Re-bind as the found user with provided password
    // Drop existing connection and create a new one
    drop(ldap);

    let (_, mut user_ldap) = LdapConnAsync::with_settings(
        LdapConnSettings::new().set_starttls(use_starttls),
        server_url,
    )
    .await
    .map_err(|e| format!("LDAP user connection failed: {}", e))?;

    user_ldap
        .simple_bind(&user_dn, password)
        .await
        .map_err(|e| format!("LDAP user bind failed: {}", e))?
        .success()
        .map_err(|e| format!("LDAP user bind unsuccessful: {:?}", e))?;

    // Extract attributes
    let email = entry
        .attrs
        .get("mail")
        .and_then(|v| v.first())
        .cloned()
        .unwrap_or_else(|| username.to_string());

    let display_name = entry
        .attrs
        .get("displayName")
        .and_then(|v| v.first())
        .cloned()
        .or_else(|| entry.attrs.get("cn").and_then(|v| v.first()).cloned());

    Ok(LdapUser {
        email,
        display_name,
    })
}

/// Escape special characters in an LDAP filter value per RFC 4515.
fn escape_ldap_filter(value: &str) -> String {
    let mut escaped = String::with_capacity(value.len() * 2);
    for c in value.chars() {
        match c {
            '*' => escaped.push_str("\\2a"),
            '(' => escaped.push_str("\\28"),
            ')' => escaped.push_str("\\29"),
            '\\' => escaped.push_str("\\5c"),
            '\0' => escaped.push_str("\\00"),
            other => escaped.push(other),
        }
    }
    escaped
}
