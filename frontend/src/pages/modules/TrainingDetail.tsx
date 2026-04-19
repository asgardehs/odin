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
import { formatDate } from '../../utils/date';

type TrainingRow = Record<string, unknown>;
type Row = Record<string, unknown>;

interface PagedResult<T> {
  data: T[];
  total: number;
}

function durationLabel(mins: unknown): string {
  const m = typeof mins === 'number' ? mins : Number(mins);
  if (!Number.isFinite(m) || m <= 0) return '—';
  return m >= 60 ? `${Math.floor(m / 60)}h ${m % 60}m` : `${m}m`;
}

// ============ Log Completion modal ============

function LogCompletionModal({
  courseId,
  validityMonths,
  open,
  onClose,
  onSaved,
}: {
  courseId: number;
  validityMonths: number | null;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [employeeId, setEmployeeId] = useState<number | null>(null);
  const [completionDate, setCompletionDate] = useState('');
  const [expirationDate, setExpirationDate] = useState('');
  const [score, setScore] = useState('');
  const [passed, setPassed] = useState(true);
  const [instructor, setInstructor] = useState('');
  const [location, setLocation] = useState('');
  const [certificateNumber, setCertificateNumber] = useState('');
  const [notes, setNotes] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [expirationTouched, setExpirationTouched] = useState(false);
  const { mutate, loading } = useEntityMutation();

  function reset() {
    setEmployeeId(null);
    setCompletionDate('');
    setExpirationDate('');
    setScore('');
    setPassed(true);
    setInstructor('');
    setLocation('');
    setCertificateNumber('');
    setNotes('');
    setErr(null);
    setExpirationTouched(false);
  }

  // Auto-fill expiration from completion + validity_months when the user
  // hasn't overridden it.
  useEffect(() => {
    if (expirationTouched) return;
    if (!completionDate || !validityMonths) {
      setExpirationDate('');
      return;
    }
    const d = new Date(completionDate + 'T00:00:00Z');
    if (Number.isNaN(d.getTime())) return;
    d.setUTCMonth(d.getUTCMonth() + validityMonths);
    setExpirationDate(d.toISOString().slice(0, 10));
  }, [completionDate, validityMonths, expirationTouched]);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (employeeId == null) { setErr('Employee is required.'); return; }
    if (!completionDate) { setErr('Completion date is required.'); return; }
    const body: Record<string, unknown> = {
      employee_id: employeeId,
      course_id: courseId,
      completion_date: completionDate,
      expiration_date: expirationDate || null,
      score: score === '' ? null : Number(score),
      passed: passed ? 1 : 0,
      instructor: instructor.trim() || null,
      location: location.trim() || null,
      certificate_number: certificateNumber.trim() || null,
      notes: notes.trim() || null,
    };
    try {
      await mutate('POST', '/api/training/completions', body);
      reset();
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to save');
    }
  }

  return (
    <Modal open={open} onClose={() => { reset(); onClose(); }} title="Log completion" size="lg">
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
          <FormField type="date" label="Completion Date" required value={completionDate} onChange={setCompletionDate} />
          <FormField
            type="date"
            label="Expiration Date"
            value={expirationDate}
            onChange={v => { setExpirationDate(v); setExpirationTouched(true); }}
            hint={validityMonths ? `Auto-filled +${validityMonths}mo from completion.` : undefined}
          />
          <FormField type="number" label="Score" value={score} onChange={setScore} />
          <FormField label="Instructor" value={instructor} onChange={setInstructor} />
          <FormField label="Location" value={location} onChange={setLocation} />
          <FormField label="Certificate Number" value={certificateNumber} onChange={setCertificateNumber} />
          <label className="flex items-center gap-2 h-10 cursor-pointer select-none">
            <input
              type="checkbox"
              checked={passed}
              onChange={e => setPassed(e.target.checked)}
              className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
            />
            <span className="text-sm text-[var(--color-fg)]">Passed</span>
          </label>
        </div>
        <FormField type="textarea" label="Notes" value={notes} onChange={setNotes} rows={2} />
        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button
            type="button"
            onClick={() => { reset(); onClose(); }}
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Saving...' : 'Log completion'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============ Assign course modal ============

function AssignCourseModal({
  courseId,
  open,
  onClose,
  onSaved,
}: {
  courseId: number;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [employeeId, setEmployeeId] = useState<number | null>(null);
  const [dueDate, setDueDate] = useState('');
  const [priority, setPriority] = useState('normal');
  const [assignedBy, setAssignedBy] = useState('');
  const [reason, setReason] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  function reset() {
    setEmployeeId(null);
    setDueDate('');
    setPriority('normal');
    setAssignedBy('');
    setReason('');
    setErr(null);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (employeeId == null) { setErr('Employee is required.'); return; }
    const body: Record<string, unknown> = {
      employee_id: employeeId,
      course_id: courseId,
      due_date: dueDate || null,
      priority: priority || null,
      assigned_by: assignedBy.trim() || null,
      reason: reason.trim() || null,
    };
    try {
      await mutate('POST', '/api/training/assignments', body);
      reset();
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to save');
    }
  }

  return (
    <Modal open={open} onClose={() => { reset(); onClose(); }} title="Assign course" size="md">
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
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormField type="date" label="Due Date" value={dueDate} onChange={setDueDate} />
          <FormField
            type="select"
            label="Priority"
            value={priority}
            onChange={setPriority}
            options={[
              { value: 'low', label: 'Low' },
              { value: 'normal', label: 'Normal' },
              { value: 'high', label: 'High' },
            ]}
          />
          <FormField
            label="Assigned By"
            value={assignedBy}
            onChange={setAssignedBy}
            placeholder="Defaults to current user if blank"
          />
        </div>
        <FormField
          type="textarea"
          label="Reason"
          value={reason}
          onChange={setReason}
          rows={2}
          placeholder="e.g. New hire, annual refresher, incident follow-up"
        />
        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button
            type="button"
            onClick={() => { reset(); onClose(); }}
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Saving...' : 'Assign'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============ Sub-record lists ============

function CompletionsList({ courseId, refreshKey }: { courseId: number; refreshKey: number }) {
  const [rows, setRows] = useState<Row[] | null>(null);

  // Backend doesn't filter by course yet — fetch all and filter client-side.
  // Acceptable for now; a course_id filter is a follow-up.
  const refresh = useCallback(() => {
    api.get<PagedResult<Row>>('/api/training/completions?per_page=500')
      .then(r => setRows((r.data ?? []).filter(x => (x.course_id as number) === courseId)))
      .catch(() => setRows([]));
  }, [courseId]);

  useEffect(() => { refresh(); }, [refresh, refreshKey]);

  if (rows === null) return <p className="text-xs text-[var(--color-comment)]">Loading…</p>;
  if (rows.length === 0) return <p className="text-xs text-[var(--color-comment)]">No completions recorded yet.</p>;
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b border-[var(--color-current-line)]">
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Employee</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Completed</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Expires</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Score</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Passed</th>
        </tr>
      </thead>
      <tbody>
        {rows.map(r => (
          <tr key={String(r.id)} className="border-b border-[var(--color-current-line)] last:border-b-0">
            <td className="py-2 text-[var(--color-fg)]">#{String(r.employee_id)}</td>
            <td className="py-2 text-[var(--color-fg)]">{formatDate(r.completion_date as string)}</td>
            <td className="py-2 text-[var(--color-fg)]">{r.expiration_date ? formatDate(r.expiration_date as string) : '—'}</td>
            <td className="py-2 text-[var(--color-fg)]">{r.score == null ? '—' : String(r.score)}</td>
            <td className="py-2 text-[var(--color-fg)]">{r.passed ? 'Yes' : 'No'}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function AssignmentsList({ courseId, refreshKey }: { courseId: number; refreshKey: number }) {
  const [rows, setRows] = useState<Row[] | null>(null);

  const refresh = useCallback(() => {
    api.get<PagedResult<Row>>('/api/training/assignments?per_page=500')
      .then(r => setRows((r.data ?? []).filter(x => (x.course_id as number) === courseId)))
      .catch(() => setRows([]));
  }, [courseId]);

  useEffect(() => { refresh(); }, [refresh, refreshKey]);

  if (rows === null) return <p className="text-xs text-[var(--color-comment)]">Loading…</p>;
  if (rows.length === 0) return <p className="text-xs text-[var(--color-comment)]">No outstanding assignments.</p>;
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b border-[var(--color-current-line)]">
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Employee</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Due</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Priority</th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Status</th>
        </tr>
      </thead>
      <tbody>
        {rows.map(r => (
          <tr key={String(r.id)} className="border-b border-[var(--color-current-line)] last:border-b-0">
            <td className="py-2 text-[var(--color-fg)]">#{String(r.employee_id)}</td>
            <td className="py-2 text-[var(--color-fg)]">{r.due_date ? formatDate(r.due_date as string) : '—'}</td>
            <td className="py-2 text-[var(--color-fg)] capitalize">{String(r.priority ?? '—')}</td>
            <td className="py-2 text-[var(--color-fg)] capitalize">{String(r.status ?? '—')}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// ============ Detail page ============

export default function TrainingDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<TrainingRow>(`/api/training/courses/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'delete'>(null);
  const [logOpen, setLogOpen] = useState(false);
  const [assignOpen, setAssignOpen] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);

  async function runDelete() {
    if (!id) return;
    try {
      await mutate('DELETE', `/api/training/courses/${id}`);
      navigate('/training');
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
        <p className="text-sm">{notFound ? 'Training course not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/training')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Training
        </button>
      </div>
    );
  }

  const courseId = Number(id);
  const validityMonths = data.validity_months == null ? null : Number(data.validity_months);

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/training')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Training
        </button>
        <div>
          <p className="text-xs text-[var(--color-comment)] mb-0.5">{String(data.course_code ?? '')}</p>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">
            {String(data.course_name ?? 'Course')}
          </h1>
        </div>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/training/${id}/edit`)}
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

      <div className="flex flex-col gap-4">
        <Section title="Course Info">
          <Field label="Course Code" value={data.course_code} />
          <Field label="Course Name" value={data.course_name} />
          <Field label="Duration" value={durationLabel(data.duration_minutes)} />
          <Field label="Delivery Method" value={data.delivery_method} />
          <Field label="Validity (months)" value={data.validity_months} />
          <Field label="External" value={data.is_external ? 'Yes' : 'No'} />
          {!!data.is_external && <Field label="Vendor" value={data.vendor_name} />}
        </Section>

        {!!data.description && (
          <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
            <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider mb-3">
              Description
            </h2>
            <p className="text-sm text-[var(--color-fg)] whitespace-pre-wrap">
              {String(data.description)}
            </p>
          </div>
        )}

        <Section title="Assessment">
          <Field label="Has Test" value={data.has_test ? 'Yes' : 'No'} />
          <Field label="Passing Score" value={data.passing_score} />
        </Section>

        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider">
              Completions
            </h2>
            <button
              type="button"
              onClick={() => setLogOpen(true)}
              className="h-8 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
            >
              + Log completion
            </button>
          </div>
          <CompletionsList courseId={courseId} refreshKey={refreshKey} />
        </div>

        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider">
              Assignments
            </h2>
            <button
              type="button"
              onClick={() => setAssignOpen(true)}
              className="h-8 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
            >
              + Assign course
            </button>
          </div>
          <AssignmentsList courseId={courseId} refreshKey={refreshKey} />
        </div>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>

      <LogCompletionModal
        courseId={courseId}
        validityMonths={validityMonths}
        open={logOpen}
        onClose={() => setLogOpen(false)}
        onSaved={() => setRefreshKey(k => k + 1)}
      />
      <AssignCourseModal
        courseId={courseId}
        open={assignOpen}
        onClose={() => setAssignOpen(false)}
        onSaved={() => setRefreshKey(k => k + 1)}
      />

      {confirm && (
        <ConfirmDialog
          open
          title="Delete course?"
          message="Permanently deletes the course. Completions and assignments for this course may block the delete — or cascade, depending on the backend constraint."
          confirmLabel="Delete"
          destructive
          loading={mutating}
          onConfirm={runDelete}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
