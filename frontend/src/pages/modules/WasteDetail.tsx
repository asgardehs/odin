import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';

type WasteRow = Record<string, unknown>;

function HazardBadge({ label, active }: { label: string; active: unknown }) {
  if (!active) return null;
  return (
    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-[var(--color-fn-red)]/15 text-[var(--color-fn-red)] mr-2">
      ⚠ {label}
    </span>
  );
}

export default function WasteDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<WasteRow>(`/api/waste-streams/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'deactivate' | 'reactivate' | 'delete'>(null);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'deactivate') {
        await mutate('POST', `/api/waste-streams/${id}/deactivate`);
        window.location.reload();
      } else if (confirm === 'reactivate') {
        await mutate('POST', `/api/waste-streams/${id}/reactivate`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/waste-streams/${id}`);
        navigate('/waste');
      }
    } catch { /* mutateError surfaces */ }
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
        <p className="text-sm">{notFound ? 'Waste stream not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/waste')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Waste Streams
        </button>
      </div>
    );
  }

  const active = Boolean(data.is_active);
  const hasHazards = data.is_ignitable || data.is_corrosive || data.is_reactive || data.is_toxic || data.is_acute_hazardous;

  const confirmConfig = {
    deactivate: {
      title: 'Deactivate waste stream?',
      message: 'Hides the stream from active lists. Historical records preserved.',
      confirmLabel: 'Deactivate',
      destructive: true,
    },
    reactivate: {
      title: 'Reactivate waste stream?',
      message: 'Returns this stream to the active list.',
      confirmLabel: 'Reactivate',
      destructive: false,
    },
    delete: {
      title: 'Delete waste stream?',
      message: 'Permanent delete. If related records exist, the delete will fail — deactivate instead.',
      confirmLabel: 'Delete',
      destructive: true,
    },
  };

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/waste')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Waste Streams
        </button>
        <div>
          <p className="text-xs text-[var(--color-comment)] mb-0.5">{String(data.stream_code ?? '')}</p>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">
            {String(data.stream_name ?? 'Waste Stream')}
          </h1>
        </div>
        <span
          className={`text-xs font-medium px-2 py-0.5 rounded-full ${
            active
              ? 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]'
              : 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
          }`}
        >
          {active ? 'Active' : 'Inactive'}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/waste/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {isAdmin && (active ? (
            <button
              type="button"
              onClick={() => setConfirm('deactivate')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Deactivate
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setConfirm('reactivate')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Reactivate
            </button>
          ))}
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
        {hasHazards ? (
          <div className="rounded-xl bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 px-5 py-4">
            <p className="text-xs text-[var(--color-fn-red)] font-semibold uppercase tracking-wide mb-2">
              RCRA Characteristics
            </p>
            <div>
              <HazardBadge label="Ignitable" active={data.is_ignitable} />
              <HazardBadge label="Corrosive" active={data.is_corrosive} />
              <HazardBadge label="Reactive" active={data.is_reactive} />
              <HazardBadge label="Toxic" active={data.is_toxic} />
              <HazardBadge label="Acute Hazardous" active={data.is_acute_hazardous} />
            </div>
          </div>
        ) : null}

        <Section title="Identity">
          <Field label="Stream Code" value={data.stream_code} />
          <Field label="Stream Name" value={data.stream_name} />
          <Field label="Description" value={data.description} />
        </Section>

        <Section title="Source">
          <Field label="Generating Process" value={data.generating_process} />
          <Field label="Source Location" value={data.source_location} />
          <Field label="Source Chemical ID" value={data.source_chemical_id} />
        </Section>

        <Section title="Classification">
          <Field label="Waste Category" value={data.waste_category} />
          <Field label="Waste Stream Type Code" value={data.waste_stream_type_code} />
        </Section>

        <Section title="Physical Form & Quantity">
          <Field label="Physical Form" value={data.physical_form} />
          <Field label="Typical Qty / Month" value={data.typical_quantity_per_month} />
          <Field label="Quantity Unit" value={data.quantity_unit} />
        </Section>

        <Section title="Handling">
          <Field label="Handling Instructions" value={data.handling_instructions} />
          <Field label="Required PPE" value={data.ppe_required} />
          <Field label="Incompatible With" value={data.incompatible_with} />
        </Section>

        <Section title="Waste Profile">
          <Field label="Profile Number" value={data.profile_number} />
          <Field label="Profile Expiration" value={data.profile_expiration} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>

      {confirm && (
        <ConfirmDialog
          open
          title={confirmConfig[confirm].title}
          message={confirmConfig[confirm].message}
          confirmLabel={confirmConfig[confirm].confirmLabel}
          destructive={confirmConfig[confirm].destructive}
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
