import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';

type PPERow = Record<string, unknown>;

const STATUS_COLORS: Record<string, string> = {
  active:  'var(--color-fn-green)',
  retired: 'var(--color-fn-red)',
  expired: 'var(--color-fn-red)',
};

export default function PPEDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data, loading, error } = useApi<PPERow>(`/api/ppe/items/${id}`);

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
        <p className="text-sm">{notFound ? 'PPE item not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/ppe')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to PPE
        </button>
      </div>
    );
  }

  const statusKey = String(data.status ?? '').toLowerCase();
  const statusColor = STATUS_COLORS[statusKey] ?? 'var(--color-comment)';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/ppe')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← PPE
        </button>
        <div>
          <p className="text-xs text-[var(--color-comment)] mb-0.5">
            {[data.manufacturer, data.model].filter(Boolean).join(' ')}
          </p>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">
            {String(data.serial_number ?? data.asset_tag ?? 'PPE Item')}
          </h1>
        </div>
        <span
          className="ml-auto text-xs font-medium px-2 py-0.5 rounded-full capitalize"
          style={{
            color: statusColor,
            background: `color-mix(in srgb, ${statusColor} 15%, transparent)`,
          }}
        >
          {statusKey || '—'}
        </span>
      </div>

      <div className="flex flex-col gap-4">
        <Section title="Item Details">
          <Field label="Serial Number" value={data.serial_number} />
          <Field label="Asset Tag" value={data.asset_tag} />
          <Field label="Manufacturer" value={data.manufacturer} />
          <Field label="Model" value={data.model} />
          <Field label="Size" value={data.size} />
          <Field label="Status" value={data.status} />
          <Field label="Assigned To" value={data.current_assignee} />
        </Section>

        <Section title="Dates">
          <Field label="In Service Date" value={data.in_service_date} />
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
