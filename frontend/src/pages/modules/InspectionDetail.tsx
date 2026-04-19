import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';

type InspectionRow = Record<string, unknown>;

export default function InspectionDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data, loading, error } = useApi<InspectionRow>(`/api/inspections/${id}`);

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
        <span className="ml-auto text-xs font-medium px-2 py-0.5 rounded-full capitalize bg-[var(--color-current-line)] text-[var(--color-fg)]">
          {String(data.status ?? '—')}
        </span>
      </div>

      <div className="flex flex-col gap-4">
        <Section title="Schedule">
          <Field label="Inspection #" value={data.inspection_number} />
          <Field label="Scheduled Date" value={data.scheduled_date} />
          <Field label="Inspection Date" value={data.inspection_date} />
        </Section>

        <Section title="Result">
          <Field label="Overall Result" value={data.overall_result} />
          <Field label="Status" value={data.status} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>
    </div>
  );
}
