import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';

type EstablishmentRow = Record<string, unknown>;

export default function EstablishmentDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data, loading, error } = useApi<EstablishmentRow>(`/api/establishments/${id}`);

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
        <p className="text-sm">{notFound ? 'Facility not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/establishments')} className="text-xs text-[var(--color-accent-light)] hover:underline">
          ← Back to Facilities
        </button>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/establishments')}
          className="text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)] text-sm transition-colors"
        >
          ← Facilities
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-text-primary)]">
          {String(data.name ?? 'Facility')}
        </h1>
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
      </div>
    </div>
  );
}
