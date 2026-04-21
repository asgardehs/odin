import { useEffect, useState } from 'react';
import { api } from '../../api';
import { formatTimestamp } from '../../utils/date';

interface TableVersion {
  id: number;
  custom_table_id: number;
  change_type: string;
  change_payload: unknown;
  changed_by: string;
  changed_at: string;
}

const CHANGE_COLORS: Record<string, string> = {
  create_table:        'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]',
  add_field:           'bg-[var(--color-fn-cyan)]/15 text-[var(--color-fn-cyan)]',
  add_relation:        'bg-[var(--color-fn-cyan)]/15 text-[var(--color-fn-cyan)]',
  deactivate_field:    'bg-[var(--color-fn-yellow)]/15 text-[var(--color-fn-yellow)]',
  deactivate_relation: 'bg-[var(--color-fn-yellow)]/15 text-[var(--color-fn-yellow)]',
  deactivate_table:    'bg-[var(--color-fn-red)]/15 text-[var(--color-fn-red)]',
  reactivate_table:    'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]',
};

export function VersionHistory({ tableID, refreshKey }: { tableID: number; refreshKey?: number }) {
  const [expanded, setExpanded] = useState(false);
  const [entries, setEntries] = useState<TableVersion[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function toggle() {
    if (expanded) {
      setExpanded(false);
      return;
    }
    setExpanded(true);
    load();
  }

  function load() {
    setLoading(true);
    setError(null);
    api.get<{ versions: TableVersion[] }>(`/api/schema/tables/${tableID}/versions`)
      .then(r => setEntries(r.versions ?? []))
      .catch(e => setError(e instanceof Error ? e.message : 'Failed to load versions'))
      .finally(() => setLoading(false));
  }

  // Re-load whenever the parent asks (e.g. after a schema mutation).
  useLoadOnRefreshKey(expanded, refreshKey, load);

  return (
    <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
      <button
        type="button"
        onClick={toggle}
        className="w-full flex items-center justify-between bg-transparent border-none cursor-pointer p-0 text-left"
      >
        <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider">
          DDL History
          <span className="ml-2 text-[var(--color-comment)] normal-case font-normal tracking-normal">
            from _custom_table_versions
          </span>
        </h2>
        <span className="text-[var(--color-comment)] text-xs">{expanded ? '▾' : '▸'}</span>
      </button>

      {expanded && (
        <div className="mt-4">
          {loading && <p className="text-xs text-[var(--color-comment)]">Loading…</p>}
          {error && (
            <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 text-sm">
              {error}
            </div>
          )}
          {entries && entries.length === 0 && (
            <p className="text-xs text-[var(--color-comment)]">No DDL changes recorded yet.</p>
          )}
          {entries && entries.length > 0 && (
            <ol className="flex flex-col gap-3">
              {entries.map(v => {
                const tone = CHANGE_COLORS[v.change_type] ?? 'bg-[var(--color-bg-lighter)] text-[var(--color-fg)]';
                const payload = v.change_payload && typeof v.change_payload === 'object'
                  ? v.change_payload as Record<string, unknown>
                  : null;
                const summary = summarizeChange(v.change_type, payload);
                return (
                  <li
                    key={v.id}
                    className="flex gap-3 pb-3 border-b border-[var(--color-current-line)] last:border-b-0 last:pb-0"
                  >
                    <span className={`inline-flex items-center h-6 px-2 rounded-md text-[10px] font-semibold uppercase tracking-wider shrink-0 ${tone}`}>
                      {v.change_type.replace(/_/g, ' ')}
                    </span>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-[var(--color-fg)]">{summary}</p>
                      <p className="text-xs text-[var(--color-comment)] mt-0.5">
                        by <span className="text-[var(--color-fg)]">{v.changed_by}</span>
                        {' · '}
                        {formatTimestamp(v.changed_at)}
                      </p>
                    </div>
                  </li>
                );
              })}
            </ol>
          )}
        </div>
      )}
    </div>
  );
}

function summarizeChange(changeType: string, p: Record<string, unknown> | null): string {
  if (!p) return changeType.replace(/_/g, ' ');
  switch (changeType) {
    case 'create_table':
      return `Created ${String(p.name ?? '?')} (${String(p.physical ?? '?')})`;
    case 'add_field':
      return `Added field ${String(p.name ?? '?')} (${String(p.field_type ?? '?')})${p.is_required ? ' [required]' : ''}`;
    case 'deactivate_field':
      return `Deactivated field ${String(p.name ?? `#${p.field_id}`)}`;
    case 'add_relation':
      return `Added relation → ${String(p.target_table_name ?? '?')} (${String(p.display_field ?? '?')})`;
    case 'deactivate_relation':
      return `Deactivated relation #${String(p.relation_id ?? '?')}`;
    case 'deactivate_table':
      return `Deactivated table ${String(p.name ?? '?')}`;
    case 'reactivate_table':
      return `Reactivated table ${String(p.name ?? '?')}`;
    default:
      return changeType.replace(/_/g, ' ');
  }
}

// Lightweight effect to reload when refreshKey bumps. Split out to
// keep the main body readable and to colocate the side-effect rule.
function useLoadOnRefreshKey(expanded: boolean, key: number | undefined, load: () => void) {
  useEffect(() => {
    if (!expanded || key == null) return;
    load();
    // Intentionally depend only on key — load is recreated each render
    // but we only want to trigger on refreshKey bumps after expansion.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, expanded]);
}
