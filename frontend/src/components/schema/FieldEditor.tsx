import { useEffect, useState } from 'react';
import { Modal } from '../Modal';
import { FormField } from '../forms/FormField';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { api } from '../../api';
import type { FieldType } from '../../hooks/useCustomTableSchema';

interface ColumnInfo { name: string; type: string }
interface ColumnsResponse { columns: ColumnInfo[] }

const fieldTypeOptions: { value: FieldType; label: string }[] = [
  { value: 'text', label: 'Text' },
  { value: 'number', label: 'Integer' },
  { value: 'decimal', label: 'Decimal' },
  { value: 'date', label: 'Date' },
  { value: 'datetime', label: 'Date & time' },
  { value: 'boolean', label: 'Boolean' },
  { value: 'select', label: 'Select (fixed options)' },
  { value: 'relation', label: 'Relation' },
];

function nameFromDisplay(s: string): string {
  let out = s.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/_+/g, '_').replace(/^_+|_+$/g, '');
  if (out.length > 0 && !/^[a-z]/.test(out)) out = 'f_' + out;
  if (out.length > 63) out = out.slice(0, 63);
  return out;
}

/**
 * Modal for creating a new field on a custom table. For this MVP we
 * support creating new fields only — field deactivation is the inverse
 * op and happens inline from the designer, and rename is not supported
 * by the schema builder at all.
 */
export function FieldEditor({
  open, onClose, onSaved, tableID,
}: {
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
  tableID: number;
}) {
  const [displayName, setDisplayName] = useState('');
  const [name, setName] = useState('');
  const [nameTouched, setNameTouched] = useState(false);
  const [fieldType, setFieldType] = useState<FieldType>('text');
  const [isRequired, setIsRequired] = useState(false);
  const [defaultValue, setDefaultValue] = useState('');
  // Type-specific config state
  const [textMultiline, setTextMultiline] = useState(false);
  const [textMaxLength, setTextMaxLength] = useState('');
  const [selectOptions, setSelectOptions] = useState('');
  const [numberMin, setNumberMin] = useState('');
  const [numberMax, setNumberMax] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  function reset() {
    setDisplayName('');
    setName('');
    setNameTouched(false);
    setFieldType('text');
    setIsRequired(false);
    setDefaultValue('');
    setTextMultiline(false);
    setTextMaxLength('');
    setSelectOptions('');
    setNumberMin('');
    setNumberMax('');
    setErr(null);
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (!open) reset();
  }, [open]);

  function onDisplayChange(v: string) {
    setDisplayName(v);
    if (!nameTouched) setName(nameFromDisplay(v));
    setErr(null);
  }

  function buildConfig(): Record<string, unknown> | null {
    switch (fieldType) {
      case 'text': {
        const cfg: Record<string, unknown> = {};
        if (textMultiline) cfg.multiline = true;
        const max = parseInt(textMaxLength, 10);
        if (!Number.isNaN(max) && max > 0) cfg.max_length = max;
        return Object.keys(cfg).length ? cfg : null;
      }
      case 'select': {
        const options = selectOptions
          .split('\n')
          .map(s => s.trim())
          .filter(Boolean);
        return options.length ? { options } : null;
      }
      case 'number':
      case 'decimal': {
        const cfg: Record<string, unknown> = {};
        const min = fieldType === 'number' ? parseInt(numberMin, 10) : parseFloat(numberMin);
        const max = fieldType === 'number' ? parseInt(numberMax, 10) : parseFloat(numberMax);
        if (!Number.isNaN(min)) cfg.min = min;
        if (!Number.isNaN(max)) cfg.max = max;
        return Object.keys(cfg).length ? cfg : null;
      }
      default:
        return null;
    }
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!displayName.trim()) { setErr('Display name is required.'); return; }
    if (!name.trim()) { setErr('Name is required.'); return; }
    try {
      await mutate('POST', `/api/schema/tables/${tableID}/fields`, {
        name: name.trim(),
        display_name: displayName.trim(),
        field_type: fieldType,
        is_required: isRequired,
        default_value: defaultValue.trim() || null,
        config: buildConfig(),
      });
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to add field');
    }
  }

  return (
    <Modal open={open} onClose={onClose} title="Add field" size="lg">
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormField
            label="Display Name"
            required
            value={displayName}
            onChange={onDisplayChange}
            placeholder="e.g. Due Date"
            autoFocus
          />
          <FormField
            label="Name"
            required
            value={name}
            onChange={v => { setName(v); setNameTouched(true); setErr(null); }}
            hint="Physical column name. Lowercase letters / digits / underscores, 2–63 chars."
          />
          <FormField
            type="select"
            label="Type"
            required
            value={fieldType}
            onChange={v => setFieldType(v as FieldType)}
            options={fieldTypeOptions.map(o => ({ value: o.value, label: o.label }))}
          />
          <FormField
            type="checkbox"
            label="Required"
            value={isRequired}
            onChange={setIsRequired}
            hint="Required in new-record forms"
          />
        </div>

        {fieldType === 'text' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="checkbox"
              label="Multiline"
              value={textMultiline}
              onChange={setTextMultiline}
              hint="Render as textarea"
            />
            <FormField
              type="number"
              label="Max length"
              value={textMaxLength}
              onChange={setTextMaxLength}
              hint="Optional"
            />
          </div>
        )}

        {(fieldType === 'number' || fieldType === 'decimal') && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="number"
              label="Min"
              value={numberMin}
              onChange={setNumberMin}
            />
            <FormField
              type="number"
              label="Max"
              value={numberMax}
              onChange={setNumberMax}
            />
          </div>
        )}

        {fieldType === 'select' && (
          <FormField
            type="textarea"
            label="Options"
            value={selectOptions}
            onChange={setSelectOptions}
            rows={4}
            hint="One option per line"
            placeholder={'Low\nMedium\nHigh'}
          />
        )}

        {fieldType === 'relation' && (
          <div className="rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] p-3 text-xs text-[var(--color-comment)]">
            Relation targets are configured in the Relations panel after saving
            the field — the field itself only stores the FK id.
          </div>
        )}

        {fieldType !== 'boolean' && fieldType !== 'relation' && (
          <FormField
            label="Default value"
            value={defaultValue}
            onChange={setDefaultValue}
            hint="Pre-filled in new-record forms. Leave blank for none."
          />
        )}

        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50"
          >
            {loading ? 'Saving...' : 'Add field'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============================================================
// Relation editor — bound to an existing relation-typed field
// ============================================================

/**
 * Modal for creating a new relation. Requires an existing
 * relation-typed field on the table — it binds the relation to a
 * target table + display column.
 */
export function RelationEditor({
  open, onClose, onSaved, tableID, relationFields,
}: {
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
  tableID: number;
  relationFields: { id: number; display_name: string; name: string }[];
}) {
  const [sourceFieldID, setSourceFieldID] = useState<string>('');
  const [targetTableName, setTargetTableName] = useState<string>('employees');
  const [displayField, setDisplayField] = useState<string>('');
  const [err, setErr] = useState<string | null>(null);
  const [columns, setColumns] = useState<ColumnInfo[] | null>(null);
  const [columnsError, setColumnsError] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  useEffect(() => {
    if (!open) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setSourceFieldID('');
      setTargetTableName('employees');
      setDisplayField('');
      setErr(null);
      setColumns(null);
      setColumnsError(null);
    }
  }, [open]);

  // Fetch columns whenever the target-table input changes (debounced).
  // Failures fall back to free-text entry so a typo or temporarily
  // unresolvable target doesn't block the admin.
  useEffect(() => {
    if (!open) return;
    const target = targetTableName.trim();
    if (!target) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setColumns(null);
      setColumnsError(null);
      return;
    }
    const controller = new AbortController();
    const t = setTimeout(() => {
      api.get<ColumnsResponse>(`/api/schema/columns?table=${encodeURIComponent(target)}`)
        .then(r => {
          if (controller.signal.aborted) return;
          setColumns(r.columns ?? []);
          setColumnsError(null);
        })
        .catch(e => {
          if (controller.signal.aborted) return;
          setColumns(null);
          setColumnsError(e instanceof Error ? e.message : 'Failed to load columns');
        });
    }, 200);
    return () => {
      controller.abort();
      clearTimeout(t);
    };
  }, [open, targetTableName]);

  // When the column list arrives, clear a stale display_field that
  // isn't on the new target; otherwise keep whatever the admin picked.
  useEffect(() => {
    if (!columns || !displayField) return;
    if (!columns.some(c => c.name === displayField)) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setDisplayField('');
    }
  }, [columns, displayField]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!sourceFieldID) { setErr('Source field is required.'); return; }
    if (!targetTableName.trim()) { setErr('Target table is required.'); return; }
    if (!displayField.trim()) { setErr('Display field is required.'); return; }
    try {
      await mutate('POST', `/api/schema/tables/${tableID}/relations`, {
        source_field_id: parseInt(sourceFieldID, 10),
        target_table_name: targetTableName.trim(),
        display_field: displayField.trim(),
        relation_type: 'belongs_to',
      });
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to add relation');
    }
  }

  const fieldOptions = relationFields.map(f => ({
    value: String(f.id),
    label: `${f.display_name} (${f.name})`,
  }));

  return (
    <Modal open={open} onClose={onClose} title="Add relation" size="md">
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        {fieldOptions.length === 0 ? (
          <div className="rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] p-3 text-sm text-[var(--color-comment)]">
            Add a field of type <span className="text-[var(--color-fg)]">relation</span> first.
            Relations bind an existing FK column to a target table + display column.
          </div>
        ) : (
          <>
            <FormField
              type="select"
              label="Source field"
              required
              value={sourceFieldID}
              onChange={setSourceFieldID}
              options={fieldOptions}
              placeholder="Pick a relation-typed field..."
              hint="Only relation fields without an existing relation are listed."
            />
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">
                Target table<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
              </label>
              <input
                value={targetTableName}
                onChange={e => setTargetTableName(e.target.value)}
                placeholder="e.g. employees, establishments, cx_projects"
                className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm outline-none focus:border-[var(--color-fn-purple)] transition-colors placeholder:text-[var(--color-comment)]"
              />
              <p className="text-xs text-[var(--color-comment)]">
                Allowed pre-built: establishments, employees, incidents, chemicals,
                training_courses, training_completions, storage_locations, work_areas.
                Any existing cx_* table is also allowed.
              </p>
            </div>
            {columns && columns.length > 0 ? (
              <FormField
                type="select"
                label="Display field"
                required
                value={displayField}
                onChange={setDisplayField}
                options={columns.map(c => ({
                  value: c.name,
                  label: c.type ? `${c.name} (${c.type.toLowerCase()})` : c.name,
                }))}
                placeholder="Pick a column..."
                hint={`Column on ${targetTableName} used as the dropdown label.`}
              />
            ) : (
              <FormField
                label="Display field"
                required
                value={displayField}
                onChange={setDisplayField}
                placeholder="e.g. last_name, name, title"
                hint={
                  columnsError
                    ? `Can't load columns for ${targetTableName} — enter a column name manually.`
                    : 'Column on the target used as the dropdown label.'
                }
              />
            )}
          </>
        )}

        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button
            type="button"
            onClick={onClose}
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          {fieldOptions.length > 0 && (
            <button
              type="submit"
              disabled={loading}
              className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50"
            >
              {loading ? 'Saving...' : 'Add relation'}
            </button>
          )}
        </div>
      </form>
    </Modal>
  );
}

