import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const resultOptions = [
  { value: 'pass', label: 'Pass' },
  { value: 'pass_with_findings', label: 'Pass with findings' },
  { value: 'fail', label: 'Fail' },
  { value: 'not_applicable', label: 'Not applicable' },
];

interface InspectionFormState {
  establishment_id: number | null;
  inspection_type_id: number | null;
  inspector_id: number | null;
  inspection_number: string;
  scheduled_date: string;
  inspection_date: string;
  inspector_name: string;
  areas_inspected: string;
  is_storm_triggered: boolean;
  storm_date: string;
  rainfall_inches: string;
  weather_conditions: string;
  temperature_f: string;
  overall_result: string;
  summary_notes: string;
}

const empty: InspectionFormState = {
  establishment_id: null,
  inspection_type_id: null,
  inspector_id: null,
  inspection_number: '',
  scheduled_date: '',
  inspection_date: '',
  inspector_name: '',
  areas_inspected: '',
  is_storm_triggered: false,
  storm_date: '',
  rainfall_inches: '',
  weather_conditions: '',
  temperature_f: '',
  overall_result: '',
  summary_notes: '',
};

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}

function numOrNull(s: string): number | null {
  if (s.trim() === '') return null;
  const n = parseFloat(s);
  return Number.isNaN(n) ? null : n;
}

function intOrNull(s: string): number | null {
  if (s.trim() === '') return null;
  const n = parseInt(s, 10);
  return Number.isNaN(n) ? null : n;
}

function toBody(f: InspectionFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    inspection_type_id: f.inspection_type_id,
    inspector_id: f.inspector_id,
    inspection_number: nullIfBlank(f.inspection_number),
    scheduled_date: nullIfBlank(f.scheduled_date),
    inspection_date: f.inspection_date,
    inspector_name: nullIfBlank(f.inspector_name),
    areas_inspected: nullIfBlank(f.areas_inspected),
    is_storm_triggered: f.is_storm_triggered ? 1 : 0,
    storm_date: nullIfBlank(f.storm_date),
    rainfall_inches: numOrNull(f.rainfall_inches),
    weather_conditions: nullIfBlank(f.weather_conditions),
    temperature_f: intOrNull(f.temperature_f),
    overall_result: nullIfBlank(f.overall_result),
    summary_notes: nullIfBlank(f.summary_notes),
  };
}

export default function InspectionForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<InspectionFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/inspections/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        const n = (k: string) => (row[k] == null ? '' : String(row[k]));
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          inspection_type_id: (row.inspection_type_id as number) ?? null,
          inspector_id: (row.inspector_id as number) ?? null,
          inspection_number: s('inspection_number'),
          scheduled_date: s('scheduled_date'),
          inspection_date: s('inspection_date'),
          inspector_name: s('inspector_name'),
          areas_inspected: s('areas_inspected'),
          is_storm_triggered: Boolean(row.is_storm_triggered),
          storm_date: s('storm_date'),
          rainfall_inches: n('rainfall_inches'),
          weather_conditions: s('weather_conditions'),
          temperature_f: n('temperature_f'),
          overall_result: s('overall_result'),
          summary_notes: s('summary_notes'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof InspectionFormState>(key: K, value: InspectionFormState[K]) => {
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
    if (form.inspection_type_id == null) {
      setValidationError('Inspection type is required.');
      return;
    }
    if (!form.inspection_date) {
      setValidationError('Inspection date is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/inspections/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/inspections', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/inspections/${nextId}`);
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
  const title = isEdit ? `Edit ${form.inspection_number || 'Inspection'}` : 'New Inspection';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/inspections/${id}` : '/inspections')}
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
        <SectionCard title="Scheduling" description="What kind of inspection and when.">
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
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">
                Inspection Type<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
              </label>
              <EntitySelector
                entity="inspection-types"
                value={form.inspection_type_id}
                onChange={id => update('inspection_type_id', id)}
                renderLabel={row =>
                  `${String(row.type_code ?? '')} — ${String(row.type_name ?? '')}`
                }
                placeholder="Select an inspection type..."
                required
              />
            </div>
            <FormField
              label="Inspection Number"
              value={form.inspection_number}
              onChange={v => update('inspection_number', v)}
              placeholder="e.g. SWPPP-2026-Q1"
            />
            <FormField
              type="date"
              label="Scheduled Date"
              value={form.scheduled_date}
              onChange={v => update('scheduled_date', v)}
            />
            <FormField
              type="date"
              label="Inspection Date"
              required
              value={form.inspection_date}
              onChange={v => update('inspection_date', v)}
              autoFocus
            />
          </div>
        </SectionCard>

        <SectionCard title="Inspector">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Internal Inspector (Employee)</label>
              <EntitySelector
                entity="employees"
                value={form.inspector_id}
                onChange={id => update('inspector_id', id)}
                renderLabel={row =>
                  `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`
                }
                placeholder="Pick an employee or leave blank for external"
              />
            </div>
            <FormField
              label="External Inspector Name"
              value={form.inspector_name}
              onChange={v => update('inspector_name', v)}
              placeholder="If external — e.g. agency inspector"
            />
          </div>
        </SectionCard>

        <SectionCard title="Scope">
          <FormField
            type="textarea"
            label="Areas Inspected"
            value={form.areas_inspected}
            onChange={v => update('areas_inspected', v)}
            placeholder="Description of areas covered during inspection"
            rows={2}
          />
        </SectionCard>

        <SectionCard title="Storm &amp; Weather" description="For SWPPP and outdoor inspections.">
          <div className="flex flex-col gap-4">
            <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={form.is_storm_triggered}
                onChange={e => update('is_storm_triggered', e.target.checked)}
                className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
              />
              <span className="text-sm text-[var(--color-fg)]">Storm-triggered (SWPPP)</span>
            </label>
            {form.is_storm_triggered && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pl-6">
                <FormField
                  type="date"
                  label="Storm Date"
                  value={form.storm_date}
                  onChange={v => update('storm_date', v)}
                />
                <FormField
                  type="number"
                  label="Rainfall (inches)"
                  value={form.rainfall_inches}
                  onChange={v => update('rainfall_inches', v)}
                />
              </div>
            )}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                label="Weather Conditions"
                value={form.weather_conditions}
                onChange={v => update('weather_conditions', v)}
                placeholder="e.g. Clear, light breeze"
              />
              <FormField
                type="number"
                label="Temperature (°F)"
                value={form.temperature_f}
                onChange={v => update('temperature_f', v)}
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Outcome">
          <div className="flex flex-col gap-4">
            <FormField
              type="select"
              label="Overall Result"
              value={form.overall_result}
              onChange={v => update('overall_result', v)}
              options={resultOptions}
              placeholder="— not set —"
              hint="Set on completion. Can be revised in edit."
            />
            <FormField
              type="textarea"
              label="Summary Notes"
              value={form.summary_notes}
              onChange={v => update('summary_notes', v)}
              rows={3}
              placeholder="High-level summary. Record specific findings via the Findings section on the detail page."
            />
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/inspections/${id}` : '/inspections')}
          saveLabel={isEdit ? 'Save changes' : 'Create inspection'}
        />
      </form>
    </div>
  );
}
