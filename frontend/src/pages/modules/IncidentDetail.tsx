import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';

type IncidentRow = Record<string, unknown>;

const SEVERITY_COLORS: Record<string, string> = {
  first_aid: 'var(--color-fn-green)',
  medical: 'var(--color-fn-cyan)',
  restricted: 'var(--color-fn-yellow)',
  lost_time: 'var(--color-fn-orange)',
  fatality: 'var(--color-fn-red)',
};

export default function IncidentDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<IncidentRow>(`/api/incidents/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'close' | 'delete'>(null);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'close') {
        await mutate('POST', `/api/incidents/${id}/close`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/incidents/${id}`);
        navigate('/incidents');
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
        <p className="text-sm">{notFound ? 'Incident not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/incidents')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Incidents
        </button>
      </div>
    );
  }

  const severityKey = String(data.severity_code ?? '').toLowerCase();
  const severityColor = SEVERITY_COLORS[severityKey] ?? 'var(--color-comment)';
  const status = String(data.status ?? 'reported');
  const isClosed = status === 'closed';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/incidents')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Incidents
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">
          {String(data.case_number ?? 'Incident')}
        </h1>
        {!!data.severity_code && (
          <span
            className="text-xs font-medium px-2 py-0.5 rounded-full capitalize"
            style={{
              color: severityColor,
              background: `color-mix(in srgb, ${severityColor} 15%, transparent)`,
            }}
          >
            {String(data.severity_code).toLowerCase().replace(/_/g, ' ')}
          </span>
        )}
        <span
          className={`text-xs font-medium px-2 py-0.5 rounded-full capitalize ${
            isClosed
              ? 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
              : 'bg-[var(--color-fn-purple)]/15 text-[var(--color-fn-purple)]'
          }`}
        >
          {status.replace(/_/g, ' ')}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/incidents/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {!isClosed && (
            <button
              type="button"
              onClick={() => setConfirm('close')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Close incident
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
        <Section title="Case Info">
          <Field label="Case Number" value={data.case_number} />
          <Field label="Incident Date" value={data.incident_date} />
          <Field label="Incident Time" value={data.incident_time} />
          <Field label="Time Began Work" value={data.time_employee_began_work} />
          <Field label="Status" value={status} />
          <Field label="Closed Date" value={data.closed_date} />
        </Section>

        <Section title="Classification & Severity">
          <Field label="Severity Code" value={data.severity_code} />
          <Field label="Case Classification" value={data.case_classification_code} />
          <Field label="Body Part" value={data.body_part_code} />
        </Section>

        <Section title="Location">
          <Field label="Location" value={data.location_description} />
        </Section>

        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider mb-3">
            What Happened
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <dt className="text-xs text-[var(--color-comment)] uppercase tracking-wide mb-1">Activity</dt>
              <dd className="text-[var(--color-fg)] text-sm whitespace-pre-wrap">
                {String(data.activity_description ?? '—')}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-[var(--color-comment)] uppercase tracking-wide mb-1">Object / Substance</dt>
              <dd className="text-[var(--color-fg)] text-sm whitespace-pre-wrap">
                {String(data.object_or_substance ?? '—')}
              </dd>
            </div>
            <div className="md:col-span-2">
              <dt className="text-xs text-[var(--color-comment)] uppercase tracking-wide mb-1">Incident Description</dt>
              <dd className="text-[var(--color-fg)] text-sm whitespace-pre-wrap">
                {String(data.incident_description ?? '—')}
              </dd>
            </div>
          </div>
        </div>

        <Section title="People">
          <Field label="Employee ID" value={data.employee_id} />
          <Field label="Reported By" value={data.reported_by} />
          <Field label="Reported Date" value={data.reported_date} />
          <Field label="Closed By" value={data.closed_by} />
        </Section>

        <Section title="Treatment">
          <Field label="Hospitalized" value={data.was_hospitalized} />
          <Field label="ER Visit" value={data.was_er_visit} />
          <Field label="Treating Physician" value={data.treating_physician} />
          <Field label="Treatment Facility" value={data.treatment_facility} />
          <Field label="Treatment Provided" value={data.treatment_provided} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>

      {confirm && (
        <ConfirmDialog
          open
          title={confirm === 'close' ? 'Close incident?' : 'Delete incident?'}
          message={
            confirm === 'close'
              ? 'Closing marks the incident final. You can still edit it afterward, but this is typically the end of the workflow.'
              : 'This permanently deletes the incident and cannot be undone. Related records (corrective actions) will fail to delete without care.'
          }
          confirmLabel={confirm === 'close' ? 'Close incident' : 'Delete'}
          destructive={confirm === 'delete'}
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
