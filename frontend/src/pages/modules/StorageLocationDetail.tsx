import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import { AuditHistory } from '../../components/AuditHistory';

type Row = Record<string, unknown>;

export default function StorageLocationDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<Row>(`/api/storage-locations/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'deactivate' | 'reactivate' | 'delete'>(null);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'deactivate') {
        await mutate('POST', `/api/storage-locations/${id}/deactivate`);
        window.location.reload();
      } else if (confirm === 'reactivate') {
        await mutate('POST', `/api/storage-locations/${id}/reactivate`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/storage-locations/${id}`);
        navigate('/storage-locations');
      }
    } catch { /* mutateError surfaces */ }
  }

  if (loading) {
    return <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">Loading…</div>;
  }

  if (error || !data) {
    const notFound = error?.startsWith('404');
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-comment)]">
        <p className="text-sm">{notFound ? 'Storage location not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/storage-locations')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Storage Locations
        </button>
      </div>
    );
  }

  const active = Boolean(data.is_active);
  const label = [data.building, data.room, data.area].filter(Boolean).join(' / ') || 'Location';

  const cfg = {
    deactivate: { title: 'Deactivate location?', message: 'Hides from active selectors. Past inventory snapshots are preserved.', confirmLabel: 'Deactivate', destructive: true },
    reactivate: { title: 'Reactivate location?', message: 'Returns this location to active use.', confirmLabel: 'Reactivate', destructive: false },
    delete: { title: 'Delete location?', message: 'Permanent. If inventory snapshots reference this location, the delete will fail — deactivate instead.', confirmLabel: 'Delete', destructive: true },
  };

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button onClick={() => navigate('/storage-locations')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors">
          ← Storage Locations
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">{label}</h1>
        <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${
          active ? 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]' : 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
        }`}>
          {active ? 'Active' : 'Inactive'}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button type="button" onClick={() => navigate(`/storage-locations/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity">
            Edit
          </button>
          {isAdmin && (active ? (
            <button type="button" onClick={() => setConfirm('deactivate')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors">
              Deactivate
            </button>
          ) : (
            <button type="button" onClick={() => setConfirm('reactivate')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors">
              Reactivate
            </button>
          ))}
          {isAdmin && (
            <button type="button" onClick={() => setConfirm('delete')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fn-red)] text-xs cursor-pointer hover:border-[var(--color-fn-red)]/50 transition-colors">
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
        <Section title="Location">
          <Field label="Building" value={data.building} />
          <Field label="Room" value={data.room} />
          <Field label="Area" value={data.area} />
        </Section>

        <Section title="Site Map">
          <Field label="Grid Reference" value={data.grid_reference} />
          <Field label="Latitude" value={data.latitude} />
          <Field label="Longitude" value={data.longitude} />
        </Section>

        <Section title="Storage Conditions">
          <Field label="Indoor" value={data.is_indoor ? 'Yes' : 'No'} />
          <Field label="Pressure" value={data.storage_pressure} />
          <Field label="Temperature" value={data.storage_temperature} />
        </Section>

        <Section title="Containers">
          <Field label="Container Types" value={data.container_types} />
          <Field label="Max Capacity (gal)" value={data.max_capacity_gallons} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="storage_locations" entityId={id} />
      </div>

      {confirm && (
        <ConfirmDialog open
          title={cfg[confirm].title}
          message={cfg[confirm].message}
          confirmLabel={cfg[confirm].confirmLabel}
          destructive={cfg[confirm].destructive}
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)} />
      )}
    </div>
  );
}
