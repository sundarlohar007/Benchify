import { useState, useMemo, useCallback } from 'react';
import { createFileRoute } from '@tanstack/react-router';
import { TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { TrendChart } from '@/components/charts/TrendChart';
import {
  useFpsTrends,
  useCpuTrends,
  useMemoryTrends,
  useBatteryTrends,
  useNetworkTrends,
  computeTrendSummary,
  type TrendFilters,
  type TrendPoint,
} from '@/hooks/useTrends';
import { formatTimestamp } from '@/lib/utils';

// ─── KPI definitions ────────────────────────────────────────────────────────

const KPIS = [
  { id: 'fps', label: 'FPS', color: '#569CD6', unit: 'fps' },
  { id: 'cpu', label: 'CPU', color: '#4EC9B0', unit: '%' },
  { id: 'memory', label: 'Memory', color: '#CE9178', unit: 'KB' },
  { id: 'battery', label: 'Battery', color: '#DCDCAA', unit: '%/hr' },
  { id: 'network', label: 'Network', color: '#4FC1FF', unit: 'kbps' },
] as const;

type KpiId = (typeof KPIS)[number]['id'];

// ─── Route ──────────────────────────────────────────────────────────────────

export const Route = createFileRoute('/trends')({
  component: TrendsPage,
});

// ─── Default date range (last 30 days) ──────────────────────────────────────

function defaultDateRange() {
  const end = new Date();
  const start = new Date();
  start.setDate(start.getDate() - 30);
  return {
    start: start.toISOString().slice(0, 10),
    end: end.toISOString().slice(0, 10),
  };
}

// ─── Main Page ──────────────────────────────────────────────────────────────

function TrendsPage() {
  const [kpi, setKpi] = useState<KpiId>('fps');
  const [startDate, setStartDate] = useState(defaultDateRange().start);
  const [endDate, setEndDate] = useState(defaultDateRange().end);
  const [appName, setAppName] = useState('');

  const filters: TrendFilters = useMemo(
    () => ({
      start_date: startDate,
      end_date: endDate,
      ...(appName ? { app_name: appName } : {}),
    }),
    [startDate, endDate, appName],
  );

  // Fetch all KPIs (used for summary cards)
  const fpsQuery = useFpsTrends(filters);
  const cpuQuery = useCpuTrends(filters);
  const memoryQuery = useMemoryTrends(filters);
  const batteryQuery = useBatteryTrends(filters);
  const networkQuery = useNetworkTrends(filters);

  const kpiQueries = { fps: fpsQuery, cpu: cpuQuery, memory: memoryQuery, battery: batteryQuery, network: networkQuery };
  const activeQuery = kpiQueries[kpi as KpiId];

  const summary = useMemo(
    () => (activeQuery.data?.data ? computeTrendSummary(activeQuery.data.data) : null),
    [activeQuery.data],
  );

  // Convert TrendPoint[] to Chart.js format
  const chartDatasets = useMemo(() => {
    const points = activeQuery.data?.data ?? [];
    const activeKpi = KPIS.find((k) => k.id === kpi);
    return [
      {
        label: activeKpi?.label ?? kpi,
        data: points
          .filter((p: TrendPoint) => p.value != null)
          .map((p: TrendPoint) => ({ x: new Date(p.timestamp).getTime(), y: p.value! })),
        borderColor: activeKpi?.color ?? '#569CD6',
        backgroundColor: (activeKpi?.color ?? '#569CD6') + '30',
        fill: false,
        tension: 0.1,
        pointRadius: 3,
        pointHoverRadius: 6,
        borderWidth: 2,
      },
    ];
  }, [activeQuery.data, kpi]);

  const isLoading = activeQuery.isLoading;
  const error = activeQuery.error;

  const inputClass =
    'rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-6">
        {/* Header */}
        <div>
          <h1 className="text-xl font-semibold text-text-primary">
            Trends Explorer
          </h1>
          <p className="mt-1 text-sm text-text-secondary">
            Track KPI trends across all uploaded sessions over time.
          </p>
        </div>

        {/* Filters bar */}
        <div className="flex flex-wrap items-end gap-3 rounded-lg border border-border-subtle bg-bg-elevated p-3">
          <div>
            <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
              From
            </label>
            <input
              type="date"
              className={inputClass}
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
            />
          </div>
          <div>
            <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
              To
            </label>
            <input
              type="date"
              className={inputClass}
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
            />
          </div>
          <div>
            <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
              App
            </label>
            <input
              type="text"
              className={inputClass}
              placeholder="All apps"
              value={appName}
              onChange={(e) => setAppName(e.target.value)}
            />
          </div>
        </div>

        {/* KPI Selector Tabs */}
        <div className="flex gap-1 rounded-lg border border-border-subtle bg-bg-elevated p-1">
          {KPIS.map(({ id, label }) => (
            <button
              key={id}
              onClick={() => setKpi(id)}
              className={`flex-1 rounded px-3 py-1.5 text-xs font-medium transition-colors ${
                kpi === id
                  ? 'bg-accent-blue text-white'
                  : 'text-text-secondary hover:text-text-primary hover:bg-bg-hover'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {/* Summary Stats */}
        {summary && (
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-5">
            <SummaryCard
              label="Average"
              value={summary.avg.toFixed(1)}
              unit={KPIS.find((k) => k.id === kpi)?.unit ?? ''}
            />
            <SummaryCard
              label="Best"
              value={summary.max?.value.toFixed(1)}
              unit={KPIS.find((k) => k.id === kpi)?.unit ?? ''}
              detail={
                summary.max
                  ? formatTimestamp(summary.max.sessionId.slice(0, 8))
                  : undefined
              }
            />
            <SummaryCard
              label="Worst"
              value={summary.min?.value.toFixed(1)}
              unit={KPIS.find((k) => k.id === kpi)?.unit ?? ''}
              detail={
                summary.min
                  ? formatTimestamp(summary.min.sessionId.slice(0, 8))
                  : undefined
              }
            />
            <SummaryCard
              label="Sessions"
              value={String(summary.count)}
              unit="total"
            />
            <TrendDirectionCard trend={summary.trend} changePct={summary.changePct} />
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="rounded border border-accent-danger/30 bg-accent-danger/10 px-4 py-3 text-sm text-accent-danger">
            Failed to load trend data. Ensure the server is running.
          </div>
        )}

        {/* Chart */}
        <div className="rounded-lg border border-border-subtle bg-bg-elevated p-4">
          <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-text-secondary">
            {KPIS.find((k) => k.id === kpi)?.label} Trend
          </h3>
          {isLoading ? (
            <div className="h-[300px] animate-pulse rounded bg-bg-base" />
          ) : chartDatasets[0].data.length === 0 ? (
            <div className="flex h-[300px] items-center justify-center text-text-disabled">
              No trend data available for the selected filters.
            </div>
          ) : (
            <TrendChart
              datasets={chartDatasets}
              yAxisLabel={KPIS.find((k) => k.id === kpi)?.unit}
              height={300}
            />
          )}
        </div>

        {/* Session List Table */}
        {activeQuery.data?.data && activeQuery.data.data.length > 0 && (
          <div className="rounded-lg border border-border-subtle overflow-hidden">
            <h3 className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-text-secondary border-b border-border-subtle bg-bg-elevated">
              Sessions ({activeQuery.data.data.length})
            </h3>
            <table className="w-full">
              <thead>
                <tr className="border-b border-border-subtle bg-bg-elevated/50">
                  <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                    App
                  </th>
                  <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                    Date
                  </th>
                  <th className="px-3 py-2 text-right text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                    {KPIS.find((k) => k.id === kpi)?.label}
                  </th>
                </tr>
              </thead>
              <tbody>
                {activeQuery.data.data.map((pt: TrendPoint) => (
                  <tr
                    key={pt.sessionId}
                    className="border-b border-border-subtle/30 transition-colors hover:bg-bg-hover cursor-pointer"
                  >
                    <td className="px-3 py-2 text-sm text-text-primary">
                      {pt.appName}
                    </td>
                    <td className="px-3 py-2 text-xs text-text-secondary">
                      {formatTimestamp(pt.timestamp)}
                    </td>
                    <td className="px-3 py-2 text-right font-mono-data text-sm text-text-primary">
                      {pt.value != null ? pt.value.toFixed(1) : '—'}
                      <span className="ml-1 text-[10px] text-text-disabled">
                        {KPIS.find((k) => k.id === kpi)?.unit}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </ProtectedRoute>
  );
}

// ─── Sub-components ─────────────────────────────────────────────────────────

function SummaryCard({
  label,
  value,
  unit,
  detail,
}: {
  label: string;
  value: string | undefined;
  unit: string;
  detail?: string;
}) {
  return (
    <div className="rounded-lg border border-border-subtle bg-bg-elevated p-3">
      <p className="text-[10px] uppercase text-text-disabled">{label}</p>
      <p className="mt-0.5 font-mono-data text-lg font-semibold text-text-primary">
        {value ?? '—'}
        {value && <span className="ml-1 text-sm font-normal text-text-disabled">{unit}</span>}
      </p>
      {detail && <p className="mt-0.5 text-[10px] text-text-disabled">{detail}</p>}
    </div>
  );
}

function TrendDirectionCard({
  trend,
  changePct,
}: {
  trend: 'up' | 'down' | 'flat';
  changePct: number;
}) {
  const icon =
    trend === 'up' ? (
      <TrendingUp className="h-4 w-4 text-accent-success" />
    ) : trend === 'down' ? (
      <TrendingDown className="h-4 w-4 text-accent-danger" />
    ) : (
      <Minus className="h-4 w-4 text-text-disabled" />
    );

  const color =
    trend === 'up' ? 'text-accent-success' : trend === 'down' ? 'text-accent-danger' : 'text-text-disabled';

  return (
    <div className="rounded-lg border border-border-subtle bg-bg-elevated p-3">
      <p className="text-[10px] uppercase text-text-disabled">Trend</p>
      <div className="mt-0.5 flex items-center gap-1">
        {icon}
        <p className={`font-mono-data text-lg font-semibold ${color}`}>
          {changePct > 0 ? '+' : ''}
          {changePct}%
        </p>
      </div>
    </div>
  );
}
