import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const classificationOptions = [
  { value: 'major', label: 'Major' },
  { value: 'minor', label: 'Minor' },
  { value: 'synthetic_minor', label: 'Synthetic minor' },
  { value: 'area_source', label: 'Area source' },
];

interface PermitFormState {
  establishment_id: number | null;
  permit_type_id: number | null;
  issuing_agency_id: number | null;
  internal_owner_id: number | null;
  permit_number: string;
  permit_name: string;
  application_date: string;
  application_number: string;
  issue_date: string;
  effective_date: string;
  expiration_date: string;
  permit_classification: string;
  coverage_description: string;
  annual_fee: string;
  fee_due_date: string;
  notes: string;
}

const empty: PermitFormState = {
  establishment_id: null,
  permit_type_id: null,
  issuing_agency_id: null,
  internal_owner_id: null,
  permit_number: '',
  permit_name: '',
  application_date: '',
  application_number: '',
  issue_date: '',
  effective_date: '',
  expiration_date: '',
  permit_classification: '',
  coverage_description: '',
  annual_fee: '',
  fee_due_date: '',
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

function toBody(f: PermitFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    permit_type_id: f.permit_type_id,
    issuing_agency_id: f.issuing_agency_id,
    internal_owner_id: f.internal_owner_id,
    permit_number: f.permit_number.trim(),
    permit_name: nullIfBlank(f.permit_name),
    application_date: nullIfBlank(f.application_date),
    application_number: nullIfBlank(f.application_number),
    issue_date: nullIfBlank(f.issue_date),
    effective_date: nullIfBlank(f.effective_date),
    expiration_date: nullIfBlank(f.expiration_date),
    permit_classification: nullIfBlank(f.permit_classification),
    coverage_description: nullIfBlank(f.coverage_description),
    annual_fee: numOrNull(f.annual_fee),
    fee_due_date: nullIfBlank(f.fee_due_date),
    notes: nullIfBlank(f.notes),
  };
}

export default function PermitForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<PermitFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/permits/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        const n = (k: string) => (row[k] == null ? '' : String(row[k]));
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          permit_type_id: (row.permit_type_id as number) ?? null,
          issuing_agency_id: (row.issuing_agency_id as number) ?? null,
          internal_owner_id: (row.internal_owner_id as number) ?? null,
          permit_number: s('permit_number'),
          permit_name: s('permit_name'),
          application_date: s('application_date'),
          application_number: s('application_number'),
          issue_date: s('issue_date'),
          effective_date: s('effective_date'),
          expiration_date: s('expiration_date'),
          permit_classification: s('permit_classification'),
          coverage_description: s('coverage_description'),
          annual_fee: n('annual_fee'),
          fee_due_date: s('fee_due_date'),
          notes: s('notes'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof PermitFormState>(key: K, value: PermitFormState[K]) => {
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
    if (form.permit_type_id == null) {
      setValidationError('Permit type is required.');
      return;
    }
    if (!form.permit_number.trim()) {
      setValidationError('Permit number is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/permits/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/permits', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/permits/${nextId}`);
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
  const title = isEdit ? `Edit ${form.permit_number || 'Permit'}` : 'New Permit';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/permits/${id}` : '/permits')}
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
        <SectionCard title="Identity" description="Permit identification and classification.">
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
                Permit Type<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
              </label>
              <EntitySelector
                entity="permit-types"
                value={form.permit_type_id}
                onChange={id => update('permit_type_id', id)}
                renderLabel={row => {
                  const cat = row.category ? `[${String(row.category)}] ` : '';
                  return `${cat}${String(row.type_code ?? '')} — ${String(row.type_name ?? '')}`;
                }}
                placeholder="Select a permit type..."
                required
              />
            </div>
            <FormField
              label="Permit Number"
              required
              value={form.permit_number}
              onChange={v => update('permit_number', v)}
              autoFocus
              hint="Unique per facility."
            />
            <FormField
              label="Permit Name"
              value={form.permit_name}
              onChange={v => update('permit_name', v)}
              placeholder="Descriptive name"
            />
            <FormField
              type="select"
              label="Classification"
              value={form.permit_classification}
              onChange={v => update('permit_classification', v)}
              options={classificationOptions}
              placeholder="— none —"
              hint="Common for air permits."
            />
            <div />
            <div className="md:col-span-2">
              <FormField
                type="textarea"
                label="Coverage Description"
                value={form.coverage_description}
                onChange={v => update('coverage_description', v)}
                placeholder="What operations/equipment the permit covers"
                rows={2}
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Agency & Owner">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Issuing Agency</label>
              <EntitySelector
                entity="regulatory-agencies"
                value={form.issuing_agency_id}
                onChange={id => update('issuing_agency_id', id)}
                renderLabel={row =>
                  `${String(row.agency_code ?? '')} — ${String(row.agency_name ?? '')}`
                }
                placeholder="Select an agency..."
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Internal Owner (Employee)</label>
              <EntitySelector
                entity="employees"
                value={form.internal_owner_id}
                onChange={id => update('internal_owner_id', id)}
                renderLabel={row =>
                  `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`
                }
                placeholder="Responsible employee"
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Application & Dates">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <FormField
              type="date"
              label="Application Date"
              value={form.application_date}
              onChange={v => update('application_date', v)}
            />
            <FormField
              label="Application Number"
              value={form.application_number}
              onChange={v => update('application_number', v)}
            />
            <FormField
              type="date"
              label="Issue Date"
              value={form.issue_date}
              onChange={v => update('issue_date', v)}
            />
            <FormField
              type="date"
              label="Effective Date"
              value={form.effective_date}
              onChange={v => update('effective_date', v)}
            />
            <FormField
              type="date"
              label="Expiration Date"
              value={form.expiration_date}
              onChange={v => update('expiration_date', v)}
            />
          </div>
        </SectionCard>

        <SectionCard title="Fees">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="number"
              label="Annual Fee ($)"
              value={form.annual_fee}
              onChange={v => update('annual_fee', v)}
            />
            <FormField
              type="date"
              label="Fee Due Date"
              value={form.fee_due_date}
              onChange={v => update('fee_due_date', v)}
            />
          </div>
        </SectionCard>

        <SectionCard title="Notes">
          <FormField
            type="textarea"
            label="Notes"
            value={form.notes}
            onChange={v => update('notes', v)}
            rows={3}
            placeholder="Conditions, tie-ins to equipment, recurring obligations, etc."
          />
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/permits/${id}` : '/permits')}
          saveLabel={isEdit ? 'Save changes' : 'Create permit'}
        />
      </form>
    </div>
  );
}
