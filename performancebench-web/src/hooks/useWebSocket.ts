import { useEffect, useRef, useCallback } from 'react';

type SampleListener = (sample: Record<string, unknown>) => void;

export function useWebSocket(sessionId: string | null) {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<number>();
  const listenersRef = useRef<Set<SampleListener>>(new Set());

  const connect = useCallback(() => {
    if (!sessionId) return;

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/live/${sessionId}`;
    const ws = new WebSocket(wsUrl);

    ws.onmessage = (event) => {
      try {
        const sample = JSON.parse(event.data);
        listenersRef.current.forEach((fn) => fn(sample));
      } catch {
        // Ignore malformed messages
      }
    };

    ws.onclose = () => {
      // Auto-reconnect after 2s
      reconnectTimeoutRef.current = window.setTimeout(connect, 2000);
    };

    ws.onerror = () => {
      ws.close();
    };

    wsRef.current = ws;
  }, [sessionId]);

  useEffect(() => {
    connect();
    return () => {
      wsRef.current?.close();
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
    };
  }, [connect]);

  const onSample = useCallback((fn: SampleListener) => {
    listenersRef.current.add(fn);
    return () => {
      listenersRef.current.delete(fn);
    };
  }, []);

  return { onSample };
}
