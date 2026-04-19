import { useEffect, useRef, useState } from 'react';
import { api } from '../../api';

interface PagedResult<T> {
  data: T[];
  total: number;
}

type Row = Record<string, unknown> & { id: number };

interface EntitySelectorProps {
  /** API path segment, e.g. "employees" for /api/employees. */
  entity: string;
  /** Currently selected id, or null/undefined for unselected. */
  value: number | null | undefined;
  onChange: (id: number | null, row: Row | null) => void;
  /** Render a row into its display label. */
  renderLabel: (row: Row) => string;
  placeholder?: string;
  required?: boolean;
  disabled?: boolean;
  /** Extra query params (e.g. "&is_active=1"). */
  extraQuery?: string;
  /** Max rows to show per search. Default 10. */
  pageSize?: number;
}

export function EntitySelector({
  entity,
  value,
  onChange,
  renderLabel,
  placeholder = 'Select...',
  required,
  disabled,
  extraQuery = '',
  pageSize = 10,
}: EntitySelectorProps) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<Row | null>(null);
  const rootRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Resolve the selected id to a display row when value changes from outside.
  useEffect(() => {
    if (value == null) {
      setSelected(null);
      return;
    }
    if (selected?.id === value) return;
    api.get<Row>(`/api/${entity}/${value}`)
      .then(setSelected)
      .catch(() => setSelected(null));
  }, [entity, value, selected?.id]);

  // Debounced search while open.
  useEffect(() => {
    if (!open) return;
    const controller = new AbortController();
    const t = setTimeout(() => {
      setLoading(true);
      const q = query.trim();
      const url = `/api/${entity}?per_page=${pageSize}${q ? `&q=${encodeURIComponent(q)}` : ''}${extraQuery}`;
      api.get<PagedResult<Row>>(url)
        .then(r => {
          if (!controller.signal.aborted) setRows(r.data ?? []);
        })
        .catch(() => {
          if (!controller.signal.aborted) setRows([]);
        })
        .finally(() => {
          if (!controller.signal.aborted) setLoading(false);
        });
    }, 200);
    return () => {
      controller.abort();
      clearTimeout(t);
    };
  }, [open, query, entity, extraQuery, pageSize]);

  // Close on outside click.
  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    window.addEventListener('mousedown', handler);
    return () => window.removeEventListener('mousedown', handler);
  }, [open]);

  const openPopup = () => {
    if (disabled) return;
    setOpen(true);
    setTimeout(() => inputRef.current?.focus(), 0);
  };

  const pick = (row: Row) => {
    setSelected(row);
    onChange(row.id, row);
    setOpen(false);
    setQuery('');
  };

  const clear = () => {
    setSelected(null);
    onChange(null, null);
  };

  return (
    <div ref={rootRef} className="relative">
      <div
        onClick={openPopup}
        className={`w-full h-10 px-3 flex items-center justify-between rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm transition-colors ${
          disabled
            ? 'opacity-50 cursor-not-allowed'
            : 'cursor-pointer hover:border-[var(--color-selection)]'
        } ${open ? 'border-[var(--color-fn-purple)]' : ''}`}
      >
        <span className={selected ? '' : 'text-[var(--color-comment)]'}>
          {selected ? renderLabel(selected) : placeholder}
        </span>
        <div className="flex items-center gap-2">
          {selected && !disabled && !required && (
            <button
              type="button"
              onClick={e => {
                e.stopPropagation();
                clear();
              }}
              className="text-[var(--color-comment)] hover:text-[var(--color-fg)] cursor-pointer text-xs"
              aria-label="Clear"
            >
              ✕
            </button>
          )}
          <span className="text-[var(--color-comment)] text-xs">▾</span>
        </div>
      </div>

      {open && (
        <div className="absolute z-30 mt-1 w-full rounded-lg bg-[var(--color-bg-light)] border border-[var(--color-current-line)] shadow-xl overflow-hidden">
          <input
            ref={inputRef}
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Search..."
            className="w-full h-10 px-3 bg-[var(--color-bg)] border-b border-[var(--color-current-line)] text-[var(--color-fg)] text-sm outline-none placeholder:text-[var(--color-comment)]"
          />
          <ul className="max-h-64 overflow-y-auto">
            {loading && (
              <li className="px-3 py-2 text-xs text-[var(--color-comment)]">Loading...</li>
            )}
            {!loading && rows.length === 0 && (
              <li className="px-3 py-2 text-xs text-[var(--color-comment)]">No matches</li>
            )}
            {!loading && rows.map(row => (
              <li
                key={row.id}
                onClick={() => pick(row)}
                className={`px-3 py-2 text-sm cursor-pointer hover:bg-[var(--color-bg-lighter)] ${
                  row.id === value ? 'bg-[var(--color-bg-lighter)] text-[var(--color-fn-purple)]' : 'text-[var(--color-fg)]'
                }`}
              >
                {renderLabel(row)}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
