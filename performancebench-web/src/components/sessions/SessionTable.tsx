import { useMemo, useState } from 'react';
import { useNavigate } from '@tanstack/react-router';
import {
  createColumnHelper,
  flexRender,
  getCoreRowModel,
  useReactTable,
  type RowSelectionState,
} from '@tanstack/react-table';
import { Trash2, Download, Video } from 'lucide-react';
import type { Session } from '@/hooks/useSessions';
import {
  formatDuration,
  formatTimestamp,
  fpsColorClass,
  truncate,
} from '@/lib/utils';

const columnHelper = createColumnHelper<Session>();

interface SessionTableProps {
  sessions: Session[];
  isLoading: boolean;
  onDeleteSelected: (ids: string[]) => void;
  onExportSelected: (ids: string[]) => void;
}

export function SessionTable({
  sessions,
  isLoading,
  onDeleteSelected,
  onExportSelected,
}: SessionTableProps) {
  const navigate = useNavigate();
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({});

  const columns = useMemo(
    () => [
      columnHelper.display({
        id: 'select',
        header: ({ table }) => (
          <input
            type="checkbox"
            className="rounded border-border-subtle bg-bg-input accent-accent-blue"
            checked={table.getIsAllRowsSelected()}
            onChange={table.getToggleAllRowsSelectedHandler()}
          />
        ),
        cell: ({ row }) => (
          <input
            type="checkbox"
            className="rounded border-border-subtle bg-bg-input accent-accent-blue"
            checked={row.getIsSelected()}
            onChange={row.getToggleSelectedHandler()}
          />
        ),
        size: 40,
      }),
      columnHelper.accessor('app_name', {
        header: 'App',
        cell: (info) => {
          const name = info.getValue();
          return (
            <span className="font-medium text-text-primary">
              {name || (
                <span className="italic text-text-disabled">Unknown</span>
              )}
            </span>
          );
        },
        size: 140,
      }),
      columnHelper.accessor('device_id', {
        header: 'Device',
        cell: (info) => (
          <span className="text-text-secondary">
            {truncate(info.getValue(), 20)}
          </span>
        ),
        size: 120,
      }),
      columnHelper.accessor('duration_ms', {
        header: 'Duration',
        cell: (info) => (
          <span className="font-mono-data text-text-secondary">
            {info.getValue() != null
              ? formatDuration(info.getValue()!)
              : '—'}
          </span>
        ),
        size: 100,
      }),
      columnHelper.accessor('started_at', {
        header: 'Started',
        cell: (info) => (
          <span className="text-xs text-text-secondary">
            {formatTimestamp(
              new Date(info.getValue()).toISOString(),
            )}
          </span>
        ),
        size: 140,
      }),
      columnHelper.accessor('tags', {
        header: 'Tags',
        cell: (info) => {
          const raw = info.getValue();
          if (!raw) return <span className="text-text-disabled">—</span>;
          try {
            const tags: string[] = JSON.parse(raw);
            return (
              <div className="flex flex-wrap gap-1">
                {tags.slice(0, 3).map((tag) => (
                  <span
                    key={tag}
                    className="inline-block rounded bg-bg-hover px-1.5 py-0.5 text-[10px] text-text-secondary"
                  >
                    {tag}
                  </span>
                ))}
                {tags.length > 3 && (
                  <span className="text-[10px] text-text-disabled">
                    +{tags.length - 3}
                  </span>
                )}
              </div>
            );
          } catch {
            return (
              <span className="text-xs text-text-disabled">{raw}</span>
            );
          }
        },
        size: 150,
      }),
      columnHelper.accessor('target_fps', {
        header: 'FPS',
        cell: (info) => {
          const fps = info.getValue();
          return (
            <span className={`font-mono-data font-semibold ${fpsColorClass(fps)}`}>
              {fps}
            </span>
          );
        },
        size: 60,
      }),
      columnHelper.accessor('platform', {
        header: 'Platform',
        cell: (info) => (
          <span className="text-xs text-text-secondary">
            {info.getValue()}
          </span>
        ),
        size: 80,
      }),
      columnHelper.display({
        id: 'video',
        header: '',
        cell: ({ row }) =>
          row.original.has_video ? (
            <span title="Has video recording">
              <Video className="h-3.5 w-3.5 text-accent-success" />
            </span>
          ) : null,
        size: 30,
      }),
      columnHelper.display({
        id: 'status',
        header: 'Status',
        cell: ({ row }) =>
          row.original.is_uploaded ? (
            <span className="inline-block rounded bg-accent-success/15 px-2 py-0.5 text-[10px] font-medium text-accent-success">
              Uploaded
            </span>
          ) : (
            <span className="inline-block rounded bg-accent-warning/15 px-2 py-0.5 text-[10px] font-medium text-accent-warning">
              Local
            </span>
          ),
        size: 80,
      }),
    ],
    [],
  );

  const table = useReactTable({
    data: sessions,
    columns,
    state: { rowSelection },
    onRowSelectionChange: setRowSelection,
    getCoreRowModel: getCoreRowModel(),
    getRowId: (row) => row.id,
  });

  const selectedIds = Object.keys(rowSelection);
  const hasSelection = selectedIds.length > 0;

  if (isLoading) {
    return (
      <div className="space-y-2">
        {Array.from({ length: 5 }).map((_, i) => (
          <div
            key={i}
            className="h-10 animate-pulse rounded bg-bg-elevated"
          />
        ))}
      </div>
    );
  }

  if (sessions.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <p className="text-text-secondary">
          No sessions found.
        </p>
        <p className="mt-1 text-sm text-text-disabled">
          Upload your first session from the desktop app.
        </p>
      </div>
    );
  }

  return (
    <div>
      {/* Bulk actions bar */}
      {hasSelection && (
        <div className="mb-2 flex items-center gap-3 rounded border border-accent-blue/30 bg-accent-blue/5 px-3 py-2">
          <span className="text-sm text-text-primary">
            {selectedIds.length} selected
          </span>
          <button
            onClick={() => onDeleteSelected(selectedIds)}
            className="flex items-center gap-1 rounded px-2 py-1 text-xs text-accent-danger hover:bg-accent-danger/10"
          >
            <Trash2 className="h-3 w-3" />
            Delete
          </button>
          <button
            onClick={() => onExportSelected(selectedIds)}
            className="flex items-center gap-1 rounded px-2 py-1 text-xs text-accent-success hover:bg-accent-success/10"
          >
            <Download className="h-3 w-3" />
            Export
          </button>
        </div>
      )}

      {/* Table */}
      <div className="overflow-x-auto rounded-lg border border-border-subtle">
        <table className="w-full">
          <thead>
            {table.getHeaderGroups().map((headerGroup) => (
              <tr
                key={headerGroup.id}
                className="border-b border-border-subtle bg-bg-elevated"
              >
                {headerGroup.headers.map((header) => (
                  <th
                    key={header.id}
                    className="px-3 py-2 text-left text-[10px] font-semibold uppercase tracking-wider text-text-disabled"
                    style={{ width: header.getSize() }}
                  >
                    {flexRender(
                      header.column.columnDef.header,
                      header.getContext(),
                    )}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.map((row) => (
              <tr
                key={row.id}
                onClick={() =>
                  navigate({
                    to: '/sessions/$sessionId',
                    params: { sessionId: row.original.id },
                  })
                }
                className="cursor-pointer border-b border-border-subtle/50 transition-colors hover:bg-bg-hover"
              >
                {row.getVisibleCells().map((cell) => (
                  <td
                    key={cell.id}
                    className="whitespace-nowrap px-3 py-2.5"
                    style={{ width: cell.column.getSize() }}
                  >
                    {flexRender(
                      cell.column.columnDef.cell,
                      cell.getContext(),
                    )}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
