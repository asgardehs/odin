import { useCallback, useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { api } from '../../api';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { Modal } from '../../components/Modal';
import { FormField } from '../../components/forms/FormField';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import { AuditHistory } from '../../components/AuditHistory';
import { formatDate } from '../../utils/date';

type PPERow = Record<string, unknown>;
type Row = Record<string, unknown>;

interface PagedResult<T> { data: T[]; total: number; }

// ============ Assign modal ============

function AssignModal({
  ppeItemId, open, onClose, onSaved,
}: {
  ppeItemId: number;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [employeeId, setEmployeeId] = useState<number | null>(null);
  const [assignedDate, setAssignedDate] = useState('');
  const [notes, setNotes] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  function reset() {
    setEmployeeId(null);
    setAssignedDate('');
    setNotes('');
    setErr(null);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (employeeId == null) { setErr('Employee is required.'); return; }
    if (!assignedDate) { setErr('Assigned date is required.'); return; }
    try {
      await mutate('POST', '/api/ppe/assignments', {
        ppe_item_id: ppeItemId,
        employee_id: employeeId,
        assigned_date: assignedDate,
        notes: notes.trim() || null,
      });
      reset();
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to save');
    }
  }

  return (
    <Modal open={open} onClose={() => { reset(); onClose(); }} title="Assign PPE" size="md">
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        <div className="flex flex-col gap-1.5">
          <label className="text-xs text-[var(--color-fg)]">
            Employee<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
          </label>
          <EntitySelector
            entity="employees"
            value={employeeId}
            onChange={setEmployeeId}
            renderLabel={row => `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`}
            placeholder="Select an employee..."
            required
          />
        </div>
        <FormField type="date" label="Assigned Date" required value={assignedDate} onChange={setAssignedDate} />
        <FormField type="textarea" label="Notes" value={notes} onChange={setNotes} rows={2} />
        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button type="button" onClick={() => { reset(); onClose(); }} disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50">
            Cancel
          </button>
          <button type="submit" disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50">
            {loading ? 'Saving...' : 'Assign'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============ Inspection modal ============

function InspectionModal({
  ppeItemId, open, onClose, onSaved,
}: {
  ppeItemId: number;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [inspectionDate, setInspectionDate] = useState('');
  const [inspectedByEmployeeId, setInspectedByEmployeeId] = useState<number | null>(null);
  const [passed, setPassed] = useState(true);
  const [condition, setCondition] = useState('');
  const [issuesFound, setIssuesFound] = useState('');
  const [correctiveAction, setCorrectiveAction] = useState('');
  const [nextInspectionDue, setNextInspectionDue] = useState('');
  const [removedFromService, setRemovedFromService] = useState(false);
  const [removalReason, setRemovalReason] = useState('');
  const [notes, setNotes] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  function reset() {
    setInspectionDate('');
    setInspectedByEmployeeId(null);
    setPassed(true);
    setCondition('');
    setIssuesFound('');
    setCorrectiveAction('');
    setNextInspectionDue('');
    setRemovedFromService(false);
    setRemovalReason('');
    setNotes('');
    setErr(null);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!inspectionDate) { setErr('Inspection date is required.'); return; }
    if (inspectedByEmployeeId == null) { setErr('Inspector is required.'); return; }
    try {
      await mutate('POST', '/api/ppe/inspections', {
        ppe_item_id: ppeItemId,
        inspection_date: inspectionDate,
        inspected_by_employee_id: inspectedByEmployeeId,
        passed: passed ? 1 : 0,
        condition: condition.trim() || null,
        issues_found: issuesFound.trim() || null,
        corrective_action: correctiveAction.trim() || null,
        next_inspection_due: nextInspectionDue || null,
        removed_from_service: removedFromService ? 1 : 0,
        removal_reason: removalReason.trim() || null,
        notes: notes.trim() || null,
      });
      reset();
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to save');
    }
  }

  return (
    <Modal open={open} onClose={() => { reset(); onClose(); }} title="Log PPE inspection" size="lg">
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormField type="date" label="Inspection Date" required value={inspectionDate} onChange={setInspectionDate} />
          <div className="flex flex-col gap-1.5">
            <label className="text-xs text-[var(--color-fg)]">
              Inspector<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
            </label>
            <EntitySelector
              entity="employees"
              value={inspectedByEmployeeId}
              onChange={setInspectedByEmployeeId}
              renderLabel={row => `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`}
              placeholder="Select inspector..."
              required
            />
          </div>
          <label className="flex items-center gap-2 h-10 cursor-pointer select-none">
            <input type="checkbox" checked={passed} onChange={e => setPassed(e.target.checked)}
              className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer" />
            <span className="text-sm text-[var(--color-fg)]">Inspection passed</span>
          </label>
          <FormField label="Condition" value={condition} onChange={setCondition} placeholder="e.g. Good, Worn, Damaged" />
          <FormField type="date" label="Next Inspection Due" value={nextInspectionDue} onChange={setNextInspectionDue} />
        </div>
        <FormField type="textarea" label="Issues Found" value={issuesFound} onChange={setIssuesFound} rows={2} />
        <FormField type="textarea" label="Corrective Action" value={correctiveAction} onChange={setCorrectiveAction} rows={2} />
        <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
          <input type="checkbox" checked={removedFromService} onChange={e => setRemovedFromService(e.target.checked)}
            className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer" />
          <span className="text-sm text-[var(--color-fg)]">Remove from service</span>
        </label>
        {removedFromService && (
          <FormField label="Removal Reason" value={removalReason} onChange={setRemovalReason} />
        )}
        <FormField type="textarea" label="Notes" value={notes} onChange={setNotes} rows={2} />
        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button type="button" onClick={() => { reset(); onClose(); }} disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50">
            Cancel
          </button>
          <button type="submit" disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50">
            {loading ? 'Saving...' : 'Log inspection'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============ Sub-record lists ============

function AssignmentsList({ ppeItemId, refreshKey, onRefresh }: { ppeItemId: number; refreshKey: number; onRefresh: () => void }) {
  const [rows, setRows] = useState<Row[] | null>(null);
  const { mutate } = useEntityMutation();

  const refresh = useCallback(() => {
    api.get<PagedResult<Row>>('/api/ppe/assignments?per_page=500')
      .then(r => setRows((r.data ?? []).filter(x => (x.ppe_item_id as number) === ppeItemId)))
      .catch(() => setRows([]));
  }, [ppeItemId]);

  useEffect(() => { refresh(); }, [refresh, refreshKey]);

  async function returnItem(assignmentId: number) {
    try {
      await mutate('POST', `/api/ppe/assignments/${assignmentId}/return`, {});
      refresh();
      onRefresh();
    } catch {
      /* swallow */
    }
  }

  if (rows === null) return <p className="text-xs text-[var(--color-comment)]">Loading…</p>;
  if (rows.length === 0) return <p className="text-xs text-[var(--color-comment)]">No assignments.</p>;
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b border-[var(--color-current-line)]">
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Employee</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Assigned</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Returned</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Condition</th>
          <th className="py-2"></th>
        </tr>
      </thead>
      <tbody>
        {rows.map(r => (
          <tr key={String(r.id)} className="border-b border-[var(--color-current-line)] last:border-b-0">
            <td className="py-2 text-[var(--color-fg)]">#{String(r.employee_id)}</td>
            <td className="py-2 text-[var(--color-fg)]">{formatDate(r.assigned_date as string)}</td>
            <td className="py-2 text-[var(--color-fg)]">{r.returned_date ? formatDate(r.returned_date as string) : '—'}</td>
            <td className="py-2 text-[var(--color-fg)]">{String(r.returned_condition ?? '—')}</td>
            <td className="py-2 text-right">
              {!r.returned_date && (
                <button
                  type="button"
                  onClick={() => returnItem(Number(r.id))}
                  className="h-7 px-2 rounded-md bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
                >
                  Return
                </button>
              )}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function InspectionsList({ ppeItemId, refreshKey }: { ppeItemId: number; refreshKey: number }) {
  const [rows, setRows] = useState<Row[] | null>(null);

  const refresh = useCallback(() => {
    api.get<PagedResult<Row>>('/api/ppe/inspections?per_page=500')
      .then(r => setRows((r.data ?? []).filter(x => (x.ppe_item_id as number) === ppeItemId)))
      .catch(() => setRows([]));
  }, [ppeItemId]);

  useEffect(() => { refresh(); }, [refresh, refreshKey]);

  if (rows === null) return <p className="text-xs text-[var(--color-comment)]">Loading…</p>;
  if (rows.length === 0) return <p className="text-xs text-[var(--color-comment)]">No inspections recorded yet.</p>;
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b border-[var(--color-current-line)]">
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Date</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Inspector</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Result</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Condition</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Next Due</th>
        </tr>
      </thead>
      <tbody>
        {rows.map(r => (
          <tr key={String(r.id)} className="border-b border-[var(--color-current-line)] last:border-b-0">
            <td className="py-2 text-[var(--color-fg)]">{formatDate(r.inspection_date as string)}</td>
            <td className="py-2 text-[var(--color-fg)]">#{String(r.inspected_by_employee_id)}</td>
            <td className="py-2">
              <span className={r.passed ? 'text-[var(--color-fn-green)]' : 'text-[var(--color-fn-red)]'}>
                {r.passed ? 'Pass' : 'Fail'}
              </span>
            </td>
            <td className="py-2 text-[var(--color-fg)]">{String(r.condition ?? '—')}</td>
            <td className="py-2 text-[var(--color-fg)]">{r.next_inspection_due ? formatDate(r.next_inspection_due as string) : '—'}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// ============ Detail page ============

export default function PPEDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<PPERow>(`/api/ppe/items/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'retire' | 'delete'>(null);
  const [assignOpen, setAssignOpen] = useState(false);
  const [inspectOpen, setInspectOpen] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'retire') {
        await mutate('POST', `/api/ppe/items/${id}/retire`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/ppe/items/${id}`);
        navigate('/ppe');
      }
    } catch { /* mutateError surfaces */ }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">
        Loading…
      </div>
    );
  }

  if (error || !data) {
    const notFound = error?.startsWith('404');
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-comment)]">
        <p className="text-sm">{notFound ? 'PPE item not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/ppe')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to PPE
        </button>
      </div>
    );
  }

  const ppeItemId = Number(id);
  const status = String(data.status ?? 'available').toLowerCase();
  const canRetire = status !== 'retired';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/ppe')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← PPE
        </button>
        <div>
          <p className="text-xs text-[var(--color-comment)] mb-0.5">
            {String(data.asset_tag ?? data.serial_number ?? '')}
          </p>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">
            {String(data.manufacturer ?? '')} {String(data.model ?? 'PPE Item')}
          </h1>
        </div>
        <span className="text-xs font-medium px-2 py-0.5 rounded-full capitalize bg-[var(--color-current-line)] text-[var(--color-fg)]">
          {status.replace(/_/g, ' ')}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/ppe/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {canRetire && (
            <button
              type="button"
              onClick={() => setConfirm('retire')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Retire
            </button>
          )}
          {isAdmin && (
            <button
              type="button"
              onClick={() => setConfirm('delete')}
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
        <Section title="Item Identity">
          <Field label="Serial Number" value={data.serial_number} />
          <Field label="Asset Tag" value={data.asset_tag} />
          <Field label="Type ID" value={data.ppe_type_id} />
        </Section>

        <Section title="Manufacturer">
          <Field label="Manufacturer" value={data.manufacturer} />
          <Field label="Model" value={data.model} />
          <Field label="Size" value={data.size} />
        </Section>

        <Section title="Service Dates">
          <Field label="Manufacture Date" value={data.manufacture_date} />
          <Field label="Purchase Date" value={data.purchase_date} />
          <Field label="In-Service Date" value={data.in_service_date} />
          <Field label="Expiration Date" value={data.expiration_date} />
        </Section>

        <Section title="Procurement">
          <Field label="Purchase Order" value={data.purchase_order} />
          <Field label="Purchase Cost" value={data.purchase_cost} />
          <Field label="Vendor" value={data.vendor} />
        </Section>

        <Section title="Current Assignment">
          <Field label="Current Employee ID" value={data.current_employee_id} />
          <Field label="Assigned Date" value={data.assigned_date} />
        </Section>

        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider">
              Assignment History
            </h2>
            <button
              type="button"
              onClick={() => setAssignOpen(true)}
              className="h-8 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
            >
              + Assign to employee
            </button>
          </div>
          <AssignmentsList
            ppeItemId={ppeItemId}
            refreshKey={refreshKey}
            onRefresh={() => setRefreshKey(k => k + 1)}
          />
        </div>

        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider">
              Inspections
            </h2>
            <button
              type="button"
              onClick={() => setInspectOpen(true)}
              className="h-8 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
            >
              + Log inspection
            </button>
          </div>
          <InspectionsList ppeItemId={ppeItemId} refreshKey={refreshKey} />
        </div>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="ppe_items" entityId={id} />
      </div>

      <AssignModal
        ppeItemId={ppeItemId}
        open={assignOpen}
        onClose={() => setAssignOpen(false)}
        onSaved={() => setRefreshKey(k => k + 1)}
      />
      <InspectionModal
        ppeItemId={ppeItemId}
        open={inspectOpen}
        onClose={() => setInspectOpen(false)}
        onSaved={() => setRefreshKey(k => k + 1)}
      />

      {confirm && (
        <ConfirmDialog
          open
          title={confirm === 'retire' ? 'Retire PPE item?' : 'Delete PPE item?'}
          message={
            confirm === 'retire'
              ? 'Marks this item retired from service. Historical assignments and inspections are preserved for audit.'
              : 'Permanently deletes the PPE item. Existing assignments/inspections may block the delete — retire instead.'
          }
          confirmLabel={confirm === 'retire' ? 'Retire' : 'Delete'}
          destructive
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
