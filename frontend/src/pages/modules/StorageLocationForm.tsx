import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const pressureOptions = [
  { value: 'ambient', label: 'Ambient' },
  { value: 'above_ambient', label: 'Above ambient' },
  { value: 'below_ambient', label: 'Below ambient' },
];

const temperatureOptions = [
  { value: 'ambient', label: 'Ambient' },
  { value: 'above_ambient', label: 'Above ambient' },
  { value: 'below_ambient', label: 'Below ambient' },
  { value: 'cryogenic', label: 'Cryogenic' },
];

interface FormState {
  establishment_id: number | null;
  building: string;
  room: string;
  area: string;
  grid_reference: string;
  latitude: string;
  longitude: string;
  is_indoor: boolean;
  storage_pressure: string;
  storage_temperature: string;
  container_types: string;
  max_capacity_gallons: string;
}

const empty: FormState = {
  establishment_id: null,
  building: '',
  room: '',
  area: '',
  grid_reference: '',
  latitude: '',
  longitude: '',
  is_indoor: true,
  storage_pressure: 'ambient',
  storage_temperature: 'ambient',
  container_types: '',
  max_capacity_gallons: '',
};

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}
function numOrNull(s: string): number | null {
  if (s.trim() === '') return null;
  const n = parseFloat(s);
  return Number.isNaN(n) ? null : n;
}

function toBody(f: FormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    building: f.building.trim(),
    room: nullIfBlank(f.room),
    area: nullIfBlank(f.area),
    grid_reference: nullIfBlank(f.grid_reference),
    latitude: numOrNull(f.latitude),
    longitude: numOrNull(f.longitude),
    is_indoor: f.is_indoor ? 1 : 0,
    storage_pressure: nullIfBlank(f.storage_pressure),
    storage_temperature: nullIfBlank(f.storage_temperature),
    container_types: nullIfBlank(f.container_types),
    max_capacity_gallons: numOrNull(f.max_capacity_gallons),
  };
}

export default function StorageLocationForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<FormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/storage-locations/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        const n = (k: string) => (row[k] == null ? '' : String(row[k]));
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          building: s('building'),
          room: s('room'),
          area: s('area'),
          grid_reference: s('grid_reference'),
          latitude: n('latitude'),
          longitude: n('longitude'),
          is_indoor: row.is_indoor == null ? true : Boolean(row.is_indoor),
          storage_pressure: s('storage_pressure') || 'ambient',
          storage_temperature: s('storage_temperature') || 'ambient',
          container_types: s('container_types'),
          max_capacity_gallons: n('max_capacity_gallons'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof FormState>(key: K, value: FormState[K]) => {
    setForm(prev => ({ ...prev, [key]: value }));
    setDirty(true);
    setValidationError(null);
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (form.establishment_id == null) { setValidationError('Facility is required.'); return; }
    if (!form.building.trim()) { setValidationError('Building is required.'); return; }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/storage-locations/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/storage-locations', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/storage-locations/${nextId}`);
    } catch {
      // saveError surfaces
    }
  }

  if (loading) {
    return <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">Loading…</div>;
  }

  const errorMessage = validationError ?? saveError;
  const title = isEdit ? `Edit ${form.building || 'Storage Location'}` : 'New Storage Location';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button type="button" onClick={() => navigate(isEdit ? `/storage-locations/${id}` : '/storage-locations')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors">
          ← Cancel
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">{title}</h1>
      </div>

      {errorMessage && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {errorMessage}
        </div>
      )}

      <form onSubmit={submit} className="flex flex-col gap-6 max-w-4xl">
        <SectionCard title="Location Hierarchy" description="Where this storage sits within the facility.">
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
            <FormField label="Building" required value={form.building} onChange={v => update('building', v)}
              autoFocus placeholder="e.g. Building A" />
            <FormField label="Room" value={form.room} onChange={v => update('room', v)} placeholder="e.g. 101, Mezzanine" />
            <FormField label="Area" value={form.area} onChange={v => update('area', v)}
              placeholder="e.g. Flammable Cabinet 3, Tank Farm Bay 2" />
          </div>
        </SectionCard>

        <SectionCard title="Site Map">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <FormField label="Grid Reference" value={form.grid_reference} onChange={v => update('grid_reference', v)}
              placeholder="e.g. B-7" hint="Tier II site plan reference." />
            <FormField type="number" label="Latitude" value={form.latitude} onChange={v => update('latitude', v)} />
            <FormField type="number" label="Longitude" value={form.longitude} onChange={v => update('longitude', v)} />
          </div>
        </SectionCard>

        <SectionCard title="Storage Conditions">
          <div className="flex flex-col gap-4">
            <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
              <input type="checkbox" checked={form.is_indoor} onChange={e => update('is_indoor', e.target.checked)}
                className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer" />
              <span className="text-sm text-[var(--color-fg)]">Indoor storage</span>
            </label>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField type="select" label="Pressure" value={form.storage_pressure}
                onChange={v => update('storage_pressure', v)} options={pressureOptions} />
              <FormField type="select" label="Temperature" value={form.storage_temperature}
                onChange={v => update('storage_temperature', v)} options={temperatureOptions} />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Containers">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField label="Container Types" value={form.container_types} onChange={v => update('container_types', v)}
              placeholder="tank, drum, tote, cylinder (comma-separated)" />
            <FormField type="number" label="Max Capacity (gallons)" value={form.max_capacity_gallons}
              onChange={v => update('max_capacity_gallons', v)} />
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/storage-locations/${id}` : '/storage-locations')}
          saveLabel={isEdit ? 'Save changes' : 'Create storage location'}
        />
      </form>
    </div>
  );
}
