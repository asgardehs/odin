import { useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { Modal } from '../../components/Modal';
import { FormField } from '../../components/forms/FormField';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';

type ChemicalRow = Record<string, unknown>;

function HazardBadge({ label, active }: { label: string; active: unknown }) {
  if (!active) return null;
  return (
    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-[var(--color-fn-red)]/15 text-[var(--color-fn-red)] mr-2">
      ⚠ {label}
    </span>
  );
}

function GhsBadge({ label, active }: { label: string; active: unknown }) {
  if (!active) return null;
  return (
    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs bg-[var(--color-fn-yellow)]/10 border border-[var(--color-fn-yellow)]/30 text-[var(--color-fn-yellow)] mr-2 mb-2">
      {label}
    </span>
  );
}

export default function ChemicalDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<ChemicalRow>(`/api/chemicals/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'reactivate' | 'delete'>(null);
  const [discontinueOpen, setDiscontinueOpen] = useState(false);
  const [discontinueReason, setDiscontinueReason] = useState('');

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'reactivate') {
        await mutate('POST', `/api/chemicals/${id}/reactivate`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/chemicals/${id}`);
        navigate('/chemicals');
      }
    } catch {
      // mutateError surfaces
    }
  }

  async function runDiscontinue() {
    if (!id) return;
    try {
      await mutate('POST', `/api/chemicals/${id}/discontinue`, {
        reason: discontinueReason.trim() || 'Discontinued',
      });
      setDiscontinueOpen(false);
      setDiscontinueReason('');
      window.location.reload();
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
        <p className="text-sm">{notFound ? 'Chemical not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/chemicals')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Chemicals
        </button>
      </div>
    );
  }

  const active = Boolean(data.is_active);
  const any = (...vals: unknown[]) => vals.some(v => Boolean(v));
  const hasRegulatory = any(data.is_ehs, data.is_sara_313, data.is_pbt);
  const hasPhysicalGhs = any(
    data.is_flammable, data.is_oxidizer, data.is_explosive,
    data.is_self_reactive, data.is_pyrophoric, data.is_self_heating,
    data.is_organic_peroxide, data.is_corrosive_to_metal,
    data.is_gas_under_pressure, data.is_water_reactive,
  );
  const hasHealthGhs = any(
    data.is_acute_toxic, data.is_skin_corrosion, data.is_eye_damage,
    data.is_skin_sensitizer, data.is_respiratory_sensitizer,
    data.is_germ_cell_mutagen, data.is_carcinogen,
    data.is_reproductive_toxin, data.is_target_organ_single,
    data.is_target_organ_repeat, data.is_aspiration_hazard,
  );
  const hasEnvGhs = Boolean(data.is_aquatic_toxic);

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
          className={`text-xs font-medium px-2 py-0.5 rounded-full ${
            active
              ? 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]'
              : 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
          }`}
        >
          {active ? 'Active' : 'Discontinued'}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/chemicals/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {isAdmin && (active ? (
            <button
              type="button"
              onClick={() => setDiscontinueOpen(true)}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Discontinue
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
        {!!hasRegulatory && (
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

        {!active && data.discontinued_reason ? (
          <div className="rounded-xl bg-[var(--color-fn-yellow)]/10 border border-[var(--color-fn-yellow)]/30 px-5 py-3 text-sm text-[var(--color-fn-yellow)]">
            <span className="font-semibold uppercase text-xs tracking-wide">Discontinued on {String(data.discontinued_date ?? '—')}:</span>{' '}
            {String(data.discontinued_reason)}
          </div>
        ) : null}

        <Section title="Identification">
          <Field label="Product Name" value={data.product_name} />
          <Field label="CAS Number" value={data.primary_cas_number} />
          <Field label="Manufacturer" value={data.manufacturer} />
          <Field label="Manufacturer Phone" value={data.manufacturer_phone} />
          <Field label="Signal Word" value={data.signal_word} />
        </Section>

        {(hasPhysicalGhs || hasHealthGhs || hasEnvGhs) && (
          <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
            <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider mb-3">
              GHS Hazards
            </h2>
            {hasPhysicalGhs && (
              <div className="mb-2">
                <p className="text-xs text-[var(--color-comment)] uppercase tracking-wide mb-1">Physical</p>
                <div className="flex flex-wrap">
                  <GhsBadge label="Flammable" active={data.is_flammable} />
                  <GhsBadge label="Oxidizer" active={data.is_oxidizer} />
                  <GhsBadge label="Explosive" active={data.is_explosive} />
                  <GhsBadge label="Self-reactive" active={data.is_self_reactive} />
                  <GhsBadge label="Pyrophoric" active={data.is_pyrophoric} />
                  <GhsBadge label="Self-heating" active={data.is_self_heating} />
                  <GhsBadge label="Organic peroxide" active={data.is_organic_peroxide} />
                  <GhsBadge label="Corrosive to metal" active={data.is_corrosive_to_metal} />
                  <GhsBadge label="Gas under pressure" active={data.is_gas_under_pressure} />
                  <GhsBadge label="Water-reactive" active={data.is_water_reactive} />
                </div>
              </div>
            )}
            {hasHealthGhs && (
              <div className="mb-2">
                <p className="text-xs text-[var(--color-comment)] uppercase tracking-wide mb-1">Health</p>
                <div className="flex flex-wrap">
                  <GhsBadge label="Acute toxicity" active={data.is_acute_toxic} />
                  <GhsBadge label="Skin corrosion" active={data.is_skin_corrosion} />
                  <GhsBadge label="Eye damage" active={data.is_eye_damage} />
                  <GhsBadge label="Skin sensitizer" active={data.is_skin_sensitizer} />
                  <GhsBadge label="Respiratory sensitizer" active={data.is_respiratory_sensitizer} />
                  <GhsBadge label="Germ cell mutagen" active={data.is_germ_cell_mutagen} />
                  <GhsBadge label="Carcinogen" active={data.is_carcinogen} />
                  <GhsBadge label="Reproductive toxin" active={data.is_reproductive_toxin} />
                  <GhsBadge label="STOT-SE" active={data.is_target_organ_single} />
                  <GhsBadge label="STOT-RE" active={data.is_target_organ_repeat} />
                  <GhsBadge label="Aspiration hazard" active={data.is_aspiration_hazard} />
                </div>
              </div>
            )}
            {hasEnvGhs && (
              <div>
                <p className="text-xs text-[var(--color-comment)] uppercase tracking-wide mb-1">Environmental</p>
                <div className="flex flex-wrap">
                  <GhsBadge label="Aquatic toxicity" active={data.is_aquatic_toxic} />
                </div>
              </div>
            )}
          </div>
        )}

        {!!data.is_ehs && (
          <Section title="EHS Thresholds">
            <Field label="TPQ (lbs)" value={data.ehs_tpq_lbs} />
            <Field label="RQ (lbs)" value={data.ehs_rq_lbs} />
          </Section>
        )}

        {!!data.is_sara_313 && (
          <Section title="SARA 313">
            <Field label="Category" value={data.sara_313_category} />
          </Section>
        )}

        <Section title="Physical Properties">
          <Field label="Physical State" value={data.physical_state} />
          <Field label="Specific Gravity" value={data.specific_gravity} />
          <Field label="Vapor Pressure (mmHg)" value={data.vapor_pressure_mmhg} />
          <Field label="Flash Point (°F)" value={data.flash_point_f} />
          <Field label="pH" value={data.ph} />
          <Field label="Appearance" value={data.appearance} />
          <Field label="Odor" value={data.odor} />
        </Section>

        <Section title="Storage & Handling">
          <Field label="Storage Requirements" value={data.storage_requirements} />
          <Field label="Incompatible Materials" value={data.incompatible_materials} />
          <Field label="Required PPE" value={data.ppe_required} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>

      {confirm && (
        <ConfirmDialog
          open
          title={confirm === 'reactivate' ? 'Reactivate chemical?' : 'Delete chemical?'}
          message={
            confirm === 'reactivate'
              ? 'This clears the discontinuation record and returns the chemical to active status.'
              : 'This permanently deletes the chemical and is not reversible. If the chemical has related records (inventory snapshots), the delete will fail — discontinue instead.'
          }
          confirmLabel={confirm === 'reactivate' ? 'Reactivate' : 'Delete'}
          destructive={confirm === 'delete'}
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}

      <Modal
        open={discontinueOpen}
        onClose={() => { setDiscontinueOpen(false); setDiscontinueReason(''); }}
        title="Discontinue chemical?"
        size="md"
        footer={
          <>
            <button
              type="button"
              onClick={() => { setDiscontinueOpen(false); setDiscontinueReason(''); }}
              disabled={mutating}
              className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={runDiscontinue}
              disabled={mutating}
              className="h-10 px-4 rounded-lg bg-[var(--color-fn-red)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {mutating ? 'Discontinuing...' : 'Discontinue'}
            </button>
          </>
        }
      >
        <p className="text-sm text-[var(--color-fg)] mb-4">
          Mark this chemical inactive. Record a reason for the audit trail
          (e.g. replaced by safer alternative, supplier change, no longer used).
        </p>
        <FormField
          type="textarea"
          label="Reason"
          value={discontinueReason}
          onChange={setDiscontinueReason}
          rows={3}
          placeholder="e.g. Replaced with non-halogenated alternative"
        />
      </Modal>
    </div>
  );
}
