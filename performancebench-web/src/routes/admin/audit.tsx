import { useState, useCallback } from 'react';
import { createFileRoute, redirect } from '@tanstack/react-router';
import type { QueryClient } from '@tanstack/react-query';
import {
  ScrollText,
  Search,
  Calendar,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { useAuth, type User } from '@/hooks/useAuth';
import { AuditLogTable } from '@/components/admin/AuditLogTable';
import { AuditExportButton } from '@/components/admin/AuditExportButton';
import {
  useAuditEvents,
  useAuditExport,
  usePurgeAuditEvents,
} from '@/hooks/useAudit';

export const Route = createFileRoute('/admin/audit')({
  beforeLoad: ({ context }) => {
    const ctx = context as { queryClient: QueryClient };
    const user = ctx.queryClient.getQueryData<User>(['auth', 'me']);
    // Only redirect if we have cached user data and they're not admin.
    // If data isn't cached yet, let the component's ProtectedRoute handle it.
    if (user !== undefined && user.role !== 'admin') {
      throw redirect({ to: '/sessions' });
    }
  },
  component: AuditLogPage,
});

const categoryOptions = [
  { value: '', label: 'All Categories' },
  { value: 'auth', label: 'Auth' },
  { value: 'session', label: 'Session' },
  { value: 'user', label: 'User' },
  { value: 'config', label: 'Config' },
  { value: 'team', label: 'Team' },
  { value: 'export', label: 'Export' },
  { value: 'system', label: 'System' },
];

const categoryBadge = (cat: string): string => {
  switch (cat) {
    case 'auth':
      return 'bg-accent-blue/15 text-accent-blue';
    case 'session':
      return 'bg-accent-success/15 text-accent-success';
    case 'user':
      return 'bg-accent-warning/15 text-accent-warning';
    case 'config':
      return 'bg-purple-500/15 text-purple-400';
    case 'team':
      return 'bg-cyan-500/15 text-cyan-400';
    case 'export':
      return 'bg-pink-500/15 text-pink-400';
    case 'system':
      return 'bg-bg-input text-text-secondary';
    default:
      return 'bg-bg-input text-text-disabled';
  }
};

const inputClass =
  'rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

function AuditLogPage() {
  const { user, isAdmin } = useAuth();

  // Filters
  const [category, setCategory] = useState('');
  const [eventType, setEventType] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [page, setPage] = useState(0);
  const pageSize = 25;

  const { data, isLoading, error } = useAuditEvents({
    category: category || undefined,
    eventType: eventType || undefined,
    from: dateFrom || undefined,
    to: dateTo || undefined,
    offset: page * pageSize,
    limit: pageSize,
  });

  const exportMut = useAuditExport();
  const purgeMut = usePurgeAuditEvents();

  const [showPurgeConfirm, setShowPurgeConfirm] = useState(false);
  const [purgeBefore, setPurgeBefore] = useState('');

  const events = data?.events ?? [];
  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  const handleExport = useCallback(
    (format: 'csv' | 'json') => {
      exportMut.mutate({
        format,
        from: dateFrom || undefined,
        to: dateTo || undefined,
        category: category || undefined,
      });
    },
    [exportMut, dateFrom, dateTo, category],
  );

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-6">
        {/* Header */}
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h1 className="text-xl font-semibold text-text-primary">
              Audit Log
            </h1>
            <p className="mt-1 text-sm text-text-secondary">
              {total > 0
                ? `${total} total event${total !== 1 ? 's' : ''}`
                : 'View and export security and operational audit events'}
            </p>
          </div>

          <div className="flex items-center gap-2">
            {/* Export button */}
            <AuditExportButton
              filters={{ from: dateFrom, to: dateTo, category }}
              onExport={handleExport}
              isExporting={exportMut.isPending}
              disabled={events.length === 0}
            />

            {/* Purge button (admin only) */}
            {isAdmin && (
              <button
                onClick={() => setShowPurgeConfirm(true)}
                className="flex items-center gap-1.5 rounded border border-accent-danger/30 bg-accent-danger/10 px-3 py-1.5 text-xs text-accent-danger transition-colors hover:bg-accent-danger/20"
              >
                Purge Events
              </button>
            )}
          </div>
        </div>

        {/* Error state */}
        {error && (
          <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-4 py-3 text-sm text-accent-danger">
            Failed to load audit events.
          </div>
        )}

        {/* Filters bar */}
        <div className="flex flex-wrap items-center gap-3">
          {/* Category dropdown */}
          <select
            className={inputClass}
            value={category}
            onChange={(e) => {
              setCategory(e.target.value);
              setPage(0);
            }}
          >
            {categoryOptions.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>

          {/* Event type filter */}
          <div className="relative flex-1 min-w-[160px]">
            <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-text-disabled" />
            <input
              type="text"
              className={`${inputClass} pl-7`}
              placeholder="Filter event type..."
              value={eventType}
              onChange={(e) => {
                setEventType(e.target.value);
                setPage(0);
              }}
            />
          </div>

          {/* Date range */}
          <div className="flex items-center gap-2">
            <Calendar className="h-3.5 w-3.5 text-text-disabled" />
            <input
              type="date"
              className={inputClass}
              value={dateFrom}
              onChange={(e) => {
                setDateFrom(e.target.value);
                setPage(0);
              }}
              placeholder="From"
            />
            <span className="text-text-disabled text-xs">to</span>
            <input
              type="date"
              className={inputClass}
              value={dateTo}
              onChange={(e) => {
                setDateTo(e.target.value);
                setPage(0);
              }}
              placeholder="To"
            />
          </div>
        </div>

        {/* Loading state */}
        {isLoading && (
          <div className="space-y-2">
            {Array.from({ length: 5 }).map((_, i) => (
              <div
                key={i}
                className="h-12 animate-pulse rounded bg-bg-elevated"
              />
            ))}
          </div>
        )}

        {/* Audit log table */}
        {!isLoading && <AuditLogTable events={events} />}

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between">
            <span className="text-xs text-text-disabled">
              Page {page + 1} of {totalPages}
            </span>
            <div className="flex gap-2">
              <button
                onClick={() => setPage((p) => Math.max(0, p - 1))}
                disabled={page === 0}
                className="flex items-center gap-1 rounded border border-border-subtle bg-bg-elevated px-3 py-1 text-xs text-text-secondary hover:bg-bg-hover hover:text-text-primary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <ChevronLeft className="h-3 w-3" />
                Previous
              </button>
              <button
                onClick={() =>
                  setPage((p) => Math.min(totalPages - 1, p + 1))
                }
                disabled={page >= totalPages - 1}
                className="flex items-center gap-1 rounded border border-border-subtle bg-bg-elevated px-3 py-1 text-xs text-text-secondary hover:bg-bg-hover hover:text-text-primary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Next
                <ChevronRight className="h-3 w-3" />
              </button>
            </div>
          </div>
        )}

        {/* Purge confirmation modal (admin only) */}
        {showPurgeConfirm && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
            <div className="w-96 rounded-lg border border-border-subtle bg-bg-elevated p-6 shadow-xl">
              <h3 className="text-sm font-semibold text-accent-danger">
                Purge Audit Events
              </h3>
              <p className="mt-2 text-sm text-text-secondary">
                This will permanently delete all audit events older than the
                specified date. Minimum 30-day retention is enforced. This
                action cannot be undone.
              </p>
              <div className="mt-3">
                <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                  Delete events before
                </label>
                <input
                  type="date"
                  className={inputClass}
                  value={purgeBefore}
                  onChange={(e) => setPurgeBefore(e.target.value)}
                />
              </div>
              {purgeMut.error && (
                <p className="mt-2 text-xs text-accent-danger">
                  {(purgeMut.error as Error).message}
                </p>
              )}
              <div className="mt-4 flex justify-end gap-2">
                <button
                  onClick={() => setShowPurgeConfirm(false)}
                  className="rounded px-3 py-1.5 text-xs text-text-secondary hover:text-text-primary"
                >
                  Cancel
                </button>
                <button
                  onClick={() => {
                    purgeMut.mutate(purgeBefore, {
                      onSuccess: () => setShowPurgeConfirm(false),
                    });
                  }}
                  disabled={!purgeBefore.trim() || purgeMut.isPending}
                  className="rounded bg-accent-danger px-3 py-1.5 text-xs font-medium text-white hover:opacity-90 disabled:opacity-50"
                >
                  {purgeMut.isPending ? 'Purging...' : 'Confirm Purge'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </ProtectedRoute>
  );
}
