import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { AuditHistory } from '../../components/AuditHistory';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import {
  useCustomTableSchema,
  activeFields,
  relationFor,
} from '../../hooks/useCustomTableSchema';

type RecordRow = Record<string, unknown>;

/** Resolve the display value for a field, preferring a joined
 * relation label over the raw FK id when available. */
function fieldValue(fieldName: string, fieldType: string, row: RecordRow): unknown {
  if (fieldType === 'relation') {
    const label = row[`${fieldName}__label`];
    if (label != null && label !== '') return label;
  }
  return row[fieldName];
}

export default function GenericRecordDetail() {
  const { slug = '', id } = useParams<{ slug: string; id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';

  const { data: schema, loading: schemaLoading, error: schemaError } = useCustomTableSchema(slug);
  const { data, loading, error } = useApi<RecordRow>(`/api/records/${encodeURIComponent(slug)}/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirmDelete, setConfirmDelete] = useState(false);

  async function runDelete() {
    if (!id) return;
    try {
      await mutate('DELETE', `/api/records/${encodeURIComponent(slug)}/${id}`);
      navigate(`/custom/${slug}`);
    } catch {
      // mutateError surfaces
    }
  }

  if (schemaLoading || loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">
        Loading…
      </div>
    );
  }
  if (schemaError || !schema) {
    const notFound = schemaError?.startsWith('404');
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-comment)]">
        <p className="text-sm">{notFound ? 'Custom table not found.' : `Error: ${schemaError}`}</p>
      </div>
    );
  }
  if (error || !data) {
    const notFound = error?.startsWith('404');
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-comment)]">
        <p className="text-sm">{notFound ? 'Record not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate(`/custom/${slug}`)} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to {schema.display_name}
        </button>
      </div>
    );
  }

  const fields = activeFields(schema);
  const module = `cx_${schema.name}`;

  // Build a readable title — prefer the first text field's value if
  // there is one, otherwise fall back to "#{id}".
  const firstText = fields.find(f => f.field_type === 'text');
  const titleValue = firstText ? data[firstText.name] : null;
  const title = titleValue ? String(titleValue) : `#${id}`;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6 flex-wrap">
        <button
          onClick={() => navigate(`/custom/${slug}`)}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← {schema.display_name}
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">{title}</h1>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/custom/${slug}/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {isAdmin && (
            <button
              type="button"
              onClick={() => setConfirmDelete(true)}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fn-red)] text-xs cursor-pointer hover:border-[var(--color-fn-red)]/50 transition-colors"
            >
              Delete
            </button>
          )}
        </div>
      </div>

      {mutateError && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {mutateError}
        </div>
      )}

      <div className="flex flex-col gap-4">
        <Section title={schema.display_name}>
          <Field label="Facility ID" value={data.establishment_id} />
          {fields.map(f => {
            const rel = relationFor(schema, f);
            const labelSuffix = rel ? ` — ${rel.display_field}` : '';
            return (
              <Field
                key={f.id}
                label={f.display_name + (rel ? labelSuffix : '')}
                value={fieldValue(f.name, f.field_type, data)}
              />
            );
          })}
        </Section>

        <Section title="Record">
          <Field label="ID" value={data.id} />
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module={module} entityId={id} />
      </div>

      {confirmDelete && (
        <ConfirmDialog
          open
          title="Delete record?"
          message="Permanently deletes this record. The audit trail keeps the history of what was here."
          confirmLabel="Delete"
          destructive
          loading={mutating}
          onConfirm={runDelete}
          onCancel={() => setConfirmDelete(false)}
        />
      )}
    </div>
  );
}
