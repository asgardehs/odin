import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const sampleTypeOptions = [
  { value: '', label: '— not specified —' },
  { value: 'grab', label: 'Grab' },
  { value: 'composite', label: 'Composite' },
  { value: 'flow_proportional', label: 'Flow-proportional' },
];

const weatherOptions = [
  { value: '', label: '— not recorded —' },
  { value: 'dry', label: 'Dry' },
  { value: 'rain', label: 'Rain' },
  { value: 'snow', label: 'Snow' },
];

interface WaterSampleEventFormState {
  establishment_id: number | null;
  location_id: number | null;
  event_number: string;
  sample_date: string;
  sample_time: string;
  sampled_by_employee_id: number | null;
  sample_type: string;
  composite_period_hours: string;
  weather_conditions: string;
  equipment_id: number | null;
  lab_submission_id: number | null;
  notes: string;
}

const empty: WaterSampleEventFormState = {
  establishment_id: null,
  location_id: null,
  event_number: '',
  sample_date: '',
  sample_time: '',
  sampled_by_employee_id: null,
  sample_type: 'grab',
  composite_period_hours: '',
  weather_conditions: '',
  equipment_id: null,
  lab_submission_id: null,
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

function toBody(f: WaterSampleEventFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    location_id: f.location_id,
    event_number: nullIfBlank(f.event_number),
    sample_date: f.sample_date,
    sample_time: nullIfBlank(f.sample_time),
    sampled_by_employee_id: f.sampled_by_employee_id,
    sample_type: nullIfBlank(f.sample_type),
    composite_period_hours: numOrNull(f.composite_period_hours),
    weather_conditions: nullIfBlank(f.weather_conditions),
    equipment_id: f.equipment_id,
    lab_submission_id: f.lab_submission_id,
    notes: nullIfBlank(f.notes),
  };
}

export default function WaterSampleEventForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<WaterSampleEventFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api
      .get<Record<string, unknown>>(`/api/ww-sample-events/${id}`)
      .then((row) => {
        const s = (k: string) => (row[k] as string) ?? '';
        const n = (k: string) => (row[k] == null ? '' : String(row[k]));
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          location_id: (row.location_id as number) ?? null,
          event_number: s('event_number'),
          sample_date: s('sample_date'),
          sample_time: s('sample_time'),
          sampled_by_employee_id: (row.sampled_by_employee_id as number) ?? null,
          sample_type: s('sample_type') || 'grab',
          composite_period_hours: n('composite_period_hours'),
          weather_conditions: s('weather_conditions'),
          equipment_id: (row.equipment_id as number) ?? null,
          lab_submission_id: (row.lab_submission_id as number) ?? null,
          notes: s('notes'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof WaterSampleEventFormState>(
    key: K,
    value: WaterSampleEventFormState[K],
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
    if (form.location_id == null) {
      setValidationError('Monitoring location is required.');
      return;
    }
    if (!form.sample_date) {
      setValidationError('Sample date is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/ww-sample-events/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/ww-sample-events', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/ww-sample-events/${nextId}`);
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
  const title = isEdit
    ? `Edit ${form.event_number || form.sample_date || 'Sample Event'}`
    : 'New Sample Event';
  const isComposite = form.sample_type === 'composite';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/ww-sample-events/${id}` : '/ww-sample-events')}
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
        <SectionCard title="Sampling Location" description="Where this sample was collected.">
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
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">
                Monitoring Location<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
              </label>
              <EntitySelector
                entity="ww-monitoring-locations"
                value={form.location_id}
                onChange={(id) => update('location_id', id)}
                renderLabel={(row) =>
                  `${String(row.location_code ?? '')} — ${String(row.location_name ?? '')}`
                }
                placeholder="Select a sampling point..."
                required
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Event Identification">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Event Number"
              value={form.event_number}
              onChange={(v) => update('event_number', v)}
              placeholder="Optional internal tracking number"
              hint="e.g. SE-2026-Q1-001"
            />
            <div />
            <FormField
              type="date"
              label="Sample Date"
              required
              value={form.sample_date}
              onChange={(v) => update('sample_date', v)}
              autoFocus
            />
            <FormField
              label="Sample Time"
              value={form.sample_time}
              onChange={(v) => update('sample_time', v)}
              placeholder="HH:MM (24-hour)"
            />
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Sampled By (Employee)</label>
              <EntitySelector
                entity="employees"
                value={form.sampled_by_employee_id}
                onChange={(id) => update('sampled_by_employee_id', id)}
                renderLabel={(row) =>
                  `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`
                }
                placeholder="Select an employee..."
              />
            </div>
            <FormField
              type="select"
              label="Weather Conditions"
              value={form.weather_conditions}
              onChange={(v) => update('weather_conditions', v)}
              options={weatherOptions}
              hint="Required under some permit conditions (e.g. MSGP)."
            />
          </div>
        </SectionCard>

        <SectionCard title="Sample Collection">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="select"
              label="Sample Type"
              value={form.sample_type}
              onChange={(v) => update('sample_type', v)}
              options={sampleTypeOptions}
            />
            {isComposite && (
              <FormField
                type="number"
                label="Composite Period (hours)"
                value={form.composite_period_hours}
                onChange={(v) => update('composite_period_hours', v)}
                placeholder="e.g. 24"
              />
            )}
          </div>
        </SectionCard>

        <SectionCard title="Notes">
          <FormField
            type="textarea"
            label="Notes"
            value={form.notes}
            onChange={(v) => update('notes', v)}
            rows={3}
            placeholder="Field observations, chain-of-custody notes, etc."
          />
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/ww-sample-events/${id}` : '/ww-sample-events')}
        />
      </form>
    </div>
  );
}
