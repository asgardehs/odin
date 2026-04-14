import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';

type TrainingRow = Record<string, unknown>;

export default function TrainingDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data, loading, error } = useApi<TrainingRow>(`/api/training/courses/${id}`);

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
        <p className="text-sm">{notFound ? 'Training course not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/training')} className="text-xs text-[var(--color-accent-light)] hover:underline">
          ← Back to Training
        </button>
      </div>
    );
  }

  const durationMins = data.duration_minutes as number | null;
  const durationDisplay = durationMins == null ? '—'
    : durationMins >= 60 ? `${Math.floor(durationMins / 60)}h ${durationMins % 60}m`
    : `${durationMins}m`;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/training')}
          className="text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)] text-sm transition-colors"
        >
          ← Training
        </button>
        <div>
          <p className="text-xs text-[var(--color-text-muted)] mb-0.5">{String(data.course_code ?? '')}</p>
          <h1 className="text-2xl font-bold text-[var(--color-text-primary)]">
            {String(data.course_name ?? 'Course')}
          </h1>
        </div>
      </div>

      <div className="flex flex-col gap-4">
        <Section title="Course Info">
          <Field label="Course Code" value={data.course_code} />
          <Field label="Course Name" value={data.course_name} />
          <Field label="Duration" value={durationDisplay} />
          <Field label="Delivery Method" value={data.delivery_method} />
          <Field label="Validity (months)" value={data.validity_months} />
        </Section>

        {!!data.description && (
          <div className="rounded-xl bg-[var(--color-bg-card)] border border-[var(--color-border)] p-5">
            <h2 className="text-xs font-semibold text-[var(--color-accent-light)] uppercase tracking-wider mb-3">
              Description
            </h2>
            <p className="text-sm text-[var(--color-text-primary)] whitespace-pre-wrap">
              {String(data.description)}
            </p>
          </div>
        )}

        <Section title="Assessment">
          <Field label="Has Test" value={data.has_test ? 'Yes' : 'No'} />
          <Field label="Passing Score" value={data.passing_score} />
        </Section>
      </div>
    </div>
  );
}
