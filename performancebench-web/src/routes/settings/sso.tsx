import { useState } from 'react';
import { createFileRoute } from '@tanstack/react-router';
import { Plus, Edit, Trash2, Shield } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { useAuth } from '@/hooks/useAuth';
import { RoleBadge } from '@/components/admin/RoleBadge';
import { SsoConfigForm } from '@/components/admin/SsoConfigForm';
import {
  useSsoConfigs,
  useCreateSsoConfig,
  useUpdateSsoConfig,
  useDeleteSsoConfig,
} from '@/hooks/useAdmin';

export const Route = createFileRoute('/settings/sso')({
  component: SsoSettingsPage,
});

const providerTypeLabel = (type: string): string => {
  switch (type) {
    case 'oidc':
      return 'OIDC';
    case 'saml':
      return 'SAML';
    case 'ldap':
      return 'LDAP';
    default:
      return type.toUpperCase();
  }
};

const providerTypeBadge = (type: string): string => {
  switch (type) {
    case 'oidc':
      return 'bg-accent-blue/15 text-accent-blue';
    case 'saml':
      return 'bg-accent-warning/15 text-accent-warning';
    case 'ldap':
      return 'bg-purple-500/15 text-purple-400';
    default:
      return 'bg-bg-input text-text-secondary';
  }
};

const inputClass =
  'w-full rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

function SsoSettingsPage() {
  const { user } = useAuth();
  const { data: configs, isLoading, error } = useSsoConfigs();
  const createMut = useCreateSsoConfig();
  const updateMut = useUpdateSsoConfig();
  const deleteMut = useDeleteSsoConfig();

  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);

  const ssoConfigs = configs ?? [];
  const editingConfig = editingId
    ? ssoConfigs.find((c) => c.id === editingId)
    : undefined;

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-text-primary">
              SSO Providers
            </h1>
            <p className="mt-1 text-sm text-text-secondary">
              Configure enterprise single sign-on for OIDC, SAML, and LDAP
              providers.
            </p>
          </div>
          {!showForm && (
            <button
              onClick={() => {
                setShowForm(true);
                setEditingId(null);
              }}
              className="flex items-center gap-1.5 rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white transition-opacity hover:opacity-90"
            >
              <Plus className="h-3.5 w-3.5" />
              Add Provider
            </button>
          )}
        </div>

        {/* Info banner */}
        <div className="rounded border border-accent-blue/20 bg-accent-blue/5 px-4 py-3 text-xs text-text-secondary">
          <Shield className="mr-2 inline-block h-3.5 w-3.5 text-accent-blue" />
          SSO can also be configured via config file or environment variables
          (<code className="text-accent-blue">SSO_ENABLED</code>,{' '}
          <code className="text-accent-blue">OIDC_PROVIDERS</code>). Database
          configuration takes precedence.
        </div>

        {/* Error state */}
        {error && (
          <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-4 py-3 text-sm text-accent-danger">
            Failed to load SSO configurations.
          </div>
        )}

        {/* Loading state */}
        {isLoading && (
          <div className="space-y-2">
            {Array.from({ length: 2 }).map((_, i) => (
              <div
                key={i}
                className="h-20 animate-pulse rounded bg-bg-elevated"
              />
            ))}
          </div>
        )}

        {/* Form */}
        {showForm && (
          <SsoConfigForm
            mode={editingId ? 'edit' : 'create'}
            existing={editingConfig}
            onClose={() => {
              setShowForm(false);
              setEditingId(null);
            }}
            onSubmit={(bodyOrParams) => {
              if ('provider_type' in bodyOrParams) {
                createMut.mutate(bodyOrParams, {
                  onSuccess: () => setShowForm(false),
                });
              } else {
                updateMut.mutate(bodyOrParams, {
                  onSuccess: () => setShowForm(false),
                });
              }
            }}
            isSubmitting={createMut.isPending || updateMut.isPending}
          />
        )}

        {/* Empty state */}
        {!isLoading && ssoConfigs.length === 0 && !showForm && (
          <div className="flex flex-col items-center py-12 text-text-disabled">
            <Shield className="mb-3 h-8 w-8" />
            <p>No SSO providers configured.</p>
            <p className="mt-1 text-xs">
              Add one to enable enterprise single sign-on.
            </p>
          </div>
        )}

        {/* Provider cards */}
        <div className="space-y-3">
          {ssoConfigs.map((config) => (
            <div
              key={config.id}
              className="rounded-lg border border-border-subtle bg-bg-elevated p-4"
            >
              <div className="flex items-start justify-between">
                <div className="space-y-1.5">
                  <div className="flex items-center gap-2">
                    <h4 className="text-sm font-medium text-text-primary">
                      {config.name}
                    </h4>
                    <span
                      className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${providerTypeBadge(config.provider_type)}`}
                    >
                      {providerTypeLabel(config.provider_type)}
                    </span>
                    <span
                      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${
                        config.is_active
                          ? 'bg-accent-success/15 text-accent-success'
                          : 'bg-accent-danger/15 text-accent-danger'
                      }`}
                    >
                      {config.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </div>
                  <div className="flex items-center gap-4 text-xs text-text-disabled">
                    <span>
                      ID:{' '}
                      <code className="font-mono">
                        {config.id.slice(0, 8)}
                      </code>
                    </span>
                    <span>
                      Created:{' '}
                      {new Date(config.created_at).toLocaleDateString(
                        'en-US',
                        {
                          month: 'short',
                          day: 'numeric',
                          year: 'numeric',
                        },
                      )}
                    </span>
                  </div>
                </div>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => {
                      setEditingId(config.id);
                      setShowForm(true);
                    }}
                    className="rounded p-1.5 text-text-disabled hover:bg-bg-hover hover:text-text-primary"
                    title="Edit provider"
                  >
                    <Edit className="h-3.5 w-3.5" />
                  </button>
                  <button
                    onClick={() => setConfirmDelete(config.id)}
                    className="rounded p-1.5 text-text-disabled hover:bg-accent-danger/10 hover:text-accent-danger"
                    title="Delete provider"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Delete confirmation modal */}
        {confirmDelete && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
            <div className="w-96 rounded-lg border border-border-subtle bg-bg-elevated p-6 shadow-xl">
              <h3 className="text-sm font-semibold text-text-primary">
                Delete SSO Provider
              </h3>
              <p className="mt-2 text-sm text-text-secondary">
                Are you sure you want to delete this SSO provider? Users who
                signed up via this provider will still be able to log in using
                local auth (if they set a password).
              </p>
              <div className="mt-4 flex justify-end gap-2">
                <button
                  onClick={() => setConfirmDelete(null)}
                  className="rounded px-3 py-1.5 text-xs text-text-secondary hover:text-text-primary"
                >
                  Cancel
                </button>
                <button
                  onClick={() => {
                    deleteMut.mutate(confirmDelete, {
                      onSuccess: () => setConfirmDelete(null),
                    });
                  }}
                  disabled={deleteMut.isPending}
                  className="rounded bg-accent-danger px-3 py-1.5 text-xs font-medium text-white hover:opacity-90 disabled:opacity-50"
                >
                  {deleteMut.isPending ? 'Deleting...' : 'Delete'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </ProtectedRoute>
  );
}
