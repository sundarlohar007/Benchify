import { useState, useMemo } from 'react';
import {
  BarChart3,
  LineChart,
  FileText,
  AlertTriangle,
  Bookmark,
} from 'lucide-react';
import { TrendChart } from '@/components/charts/TrendChart';
import type { TrendDataset } from '@/components/charts/TrendChart';
import type {
  SessionDetail,
  MetricSample,
  SessionStats,
  Marker,
  DetectedIssue,
} from '@/hooks/useSessions';
import {
  formatDuration,
  formatTimestamp,
  formatPercent,
  formatKB,
} from '@/lib/utils';

// ─── Tab definitions ─────────────────────────────────────────────────────

const TABS = [
  { id: 'overview', label: 'Overview', icon: BarChart3 },
  { id: 'performance', label: 'Performance', icon: LineChart },
  { id: 'stats', label: 'Stats', icon: FileText },
  { id: 'issues', label: 'Issues', icon: AlertTriangle },
  { id: 'markers', label: 'Markers', icon: Bookmark },
] as const;

type TabId = (typeof TABS)[number]['id'];

interface Props {
  session: SessionDetail;
}

// ─── Chart data helpers ───────────────────────────────────────────────────

function samplesToChartData(
  samples: MetricSample[],
  field: (s: MetricSample) => number | null,
  label: string,
  color: string,
): TrendDataset {
  const data = samples
    .filter((s) => field(s) != null)
    .map((s) => ({ x: s.timestamp, y: field(s)! }));
  return {
    label,
    data,
    borderColor: color,
    backgroundColor: color + '30',
    fill: false,
    tension: 0.1,
    pointRadius: 0,
    borderWidth: 1.5,
  };
}

/** Compute network rate (KB/s) from cumulative byte counters */
function computeNetworkRate(
  samples: MetricSample[],
  field: (s: MetricSample) => number | null,
): { x: number; y: number }[] {
  const result: { x: number; y: number }[] = [];
  for (let i = 1; i < samples.length; i++) {
    const prev = field(samples[i - 1]);
    const curr = field(samples[i]);
    if (prev == null || curr == null) continue;
    const dt = (samples[i].timestamp - samples[i - 1].timestamp) / 1000; // seconds
    if (dt <= 0 || dt > 10) continue; // skip large gaps
    const rate = (curr - prev) / dt / 1024; // bytes → KB/s
    result.push({ x: samples[i].timestamp, y: Math.max(0, rate) });
  }
  return result;
}

// ─── Stat row helpers ─────────────────────────────────────────────────────

function StatRow({
  label,
  value,
  unit,
}: {
  label: string;
  value: string | number | null | undefined;
  unit?: string;
}) {
  return (
    <div className="flex items-center justify-between border-b border-border-subtle/30 py-2">
      <span className="text-xs text-text-secondary">{label}</span>
      <span className="font-mono-data text-sm text-text-primary">
        {value != null ? value : <span className="text-text-disabled">—</span>}
        {unit && value != null && (
          <span className="ml-1 text-text-disabled">{unit}</span>
        )}
      </span>
    </div>
  );
}

function SectionHeader({ label }: { label: string }) {
  return (
    <h3 className="mb-1 mt-4 text-[10px] font-semibold uppercase tracking-wider text-text-accent">
      {label}
    </h3>
  );
}

// ─── Severity badge ───────────────────────────────────────────────────────

function SeverityBadge({ severity }: { severity: string }) {
  const colorMap: Record<string, string> = {
    critical: 'bg-accent-danger/15 text-accent-danger',
    high: 'bg-accent-warning/15 text-accent-warning',
    medium: 'bg-accent-gold/15 text-accent-gold',
    informational: 'bg-accent-blue/15 text-accent-blue',
    info: 'bg-accent-blue/15 text-accent-blue',
    warning: 'bg-accent-warning/15 text-accent-warning',
  };
  const cls = colorMap[severity] ?? 'bg-bg-hover text-text-secondary';
  return (
    <span
      className={`inline-block rounded px-2 py-0.5 text-[10px] font-semibold uppercase ${cls}`}
    >
      {severity}
    </span>
  );
}

// ─── Main component ───────────────────────────────────────────────────────

export function SessionDetailTabs({ session }: Props) {
  const [activeTab, setActiveTab] = useState<TabId>('overview');
  const stats = session.session_stats;
  const samples = session.metric_samples ?? [];
  const markers = session.markers ?? [];
  const issues = session.detected_issues ?? [];

  // Build chart datasets once
  const fpsDataset = useMemo(
    () =>
      samplesToChartData(
        samples,
        (s) => s.fps,
        'FPS',
        'var(--color-chart-fps-raw, #569CD6)',
      ),
    [samples],
  );

  const cpuAppDataset = useMemo(
    () =>
      samplesToChartData(
        samples,
        (s) => s.cpu_app_pct,
        'CPU App %',
        'var(--color-chart-cpu-raw, #4EC9B0)',
      ),
    [samples],
  );

  const cpuSysDataset = useMemo(
    () =>
      samplesToChartData(
        samples,
        (s) => s.cpu_system_pct,
        'CPU System %',
        'var(--color-chart-cpu-raw, #4EC9B0)',
      ),
    [samples],
  );

  const memoryDataset = useMemo(
    () =>
      samplesToChartData(
        samples,
        (s) => s.memory_pss_kb,
        'Memory PSS KB',
        'var(--color-chart-memory-raw, #CE9178)',
      ),
    [samples],
  );

  const batteryDataset = useMemo(
    () =>
      samplesToChartData(
        samples,
        (s) => s.battery_pct,
        'Battery %',
        'var(--color-chart-battery-raw, #DCDCAA)',
      ),
    [samples],
  );

  const netTxRate = useMemo(
    () => ({
      label: 'TX KB/s',
      data: computeNetworkRate(samples, (s) => s.net_tx_bytes),
      borderColor: 'var(--color-chart-network-raw, #4FC1FF)',
      backgroundColor: '#4FC1FF30',
      fill: false,
      tension: 0.1,
      pointRadius: 0,
      borderWidth: 1.5,
    }),
    [samples],
  );

  const netRxRate = useMemo(
    () => ({
      label: 'RX KB/s',
      data: computeNetworkRate(samples, (s) => s.net_rx_bytes),
      borderColor: '#85C1E9',
      backgroundColor: '#85C1E930',
      fill: false,
      tension: 0.1,
      pointRadius: 0,
      borderWidth: 1.5,
    }),
    [samples],
  );

  const gpuDataset = useMemo(
    () =>
      samplesToChartData(
        samples,
        (s) => s.gpu_pct,
        'GPU %',
        'var(--color-chart-gpu-raw, #C586C0)',
      ),
    [samples],
  );

  // ─── Tab bar ──────────────────────────────────────────────────────────

  return (
    <div className="space-y-4">
      {/* Tab navigation */}
      <div className="flex border-b border-border-subtle">
        {TABS.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center gap-2 px-4 py-2.5 text-sm font-medium transition-colors ${
                isActive
                  ? 'border-b-2 border-accent-blue text-text-accent'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              <Icon className="h-4 w-4" />
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* ─── OVERVIEW TAB ─────────────────────────────────────────────── */}
      {activeTab === 'overview' && (
        <div className="space-y-6">
          {/* Metadata */}
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <MetaCard label="App" value={session.app_name ?? 'Unknown'} />
            <MetaCard label="Device" value={session.device_id} />
            <MetaCard
              label="Duration"
              value={
                session.duration_ms != null
                  ? formatDuration(session.duration_ms)
                  : '—'
              }
            />
            <MetaCard
              label="Started"
              value={formatTimestamp(new Date(session.started_at).toISOString())}
            />
          </div>

          {/* Key stats grid */}
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            <StatCard
              label="FPS Median"
              value={stats?.fps_median}
              unit="fps"
              colorClass="text-chart-fps"
            />
            <StatCard
              label="CPU Avg"
              value={stats?.cpu_avg_pct}
              unit="%"
              colorClass="text-chart-cpu"
            />
            <StatCard
              label="Memory Peak"
              value={stats?.memory_peak_kb}
              unit="KB"
              colorClass="text-chart-memory"
            />
            <StatCard
              label="GPU Avg"
              value={stats?.gpu_avg_pct}
              unit="%"
              colorClass="text-chart-gpu"
            />
            <StatCard
              label="Battery Drain"
              value={stats?.battery_drain_per_hour}
              unit="%/hr"
              colorClass="text-chart-battery"
            />
            <StatCard
              label="Jank Total"
              value={stats?.jank_total}
              unit="janks"
              colorClass="text-accent-warning"
            />
            <StatCard
              label="Network TX"
              value={stats?.net_total_tx_kb}
              unit="KB"
              colorClass="text-chart-network"
            />
            <StatCard
              label="Thermal Peak"
              value={stats?.thermal_peak}
              unit="status"
              colorClass="text-accent-danger"
            />
          </div>

          {/* Detected Issues card with severity breakdown */}
          <div className="rounded-lg border border-border-subtle bg-bg-elevated p-4">
            <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-text-secondary">
              Detected Issues
            </h3>
            {issues.length === 0 ? (
              <div className="flex items-center gap-2 text-sm text-accent-success">
                <AlertTriangle className="h-4 w-4" />
                No issues detected. This session looks clean.
              </div>
            ) : (
              <div className="space-y-3">
                <div className="flex flex-wrap gap-3">
                  {(() => {
                    const criticalCount = issues.filter(
                      (i) => i.severity === 'critical' || i.severity === 'high',
                    ).length;
                    const warningCount = issues.filter(
                      (i) => i.severity === 'warning' || i.severity === 'medium',
                    ).length;
                    const infoCount = issues.filter(
                      (i) => i.severity === 'info' || i.severity === 'informational',
                    ).length;
                    return (
                      <>
                        {criticalCount > 0 && (
                          <span className="inline-flex items-center gap-1 rounded bg-accent-danger/15 px-3 py-1.5">
                            <span className="h-2 w-2 rounded-full bg-accent-danger" />
                            <span className="text-xs font-semibold text-accent-danger">
                              Critical: {criticalCount}
                            </span>
                          </span>
                        )}
                        {warningCount > 0 && (
                          <span className="inline-flex items-center gap-1 rounded bg-accent-warning/15 px-3 py-1.5">
                            <span className="h-2 w-2 rounded-full bg-accent-warning" />
                            <span className="text-xs font-semibold text-accent-warning">
                              Warning: {warningCount}
                            </span>
                          </span>
                        )}
                        {infoCount > 0 && (
                          <span className="inline-flex items-center gap-1 rounded bg-accent-blue/15 px-3 py-1.5">
                            <span className="h-2 w-2 rounded-full bg-accent-blue" />
                            <span className="text-xs font-semibold text-accent-blue">
                              Info: {infoCount}
                            </span>
                          </span>
                        )}
                      </>
                    );
                  })()}
                </div>
                <button
                  onClick={() => setActiveTab('issues')}
                  className="text-xs text-text-accent hover:underline"
                >
                  View All Issues <span className="text-text-disabled">({issues.length})</span>
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ─── PERFORMANCE TAB ──────────────────────────────────────────── */}
      {activeTab === 'performance' && (
        <div className="space-y-6">
          {samples.length === 0 ? (
            <p className="py-12 text-center text-text-disabled">
              No metric samples available for this session.
            </p>
          ) : (
            <>
              {fpsDataset.data.length > 0 && (
                <ChartCard title="FPS">
                  <TrendChart
                    datasets={[
                      fpsDataset,
                      {
                        label: '30 FPS Threshold',
                        data:
                          fpsDataset.data.length > 0
                            ? [
                                {
                                  x: fpsDataset.data[0].x,
                                  y: 30,
                                },
                                {
                                  x: fpsDataset.data[fpsDataset.data.length - 1]
                                    .x,
                                  y: 30,
                                },
                              ]
                            : [],
                        borderColor: '#F4474730',
                        borderWidth: 1,
                        pointRadius: 0,
                        fill: false,
                      },
                    ]}
                    yAxisLabel="FPS"
                  />
                </ChartCard>
              )}
              {cpuAppDataset.data.length > 0 && (
                <ChartCard title="CPU Usage">
                  <TrendChart
                    datasets={[cpuAppDataset, cpuSysDataset]}
                    yAxisLabel="%"
                  />
                </ChartCard>
              )}
              {memoryDataset.data.length > 0 && (
                <ChartCard title="Memory (PSS)">
                  <TrendChart
                    datasets={[
                      { ...memoryDataset, fill: true, backgroundColor: '#CE917820' },
                    ]}
                    yAxisLabel="KB"
                  />
                </ChartCard>
              )}
              {batteryDataset.data.length > 0 && (
                <ChartCard title="Battery Level">
                  <TrendChart
                    datasets={[
                      {
                        ...batteryDataset,
                        fill: true,
                        backgroundColor: '#DCDCAA20',
                      },
                    ]}
                    yAxisLabel="%"
                  />
                </ChartCard>
              )}
              {netTxRate.data.length > 0 && (
                <ChartCard title="Network Throughput">
                  <TrendChart
                    datasets={[netTxRate, netRxRate]}
                    yAxisLabel="KB/s"
                  />
                </ChartCard>
              )}
              {gpuDataset.data.length > 0 && (
                <ChartCard title="GPU Usage">
                  <TrendChart
                    datasets={[gpuDataset]}
                    yAxisLabel="%"
                  />
                </ChartCard>
              )}
            </>
          )}
        </div>
      )}

      {/* ─── STATS TAB ────────────────────────────────────────────────── */}
      {activeTab === 'stats' && (
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
          {/* Column 1 */}
          <div>
            <SectionHeader label="FPS" />
            <StatRow label="Median" value={stats?.fps_median?.toFixed(1)} unit="fps" />
            <StatRow label="Min" value={stats?.fps_min?.toFixed(1)} unit="fps" />
            <StatRow label="Max" value={stats?.fps_max?.toFixed(1)} unit="fps" />
            <StatRow label="1% Low" value={stats?.fps_1pct_low?.toFixed(1)} unit="fps" />
            <StatRow label="Stability" value={stats?.fps_stability?.toFixed(1)} unit="%" />
            <StatRow label="P95 Frame Time" value={stats?.frame_time_p95?.toFixed(2)} unit="ms" />
            <StatRow label="Variability" value={stats?.variability_index?.toFixed(2)} />
            <StatRow label="Jank Ratio Total" value={stats?.frame_ratio_jank_total} />

            <SectionHeader label="CPU" />
            <StatRow label="Avg %" value={stats?.cpu_avg_pct?.toFixed(1)} unit="%" />
            <StatRow label="Peak %" value={stats?.cpu_peak_pct?.toFixed(1)} unit="%" />
            <StatRow label="Avg % Freq Norm" value={stats?.cpu_avg_pct_freq_norm?.toFixed(1)} unit="%" />
            <StatRow label="Peak % Freq Norm" value={stats?.cpu_peak_pct_freq_norm?.toFixed(1)} unit="%" />

            <SectionHeader label="GPU" />
            <StatRow label="Avg %" value={stats?.gpu_avg_pct?.toFixed(1)} unit="%" />
            <StatRow label="Peak %" value={stats?.gpu_peak_pct?.toFixed(1)} unit="%" />

            <SectionHeader label="Thermal" />
            <StatRow label="Peak Status" value={stats?.thermal_peak} />
          </div>

          {/* Column 2 */}
          <div>
            <SectionHeader label="Memory" />
            <StatRow label="Avg PSS" value={formatKB(stats?.memory_avg_kb)} />
            <StatRow label="Peak PSS" value={formatKB(stats?.memory_peak_kb)} />
            <StatRow label="Growth" value={formatKB(stats?.mem_growth_kb)} />
            <StatRow label="Trend Slope" value={stats?.mem_trend_slope_kb_per_min?.toFixed(1)} unit="KB/min" />
            <StatRow label="Java Avg" value={formatKB(stats?.mem_java_avg_kb)} />
            <StatRow label="Java Peak" value={formatKB(stats?.mem_java_peak_kb)} />
            <StatRow label="Native Avg" value={formatKB(stats?.mem_native_avg_kb)} />
            <StatRow label="Native Peak" value={formatKB(stats?.mem_native_peak_kb)} />
            <StatRow label="Graphics Avg" value={formatKB(stats?.mem_graphics_avg_kb)} />
            <StatRow label="Graphics Peak" value={formatKB(stats?.mem_graphics_peak_kb)} />
            <StatRow label="Code Avg" value={formatKB(stats?.mem_code_avg_kb)} />
            <StatRow label="System Avg" value={formatKB(stats?.mem_system_avg_kb)} />
            <StatRow label="WebView Avg" value={formatKB(stats?.mem_webview_avg_kb)} />

            <SectionHeader label="Battery + Power" />
            <StatRow label="Drain %" value={stats?.battery_drain_pct?.toFixed(1)} unit="%" />
            <StatRow label="Drain Rate" value={stats?.battery_drain_per_hour?.toFixed(2)} unit="%/hr" />
            <StatRow label="Temp Max" value={stats?.battery_temp_max_c?.toFixed(1)} unit="°C" />
            <StatRow label="mAh Consumed" value={stats?.mah_consumed?.toFixed(1)} unit="mAh" />
            <StatRow label="Avg Power" value={stats?.avg_power_mw?.toFixed(1)} unit="mW" />
            <StatRow label="Total Power" value={stats?.total_power_mwh?.toFixed(1)} unit="mWh" />
            <StatRow label="Est. Playtime" value={stats?.estimated_playtime_h?.toFixed(1)} unit="h" />

            <SectionHeader label="Jank" />
            <StatRow label="Total" value={stats?.jank_total} />
            <StatRow label="Small" value={stats?.jank_small_total} />
            <StatRow label="Big" value={stats?.jank_big_total} />
            <StatRow label="Ratio" value={stats?.jank_ratio_total} />
            <StatRow label="Per Min" value={stats?.jank_per_min?.toFixed(1)} unit="/min" />

            <SectionHeader label="Network" />
            <StatRow label="TX Total" value={stats?.net_total_tx_kb?.toFixed(0)} unit="KB" />
            <StatRow label="RX Total" value={stats?.net_total_rx_kb?.toFixed(0)} unit="KB" />
            <StatRow label="WiFi TX" value={stats?.net_wifi_total_tx_kb?.toFixed(0)} unit="KB" />
            <StatRow label="WiFi RX" value={stats?.net_wifi_total_rx_kb?.toFixed(0)} unit="KB" />
            <StatRow label="WiFi Avg" value={stats?.net_wifi_avg_kbps?.toFixed(0)} unit="kbps" />
            <StatRow label="Cellular TX" value={stats?.net_cellular_total_tx_kb?.toFixed(0)} unit="KB" />
            <StatRow label="Cellular RX" value={stats?.net_cellular_total_rx_kb?.toFixed(0)} unit="KB" />
            <StatRow label="Cellular Avg" value={stats?.net_cellular_avg_kbps?.toFixed(0)} unit="kbps" />
          </div>
        </div>
      )}

      {/* ─── ISSUES TAB ───────────────────────────────────────────────── */}
      {activeTab === 'issues' && (
        <div className="space-y-3">
          {issues.length === 0 ? (
            <p className="py-12 text-center text-text-disabled">
              No issues detected. This session looks clean.
            </p>
          ) : (
            <>
              {/* Group by severity */}
              {(['critical', 'high', 'medium', 'info', 'informational'] as const).map(
                (severity) => {
                  const group = issues.filter((i) => i.severity === severity);
                  if (group.length === 0) return null;
                  return (
                    <div key={severity}>
                      <h4 className="mb-2 text-xs font-semibold uppercase text-text-disabled">
                        {severity} ({group.length})
                      </h4>
                      <div className="space-y-2">
                        {group.map((issue, idx) => (
                          <IssueCard key={idx} issue={issue} />
                        ))}
                      </div>
                    </div>
                  );
                },
              )}
            </>
          )}
        </div>
      )}

      {/* ─── MARKERS TAB ──────────────────────────────────────────────── */}
      {activeTab === 'markers' && (
        <div>
          {markers.length === 0 ? (
            <p className="py-12 text-center text-text-disabled">
              No markers recorded for this session.
            </p>
          ) : (
            <div className="overflow-x-auto rounded-lg border border-border-subtle">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border-subtle bg-bg-elevated">
                    <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                      Label
                    </th>
                    <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                      Start
                    </th>
                    <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                      End
                    </th>
                    <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                      Duration
                    </th>
                    <th className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled">
                      Notes
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {markers.map((marker, idx) => (
                    <MarkerRow
                      key={marker.id ?? idx}
                      marker={marker}
                      sessionStart={session.started_at}
                    />
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ─── Sub-components ───────────────────────────────────────────────────────

function MetaCard({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="rounded-lg border border-border-subtle bg-bg-elevated p-3">
      <p className="text-[10px] uppercase text-text-disabled">{label}</p>
      <p className="mt-0.5 text-sm text-text-primary truncate" title={value}>
        {value}
      </p>
    </div>
  );
}

function StatCard({
  label,
  value,
  unit,
  colorClass = 'text-text-primary',
}: {
  label: string;
  value: number | null | undefined;
  unit: string;
  colorClass?: string;
}) {
  return (
    <div className="rounded-lg border border-border-subtle bg-bg-elevated p-4">
      <p className="text-[10px] uppercase text-text-disabled">{label}</p>
      <p className={`mt-1 font-mono-data text-xl font-bold ${colorClass}`}>
        {value != null ? value.toFixed(1) : '—'}
      </p>
      {value != null && (
        <span className="text-[10px] text-text-disabled">{unit}</span>
      )}
    </div>
  );
}

function ChartCard({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-lg border border-border-subtle bg-bg-elevated p-4">
      <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-text-secondary">
        {title}
      </h3>
      {children}
    </div>
  );
}

function IssueCard({ issue }: { issue: DetectedIssue }) {
  const [expanded, setExpanded] = useState(false);
  return (
    <div className="rounded border border-border-subtle bg-bg-elevated p-3">
      <div className="flex items-start justify-between">
        <div>
          <div className="flex items-center gap-2">
            <SeverityBadge severity={issue.severity} />
            <span className="font-mono-data text-xs text-text-secondary">
              {issue.rule_id}
            </span>
          </div>
          <p className="mt-1 text-sm text-text-primary">{issue.message}</p>
        </div>
        <button
          onClick={() => setExpanded(!expanded)}
          className="ml-2 text-xs text-text-disabled hover:text-text-secondary"
        >
          {expanded ? 'Less' : 'More'}
        </button>
      </div>
      {expanded && (
        <div className="mt-2 space-y-1 border-t border-border-subtle/50 pt-2">
          {issue.metric && (
            <p className="text-xs text-text-secondary">
              Metric: <span className="font-mono-data">{issue.metric}</span>
            </p>
          )}
          {issue.observed_value != null && (
            <p className="text-xs text-text-secondary">
              Observed:{' '}
              <span className="font-mono-data">
                {issue.observed_value.toFixed(2)}
              </span>
            </p>
          )}
          {issue.threshold_value != null && (
            <p className="text-xs text-text-secondary">
              Threshold:{' '}
              <span className="font-mono-data">
                {issue.threshold_value.toFixed(2)}
              </span>
            </p>
          )}
        </div>
      )}
    </div>
  );
}

function MarkerRow({
  marker,
  sessionStart,
}: {
  marker: Marker;
  sessionStart: number;
}) {
  const relStart = marker.started_at - sessionStart;
  const relEnd =
    marker.ended_at != null ? marker.ended_at - sessionStart : null;
  const duration =
    marker.ended_at != null ? marker.ended_at - marker.started_at : null;

  return (
    <tr className="border-b border-border-subtle/30 transition-colors hover:bg-bg-hover">
      <td className="px-3 py-2 text-sm font-medium text-text-primary">
        {marker.label}
      </td>
      <td className="px-3 py-2 font-mono-data text-xs text-text-secondary">
        {formatDuration(relStart)}
      </td>
      <td className="px-3 py-2 font-mono-data text-xs text-text-secondary">
        {relEnd != null ? formatDuration(relEnd) : '—'}
      </td>
      <td className="px-3 py-2 font-mono-data text-xs text-text-secondary">
        {duration != null ? formatDuration(duration) : '—'}
      </td>
      <td className="max-w-[200px] truncate px-3 py-2 text-xs text-text-disabled">
        {marker.notes ?? '—'}
      </td>
    </tr>
  );
}
