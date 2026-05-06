import { useState, useCallback } from 'react';
import type { SsoConfig, CreateSsoConfigBody, UpdateSsoConfigBody } from '@/hooks/useAdmin';

interface SsoConfigFormProps {
  mode: 'create' | 'edit';
  existing?: SsoConfig;
  onClose: () => void;
  onSubmit:
    | ((body: CreateSsoConfigBody) => void)
    | ((
        params: { id: string; body: UpdateSsoConfigBody },
      ) => void);
  isSubmitting: boolean;
}

type ProviderType = 'oidc' | 'saml' | 'ldap';

const inputClass =
  'w-full rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

const labelClass =
  'mb-1 block text-[10px] uppercase tracking-wider text-text-disabled';

const errorClass = 'mt-0.5 text-[10px] text-accent-danger';

export function SsoConfigForm({
  mode,
  existing,
  onClose,
  onSubmit,
  isSubmitting,
}: SsoConfigFormProps) {
  const [providerType, setProviderType] = useState<ProviderType>(
    () =>
      (existing?.provider_type as ProviderType) || 'oidc',
  );
  const [name, setName] = useState(existing?.name || '');
  const [isActive, setIsActive] = useState(
    existing?.is_active ?? true,
  );

  // OIDC fields
  const [issuerUrl, setIssuerUrl] = useState(
    () => (existing?.config as Record<string, string>)?.issuer_url || '',
  );
  const [clientId, setClientId] = useState(
    () => (existing?.config as Record<string, string>)?.client_id || '',
  );
  const [clientSecret, setClientSecret] = useState('');
  const [scopes, setScopes] = useState(
    () =>
      ((existing?.config as Record<string, unknown>)?.scopes as string[])?.join(
        ', ',
      ) || 'openid, profile, email',
  );

  // SAML fields
  const [idpMetadataUrl, setIdpMetadataUrl] = useState(
    () =>
      (existing?.config as Record<string, string>)?.idp_metadata_url || '',
  );
  const [idpSsoUrl, setIdpSsoUrl] = useState(
    () => (existing?.config as Record<string, string>)?.idp_sso_url || '',
  );
  const [idpEntityId, setIdpEntityId] = useState(
    () =>
      (existing?.config as Record<string, string>)?.idp_entity_id || '',
  );
  const [spEntityId, setSpEntityId] = useState(
    () =>
      (existing?.config as Record<string, string>)?.sp_entity_id || '',
  );
  const [acsUrl, setAcsUrl] = useState(
    () => (existing?.config as Record<string, string>)?.acs_url || '',
  );
  const [idpSigningCert, setIdpSigningCert] = useState('');

  // LDAP fields
  const [serverUrl, setServerUrl] = useState(
    () => (existing?.config as Record<string, string>)?.server_url || '',
  );
  const [bindDn, setBindDn] = useState(
    () => (existing?.config as Record<string, string>)?.bind_dn || '',
  );
  const [bindPassword, setBindPassword] = useState('');
  const [searchBase, setSearchBase] = useState(
    () =>
      (existing?.config as Record<string, string>)?.search_base || '',
  );
  const [userFilter, setUserFilter] = useState(
    () =>
      (existing?.config as Record<string, string>)?.user_filter ||
      '(mail={username})',
  );
  const [emailAttr, setEmailAttr] = useState(
    () =>
      (existing?.config as Record<string, string>)?.email_attribute || 'mail',
  );
  const [displayNameAttr, setDisplayNameAttr] = useState(
    () =>
      (existing?.config as Record<string, string>)?.display_name_attribute ||
      'displayName',
  );

  // Common attribute mapping
  const [attrEmail, setAttrEmail] = useState(
    () =>
      (existing?.config as Record<string, unknown>)?.attribute_mapping
        ? (
            (existing?.config as Record<string, unknown>)
              ?.attribute_mapping as Record<string, string>
          )?.email || ''
        : '',
  );
  const [attrDisplayName, setAttrDisplayName] = useState(
    () =>
      (existing?.config as Record<string, unknown>)?.attribute_mapping
        ? (
            (existing?.config as Record<string, unknown>)
              ?.attribute_mapping as Record<string, string>
          )?.display_name || ''
        : '',
  );

  const [errors, setErrors] = useState<Record<string, string>>({});

  const validate = useCallback((): boolean => {
    const errs: Record<string, string> = {};
    if (!name.trim()) errs.name = 'Provider name is required';

    if (providerType === 'oidc') {
      if (!issuerUrl.trim()) errs.issuerUrl = 'Issuer URL is required';
      if (!clientId.trim()) errs.clientId = 'Client ID is required';
    }
    if (providerType === 'saml') {
      if (!idpSsoUrl.trim()) errs.idpSsoUrl = 'IdP SSO URL is required';
      if (!idpEntityId.trim()) errs.idpEntityId = 'IdP Entity ID is required';
      if (!spEntityId.trim()) errs.spEntityId = 'SP Entity ID is required';
    }
    if (providerType === 'ldap') {
      if (!serverUrl.trim()) errs.serverUrl = 'Server URL is required';
      if (!bindDn.trim()) errs.bindDn = 'Bind DN is required';
      if (!searchBase.trim()) errs.searchBase = 'Search base is required';
    }
    setErrors(errs);
    return Object.keys(errs).length === 0;
  }, [providerType, name, issuerUrl, clientId, idpSsoUrl, idpEntityId, spEntityId, serverUrl, bindDn, searchBase]);

  const handleSubmit = () => {
    if (!validate()) return;

    let config: Record<string, unknown> = {};

    if (providerType === 'oidc') {
      config = {
        issuer_url: issuerUrl,
        client_id: clientId,
        client_secret: clientSecret || undefined,
        scopes: scopes
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean),
        attribute_mapping:
          attrEmail || attrDisplayName
            ? { email: attrEmail || undefined, display_name: attrDisplayName || undefined }
            : undefined,
      };
    } else if (providerType === 'saml') {
      config = {
        idp_metadata_url: idpMetadataUrl || undefined,
        idp_sso_url: idpSsoUrl,
        idp_entity_id: idpEntityId,
        sp_entity_id: spEntityId,
        acs_url: acsUrl || undefined,
        idp_signing_cert: idpSigningCert || undefined,
        attribute_mapping:
          attrEmail || attrDisplayName
            ? { email: attrEmail || undefined, display_name: attrDisplayName || undefined }
            : undefined,
      };
    } else if (providerType === 'ldap') {
      config = {
        server_url: serverUrl,
        bind_dn: bindDn,
        bind_password: bindPassword || undefined,
        search_base: searchBase,
        user_filter: userFilter,
        email_attribute: emailAttr,
        display_name_attribute: displayNameAttr,
        attribute_mapping:
          attrEmail || attrDisplayName
            ? { email: attrEmail || undefined, display_name: attrDisplayName || undefined }
            : undefined,
      };
    }

    if (mode === 'create') {
      (onSubmit as (body: CreateSsoConfigBody) => void)({
        provider_type: providerType,
        name: name.trim(),
        config,
        is_active: isActive,
      });
    } else if (existing) {
      (onSubmit as (params: { id: string; body: UpdateSsoConfigBody }) => void)({
        id: existing.id,
        body: {
          name: name.trim() || undefined,
          config,
          is_active: isActive,
        },
      });
    }
  };

  return (
    <div className="rounded-lg border border-accent-blue/30 bg-bg-elevated p-4 space-y-4">
      <h3 className="text-sm font-semibold text-text-primary">
        {mode === 'create' ? 'Add SSO Provider' : 'Edit SSO Provider'}
      </h3>

      {/* Provider type selector */}
      <div>
        <label className={labelClass}>Provider Type</label>
        <div className="flex gap-2">
          {(['oidc', 'saml', 'ldap'] as const).map((type) => (
            <button
              key={type}
              onClick={() => setProviderType(type)}
              className={`rounded px-3 py-1.5 text-xs font-medium transition-colors ${
                providerType === type
                  ? 'bg-accent-blue text-white'
                  : 'bg-bg-input text-text-secondary hover:text-text-primary'
              }`}
            >
              {type.toUpperCase()}
            </button>
          ))}
        </div>
      </div>

      {/* Name */}
      <div>
        <label className={labelClass}>Provider Name *</label>
        <input
          type="text"
          className={inputClass}
          placeholder="e.g., Company Okta"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        {errors.name && <p className={errorClass}>{errors.name}</p>}
      </div>

      {/* OIDC fields */}
      {providerType === 'oidc' && (
        <>
          <div>
            <label className={labelClass}>Issuer URL *</label>
            <input
              type="url"
              className={inputClass}
              placeholder="https://accounts.google.com"
              value={issuerUrl}
              onChange={(e) => setIssuerUrl(e.target.value)}
            />
            {errors.issuerUrl && (
              <p className={errorClass}>{errors.issuerUrl}</p>
            )}
          </div>
          <div>
            <label className={labelClass}>Client ID *</label>
            <input
              type="text"
              className={inputClass}
              placeholder="your-client-id"
              value={clientId}
              onChange={(e) => setClientId(e.target.value)}
            />
            {errors.clientId && (
              <p className={errorClass}>{errors.clientId}</p>
            )}
          </div>
          <div>
            <label className={labelClass}>
              Client Secret {mode === 'create' ? '*' : '(leave blank to keep)'}
            </label>
            <input
              type="password"
              className={inputClass}
              placeholder="your-client-secret"
              value={clientSecret}
              onChange={(e) => setClientSecret(e.target.value)}
            />
          </div>
          <div>
            <label className={labelClass}>Scopes (comma-separated)</label>
            <input
              type="text"
              className={inputClass}
              placeholder="openid, profile, email"
              value={scopes}
              onChange={(e) => setScopes(e.target.value)}
            />
          </div>
        </>
      )}

      {/* SAML fields */}
      {providerType === 'saml' && (
        <>
          <div>
            <label className={labelClass}>IdP Metadata URL</label>
            <input
              type="url"
              className={inputClass}
              placeholder="https://idp.example.com/metadata"
              value={idpMetadataUrl}
              onChange={(e) => setIdpMetadataUrl(e.target.value)}
            />
          </div>
          <div>
            <label className={labelClass}>IdP SSO URL *</label>
            <input
              type="url"
              className={inputClass}
              placeholder="https://idp.example.com/sso"
              value={idpSsoUrl}
              onChange={(e) => setIdpSsoUrl(e.target.value)}
            />
            {errors.idpSsoUrl && (
              <p className={errorClass}>{errors.idpSsoUrl}</p>
            )}
          </div>
          <div>
            <label className={labelClass}>IdP Entity ID *</label>
            <input
              type="text"
              className={inputClass}
              placeholder="https://idp.example.com/entity"
              value={idpEntityId}
              onChange={(e) => setIdpEntityId(e.target.value)}
            />
            {errors.idpEntityId && (
              <p className={errorClass}>{errors.idpEntityId}</p>
            )}
          </div>
          <div>
            <label className={labelClass}>SP Entity ID *</label>
            <input
              type="text"
              className={inputClass}
              placeholder="benchify-sp"
              value={spEntityId}
              onChange={(e) => setSpEntityId(e.target.value)}
            />
            {errors.spEntityId && (
              <p className={errorClass}>{errors.spEntityId}</p>
            )}
          </div>
          <div>
            <label className={labelClass}>ACS URL</label>
            <input
              type="url"
              className={inputClass}
              placeholder="Auto-generated if blank"
              value={acsUrl}
              onChange={(e) => setAcsUrl(e.target.value)}
            />
          </div>
          <div>
            <label className={labelClass}>
              IdP Signing Cert (PEM) {mode === 'create' ? '' : '(leave blank to keep)'}
            </label>
            <textarea
              className={inputClass}
              rows={3}
              placeholder="-----BEGIN CERTIFICATE-----&#10;..."
              value={idpSigningCert}
              onChange={(e) => setIdpSigningCert(e.target.value)}
            />
          </div>
        </>
      )}

      {/* LDAP fields */}
      {providerType === 'ldap' && (
        <>
          <div>
            <label className={labelClass}>Server URL *</label>
            <input
              type="url"
              className={inputClass}
              placeholder="ldaps://ldap.example.com:636"
              value={serverUrl}
              onChange={(e) => setServerUrl(e.target.value)}
            />
            {errors.serverUrl && (
              <p className={errorClass}>{errors.serverUrl}</p>
            )}
          </div>
          <div>
            <label className={labelClass}>Bind DN *</label>
            <input
              type="text"
              className={inputClass}
              placeholder="cn=admin,dc=example,dc=com"
              value={bindDn}
              onChange={(e) => setBindDn(e.target.value)}
            />
            {errors.bindDn && <p className={errorClass}>{errors.bindDn}</p>}
          </div>
          <div>
            <label className={labelClass}>
              Bind Password {mode === 'create' ? '*' : '(leave blank to keep)'}
            </label>
            <input
              type="password"
              className={inputClass}
              placeholder="bind-password"
              value={bindPassword}
              onChange={(e) => setBindPassword(e.target.value)}
            />
          </div>
          <div>
            <label className={labelClass}>Search Base *</label>
            <input
              type="text"
              className={inputClass}
              placeholder="dc=example,dc=com"
              value={searchBase}
              onChange={(e) => setSearchBase(e.target.value)}
            />
            {errors.searchBase && (
              <p className={errorClass}>{errors.searchBase}</p>
            )}
          </div>
          <div>
            <label className={labelClass}>User Filter</label>
            <input
              type="text"
              className={inputClass}
              placeholder="(mail={username})"
              value={userFilter}
              onChange={(e) => setUserFilter(e.target.value)}
            />
          </div>
          <div>
            <label className={labelClass}>Email Attribute</label>
            <input
              type="text"
              className={inputClass}
              placeholder="mail"
              value={emailAttr}
              onChange={(e) => setEmailAttr(e.target.value)}
            />
          </div>
          <div>
            <label className={labelClass}>Display Name Attribute</label>
            <input
              type="text"
              className={inputClass}
              placeholder="displayName"
              value={displayNameAttr}
              onChange={(e) => setDisplayNameAttr(e.target.value)}
            />
          </div>
        </>
      )}

      {/* Common attribute mapping */}
      <div className="border-t border-border-subtle pt-3">
        <p className="mb-2 text-xs font-medium text-text-secondary">
          Attribute Mapping
        </p>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className={labelClass}>Email Attribute</label>
            <input
              type="text"
              className={inputClass}
              placeholder="email"
              value={attrEmail}
              onChange={(e) => setAttrEmail(e.target.value)}
            />
          </div>
          <div>
            <label className={labelClass}>Display Name Attribute</label>
            <input
              type="text"
              className={inputClass}
              placeholder="name"
              value={attrDisplayName}
              onChange={(e) => setAttrDisplayName(e.target.value)}
            />
          </div>
        </div>
      </div>

      {/* Active toggle */}
      <div className="flex items-center gap-2">
        <input
          type="checkbox"
          id="sso-active"
          className="rounded border-border-subtle bg-bg-input accent-accent-blue"
          checked={isActive}
          onChange={(e) => setIsActive(e.target.checked)}
        />
        <label
          htmlFor="sso-active"
          className="text-xs text-text-secondary"
        >
          Active
        </label>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-2 pt-2">
        <button
          onClick={handleSubmit}
          disabled={isSubmitting}
          className="rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white hover:opacity-90 disabled:opacity-50"
        >
          {isSubmitting
            ? mode === 'create'
              ? 'Creating...'
              : 'Saving...'
            : mode === 'create'
              ? 'Add Provider'
              : 'Save Changes'}
        </button>
        <button
          onClick={onClose}
          className="rounded px-3 py-1.5 text-xs text-text-secondary hover:text-text-primary"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}
