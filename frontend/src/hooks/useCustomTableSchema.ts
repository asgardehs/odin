import { useEffect, useState } from 'react';
import { api } from '../api';

export type FieldType =
  | 'text' | 'number' | 'decimal' | 'date'
  | 'datetime' | 'boolean' | 'select' | 'relation';

export interface CustomField {
  id: number;
  custom_table_id: number;
  name: string;
  display_name: string;
  field_type: FieldType;
  is_required: boolean;
  default_value?: string | null;
  config?: unknown;
  display_order: number;
  is_active: boolean;
}

export interface CustomRelation {
  id: number;
  source_table_id: number;
  source_field_id: number;
  target_table_name: string;
  display_field: string;
  relation_type: string;
  is_active: boolean;
}

export type ParentModule = 'none' | 'facilities' | 'employees' | 'inspections';

export interface CustomTable {
  id: number;
  name: string;
  display_name: string;
  description?: string | null;
  icon?: string | null;
  display_order: number;
  is_active: boolean;
  parent_module: ParentModule;
  created_at: string;
  updated_at: string;
  fields: CustomField[];
  relations: CustomRelation[];
}

/**
 * Fetches the active custom table's metadata by slug. The endpoint
 * `/api/records/:slug/_schema` is intentionally accessible to any
 * authed user so the generic record UI can render without admin
 * rights; admin-only schema management lives under /api/schema/*.
 */
export function useCustomTableSchema(slug: string | undefined) {
  const [data, setData] = useState<CustomTable | null>(null);
  const [loading, setLoading] = useState<boolean>(Boolean(slug));
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!slug) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setData(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    api.get<CustomTable>(`/api/records/${encodeURIComponent(slug)}/_schema`)
      .then(setData)
      .catch(e => setError(e instanceof Error ? e.message : 'Failed to load schema'))
      .finally(() => setLoading(false));
  }, [slug]);

  return { data, loading, error };
}

/**
 * Active fields sorted by display_order then id. The server already
 * orders them this way, but front-end code that mutates the array
 * (e.g. the designer) should call this to re-normalize.
 */
export function activeFields(t: CustomTable | null | undefined): CustomField[] {
  if (!t) return [];
  return [...t.fields]
    .filter(f => f.is_active)
    .sort((a, b) => a.display_order - b.display_order || a.id - b.id);
}

/**
 * Map a field to its active relation metadata (if any).
 */
export function relationFor(
  t: CustomTable | null | undefined,
  field: CustomField
): CustomRelation | null {
  if (!t || field.field_type !== 'relation') return null;
  return t.relations.find(r => r.is_active && r.source_field_id === field.id) ?? null;
}

/**
 * The API slug for a relation target. Pre-built tables use their
 * bare name (`employees` → `/api/employees/...`); custom tables use
 * the `records/{slug}` path (`/api/records/{slug}/...`).
 */
export function relationEntityPath(r: CustomRelation): string {
  if (r.target_table_name.startsWith('cx_')) {
    return `records/${r.target_table_name.slice(3)}`;
  }
  return r.target_table_name;
}
