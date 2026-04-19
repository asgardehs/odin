import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const categoryOptions = [
  { value: 'hazardous', label: 'Hazardous' },
  { value: 'universal', label: 'Universal' },
  { value: 'used_oil', label: 'Used oil' },
  { value: 'non_hazardous', label: 'Non-hazardous' },
  { value: 'special', label: 'Special' },
];

const physicalFormOptions = [
  { value: 'solid', label: 'Solid' },
  { value: 'liquid', label: 'Liquid' },
  { value: 'sludge', label: 'Sludge' },
  { value: 'gas', label: 'Gas' },
  { value: 'debris', label: 'Debris' },
];

const quantityUnitOptions = [
  { value: 'kg', label: 'kg' },
  { value: 'lbs', label: 'lbs' },
  { value: 'gallons', label: 'gallons' },
  { value: 'drums', label: 'drums' },
  { value: 'liters', label: 'liters' },
];

interface WasteFormState {
  establishment_id: number | null;
  source_chemical_id: number | null;
  stream_code: string;
  stream_name: string;
  description: string;
  generating_process: string;
  source_location: string;
  waste_category: string;
  waste_stream_type_code: string;
  physical_form: string;
  typical_quantity_per_month: string;
  quantity_unit: string;
  is_ignitable: boolean;
  is_corrosive: boolean;
  is_reactive: boolean;
  is_toxic: boolean;
  is_acute_hazardous: boolean;
  handling_instructions: string;
  ppe_required: string;
  incompatible_with: string;
  profile_number: string;
  profile_expiration: string;
}

const empty: WasteFormState = {
  establishment_id: null,
  source_chemical_id: null,
  stream_code: '',
  stream_name: '',
  description: '',
  generating_process: '',
  source_location: '',
  waste_category: 'hazardous',
  waste_stream_type_code: '',
  physical_form: '',
  typical_quantity_per_month: '',
  quantity_unit: 'kg',
  is_ignitable: false,
  is_corrosive: false,
  is_reactive: false,
  is_toxic: false,
  is_acute_hazardous: false,
  handling_instructions: '',
  ppe_required: '',
  incompatible_with: '',
  profile_number: '',
  profile_expiration: '',
};

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}
function numOrNull(s: string): number | null {
  if (s.trim() === '') return null;
  const n = parseFloat(s);
  return Number.isNaN(n) ? null : n;
}

function toBody(f: WasteFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    source_chemical_id: f.source_chemical_id,
    stream_code: nullIfBlank(f.stream_code),
    stream_name: f.stream_name.trim(),
    description: nullIfBlank(f.description),
    generating_process: nullIfBlank(f.generating_process),
    source_location: nullIfBlank(f.source_location),
    waste_category: f.waste_category,
    waste_stream_type_code: nullIfBlank(f.waste_stream_type_code),
    physical_form: nullIfBlank(f.physical_form),
    typical_quantity_per_month: numOrNull(f.typical_quantity_per_month),
    quantity_unit: nullIfBlank(f.quantity_unit),
    is_ignitable: f.is_ignitable ? 1 : 0,
    is_corrosive: f.is_corrosive ? 1 : 0,
    is_reactive: f.is_reactive ? 1 : 0,
    is_toxic: f.is_toxic ? 1 : 0,
    is_acute_hazardous: f.is_acute_hazardous ? 1 : 0,
    handling_instructions: nullIfBlank(f.handling_instructions),
    ppe_required: nullIfBlank(f.ppe_required),
    incompatible_with: nullIfBlank(f.incompatible_with),
    profile_number: nullIfBlank(f.profile_number),
    profile_expiration: nullIfBlank(f.profile_expiration),
  };
}

export default function WasteForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<WasteFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/waste-streams/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        const n = (k: string) => (row[k] == null ? '' : String(row[k]));
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          source_chemical_id: (row.source_chemical_id as number) ?? null,
          stream_code: s('stream_code'),
          stream_name: s('stream_name'),
          description: s('description'),
          generating_process: s('generating_process'),
          source_location: s('source_location'),
          waste_category: s('waste_category') || 'hazardous',
          waste_stream_type_code: s('waste_stream_type_code'),
          physical_form: s('physical_form'),
          typical_quantity_per_month: n('typical_quantity_per_month'),
          quantity_unit: s('quantity_unit') || 'kg',
          is_ignitable: Boolean(row.is_ignitable),
          is_corrosive: Boolean(row.is_corrosive),
          is_reactive: Boolean(row.is_reactive),
          is_toxic: Boolean(row.is_toxic),
          is_acute_hazardous: Boolean(row.is_acute_hazardous),
          handling_instructions: s('handling_instructions'),
          ppe_required: s('ppe_required'),
          incompatible_with: s('incompatible_with'),
          profile_number: s('profile_number'),
          profile_expiration: s('profile_expiration'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof WasteFormState>(key: K, value: WasteFormState[K]) => {
    setForm(prev => ({ ...prev, [key]: value }));
    setDirty(true);
    setValidationError(null);
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (form.establishment_id == null) { setValidationError('Facility is required.'); return; }
    if (!form.stream_name.trim()) { setValidationError('Stream name is required.'); return; }
    if (!form.waste_category) { setValidationError('Waste category is required.'); return; }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/waste-streams/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/waste-streams', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/waste/${nextId}`);
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
  const title = isEdit ? `Edit ${form.stream_name || 'Waste Stream'}` : 'New Waste Stream';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/waste/${id}` : '/waste')}
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
        <SectionCard title="Stream Identity">
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
              label="Stream Code"
              value={form.stream_code}
              onChange={v => update('stream_code', v)}
              placeholder="e.g. WS-001"
            />
            <div className="md:col-span-2">
              <FormField
                label="Stream Name"
                required
                value={form.stream_name}
                onChange={v => update('stream_name', v)}
                autoFocus
              />
            </div>
            <div className="md:col-span-2">
              <FormField
                type="textarea"
                label="Description"
                value={form.description}
                onChange={v => update('description', v)}
                rows={2}
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Source">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Generating Process"
              value={form.generating_process}
              onChange={v => update('generating_process', v)}
              placeholder="e.g. Degreasing line, metal finishing"
            />
            <FormField
              label="Source Location"
              value={form.source_location}
              onChange={v => update('source_location', v)}
              placeholder="e.g. Building A, tank farm"
            />
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Source Chemical (if applicable)</label>
              <EntitySelector
                entity="chemicals"
                value={form.source_chemical_id}
                onChange={id => update('source_chemical_id', id)}
                renderLabel={row => String(row.product_name ?? `Chemical ${row.id}`)}
                placeholder="Optional — link to chemical inventory"
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Classification">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="select"
              label="Waste Category"
              required
              value={form.waste_category}
              onChange={v => update('waste_category', v)}
              options={categoryOptions}
            />
            <FormField
              label="Waste Stream Type Code"
              value={form.waste_stream_type_code}
              onChange={v => update('waste_stream_type_code', v)}
              placeholder="hazardous, universal, used_oil, non_hazardous, industrial_wastewater"
              hint="Regulatory-program code. Must match a row in waste_stream_types."
            />
          </div>
        </SectionCard>

        <SectionCard title="Physical Form &amp; Quantity">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <FormField
              type="select"
              label="Physical Form"
              value={form.physical_form}
              onChange={v => update('physical_form', v)}
              options={physicalFormOptions}
              placeholder="— select —"
            />
            <FormField
              type="number"
              label="Typical Quantity / Month"
              value={form.typical_quantity_per_month}
              onChange={v => update('typical_quantity_per_month', v)}
            />
            <FormField
              type="select"
              label="Quantity Unit"
              value={form.quantity_unit}
              onChange={v => update('quantity_unit', v)}
              options={quantityUnitOptions}
            />
          </div>
        </SectionCard>

        <SectionCard title="Hazard Characteristics" description="RCRA hazardous waste characteristic codes.">
          <div className="grid grid-cols-2 md:grid-cols-3 gap-x-4 gap-y-1">
            <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
              <input type="checkbox" checked={form.is_ignitable} onChange={e => update('is_ignitable', e.target.checked)} className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer" />
              <span className="text-sm text-[var(--color-fg)]">Ignitable (D001)</span>
            </label>
            <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
              <input type="checkbox" checked={form.is_corrosive} onChange={e => update('is_corrosive', e.target.checked)} className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer" />
              <span className="text-sm text-[var(--color-fg)]">Corrosive (D002)</span>
            </label>
            <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
              <input type="checkbox" checked={form.is_reactive} onChange={e => update('is_reactive', e.target.checked)} className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer" />
              <span className="text-sm text-[var(--color-fg)]">Reactive (D003)</span>
            </label>
            <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
              <input type="checkbox" checked={form.is_toxic} onChange={e => update('is_toxic', e.target.checked)} className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer" />
              <span className="text-sm text-[var(--color-fg)]">Toxic (D004–D043)</span>
            </label>
            <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
              <input type="checkbox" checked={form.is_acute_hazardous} onChange={e => update('is_acute_hazardous', e.target.checked)} className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer" />
              <span className="text-sm text-[var(--color-fg)]">Acute Hazardous (P-list / acute F)</span>
            </label>
          </div>
        </SectionCard>

        <SectionCard title="Handling">
          <div className="flex flex-col gap-4">
            <FormField
              type="textarea"
              label="Handling Instructions"
              value={form.handling_instructions}
              onChange={v => update('handling_instructions', v)}
              rows={2}
            />
            <FormField
              type="textarea"
              label="Required PPE"
              value={form.ppe_required}
              onChange={v => update('ppe_required', v)}
              rows={2}
            />
            <FormField
              type="textarea"
              label="Incompatible With"
              value={form.incompatible_with}
              onChange={v => update('incompatible_with', v)}
              rows={2}
              placeholder="Substances, conditions, or other streams to keep segregated."
            />
          </div>
        </SectionCard>

        <SectionCard title="Waste Profile">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Profile Number"
              value={form.profile_number}
              onChange={v => update('profile_number', v)}
              hint="Assigned by TSDF or broker on approved profile."
            />
            <FormField
              type="date"
              label="Profile Expiration"
              value={form.profile_expiration}
              onChange={v => update('profile_expiration', v)}
            />
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/waste/${id}` : '/waste')}
          saveLabel={isEdit ? 'Save changes' : 'Create waste stream'}
        />
      </form>
    </div>
  );
}
