import { useCallback, useEffect, useState } from 'react';
import { api } from '../api';
import type { CustomTable } from './useCustomTableSchema';

interface TablesResponse { tables: CustomTable[] }

/**
 * Event dispatched by admin pages after any schema mutation so the
 * sidebar (and anything else that renders the active-table list)
 * can refetch.
 */
export const SCHEMA_CHANGED_EVENT = 'odin:schema-changed';

/**
 * Convenience: call this after a successful schema mutation to tell
 * the sidebar (and any other listeners) to refetch.
 */
export function notifySchemaChanged(): void {
  window.dispatchEvent(new Event(SCHEMA_CHANGED_EVENT));
}

/**
 * Fetches the active custom tables for the sidebar "Custom Tables"
 * group. Uses `/api/schema/tables?active=1` which is admin-only —
 * non-admin users get an empty list (swallowed 403) so the group
 * simply doesn't render for them.
 *
 * Refetches whenever another part of the app dispatches
 * `odin:schema-changed` (table created, deactivated, reactivated,
 * etc.).
 */
export function useCustomTablesList(enabled: boolean): CustomTable[] {
  const [tables, setTables] = useState<CustomTable[]>([]);

  const load = useCallback(() => {
    if (!enabled) {
      setTables([]);
      return;
    }
    api.get<TablesResponse>('/api/schema/tables?active=1')
      .then(r => setTables(r.tables ?? []))
      .catch(() => setTables([])); // non-admin / error → empty
  }, [enabled]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    load();
    const handler = () => load();
    window.addEventListener(SCHEMA_CHANGED_EVENT, handler);
    return () => window.removeEventListener(SCHEMA_CHANGED_EVENT, handler);
  }, [load]);

  return tables;
}
