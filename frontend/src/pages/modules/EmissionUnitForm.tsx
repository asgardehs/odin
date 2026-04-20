import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const sourceCategoryOptions = [
  { value: 'welding', label: 'Welding' },
  { value: 'coating', label: 'Coating' },
  { value: 'combustion', label: 'Combustion' },
  { value: 'solvent', label: 'Solvent' },
  { value: 'material_handling', label: 'Material handling' },
];

interface EmissionUnitFormState {
  establishment_id: number | null;
  unit_name: string;
  unit_description: string;
  source_category: string;
  scc_code: string;
  is_fugitive: boolean;
  building: string;
  area: string;
  stack_id: number | null;
  permit_type_code: string;
  permit_number: string;
  max_throughput: string;
  max_throughput_unit: string;
  max_operating_hours_year: string;
  typical_operating_hours_year: string;
  restricted_throughput: string;
  restricted_throughput_unit: string;
  restricted_hours_year: string;
  install_date: string;
  decommission_date: string;
  notes: string;
}

const empty: EmissionUnitFormState = {
  establishment_id: null,
  unit_name: '',
  unit_description: '',
  source_category: 'combustion',
  scc_code: '',
  is_fugitive: false,
  building: '',
  area: '',
  stack_id: null,
  permit_type_code: '',
  permit_number: '',
  max_throughput: '',
  max_throughput_unit: '',
  max_operating_hours_year: '8760',
  typical_operating_hours_year: '',
  restricted_throughput: '',
  restricted_throughput_unit: '',
  restricted_hours_year: '',
  install_date: '',
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

function toBody(f: EmissionUnitFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    unit_name: f.unit_name.trim(),
    unit_description: nullIfBlank(f.unit_description),
    source_category: f.source_category,
    scc_code: nullIfBlank(f.scc_code),
    is_fugitive: f.is_fugitive ? 1 : 0,
    building: nullIfBlank(f.building),
    area: nullIfBlank(f.area),
    stack_id: f.stack_id,
    permit_type_code: nullIfBlank(f.permit_type_code),
    permit_number: nullIfBlank(f.permit_number),
    max_throughput: numOrNull(f.max_throughput),
    max_throughput_unit: nullIfBlank(f.max_throughput_unit),
    max_operating_hours_year: numOrNull(f.max_operating_hours_year),
    typical_operating_hours_year: numOrNull(f.typical_operating_hours_year),
    restricted_throughput: numOrNull(f.restricted_throughput),
    restricted_throughput_unit: nullIfBlank(f.restricted_throughput_unit),
    restricted_hours_year: numOrNull(f.restricted_hours_year),
    install_date: nullIfBlank(f.install_date),
    decommission_date: nullIfBlank(f.decommission_date),
    notes: nullIfBlank(f.notes),
  };
}

interface PermitTypeOption { code: string; name: string; }

export default function EmissionUnitForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<EmissionUnitFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const [permitTypes, setPermitTypes] = useState<PermitTypeOption[]>([]);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    api.get<{ data: PermitTypeOption[] }>('/api/air-permit-types?per_page=100')
      .then(r => setPermitTypes(r.data ?? []))
      .catch(() => setPermitTypes([]));
  }, []);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/emission-units/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        const n = (k: string) => (row[k] == null ? '' : String(row[k]));
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          unit_name: s('unit_name'),
          unit_description: s('unit_description'),
          source_category: s('source_category') || 'combustion',
          scc_code: s('scc_code'),
          is_fugitive: Boolean(row.is_fugitive),
          building: s('building'),
          area: s('area'),
          stack_id: (row.stack_id as number) ?? null,
          permit_type_code: s('permit_type_code'),
          permit_number: s('permit_number'),
          max_throughput: n('max_throughput'),
          max_throughput_unit: s('max_throughput_unit'),
          max_operating_hours_year: n('max_operating_hours_year'),
          typical_operating_hours_year: n('typical_operating_hours_year'),
          restricted_throughput: n('restricted_throughput'),
          restricted_throughput_unit: s('restricted_throughput_unit'),
          restricted_hours_year: n('restricted_hours_year'),
          install_date: s('install_date'),
          decommission_date: s('decommission_date'),
          notes: s('notes'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof EmissionUnitFormState>(key: K, value: EmissionUnitFormState[K]) => {
    setForm(prev => ({ ...prev, [key]: value }));
    setDirty(true);
    setValidationError(null);
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (form.establishment_id == null) {
      setValidationError('Facility is required.');
      return;
    }
    if (!form.unit_name.trim()) {
      setValidationError('Unit name is required.');
      return;
    }
    if (!form.source_category) {
      setValidationError('Source category is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/emission-units/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/emission-units', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/emission-units/${nextId}`);
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
  const title = isEdit ? `Edit ${form.unit_name || 'Emission Unit'}` : 'New Emission Unit';
  const permitTypeOptions = [
    ...permitTypes.map(p => ({ value: p.code, label: `${p.code} — ${p.name}` })),
  ];

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/emission-units/${id}` : '/emission-units')}
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
        <SectionCard title="Identity" description="Name and describe this emission unit.">
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
              label="Unit Name"
              required
              value={form.unit_name}
              onChange={v => update('unit_name', v)}
              placeholder="e.g. Weld Cell 1, Paint Booth A, Boiler #2"
              autoFocus
            />
            <div className="md:col-span-2">
              <FormField
                type="textarea"
                label="Description"
                value={form.unit_description}
                onChange={v => update('unit_description', v)}
                rows={2}
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Source Classification" description="EPA category and SCC code.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="select"
              label="Source Category"
              required
              value={form.source_category}
              onChange={v => update('source_category', v)}
              options={sourceCategoryOptions}
            />
            <FormField
              label="SCC Code"
              value={form.scc_code}
              onChange={v => update('scc_code', v)}
              placeholder="EPA Source Classification Code"
            />
            <div className="md:col-span-2">
              <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={form.is_fugitive}
                  onChange={e => update('is_fugitive', e.target.checked)}
                  className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
                />
                <span className="text-sm text-[var(--color-fg)]">
                  Fugitive emission source (no stack — LDAR applies)
                </span>
              </label>
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Location">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Building"
              value={form.building}
              onChange={v => update('building', v)}
            />
            <FormField
              label="Area"
              value={form.area}
              onChange={v => update('area', v)}
              placeholder="Production line, zone, cell"
            />
            {!form.is_fugitive && (
              <div className="md:col-span-2">
                <div className="flex flex-col gap-1.5">
                  <label className="text-xs text-[var(--color-fg)]">Vents to Stack</label>
                  <EntitySelector
                    entity="air-stacks"
                    value={form.stack_id}
                    onChange={id => update('stack_id', id)}
                    renderLabel={row =>
                      `${String(row.stack_name ?? '')}${row.stack_number ? ' (' + row.stack_number + ')' : ''}`
                    }
                    placeholder="Optional — leave blank if not yet defined"
                  />
                </div>
              </div>
            )}
          </div>
        </SectionCard>

        <SectionCard title="Permit" description="Which air permit covers this unit.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="select"
              label="Permit Type"
              value={form.permit_type_code}
              onChange={v => update('permit_type_code', v)}
              options={permitTypeOptions}
              placeholder="— not covered / TBD —"
            />
            <FormField
              label="Permit Number"
              value={form.permit_number}
              onChange={v => update('permit_number', v)}
              placeholder="State-assigned number"
            />
          </div>
        </SectionCard>

        <SectionCard title="Operating Parameters" description="Used for potential-to-emit (PTE) calculations.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="number"
              label="Max Throughput"
              value={form.max_throughput}
              onChange={v => update('max_throughput', v)}
            />
            <FormField
              label="Throughput Unit"
              value={form.max_throughput_unit}
              onChange={v => update('max_throughput_unit', v)}
              placeholder="tons/hr, gallons/day, MMBtu/hr"
            />
            <FormField
              type="number"
              label="Max Operating Hours / Year"
              value={form.max_operating_hours_year}
              onChange={v => update('max_operating_hours_year', v)}
              hint="8760 = 24/365, default for PTE unless restricted"
            />
            <FormField
              type="number"
              label="Typical Operating Hours / Year"
              value={form.typical_operating_hours_year}
              onChange={v => update('typical_operating_hours_year', v)}
              hint="Used for actual emissions"
            />
          </div>
        </SectionCard>

        <SectionCard
          title="Federally Enforceable Restrictions"
          description="FESOP / synthetic minor limits. Leave blank if unit is not restricted."
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="number"
              label="Restricted Throughput"
              value={form.restricted_throughput}
              onChange={v => update('restricted_throughput', v)}
            />
            <FormField
              label="Restricted Throughput Unit"
              value={form.restricted_throughput_unit}
              onChange={v => update('restricted_throughput_unit', v)}
            />
            <FormField
              type="number"
              label="Restricted Hours / Year"
              value={form.restricted_hours_year}
              onChange={v => update('restricted_hours_year', v)}
            />
          </div>
        </SectionCard>

        <SectionCard title="Service Dates">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="date"
              label="Install Date"
              value={form.install_date}
              onChange={v => update('install_date', v)}
            />
            <FormField
              type="date"
              label="Decommission Date"
              value={form.decommission_date}
              onChange={v => update('decommission_date', v)}
              hint="Set by the Decommission action — edit here only to correct."
            />
            <div className="md:col-span-2">
              <FormField
                type="textarea"
                label="Notes"
                value={form.notes}
                onChange={v => update('notes', v)}
                rows={2}
              />
            </div>
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/emission-units/${id}` : '/emission-units')}
          saveLabel={isEdit ? 'Save changes' : 'Create emission unit'}
        />
      </form>
    </div>
  );
}
