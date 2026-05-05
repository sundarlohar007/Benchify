/**
 * Format duration in milliseconds to human-readable string.
 * e.g., 5025000 → "1h 23m 45s"
 */
export function formatDuration(ms: number): string {
  if (ms < 0) return '—';
  const seconds = Math.floor(ms / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);

  if (hours > 0) {
    const remainingMin = minutes % 60;
    const remainingSec = seconds % 60;
    return `${hours}h ${remainingMin}m ${remainingSec}s`;
  }
  if (minutes > 0) {
    const remainingSec = seconds % 60;
    return `${minutes}m ${remainingSec}s`;
  }
  return `${seconds}s`;
}

/**
 * Format ISO timestamp to readable date string.
 * e.g., "2026-05-05T14:30:00Z" → "May 5, 2026 14:30"
 */
export function formatTimestamp(ts: string): string {
  const date = new Date(ts);
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * Format a number as a percentage string.
 * e.g., 60.0 → "60.0%"
 */
export function formatPercent(val: number | null | undefined): string {
  if (val === null || val === undefined) return '—';
  return `${val.toFixed(1)}%`;
}

/**
 * Format bytes to human-readable size string.
 * e.g., 1289748480 → "1.2 GB"
 */
export function formatKB(val: number | null | undefined): string {
  if (val === null || val === undefined) return '—';
  const bytes = val * 1024;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let unitIndex = 0;
  let size = bytes;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return `${size.toFixed(1)} ${units[unitIndex]}`;
}

/**
 * Format FPS value with color coding hint.
 */
export function fpsColorClass(fps: number | null | undefined): string {
  if (fps === null || fps === undefined) return 'text-text-disabled';
  if (fps > 55) return 'text-accent-success';
  if (fps > 30) return 'text-accent-warning';
  return 'text-accent-danger';
}

/**
 * Truncate a string to maxLen characters.
 */
export function truncate(str: string, maxLen: number): string {
  if (str.length <= maxLen) return str;
  return str.slice(0, maxLen - 3) + '...';
}

/**
 * Generate a relative time string from ISO timestamp.
 */
export function relativeTime(ts: string): string {
  const now = Date.now();
  const then = new Date(ts).getTime();
  const diffMs = now - then;

  if (diffMs < 0) return 'just now';

  const seconds = Math.floor(diffMs / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (minutes > 0) return `${minutes}m ago`;
  return 'just now';
}
