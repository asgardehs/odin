import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const dischargeTypeOptions = [
  { value: 'process_wastewater', label: 'Process wastewater' },
  { value: 'stormwater', label: 'Stormwater' },
  { value: 'combined', label: 'Combined (process + stormwater)' },
  { value: 'non_contact_cooling', label: 'Non-contact cooling water' },
  { value: 'sanitary', label: 'Sanitary' },
  { value: 'boiler_blowdown', label: 'Boiler blowdown' },
];

const waterbodyTypeOptions = [
  { value: '', label: '— not specified —' },
  { value: 'surface_water', label: 'Surface water' },
  { value: 'potw', label: 'Publicly-Owned Treatment Works (POTW)' },
  { value: 'groundwater', label: 'Groundwater' },
];

interface DischargePointFormState {
  establishment_id: number | null;
  outfall_code: string;
  outfall_name: string;
  description: string;
  discharge_type: string;
  receiving_waterbody: string;
  receiving_waterbody_type: string;
  receiving_waterbody_classification: string;
  is_impaired_water: boolean;
  tmdl_applies: boolean;
  tmdl_parameters: string;
  latitude: string;
  longitude: string;
  permit_id: number | null;
  stormwater_sector_code: string;
  swppp_id: number | null;
  emission_unit_id: number | null;
  pipe_diameter_inches: string;
  typical_flow_mgd: string;
  installation_date: string;
  decommission_date: string;
  notes: string;
}

const empty: DischargePointFormState = {
  establishment_id: null,
  outfall_code: '',
  outfall_name: '',
  description: '',
  discharge_type: 'process_wastewater',
  receiving_waterbody: '',
  receiving_waterbody_type: '',
  receiving_waterbody_classification: '',
  is_impaired_water: false,
  tmdl_applies: false,
  tmdl_parameters: '',
  latitude: '',
  longitude: '',
  permit_id: null,
  stormwater_sector_code: '',
  swppp_id: null,
  emission_unit_id: null,
  pipe_diameter_inches: '',
  typical_flow_mgd: '',
  installation_date: '',
  decommission_date: '',
  notes: '',
};

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}

function numOrNull(s: string): number | null {
  if (s.trim() === '') return null;
  const n = parseFloat(s);
  return Number.isNaN(n) ? null : n;
}

function toBody(f: DischargePointFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    outfall_code: f.outfall_code.trim(),
    outfall_name: nullIfBlank(f.outfall_name),
    description: nullIfBlank(f.description),
    discharge_type: f.discharge_type,
    receiving_waterbody: nullIfBlank(f.receiving_waterbody),
    receiving_waterbody_type: nullIfBlank(f.receiving_waterbody_type),
    receiving_waterbody_classification: nullIfBlank(f.receiving_waterbody_classification),
    is_impaired_water: f.is_impaired_water ? 1 : 0,
    tmdl_applies: f.tmdl_applies ? 1 : 0,
    tmdl_parameters: nullIfBlank(f.tmdl_parameters),
    latitude: numOrNull(f.latitude),
    longitude: numOrNull(f.longitude),
    permit_id: f.permit_id,
    stormwater_sector_code: nullIfBlank(f.stormwater_sector_code),
    swppp_id: f.swppp_id,
    emission_unit_id: f.emission_unit_id,
    pipe_diameter_inches: numOrNull(f.pipe_diameter_inches),
    typical_flow_mgd: numOrNull(f.typical_flow_mgd),
    installation_date: nullIfBlank(f.installation_date),
    decommission_date: nullIfBlank(f.decommission_date),
    notes: nullIfBlank(f.notes),
  };
}

interface SectorOption {
  code: string;
  name: string;
}

export default function DischargePointForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<DischargePointFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const [sectors, setSectors] = useState<SectorOption[]>([]);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    api
      .get<{ data: SectorOption[] }>('/api/sw-industrial-sectors?per_page=100')
      .then((r) => setSectors(r.data ?? []))
      .catch(() => setSectors([]));
  }, []);

  useEffect(() => {
    if (!isEdit) return;
    api
      .get<Record<string, unknown>>(`/api/discharge-points/${id}`)
      .then((row) => {
        const s = (k: string) => (row[k] as string) ?? '';
        const n = (k: string) => (row[k] == null ? '' : String(row[k]));
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          outfall_code: s('outfall_code'),
          outfall_name: s('outfall_name'),
          description: s('description'),
          discharge_type: s('discharge_type') || 'process_wastewater',
          receiving_waterbody: s('receiving_waterbody'),
          receiving_waterbody_type: s('receiving_waterbody_type'),
          receiving_waterbody_classification: s('receiving_waterbody_classification'),
          is_impaired_water: Boolean(row.is_impaired_water),
          tmdl_applies: Boolean(row.tmdl_applies),
          tmdl_parameters: s('tmdl_parameters'),
          latitude: n('latitude'),
          longitude: n('longitude'),
          permit_id: (row.permit_id as number) ?? null,
          stormwater_sector_code: s('stormwater_sector_code'),
          swppp_id: (row.swppp_id as number) ?? null,
          emission_unit_id: (row.emission_unit_id as number) ?? null,
          pipe_diameter_inches: n('pipe_diameter_inches'),
          typical_flow_mgd: n('typical_flow_mgd'),
          installation_date: s('installation_date'),
          decommission_date: s('decommission_date'),
          notes: s('notes'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof DischargePointFormState>(
    key: K,
    value: DischargePointFormState[K],
  ) => {
    setForm((prev) => ({ ...prev, [key]: value }));
    setDirty(true);
    setValidationError(null);
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (form.establishment_id == null) {
      setValidationError('Facility is required.');
      return;
    }
    if (!form.outfall_code.trim()) {
      setValidationError('Outfall code is required.');
      return;
    }
    if (!form.discharge_type) {
      setValidationError('Discharge type is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/discharge-points/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/discharge-points', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/discharge-points/${nextId}`);
    } catch {
      // saveError surfaces
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">
        Loading…
      </div>
    );
  }

  const errorMessage = validationError ?? saveError;
  const title = isEdit ? `Edit ${form.outfall_code || 'Discharge Point'}` : 'New Discharge Point';
  const isStormwater =
    form.discharge_type === 'stormwater' || form.discharge_type === 'combined';
  const sectorOptions = [
    { value: '', label: '— not a stormwater outfall —' },
    ...sectors.map((s) => ({ value: s.code, label: `${s.code} — ${s.name}` })),
  ];

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/discharge-points/${id}` : '/discharge-points')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Cancel
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">{title}</h1>
      </div>

      {errorMessage && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {errorMessage}
        </div>
      )}

      <form onSubmit={submit} className="flex flex-col gap-6 max-w-5xl">
        <SectionCard title="Identity" description="Outfall identification and type.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">
                Facility<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
              </label>
              <EntitySelector
                entity="establishments"
                value={form.establishment_id}
                onChange={(id) => update('establishment_id', id)}
                renderLabel={(row) => String(row.name ?? `Facility ${row.id}`)}
                placeholder="Select a facility..."
                required
              />
            </div>
            <FormField
              label="Outfall Code"
              required
              value={form.outfall_code}
              onChange={(v) => update('outfall_code', v)}
              placeholder="e.g. OUTFALL-001, SW-OUT-002"
              autoFocus
              hint="Unique per facility."
            />
            <FormField
              label="Outfall Name"
              value={form.outfall_name}
              onChange={(v) => update('outfall_name', v)}
              placeholder="Descriptive name"
            />
            <FormField
              type="select"
              label="Discharge Type"
              required
              value={form.discharge_type}
              onChange={(v) => update('discharge_type', v)}
              options={dischargeTypeOptions}
            />
            <div className="md:col-span-2">
              <FormField
                type="textarea"
                label="Description"
                value={form.description}
                onChange={(v) => update('description', v)}
                rows={2}
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard
          title="Receiving Waterbody"
          description="What body of water or POTW receives this discharge, and whether it is regulated as impaired."
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Waterbody"
              value={form.receiving_waterbody}
              onChange={(v) => update('receiving_waterbody', v)}
              placeholder="e.g. Cedar Creek, POTW-Ashfork"
            />
            <FormField
              type="select"
              label="Waterbody Type"
              value={form.receiving_waterbody_type}
              onChange={(v) => update('receiving_waterbody_type', v)}
              options={waterbodyTypeOptions}
            />
            <FormField
              label="State Classification"
              value={form.receiving_waterbody_classification}
              onChange={(v) => update('receiving_waterbody_classification', v)}
              placeholder="e.g. Class II, Cold-water fishery"
            />
            <div className="flex flex-col gap-2 pt-6">
              <label className="flex items-center gap-2 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={form.is_impaired_water}
                  onChange={(e) => update('is_impaired_water', e.target.checked)}
                  className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
                />
                <span className="text-sm text-[var(--color-fg)]">
                  On the CWA §303(d) impaired waters list
                </span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={form.tmdl_applies}
                  onChange={(e) => update('tmdl_applies', e.target.checked)}
                  className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
                />
                <span className="text-sm text-[var(--color-fg)]">
                  A Total Maximum Daily Load (TMDL) applies
                </span>
              </label>
            </div>
            {form.tmdl_applies && (
              <div className="md:col-span-2">
                <FormField
                  label="TMDL Parameters"
                  value={form.tmdl_parameters}
                  onChange={(v) => update('tmdl_parameters', v)}
                  placeholder='JSON array, e.g. ["zinc","PAHs"]'
                  hint="Parameters subject to wasteload allocation from the TMDL."
                />
              </div>
            )}
          </div>
        </SectionCard>

        <SectionCard
          title="Regulatory Coverage"
          description="Which permit authorizes this discharge, and — for stormwater — which MSGP sector and SWPPP apply."
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Governing Permit</label>
              <EntitySelector
                entity="permits"
                value={form.permit_id}
                onChange={(id) => update('permit_id', id)}
                renderLabel={(row) =>
                  `${String(row.permit_number ?? '')} — ${String(row.permit_name ?? '')}`
                }
                placeholder="Typically an NPDES permit..."
              />
            </div>
            {isStormwater && (
              <FormField
                type="select"
                label="MSGP Industrial Sector"
                value={form.stormwater_sector_code}
                onChange={(v) => update('stormwater_sector_code', v)}
                options={sectorOptions}
                hint="From the EPA Multi-Sector General Permit."
              />
            )}
            {isStormwater && (
              <div className="flex flex-col gap-1.5">
                <label className="text-xs text-[var(--color-fg)]">Governing SWPPP</label>
                <EntitySelector
                  entity="swpps"
                  value={form.swppp_id}
                  onChange={(id) => update('swppp_id', id)}
                  renderLabel={(row) =>
                    `${String(row.revision_number ?? '')} (eff. ${String(row.effective_date ?? '')})`
                  }
                  placeholder="Select the SWPPP covering this outfall..."
                />
              </div>
            )}
          </div>
        </SectionCard>

        <SectionCard
          title="Upstream Source"
          description="Optional: the process unit whose discharge feeds this outfall (ehs:dischargesTo)."
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Primary Upstream Process Unit</label>
              <EntitySelector
                entity="emission-units"
                value={form.emission_unit_id}
                onChange={(id) => update('emission_unit_id', id)}
                renderLabel={(row) => String(row.unit_name ?? `Unit ${row.id}`)}
                placeholder="Select an emission / process unit..."
              />
            </div>
            <FormField
              type="number"
              label="Pipe Diameter (inches)"
              value={form.pipe_diameter_inches}
              onChange={(v) => update('pipe_diameter_inches', v)}
            />
            <FormField
              type="number"
              label="Typical Flow (MGD)"
              value={form.typical_flow_mgd}
              onChange={(v) => update('typical_flow_mgd', v)}
              hint="Million gallons per day."
            />
          </div>
        </SectionCard>

        <SectionCard title="Geography">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="number"
              label="Latitude"
              value={form.latitude}
              onChange={(v) => update('latitude', v)}
              placeholder="Decimal degrees"
            />
            <FormField
              type="number"
              label="Longitude"
              value={form.longitude}
              onChange={(v) => update('longitude', v)}
              placeholder="Decimal degrees (negative for W)"
            />
          </div>
        </SectionCard>

        <SectionCard title="Lifecycle">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="date"
              label="Installation Date"
              value={form.installation_date}
              onChange={(v) => update('installation_date', v)}
            />
            <FormField
              type="date"
              label="Decommission Date"
              value={form.decommission_date}
              onChange={(v) => update('decommission_date', v)}
              hint="Usually set via the Decommission action on the detail page."
            />
          </div>
        </SectionCard>

        <SectionCard title="Notes">
          <FormField
            type="textarea"
            label="Notes"
            value={form.notes}
            onChange={(v) => update('notes', v)}
            rows={3}
          />
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/discharge-points/${id}` : '/discharge-points')}
        />
      </form>
    </div>
  );
}
