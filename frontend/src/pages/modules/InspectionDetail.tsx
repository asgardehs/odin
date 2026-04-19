import { useCallback, useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { api } from '../../api';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { Modal } from '../../components/Modal';
import { FormField } from '../../components/forms/FormField';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import { AuditHistory } from '../../components/AuditHistory';
import { formatDate } from '../../utils/date';

type InspectionRow = Record<string, unknown>;
type Row = Record<string, unknown>;

interface PagedResult<T> { data: T[]; total: number; }

const findingTypeOptions = [
  { value: 'observation', label: 'Observation' },
  { value: 'deficiency', label: 'Deficiency' },
  { value: 'violation', label: 'Violation' },
  { value: 'opportunity', label: 'Opportunity' },
];

const severityOptions = [
  { value: 'minor', label: 'Minor' },
  { value: 'major', label: 'Major' },
  { value: 'critical', label: 'Critical' },
];

const SEVERITY_COLORS: Record<string, string> = {
  minor: 'var(--color-fn-green)',
  major: 'var(--color-fn-yellow)',
  critical: 'var(--color-fn-red)',
};

// ============ Finding modal ============

function FindingModal({
  inspectionId, open, onClose, onSaved,
}: {
  inspectionId: number;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [findingNumber, setFindingNumber] = useState('');
  const [findingType, setFindingType] = useState('observation');
  const [severity, setSeverity] = useState('minor');
  const [description, setDescription] = useState('');
  const [location, setLocation] = useState('');
  const [regulatoryCitation, setRegulatoryCitation] = useState('');
  const [immediateAction, setImmediateAction] = useState('');
  const [immediateActionBy, setImmediateActionBy] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  function reset() {
    setFindingNumber('');
    setFindingType('observation');
    setSeverity('minor');
    setDescription('');
    setLocation('');
    setRegulatoryCitation('');
    setImmediateAction('');
    setImmediateActionBy('');
    setErr(null);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!description.trim()) { setErr('Finding description is required.'); return; }
    try {
      await mutate('POST', '/api/inspection-findings', {
        inspection_id: inspectionId,
        finding_number: findingNumber.trim() || null,
        finding_type: findingType,
        severity: severity || null,
        finding_description: description.trim(),
        location: location.trim() || null,
        regulatory_citation: regulatoryCitation.trim() || null,
        immediate_action: immediateAction.trim() || null,
        immediate_action_by: immediateActionBy.trim() || null,
      });
      reset();
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to save');
    }
  }

  return (
    <Modal open={open} onClose={() => { reset(); onClose(); }} title="Add finding" size="lg">
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormField label="Finding Number" value={findingNumber} onChange={setFindingNumber}
            placeholder="Sequence within inspection, e.g. F-01" />
          <FormField type="select" label="Type" required value={findingType} onChange={setFindingType} options={findingTypeOptions} />
          <FormField type="select" label="Severity" value={severity} onChange={setSeverity} options={severityOptions} />
          <FormField label="Location" value={location} onChange={setLocation}
            placeholder="Where the finding was observed" />
        </div>
        <FormField type="textarea" label="Description" required value={description} onChange={setDescription}
          rows={3} placeholder="What was observed?" />
        <FormField label="Regulatory Citation" value={regulatoryCitation} onChange={setRegulatoryCitation}
          placeholder="e.g. 29 CFR 1910.147(c)(4)" />
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormField label="Immediate Action Taken" value={immediateAction} onChange={setImmediateAction} />
          <FormField label="Action Taken By" value={immediateActionBy} onChange={setImmediateActionBy} />
        </div>
        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button type="button" onClick={() => { reset(); onClose(); }} disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50">
            Cancel
          </button>
          <button type="submit" disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50">
            {loading ? 'Saving...' : 'Add finding'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============ Close finding modal ============

function CloseFindingModal({
  findingId, open, onClose, onSaved,
}: {
  findingId: number | null;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [notes, setNotes] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!findingId) return;
    setErr(null);
    try {
      await mutate('POST', `/api/inspection-findings/${findingId}/close`, {
        notes: notes.trim() || null,
      });
      setNotes('');
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to close');
    }
  }

  return (
    <Modal open={open} onClose={() => { setNotes(''); onClose(); }} title="Close finding" size="md">
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        <FormField type="textarea" label="Closure Notes" value={notes} onChange={setNotes} rows={3}
          placeholder="How was this finding resolved?" />
        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button type="button" onClick={() => { setNotes(''); onClose(); }} disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50">
            Cancel
          </button>
          <button type="submit" disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50">
            {loading ? 'Closing...' : 'Close finding'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============ Findings list ============

function FindingsList({
  inspectionId, refreshKey, onClose,
}: {
  inspectionId: number;
  refreshKey: number;
  onClose: (findingId: number) => void;
}) {
  const [rows, setRows] = useState<Row[] | null>(null);

  const refresh = useCallback(() => {
    api.get<PagedResult<Row>>('/api/inspection-findings?per_page=500')
      .then(r => setRows((r.data ?? []).filter(x => (x.inspection_id as number) === inspectionId)))
      .catch(() => setRows([]));
  }, [inspectionId]);

  useEffect(() => { refresh(); }, [refresh, refreshKey]);

  if (rows === null) return <p className="text-xs text-[var(--color-comment)]">Loading…</p>;
  if (rows.length === 0) return <p className="text-xs text-[var(--color-comment)]">No findings recorded yet.</p>;
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b border-[var(--color-current-line)]">
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">#</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Type</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Severity</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Description</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Status</th>
          <th className="py-2"></th>
        </tr>
      </thead>
      <tbody>
        {rows.map(r => {
          const status = String(r.status ?? 'open');
          const severity = String(r.severity ?? 'minor');
          const color = SEVERITY_COLORS[severity] ?? 'var(--color-comment)';
          const desc = String(r.finding_description ?? '');
          return (
            <tr key={String(r.id)} className="border-b border-[var(--color-current-line)] last:border-b-0 align-top">
              <td className="py-2 text-[var(--color-fg)]">{String(r.finding_number ?? '—')}</td>
              <td className="py-2 text-[var(--color-fg)] capitalize">{String(r.finding_type ?? '—')}</td>
              <td className="py-2">
                <span style={{ color }} className="text-xs font-medium capitalize">{severity}</span>
              </td>
              <td className="py-2 text-[var(--color-fg)] max-w-md">
                {desc.length > 120 ? desc.slice(0, 120) + '…' : desc}
                {r.closed_date ? (
                  <span className="block text-xs text-[var(--color-comment)] mt-1">
                    Closed {formatDate(r.closed_date as string)}
                  </span>
                ) : null}
              </td>
              <td className="py-2 text-[var(--color-fg)] capitalize">{status.replace(/_/g, ' ')}</td>
              <td className="py-2 text-right">
                {status !== 'closed' && (
                  <button
                    type="button"
                    onClick={() => onClose(Number(r.id))}
                    className="h-7 px-2 rounded-md bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
                  >
                    Close
                  </button>
                )}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}

export default function InspectionDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<InspectionRow>(`/api/inspections/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'complete' | 'delete'>(null);
  const [findingOpen, setFindingOpen] = useState(false);
  const [closeFindingId, setCloseFindingId] = useState<number | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'complete') {
        await mutate('POST', `/api/inspections/${id}/complete`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/inspections/${id}`);
        navigate('/inspections');
      }
    } catch {
      // mutateError surfaces
    }
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
        <p className="text-sm">{notFound ? 'Inspection not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/inspections')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Inspections
        </button>
      </div>
    );
  }

  const status = String(data.status ?? 'scheduled').toLowerCase();
  const canComplete = status !== 'completed' && status !== 'complete';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/inspections')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Inspections
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">
          {String(data.inspection_number ?? 'Inspection')}
        </h1>
        <span className="text-xs font-medium px-2 py-0.5 rounded-full capitalize bg-[var(--color-current-line)] text-[var(--color-fg)]">
          {status.replace(/_/g, ' ')}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/inspections/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {canComplete && (
            <button
              type="button"
              onClick={() => setConfirm('complete')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Mark complete
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
        <Section title="Schedule">
          <Field label="Inspection #" value={data.inspection_number} />
          <Field label="Scheduled Date" value={data.scheduled_date} />
          <Field label="Inspection Date" value={data.inspection_date} />
          <Field label="Type ID" value={data.inspection_type_id} />
        </Section>

        <Section title="Inspector">
          <Field label="Inspector ID" value={data.inspector_id} />
          <Field label="Inspector Name" value={data.inspector_name} />
          <Field label="Inspector Title" value={data.inspector_title} />
        </Section>

        <Section title="Scope">
          <Field label="Areas Inspected" value={data.areas_inspected} />
        </Section>

        <Section title="Storm & Weather">
          <Field label="Storm Triggered" value={data.is_storm_triggered} />
          <Field label="Storm Date" value={data.storm_date} />
          <Field label="Rainfall (inches)" value={data.rainfall_inches} />
          <Field label="Weather" value={data.weather_conditions} />
          <Field label="Temperature (°F)" value={data.temperature_f} />
        </Section>

        <Section title="Outcome">
          <Field label="Status" value={status} />
          <Field label="Overall Result" value={data.overall_result} />
          <Field label="Summary Notes" value={data.summary_notes} />
        </Section>

        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider">
              Findings
            </h2>
            <button
              type="button"
              onClick={() => setFindingOpen(true)}
              className="h-8 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
            >
              + Add finding
            </button>
          </div>
          <FindingsList
            inspectionId={Number(id)}
            refreshKey={refreshKey}
            onClose={setCloseFindingId}
          />
        </div>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="inspections" entityId={id} />
      </div>

      {confirm && (
        <ConfirmDialog
          open
          title={confirm === 'complete' ? 'Mark inspection complete?' : 'Delete inspection?'}
          message={
            confirm === 'complete'
              ? 'This marks the inspection final. You can still edit afterward. Findings and corrective actions can be added before or after completion.'
              : 'Permanently deletes the inspection record. Associated findings may block the delete.'
          }
          confirmLabel={confirm === 'complete' ? 'Mark complete' : 'Delete'}
          destructive={confirm === 'delete'}
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}

      <FindingModal
        inspectionId={Number(id)}
        open={findingOpen}
        onClose={() => setFindingOpen(false)}
        onSaved={() => setRefreshKey(k => k + 1)}
      />
      <CloseFindingModal
        findingId={closeFindingId}
        open={closeFindingId !== null}
        onClose={() => setCloseFindingId(null)}
        onSaved={() => setRefreshKey(k => k + 1)}
      />
    </div>
  );
}
