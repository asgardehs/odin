import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { LookupDropdown } from '../../components/forms/LookupDropdown';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const severityOptions = [
  { value: 'FIRST_AID', label: 'First Aid (not recordable)' },
  { value: 'MEDICAL_TX', label: 'Medical Treatment' },
  { value: 'RESTRICTED', label: 'Restricted Duty' },
  { value: 'LOST_TIME', label: 'Lost Time' },
  { value: 'FATALITY', label: 'Fatality' },
  { value: 'NEAR_MISS', label: 'Near Miss' },
  { value: 'PROPERTY', label: 'Property Damage' },
  { value: 'ENVIRONMENTAL', label: 'Environmental' },
];

interface IncidentFormState {
  establishment_id: number | null;
  employee_id: number | null;
  case_number: string;
  incident_date: string;
  incident_time: string;
  time_employee_began_work: string;
  location_description: string;
  activity_description: string;
  incident_description: string;
  object_or_substance: string;
  case_classification_code: string;
  body_part_code: string;
  severity_code: string;
  treatment_provided: string;
  treating_physician: string;
  treatment_facility: string;
  was_hospitalized: boolean;
  was_er_visit: boolean;
  reported_by: string;
  reported_date: string;
  // OSHA ITA fields (v3.3)
  treatment_facility_type_code: string;
  days_away_from_work: number | null;
  days_restricted_or_transferred: number | null;
  date_of_death: string;
  time_unknown: boolean;
  injury_illness_description: string;
}

const empty: IncidentFormState = {
  establishment_id: null,
  employee_id: null,
  case_number: '',
  incident_date: '',
  incident_time: '',
  time_employee_began_work: '',
  location_description: '',
  activity_description: '',
  incident_description: '',
  object_or_substance: '',
  case_classification_code: '',
  body_part_code: '',
  severity_code: 'FIRST_AID',
  treatment_provided: '',
  treating_physician: '',
  treatment_facility: '',
  was_hospitalized: false,
  was_er_visit: false,
  reported_by: '',
  reported_date: '',
  treatment_facility_type_code: '',
  days_away_from_work: null,
  days_restricted_or_transferred: null,
  date_of_death: '',
  time_unknown: false,
  injury_illness_description: '',
};

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}

function toBody(f: IncidentFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    employee_id: f.employee_id,
    case_number: nullIfBlank(f.case_number),
    incident_date: f.incident_date,
    incident_time: nullIfBlank(f.incident_time),
    time_employee_began_work: nullIfBlank(f.time_employee_began_work),
    location_description: nullIfBlank(f.location_description),
    activity_description: nullIfBlank(f.activity_description),
    incident_description: f.incident_description.trim(),
    object_or_substance: nullIfBlank(f.object_or_substance),
    case_classification_code: nullIfBlank(f.case_classification_code),
    body_part_code: nullIfBlank(f.body_part_code),
    severity_code: f.severity_code,
    treatment_provided: nullIfBlank(f.treatment_provided),
    treating_physician: nullIfBlank(f.treating_physician),
    treatment_facility: nullIfBlank(f.treatment_facility),
    was_hospitalized: f.was_hospitalized ? 1 : 0,
    was_er_visit: f.was_er_visit ? 1 : 0,
    reported_by: nullIfBlank(f.reported_by),
    reported_date: nullIfBlank(f.reported_date),
    treatment_facility_type_code: nullIfBlank(f.treatment_facility_type_code),
    days_away_from_work: f.days_away_from_work,
    days_restricted_or_transferred: f.days_restricted_or_transferred,
    date_of_death: nullIfBlank(f.date_of_death),
    time_unknown: f.time_unknown ? 1 : 0,
    injury_illness_description: nullIfBlank(f.injury_illness_description),
  };
}

function intField(raw: string): number | null {
  if (raw.trim() === '') return null;
  const n = parseInt(raw, 10);
  return Number.isNaN(n) ? null : n;
}

export default function IncidentForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<IncidentFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/incidents/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          employee_id: (row.employee_id as number) ?? null,
          case_number: s('case_number'),
          incident_date: s('incident_date'),
          incident_time: s('incident_time'),
          time_employee_began_work: s('time_employee_began_work'),
          location_description: s('location_description'),
          activity_description: s('activity_description'),
          incident_description: s('incident_description'),
          object_or_substance: s('object_or_substance'),
          case_classification_code: s('case_classification_code'),
          body_part_code: s('body_part_code'),
          severity_code: s('severity_code') || 'FIRST_AID',
          treatment_provided: s('treatment_provided'),
          treating_physician: s('treating_physician'),
          treatment_facility: s('treatment_facility'),
          was_hospitalized: Boolean(row.was_hospitalized),
          was_er_visit: Boolean(row.was_er_visit),
          reported_by: s('reported_by'),
          reported_date: s('reported_date'),
          treatment_facility_type_code: s('treatment_facility_type_code'),
          days_away_from_work: (row.days_away_from_work as number) ?? null,
          days_restricted_or_transferred: (row.days_restricted_or_transferred as number) ?? null,
          date_of_death: s('date_of_death'),
          time_unknown: Boolean(row.time_unknown),
          injury_illness_description: s('injury_illness_description'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof IncidentFormState>(key: K, value: IncidentFormState[K]) => {
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
    if (!form.incident_date) {
      setValidationError('Incident date is required.');
      return;
    }
    if (!form.incident_description.trim()) {
      setValidationError('Incident description is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/incidents/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/incidents', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/incidents/${nextId}`);
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
  const title = isEdit ? `Edit ${form.case_number || 'Incident'}` : 'New Incident';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/incidents/${id}` : '/incidents')}
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
        <SectionCard title="Case" description="OSHA 300/301 case tracking.">
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
              label="Case Number"
              value={form.case_number}
              onChange={v => update('case_number', v)}
              placeholder="e.g. 2026-001"
              hint="Unique per establishment per year."
            />
            <FormField
              type="date"
              label="Incident Date"
              required
              value={form.incident_date}
              onChange={v => update('incident_date', v)}
              autoFocus
            />
            <FormField
              label="Incident Time"
              value={form.incident_time}
              onChange={v => update('incident_time', v)}
              placeholder="HH:MM (24-hour)"
            />
          </div>
        </SectionCard>

        <SectionCard title="Classification & Severity" description="Used for OSHA 300 logs and trend reporting.">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <FormField
              type="select"
              label="Severity"
              required
              value={form.severity_code}
              onChange={v => update('severity_code', v)}
              options={severityOptions}
            />
            <LookupDropdown
              table="case_classifications"
              label="Case Classification"
              value={form.case_classification_code}
              onChange={v => update('case_classification_code', v)}
              placeholder="Select classification"
            />
            <LookupDropdown
              table="body_parts"
              label="Body Part"
              value={form.body_part_code}
              onChange={v => update('body_part_code', v)}
              placeholder="Select body part"
            />
          </div>
        </SectionCard>

        <SectionCard title="When & Where">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Time Employee Began Work"
              value={form.time_employee_began_work}
              onChange={v => update('time_employee_began_work', v)}
              placeholder="HH:MM (OSHA 301 item 11)"
            />
            <div />
            <div className="md:col-span-2">
              <FormField
                label="Location Description"
                value={form.location_description}
                onChange={v => update('location_description', v)}
                placeholder="e.g. Tank farm area B, near tank 3"
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="What Happened" description="OSHA 301 items 13–15.">
          <div className="flex flex-col gap-4">
            <FormField
              type="textarea"
              label="Activity Description"
              value={form.activity_description}
              onChange={v => update('activity_description', v)}
              placeholder="What was the employee doing just before the incident?"
              rows={2}
            />
            <FormField
              type="textarea"
              label="Incident Description"
              required
              value={form.incident_description}
              onChange={v => update('incident_description', v)}
              placeholder="How did the injury/illness occur?"
              rows={3}
            />
            <FormField
              label="Object or Substance"
              value={form.object_or_substance}
              onChange={v => update('object_or_substance', v)}
              placeholder="What harmed the employee?"
            />
          </div>
        </SectionCard>

        <SectionCard title="People Involved">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Employee (if applicable)</label>
              <EntitySelector
                entity="employees"
                value={form.employee_id}
                onChange={id => update('employee_id', id)}
                renderLabel={row =>
                  `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`
                }
                placeholder="None / non-employee incident"
              />
            </div>
            <FormField
              label="Reported By"
              value={form.reported_by}
              onChange={v => update('reported_by', v)}
              placeholder="Name of person reporting"
            />
            <FormField
              type="date"
              label="Reported Date"
              value={form.reported_date}
              onChange={v => update('reported_date', v)}
            />
          </div>
        </SectionCard>

        <SectionCard title="Treatment">
          <div className="flex flex-col gap-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <label className="flex items-center gap-2 h-10 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={form.was_hospitalized}
                  onChange={e => update('was_hospitalized', e.target.checked)}
                  className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
                />
                <span className="text-sm text-[var(--color-fg)]">In-patient hospitalization (triggers OSHA 24-hr report)</span>
              </label>
              <label className="flex items-center gap-2 h-10 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={form.was_er_visit}
                  onChange={e => update('was_er_visit', e.target.checked)}
                  className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
                />
                <span className="text-sm text-[var(--color-fg)]">Emergency room visit</span>
              </label>
            </div>
            <FormField
              type="textarea"
              label="Treatment Provided"
              value={form.treatment_provided}
              onChange={v => update('treatment_provided', v)}
              rows={2}
            />
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                label="Treating Physician"
                value={form.treating_physician}
                onChange={v => update('treating_physician', v)}
                hint="OSHA 301 item 6"
              />
              <FormField
                label="Treatment Facility"
                value={form.treatment_facility}
                onChange={v => update('treatment_facility', v)}
                hint="OSHA 301 item 7 — facility name/address"
              />
              <LookupDropdown
                table="ita_treatment_facility_types"
                label="Treatment Facility Type"
                value={form.treatment_facility_type_code}
                onChange={v => update('treatment_facility_type_code', v)}
                placeholder="Select facility type"
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard
          title="ITA Reporting"
          description="Fields required for OSHA Injury Tracking Application (ITA) submission per 29 CFR 1904.41. Leave blank for non-recordable cases."
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="number"
              label="Days Away From Work"
              value={form.days_away_from_work?.toString() ?? ''}
              onChange={v => update('days_away_from_work', intField(v))}
              hint="29 CFR 1904.7(b)(3) — 180-day cap applies"
            />
            <FormField
              type="number"
              label="Days Restricted or Transferred"
              value={form.days_restricted_or_transferred?.toString() ?? ''}
              onChange={v => update('days_restricted_or_transferred', intField(v))}
              hint="29 CFR 1904.7(b)(4) — 180-day cap shared with Days Away"
            />
            <FormField
              type="date"
              label="Date of Death"
              value={form.date_of_death}
              onChange={v => update('date_of_death', v)}
              hint="Only when case transitions to fatality"
            />
            <FormField
              type="checkbox"
              label="Time of Incident Unknown"
              value={form.time_unknown}
              onChange={v => update('time_unknown', v)}
              hint="Check if exact time cannot be determined (e.g. cumulative exposure, delayed reporting)"
            />
            <div className="md:col-span-2">
              <FormField
                type="textarea"
                label="Injury / Illness Description"
                value={form.injury_illness_description}
                onChange={v => update('injury_illness_description', v)}
                placeholder="Describe the injury or illness itself — body part, nature of harm."
                hint="OSHA 301 item 16 — distinct from the incident description above"
                rows={2}
              />
            </div>
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/incidents/${id}` : '/incidents')}
          saveLabel={isEdit ? 'Save changes' : 'Create incident'}
        />
      </form>
    </div>
  );
}
