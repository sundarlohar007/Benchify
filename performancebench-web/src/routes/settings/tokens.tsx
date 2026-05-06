import { useState } from 'react';
import { createFileRoute } from '@tanstack/react-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2, Copy, Key, Check } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { api } from '@/lib/api';
import { relativeTime } from '@/lib/utils';

// ─── Types ──────────────────────────────────────────────────────────────────

interface ApiToken {
  id: string;
  name: string;
  token_prefix: string;
  scopes: string[];
  last_used_at: string | null;
  expires_at: string | null;
  is_revoked: boolean;
  created_at: string;
}

interface CreateTokenResponse {
  token: string;
  message: string;
}

// ─── Route ──────────────────────────────────────────────────────────────────

export const Route = createFileRoute('/settings/tokens')({
  component: TokensPage,
});

function TokensPage() {
  const queryClient = useQueryClient();
  const [showCreate, setShowCreate] = useState(false);
  const [newToken, setNewToken] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const { data, isLoading, error } = useQuery({
    queryKey: ['tokens'],
    queryFn: () =>
      api.get<{ data: ApiToken[] }>('/api/v1/tokens'),
  });

  const createMutation = useMutation({
    mutationFn: (body: { name: string; scopes: string[] }) =>
      api.post<CreateTokenResponse>('/api/v1/tokens', body),
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['tokens'] });
      setNewToken(data.token);
      setShowCreate(false);
    },
  });

  const revokeMutation = useMutation({
    mutationFn: (id: string) =>
      api.delete(`/api/v1/tokens/${id}`),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['tokens'] }),
  });

  const tokens = data?.data ?? [];

  const handleCopy = (token: string) => {
    navigator.clipboard.writeText(token);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const scopeBadgeClass = (scope: string) => {
    switch (scope) {
      case 'admin':
        return 'bg-accent-danger/15 text-accent-danger';
      case 'write':
        return 'bg-accent-warning/15 text-accent-warning';
      default:
        return 'bg-accent-blue/15 text-accent-blue';
    }
  };

  const inputClass =
    'w-full rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-text-primary">
              API Tokens
            </h1>
            <p className="mt-1 text-sm text-text-secondary">
              Manage API tokens for CI/CD integration and desktop app uploads.
            </p>
          </div>
          <button
            onClick={() => {
              setShowCreate(true);
              setNewToken(null);
            }}
            className="flex items-center gap-1.5 rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white transition-opacity hover:opacity-90"
          >
            <Plus className="h-3.5 w-3.5" />
            New Token
          </button>
        </div>

        {/* New Token Display (shown once after creation) */}
        {newToken && (
          <div className="rounded-lg border border-accent-success/30 bg-accent-success/5 p-4 space-y-3">
            <div className="flex items-center gap-2">
              <Key className="h-4 w-4 text-accent-success" />
              <h3 className="text-sm font-semibold text-accent-success">
                Token Created
              </h3>
            </div>
            <div className="flex items-center gap-2">
              <code className="flex-1 rounded bg-bg-input px-3 py-2 font-mono-data text-sm text-text-primary break-all select-all">
                {newToken}
              </code>
              <button
                onClick={() => handleCopy(newToken)}
                className="flex items-center gap-1 rounded bg-bg-elevated px-3 py-2 text-xs text-text-secondary hover:text-text-primary border border-border-subtle"
              >
                {copied ? (
                  <Check className="h-3.5 w-3.5 text-accent-success" />
                ) : (
                  <Copy className="h-3.5 w-3.5" />
                )}
                {copied ? 'Copied' : 'Copy'}
              </button>
            </div>
            <p className="text-xs text-accent-warning font-medium">
              Copy this token now. You won't be able to see it again.
            </p>
            <button
              onClick={() => setNewToken(null)}
              className="text-xs text-text-secondary hover:text-text-primary"
            >
              Dismiss
            </button>
          </div>
        )}

        {/* Create Token Modal */}
        {showCreate && (
          <CreateTokenForm
            onClose={() => setShowCreate(false)}
            onCreate={(body) => createMutation.mutate(body)}
            isCreating={createMutation.isPending}
          />
        )}

        {/* Error state */}
        {error && (
          <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-4 py-3 text-sm text-accent-danger">
            Failed to load API tokens. Ensure the server is running.
          </div>
        )}

        {/* Loading state */}
        {isLoading && (
          <div className="space-y-2">
            {Array.from({ length: 3 }).map((_, i) => (
              <div
                key={i}
                className="h-14 animate-pulse rounded bg-bg-elevated"
              />
            ))}
          </div>
        )}

        {/* Empty state */}
        {!isLoading && tokens.length === 0 && (
          <div className="flex flex-col items-center py-12 text-text-disabled">
            <Key className="mb-3 h-8 w-8" />
            <p>No API tokens created yet.</p>
            <p className="mt-1 text-xs">
              Create a token for the desktop app or CI/CD pipeline.
            </p>
          </div>
        )}

        {/* Token List */}
        <div className="space-y-2">
          {tokens.map((token) => (
            <div
              key={token.id}
              className="rounded-lg border border-border-subtle bg-bg-elevated p-3"
            >
              <div className="flex items-center justify-between">
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <h4 className="text-sm font-medium text-text-primary">
                      {token.name}
                    </h4>
                    {token.is_revoked && (
                      <span className="inline-block rounded bg-accent-danger/15 px-2 py-0.5 text-[10px] font-medium text-accent-danger">
                        Revoked
                      </span>
                    )}
                  </div>
                  <code className="font-mono-data text-xs text-text-secondary">
                    {token.token_prefix}
                  </code>
                  <div className="flex items-center gap-2 text-[10px] text-text-disabled">
                    {token.scopes.map((scope) => (
                      <span
                        key={scope}
                        className={`inline-block rounded px-1.5 py-0.5 ${scopeBadgeClass(scope)}`}
                      >
                        {scope}
                      </span>
                    ))}
                    <span>
                      Created {relativeTime(token.created_at)}
                    </span>
                    {token.last_used_at && (
                      <span>
                        Last used {relativeTime(token.last_used_at)}
                      </span>
                    )}
                  </div>
                </div>
                {!token.is_revoked && (
                  <button
                    onClick={() => {
                      if (
                        confirm(
                          'Revoke this token? Any apps using it will no longer be able to connect.',
                        )
                      ) {
                        revokeMutation.mutate(token.id);
                      }
                    }}
                    className="flex items-center gap-1 rounded px-2 py-1 text-xs text-text-disabled hover:text-accent-danger hover:bg-accent-danger/10"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                    Revoke
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    </ProtectedRoute>
  );
}

// ─── Create Token Form ──────────────────────────────────────────────────────

function CreateTokenForm({
  onClose,
  onCreate,
  isCreating,
}: {
  onClose: () => void;
  onCreate: (body: { name: string; scopes: string[] }) => void;
  isCreating: boolean;
}) {
  const [name, setName] = useState('');
  const [scopes, setScopes] = useState<string[]>(['read']);

  const toggleScope = (scope: string) => {
    setScopes((prev) =>
      prev.includes(scope)
        ? prev.filter((s) => s !== scope)
        : [...prev, scope],
    );
  };

  const inputClass =
    'w-full rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

  return (
    <div className="rounded-lg border border-accent-blue/30 bg-bg-elevated p-4 space-y-3">
      <h3 className="text-sm font-semibold text-text-primary">
        Create API Token
      </h3>

      <div>
        <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
          Name *
        </label>
        <input
          type="text"
          className={inputClass}
          placeholder="e.g. Desktop App, CI Pipeline"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
      </div>

      <div>
        <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
          Scopes
        </label>
        <div className="flex flex-wrap gap-2">
          {(['read', 'write', 'admin'] as const).map((scope) => (
            <label
              key={scope}
              className="flex items-center gap-1.5 cursor-pointer"
            >
              <input
                type="checkbox"
                className="rounded border-border-subtle bg-bg-input accent-accent-blue"
                checked={scopes.includes(scope)}
                onChange={() => toggleScope(scope)}
              />
              <span className="text-xs text-text-secondary capitalize">
                {scope}
              </span>
            </label>
          ))}
        </div>
      </div>

      <div className="flex items-center gap-2 pt-2">
        <button
          onClick={() => onCreate({ name, scopes })}
          disabled={!name.trim() || scopes.length === 0 || isCreating}
          className="rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white hover:opacity-90 disabled:opacity-50"
        >
          {isCreating ? 'Creating...' : 'Create Token'}
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
