import { useState } from 'react';
import { Download, Loader2 } from 'lucide-react';

interface AuditExportButtonProps {
  /** Current filter state (used to pre-populate export params). */
  filters: {
    from?: string;
    to?: string;
    category?: string;
  };
  /** Called when user confirms export. */
  onExport: (format: 'csv' | 'json') => void;
  /** Whether an export is currently in progress. */
  isExporting: boolean;
  /** Disable the button (e.g., when no events loaded). */
  disabled?: boolean;
}

export function AuditExportButton({
  filters,
  onExport,
  isExporting,
  disabled,
}: AuditExportButtonProps) {
  const [open, setOpen] = useState(false);

  return (
    <div className="relative">
      <button
        onClick={() => setOpen(!open)}
        disabled={disabled}
        className="flex items-center gap-1.5 rounded border border-border-subtle bg-bg-elevated px-3 py-1.5 text-xs text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isExporting ? (
          <Loader2 className="h-3.5 w-3.5 animate-spin" />
        ) : (
          <Download className="h-3.5 w-3.5" />
        )}
        {isExporting ? 'Exporting...' : 'Export'}
      </button>

      {open && !isExporting && (
        <div className="absolute right-0 top-full mt-1 z-20 w-44 rounded border border-border-subtle bg-bg-elevated py-1 shadow-lg">
          <p className="px-3 py-1.5 text-[10px] text-text-disabled uppercase tracking-wider">
            Export Format
          </p>
          <button
            onClick={() => {
              onExport('csv');
              setOpen(false);
            }}
            className="w-full px-3 py-1.5 text-left text-xs text-text-primary hover:bg-bg-hover"
          >
            Export CSV
          </button>
          <button
            onClick={() => {
              onExport('json');
              setOpen(false);
            }}
            className="w-full px-3 py-1.5 text-left text-xs text-text-primary hover:bg-bg-hover"
          >
            Export JSON
          </button>
        </div>
      )}
    </div>
  );
}
