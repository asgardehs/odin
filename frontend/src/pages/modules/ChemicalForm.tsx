import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

// 0/1 flag fields on chemicals — matches `is_*` columns in the schema.
type FlagKey =
  | 'is_flammable' | 'is_oxidizer' | 'is_explosive'
  | 'is_self_reactive' | 'is_pyrophoric' | 'is_self_heating'
  | 'is_organic_peroxide' | 'is_corrosive_to_metal'
  | 'is_gas_under_pressure' | 'is_water_reactive'
  | 'is_acute_toxic' | 'is_skin_corrosion' | 'is_eye_damage'
  | 'is_skin_sensitizer' | 'is_respiratory_sensitizer'
  | 'is_germ_cell_mutagen' | 'is_carcinogen' | 'is_reproductive_toxin'
  | 'is_target_organ_single' | 'is_target_organ_repeat'
  | 'is_aspiration_hazard' | 'is_aquatic_toxic'
  | 'is_ehs' | 'is_sara_313' | 'is_pbt';

const flagKeys: FlagKey[] = [
  'is_flammable', 'is_oxidizer', 'is_explosive',
  'is_self_reactive', 'is_pyrophoric', 'is_self_heating',
  'is_organic_peroxide', 'is_corrosive_to_metal',
  'is_gas_under_pressure', 'is_water_reactive',
  'is_acute_toxic', 'is_skin_corrosion', 'is_eye_damage',
  'is_skin_sensitizer', 'is_respiratory_sensitizer',
  'is_germ_cell_mutagen', 'is_carcinogen', 'is_reproductive_toxin',
  'is_target_organ_single', 'is_target_organ_repeat',
  'is_aspiration_hazard', 'is_aquatic_toxic',
  'is_ehs', 'is_sara_313', 'is_pbt',
];

interface ChemicalFormState {
  establishment_id: number | null;
  product_name: string;
  manufacturer: string;
  manufacturer_phone: string;
  primary_cas_number: string;
  signal_word: string;

  flags: Record<FlagKey, boolean>;

  ehs_tpq_lbs: string;
  ehs_rq_lbs: string;
  sara_313_category: string;

  physical_state: string;
  specific_gravity: string;
  vapor_pressure_mmhg: string;
  flash_point_f: string;
  ph: string;
  appearance: string;
  odor: string;

  storage_requirements: string;
  incompatible_materials: string;
  ppe_required: string;
}

function newState(): ChemicalFormState {
  return {
    establishment_id: null,
    product_name: '',
    manufacturer: '',
    manufacturer_phone: '',
    primary_cas_number: '',
    signal_word: '',
    flags: Object.fromEntries(flagKeys.map(k => [k, false])) as Record<FlagKey, boolean>,
    ehs_tpq_lbs: '',
    ehs_rq_lbs: '',
    sara_313_category: '',
    physical_state: '',
    specific_gravity: '',
    vapor_pressure_mmhg: '',
    flash_point_f: '',
    ph: '',
    appearance: '',
    odor: '',
    storage_requirements: '',
    incompatible_materials: '',
    ppe_required: '',
  };
}

function fromRow(row: Record<string, unknown>): ChemicalFormState {
  const s = (k: string) => (row[k] as string) ?? '';
  const n = (k: string) =>
    row[k] == null ? '' : String(row[k]);
  const flag = (k: FlagKey) => Boolean(row[k]);
  return {
    establishment_id: (row.establishment_id as number) ?? null,
    product_name: s('product_name'),
    manufacturer: s('manufacturer'),
    manufacturer_phone: s('manufacturer_phone'),
    primary_cas_number: s('primary_cas_number'),
    signal_word: s('signal_word'),
    flags: Object.fromEntries(flagKeys.map(k => [k, flag(k)])) as Record<FlagKey, boolean>,
    ehs_tpq_lbs: n('ehs_tpq_lbs'),
    ehs_rq_lbs: n('ehs_rq_lbs'),
    sara_313_category: s('sara_313_category'),
    physical_state: s('physical_state'),
    specific_gravity: n('specific_gravity'),
    vapor_pressure_mmhg: n('vapor_pressure_mmhg'),
    flash_point_f: n('flash_point_f'),
    ph: n('ph'),
    appearance: s('appearance'),
    odor: s('odor'),
    storage_requirements: s('storage_requirements'),
    incompatible_materials: s('incompatible_materials'),
    ppe_required: s('ppe_required'),
  };
}

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}

function numOrNull(s: string): number | null {
  if (s.trim() === '') return null;
  const n = parseFloat(s);
  return Number.isNaN(n) ? null : n;
}

function toBody(f: ChemicalFormState): Record<string, unknown> {
  const body: Record<string, unknown> = {
    establishment_id: f.establishment_id,
    product_name: f.product_name.trim(),
    manufacturer: nullIfBlank(f.manufacturer),
    manufacturer_phone: nullIfBlank(f.manufacturer_phone),
    primary_cas_number: nullIfBlank(f.primary_cas_number),
    signal_word: nullIfBlank(f.signal_word),
    ehs_tpq_lbs: numOrNull(f.ehs_tpq_lbs),
    ehs_rq_lbs: numOrNull(f.ehs_rq_lbs),
    sara_313_category: nullIfBlank(f.sara_313_category),
    physical_state: nullIfBlank(f.physical_state),
    specific_gravity: numOrNull(f.specific_gravity),
    vapor_pressure_mmhg: numOrNull(f.vapor_pressure_mmhg),
    flash_point_f: numOrNull(f.flash_point_f),
    ph: numOrNull(f.ph),
    appearance: nullIfBlank(f.appearance),
    odor: nullIfBlank(f.odor),
    storage_requirements: nullIfBlank(f.storage_requirements),
    incompatible_materials: nullIfBlank(f.incompatible_materials),
    ppe_required: nullIfBlank(f.ppe_required),
  };
  for (const k of flagKeys) {
    body[k] = f.flags[k] ? 1 : 0;
  }
  return body;
}

// Checkbox row — one flag, inline, compact.
function FlagCheckbox({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
      <input
        type="checkbox"
        checked={checked}
        onChange={e => onChange(e.target.checked)}
        className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
      />
      <span className="text-sm text-[var(--color-fg)]">{label}</span>
    </label>
  );
}

export default function ChemicalForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<ChemicalFormState>(newState);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/chemicals/${id}`)
      .then(row => setForm(fromRow(row)))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof ChemicalFormState>(key: K, value: ChemicalFormState[K]) => {
    setForm(prev => ({ ...prev, [key]: value }));
    setDirty(true);
    setValidationError(null);
  };
  const updateFlag = (key: FlagKey, value: boolean) => {
    setForm(prev => ({ ...prev, flags: { ...prev.flags, [key]: value } }));
    setDirty(true);
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (form.establishment_id == null) {
      setValidationError('Facility is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/chemicals/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/chemicals', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/chemicals/${nextId}`);
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
  const title = isEdit ? `Edit ${form.product_name || 'Chemical'}` : 'New Chemical';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/chemicals/${id}` : '/chemicals')}
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
        <SectionCard title="Identity" description="Product identification and manufacturer.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">
                Facility<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
              </label>
              <EntitySelector
                entity="establishments"
                value={form.establishment_id}
                onChange={id => update('establishment_id', id)}
                renderLabel={row => String(row.name ?? `Facility ${row.id}`)}
                placeholder="Select a facility..."
                required
              />
            </div>
            <FormField
              label="Product Name"
              required
              value={form.product_name}
              onChange={v => update('product_name', v)}
              autoFocus
            />
            <FormField
              label="Primary CAS Number"
              value={form.primary_cas_number}
              onChange={v => update('primary_cas_number', v)}
              placeholder="e.g. 7664-93-9"
              hint="Chemical Abstracts Service number. For mixtures, record components separately (future)."
            />
            <FormField
              label="Manufacturer"
              value={form.manufacturer}
              onChange={v => update('manufacturer', v)}
            />
            <FormField
              type="tel"
              label="Manufacturer Phone"
              value={form.manufacturer_phone}
              onChange={v => update('manufacturer_phone', v)}
              placeholder="24-hour emergency line if provided on SDS"
            />
          </div>
        </SectionCard>

        <SectionCard title="GHS Signal Word" description="From Section 2 of the SDS.">
          <FormField
            type="select"
            label="Signal Word"
            value={form.signal_word}
            onChange={v => update('signal_word', v)}
            options={[
              { value: 'Danger', label: 'Danger' },
              { value: 'Warning', label: 'Warning' },
            ]}
            placeholder="— none —"
          />
        </SectionCard>

        <SectionCard title="Physical Hazards" description="GHS physical hazard classes.">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-4 gap-y-1">
            <FlagCheckbox label="Flammable" checked={form.flags.is_flammable} onChange={v => updateFlag('is_flammable', v)} />
            <FlagCheckbox label="Oxidizer" checked={form.flags.is_oxidizer} onChange={v => updateFlag('is_oxidizer', v)} />
            <FlagCheckbox label="Explosive" checked={form.flags.is_explosive} onChange={v => updateFlag('is_explosive', v)} />
            <FlagCheckbox label="Self-reactive" checked={form.flags.is_self_reactive} onChange={v => updateFlag('is_self_reactive', v)} />
            <FlagCheckbox label="Pyrophoric" checked={form.flags.is_pyrophoric} onChange={v => updateFlag('is_pyrophoric', v)} />
            <FlagCheckbox label="Self-heating" checked={form.flags.is_self_heating} onChange={v => updateFlag('is_self_heating', v)} />
            <FlagCheckbox label="Organic peroxide" checked={form.flags.is_organic_peroxide} onChange={v => updateFlag('is_organic_peroxide', v)} />
            <FlagCheckbox label="Corrosive to metal" checked={form.flags.is_corrosive_to_metal} onChange={v => updateFlag('is_corrosive_to_metal', v)} />
            <FlagCheckbox label="Gas under pressure" checked={form.flags.is_gas_under_pressure} onChange={v => updateFlag('is_gas_under_pressure', v)} />
            <FlagCheckbox label="Water-reactive" checked={form.flags.is_water_reactive} onChange={v => updateFlag('is_water_reactive', v)} />
          </div>
        </SectionCard>

        <SectionCard title="Health Hazards" description="GHS health hazard classes.">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-4 gap-y-1">
            <FlagCheckbox label="Acute toxicity" checked={form.flags.is_acute_toxic} onChange={v => updateFlag('is_acute_toxic', v)} />
            <FlagCheckbox label="Skin corrosion/irritation" checked={form.flags.is_skin_corrosion} onChange={v => updateFlag('is_skin_corrosion', v)} />
            <FlagCheckbox label="Serious eye damage" checked={form.flags.is_eye_damage} onChange={v => updateFlag('is_eye_damage', v)} />
            <FlagCheckbox label="Skin sensitizer" checked={form.flags.is_skin_sensitizer} onChange={v => updateFlag('is_skin_sensitizer', v)} />
            <FlagCheckbox label="Respiratory sensitizer" checked={form.flags.is_respiratory_sensitizer} onChange={v => updateFlag('is_respiratory_sensitizer', v)} />
            <FlagCheckbox label="Germ cell mutagen" checked={form.flags.is_germ_cell_mutagen} onChange={v => updateFlag('is_germ_cell_mutagen', v)} />
            <FlagCheckbox label="Carcinogen" checked={form.flags.is_carcinogen} onChange={v => updateFlag('is_carcinogen', v)} />
            <FlagCheckbox label="Reproductive toxin" checked={form.flags.is_reproductive_toxin} onChange={v => updateFlag('is_reproductive_toxin', v)} />
            <FlagCheckbox label="STOT — single exposure" checked={form.flags.is_target_organ_single} onChange={v => updateFlag('is_target_organ_single', v)} />
            <FlagCheckbox label="STOT — repeated exposure" checked={form.flags.is_target_organ_repeat} onChange={v => updateFlag('is_target_organ_repeat', v)} />
            <FlagCheckbox label="Aspiration hazard" checked={form.flags.is_aspiration_hazard} onChange={v => updateFlag('is_aspiration_hazard', v)} />
          </div>
        </SectionCard>

        <SectionCard title="Environmental Hazards">
          <FlagCheckbox label="Aquatic toxicity" checked={form.flags.is_aquatic_toxic} onChange={v => updateFlag('is_aquatic_toxic', v)} />
        </SectionCard>

        <SectionCard
          title="Regulatory"
          description="EPCRA, SARA Title III §313, and TRI classifications."
        >
          <div className="flex flex-col gap-4">
            <div>
              <FlagCheckbox
                label="Extremely Hazardous Substance (EHS)"
                checked={form.flags.is_ehs}
                onChange={v => updateFlag('is_ehs', v)}
              />
              {form.flags.is_ehs && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3 pl-6">
                  <FormField
                    type="number"
                    label="TPQ (lbs)"
                    value={form.ehs_tpq_lbs}
                    onChange={v => update('ehs_tpq_lbs', v)}
                    hint="Threshold Planning Quantity"
                  />
                  <FormField
                    type="number"
                    label="RQ (lbs)"
                    value={form.ehs_rq_lbs}
                    onChange={v => update('ehs_rq_lbs', v)}
                    hint="Reportable Quantity"
                  />
                </div>
              )}
            </div>

            <div>
              <FlagCheckbox
                label="SARA §313 / TRI reportable"
                checked={form.flags.is_sara_313}
                onChange={v => updateFlag('is_sara_313', v)}
              />
              {form.flags.is_sara_313 && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3 pl-6">
                  <FormField
                    label="SARA 313 Category"
                    value={form.sara_313_category}
                    onChange={v => update('sara_313_category', v)}
                    placeholder="e.g. metal, dioxin"
                  />
                </div>
              )}
            </div>

            <FlagCheckbox
              label="PBT (Persistent, Bioaccumulative, Toxic)"
              checked={form.flags.is_pbt}
              onChange={v => updateFlag('is_pbt', v)}
            />
          </div>
        </SectionCard>

        <SectionCard title="Physical Properties">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <FormField
              type="select"
              label="Physical State"
              value={form.physical_state}
              onChange={v => update('physical_state', v)}
              options={[
                { value: 'solid', label: 'Solid' },
                { value: 'liquid', label: 'Liquid' },
                { value: 'gas', label: 'Gas' },
              ]}
              placeholder="— select —"
            />
            <FormField
              type="number"
              label="Specific Gravity"
              value={form.specific_gravity}
              onChange={v => update('specific_gravity', v)}
            />
            <FormField
              type="number"
              label="Vapor Pressure (mmHg)"
              value={form.vapor_pressure_mmhg}
              onChange={v => update('vapor_pressure_mmhg', v)}
            />
            <FormField
              type="number"
              label="Flash Point (°F)"
              value={form.flash_point_f}
              onChange={v => update('flash_point_f', v)}
            />
            <FormField
              type="number"
              label="pH"
              value={form.ph}
              onChange={v => update('ph', v)}
            />
            <FormField
              label="Appearance"
              value={form.appearance}
              onChange={v => update('appearance', v)}
              placeholder="e.g. Clear amber liquid"
            />
            <div className="md:col-span-2 lg:col-span-3">
              <FormField
                label="Odor"
                value={form.odor}
                onChange={v => update('odor', v)}
                placeholder="e.g. Pungent, sulfurous"
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Storage &amp; Handling">
          <div className="flex flex-col gap-4">
            <FormField
              type="textarea"
              label="Storage Requirements"
              value={form.storage_requirements}
              onChange={v => update('storage_requirements', v)}
              placeholder="e.g. Flammable cabinet, keep below 120°F, segregate from oxidizers."
              rows={2}
            />
            <FormField
              type="textarea"
              label="Incompatible Materials"
              value={form.incompatible_materials}
              onChange={v => update('incompatible_materials', v)}
              placeholder="e.g. Strong bases, water, oxidizers."
              rows={2}
            />
            <FormField
              type="textarea"
              label="Required PPE"
              value={form.ppe_required}
              onChange={v => update('ppe_required', v)}
              placeholder="e.g. Nitrile gloves, chemical splash goggles, face shield, apron."
              rows={2}
            />
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/chemicals/${id}` : '/chemicals')}
          saveLabel={isEdit ? 'Save changes' : 'Create chemical'}
        />
      </form>
    </div>
  );
}
