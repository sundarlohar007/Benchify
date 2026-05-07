import { useCallback, useState } from 'react';
import { createFileRoute, useParams, Link } from '@tanstack/react-router';
import { ChevronLeft, Download, Bug, ExternalLink } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { SessionDetailTabs } from '@/components/sessions/SessionDetailTabs';
import { useSession, type SessionDetail } from '@/hooks/useSessions';
import { api } from '@/lib/api';

export const Route = createFileRoute('/sessions/$sessionId')({
  component: SessionDetailPage,
});

function SessionDetailPage() {
  const { sessionId } = useParams({ from: '/sessions/$sessionId' });
  const { data: session, isLoading, error } = useSession(sessionId);

  const [showJiraModal, setShowJiraModal] = useState(false);
  const [jiraSubmitting, setJiraSubmitting] = useState(false);
  const [jiraError, setJiraError] = useState<string | null>(null);
  const [jiraResult, setJiraResult] = useState<{
    issue_key: string;
    issue_url: string;
  } | null>(null);

  const [jiraProjectKey, setJiraProjectKey] = useState('');
  const [jiraIssueType, setJiraIssueType] = useState('Bug');
  const [jiraSummary, setJiraSummary] = useState('');
  const [jiraLabels, setJiraLabels] = useState('');

  const exportJSON = useCallback(
    () => downloadExport(session!, 'json'),
    [session],
  );

  const exportCSV = useCallback(
    () => downloadExport(session!, 'csv'),
    [session],
  );

  const handleCreateJiraIssue = useCallback(async () => {
    if (!session || !jiraProjectKey.trim()) return;
    setJiraSubmitting(true);
    setJiraError(null);
    setJiraResult(null);
    try {
      const result = await api.post<{
        issue_key: string;
        issue_url: string;
      }>(`/api/v1/sessions/${session.id}/jira`, {
        project_key: jiraProjectKey.trim(),
        issue_type: jiraIssueType,
        summary: jiraSummary.trim() || null,
        labels: jiraLabels
          .split(',')
          .map((l) => l.trim())
          .filter(Boolean),
      });
      setJiraResult(result);
    } catch (e) {
      setJiraError((e as Error).message);
    } finally {
      setJiraSubmitting(false);
    }
  }, [session, jiraProjectKey, jiraIssueType, jiraSummary, jiraLabels]);

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
            to={'/sessions' as any}
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
            to={'/sessions' as any}
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
              to={'/sessions' as any}
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
              onClick={() => setShowJiraModal(true)}
              className="flex items-center gap-1.5 rounded border border-accent-blue/30 bg-accent-blue/10 px-3 py-1.5 text-xs text-accent-blue transition-colors hover:bg-accent-blue/20"
            >
              <Bug className="h-3.5 w-3.5" />
              Create Jira Issue
            </button>
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

        {/* Jira issue creation modal */}
        {showJiraModal && (
          <JiraIssueModal
            onClose={() => {
              setShowJiraModal(false);
              setJiraError(null);
              setJiraResult(null);
            }}
            projectKey={jiraProjectKey}
            onProjectKeyChange={setJiraProjectKey}
            issueType={jiraIssueType}
            onIssueTypeChange={setJiraIssueType}
            summary={jiraSummary}
            onSummaryChange={setJiraSummary}
            labels={jiraLabels}
            onLabelsChange={setJiraLabels}
            onSubmit={handleCreateJiraIssue}
            isSubmitting={jiraSubmitting}
            error={jiraError}
            result={jiraResult}
          />
        )}
      </div>
    </ProtectedRoute>
  );
}

// ─── Jira Issue Modal ──────────────────────────────────────────────────────

interface JiraIssueModalProps {
  onClose: () => void;
  projectKey: string;
  onProjectKeyChange: (v: string) => void;
  issueType: string;
  onIssueTypeChange: (v: string) => void;
  summary: string;
  onSummaryChange: (v: string) => void;
  labels: string;
  onLabelsChange: (v: string) => void;
  onSubmit: () => void;
  isSubmitting: boolean;
  error: string | null;
  result: { issue_key: string; issue_url: string } | null;
}

function JiraIssueModal({
  onClose,
  projectKey,
  onProjectKeyChange,
  issueType,
  onIssueTypeChange,
  summary,
  onSummaryChange,
  labels,
  onLabelsChange,
  onSubmit,
  isSubmitting,
  error,
  result,
}: JiraIssueModalProps) {
  const inputClass =
    'w-full rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

  if (result) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
        <div className="w-96 rounded-lg border border-accent-success/30 bg-bg-elevated p-6 shadow-xl space-y-4">
          <div className="flex items-center gap-2">
            <ExternalLink className="h-4 w-4 text-accent-success" />
            <h3 className="text-sm font-semibold text-accent-success">
              Jira Issue Created
            </h3>
          </div>
          <div className="rounded bg-bg-input p-3">
            <code className="text-sm text-text-primary font-mono">
              {result.issue_key}
            </code>
          </div>
          <a
            href={result.issue_url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs text-accent-blue hover:underline"
          >
            <ExternalLink className="h-3 w-3" />
            Open in Jira
          </a>
          <div className="flex justify-end">
            <button
              onClick={onClose}
              className="rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white hover:opacity-90"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="w-96 rounded-lg border border-border-subtle bg-bg-elevated p-6 shadow-xl space-y-4">
        <div className="flex items-center gap-2">
          <Bug className="h-4 w-4 text-accent-blue" />
          <h3 className="text-sm font-semibold text-text-primary">
            Create Jira Issue
          </h3>
        </div>
        <p className="text-xs text-text-secondary">
          Pre-fills the Jira issue description with performance metrics from
          this session.
        </p>

        {error && (
          <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-3 py-2 text-xs text-accent-danger">
            {error}
          </div>
        )}

        <div>
          <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
            Project Key *
          </label>
          <input
            type="text"
            className={inputClass}
            placeholder="e.g. PROJ"
            value={projectKey}
            onChange={(e) => onProjectKeyChange(e.target.value)}
          />
        </div>

        <div>
          <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
            Issue Type
          </label>
          <select
            className={inputClass}
            value={issueType}
            onChange={(e) => onIssueTypeChange(e.target.value)}
          >
            <option value="Bug">Bug</option>
            <option value="Task">Task</option>
            <option value="Story">Story</option>
          </select>
        </div>

        <div>
          <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
            Summary (optional — auto-generated if empty)
          </label>
          <input
            type="text"
            className={inputClass}
            placeholder="Auto-generated: Performance: App — FPS avg / CPU avg..."
            value={summary}
            onChange={(e) => onSummaryChange(e.target.value)}
          />
        </div>

        <div>
          <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
            Labels (comma-separated)
          </label>
          <input
            type="text"
            className={inputClass}
            placeholder="performance, benchmark"
            value={labels}
            onChange={(e) => onLabelsChange(e.target.value)}
          />
        </div>

        <div className="flex justify-end gap-2 pt-2">
          <button
            onClick={onClose}
            className="rounded px-3 py-1.5 text-xs text-text-secondary hover:text-text-primary"
          >
            Cancel
          </button>
          <button
            onClick={onSubmit}
            disabled={!projectKey.trim() || isSubmitting}
            className="rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white hover:opacity-90 disabled:opacity-50"
          >
            {isSubmitting ? 'Creating...' : 'Create Issue'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Export helpers ───────────────────────────────────────────────────────

/**
 * Escape a value for safe CSV output.  Handles three concerns:
 *  1. CSV injection — cells starting with =, +, -, @ are prefixed with a tab
 *     (OWASP CSV Injection mitigation).
 *  2. Field delimiters — commas, newlines, or double-quotes trigger
 *     RFC 4180 quoting and internal-double-quote escaping.
 *  3. null / undefined → empty string.
 */
function escapeCsvValue(val: unknown): string {
  if (val == null) return '';
  const str = String(val);
  // Prevent formula injection: prefix with tab if starts with =, +, -, @
  const safeStr = /^[=+\-@]/.test(str) ? '\t' + str : str;
  // Escape quotes and wrap if contains special chars
  if (/[",\n\r]/.test(safeStr)) {
    return '"' + safeStr.replace(/"/g, '""') + '"';
  }
  return safeStr;
}

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
      keys.map((k) => escapeCsvValue((s as Record<string, unknown>)[k])).join(','),
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
