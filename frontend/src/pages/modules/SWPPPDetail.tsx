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

type SWPPPRow = Record<string, unknown>;
type BMPRow = Record<string, unknown>;

interface PagedResult<T> {
  data: T[];
  total: number;
}

const BMP_TYPE_LABELS: Record<string, string> = {
  structural: 'Structural',
  non_structural: 'Non-structural',
};

const FREQUENCY_OPTIONS = [
  { value: '', label: '— not set —' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'monthly', label: 'Monthly' },
  { value: 'quarterly', label: 'Quarterly' },
  { value: 'annual', label: 'Annual' },
  { value: 'storm_event', label: 'After each storm event' },
  { value: 'continuous', label: 'Continuous' },
];

const BMP_TYPE_OPTIONS = [
  { value: 'structural', label: 'Structural' },
  { value: 'non_structural', label: 'Non-structural' },
];

// ============ BMP modal (add / edit a single BMP) ============

interface BMPModalProps {
  swpppId: number;
  establishmentId: number;
  editingBmp: BMPRow | null;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}

function BMPModal({ swpppId, establishmentId, editingBmp, open, onClose, onSaved }: BMPModalProps) {
  const [bmpCode, setBmpCode] = useState('');
  const [bmpName, setBmpName] = useState('');
  const [bmpType, setBmpType] = useState('structural');
  const [bmpSubtype, setBmpSubtype] = useState('');
  const [description, setDescription] = useState('');
  const [implementationDate, setImplementationDate] = useState('');
  const [inspectionFrequency, setInspectionFrequency] = useState('');
  const [inspectionFrequencyDays, setInspectionFrequencyDays] = useState('');
  const [responsibleRole, setResponsibleRole] = useState('');
  const [responsibleEmployeeId, setResponsibleEmployeeId] = useState<number | null>(null);
  const [notes, setNotes] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  // Reset / preload form whenever the "editingBmp" changes.
  useEffect(() => {
    if (editingBmp) {
      setBmpCode(String(editingBmp.bmp_code ?? ''));
      setBmpName(String(editingBmp.bmp_name ?? ''));
      setBmpType(String(editingBmp.bmp_type ?? 'structural'));
      setBmpSubtype(String(editingBmp.bmp_subtype ?? ''));
      setDescription(String(editingBmp.description ?? ''));
      setImplementationDate(String(editingBmp.implementation_date ?? ''));
      setInspectionFrequency(String(editingBmp.inspection_frequency ?? ''));
      setInspectionFrequencyDays(
        editingBmp.inspection_frequency_days == null
          ? ''
          : String(editingBmp.inspection_frequency_days),
      );
      setResponsibleRole(String(editingBmp.responsible_role ?? ''));
      setResponsibleEmployeeId((editingBmp.responsible_employee_id as number) ?? null);
      setNotes(String(editingBmp.notes ?? ''));
      setErr(null);
    } else {
      setBmpCode('');
      setBmpName('');
      setBmpType('structural');
      setBmpSubtype('');
      setDescription('');
      setImplementationDate('');
      setInspectionFrequency('');
      setInspectionFrequencyDays('');
      setResponsibleRole('');
      setResponsibleEmployeeId(null);
      setNotes('');
      setErr(null);
    }
  }, [editingBmp]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (!bmpCode.trim()) {
      setErr('BMP code is required.');
      return;
    }
    if (!bmpName.trim()) {
      setErr('BMP name is required.');
      return;
    }
    if (!description.trim()) {
      setErr('Description is required.');
      return;
    }
    const daysNum =
      inspectionFrequencyDays.trim() === ''
        ? null
        : parseInt(inspectionFrequencyDays, 10);
    if (daysNum !== null && Number.isNaN(daysNum)) {
      setErr('Inspection frequency days must be a number.');
      return;
    }
    const body = {
      swppp_id: swpppId,
      establishment_id: establishmentId,
      bmp_code: bmpCode.trim(),
      bmp_name: bmpName.trim(),
      bmp_type: bmpType,
      bmp_subtype: bmpSubtype.trim() || null,
      description: description.trim(),
      implementation_date: implementationDate || null,
      inspection_frequency: inspectionFrequency || null,
      inspection_frequency_days: daysNum,
      responsible_role: responsibleRole.trim() || null,
      responsible_employee_id: responsibleEmployeeId,
      notes: notes.trim() || null,
    };
    try {
      if (editingBmp) {
        await mutate('PUT', `/api/bmps/${editingBmp.id}`, body);
      } else {
        await mutate('POST', '/api/bmps', body);
      }
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to save');
    }
  }

  return (
    <Modal open={open} onClose={onClose} title={editingBmp ? 'Edit BMP' : 'Add BMP'} size="lg">
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormField
            label="BMP Code"
            required
            value={bmpCode}
            onChange={setBmpCode}
            placeholder="BMP-COVER-001"
            autoFocus
            hint="Unique per SWPPP."
          />
          <FormField
            label="BMP Name"
            required
            value={bmpName}
            onChange={setBmpName}
            placeholder="Cover outside material storage"
          />
          <FormField
            type="select"
            label="Type"
            required
            value={bmpType}
            onChange={setBmpType}
            options={BMP_TYPE_OPTIONS}
          />
          <FormField
            label="Subtype"
            value={bmpSubtype}
            onChange={setBmpSubtype}
            placeholder="secondary_containment, good_housekeeping, inspection"
            hint="Free-form category tag."
          />
          <div className="md:col-span-2">
            <FormField
              type="textarea"
              label="Description"
              required
              value={description}
              onChange={setDescription}
              rows={3}
              placeholder="What this BMP does and how it's implemented."
            />
          </div>
          <FormField
            type="date"
            label="Implementation Date"
            value={implementationDate}
            onChange={setImplementationDate}
          />
          <div />
          <FormField
            type="select"
            label="Inspection Frequency"
            value={inspectionFrequency}
            onChange={setInspectionFrequency}
            options={FREQUENCY_OPTIONS}
          />
          <FormField
            type="number"
            label="Inspection Frequency (days)"
            value={inspectionFrequencyDays}
            onChange={setInspectionFrequencyDays}
            hint="Numeric form for scheduling (7 for weekly, 30 for monthly, etc.)."
          />
          <FormField
            label="Responsible Role"
            value={responsibleRole}
            onChange={setResponsibleRole}
            placeholder="EHS Manager, Facility Operator"
          />
          <div className="flex flex-col gap-1.5">
            <label className="text-xs text-[var(--color-fg)]">Responsible Employee</label>
            <EntitySelector
              entity="employees"
              value={responsibleEmployeeId}
              onChange={setResponsibleEmployeeId}
              renderLabel={(row) =>
                `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`
              }
              placeholder="Optional — specific person..."
            />
          </div>
        </div>
        <FormField type="textarea" label="Notes" value={notes} onChange={setNotes} rows={2} />
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
            {loading ? 'Saving...' : editingBmp ? 'Save BMP' : 'Add BMP'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============ BMP list (nested sub-collection) ============

function BMPList({
  swpppId,
  refreshKey,
  onEdit,
  onDeleted,
}: {
  swpppId: number;
  refreshKey: number;
  onEdit: (bmp: BMPRow) => void;
  onDeleted: () => void;
}) {
  const [rows, setRows] = useState<BMPRow[] | null>(null);
  const [deleting, setDeleting] = useState<number | null>(null);
  const { mutate } = useEntityMutation();

  const refresh = useCallback(() => {
    api
      .get<PagedResult<BMPRow>>('/api/bmps?per_page=500')
      .then((r) => setRows((r.data ?? []).filter((x) => (x.swppp_id as number) === swpppId)))
      .catch(() => setRows([]));
  }, [swpppId]);

  useEffect(() => {
    refresh();
  }, [refresh, refreshKey]);

  async function deleteBmp(bmpId: number) {
    if (!confirm('Delete this BMP?')) return;
    setDeleting(bmpId);
    try {
      await mutate('DELETE', `/api/bmps/${bmpId}`);
      onDeleted();
    } finally {
      setDeleting(null);
    }
  }

  if (rows === null) {
    return <p className="text-xs text-[var(--color-comment)]">Loading…</p>;
  }
  if (rows.length === 0) {
    return (
      <p className="text-xs text-[var(--color-comment)]">
        No BMPs recorded yet. Click <strong>Add BMP</strong> above to describe the first
        one.
      </p>
    );
  }
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b border-[var(--color-current-line)]">
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            Code
          </th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            Name
          </th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            Type
          </th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            Inspection
          </th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            Responsible
          </th>
          <th className="text-right py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            &nbsp;
          </th>
        </tr>
      </thead>
      <tbody>
        {rows.map((b) => {
          const bmpType = String(b.bmp_type ?? '');
          return (
            <tr key={String(b.id)} className="border-b border-[var(--color-current-line)] last:border-b-0">
              <td className="py-2 text-[var(--color-fg)] font-mono text-xs">
                {String(b.bmp_code ?? '—')}
              </td>
              <td className="py-2 text-[var(--color-fg)]">{String(b.bmp_name ?? '—')}</td>
              <td className="py-2 text-xs">
                <span
                  className="px-2 py-0.5 rounded"
                  style={{
                    background:
                      bmpType === 'structural'
                        ? 'color-mix(in srgb, var(--color-fn-blue) 15%, transparent)'
                        : 'color-mix(in srgb, var(--color-fn-cyan) 15%, transparent)',
                    color:
                      bmpType === 'structural'
                        ? 'var(--color-fn-blue)'
                        : 'var(--color-fn-cyan)',
                  }}
                >
                  {BMP_TYPE_LABELS[bmpType] ?? bmpType}
                </span>
                {Boolean(b.bmp_subtype) && (
                  <span className="text-[10px] text-[var(--color-comment)] ml-2">
                    {String(b.bmp_subtype)}
                  </span>
                )}
              </td>
              <td className="py-2 text-[var(--color-fg)] text-xs capitalize">
                {String(b.inspection_frequency ?? '—').replace('_', ' ')}
              </td>
              <td className="py-2 text-[var(--color-comment)] text-xs">
                {String(b.responsible_role ?? '—')}
              </td>
              <td className="py-2 text-right">
                <button
                  type="button"
                  onClick={() => onEdit(b)}
                  className="text-[10px] text-[var(--color-purple)] hover:underline cursor-pointer bg-transparent border-none mr-3"
                >
                  Edit
                </button>
                <button
                  type="button"
                  onClick={() => deleteBmp(b.id as number)}
                  disabled={deleting === (b.id as number)}
                  className="text-[10px] text-[var(--color-fn-red)] hover:underline disabled:opacity-50 cursor-pointer bg-transparent border-none"
                >
                  {deleting === (b.id as number) ? 'Deleting…' : 'Delete'}
                </button>
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}

// ============ Detail page ============

export default function SWPPPDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<SWPPPRow>(`/api/swpps/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'delete'>(null);
  const [bmpModalOpen, setBmpModalOpen] = useState(false);
  const [editingBmp, setEditingBmp] = useState<BMPRow | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      await mutate('DELETE', `/api/swpps/${id}`);
      navigate('/swpps');
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
        <p className="text-sm">{notFound ? 'SWPPP not found.' : `Error: ${error}`}</p>
        <button
          onClick={() => navigate('/swpps')}
          className="text-xs text-[var(--color-purple)] hover:underline"
        >
          ← Back to SWPPPs
        </button>
      </div>
    );
  }

  const status = String(data.status ?? 'active').toLowerCase();
  const swpppIdNum = data.id as number;
  const establishmentId = data.establishment_id as number;

  const nextReviewStr = String(data.next_annual_review_due ?? '');
  const daysUntilReview = nextReviewStr
    ? Math.ceil((new Date(nextReviewStr).getTime() - Date.now()) / 86_400_000)
    : null;
  const reviewWarning =
    daysUntilReview !== null && daysUntilReview <= 30
      ? daysUntilReview < 0
        ? 'Annual review overdue'
        : `Annual review due in ${daysUntilReview} day${daysUntilReview === 1 ? '' : 's'}`
      : null;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6 flex-wrap">
        <button
          onClick={() => navigate('/swpps')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← SWPPPs
        </button>
        <div>
          <p className="text-xs text-[var(--color-comment)] mb-0.5">
            {String(data.revision_number ?? '')}
          </p>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">
            SWPPP — eff. {String(data.effective_date ?? '')}
          </h1>
        </div>
        <span className="text-xs font-medium px-2 py-0.5 rounded-full capitalize bg-[var(--color-current-line)] text-[var(--color-fg)]">
          {status}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/swpps/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
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

      {!!reviewWarning && (
        <div
          className={`rounded-xl border px-5 py-4 mb-4 ${
            daysUntilReview !== null && daysUntilReview < 0
              ? 'bg-[var(--color-fn-red)]/10 border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)]'
              : 'bg-[var(--color-fn-orange)]/10 border-[var(--color-fn-orange)]/30 text-[var(--color-fn-orange)]'
          }`}
        >
          <p className="text-sm font-medium">⏰ {reviewWarning}</p>
        </div>
      )}

      <div className="flex flex-col gap-4">
        <Section title="Revision">
          <Field label="Revision Number" value={data.revision_number} />
          <Field label="Effective Date" value={data.effective_date} />
          <Field label="Supersedes Revision" value={data.supersedes_swppp_id} />
          <Field label="Status" value={status} />
        </Section>

        <Section title="Review Cadence">
          <Field label="Last Annual Review" value={data.last_annual_review_date} />
          <Field label="Next Review Due" value={data.next_annual_review_due} />
        </Section>

        <Section title="Permit & Team">
          <Field label="Governing Permit" value={data.permit_id} />
          <Field label="Team Lead" value={data.pollution_prevention_team_lead_employee_id} />
          <Field label="Team" value={data.pollution_prevention_team} />
        </Section>

        <Section title="Document">
          <Field label="Document Path" value={data.document_path} />
        </Section>

        <Section title="Narrative">
          <Field label="Site Description" value={data.site_description_summary} />
          <Field label="Industrial Activities" value={data.industrial_activities_summary} />
        </Section>

        {/* BMPs sub-collection */}
        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-lg font-semibold text-[var(--color-purple)] mb-0.5">
                Best Management Practices
              </h2>
              <p className="text-xs text-[var(--color-comment)]">
                BMPs this SWPPP implements (ehs:implements). Add structural controls
                (containment, berms) and non-structural ones (housekeeping, training).
              </p>
            </div>
            <button
              type="button"
              onClick={() => {
                setEditingBmp(null);
                setBmpModalOpen(true);
              }}
              className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
            >
              + Add BMP
            </button>
          </div>
          <BMPList
            swpppId={swpppIdNum}
            refreshKey={refreshKey}
            onEdit={(bmp) => {
              setEditingBmp(bmp);
              setBmpModalOpen(true);
            }}
            onDeleted={() => setRefreshKey((k) => k + 1)}
          />
        </div>

        <Section title="Notes">
          <Field label="Notes" value={data.notes} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="swpps" entityId={id} />
      </div>

      <BMPModal
        swpppId={swpppIdNum}
        establishmentId={establishmentId}
        editingBmp={editingBmp}
        open={bmpModalOpen}
        onClose={() => {
          setBmpModalOpen(false);
          setEditingBmp(null);
        }}
        onSaved={() => setRefreshKey((k) => k + 1)}
      />

      {confirm && (
        <ConfirmDialog
          open
          title="Delete SWPPP?"
          message="Permanently deletes this SWPPP revision. Any BMPs that reference it may block the delete — create a new revision (with supersedes link) instead of deleting live ones."
          confirmLabel="Delete"
          destructive
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
