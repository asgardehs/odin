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

type AuditRow = Record<string, unknown>;
type Row = Record<string, unknown>;

interface PagedResult<T> { data: T[]; total: number; }

const findingTypeOptions = [
  { value: 'major_nc', label: 'Major nonconformity' },
  { value: 'minor_nc', label: 'Minor nonconformity' },
  { value: 'ofi', label: 'Opportunity for improvement' },
  { value: 'observation', label: 'Observation' },
  { value: 'positive', label: 'Positive finding' },
];

const riskOptions = [
  { value: '', label: '—' },
  { value: 'high', label: 'High' },
  { value: 'medium', label: 'Medium' },
  { value: 'low', label: 'Low' },
];

const FINDING_TYPE_COLORS: Record<string, string> = {
  major_nc: 'var(--color-fn-red)',
  minor_nc: 'var(--color-fn-yellow)',
  ofi: 'var(--color-fn-cyan)',
  observation: 'var(--color-comment)',
  positive: 'var(--color-fn-green)',
};

const FINDING_TYPE_LABELS: Record<string, string> = {
  major_nc: 'Major NC',
  minor_nc: 'Minor NC',
  ofi: 'OFI',
  observation: 'Observation',
  positive: 'Positive',
};

// ============ Finding modal ============

function FindingModal({
  auditId, open, onClose, onSaved,
}: {
  auditId: number;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [findingNumber, setFindingNumber] = useState('');
  const [findingType, setFindingType] = useState('minor_nc');
  const [clauseNumber, setClauseNumber] = useState('');
  const [clauseTitle, setClauseTitle] = useState('');
  const [requirementStatement, setRequirementStatement] = useState('');
  const [findingStatement, setFindingStatement] = useState('');
  const [processArea, setProcessArea] = useState('');
  const [evidenceDescription, setEvidenceDescription] = useState('');
  const [riskLevel, setRiskLevel] = useState('');
  const [isRepeat, setIsRepeat] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  function reset() {
    setFindingNumber('');
    setFindingType('minor_nc');
    setClauseNumber('');
    setClauseTitle('');
    setRequirementStatement('');
    setFindingStatement('');
    setProcessArea('');
    setEvidenceDescription('');
    setRiskLevel('');
    setIsRepeat(false);
    setErr(null);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!findingNumber.trim()) { setErr('Finding number is required.'); return; }
    if (!findingStatement.trim()) { setErr('Finding statement is required.'); return; }
    try {
      await mutate('POST', '/api/audit-findings', {
        audit_id: auditId,
        finding_number: findingNumber.trim(),
        finding_type: findingType,
        clause_number: clauseNumber.trim() || null,
        clause_title: clauseTitle.trim() || null,
        requirement_statement: requirementStatement.trim() || null,
        finding_statement: findingStatement.trim(),
        process_area: processArea.trim() || null,
        evidence_description: evidenceDescription.trim() || null,
        risk_level: riskLevel || null,
        is_repeat_finding: isRepeat ? 1 : 0,
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
          <FormField label="Finding Number" required value={findingNumber} onChange={setFindingNumber}
            placeholder="e.g. MAJ-001, F1" />
          <FormField type="select" label="Type" required value={findingType} onChange={setFindingType}
            options={findingTypeOptions} />
          <FormField label="Clause Number" value={clauseNumber} onChange={setClauseNumber}
            placeholder="e.g. 7.2, 9.2.2" />
          <FormField label="Clause Title" value={clauseTitle} onChange={setClauseTitle}
            placeholder="e.g. Competence" />
        </div>
        <FormField type="textarea" label="Requirement Statement" value={requirementStatement}
          onChange={setRequirementStatement} rows={2}
          placeholder="What does the standard require?" />
        <FormField type="textarea" label="Finding Statement" required value={findingStatement}
          onChange={setFindingStatement} rows={3}
          placeholder="Objective evidence of the finding" />
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormField label="Process Area" value={processArea} onChange={setProcessArea}
            placeholder="Where the finding was identified" />
          <FormField type="select" label="Risk Level" value={riskLevel} onChange={setRiskLevel}
            options={riskOptions} />
        </div>
        <FormField type="textarea" label="Evidence / Documents Reviewed" value={evidenceDescription}
          onChange={setEvidenceDescription} rows={2}
          placeholder="Records, interviews, observations that support this finding" />
        <label className="flex items-center gap-2 cursor-pointer select-none">
          <input
            type="checkbox"
            checked={isRepeat}
            onChange={e => setIsRepeat(e.target.checked)}
            className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
          />
          <span className="text-sm text-[var(--color-fg)]">Repeat finding from a prior audit</span>
        </label>
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

// ============ Verify finding modal ============

function VerifyFindingModal({
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
      await mutate('POST', `/api/audit-findings/${findingId}/verify`, {
        notes: notes.trim() || null,
      });
      setNotes('');
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to verify');
    }
  }

  return (
    <Modal open={open} onClose={() => { setNotes(''); onClose(); }} title="Verify finding" size="md">
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        <FormField type="textarea" label="Verification Notes" value={notes} onChange={setNotes} rows={3}
          placeholder="Evidence that the corrective action was effective" />
        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button type="button" onClick={() => { setNotes(''); onClose(); }} disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50">
            Cancel
          </button>
          <button type="submit" disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50">
            {loading ? 'Verifying...' : 'Verify finding'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============ Findings list ============

function FindingsList({
  auditId, refreshKey, onVerify,
}: {
  auditId: number;
  refreshKey: number;
  onVerify: (findingId: number) => void;
}) {
  const [rows, setRows] = useState<Row[] | null>(null);

  const refresh = useCallback(() => {
    api.get<PagedResult<Row>>('/api/audit-findings?per_page=500')
      .then(r => setRows((r.data ?? []).filter(x => (x.audit_id as number) === auditId)))
      .catch(() => setRows([]));
  }, [auditId]);

  useEffect(() => { refresh(); }, [refresh, refreshKey]);

  if (rows === null) return <p className="text-xs text-[var(--color-comment)]">Loading…</p>;
  if (rows.length === 0) return <p className="text-xs text-[var(--color-comment)]">No findings recorded yet.</p>;
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b border-[var(--color-current-line)]">
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">#</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Type</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Clause</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Statement</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Status</th>
          <th className="py-2"></th>
        </tr>
      </thead>
      <tbody>
        {rows.map(r => {
          const status = String(r.status ?? 'open');
          const findingType = String(r.finding_type ?? 'observation');
          const color = FINDING_TYPE_COLORS[findingType] ?? 'var(--color-comment)';
          const typeLabel = FINDING_TYPE_LABELS[findingType] ?? findingType;
          const stmt = String(r.finding_statement ?? '');
          const clause = r.clause_number
            ? `${r.clause_number}${r.clause_title ? ' — ' + r.clause_title : ''}`
            : '—';
          return (
            <tr key={String(r.id)} className="border-b border-[var(--color-current-line)] last:border-b-0 align-top">
              <td className="py-2 text-[var(--color-fg)]">{String(r.finding_number ?? '—')}</td>
              <td className="py-2">
                <span style={{ color }} className="text-xs font-medium">{typeLabel}</span>
              </td>
              <td className="py-2 text-[var(--color-fg)] text-xs">{clause}</td>
              <td className="py-2 text-[var(--color-fg)] max-w-md">
                {stmt.length > 120 ? stmt.slice(0, 120) + '…' : stmt}
                {r.verified_date ? (
                  <span className="block text-xs text-[var(--color-comment)] mt-1">
                    Verified {formatDate(r.verified_date as string)}
                  </span>
                ) : null}
              </td>
              <td className="py-2 text-[var(--color-fg)] capitalize">{status.replace(/_/g, ' ')}</td>
              <td className="py-2 text-right">
                {status !== 'verified' && status !== 'closed' && (
                  <button
                    type="button"
                    onClick={() => onVerify(Number(r.id))}
                    className="h-7 px-2 rounded-md bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
                  >
                    Verify
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

export default function AuditDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<AuditRow>(`/api/audits/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'close' | 'delete'>(null);
  const [findingOpen, setFindingOpen] = useState(false);
  const [verifyFindingId, setVerifyFindingId] = useState<number | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'close') {
        await mutate('POST', `/api/audits/${id}/close`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/audits/${id}`);
        navigate('/audits');
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
        <p className="text-sm">{notFound ? 'Audit not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/audits')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Audits
        </button>
      </div>
    );
  }

  const status = String(data.status ?? 'planned').toLowerCase();
  const canClose = status !== 'closed';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/audits')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Audits
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">
          {String(data.audit_title ?? 'Audit')}
        </h1>
        <span className="text-xs font-medium px-2 py-0.5 rounded-full capitalize bg-[var(--color-current-line)] text-[var(--color-fg)]">
          {status.replace(/_/g, ' ')}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/audits/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {canClose && (
            <button
              type="button"
              onClick={() => setConfirm('close')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Close audit
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
        <Section title="Identity">
          <Field label="Audit #" value={data.audit_number} />
          <Field label="Title" value={data.audit_title} />
          <Field label="Type" value={String(data.audit_type ?? '').replace(/_/g, ' ')} />
        </Section>

        <Section title="Standards">
          <Field label="Primary Standard ID" value={data.standard_id} />
          <Field label="Integrated Audit" value={data.is_integrated_audit} />
          <Field label="Additional Standards" value={data.additional_standard_ids} />
          <Field label="Registrar" value={data.registrar_name} />
          <Field label="Certificate #" value={data.certificate_number} />
        </Section>

        <Section title="Dates">
          <Field label="Scheduled Start" value={data.scheduled_start_date} />
          <Field label="Scheduled End" value={data.scheduled_end_date} />
          <Field label="Actual Start" value={data.actual_start_date} />
          <Field label="Actual End" value={data.actual_end_date} />
        </Section>

        <Section title="Lead Auditor">
          <Field label="Employee ID" value={data.lead_auditor_id} />
          <Field label="Name" value={data.lead_auditor_name} />
          <Field label="Company" value={data.lead_auditor_company} />
        </Section>

        <Section title="Scope">
          <Field label="Scope Description" value={data.scope_description} />
          <Field label="Exclusions" value={data.exclusions} />
          <Field label="Objectives" value={data.audit_objectives} />
          <Field label="Criteria" value={data.audit_criteria} />
        </Section>

        <Section title="Results Summary">
          <Field label="Total Findings" value={data.total_findings} />
          <Field label="Major NCs" value={data.major_nonconformities} />
          <Field label="Minor NCs" value={data.minor_nonconformities} />
          <Field label="OFIs" value={data.opportunities_for_improvement} />
          <Field label="Positive" value={data.positive_findings} />
          <Field label="Recommendation" value={data.recommendation} />
        </Section>

        <Section title="Report">
          <Field label="Executive Summary" value={data.executive_summary} />
          <Field label="Conclusion" value={data.conclusion} />
          <Field label="Report Date" value={data.report_date} />
          <Field label="Report File Reference" value={data.report_file_reference} />
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
            auditId={Number(id)}
            refreshKey={refreshKey}
            onVerify={setVerifyFindingId}
          />
        </div>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="audits" entityId={id} />
      </div>

      {confirm && (
        <ConfirmDialog
          open
          title={confirm === 'close' ? 'Close audit?' : 'Delete audit?'}
          message={
            confirm === 'close'
              ? 'Marks the audit closed. Findings can still be verified afterward, and you can reopen by editing the status field if needed.'
              : 'Permanently deletes the audit record. Associated findings may block the delete.'
          }
          confirmLabel={confirm === 'close' ? 'Close audit' : 'Delete'}
          destructive={confirm === 'delete'}
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}

      <FindingModal
        auditId={Number(id)}
        open={findingOpen}
        onClose={() => setFindingOpen(false)}
        onSaved={() => setRefreshKey(k => k + 1)}
      />
      <VerifyFindingModal
        findingId={verifyFindingId}
        open={verifyFindingId !== null}
        onClose={() => setVerifyFindingId(null)}
        onSaved={() => setRefreshKey(k => k + 1)}
      />
    </div>
  );
}
