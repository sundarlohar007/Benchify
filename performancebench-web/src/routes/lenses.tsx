import { useState } from 'react';
import { createFileRoute, useNavigate } from '@tanstack/react-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2, ExternalLink, Eye, EyeOff, X, Save } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { api } from '@/lib/api';

// ─── Types ──────────────────────────────────────────────────────────────────

interface Lens {
  id: string;
  user_id: string;
  name: string;
  description: string | null;
  filters: Record<string, unknown>;
  chart_config: Record<string, unknown>;
  is_public: boolean;
  created_at: string;
  updated_at: string;
}

interface LensFormData {
  name: string;
  description: string;
  appName: string;
  deviceModel: string;
  tags: string;
  projectId: string;
  dateFrom: string;
  dateTo: string;
  isPublic: boolean;
}

const EMPTY_FORM: LensFormData = {
  name: '',
  description: '',
  appName: '',
  deviceModel: '',
  tags: '',
  projectId: '',
  dateFrom: '',
  dateTo: '',
  isPublic: false,
};

// ─── Route ──────────────────────────────────────────────────────────────────

export const Route = createFileRoute('/lenses')({
  component: LensesPage,
});

function LensesPage() {
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState<LensFormData>(EMPTY_FORM);
  const [editingId, setEditingId] = useState<string | null>(null);

  const { data, isLoading, error } = useQuery({
    queryKey: ['lenses'],
    queryFn: () =>
      api.get<{ data: Lens[] }>('/api/v1/lenses?include_public=true'),
  });

  const createMutation = useMutation({
    mutationFn: (body: Record<string, unknown>) =>
      api.post<Lens>('/api/v1/lenses', body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['lenses'] });
      setShowCreate(false);
      setForm(EMPTY_FORM);
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, body }: { id: string; body: Record<string, unknown> }) =>
      api.put<Lens>(`/api/v1/lenses/${id}`, body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['lenses'] });
      setEditingId(null);
      setForm(EMPTY_FORM);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/lenses/${id}`),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['lenses'] }),
  });

  const buildFiltersFromForm = () => {
    const filters: Record<string, unknown> = {};
    if (form.appName) filters.appName = form.appName;
    if (form.deviceModel) filters.deviceModel = form.deviceModel;
    if (form.tags) filters.tags = form.tags;
    if (form.projectId) filters.projectId = form.projectId;
    if (form.dateFrom) filters.dateFrom = form.dateFrom;
    if (form.dateTo) filters.dateTo = form.dateTo;
    return filters;
  };

  const handleSave = () => {
    const filtersJson = buildFiltersFromForm();
    const body = {
      name: form.name,
      description: form.description || null,
      filters: filtersJson,
      chart_config: { charts: ['fps', 'cpu', 'memory'], height: 300, showGrid: true },
      is_public: form.isPublic,
    };
    if (editingId) {
      updateMutation.mutate({ id: editingId, body });
    } else {
      createMutation.mutate(body);
    }
  };

  const handleApply = (lens: Lens) => {
    const filters = lens.filters as Record<string, string>;
    const params = new URLSearchParams();
    if (filters.appName) params.set('app_name', filters.appName);
    if (filters.deviceModel) params.set('device_model', filters.deviceModel);
    if (filters.tags) params.set('tags', filters.tags);
    if (filters.projectId) params.set('project_id', filters.projectId);
    if (filters.dateFrom) params.set('date_from', filters.dateFrom);
    if (filters.dateTo) params.set('date_to', filters.dateTo);
    navigate({ to: '/sessions', search: Object.fromEntries(params) as any });
  };

  const startEdit = (lens: Lens) => {
    const f = lens.filters as Record<string, string>;
    setForm({
      name: lens.name,
      description: lens.description ?? '',
      appName: f.appName ?? '',
      deviceModel: f.deviceModel ?? '',
      tags: f.tags ?? '',
      projectId: f.projectId ?? '',
      dateFrom: f.dateFrom ?? '',
      dateTo: f.dateTo ?? '',
      isPublic: lens.is_public,
    });
    setEditingId(lens.id);
    setShowCreate(true);
  };

  const lenses = data?.data ?? [];

  const inputClass =
    'w-full rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-text-primary">Lenses</h1>
            <p className="mt-1 text-sm text-text-secondary">
              Save and apply custom filter configurations across your sessions.
            </p>
          </div>
          <button
            onClick={() => {
              setForm(EMPTY_FORM);
              setEditingId(null);
              setShowCreate(true);
            }}
            className="flex items-center gap-1.5 rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white transition-opacity hover:opacity-90"
          >
            <Plus className="h-3.5 w-3.5" />
            New Lens
          </button>
        </div>

        {/* Create/Edit Modal */}
        {showCreate && (
          <div className="rounded-lg border border-border-subtle bg-bg-elevated p-4 space-y-3">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-semibold text-text-primary">
                {editingId ? 'Edit Lens' : 'Create New Lens'}
              </h3>
              <button
                onClick={() => {
                  setShowCreate(false);
                  setEditingId(null);
                }}
                className="text-text-disabled hover:text-text-primary"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                  Name *
                </label>
                <input
                  type="text"
                  className={inputClass}
                  placeholder="e.g. Release 1.0 Perf"
                  value={form.name}
                  onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))}
                />
              </div>
              <div>
                <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                  Description
                </label>
                <input
                  type="text"
                  className={inputClass}
                  placeholder="Optional description"
                  value={form.description}
                  onChange={(e) =>
                    setForm((p) => ({ ...p, description: e.target.value }))
                  }
                />
              </div>
            </div>

            <h4 className="text-[10px] font-semibold uppercase tracking-wider text-text-disabled pt-2">
              Filter Configuration
            </h4>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <div>
                <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                  App Name
                </label>
                <input
                  type="text"
                  className={inputClass}
                  placeholder="e.g. Benchify"
                  value={form.appName}
                  onChange={(e) =>
                    setForm((p) => ({ ...p, appName: e.target.value }))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                  Device
                </label>
                <input
                  type="text"
                  className={inputClass}
                  placeholder="e.g. Pixel 8"
                  value={form.deviceModel}
                  onChange={(e) =>
                    setForm((p) => ({ ...p, deviceModel: e.target.value }))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                  Tags
                </label>
                <input
                  type="text"
                  className={inputClass}
                  placeholder="e.g. release"
                  value={form.tags}
                  onChange={(e) =>
                    setForm((p) => ({ ...p, tags: e.target.value }))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                  Project ID
                </label>
                <input
                  type="text"
                  className={inputClass}
                  placeholder="UUID"
                  value={form.projectId}
                  onChange={(e) =>
                    setForm((p) => ({ ...p, projectId: e.target.value }))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                  From
                </label>
                <input
                  type="date"
                  className={inputClass}
                  value={form.dateFrom}
                  onChange={(e) =>
                    setForm((p) => ({ ...p, dateFrom: e.target.value }))
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                  To
                </label>
                <input
                  type="date"
                  className={inputClass}
                  value={form.dateTo}
                  onChange={(e) =>
                    setForm((p) => ({ ...p, dateTo: e.target.value }))
                  }
                />
              </div>
            </div>

            <label className="flex items-center gap-2 pt-2">
              <input
                type="checkbox"
                className="rounded border-border-subtle bg-bg-input accent-accent-blue"
                checked={form.isPublic}
                onChange={(e) =>
                  setForm((p) => ({ ...p, isPublic: e.target.checked }))
                }
              />
              <span className="text-xs text-text-secondary">Make public (visible to all team members)</span>
            </label>

            <div className="flex items-center gap-2 pt-2">
              <button
                onClick={handleSave}
                disabled={!form.name.trim()}
                className="flex items-center gap-1 rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white transition-opacity hover:opacity-90 disabled:opacity-50"
              >
                <Save className="h-3.5 w-3.5" />
                {editingId ? 'Update' : 'Save'}
              </button>
              <button
                onClick={() => {
                  setShowCreate(false);
                  setEditingId(null);
                }}
                className="rounded px-3 py-1.5 text-xs text-text-secondary hover:text-text-primary hover:bg-bg-hover"
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        {/* Error state */}
        {error && (
          <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-4 py-3 text-sm text-accent-danger">
            Failed to load lenses. Ensure the server is running.
          </div>
        )}

        {/* Loading state */}
        {isLoading && (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="h-40 animate-pulse rounded-lg bg-bg-elevated" />
            ))}
          </div>
        )}

        {/* Lens cards grid */}
        {!isLoading && lenses.length === 0 && (
          <p className="py-12 text-center text-text-disabled">
            No lenses created yet. Create your first lens to save filter configurations.
          </p>
        )}

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {lenses.map((lens) => {
            const f = lens.filters as Record<string, string>;
            const filterCount = Object.values(f).filter(Boolean).length;
            return (
              <div
                key={lens.id}
                className="rounded-lg border border-border-subtle bg-bg-elevated p-4 space-y-3"
              >
                <div className="flex items-start justify-between">
                  <div>
                    <h4 className="text-sm font-semibold text-text-primary">
                      {lens.name}
                    </h4>
                    {lens.description && (
                      <p className="mt-0.5 text-xs text-text-secondary">
                        {lens.description}
                      </p>
                    )}
                    <div className="mt-1 flex items-center gap-1">
                      {lens.is_public ? (
                        <Eye className="h-3 w-3 text-text-disabled" />
                      ) : (
                        <EyeOff className="h-3 w-3 text-text-disabled" />
                      )}
                      <span className="text-[10px] text-text-disabled">
                        {lens.is_public ? 'Public' : 'Private'}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Filter chips */}
                {filterCount > 0 && (
                  <div className="flex flex-wrap gap-1">
                    {f.appName && (
                      <span className="inline-block rounded bg-bg-hover px-1.5 py-0.5 text-[10px] text-text-secondary">
                        App: {f.appName}
                      </span>
                    )}
                    {f.deviceModel && (
                      <span className="inline-block rounded bg-bg-hover px-1.5 py-0.5 text-[10px] text-text-secondary">
                        Device: {f.deviceModel}
                      </span>
                    )}
                    {f.tags && (
                      <span className="inline-block rounded bg-bg-hover px-1.5 py-0.5 text-[10px] text-text-secondary">
                        Tags: {f.tags}
                      </span>
                    )}
                    {f.projectId && (
                      <span className="inline-block rounded bg-bg-hover px-1.5 py-0.5 text-[10px] text-text-secondary">
                        Project: {f.projectId.slice(0, 8)}
                      </span>
                    )}
                    {f.dateFrom && f.dateTo && (
                      <span className="inline-block rounded bg-bg-hover px-1.5 py-0.5 text-[10px] text-text-secondary">
                        {f.dateFrom} — {f.dateTo}
                      </span>
                    )}
                  </div>
                )}
                {filterCount === 0 && (
                  <p className="text-[10px] text-text-disabled italic">
                    No filters configured
                  </p>
                )}

                {/* Actions */}
                <div className="flex items-center gap-2 pt-1">
                  <button
                    onClick={() => handleApply(lens)}
                    className="flex items-center gap-1 rounded bg-accent-blue px-2 py-1 text-[10px] font-medium text-white hover:opacity-90"
                  >
                    <ExternalLink className="h-3 w-3" />
                    Apply
                  </button>
                  <button
                    onClick={() => startEdit(lens)}
                    className="rounded px-2 py-1 text-[10px] text-text-secondary hover:text-text-primary hover:bg-bg-hover"
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => {
                      if (confirm('Delete this lens?')) {
                        deleteMutation.mutate(lens.id);
                      }
                    }}
                    className="ml-auto rounded p-1 text-text-disabled hover:text-accent-danger hover:bg-accent-danger/10"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </ProtectedRoute>
  );
}
