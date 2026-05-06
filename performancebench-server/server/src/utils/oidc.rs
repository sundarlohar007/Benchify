use openidconnect::core::{
    CoreClient, CoreIdTokenClaims, CoreProviderMetadata,
    CoreResponseType,
};
use openidconnect::{
    AuthenticationFlow, AuthorizationCode, ClientId, ClientSecret, CsrfToken, IssuerUrl,
    Nonce, PkceCodeChallenge, PkceCodeVerifier, RedirectUrl, Scope,
    TokenResponse as OidcTokenResponse,
};

/// Custom OIDC validation claims with nonce verification.
#[derive(Debug, Clone)]
pub struct OidcClaims {
    pub email: String,
    pub display_name: Option<String>,
    pub subject: String,
}

/// Discover OIDC provider metadata from its issuer URL.
pub async fn discover_oidc_provider(
    issuer_url: &str,
) -> Result<CoreProviderMetadata, Box<dyn std::error::Error + Send + Sync>> {
    let http_client = reqwest::ClientBuilder::new()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .map_err(|e| format!("Failed to build HTTP client: {}", e))?;

    let issuer = IssuerUrl::new(issuer_url.to_string())?;
    let metadata = CoreProviderMetadata::discover_async(issuer, &http_client).await?;
    Ok(metadata)
}

/// Build an OIDC authorization URL for the given provider.
/// This function creates the client, builds the URL, and returns everything needed.
pub async fn start_oidc_flow(
    issuer_url: &str,
    client_id: &str,
    client_secret: &str,
    redirect_url: &str,
) -> Result<
    (
        url::Url,
        CsrfToken,
        Nonce,
        PkceCodeVerifier,
    ),
    Box<dyn std::error::Error + Send + Sync>,
> {
    let metadata = discover_oidc_provider(issuer_url).await?;

    let client = CoreClient::from_provider_metadata(
        metadata,
        ClientId::new(client_id.to_string()),
        Some(ClientSecret::new(client_secret.to_string())),
    )
    .set_redirect_uri(
        RedirectUrl::new(redirect_url.to_string())
            .map_err(|e| format!("Invalid redirect URL: {}", e))?,
    );

    let (pkce_challenge, pkce_verifier) = PkceCodeChallenge::new_random_sha256();
    let (auth_url, csrf_state, nonce) = client
        .authorize_url(
            AuthenticationFlow::<CoreResponseType>::AuthorizationCode,
            CsrfToken::new_random,
            Nonce::new_random,
        )
        .add_scope(Scope::new("openid".to_string()))
        .add_scope(Scope::new("profile".to_string()))
        .add_scope(Scope::new("email".to_string()))
        .set_pkce_challenge(pkce_challenge)
        .url();

    Ok((auth_url, csrf_state, nonce, pkce_verifier))
}

/// Exchange an OIDC authorization code for tokens and return validated claims.
pub async fn finish_oidc_flow(
    issuer_url: &str,
    client_id: &str,
    client_secret: &str,
    redirect_url: &str,
    code: &str,
    pkce_verifier: PkceCodeVerifier,
    nonce: &Nonce,
) -> Result<CoreIdTokenClaims, Box<dyn std::error::Error + Send + Sync>> {
    let http_client = reqwest::ClientBuilder::new()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .map_err(|e| format!("Failed to build HTTP client: {}", e))?;

    let metadata = discover_oidc_provider(issuer_url).await?;

    let client = CoreClient::from_provider_metadata(
        metadata,
        ClientId::new(client_id.to_string()),
        Some(ClientSecret::new(client_secret.to_string())),
    )
    .set_redirect_uri(
        RedirectUrl::new(redirect_url.to_string())
            .map_err(|e| format!("Invalid redirect URL: {}", e))?,
    );

    let code = AuthorizationCode::new(code.to_string());
    let token_response = client
        .exchange_code(code)?
        .set_pkce_verifier(pkce_verifier)
        .request_async(&http_client)
        .await
        .map_err(|e| format!("Token exchange failed: {}", e))?;

    let id_token = token_response
        .id_token()
        .ok_or("No id_token in OIDC token response")?;

    let id_token_verifier = client.id_token_verifier();
    let claims = id_token
        .claims(&id_token_verifier, nonce)
        .map_err(|e| format!("ID token validation failed: {}", e))?;

    Ok(claims.clone())
}

/// Extract email and display_name from validated OIDC claims.
pub fn extract_oidc_attributes(claims: &CoreIdTokenClaims) -> Option<OidcClaims> {
    let email = claims.email().map(|e| e.to_string())?;

    let display_name = claims
        .name()
        .and_then(|n| n.get(None))
        .map(|n| n.to_string());

    Some(OidcClaims {
        email,
        display_name,
        subject: claims.subject().to_string(),
    })
}
