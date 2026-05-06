import { useState } from 'react';
import type { AuditEventResponse } from '@/hooks/useAudit';

interface AuditLogTableProps {
  events: AuditEventResponse[];
}

const categoryConfig: Record<
  string,
  { bg: string; text: string; label: string }
> = {
  auth: {
    bg: 'bg-accent-blue/15',
    text: 'text-accent-blue',
    label: 'Auth',
  },
  session: {
    bg: 'bg-accent-success/15',
    text: 'text-accent-success',
    label: 'Session',
  },
  user: {
    bg: 'bg-accent-warning/15',
    text: 'text-accent-warning',
    label: 'User',
  },
  config: {
    bg: 'bg-purple-500/15',
    text: 'text-purple-400',
    label: 'Config',
  },
  team: {
    bg: 'bg-cyan-500/15',
    text: 'text-cyan-400',
    label: 'Team',
  },
  export: {
    bg: 'bg-pink-500/15',
    text: 'text-pink-400',
    label: 'Export',
  },
  system: {
    bg: 'bg-bg-input',
    text: 'text-text-secondary',
    label: 'System',
  },
};

const formatTimestamp = (ts: string): string => {
  const d = new Date(ts);
  return d.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
};

export function AuditLogTable({ events }: AuditLogTableProps) {
  const [expandedId, setExpandedId] = useState<string | null>(null);

  if (events.length === 0) {
    return (
      <div className="flex flex-col items-center py-12 text-text-disabled">
        <svg
          className="mb-3 h-8 w-8"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={1.5}
            d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
          />
        </svg>
        <p>No audit events found</p>
      </div>
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b border-border-subtle text-text-disabled">
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Timestamp
            </th>
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Category
            </th>
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Event Type
            </th>
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Actor
            </th>
            <th className="px-3 py-2 text-xs font-medium uppercase tracking-wider">
              Target
            </th>
          </tr>
        </thead>
        <tbody>
          {events.map((event) => {
            const catCfg = categoryConfig[event.event_category] ?? {
              bg: 'bg-bg-input',
              text: 'text-text-disabled',
              label: event.event_category,
            };
            const isExpanded = expandedId === event.id;

            return (
              <>
                <tr
                  key={event.id}
                  onClick={() =>
                    setExpandedId(isExpanded ? null : event.id)
                  }
                  className="cursor-pointer border-b border-border-subtle transition-colors hover:bg-bg-hover"
                >
                  <td className="px-3 py-2.5">
                    <span className="text-xs text-text-secondary font-mono">
                      {formatTimestamp(event.created_at)}
                    </span>
                  </td>
                  <td className="px-3 py-2.5">
                    <span
                      className={`inline-block rounded px-2 py-0.5 text-xs font-medium ${catCfg.bg} ${catCfg.text}`}
                    >
                      {catCfg.label}
                    </span>
                  </td>
                  <td className="px-3 py-2.5">
                    <span className="text-text-primary font-mono text-xs">
                      {event.event_type}
                    </span>
                  </td>
                  <td className="px-3 py-2.5">
                    <span className="text-text-secondary text-xs">
                      {event.actor_email || 'System'}
                    </span>
                  </td>
                  <td className="px-3 py-2.5">
                    <span className="text-text-disabled text-xs">
                      {event.target_type
                        ? `${event.target_type}${event.target_id ? ':' + event.target_id.slice(0, 8) : ''}`
                        : '—'}
                    </span>
                  </td>
                </tr>
                {isExpanded && (
                  <tr key={`${event.id}-detail`}>
                    <td
                      colSpan={5}
                      className="bg-bg-elevated px-6 py-3"
                    >
                      <pre className="whitespace-pre-wrap break-all text-xs text-text-secondary font-mono">
                        {JSON.stringify(event.details, null, 2)}
                      </pre>
                      {event.ip_address && (
                        <p className="mt-2 text-[10px] text-text-disabled">
                          IP: {event.ip_address}
                          {event.user_agent && (
                            <> | UA: {event.user_agent}</>
                          )}
                        </p>
                      )}
                    </td>
                  </tr>
                )}
              </>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
