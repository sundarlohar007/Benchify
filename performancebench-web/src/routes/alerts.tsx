import { useState } from 'react';
import { createFileRoute } from '@tanstack/react-router';
import {
  Bell,
  Plus,
  X,
  Trash2,
  ToggleLeft,
  ToggleRight,
  AlertTriangle,
} from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import {
  useAlertRules,
  useCreateAlertRule,
  useUpdateAlertRule,
  useDeleteAlertRule,
  useAlertEvents,
  METRIC_OPTIONS,
  CONDITION_OPTIONS,
  type CreateAlertRuleBody,
  type NotificationChannel,
} from '@/hooks/useAlerts';
import { formatTimestamp, relativeTime } from '@/lib/utils';

// ─── Route ──────────────────────────────────────────────────────────────────

export const Route = createFileRoute('/alerts')({
  component: AlertsPage,
});

// ─── Main Page ──────────────────────────────────────────────────────────────

function AlertsPage() {
  const [view, setView] = useState<'events' | 'rules'>('events');
  const [showCreateRule, setShowCreateRule] = useState(false);

  const { data: rulesData } = useAlertRules();
  const { data: eventsData, isLoading: eventsLoading } = useAlertEvents();
  const createRule = useCreateAlertRule();
  const updateRule = useUpdateAlertRule();
  const deleteRule = useDeleteAlertRule();

  const rules = rulesData?.data ?? [];
  const events = eventsData?.data ?? [];

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-text-primary">Alerts</h1>
            <p className="mt-1 text-sm text-text-secondary">
              Monitor performance thresholds and get notified when metrics degrade.
            </p>
          </div>
          <button
            onClick={() => {
              setView('rules');
              setShowCreateRule(true);
            }}
            className="flex items-center gap-1.5 rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white transition-opacity hover:opacity-90"
          >
            <Plus className="h-3.5 w-3.5" />
            New Rule
          </button>
        </div>

        {/* View Tabs */}
        <div className="flex gap-1 rounded-lg border border-border-subtle bg-bg-elevated p-1 w-fit">
          {(['events', 'rules'] as const).map((v) => (
            <button
              key={v}
              onClick={() => setView(v)}
              className={`rounded px-4 py-1.5 text-xs font-medium transition-colors ${
                view === v
                  ? 'bg-accent-blue text-white'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              {v === 'events' ? 'Alert Events' : 'Alert Rules'}
            </button>
          ))}
        </div>

        {/* ─── Alert Events View ────────────────────────────────────────── */}
        {view === 'events' && (
          <AlertEventsList events={events} isLoading={eventsLoading} />
        )}

        {/* ─── Alert Rules View ─────────────────────────────────────────── */}
        {view === 'rules' && (
          <AlertRulesList
            rules={rules}
            onToggle={(rule) =>
              updateRule.mutate({
                id: rule.id,
                body: { is_active: !rule.is_active },
              })
            }
            onDelete={(id) => {
              if (confirm('Delete this alert rule?')) {
                deleteRule.mutate(id);
              }
            }}
            onCreate={() => setShowCreateRule(true)}
            showCreate={showCreateRule}
            onCloseCreate={() => setShowCreateRule(false)}
            onSaveCreate={(body) => {
              createRule.mutate(body, {
                onSuccess: () => setShowCreateRule(false),
              });
            }}
            isCreating={createRule.isPending}
          />
        )}
      </div>
    </ProtectedRoute>
  );
}

// ─── Alert Events List ──────────────────────────────────────────────────────

function AlertEventsList({
  events,
  isLoading,
}: {
  events: import('@/hooks/useAlerts').AlertEvent[];
  isLoading: boolean;
}) {
  if (isLoading) {
    return (
      <div className="space-y-2">
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} className="h-16 animate-pulse rounded bg-bg-elevated" />
        ))}
      </div>
    );
  }

  if (events.length === 0) {
    return (
      <div className="flex flex-col items-center py-12 text-text-disabled">
        <Bell className="mb-3 h-8 w-8" />
        <p>No alert events yet.</p>
        <p className="mt-1 text-xs">
          Alert events appear when a metric exceeds a configured threshold.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {events.map((event) => {
        const severity =
          event.threshold > 0
            ? event.metric_value / event.threshold
            : 0;
        const severityBadge =
          severity >= 2
            ? 'bg-accent-danger/15 text-accent-danger border-accent-danger/30'
            : severity >= 1.5
              ? 'bg-accent-warning/15 text-accent-warning border-accent-warning/30'
              : 'bg-accent-blue/15 text-accent-blue border-accent-blue/30';

        return (
          <div
            key={event.id}
            className="rounded-lg border border-border-subtle bg-bg-elevated p-3"
          >
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-2">
                <AlertTriangle className="h-4 w-4 text-accent-warning" />
                <div>
                  <p className="text-sm text-text-primary">
                    Value <span className="font-mono-data font-semibold">{event.metric_value.toFixed(2)}</span>{' '}
                    vs threshold{' '}
                    <span className="font-mono-data font-semibold">{event.threshold.toFixed(2)}</span>
                  </p>
                  <p className="mt-0.5 text-xs text-text-disabled">
                    {relativeTime(event.fired_at)}
                    {event.session_id && (
                      <span className="ml-2 font-mono-data">
                        Session: {event.session_id.slice(0, 8)}
                      </span>
                    )}
                    {event.acknowledged_at ? (
                      <span className="ml-2 text-accent-success">Acknowledged</span>
                    ) : (
                      <span className="ml-2 text-accent-warning">Unacknowledged</span>
                    )}
                  </p>
                </div>
              </div>
              <span
                className={`inline-block rounded border px-2 py-0.5 text-[10px] font-semibold ${severityBadge}`}
              >
                {severity >= 2 ? 'CRITICAL' : severity >= 1.5 ? 'WARNING' : 'INFO'}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ─── Alert Rules List ───────────────────────────────────────────────────────

function AlertRulesList({
  rules,
  onToggle,
  onDelete,
  onCreate,
  showCreate,
  onCloseCreate,
  onSaveCreate,
  isCreating,
}: {
  rules: import('@/hooks/useAlerts').AlertRule[];
  onToggle: (rule: import('@/hooks/useAlerts').AlertRule) => void;
  onDelete: (id: string) => void;
  onCreate: () => void;
  showCreate: boolean;
  onCloseCreate: () => void;
  onSaveCreate: (body: CreateAlertRuleBody) => void;
  isCreating: boolean;
}) {
  if (rules.length === 0 && !showCreate) {
    return (
      <div className="flex flex-col items-center py-12 text-text-disabled">
        <AlertTriangle className="mb-3 h-8 w-8" />
        <p>No alert rules configured.</p>
        <p className="mt-1 text-xs">Create a rule to monitor performance metrics.</p>
        <button
          onClick={onCreate}
          className="mt-4 flex items-center gap-1 rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white hover:opacity-90"
        >
          <Plus className="h-3.5 w-3.5" />
          Create Rule
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {showCreate && (
        <CreateRuleForm onClose={onCloseCreate} onSave={onSaveCreate} isSaving={isCreating} />
      )}

      {rules.map((rule) => (
        <div
          key={rule.id}
          className="rounded-lg border border-border-subtle bg-bg-elevated p-4"
        >
          <div className="flex items-start justify-between">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <h4 className="text-sm font-semibold text-text-primary">
                  {rule.name}
                </h4>
                <span
                  className={`inline-block rounded px-2 py-0.5 text-[10px] font-medium ${
                    rule.is_active
                      ? 'bg-accent-success/15 text-accent-success'
                      : 'bg-bg-hover text-text-disabled'
                  }`}
                >
                  {rule.is_active ? 'Active' : 'Disabled'}
                </span>
              </div>
              <p className="text-xs text-text-secondary font-mono-data">
                {METRIC_OPTIONS.find((m) => m.value === rule.metric_name)?.label ??
                  rule.metric_name}{' '}
                {CONDITION_OPTIONS.find((c) => c.value === rule.condition)
                  ?.label ?? rule.condition}{' '}
                {rule.threshold} (duration: {rule.duration_seconds}s)
              </p>
              {/* Channel badges */}
              {Array.isArray(rule.channels) && rule.channels.length > 0 && (
                <div className="flex flex-wrap gap-1">
                  {rule.channels.map((ch: NotificationChannel, i: number) => (
                    <span
                      key={i}
                      className="inline-block rounded bg-bg-hover px-1.5 py-0.5 text-[10px] text-text-disabled"
                    >
                      {ch.type === 'email'
                        ? `Email → ${ch.to ?? '?'}`
                        : ch.type === 'slack'
                          ? 'Slack'
                          : 'Webhook'}
                    </span>
                  ))}
                </div>
              )}
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => onToggle(rule)}
                className="text-text-secondary hover:text-text-primary"
                title={rule.is_active ? 'Disable' : 'Enable'}
              >
                {rule.is_active ? (
                  <ToggleRight className="h-5 w-5 text-accent-success" />
                ) : (
                  <ToggleLeft className="h-5 w-5 text-text-disabled" />
                )}
              </button>
              <button
                onClick={() => onDelete(rule.id)}
                className="text-text-disabled hover:text-accent-danger"
                title="Delete rule"
              >
                <Trash2 className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

// ─── Create Rule Form ───────────────────────────────────────────────────────

function CreateRuleForm({
  onClose,
  onSave,
  isSaving,
}: {
  onClose: () => void;
  onSave: (body: CreateAlertRuleBody) => void;
  isSaving: boolean;
}) {
  const [name, setName] = useState('');
  const [metric, setMetric] = useState('fps_median');
  const [condition, setCondition] = useState('lt');
  const [threshold, setThreshold] = useState('30');
  const [duration, setDuration] = useState('30');
  const [channels, setChannels] = useState<NotificationChannel[]>([]);

  const handleAddChannel = (type: 'email' | 'slack' | 'webhook') => {
    if (type === 'email') {
      const to = prompt('Email recipient:');
      if (to) setChannels((p) => [...p, { type: 'email', to }]);
    } else if (type === 'slack') {
      const url = prompt('Slack webhook URL:');
      if (url) setChannels((p) => [...p, { type: 'slack', webhook_url: url }]);
    } else {
      const url = prompt('Webhook URL:');
      const secret = prompt('Webhook secret (optional):');
      if (url)
        setChannels((p) => [
          ...p,
          { type: 'webhook', url, secret: secret || undefined },
        ]);
    }
  };

  const handleSubmit = () => {
    onSave({
      name,
      metric_name: metric,
      condition,
      threshold: parseFloat(threshold) || 0,
      duration_seconds: parseInt(duration, 10) || 30,
      channels,
    });
  };

  const inputClass =
    'w-full rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

  return (
    <div className="rounded-lg border border-accent-blue/30 bg-bg-elevated p-4 space-y-3">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-text-primary">
          Create Alert Rule
        </h3>
        <button onClick={onClose} className="text-text-disabled hover:text-text-primary">
          <X className="h-4 w-4" />
        </button>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
            Name *
          </label>
          <input
            type="text"
            className={inputClass}
            placeholder="e.g. Low FPS Alert"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </div>
        <div>
          <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
            Metric *
          </label>
          <select
            className={inputClass}
            value={metric}
            onChange={(e) => setMetric(e.target.value)}
          >
            {METRIC_OPTIONS.map((m) => (
              <option key={m.value} value={m.value}>
                {m.label}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
            Condition *
          </label>
          <select
            className={inputClass}
            value={condition}
            onChange={(e) => setCondition(e.target.value)}
          >
            {CONDITION_OPTIONS.map((c) => (
              <option key={c.value} value={c.value}>
                {c.label}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
            Threshold *
          </label>
          <input
            type="number"
            className={inputClass}
            step="0.1"
            value={threshold}
            onChange={(e) => setThreshold(e.target.value)}
          />
        </div>
        <div>
          <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
            Duration (seconds)
          </label>
          <input
            type="number"
            className={inputClass}
            value={duration}
            onChange={(e) => setDuration(e.target.value)}
          />
        </div>
      </div>

      {/* Notification Channels */}
      <div>
        <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
          Notification Channels
        </label>
        <div className="flex flex-wrap gap-1 mb-2">
          {channels.map((ch, i) => (
            <span
              key={i}
              className="flex items-center gap-1 rounded bg-bg-hover px-2 py-1 text-[10px] text-text-secondary"
            >
              {ch.type === 'email'
                ? `Email: ${ch.to}`
                : ch.type === 'slack'
                  ? 'Slack'
                  : 'Webhook'}
              <button
                onClick={() =>
                  setChannels((p) => p.filter((_, j) => j !== i))
                }
                className="text-text-disabled hover:text-accent-danger"
              >
                <X className="h-3 w-3" />
              </button>
            </span>
          ))}
        </div>
        <div className="flex gap-1">
          <button
            type="button"
            onClick={() => handleAddChannel('email')}
            className="rounded bg-bg-input px-2 py-1 text-[10px] text-text-secondary hover:bg-bg-hover"
          >
            + Email
          </button>
          <button
            type="button"
            onClick={() => handleAddChannel('slack')}
            className="rounded bg-bg-input px-2 py-1 text-[10px] text-text-secondary hover:bg-bg-hover"
          >
            + Slack
          </button>
          <button
            type="button"
            onClick={() => handleAddChannel('webhook')}
            className="rounded bg-bg-input px-2 py-1 text-[10px] text-text-secondary hover:bg-bg-hover"
          >
            + Webhook
          </button>
        </div>
      </div>

      <div className="flex items-center gap-2 pt-2">
        <button
          onClick={handleSubmit}
          disabled={!name.trim() || isSaving}
          className="rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white hover:opacity-90 disabled:opacity-50"
        >
          {isSaving ? 'Saving...' : 'Create Rule'}
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
