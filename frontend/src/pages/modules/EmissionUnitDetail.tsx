import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import { AuditHistory } from '../../components/AuditHistory';

type UnitRow = Record<string, unknown>;

const SOURCE_LABELS: Record<string, string> = {
  welding: 'Welding',
  coating: 'Coating',
  combustion: 'Combustion',
  solvent: 'Solvent',
  material_handling: 'Material handling',
};

export default function EmissionUnitDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<UnitRow>(`/api/emission-units/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'decommission' | 'reactivate' | 'delete'>(null);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'decommission') {
        await mutate('POST', `/api/emission-units/${id}/decommission`);
        window.location.reload();
      } else if (confirm === 'reactivate') {
        await mutate('POST', `/api/emission-units/${id}/reactivate`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/emission-units/${id}`);
        navigate('/emission-units');
      }
    } catch {
      // mutateError surfaces
    }
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
        <p className="text-sm">{notFound ? 'Emission unit not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/emission-units')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Emission Units
        </button>
      </div>
    );
  }

  const isActive = Boolean(Number(data.is_active));
  const sourceCategory = String(data.source_category ?? '');
  const categoryLabel = SOURCE_LABELS[sourceCategory] ?? sourceCategory;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6 flex-wrap">
        <button
          onClick={() => navigate('/emission-units')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Emission Units
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">
          {String(data.unit_name ?? 'Emission Unit')}
        </h1>
        <span
          className="text-xs font-medium px-2 py-0.5 rounded-full bg-[var(--color-current-line)] text-[var(--color-fg)]"
        >
          {isActive ? 'Active' : 'Decommissioned'}
        </span>
        {Boolean(Number(data.is_fugitive)) && (
          <span className="text-xs font-medium px-2 py-0.5 rounded-full bg-[var(--color-fn-yellow)]/15 text-[var(--color-fn-yellow)]">
            Fugitive
          </span>
        )}

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/emission-units/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {isActive ? (
            <button
              type="button"
              onClick={() => setConfirm('decommission')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Decommission
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setConfirm('reactivate')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Reactivate
            </button>
          )}
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
        <Section title="Identity">
          <Field label="Name" value={data.unit_name} />
          <Field label="Description" value={data.unit_description} />
        </Section>

        <Section title="Source Classification">
          <Field label="Category" value={categoryLabel} />
          <Field label="SCC Code" value={data.scc_code} />
          <Field label="Fugitive" value={data.is_fugitive} />
        </Section>

        <Section title="Location">
          <Field label="Building" value={data.building} />
          <Field label="Area" value={data.area} />
          <Field label="Stack ID" value={data.stack_id} />
        </Section>

        <Section title="Permit">
          <Field label="Permit Type" value={data.permit_type_code} />
          <Field label="Permit Number" value={data.permit_number} />
        </Section>

        <Section title="Operating Parameters">
          <Field label="Max Throughput" value={data.max_throughput} />
          <Field label="Throughput Unit" value={data.max_throughput_unit} />
          <Field label="Max Hours / Year" value={data.max_operating_hours_year} />
          <Field label="Typical Hours / Year" value={data.typical_operating_hours_year} />
        </Section>

        <Section title="Federally Enforceable Restrictions">
          <Field label="Restricted Throughput" value={data.restricted_throughput} />
          <Field label="Restricted Unit" value={data.restricted_throughput_unit} />
          <Field label="Restricted Hours / Year" value={data.restricted_hours_year} />
        </Section>

        <Section title="Service">
          <Field label="Install Date" value={data.install_date} />
          <Field label="Decommission Date" value={data.decommission_date} />
          <Field label="Notes" value={data.notes} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="emission_units" entityId={id} />
      </div>

      {confirm && (
        <ConfirmDialog
          open
          title={
            confirm === 'decommission' ? 'Decommission emission unit?' :
            confirm === 'reactivate'   ? 'Reactivate emission unit?'   :
                                         'Delete emission unit?'
          }
          message={
            confirm === 'decommission'
              ? 'Sets the decommission date (today if not already set) and marks the unit inactive. You can reactivate later.'
              : confirm === 'reactivate'
              ? 'Returns this unit to active service and clears the decommission date.'
              : 'Permanently deletes the emission unit record. Linked materials, PTE calcs, and monitoring may block the delete.'
          }
          confirmLabel={
            confirm === 'decommission' ? 'Decommission' :
            confirm === 'reactivate'   ? 'Reactivate'   :
                                         'Delete'
          }
          destructive={confirm === 'delete'}
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
