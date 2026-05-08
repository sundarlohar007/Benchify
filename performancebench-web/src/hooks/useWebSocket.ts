import { useEffect, useRef, useCallback } from 'react';

type SampleListener = (sample: Record<string, unknown>) => void;

const MAX_RETRIES = 30;
const BASE_DELAY_MS = 1000;
const MAX_DELAY_MS = 30000;

export function useWebSocket(sessionId: string | null) {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const listenersRef = useRef<Set<SampleListener>>(new Set());
  const retryCountRef = useRef(0);

  const connect = useCallback(() => {
    if (!sessionId) return;
    if (retryCountRef.current >= MAX_RETRIES) return;

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

    ws.onopen = () => {
      // Reset retry counter on successful connection
      retryCountRef.current = 0;
    };

    ws.onclose = () => {
      if (retryCountRef.current < MAX_RETRIES) {
        const delay = Math.min(
          BASE_DELAY_MS * Math.pow(2, retryCountRef.current),
          MAX_DELAY_MS,
        );
        retryCountRef.current++;
        reconnectTimeoutRef.current = window.setTimeout(connect, delay);
      }
    };

    ws.onerror = () => {
      ws.close();
    };

    wsRef.current = ws;
  }, [sessionId]);

  useEffect(() => {
    retryCountRef.current = 0;
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
