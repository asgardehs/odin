import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';

type WasteRow = Record<string, unknown>;

export default function WasteDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data, loading, error } = useApi<WasteRow>(`/api/waste-streams/${id}`);

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
        <p className="text-sm">{notFound ? 'Waste stream not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/waste')} className="text-xs text-[var(--color-accent-light)] hover:underline">
          ← Back to Waste Streams
        </button>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/waste')}
          className="text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)] text-sm transition-colors"
        >
          ← Waste Streams
        </button>
        <div>
          <p className="text-xs text-[var(--color-text-muted)] mb-0.5">{String(data.stream_code ?? '')}</p>
          <h1 className="text-2xl font-bold text-[var(--color-text-primary)]">
            {String(data.stream_name ?? 'Waste Stream')}
          </h1>
        </div>
        <span
          className={`ml-auto text-xs font-medium px-2 py-0.5 rounded-full ${
            data.is_active
              ? 'bg-[var(--color-status-ok)]/15 text-[var(--color-status-ok)]'
              : 'bg-[var(--color-border)] text-[var(--color-text-muted)]'
          }`}
        >
          {data.is_active ? 'Active' : 'Inactive'}
        </span>
      </div>

      <div className="flex flex-col gap-4">
        <Section title="Stream Details">
          <Field label="Stream Code" value={data.stream_code} />
          <Field label="Stream Name" value={data.stream_name} />
          <Field label="Waste Category" value={data.waste_category} />
          <Field label="Stream Type Code" value={data.waste_stream_type_code} />
          <Field label="Physical Form" value={data.physical_form} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>
    </div>
  );
}
