import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';
import {
  useCustomTableSchema,
  activeFields,
  relationFor,
  relationEntityPath,
  type CustomField,
  type CustomRelation,
} from '../../hooks/useCustomTableSchema';

// ============================================================
// Per-field-type config shapes (best-effort; config is free-form JSON)
// ============================================================

interface TextConfig { multiline?: boolean; max_length?: number }
interface SelectConfig { options?: (string | { value: string; label?: string })[] }

function parseConfig<T = unknown>(raw: unknown): T | null {
  if (raw == null) return null;
  if (typeof raw === 'object') return raw as T;
  if (typeof raw === 'string' && raw.trim() !== '') {
    try { return JSON.parse(raw) as T; } catch { return null; }
  }
  return null;
}

// ============================================================
// Value shaping
// ============================================================

type FormState = Record<string, unknown>;

/**
 * Seed a form state for each active field. Uses the default_value
 * where provided, otherwise a type-appropriate empty.
 */
function emptyState(fields: CustomField[]): FormState {
  const state: FormState = { establishment_id: null };
  for (const f of fields) {
    switch (f.field_type) {
      case 'boolean':
        state[f.name] = f.default_value === '1' || f.default_value === 'true';
        break;
      case 'number':
      case 'decimal':
      case 'relation':
        state[f.name] = null;
        break;
      default:
        state[f.name] = f.default_value ?? '';
    }
  }
  return state;
}

/** Convert a form value into the JSON value the backend expects. */
function shapeValue(field: CustomField, raw: unknown): unknown {
  if (raw == null) return null;
  switch (field.field_type) {
    case 'number':
    case 'decimal': {
      if (typeof raw === 'number') return raw;
      const s = String(raw).trim();
      if (s === '') return null;
      const n = field.field_type === 'number' ? parseInt(s, 10) : parseFloat(s);
      return Number.isNaN(n) ? null : n;
    }
    case 'boolean':
      return raw ? 1 : 0;
    case 'relation':
      return typeof raw === 'number' ? raw : (raw === '' || raw == null) ? null : Number(raw);
    default: {
      const s = typeof raw === 'string' ? raw : String(raw);
      return s.trim() === '' ? null : s;
    }
  }
}

function buildPayload(fields: CustomField[], state: FormState): Record<string, unknown> {
  const body: Record<string, unknown> = {};
  if (state.establishment_id != null) body.establishment_id = state.establishment_id;
  for (const f of fields) {
    body[f.name] = shapeValue(f, state[f.name]);
  }
  return body;
}

// ============================================================
// Individual field renderer
// ============================================================

function FieldInput({
  field, relation, value, onChange,
}: {
  field: CustomField;
  relation: CustomRelation | null;
  value: unknown;
  onChange: (v: unknown) => void;
}) {
  const label = field.display_name;

  switch (field.field_type) {
    case 'text': {
      const cfg = parseConfig<TextConfig>(field.config);
      if (cfg?.multiline) {
        return (
          <FormField
            type="textarea"
            label={label}
            required={field.is_required}
            value={String(value ?? '')}
            onChange={onChange}
            rows={3}
          />
        );
      }
      return (
        <FormField
          label={label}
          required={field.is_required}
          value={String(value ?? '')}
          onChange={onChange}
        />
      );
    }
    case 'number':
    case 'decimal':
      return (
        <FormField
          type="number"
          label={label}
          required={field.is_required}
          value={value == null ? '' : String(value)}
          onChange={onChange}
        />
      );
    case 'date':
      return (
        <FormField
          type="date"
          label={label}
          required={field.is_required}
          value={String(value ?? '')}
          onChange={onChange}
        />
      );
    case 'datetime':
      // Native datetime-local is not a declared type on FormField;
      // fall through to plain text for MVP — ISO 8601 works.
      return (
        <FormField
          label={label}
          required={field.is_required}
          value={String(value ?? '')}
          onChange={onChange}
          placeholder="YYYY-MM-DDTHH:MM:SSZ"
        />
      );
    case 'boolean':
      return (
        <FormField
          type="checkbox"
          label={label}
          value={Boolean(value)}
          onChange={onChange}
        />
      );
    case 'select': {
      const cfg = parseConfig<SelectConfig>(field.config);
      const options = (cfg?.options ?? []).map(o =>
        typeof o === 'string' ? { value: o, label: o } : { value: o.value, label: o.label ?? o.value },
      );
      return (
        <FormField
          type="select"
          label={label}
          required={field.is_required}
          value={String(value ?? '')}
          onChange={onChange}
          options={options}
          placeholder="— not set —"
        />
      );
    }
    case 'relation': {
      if (!relation) {
        return (
          <FormField
            type="number"
            label={`${label} (id)`}
            value={value == null ? '' : String(value)}
            onChange={onChange}
            hint="No relation metadata — enter the target row id directly."
          />
        );
      }
      const numericValue = typeof value === 'number' ? value : (value == null || value === '' ? null : Number(value));
      return (
        <div className="flex flex-col gap-1.5">
          <label className="text-xs text-[var(--color-fg)]">
            {label}{field.is_required && <span className="text-[var(--color-fn-red)] ml-0.5">*</span>}
          </label>
          <EntitySelector
            entity={relationEntityPath(relation)}
            value={numericValue}
            onChange={id => onChange(id)}
            renderLabel={row => String(row[relation.display_field] ?? `#${row.id}`)}
            placeholder={`Pick a ${relation.target_table_name.replace(/^cx_/, '')}...`}
            required={field.is_required}
          />
        </div>
      );
    }
  }
}

// ============================================================
// Top-level form
// ============================================================

export default function GenericRecordForm() {
  const { slug = '', id } = useParams<{ slug: string; id?: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const { data: schema, loading: schemaLoading, error: schemaError } = useCustomTableSchema(slug);
  const fields = useMemo(() => activeFields(schema), [schema]);

  const [form, setForm] = useState<FormState>({});
  const [initialized, setInitialized] = useState(false);
  const [recordLoading, setRecordLoading] = useState(isEdit);
  const [recordError, setRecordError] = useState<string | null>(null);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  // Initialize blank form once the schema is loaded.
  useEffect(() => {
    if (!schema || initialized) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setForm(emptyState(fields));
    setInitialized(true);
  }, [schema, fields, initialized]);

  // Load existing record when editing.
  useEffect(() => {
    if (!isEdit || !schema || !initialized) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setRecordLoading(true);
    api.get<Record<string, unknown>>(`/api/records/${encodeURIComponent(slug)}/${id}`)
      .then(row => {
        const seeded: FormState = { establishment_id: (row.establishment_id as number) ?? null };
        for (const f of fields) {
          const v = row[f.name];
          if (f.field_type === 'boolean') {
            seeded[f.name] = Boolean(v);
          } else if (f.field_type === 'number' || f.field_type === 'decimal') {
            seeded[f.name] = v == null ? '' : String(v);
          } else if (f.field_type === 'relation') {
            seeded[f.name] = typeof v === 'number' ? v : (v == null ? null : Number(v));
          } else {
            seeded[f.name] = v ?? '';
          }
        }
        setForm(seeded);
      })
      .catch(e => setRecordError(e instanceof Error ? e.message : 'Failed to load record'))
      .finally(() => setRecordLoading(false));
  }, [isEdit, schema, initialized, slug, id, fields]);

  const update = (key: string, value: unknown) => {
    setForm(prev => ({ ...prev, [key]: value }));
    setDirty(true);
    setValidationError(null);
  };

  async function submit(e: React.FormEvent, continueAfter: boolean) {
    e.preventDefault();
    // Required-field check.
    for (const f of fields) {
      if (!f.is_required) continue;
      const shaped = shapeValue(f, form[f.name]);
      if (shaped == null || shaped === '') {
        setValidationError(`${f.display_name} is required.`);
        return;
      }
    }
    const body = buildPayload(fields, form);
    try {
      if (isEdit) {
        await mutate('PUT', `/api/records/${encodeURIComponent(slug)}/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', `/api/records/${encodeURIComponent(slug)}`, body);
        if (continueAfter) {
          setForm(emptyState(fields));
          setDirty(false);
          return;
        }
        navigate(`/custom/${slug}/${res.id}`);
        return;
      }
      setDirty(false);
      navigate(`/custom/${slug}/${id}`);
    } catch {
      // saveError surfaces
    }
  }

  if (schemaLoading || (isEdit && recordLoading)) {
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
  if (recordError) {
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-comment)]">
        <p className="text-sm">Error: {recordError}</p>
      </div>
    );
  }

  const title = isEdit
    ? `Edit ${schema.display_name}`
    : `New ${schema.display_name}`;
  const errorMessage = validationError ?? saveError;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/custom/${slug}/${id}` : `/custom/${slug}`)}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Cancel
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">{title}</h1>
      </div>

      {errorMessage && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {errorMessage}
        </div>
      )}

      <form onSubmit={(e) => submit(e, false)} className="flex flex-col gap-6 max-w-3xl">
        <SectionCard title={schema.display_name} description={schema.description ?? undefined}>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Establishment scoping — present on every cx_ table. */}
            <div className="flex flex-col gap-1.5 md:col-span-2">
              <label className="text-xs text-[var(--color-fg)]">Facility</label>
              <EntitySelector
                entity="establishments"
                value={(form.establishment_id as number | null) ?? null}
                onChange={id => update('establishment_id', id)}
                renderLabel={row => String(row.name ?? `Facility ${row.id}`)}
                placeholder="Select a facility (optional)..."
              />
            </div>
            {fields.map(f => (
              <FieldInput
                key={f.id}
                field={f}
                relation={relationFor(schema, f)}
                value={form[f.name]}
                onChange={v => update(f.name, v)}
              />
            ))}
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/custom/${slug}/${id}` : `/custom/${slug}`)}
          onSaveAndNew={!isEdit ? () => submit(new Event('submit') as unknown as React.FormEvent, true) : undefined}
          saveLabel={isEdit ? 'Save changes' : `Create ${schema.display_name}`}
        />
      </form>
    </div>
  );
}
