import { useState, useMemo, useCallback } from 'react';
import { createFileRoute } from '@tanstack/react-router';
import { useQuery } from '@tanstack/react-query';
import { Download, FileText } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { SessionFilters } from '@/components/sessions/SessionFilters';
import type { Session, SessionFilters as Filters } from '@/hooks/useSessions';
import { api } from '@/lib/api';
import { formatTimestamp } from '@/lib/utils';

// ─── Route ──────────────────────────────────────────────────────────────────

export const Route = createFileRoute('/reports')({
  component: ReportsPage,
});

function ReportsPage() {
  // Phase 1: Session selection
  const [selectedSessionIds, setSelectedSessionIds] = useState<Set<string>>(
    new Set(),
  );
  const [reportGenerated, setReportGenerated] = useState(false);

  // Fetch sessions for selection
  const { data: sessionsData, isLoading: sessionsLoading } = useQuery({
    queryKey: ['sessions', 'report'],
    queryFn: () =>
      api.get<{ data: Session[]; total: number }>(
        '/api/v1/sessions?offset=0&limit=200',
      ),
  });

  const sessions = sessionsData?.data ?? [];

  const toggleSession = useCallback((id: string) => {
    setSelectedSessionIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const selectedSessions = useMemo(
    () => sessions.filter((s) => selectedSessionIds.has(s.id)),
    [sessions, selectedSessionIds],
  );

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-xl font-semibold text-text-primary">
            Analysis Reports
          </h1>
          <p className="mt-1 text-sm text-text-secondary">
            Generate multi-session analytical reports with summary stats, trends,
            and issue aggregation.
          </p>
        </div>

        {/* Session Selection */}
        <div className="rounded-lg border border-border-subtle bg-bg-elevated p-4 space-y-3">
          <h3 className="text-sm font-semibold text-text-primary">
            Select Sessions
          </h3>
          <p className="text-xs text-text-secondary">
            Select sessions to include in the report.{' '}
            {selectedSessionIds.size > 0 && (
              <span className="text-accent-blue font-medium">
                {selectedSessionIds.size} selected
              </span>
            )}
          </p>

          {sessionsLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <div
                  key={i}
                  className="h-10 animate-pulse rounded bg-bg-base"
                />
              ))}
            </div>
          ) : sessions.length === 0 ? (
            <p className="text-sm text-text-disabled">
              No sessions available. Upload sessions from the desktop app first.
            </p>
          ) : (
            <div className="max-h-[300px] overflow-y-auto space-y-1">
              {sessions.map((s) => (
                <label
                  key={s.id}
                  className={`flex items-center gap-3 rounded px-3 py-2 cursor-pointer transition-colors ${
                    selectedSessionIds.has(s.id)
                      ? 'bg-accent-blue/10 border border-accent-blue/30'
                      : 'hover:bg-bg-hover border border-transparent'
                  }`}
                >
                  <input
                    type="checkbox"
                    className="rounded border-border-subtle bg-bg-input accent-accent-blue"
                    checked={selectedSessionIds.has(s.id)}
                    onChange={() => toggleSession(s.id)}
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-text-primary truncate">
                      {s.app_name ?? 'Unknown'}
                    </p>
                    <p className="text-[10px] text-text-disabled">
                      {s.device_id} —{' '}
                      {formatTimestamp(
                        new Date(s.started_at).toISOString(),
                      )}
                    </p>
                  </div>
                </label>
              ))}
            </div>
          )}

          <button
            onClick={() => setReportGenerated(true)}
            disabled={selectedSessionIds.size === 0}
            className="flex items-center gap-1.5 rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white transition-opacity hover:opacity-90 disabled:opacity-50"
          >
            <FileText className="h-3.5 w-3.5" />
            Generate Report
          </button>
        </div>

        {/* Generated Report */}
        {reportGenerated && selectedSessions.length > 0 && (
          <ReportView sessions={selectedSessions} />
        )}
      </div>
    </ProtectedRoute>
  );
}

// ─── Report View ────────────────────────────────────────────────────────────

function ReportView({ sessions }: { sessions: Session[] }) {
  // Compute summary stats from sessions
  const summary = useMemo(() => {
    const total = sessions.length;
    const fpsValues = sessions
      .map((s) => s.target_fps)
      .filter((v) => v != null && v > 0);
    const avgFps =
      fpsValues.length > 0
        ? fpsValues.reduce((a, b) => a + b, 0) / fpsValues.length
        : null;

    const apps = [...new Set(sessions.map((s) => s.app_name).filter(Boolean))];
    const devices = [...new Set(sessions.map((s) => s.device_id).filter(Boolean))];

    const dates = sessions
      .map((s) => new Date(s.started_at))
      .sort((a, b) => a.getTime() - b.getTime());

    return {
      total,
      avgFps,
      apps,
      devices,
      dateRange:
        dates.length > 0
          ? `${dates[0].toLocaleDateString()} — ${dates[dates.length - 1].toLocaleDateString()}`
          : 'N/A',
    };
  }, [sessions]);

  const exportJSON = useCallback(() => {
    const blob = new Blob([JSON.stringify(sessions, null, 2)], {
      type: 'application/json',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `benchify-report-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }, [sessions]);

  const printPDF = useCallback(() => {
    window.print();
  }, []);

  return (
    <div id="report-content" className="space-y-6">
      {/* Executive Summary */}
      <div className="rounded-lg border border-border-subtle bg-bg-elevated p-4">
        <h3 className="mb-2 text-sm font-semibold text-text-primary">
          Executive Summary
        </h3>
        <p className="text-sm text-text-secondary leading-relaxed">
          Across {summary.total} session{summary.total !== 1 ? 's' : ''}{' '}
          ({summary.dateRange}), average FPS was{' '}
          {summary.avgFps != null ? summary.avgFps.toFixed(1) : 'N/A'}
          . Profiling covered {summary.apps.length} app
          {summary.apps.length !== 1 ? 's' : ''}
          {summary.apps.length > 0 && ` (${summary.apps.join(', ')})`} across{' '}
          {summary.devices.length} device
          {summary.devices.length !== 1 ? 's' : ''}.
        </p>

        {/* Metric Summary Grid */}
        <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <SummaryCard label="Total Sessions" value={String(summary.total)} />
          <SummaryCard
            label="Avg FPS"
            value={summary.avgFps?.toFixed(1) ?? 'N/A'}
          />
          <SummaryCard
            label="Apps"
            value={String(summary.apps.length)}
          />
          <SummaryCard
            label="Devices"
            value={String(summary.devices.length)}
          />
        </div>
      </div>

      {/* Metric Comparison Table */}
      <div className="rounded-lg border border-border-subtle overflow-hidden">
        <h3 className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-text-secondary border-b border-border-subtle bg-bg-elevated">
          Metric Comparison
        </h3>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border-subtle bg-bg-elevated/50">
                <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                  App
                </th>
                <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                  Device
                </th>
                <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                  Date
                </th>
                <th className="px-3 py-2 text-right text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                  Target FPS
                </th>
                <th className="px-3 py-2 text-right text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                  Duration
                </th>
              </tr>
            </thead>
            <tbody>
              {sessions.map((s) => (
                <tr
                  key={s.id}
                  className="border-b border-border-subtle/30 transition-colors hover:bg-bg-hover"
                >
                  <td className="px-3 py-2 text-sm text-text-primary">
                    {s.app_name ?? 'Unknown'}
                  </td>
                  <td className="px-3 py-2 text-xs text-text-secondary">
                    {s.device_id}
                  </td>
                  <td className="px-3 py-2 text-xs text-text-secondary">
                    {formatTimestamp(
                      new Date(s.started_at).toISOString(),
                    )}
                  </td>
                  <td className="px-3 py-2 text-right font-mono-data text-sm text-text-primary">
                    {s.target_fps ?? '—'}
                  </td>
                  <td className="px-3 py-2 text-right font-mono-data text-xs text-text-secondary">
                    {s.duration_ms != null
                      ? `${Math.round(s.duration_ms / 1000)}s`
                      : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Export Buttons */}
      <div className="flex items-center gap-3">
        <button
          onClick={exportJSON}
          className="flex items-center gap-1.5 rounded border border-border-subtle bg-bg-elevated px-3 py-1.5 text-xs text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary"
        >
          <Download className="h-3.5 w-3.5" />
          Export JSON
        </button>
        <button
          onClick={printPDF}
          className="flex items-center gap-1.5 rounded border border-border-subtle bg-bg-elevated px-3 py-1.5 text-xs text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary"
        >
          <Download className="h-3.5 w-3.5" />
          Print / Save as PDF
        </button>
      </div>
    </div>
  );
}

function SummaryCard({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="rounded border border-border-subtle/50 bg-bg-base p-3">
      <p className="text-[10px] uppercase text-text-disabled">{label}</p>
      <p className="mt-0.5 font-mono-data text-sm font-semibold text-text-primary">
        {value}
      </p>
    </div>
  );
}
