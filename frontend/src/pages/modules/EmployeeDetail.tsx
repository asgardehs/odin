import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import { AuditHistory } from '../../components/AuditHistory';

type EmployeeRow = Record<string, unknown>;

export default function EmployeeDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<EmployeeRow>(`/api/employees/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'deactivate' | 'reactivate' | 'delete'>(null);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'deactivate') {
        await mutate('POST', `/api/employees/${id}/deactivate`);
        window.location.reload();
      } else if (confirm === 'reactivate') {
        await mutate('POST', `/api/employees/${id}/reactivate`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/employees/${id}`);
        navigate('/employees');
      }
    } catch {
      // mutateError surfaces in the page
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
        <p className="text-sm">{notFound ? 'Employee not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/employees')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Employees
        </button>
      </div>
    );
  }

  const fullName = [data.first_name, data.last_name].filter(Boolean).join(' ') || 'Employee';
  const active = Boolean(data.is_active);

  const confirmConfig = {
    deactivate: {
      title: 'Deactivate employee?',
      message: 'This employee will be marked inactive and a termination date of today will be recorded.',
      confirmLabel: 'Deactivate',
      destructive: true,
    },
    reactivate: {
      title: 'Reactivate employee?',
      message: 'This employee will be marked active again and the termination date will be cleared.',
      confirmLabel: 'Reactivate',
      destructive: false,
    },
    delete: {
      title: 'Delete employee?',
      message:
        'This permanently deletes the employee and is not reversible. If the employee has related records (incidents, training, PPE), the delete will fail — deactivate instead.',
      confirmLabel: 'Delete',
      destructive: true,
    },
  };

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/employees')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Employees
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">{fullName}</h1>
        <span
          className={`text-xs font-medium px-2 py-0.5 rounded-full ${
            active
              ? 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]'
              : 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
          }`}
        >
          {active ? 'Active' : 'Inactive'}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/employees/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {isAdmin && (active ? (
            <button
              type="button"
              onClick={() => setConfirm('deactivate')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Deactivate
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setConfirm('reactivate')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Reactivate
            </button>
          ))}
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
          <Field label="First Name" value={data.first_name} />
          <Field label="Last Name" value={data.last_name} />
          <Field label="Employee #" value={data.employee_number} />
          <Field label="Gender" value={data.gender} />
          <Field label="Date of Birth" value={data.date_of_birth} />
        </Section>

        <Section title="Employment">
          <Field label="Job Title" value={data.job_title} />
          <Field label="Department" value={data.department} />
          <Field label="Supervisor" value={data.supervisor_name} />
          <Field label="Date Hired" value={data.date_hired} />
          <Field label="Termination Date" value={data.termination_date} />
        </Section>

        <Section title="Address">
          <Field label="Street Address" value={data.street_address} />
          <Field label="City" value={data.city} />
          <Field label="State" value={data.state} />
          <Field label="ZIP Code" value={data.zip} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="employees" entityId={id} />
      </div>

      {confirm && (
        <ConfirmDialog
          open
          title={confirmConfig[confirm].title}
          message={confirmConfig[confirm].message}
          confirmLabel={confirmConfig[confirm].confirmLabel}
          destructive={confirmConfig[confirm].destructive}
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
