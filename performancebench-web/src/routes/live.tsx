import { useState, useCallback, useEffect, useRef } from 'react';
import { createFileRoute } from '@tanstack/react-router';
import { Wifi, WifiOff } from 'lucide-react';
import { ProtectedRoute } from '@/components/auth/ProtectedRoute';
import { LiveChart } from '@/components/charts/LiveChart';
import { useWebSocket } from '@/hooks/useWebSocket';

// ─── Route ──────────────────────────────────────────────────────────────────

export const Route = createFileRoute('/live')({
  component: LivePage,
});

// ─── Metric extractors ──────────────────────────────────────────────────────

function extractFps(s: Record<string, unknown>): number | null {
  return typeof s.fps === 'number' ? s.fps : null;
}
function extractCpu(s: Record<string, unknown>): number | null {
  const app = typeof s.cpu_app_pct === 'number' ? s.cpu_app_pct : 0;
  const sys = typeof s.cpu_system_pct === 'number' ? s.cpu_system_pct : 0;
  return app + sys;
}
function extractMemory(s: Record<string, unknown>): number | null {
  return typeof s.memory_pss_kb === 'number' ? s.memory_pss_kb : null;
}
function extractBattery(s: Record<string, unknown>): number | null {
  return typeof s.battery_pct === 'number' ? s.battery_pct : null;
}
function extractNetworkTx(s: Record<string, unknown>): number | null {
  return typeof s.net_tx_bytes === 'number' ? s.net_tx_bytes : null;
}
function extractGpu(s: Record<string, unknown>): number | null {
  return typeof s.gpu_pct === 'number' ? s.gpu_pct : null;
}

// ─── Metric card field ──────────────────────────────────────────────────────

interface MetricField {
  key: string;
  label: string;
  unit: string;
  extract: (s: Record<string, unknown>) => number | null;
  color: string;
}

const METRICS: MetricField[] = [
  { key: 'fps', label: 'FPS', unit: 'fps', extract: extractFps, color: '#569CD6' },
  { key: 'cpu', label: 'CPU', unit: '%', extract: extractCpu, color: '#4EC9B0' },
  { key: 'memory', label: 'Memory', unit: 'KB', extract: extractMemory, color: '#CE9178' },
  { key: 'battery', label: 'Battery', unit: '%', extract: extractBattery, color: '#DCDCAA' },
  { key: 'network', label: 'Network TX', unit: 'bytes', extract: extractNetworkTx, color: '#4FC1FF' },
  { key: 'gpu', label: 'GPU', unit: '%', extract: extractGpu, color: '#C586C0' },
];

// ─── Main Page ──────────────────────────────────────────────────────────────

function LivePage() {
  const [sessionId, setSessionId] = useState('');
  const [connected, setConnected] = useState(false);
  const [currentValues, setCurrentValues] = useState<
    Record<string, number | null>
  >({});
  const [wsSessionId, setWsSessionId] = useState<string | null>(null);

  const { onSample } = useWebSocket(wsSessionId);

  // Listen for connection state via the sample callback
  // Set up listeners when connected
  const handleConnect = useCallback(() => {
    if (!sessionId.trim()) return;
    setWsSessionId(sessionId.trim());
    setConnected(true);
  }, [sessionId]);

  // Subscribe to all metrics via useEffect — properly cleans up on unmount
  // or when wsSessionId changes, preventing memory leaks and stale listeners.
  const cleanupRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    if (!wsSessionId) return;

    // Clean up previous listener before subscribing a new one
    cleanupRef.current?.();

    const cleanup = onSample((sample) => {
      const values: Record<string, number | null> = {};
      for (const m of METRICS) {
        values[m.key] = m.extract(sample);
      }
      setCurrentValues(values);
      setConnected(true);
    });
    cleanupRef.current = cleanup;

    return () => {
      cleanup();
      cleanupRef.current = null;
    };
  }, [wsSessionId, onSample]);

  return (
    <ProtectedRoute>
      <div className="p-6 space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-text-primary">
              Live Overlay
            </h1>
            <p className="mt-1 text-sm text-text-secondary">
              Real-time performance monitoring via WebSocket. Enter a session ID to
              view live metrics.
            </p>
          </div>
          {/* Status indicator */}
          {wsSessionId && (
            <div className="flex items-center gap-2">
              {connected ? (
                <>
                  <span className="relative flex h-3 w-3">
                    <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-accent-success opacity-75" />
                    <span className="relative inline-flex h-3 w-3 rounded-full bg-accent-success" />
                  </span>
                  <span className="text-sm font-medium text-accent-success">
                    LIVE
                  </span>
                </>
              ) : (
                <>
                  <WifiOff className="h-4 w-4 text-accent-danger" />
                  <span className="text-sm font-medium text-accent-danger">
                    DISCONNECTED
                  </span>
                </>
              )}
            </div>
          )}
        </div>

        {/* Session ID input (shown when not connected) */}
        {!wsSessionId && (
          <div className="flex items-end gap-3 rounded-lg border border-border-subtle bg-bg-elevated p-4">
            <div className="flex-1">
              <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
                Session ID
              </label>
              <input
                type="text"
                placeholder="Enter session UUID to stream live metrics"
                value={sessionId}
                onChange={(e) => setSessionId(e.target.value)}
                className="w-full rounded border border-border-subtle bg-bg-input px-3 py-2 text-sm text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none font-mono-data"
              />
            </div>
            <button
              onClick={handleConnect}
              disabled={!sessionId.trim()}
              className="flex items-center gap-1.5 rounded bg-accent-blue px-4 py-2 text-sm font-medium text-white hover:opacity-90 disabled:opacity-50"
            >
              <Wifi className="h-4 w-4" />
              Connect
            </button>
          </div>
        )}

        {/* Metric Summary Cards */}
        {wsSessionId && (
          <>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
              {METRICS.map((m) => (
                <div
                  key={m.key}
                  className="rounded-lg border border-border-subtle bg-bg-elevated p-3"
                >
                  <p className="text-[10px] uppercase text-text-disabled">
                    {m.label}
                  </p>
                  <p
                    className="mt-0.5 font-mono-data text-lg font-bold"
                    style={{ color: m.color }}
                  >
                    {currentValues[m.key] != null
                      ? currentValues[m.key]!.toFixed(1)
                      : '—'}
                  </p>
                  <span className="text-[10px] text-text-disabled">
                    {m.unit}
                  </span>
                </div>
              ))}
            </div>

            {/* Live Charts Grid */}
            <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
              {METRICS.map((m) => (
                <div
                  key={m.key}
                  className="rounded-lg border border-border-subtle bg-bg-elevated p-3"
                >
                  <h3 className="mb-2 text-[10px] font-semibold uppercase tracking-wider text-text-secondary">
                    {m.label}
                  </h3>
                  <div style={{ height: 200 }}>
                    <LiveChart
                      metric={m.label}
                      color={m.color}
                      yLabel={m.unit}
                      onSample={onSample}
                      extractValue={m.extract}
                    />
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </ProtectedRoute>
  );
}
