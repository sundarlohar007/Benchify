import { useState, type FormEvent } from 'react';
import { Search, X } from 'lucide-react';
import type { SessionFilters as Filters } from '@/hooks/useSessions';

interface SessionFiltersProps {
  filters: Filters;
  onApply: (filters: Filters) => void;
}

const DEFAULT_FILTERS: Filters = {};

export function SessionFilters({ filters, onApply }: SessionFiltersProps) {
  const [local, setLocal] = useState<Filters>(filters);

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    onApply(local);
  };

  const handleClear = () => {
    setLocal(DEFAULT_FILTERS);
    onApply(DEFAULT_FILTERS);
  };

  const hasFilters =
    local.appName ||
    local.deviceModel ||
    local.tags ||
    local.projectId ||
    local.dateFrom ||
    local.dateTo;

  const inputClass =
    'w-full rounded border border-border-subtle bg-bg-input px-2.5 py-1.5 text-xs text-text-primary placeholder:text-text-disabled focus:border-border-focus focus:outline-none';

  return (
    <form
      onSubmit={handleSubmit}
      className="flex flex-wrap items-end gap-3 rounded-lg border border-border-subtle bg-bg-elevated p-3"
    >
      {/* App Name */}
      <div className="min-w-[120px] flex-1">
        <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
          App Name
        </label>
        <input
          type="text"
          className={inputClass}
          placeholder="e.g. Benchify"
          value={local.appName ?? ''}
          onChange={(e) =>
            setLocal((p) => ({ ...p, appName: e.target.value || undefined }))
          }
        />
      </div>

      {/* Device Model */}
      <div className="min-w-[120px] flex-1">
        <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
          Device
        </label>
        <input
          type="text"
          className={inputClass}
          placeholder="e.g. Pixel 8"
          value={local.deviceModel ?? ''}
          onChange={(e) =>
            setLocal((p) => ({
              ...p,
              deviceModel: e.target.value || undefined,
            }))
          }
        />
      </div>

      {/* Tags */}
      <div className="min-w-[120px] flex-1">
        <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
          Tags
        </label>
        <input
          type="text"
          className={inputClass}
          placeholder="e.g. release,performance"
          value={local.tags ?? ''}
          onChange={(e) =>
            setLocal((p) => ({ ...p, tags: e.target.value || undefined }))
          }
        />
      </div>

      {/* Project ID */}
      <div className="min-w-[100px] flex-1">
        <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
          Project ID
        </label>
        <input
          type="text"
          className={inputClass}
          placeholder="UUID"
          value={local.projectId ?? ''}
          onChange={(e) =>
            setLocal((p) => ({
              ...p,
              projectId: e.target.value || undefined,
            }))
          }
        />
      </div>

      {/* Date From */}
      <div className="min-w-[110px]">
        <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
          From
        </label>
        <input
          type="date"
          className={inputClass}
          value={local.dateFrom ?? ''}
          onChange={(e) =>
            setLocal((p) => ({
              ...p,
              dateFrom: e.target.value || undefined,
            }))
          }
        />
      </div>

      {/* Date To */}
      <div className="min-w-[110px]">
        <label className="mb-1 block text-[10px] uppercase tracking-wider text-text-disabled">
          To
        </label>
        <input
          type="date"
          className={inputClass}
          value={local.dateTo ?? ''}
          onChange={(e) =>
            setLocal((p) => ({
              ...p,
              dateTo: e.target.value || undefined,
            }))
          }
        />
      </div>

      {/* Buttons */}
      <div className="flex items-end gap-2">
        <button
          type="submit"
          className="flex items-center gap-1 rounded bg-accent-blue px-3 py-1.5 text-xs font-medium text-white transition-opacity hover:opacity-90"
        >
          <Search className="h-3 w-3" />
          Apply
        </button>
        {hasFilters && (
          <button
            type="button"
            onClick={handleClear}
            className="flex items-center gap-1 rounded px-2 py-1.5 text-xs text-text-secondary hover:bg-bg-hover hover:text-text-primary transition-colors"
          >
            <X className="h-3 w-3" />
            Clear
          </button>
        )}
      </div>
    </form>
  );
}
