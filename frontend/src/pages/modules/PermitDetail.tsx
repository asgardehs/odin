import { useMemo } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';

type PermitRow = Record<string, unknown>;

export default function PermitDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data, loading, error } = useApi<PermitRow>(`/api/permits/${id}`);

  // All hooks before early returns. data may be null during loading.
  const expirationStr = data ? String(data.expiration_date ?? '') : '';
  const daysUntilExpiry = useMemo(
    () =>
      expirationStr
        ? Math.ceil((new Date(expirationStr).getTime() - Date.now()) / 86_400_000) // eslint-disable-line react-hooks/purity
        : null,
    [expirationStr],
  );
  const expiryWarning =
    daysUntilExpiry !== null && daysUntilExpiry <= 90
      ? daysUntilExpiry < 0
        ? 'Expired'
        : `Expires in ${daysUntilExpiry} day${daysUntilExpiry === 1 ? '' : 's'}`
      : null;

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
        <p className="text-sm">{notFound ? 'Permit not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/permits')} className="text-xs text-[var(--color-accent-light)] hover:underline">
          ← Back to Permits
        </button>
      </div>
    );
  }

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/permits')}
          className="text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)] text-sm transition-colors"
        >
          ← Permits
        </button>
        <div>
          <p className="text-xs text-[var(--color-text-muted)] mb-0.5">{String(data.permit_number ?? '')}</p>
          <h1 className="text-2xl font-bold text-[var(--color-text-primary)]">
            {String(data.permit_name ?? 'Permit')}
          </h1>
        </div>
        <span className="ml-auto text-xs font-medium px-2 py-0.5 rounded-full capitalize bg-[var(--color-border)] text-[var(--color-text-secondary)]">
          {String(data.status ?? '—')}
        </span>
      </div>

      {!!expiryWarning && (
        <div
          className={`rounded-xl border px-5 py-4 mb-4 ${
            daysUntilExpiry !== null && daysUntilExpiry < 0
              ? 'bg-[var(--color-status-danger)]/10 border-[var(--color-status-danger)]/30 text-[var(--color-status-danger)]'
              : 'bg-[var(--color-status-warn)]/10 border-[var(--color-status-warn)]/30 text-[var(--color-status-warn)]'
          }`}
        >
          <p className="text-sm font-medium">⏰ {expiryWarning}</p>
        </div>
      )}

      <div className="flex flex-col gap-4">
        <Section title="Permit Details">
          <Field label="Permit Number" value={data.permit_number} />
          <Field label="Permit Name" value={data.permit_name} />
          <Field label="Issuing Agency" value={data.issuing_agency} />
          <Field label="Status" value={data.status} />
        </Section>

        <Section title="Dates">
          <Field label="Effective Date" value={data.effective_date} />
          <Field label="Expiration Date" value={data.expiration_date} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>
    </div>
  );
}
