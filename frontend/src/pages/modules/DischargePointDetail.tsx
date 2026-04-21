import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import { AuditHistory } from '../../components/AuditHistory';

type DischargePointRow = Record<string, unknown>;

const DISCHARGE_TYPE_LABELS: Record<string, string> = {
  process_wastewater: 'Process wastewater',
  stormwater: 'Stormwater',
  combined: 'Combined (process + stormwater)',
  non_contact_cooling: 'Non-contact cooling water',
  sanitary: 'Sanitary',
  boiler_blowdown: 'Boiler blowdown',
};

const WATERBODY_TYPE_LABELS: Record<string, string> = {
  surface_water: 'Surface water',
  potw: 'Publicly-Owned Treatment Works (POTW)',
  groundwater: 'Groundwater',
};

export default function DischargePointDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<DischargePointRow>(`/api/discharge-points/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'decommission' | 'reactivate' | 'delete'>(null);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'decommission') {
        await mutate('POST', `/api/discharge-points/${id}/decommission`);
        window.location.reload();
      } else if (confirm === 'reactivate') {
        await mutate('POST', `/api/discharge-points/${id}/reactivate`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/discharge-points/${id}`);
        navigate('/discharge-points');
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
        <p className="text-sm">{notFound ? 'Discharge point not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/discharge-points')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Discharge Points
        </button>
      </div>
    );
  }

  const status = String(data.status ?? 'active').toLowerCase();
  const isActive = status === 'active';
  const dischargeType = String(data.discharge_type ?? '');
  const dischargeLabel = DISCHARGE_TYPE_LABELS[dischargeType] ?? dischargeType;
  const waterbodyType = String(data.receiving_waterbody_type ?? '');
  const waterbodyLabel = WATERBODY_TYPE_LABELS[waterbodyType] ?? waterbodyType;
  const isImpaired = Boolean(Number(data.is_impaired_water));
  const tmdlApplies = Boolean(Number(data.tmdl_applies));

  return (
    <div>
      <div className="flex items-center gap-4 mb-6 flex-wrap">
        <button
          onClick={() => navigate('/discharge-points')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Discharge Points
        </button>
        <div>
          <p className="text-xs text-[var(--color-comment)] mb-0.5">{String(data.outfall_code ?? '')}</p>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">
            {String(data.outfall_name ?? data.outfall_code ?? 'Discharge Point')}
          </h1>
        </div>
        <span className="text-xs font-medium px-2 py-0.5 rounded-full capitalize bg-[var(--color-current-line)] text-[var(--color-fg)]">
          {status}
        </span>
        {isImpaired && (
          <span className="text-xs font-medium px-2 py-0.5 rounded-full bg-[var(--color-fn-orange)]/15 text-[var(--color-fn-orange)]">
            Impaired water
          </span>
        )}
        {tmdlApplies && (
          <span className="text-xs font-medium px-2 py-0.5 rounded-full bg-[var(--color-fn-yellow)]/15 text-[var(--color-fn-yellow)]">
            TMDL applies
          </span>
        )}

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/discharge-points/${id}/edit`)}
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
          <Field label="Outfall Code" value={data.outfall_code} />
          <Field label="Outfall Name" value={data.outfall_name} />
          <Field label="Description" value={data.description} />
          <Field label="Status" value={status} />
        </Section>

        <Section title="Discharge">
          <Field label="Discharge Type" value={dischargeLabel} />
          <Field label="Primary Upstream Process Unit" value={data.emission_unit_id} />
          <Field label="Pipe Diameter (in.)" value={data.pipe_diameter_inches} />
          <Field label="Typical Flow (MGD)" value={data.typical_flow_mgd} />
        </Section>

        <Section title="Receiving Waterbody">
          <Field label="Waterbody" value={data.receiving_waterbody} />
          <Field label="Waterbody Type" value={waterbodyLabel} />
          <Field label="Classification" value={data.receiving_waterbody_classification} />
          <Field label="Impaired Water (CWA §303(d))" value={isImpaired ? 'Yes' : 'No'} />
          <Field label="TMDL Applies" value={tmdlApplies ? 'Yes' : 'No'} />
          {tmdlApplies && <Field label="TMDL Parameters" value={data.tmdl_parameters} />}
        </Section>

        <Section title="Regulatory Coverage">
          <Field label="Permit ID" value={data.permit_id} />
          <Field label="Stormwater Sector (MSGP)" value={data.stormwater_sector_code} />
          <Field label="Governing SWPPP" value={data.swppp_id} />
        </Section>

        <Section title="Geography">
          <Field label="Latitude" value={data.latitude} />
          <Field label="Longitude" value={data.longitude} />
        </Section>

        <Section title="Lifecycle">
          <Field label="Installation Date" value={data.installation_date} />
          <Field label="Decommission Date" value={data.decommission_date} />
        </Section>

        <Section title="Notes">
          <Field label="Notes" value={data.notes} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="discharge_points" entityId={id} />
      </div>

      {confirm && (
        <ConfirmDialog
          open
          title={
            confirm === 'decommission'
              ? 'Decommission discharge point?'
              : confirm === 'reactivate'
              ? 'Reactivate discharge point?'
              : 'Delete discharge point?'
          }
          message={
            confirm === 'decommission'
              ? 'Marks this outfall decommissioned and stamps today as the decommission date. Use when the outfall is physically sealed, removed, or no longer in use.'
              : confirm === 'reactivate'
              ? 'Returns this outfall to active service and clears the decommission date. Use when a previously decommissioned outfall is restored.'
              : 'Permanently deletes the discharge point record. Monitoring locations, sample events, or results that reference it may block the delete — decommission instead.'
          }
          confirmLabel={
            confirm === 'decommission' ? 'Decommission' : confirm === 'reactivate' ? 'Reactivate' : 'Delete'
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
