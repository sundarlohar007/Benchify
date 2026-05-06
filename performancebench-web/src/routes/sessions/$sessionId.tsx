import { useCallback } from 'react';
import { createFileRoute, useParams, Link } from '@tanstack/react-router';
import { ChevronLeft, Download } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { SessionDetailTabs } from '@/components/sessions/SessionDetailTabs';
import { useSession, type SessionDetail } from '@/hooks/useSessions';

export const Route = createFileRoute('/sessions/$sessionId')({
  component: SessionDetailPage,
});

function SessionDetailPage() {
  const { sessionId } = useParams({ from: '/sessions/$sessionId' });
  const { data: session, isLoading, error } = useSession(sessionId);

  const exportJSON = useCallback(
    () => downloadExport(session!, 'json'),
    [session],
  );

  const exportCSV = useCallback(
    () => downloadExport(session!, 'csv'),
    [session],
  );

  if (isLoading) {
    return (
      <ProtectedRoute>
        <div className="p-6 space-y-4">
          <div className="h-6 w-32 animate-pulse rounded bg-bg-elevated" />
          <div className="h-96 animate-pulse rounded bg-bg-elevated" />
        </div>
      </ProtectedRoute>
    );
  }

  if (error) {
    return (
      <ProtectedRoute>
        <div className="p-6">
          <Link
            to="/sessions"
            className="mb-4 inline-flex items-center gap-1 text-sm text-text-secondary hover:text-text-primary"
          >
            <ChevronLeft className="h-4 w-4" />
            Back to Sessions
          </Link>
          <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-4 py-3 text-sm text-accent-danger">
            Failed to load session. {error.message}
          </div>
        </div>
      </ProtectedRoute>
    );
  }

  if (!session) {
    return (
      <ProtectedRoute>
        <div className="p-6">
          <Link
            to="/sessions"
            className="mb-4 inline-flex items-center gap-1 text-sm text-text-secondary hover:text-text-primary"
          >
            <ChevronLeft className="h-4 w-4" />
            Back to Sessions
          </Link>
          <div className="rounded border border-border-subtle bg-bg-elevated px-4 py-3 text-sm text-text-primary">
            Session not found.
          </div>
        </div>
      </ProtectedRoute>
    );
  }

  return (
    <ProtectedRoute>
      <div className="p-6">
        {/* Header */}
        <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <Link
              to="/sessions"
              className="flex items-center gap-1 text-sm text-text-secondary hover:text-text-primary transition-colors"
            >
              <ChevronLeft className="h-4 w-4" />
              Back to Sessions
            </Link>
            <h1 className="text-xl font-semibold text-text-primary">
              {session.app_name ?? 'Unknown App'}
            </h1>
            <span className="rounded bg-bg-input px-2 py-0.5 font-mono-data text-xs text-text-disabled">
              {session.id.slice(0, 8)}
            </span>
          </div>

          {/* Export buttons */}
          <div className="flex items-center gap-2">
            <button
              onClick={exportJSON}
              className="flex items-center gap-1.5 rounded border border-border-subtle bg-bg-elevated px-3 py-1.5 text-xs text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary"
            >
              <Download className="h-3.5 w-3.5" />
              Export JSON
            </button>
            <button
              onClick={exportCSV}
              className="flex items-center gap-1.5 rounded border border-border-subtle bg-bg-elevated px-3 py-1.5 text-xs text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary"
            >
              <Download className="h-3.5 w-3.5" />
              Export CSV
            </button>
          </div>
        </div>

        {/* 5-tab layout */}
        <SessionDetailTabs session={session} />
      </div>
    </ProtectedRoute>
  );
}

// ─── Export helpers ───────────────────────────────────────────────────────

function downloadExport(session: SessionDetail, format: 'json' | 'csv') {
  const appName = session.app_name ?? 'session';
  const id = session.id.slice(0, 8);

  if (format === 'json') {
    const blob = new Blob([JSON.stringify(session, null, 2)], {
      type: 'application/json',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${appName}-${id}.json`;
    a.click();
    URL.revokeObjectURL(url);
  } else {
    // CSV: export metric_samples as rows
    const samples = session.metric_samples ?? [];
    if (samples.length === 0) {
      alert('No metric samples to export.');
      return;
    }
    const keys = Object.keys(samples[0]).filter(
      (k) => k !== 'session_id',
    );
    const header = keys.join(',');
    const rows = samples.map((s) =>
      keys
        .map((k) => {
          const val = (s as Record<string, unknown>)[k];
          if (val == null) return '';
          return String(val);
        })
        .join(','),
    );
    const csv = [header, ...rows].join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${appName}-${id}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }
}
