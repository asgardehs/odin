import { useState, useEffect } from 'react';
import {
  useReactTable,
  getCoreRowModel,
  flexRender,
  type ColumnDef,
} from '@tanstack/react-table';
import { apiFetch } from '../api';

/** A row from the backend's map[string]any serialized as JSON. */
export type Row = Record<string, unknown>;

interface PagedResult {
  data: Row[];
  total: number;
  page: number;
  per_page: number;
  total_pages: number;
}

interface DataTableProps {
  columns: ColumnDef<Row>[];
  apiUrl: string;
  onRowClick?: (row: Row) => void;
  /** Optional client-side transform applied to rows after fetch.
   *  Use for filter views that can't be expressed server-side
   *  (e.g. filtering permits by category via a FK join). */
  transformRows?: (rows: Row[]) => Row[];
}

const PER_PAGE = 50;

/** Reusable paginated data table backed by any PagedResult API endpoint. */
export function DataTable({ columns, apiUrl, onRowClick, transformRows }: DataTableProps) {
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<PagedResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    setError(null);
    const sep = apiUrl.includes('?') ? '&' : '?';
    apiFetch(`${apiUrl}${sep}page=${page}&per_page=${PER_PAGE}`)
      .then(async res => {
        if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
        return res.json() as Promise<PagedResult>;
      })
      .then(setResult)
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false));
  }, [apiUrl, page]);

  const rawRows = result?.data ?? [];
  const rows = transformRows ? transformRows(rawRows) : rawRows;

  // eslint-disable-next-line react-hooks/incompatible-library -- React Compiler not configured in this project
  const table = useReactTable({
    data: rows,
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  const totalPages = result?.total_pages ?? 0;
  const total = result?.total ?? 0;

  return (
    <div>
      {error && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          Failed to load: {error}
        </div>
      )}

      <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] overflow-x-auto">
        <table className="w-full text-sm text-left">
          <thead>
            {table.getHeaderGroups().map(headerGroup => (
              <tr
                key={headerGroup.id}
                className="border-b border-[var(--color-current-line)] bg-[var(--color-bg-dark)]"
              >
                {headerGroup.headers.map(header => (
                  <th
                    key={header.id}
                    className="px-4 py-3 font-medium text-[var(--color-fg)] whitespace-nowrap"
                  >
                    {header.isPlaceholder
                      ? null
                      : flexRender(header.column.columnDef.header, header.getContext())}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {loading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <tr key={i} className="border-b border-[var(--color-current-line)]/50">
                  {columns.map((_, j) => (
                    <td key={j} className="px-4 py-3">
                      <div className="h-4 rounded bg-[var(--color-current-line)] animate-pulse" />
                    </td>
                  ))}
                </tr>
              ))
            ) : rows.length === 0 ? (
              <tr>
                <td
                  colSpan={columns.length}
                  className="px-4 py-12 text-center text-[var(--color-comment)]"
                >
                  <div className="flex flex-col items-center gap-2">
                    <span className="text-2xl">□</span>
                    <span>No records found</span>
                  </div>
                </td>
              </tr>
            ) : (
              table.getRowModel().rows.map((row, idx) => (
                <tr
                  key={row.id}
                  onClick={() => onRowClick?.(row.original)}
                  className={[
                    idx < rows.length - 1 ? 'border-b border-[var(--color-current-line)]/50' : '',
                    onRowClick
                      ? 'cursor-pointer hover:bg-[var(--color-bg-lighter)] transition-colors'
                      : '',
                  ]
                    .filter(Boolean)
                    .join(' ')}
                >
                  {row.getVisibleCells().map(cell => (
                    <td
                      key={cell.id}
                      className="px-4 py-3 text-[var(--color-fg)] whitespace-nowrap"
                    >
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination — only shown when there is more than one page */}
      <div className="flex items-center justify-between mt-4 text-sm">
        <span className="text-[var(--color-comment)]">
          {loading ? '\u00A0' : `${total.toLocaleString()} total`}
        </span>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setPage(p => Math.max(1, p - 1))}
            disabled={page <= 1 || loading}
            className="px-3 py-1.5 rounded-lg border border-[var(--color-current-line)] text-[var(--color-fg)] hover:text-[var(--color-fg)] hover:border-[var(--color-selection)] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            ← Prev
          </button>
          <span className="text-[var(--color-fg)] px-2">
            {loading ? '…' : `Page ${page} of ${totalPages || 1}`}
          </span>
          <button
            onClick={() => setPage(p => Math.min(totalPages, p + 1))}
            disabled={page >= totalPages || loading}
            className="px-3 py-1.5 rounded-lg border border-[var(--color-current-line)] text-[var(--color-fg)] hover:text-[var(--color-fg)] hover:border-[var(--color-selection)] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            Next →
          </button>
        </div>
      </div>
    </div>
  );
}
