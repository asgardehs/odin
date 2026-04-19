import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';

type InspectionRow = Record<string, unknown>;

export default function InspectionDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<InspectionRow>(`/api/inspections/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'complete' | 'delete'>(null);

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

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
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
    </div>
  );
}
