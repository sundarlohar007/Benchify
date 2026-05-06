import { useState, useCallback, useMemo } from 'react';
import { createFileRoute } from '@tanstack/react-router';
import { ChevronLeft, ChevronRight, BarChart3, AlertTriangle, Calendar } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { SessionFilters } from '@/components/sessions/SessionFilters';
import { SessionTable } from '@/components/sessions/SessionTable';
import {
  useSessions,
  useDeleteSession,
  type SessionFilters as Filters,
} from '@/hooks/useSessions';
import { DEFAULT_PAGE_SIZE } from '@/lib/constants';

export const Route = createFileRoute('/sessions/')({
  component: SessionsPage,
});

function SessionsPage() {
  const [offset, setOffset] = useState(0);
  const [limit] = useState(DEFAULT_PAGE_SIZE); // 50
  const [filters, setFilters] = useState<Filters>({});

  const { data, isLoading, error } = useSessions(offset, limit, filters);
  const deleteSession = useDeleteSession();

  const handleApplyFilters = useCallback((newFilters: Filters) => {
    setFilters(newFilters);
    setOffset(0); // reset to first page on filter change
  }, []);

  const handleDeleteSelected = useCallback(
    (ids: string[]) => {
      if (!confirm(`Delete ${ids.length} session(s)?\nThis cannot be undone.`))
        return;
      ids.forEach((id) => deleteSession.mutate(id));
    },
    [deleteSession],
  );

  const handleExportSelected = useCallback(
    (_ids: string[]) => {
      alert('Export will be available in a future release.');
    },
    [],
  );

  const total = data?.total ?? 0;

  // Dashboard summary stats
  const dashboardStats = useMemo(() => {
    const allSessions = data?.data ?? [];
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const thisMonth = allSessions.filter(
      (s) => new Date(s.started_at) >= monthStart,
    ).length;
    const fpsValues = allSessions
      .map((s) => s.target_fps)
      .filter((v): v is number => v != null && v > 0);
    const avgFps =
      fpsValues.length > 0
        ? fpsValues.reduce((a, b) => a + b, 0) / fpsValues.length
        : null;
    return { thisMonth, avgFps };
  }, [data]);

  const currentStart = offset + 1;
  const currentEnd = Math.min(offset + limit, total);
  const hasPrev = offset > 0;
  const hasNext = offset + limit < total;

  const handlePrevPage = () => setOffset((p) => Math.max(0, p - limit));
  const handleNextPage = () =>
    setOffset((p) => (hasNext ? p + limit : p));

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-4">
        <h1 className="text-xl font-semibold text-text-primary">Sessions</h1>

        {/* Dashboard Summary Tiles */}
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <DashboardTile icon={<BarChart3 className="h-4 w-4 text-chart-fps" />} label="Total Sessions" value={String(total)} />
          <DashboardTile icon={<Calendar className="h-4 w-4 text-chart-cpu" />} label="This Month" value={String(dashboardStats.thisMonth)} />
          <DashboardTile
            icon={<AlertTriangle className="h-4 w-4 text-accent-warning" />}
            label="Critical Issues"
            value="—"
          />
          <DashboardTile
            icon={<BarChart3 className="h-4 w-4 text-accent-success" />}
            label="Avg FPS"
            value={dashboardStats.avgFps?.toFixed(1) ?? '—'}
          />
        </div>

        <SessionFilters filters={filters} onApply={handleApplyFilters} />

        {error && (
          <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-4 py-3 text-sm text-accent-danger">
            Failed to load sessions. Ensure the server is running.
          </div>
        )}

        <SessionTable
          sessions={data?.data ?? []}
          isLoading={isLoading}
          onDeleteSelected={handleDeleteSelected}
          onExportSelected={handleExportSelected}
        />

        {/* Pagination */}
        {total > 0 && (
          <div className="flex items-center justify-between text-sm text-text-secondary">
            <span>
              Showing {currentStart}–{currentEnd} of {total} sessions
            </span>
            <div className="flex items-center gap-2">
              <button
                onClick={handlePrevPage}
                disabled={!hasPrev}
                className="flex items-center gap-1 rounded px-2 py-1 text-xs text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary disabled:cursor-not-allowed disabled:opacity-40"
              >
                <ChevronLeft className="h-3.5 w-3.5" />
                Previous
              </button>
              <button
                onClick={handleNextPage}
                disabled={!hasNext}
                className="flex items-center gap-1 rounded px-2 py-1 text-xs text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary disabled:cursor-not-allowed disabled:opacity-40"
              >
                Next
                <ChevronRight className="h-3.5 w-3.5" />
              </button>
            </div>
          </div>
        )}
      </div>
    </ProtectedRoute>
  );
}

// ─── Dashboard tile sub-component ───────────────────────────────────────────

function DashboardTile({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center gap-3 rounded-lg border border-border-subtle bg-bg-elevated p-3">
      <div className="flex h-8 w-8 items-center justify-center rounded bg-bg-base">
        {icon}
      </div>
      <div>
        <p className="text-[10px] uppercase text-text-disabled">{label}</p>
        <p className="font-mono-data text-lg font-semibold text-text-primary">
          {value}
        </p>
      </div>
    </div>
  );
}
