import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import { AuditHistory } from '../../components/AuditHistory';

type EstablishmentRow = Record<string, unknown>;

export default function EstablishmentDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<EstablishmentRow>(`/api/establishments/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'deactivate' | 'reactivate' | 'delete'>(null);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'deactivate') {
        await mutate('POST', `/api/establishments/${id}/deactivate`);
        window.location.reload();
      } else if (confirm === 'reactivate') {
        await mutate('POST', `/api/establishments/${id}/reactivate`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/establishments/${id}`);
        navigate('/establishments');
      }
    } catch {
      // mutateError surfaces in the dialog
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
        <p className="text-sm">{notFound ? 'Facility not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/establishments')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Facilities
        </button>
      </div>
    );
  }

  const active = Boolean(data.is_active);

  const confirmConfig = {
    deactivate: {
      title: 'Deactivate facility?',
      message: 'This facility will be hidden from active lists. You can reactivate it later.',
      confirmLabel: 'Deactivate',
      destructive: true,
    },
    reactivate: {
      title: 'Reactivate facility?',
      message: 'This facility will appear in active lists again.',
      confirmLabel: 'Reactivate',
      destructive: false,
    },
    delete: {
      title: 'Delete facility?',
      message:
        'This permanently deletes the facility and is not reversible. If the facility has related records (employees, permits, etc.), the delete will fail — deactivate it instead.',
      confirmLabel: 'Delete',
      destructive: true,
    },
  };

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/establishments')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Facilities
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">
          {String(data.name ?? 'Facility')}
        </h1>
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
            onClick={() => navigate(`/establishments/${id}/edit`)}
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
        <Section title="Address">
          <Field label="Street Address" value={data.street_address} />
          <Field label="City" value={data.city} />
          <Field label="State" value={data.state} />
          <Field label="ZIP Code" value={data.zip} />
        </Section>

        <Section title="Industry">
          <Field label="NAICS Code" value={data.naics_code} />
          <Field label="SIC Code" value={data.sic_code} />
          <Field label="Industry Description" value={data.industry_description} />
        </Section>

        <Section title="Workforce">
          <Field label="Peak Employees" value={data.peak_employees} />
          <Field label="Annual Avg Employees" value={data.annual_avg_employees} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="establishments" entityId={id} />
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
