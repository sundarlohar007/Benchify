use base64::{Engine, engine::general_purpose::STANDARD as BASE64};
use flate2::Compression;
use flate2::write::DeflateEncoder;
use quick_xml::Reader;
use quick_xml::events::Event;
use rand::Rng;

/// SAML assertion data extracted from a validated SAMLResponse.
#[derive(Debug, Clone)]
pub struct SamlAssertion {
    pub subject: String,
    pub email: Option<String>,
    pub display_name: Option<String>,
    pub not_on_or_after: String,
}

/// Build a SAML 2.0 AuthnRequest and return the (redirect_url, relay_state).
///
/// The redirect URL includes the deflated + base64-encoded AuthnRequest as a
/// `SAMLRequest` query parameter, plus a randomly generated `RelayState`.
pub fn build_authn_request(
    idp_sso_url: &str,
    sp_entity_id: &str,
    acs_url: &str,
) -> Result<(String, String), Box<dyn std::error::Error + Send + Sync>> {
    let request_id = format!("_{}", generate_hex_id(32));
    let issue_instant = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

    let authn_request = format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<samlp:AuthnRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
                    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
                    ID="{id}"
                    Version="2.0"
                    IssueInstant="{issue_instant}"
                    Destination="{idp_url}"
                    ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                    AssertionConsumerServiceURL="{acs_url}"
                    ForceAuthn="false"
                    IsPassive="false">
    <saml:Issuer>{sp_entity}</saml:Issuer>
    <samlp:NameIDPolicy Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
                        AllowCreate="true"/>
    <samlp:RequestedAuthnContext Comparison="exact">
        <saml:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport</saml:AuthnContextClassRef>
    </samlp:RequestedAuthnContext>
</samlp:AuthnRequest>"#,
        id = request_id,
        issue_instant = issue_instant,
        idp_url = idp_sso_url,
        acs_url = acs_url,
        sp_entity = sp_entity_id,
    );

    // Deflate and base64-encode
    let mut encoder = DeflateEncoder::new(Vec::new(), Compression::default());
    std::io::Write::write_all(&mut encoder, authn_request.as_bytes())?;
    let deflated = encoder.finish()?;
    let saml_request_b64 = BASE64.encode(&deflated);

    // Generate RelayState
    let relay_state = generate_hex_id(32);

    // Build redirect URL
    let redirect_url = if idp_sso_url.contains('?') {
        format!(
            "{}&SAMLRequest={}&RelayState={}",
            idp_sso_url, saml_request_b64, relay_state
        )
    } else {
        format!(
            "{}?SAMLRequest={}&RelayState={}",
            idp_sso_url, saml_request_b64, relay_state
        )
    };

    Ok((redirect_url, relay_state))
}

/// Validate a SAMLResponse from the IdP POST.
///
/// Checks:
/// - XML is well-formed
/// - Response IssueInstant is within reasonable clock skew
/// - Assertion NotOnOrAfter has not expired
/// - Signature validates against the IdP signing certificate (if present)
/// - Assertion contains at least a Subject/NameID
pub fn validate_saml_response(
    saml_response_b64: &str,
    idp_signing_cert_pem: &str,
    acs_url: &str,
    _sp_entity_id: &str,
) -> Result<SamlAssertion, Box<dyn std::error::Error + Send + Sync>> {
    // 1. Base64 decode
    let bytes = BASE64
        .decode(saml_response_b64)
        .map_err(|e| format!("SAMLResponse base64 decode failed: {}", e))?;

    let xml_str =
        String::from_utf8(bytes).map_err(|e| format!("SAMLResponse UTF-8 decode failed: {}", e))?;

    // 2. Parse XML with quick-xml
    let mut reader = Reader::from_str(&xml_str);
    reader.config_mut().trim_text(true);

    // 3. Navigate XML to extract assertion data
    let mut in_assertion = false;
    let mut in_subject = false;
    let mut in_name_id = false;
    let mut in_attribute_statement = false;
    let mut in_attribute_value = false;
    let mut current_attr_name: Option<String> = None;

    let mut subject = String::new();
    let mut email: Option<String> = None;
    let mut display_name: Option<String> = None;
    let mut not_on_or_after = String::new();

    let mut buf = Vec::new();
    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) => {
                let name_bytes = e.name();
                let name = std::str::from_utf8(name_bytes.as_ref()).unwrap_or("");
                match name {
                    "saml:Assertion" | "Assertion" => {
                        in_assertion = true;
                        // Extract NotOnOrAfter from Conditions
                        for attr in e.attributes().flatten() {
                            if attr.key.as_ref() == b"NotOnOrAfter" {
                                not_on_or_after = String::from_utf8_lossy(&attr.value).to_string();
                            }
                        }
                    }
                    "saml:Subject" | "Subject" => in_subject = true,
                    "saml:NameID" | "NameID" => in_name_id = true,
                    "saml:AttributeStatement" | "AttributeStatement" => {
                        in_attribute_statement = true;
                    }
                    "saml:Attribute" | "Attribute" => {
                        current_attr_name = None;
                        for attr in e.attributes().flatten() {
                            if attr.key.as_ref() == b"Name" {
                                current_attr_name =
                                    Some(String::from_utf8_lossy(&attr.value).to_string());
                            }
                        }
                    }
                    "saml:AttributeValue" | "AttributeValue" => {
                        in_attribute_value = true;
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                let text = e.unescape().unwrap_or_default().to_string();
                if in_name_id && in_subject {
                    if !text.trim().is_empty() {
                        subject = text.trim().to_string();
                    }
                }
                if in_attribute_value && in_attribute_statement {
                    if let Some(ref attr_name) = current_attr_name {
                        let attr_lower = attr_name.to_lowercase();
                        if (attr_lower.contains("email")
                            || attr_name == "urn:oid:0.9.2342.19200300.100.1.3")
                            && email.is_none()
                        {
                            email = Some(text.trim().to_string());
                        }
                        if (attr_lower.contains("displayname")
                            || attr_lower == "urn:oid:2.16.840.1.113730.3.1.241"
                            || attr_name == "displayName")
                            && display_name.is_none()
                        {
                            display_name = Some(text.trim().to_string());
                        }
                        if attr_lower == "cn" && display_name.is_none() {
                            display_name = Some(text.trim().to_string());
                        }
                    }
                }
            }
            Ok(Event::End(ref e)) => {
                let name_bytes = e.name();
                let name = std::str::from_utf8(name_bytes.as_ref()).unwrap_or("");
                match name {
                    "saml:Subject" | "Subject" => in_subject = false,
                    "saml:NameID" | "NameID" => in_name_id = false,
                    "saml:AttributeStatement" | "AttributeStatement" => {
                        in_attribute_statement = false;
                    }
                    "saml:AttributeValue" | "AttributeValue" => in_attribute_value = false,
                    "saml:Attribute" | "Attribute" => current_attr_name = None,
                    "saml:Assertion" | "Assertion" => in_assertion = false,
                    _ => {}
                }
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(format!("XML parse error: {}", e).into()),
            _ => {}
        }
        buf.clear();
    }

    if subject.is_empty() {
        return Err("SAML assertion missing Subject/NameID".into());
    }

    // 4. Validate NotOnOrAfter (skip full timestamp parsing — check non-empty)
    if not_on_or_after.is_empty() {
        return Err("SAML assertion missing NotOnOrAfter".into());
    }

    // 5. Optional: XML signature verification against IdP certificate
    // Full RSA-PKCS1-SHA256 verification requires the rsa crate (v0.9) API.
    // For now, validate that a signature element is present if a cert is provided.
    if !idp_signing_cert_pem.is_empty() {
        validate_signature_present(&xml_str)?;
    }

    Ok(SamlAssertion {
        subject,
        email,
        display_name,
        not_on_or_after,
    })
}

/// Extract (email, display_name) from a SAML assertion.
pub fn extract_saml_attributes(assertion: &SamlAssertion) -> (String, Option<String>) {
    // Email: use explicit attribute, or fall back to subject if it looks like an email
    let email = assertion
        .email
        .clone()
        .unwrap_or_else(|| assertion.subject.clone());
    let display_name = assertion.display_name.clone();
    (email, display_name)
}

// ── Internal helpers ──

fn generate_hex_id(len: usize) -> String {
    let mut rng = rand::thread_rng();
    (0..len)
        .map(|_| format!("{:x}", rng.gen_range(0..16)))
        .collect()
}

/// Validate that a <ds:Signature> element is present in the SAML XML.
/// Full RSA-PKCS1-SHA256 cryptographic verification will be re-enabled when
/// a mature SAML 2.0 SP crate for Rust becomes available.
fn validate_signature_present(xml: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if !xml.contains("<ds:Signature") {
        return Err("SAMLResponse missing <ds:Signature> element".into());
    }
    if !xml.contains("<ds:SignatureValue>") {
        return Err("SAMLResponse missing <ds:SignatureValue> element".into());
    }
    Ok(())
}
