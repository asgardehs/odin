import { useMemo } from 'react';
import { useNavigate, useParams } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';
import {
  useCustomTableSchema,
  activeFields,
  type CustomField,
} from '../../hooks/useCustomTableSchema';
import { formatDate, formatTimestamp, looksLikeDate, looksLikeTimestamp } from '../../utils/date';

const MAX_COLUMNS = 5;

/** Render a single cell for a custom field based on its field_type. */
function renderCell(field: CustomField, row: Row): React.ReactNode {
  // Relation fields surface the joined display_field via the
  // `{name}__label` alias emitted by the backend query builder.
  if (field.field_type === 'relation') {
    const label = row[`${field.name}__label`];
    return label == null || label === '' ? '—' : String(label);
  }
  const v = row[field.name];
  if (v == null || v === '') return '—';
  switch (field.field_type) {
    case 'boolean':
      return Number(v) ? 'Yes' : 'No';
    case 'datetime':
      return looksLikeTimestamp(v) ? formatTimestamp(v as string) : String(v);
    case 'date':
      return looksLikeDate(v) ? formatDate(v as string) : String(v);
    default:
      return String(v);
  }
}

export default function GenericRecordList() {
  const { slug = '' } = useParams<{ slug: string }>();
  const navigate = useNavigate();
  const { data: schema, loading, error } = useCustomTableSchema(slug);

  const columns = useMemo<ColumnDef<Row>[]>(() => {
    if (!schema) return [];
    return activeFields(schema)
      .slice(0, MAX_COLUMNS)
      .map(f => ({
        accessorKey: f.name,
        header: f.display_name,
        cell: ({ row }) => renderCell(f, row.original),
      }));
  }, [schema]);

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">
        Loading…
      </div>
    );
  }
  if (error || !schema) {
    const notFound = error?.startsWith('404');
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-comment)]">
        <p className="text-sm">{notFound ? 'Custom table not found.' : `Error: ${error}`}</p>
      </div>
    );
  }

  // Make the relation-label column use __label if the backend supplies
  // it (query builder emits `{name}__label` aliases for relations).
  // We rely on renderCell above to read the alias; the accessorKey on
  // the column is still the field name, which keeps the column
  // distinct from system columns.

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">{schema.display_name}</h1>
          {schema.description && (
            <p className="text-sm text-[var(--color-comment)] mt-1">{schema.description}</p>
          )}
        </div>
        <button
          type="button"
          onClick={() => navigate(`/custom/${slug}/new`)}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New {schema.display_name}
        </button>
      </div>

      <DataTable
        columns={columns}
        apiUrl={`/api/records/${encodeURIComponent(slug)}`}
        onRowClick={(row) => navigate(`/custom/${slug}/${row.id}`)}
      />
    </div>
  );
}
