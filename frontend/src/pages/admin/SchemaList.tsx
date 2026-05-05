import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { api } from '../../api';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { notifySchemaChanged } from '../../hooks/useCustomTablesList';
import type { CustomTable } from '../../hooks/useCustomTableSchema';

interface TablesResponse { tables: CustomTable[] }

export default function SchemaList() {
  const navigate = useNavigate();
  const [tables, setTables] = useState<CustomTable[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const { mutate, loading: mutating } = useEntityMutation();

  const load = useCallback(() => {
    api.get<TablesResponse>('/api/schema/tables')
      .then(r => setTables(r.tables ?? []))
      .catch(e => setError(e instanceof Error ? e.message : 'Failed to load tables'));
  }, []);

  useEffect(() => { load(); }, [load]);

  async function reactivate(id: number) {
    try {
      await mutate('POST', `/api/schema/tables/${id}/reactivate`);
      notifySchemaChanged();
      load();
    } catch {
      // mutate surfaces error
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">Custom Table Builder</h1>
          <p className="text-sm text-[var(--color-comment)] mt-1">
            Admin-built tables rendered by the generic record UI. Deactivated tables keep their data
            but are hidden from the sidebar and non-admin UI.
          </p>
        </div>
        <button
          type="button"
          onClick={() => navigate('/admin/schema/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New table
        </button>
      </div>

      {error && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {error}
        </div>
      )}

      <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] overflow-x-auto">
        <table className="w-full text-sm text-left">
          <thead>
            <tr className="border-b border-[var(--color-current-line)] bg-[var(--color-bg-dark)]">
              <th className="px-4 py-3 font-medium text-[var(--color-fg)]">Name</th>
              <th className="px-4 py-3 font-medium text-[var(--color-fg)]">Physical</th>
              <th className="px-4 py-3 font-medium text-[var(--color-fg)]">Description</th>
              <th className="px-4 py-3 font-medium text-[var(--color-fg)]">Status</th>
              <th className="px-4 py-3 font-medium text-[var(--color-fg)] text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {tables == null && (
              <tr><td colSpan={5} className="px-4 py-6 text-center text-[var(--color-comment)]">Loading…</td></tr>
            )}
            {tables && tables.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-[var(--color-comment)]">
                  No custom tables yet — start with <span className="text-[var(--color-fn-purple)]">+ New table</span>.
                </td>
              </tr>
            )}
            {tables && tables.map(t => (
              <tr
                key={t.id}
                className="border-b border-[var(--color-current-line)] last:border-b-0 hover:bg-[var(--color-bg-lighter)] transition-colors"
              >
                <td className="px-4 py-3">
                  <button
                    type="button"
                    onClick={() => navigate(`/admin/schema/${t.id}`)}
                    className="text-[var(--color-fg)] hover:text-[var(--color-fn-purple)] bg-transparent border-none p-0 cursor-pointer text-left"
                  >
                    {t.display_name}
                  </button>
                </td>
                <td className="px-4 py-3 font-mono text-xs text-[var(--color-comment)]">cx_{t.name}</td>
                <td className="px-4 py-3 text-[var(--color-fg)]">
                  {t.description || <span className="text-[var(--color-comment)]">—</span>}
                </td>
                <td className="px-4 py-3">
                  <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                    t.is_active
                      ? 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]'
                      : 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
                  }`}>
                    {t.is_active ? 'Active' : 'Deactivated'}
                  </span>
                </td>
                <td className="px-4 py-3 text-right">
                  <div className="flex items-center justify-end gap-2">
                    <button
                      type="button"
                      onClick={() => navigate(`/admin/schema/${t.id}`)}
                      className="h-8 px-3 rounded-md bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
                    >
                      Open designer
                    </button>
                    {!t.is_active && (
                      <button
                        type="button"
                        disabled={mutating}
                        onClick={() => reactivate(t.id)}
                        className="h-8 px-3 rounded-md bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50"
                      >
                        Reactivate
                      </button>
                    )}
                    {t.is_active && (
                      <button
                        type="button"
                        onClick={() => navigate(`/custom/${t.name}`)}
                        className="h-8 px-3 rounded-md bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
                      >
                        Open records
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
