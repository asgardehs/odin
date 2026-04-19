import { useState } from 'react';
import { api } from '../api';
import { useAuth } from '../context/AuthContext';
import { formatTimestamp } from '../utils/date';

interface AuditEntry {
  timestamp: string;
  action: string;
  module: string;
  entity_id: string;
  user: string;
  summary: string;
  before?: unknown;
  after?: unknown;
  commit_hash: string;
  commit_time: string;
}

const actionToneClasses: Record<string, string> = {
  create: 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]',
  update: 'bg-[var(--color-fn-cyan)]/15 text-[var(--color-fn-cyan)]',
  delete: 'bg-[var(--color-fn-red)]/15 text-[var(--color-fn-red)]',
  read:   'bg-[var(--color-bg-lighter)] text-[var(--color-comment)]',
};

interface Props {
  module: string;
  entityId: string | number | null | undefined;
}

/**
 * Admin-only Activity section showing the git-backed audit trail for
 * one entity. Renders nothing when the current user isn't admin or
 * when entityId isn't known yet. Uses the session-auth'd endpoint
 * /api/admin/audit/{module}/{id} — not the Basic-Auth compliance path.
 */
export function AuditHistory({ module, entityId }: Props) {
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const [expanded, setExpanded] = useState(false);
  const [entries, setEntries] = useState<AuditEntry[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isAdmin) return null;
  if (entityId == null) return null;

  function toggle() {
    if (expanded) {
      setExpanded(false);
      return;
    }
    setExpanded(true);
    if (entries !== null) return; // already loaded
    setLoading(true);
    setError(null);
    api.get<AuditEntry[]>(`/api/admin/audit/${module}/${entityId}`)
      .then(setEntries)
      .catch(e => setError(e instanceof Error ? e.message : 'Failed to load audit history'))
      .finally(() => setLoading(false));
  }

  return (
    <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
      <button
        type="button"
        onClick={toggle}
        className="w-full flex items-center justify-between bg-transparent border-none cursor-pointer p-0 text-left"
      >
        <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider">
          Activity
          <span className="ml-2 text-[var(--color-comment)] normal-case font-normal tracking-normal">
            admin-only
          </span>
        </h2>
        <span className="text-[var(--color-comment)] text-xs">
          {expanded ? '▾' : '▸'}
        </span>
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
            <p className="text-xs text-[var(--color-comment)]">No audit entries recorded for this record.</p>
          )}
          {entries && entries.length > 0 && (
            <ol className="flex flex-col gap-3">
              {entries.map((e, i) => (
                <li
                  key={e.commit_hash + ':' + i}
                  className="flex gap-3 pb-3 border-b border-[var(--color-current-line)] last:border-b-0 last:pb-0"
                >
                  <span className={`inline-flex items-center h-6 px-2 rounded-md text-[10px] font-semibold uppercase tracking-wider shrink-0 ${actionToneClasses[e.action] ?? 'bg-[var(--color-bg-lighter)] text-[var(--color-fg)]'}`}>
                    {e.action}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-[var(--color-fg)]">{e.summary}</p>
                    <p className="text-xs text-[var(--color-comment)] mt-0.5">
                      by <span className="text-[var(--color-fg)]">{e.user}</span>
                      {' · '}
                      {formatTimestamp(e.timestamp)}
                      {' · '}
                      <span className="font-mono" title={e.commit_hash}>
                        {e.commit_hash.slice(0, 7)}
                      </span>
                    </p>
                  </div>
                </li>
              ))}
            </ol>
          )}
        </div>
      )}
    </div>
  );
}
