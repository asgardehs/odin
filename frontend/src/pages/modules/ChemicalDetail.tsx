import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';

type ChemicalRow = Record<string, unknown>;

function HazardBadge({ label, active }: { label: string; active: unknown }) {
  if (!active) return null;
  return (
    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-[var(--color-fn-red)]/15 text-[var(--color-fn-red)] mr-2">
      ⚠ {label}
    </span>
  );
}

export default function ChemicalDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data, loading, error } = useApi<ChemicalRow>(`/api/chemicals/${id}`);

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
        <p className="text-sm">{notFound ? 'Chemical not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/chemicals')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Chemicals
        </button>
      </div>
    );
  }

  const hasHazards = data.is_ehs || data.is_sara_313 || data.is_pbt;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/chemicals')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Chemicals
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">
          {String(data.product_name ?? 'Chemical')}
        </h1>
        <span
          className={`ml-auto text-xs font-medium px-2 py-0.5 rounded-full ${
            data.is_active
              ? 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]'
              : 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
          }`}
        >
          {data.is_active ? 'Active' : 'Inactive'}
        </span>
      </div>

      <div className="flex flex-col gap-4">
        {!!hasHazards && (
          <div className="rounded-xl bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 px-5 py-4">
            <p className="text-xs text-[var(--color-fn-red)] font-semibold uppercase tracking-wide mb-2">
              Regulatory Flags
            </p>
            <div>
              <HazardBadge label="EHS" active={data.is_ehs} />
              <HazardBadge label="SARA 313" active={data.is_sara_313} />
              <HazardBadge label="PBT" active={data.is_pbt} />
            </div>
          </div>
        )}

        <Section title="Identification">
          <Field label="Product Name" value={data.product_name} />
          <Field label="CAS Number" value={data.primary_cas_number} />
          <Field label="Manufacturer" value={data.manufacturer} />
          <Field label="Physical State" value={data.physical_state} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>
    </div>
  );
}
