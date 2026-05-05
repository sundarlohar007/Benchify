import { useState, useCallback } from 'react';
import { createFileRoute } from '@tanstack/react-router';
import { ChevronLeft, ChevronRight } from 'lucide-react';
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
