import { useCallback, useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { FieldEditor, RelationEditor } from '../../components/schema/FieldEditor';
import { VersionHistory } from '../../components/schema/VersionHistory';
import type { CustomTable, CustomField, CustomRelation } from '../../hooks/useCustomTableSchema';

type ConfirmState =
  | { kind: 'deactivate_field'; fieldID: number; fieldName: string }
  | { kind: 'deactivate_relation'; relationID: number }
  | { kind: 'deactivate_table' }
  | { kind: 'reactivate_table' };

function FieldTypeBadge({ type }: { type: string }) {
  return (
    <span className="text-[10px] font-mono uppercase tracking-wider px-1.5 py-0.5 rounded bg-[var(--color-bg-lighter)] text-[var(--color-comment)]">
      {type}
    </span>
  );
}

export default function SchemaDesigner() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const tableID = Number(id);

  const [table, setTable] = useState<CustomTable | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [fieldEditorOpen, setFieldEditorOpen] = useState(false);
  const [relationEditorOpen, setRelationEditorOpen] = useState(false);
  const [confirm, setConfirm] = useState<ConfirmState | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();

  const load = useCallback(() => {
    setLoading(true);
    setError(null);
    api.get<CustomTable>(`/api/schema/tables/${tableID}`)
      .then(setTable)
      .catch(e => setError(e instanceof Error ? e.message : 'Failed to load table'))
      .finally(() => setLoading(false));
  }, [tableID]);

  useEffect(() => {
    if (!Number.isFinite(tableID)) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    load();
  }, [load, tableID]);

  function refresh() {
    setRefreshKey(k => k + 1);
    load();
  }

  async function runConfirm() {
    if (!confirm) return;
    try {
      switch (confirm.kind) {
        case 'deactivate_field':
          await mutate('POST', `/api/schema/tables/${tableID}/fields/${confirm.fieldID}/deactivate`);
          break;
        case 'deactivate_relation':
          await mutate('POST', `/api/schema/tables/${tableID}/relations/${confirm.relationID}/deactivate`);
          break;
        case 'deactivate_table':
          await mutate('POST', `/api/schema/tables/${tableID}/deactivate`);
          break;
        case 'reactivate_table':
          await mutate('POST', `/api/schema/tables/${tableID}/reactivate`);
          break;
      }
      setConfirm(null);
      refresh();
    } catch {
      // mutateError surfaces below
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">
        Loading…
      </div>
    );
  }
  if (error || !table) {
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-comment)]">
        <p className="text-sm">{error ?? 'Table not found'}</p>
        <button onClick={() => navigate('/admin/schema')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Custom Tables
        </button>
      </div>
    );
  }

  const fields = table.fields ?? [];
  const relations = table.relations ?? [];
  const activeFields = fields.filter(f => f.is_active);
  const inactiveFields = fields.filter(f => !f.is_active);
  const relationFields = activeFields
    .filter(f => f.field_type === 'relation')
    .filter(f => !relations.some(r => r.is_active && r.source_field_id === f.id));
  const activeRelations = relations.filter(r => r.is_active);

  return (
    <div>
      <div className="flex items-center gap-4 mb-6 flex-wrap">
        <button
          onClick={() => navigate('/admin/schema')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Custom Tables
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">
          {table.icon && <span className="mr-2">{table.icon}</span>}
          {table.display_name}
        </h1>
        <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
          table.is_active
            ? 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]'
            : 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
        }`}>
          {table.is_active ? 'Active' : 'Deactivated'}
        </span>
        <span className="font-mono text-xs text-[var(--color-comment)]">cx_{table.name}</span>

        <div className="ml-auto flex items-center gap-2">
          {table.is_active && (
            <button
              type="button"
              onClick={() => navigate(`/custom/${table.name}`)}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Open records →
            </button>
          )}
          {table.is_active ? (
            <button
              type="button"
              onClick={() => setConfirm({ kind: 'deactivate_table' })}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fn-red)] text-xs cursor-pointer hover:border-[var(--color-fn-red)]/50 transition-colors"
            >
              Deactivate table
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setConfirm({ kind: 'reactivate_table' })}
              className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
            >
              Reactivate table
            </button>
          )}
        </div>
      </div>

      {mutateError && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {mutateError}
        </div>
      )}
      {table.description && (
        <p className="text-sm text-[var(--color-comment)] mb-6">{table.description}</p>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-4">
        {/* Fields panel — spans 2 cols on wide screens */}
        <div className="lg:col-span-2 rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider">
              Fields
            </h2>
            <button
              type="button"
              disabled={!table.is_active}
              onClick={() => setFieldEditorOpen(true)}
              className="h-8 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
            >
              + Add field
            </button>
          </div>

          <FieldList
            fields={activeFields}
            onDeactivate={f => setConfirm({ kind: 'deactivate_field', fieldID: f.id, fieldName: f.name })}
            canEdit={table.is_active}
          />

          {inactiveFields.length > 0 && (
            <details className="mt-4">
              <summary className="text-xs text-[var(--color-comment)] cursor-pointer select-none">
                Inactive fields ({inactiveFields.length})
              </summary>
              <div className="mt-3 opacity-60">
                <FieldList fields={inactiveFields} onDeactivate={() => {}} canEdit={false} showInactive />
              </div>
            </details>
          )}
        </div>

        {/* Preview panel */}
        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider mb-4">
            Preview
          </h2>
          <PreviewForm fields={activeFields} />
        </div>
      </div>

      {/* Relations panel */}
      <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5 mb-4">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider">
            Relations
          </h2>
          <button
            type="button"
            disabled={!table.is_active}
            onClick={() => setRelationEditorOpen(true)}
            className="h-8 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
          >
            + Add relation
          </button>
        </div>
        <RelationList
          relations={activeRelations}
          fields={fields}
          onDeactivate={r => setConfirm({ kind: 'deactivate_relation', relationID: r.id })}
          canEdit={table.is_active}
        />
      </div>

      <VersionHistory tableID={tableID} refreshKey={refreshKey} />

      <FieldEditor
        open={fieldEditorOpen}
        onClose={() => setFieldEditorOpen(false)}
        onSaved={refresh}
        tableID={tableID}
      />
      <RelationEditor
        open={relationEditorOpen}
        onClose={() => setRelationEditorOpen(false)}
        onSaved={refresh}
        tableID={tableID}
        relationFields={relationFields.map(f => ({ id: f.id, name: f.name, display_name: f.display_name }))}
      />

      {confirm && (
        <ConfirmDialog
          open
          title={confirmTitle(confirm)}
          message={confirmMessage(confirm)}
          confirmLabel={confirmLabel(confirm)}
          destructive={confirm.kind !== 'reactivate_table'}
          loading={mutating}
          onConfirm={runConfirm}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}

// ============================================================
// Fields list
// ============================================================

function FieldList({
  fields, onDeactivate, canEdit, showInactive,
}: {
  fields: CustomField[];
  onDeactivate: (f: CustomField) => void;
  canEdit: boolean;
  showInactive?: boolean;
}) {
  if (fields.length === 0) {
    return (
      <p className="text-xs text-[var(--color-comment)]">
        {showInactive ? 'No inactive fields.' : 'No fields yet — click + Add field to start.'}
      </p>
    );
  }
  return (
    <ul className="flex flex-col gap-2">
      {fields.map(f => (
        <li
          key={f.id}
          className="flex items-center gap-3 px-3 py-2 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)]"
        >
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium text-[var(--color-fg)]">{f.display_name}</span>
              <FieldTypeBadge type={f.field_type} />
              {f.is_required && (
                <span className="text-[10px] font-semibold uppercase tracking-wider text-[var(--color-fn-red)]">
                  required
                </span>
              )}
            </div>
            <span className="font-mono text-xs text-[var(--color-comment)]">{f.name}</span>
          </div>
          {canEdit && (
            <button
              type="button"
              onClick={() => onDeactivate(f)}
              className="h-7 px-2 rounded-md bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fn-red)] text-xs cursor-pointer hover:border-[var(--color-fn-red)]/50 transition-colors"
            >
              Deactivate
            </button>
          )}
        </li>
      ))}
    </ul>
  );
}

// ============================================================
// Relations list
// ============================================================

function RelationList({
  relations, fields, onDeactivate, canEdit,
}: {
  relations: CustomRelation[];
  fields: CustomField[];
  onDeactivate: (r: CustomRelation) => void;
  canEdit: boolean;
}) {
  if (relations.length === 0) {
    return (
      <p className="text-xs text-[var(--color-comment)]">
        No relations yet. Add a field of type relation first, then wire it to a target table here.
      </p>
    );
  }
  const fieldByID = new Map(fields.map(f => [f.id, f]));
  return (
    <ul className="flex flex-col gap-2">
      {relations.map(r => {
        const sourceField = fieldByID.get(r.source_field_id);
        return (
          <li
            key={r.id}
            className="flex items-center gap-3 px-3 py-2 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)]"
          >
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="text-sm text-[var(--color-fg)]">
                  {sourceField?.display_name ?? `field #${r.source_field_id}`}
                </span>
                <span className="text-[var(--color-comment)] text-xs">→</span>
                <span className="text-sm font-mono text-[var(--color-fn-cyan)]">{r.target_table_name}</span>
                <span className="text-[var(--color-comment)] text-xs">display:</span>
                <span className="text-sm font-mono text-[var(--color-fg)]">{r.display_field}</span>
              </div>
              <span className="text-xs text-[var(--color-comment)]">{r.relation_type}</span>
            </div>
            {canEdit && (
              <button
                type="button"
                onClick={() => onDeactivate(r)}
                className="h-7 px-2 rounded-md bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fn-red)] text-xs cursor-pointer hover:border-[var(--color-fn-red)]/50 transition-colors"
              >
                Deactivate
              </button>
            )}
          </li>
        );
      })}
    </ul>
  );
}

// ============================================================
// Preview panel — disabled, read-only sample of the record form
// ============================================================

function PreviewForm({ fields }: { fields: CustomField[] }) {
  if (fields.length === 0) {
    return (
      <p className="text-xs text-[var(--color-comment)]">
        Add at least one field to see a preview of the record form.
      </p>
    );
  }
  return (
    <div className="flex flex-col gap-3">
      {fields.map(f => (
        <div key={f.id} className="flex flex-col gap-1">
          <label className="text-xs text-[var(--color-fg)]">
            {f.display_name}
            {f.is_required && <span className="text-[var(--color-fn-red)] ml-0.5">*</span>}
          </label>
          <PreviewInput field={f} />
        </div>
      ))}
    </div>
  );
}

function PreviewInput({ field }: { field: CustomField }) {
  const base =
    'w-full h-9 px-3 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] ' +
    'text-[var(--color-fg)] text-sm opacity-70 cursor-not-allowed';
  switch (field.field_type) {
    case 'boolean':
      return (
        <div className="flex items-center gap-2 h-9">
          <input type="checkbox" disabled className="h-4 w-4 rounded accent-[var(--color-fn-purple)]" />
          <span className="text-xs text-[var(--color-comment)]">yes/no</span>
        </div>
      );
    case 'date':
      return <input disabled type="date" className={base} />;
    case 'datetime':
      return <input disabled className={base} placeholder="YYYY-MM-DDTHH:MM:SSZ" />;
    case 'number':
    case 'decimal':
      return <input disabled type="number" className={base} />;
    case 'select':
      return (
        <select disabled className={base + ' cursor-not-allowed'}>
          <option>— not set —</option>
        </select>
      );
    case 'relation':
      return (
        <div className={`${base} flex items-center`}>
          <span className="text-[var(--color-comment)] text-xs">pick from related table…</span>
        </div>
      );
    default: {
      const cfg = field.config && typeof field.config === 'object' ? field.config as { multiline?: boolean } : null;
      if (cfg?.multiline) {
        return (
          <textarea disabled rows={2} className={base.replace('h-9', '') + ' py-2'} />
        );
      }
      return <input disabled className={base} />;
    }
  }
}

// ============================================================
// Confirm copy
// ============================================================

function confirmTitle(c: ConfirmState): string {
  switch (c.kind) {
    case 'deactivate_field':    return `Deactivate field "${c.fieldName}"?`;
    case 'deactivate_relation': return 'Deactivate relation?';
    case 'deactivate_table':    return 'Deactivate table?';
    case 'reactivate_table':    return 'Reactivate table?';
  }
}

function confirmMessage(c: ConfirmState): string {
  switch (c.kind) {
    case 'deactivate_field':
      return 'The SQLite column stays in place; the field is hidden from the UI. Reactivating fields is not supported — add a new one to restore functionality.';
    case 'deactivate_relation':
      return 'The FK column stays. Future record forms will no longer surface this relation as a dropdown.';
    case 'deactivate_table':
      return 'Hides the table from the sidebar and blocks record reads/writes through the API. Data stays in SQLite and can be restored with Reactivate.';
    case 'reactivate_table':
      return 'Makes the table visible and allows record reads/writes again. Existing rows come back as they were.';
  }
}

function confirmLabel(c: ConfirmState): string {
  switch (c.kind) {
    case 'deactivate_field':    return 'Deactivate field';
    case 'deactivate_relation': return 'Deactivate relation';
    case 'deactivate_table':    return 'Deactivate table';
    case 'reactivate_table':    return 'Reactivate';
  }
}
