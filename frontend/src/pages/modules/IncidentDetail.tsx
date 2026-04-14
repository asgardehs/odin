import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';

type IncidentRow = Record<string, unknown>;

const SEVERITY_COLORS: Record<string, string> = {
  fatal:    'var(--color-status-danger)',
  serious:  'var(--color-status-warn)',
  moderate: 'var(--color-status-info)',
  minor:    'var(--color-status-ok)',
};

export default function IncidentDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data, loading, error } = useApi<IncidentRow>(`/api/incidents/${id}`);

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-text-muted)] text-sm">
        Loading…
      </div>
    );
  }

  if (error || !data) {
    const notFound = error?.startsWith('404');
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-text-muted)]">
        <p className="text-sm">{notFound ? 'Incident not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/incidents')} className="text-xs text-[var(--color-accent-light)] hover:underline">
          ← Back to Incidents
        </button>
      </div>
    );
  }

  const severityKey = String(data.severity_code ?? '').toLowerCase();
  const severityColor = SEVERITY_COLORS[severityKey] ?? 'var(--color-text-muted)';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/incidents')}
          className="text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)] text-sm transition-colors"
        >
          ← Incidents
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-text-primary)]">
          {String(data.case_number ?? 'Incident')}
        </h1>
        {!!data.severity_code && (
          <span
            className="ml-auto text-xs font-medium px-2 py-0.5 rounded-full capitalize"
            style={{
              color: severityColor,
              background: `color-mix(in srgb, ${severityColor} 15%, transparent)`,
            }}
          >
            {String(data.severity_code)}
          </span>
        )}
      </div>

      <div className="flex flex-col gap-4">
        <Section title="Case Info">
          <Field label="Case Number" value={data.case_number} />
          <Field label="Incident Date" value={data.incident_date} />
          <Field label="Incident Time" value={data.incident_time} />
          <Field label="Status" value={data.status} />
        </Section>

        <Section title="Location">
          <Field label="Location" value={data.location_description} />
        </Section>

        <Section title="Description">
          <div className="col-span-3">
            <dt className="text-xs text-[var(--color-text-muted)] uppercase tracking-wide mb-1">
              Incident Description
            </dt>
            <dd className="text-[var(--color-text-primary)] text-sm whitespace-pre-wrap">
              {String(data.incident_description ?? '—')}
            </dd>
          </div>
        </Section>

        <Section title="Classification">
          <Field label="Case Classification" value={data.case_classification_code} />
          <Field label="Severity" value={data.severity_code} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>
    </div>
  );
}
