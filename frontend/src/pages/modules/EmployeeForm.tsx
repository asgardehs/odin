import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

interface EmployeeInput {
  establishment_id: number | null;
  employee_number?: string | null;
  first_name: string;
  last_name: string;
  street_address?: string | null;
  city?: string | null;
  state?: string | null;
  zip?: string | null;
  date_of_birth?: string | null;
  date_hired?: string | null;
  gender?: string | null;
  job_title?: string | null;
  department?: string | null;
  supervisor_name?: string | null;
}

const empty: EmployeeInput = {
  establishment_id: null,
  employee_number: '',
  first_name: '',
  last_name: '',
  street_address: '',
  city: '',
  state: '',
  zip: '',
  date_of_birth: '',
  date_hired: '',
  gender: '',
  job_title: '',
  department: '',
  supervisor_name: '',
};

function nullIfBlank(s: string | null | undefined): string | null {
  return s == null || s.trim() === '' ? null : s.trim();
}

function normalizeForSubmit(form: EmployeeInput): EmployeeInput {
  return {
    establishment_id: form.establishment_id,
    employee_number: nullIfBlank(form.employee_number),
    first_name: form.first_name.trim(),
    last_name: form.last_name.trim(),
    street_address: nullIfBlank(form.street_address),
    city: nullIfBlank(form.city),
    state: nullIfBlank(form.state),
    zip: nullIfBlank(form.zip),
    date_of_birth: nullIfBlank(form.date_of_birth),
    date_hired: nullIfBlank(form.date_hired),
    gender: nullIfBlank(form.gender),
    job_title: nullIfBlank(form.job_title),
    department: nullIfBlank(form.department),
    supervisor_name: nullIfBlank(form.supervisor_name),
  };
}

export default function EmployeeForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<EmployeeInput>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/employees/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          employee_number: s('employee_number'),
          first_name: s('first_name'),
          last_name: s('last_name'),
          street_address: s('street_address'),
          city: s('city'),
          state: s('state'),
          zip: s('zip'),
          date_of_birth: s('date_of_birth'),
          date_hired: s('date_hired'),
          gender: s('gender'),
          job_title: s('job_title'),
          department: s('department'),
          supervisor_name: s('supervisor_name'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof EmployeeInput>(key: K, value: EmployeeInput[K]) => {
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
    const body = normalizeForSubmit(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/employees/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/employees', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/employees/${nextId}`);
    } catch {
      // saveError is populated by the hook
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">
        Loading…
      </div>
    );
  }

  const title = isEdit
    ? `Edit ${[form.first_name, form.last_name].filter(Boolean).join(' ') || 'Employee'}`
    : 'New Employee';

  const errorMessage = validationError ?? saveError;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/employees/${id}` : '/employees')}
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

      <form onSubmit={submit} className="flex flex-col gap-6 max-w-4xl">
        <SectionCard title="Identity" description="Core personal information.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="First Name"
              required
              value={form.first_name}
              onChange={v => update('first_name', v)}
              autoFocus
            />
            <FormField
              label="Last Name"
              required
              value={form.last_name}
              onChange={v => update('last_name', v)}
            />
            <FormField
              label="Employee Number"
              value={form.employee_number ?? ''}
              onChange={v => update('employee_number', v)}
              placeholder="e.g. E-1042"
            />
            <FormField
              label="Gender"
              value={form.gender ?? ''}
              onChange={v => update('gender', v)}
              placeholder="Free text; leave blank if not collected"
            />
            <FormField
              type="date"
              label="Date of Birth"
              value={form.date_of_birth ?? ''}
              onChange={v => update('date_of_birth', v)}
            />
          </div>
        </SectionCard>

        <SectionCard title="Employment" description="Where this employee works.">
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
              type="date"
              label="Date Hired"
              value={form.date_hired ?? ''}
              onChange={v => update('date_hired', v)}
            />
            <FormField
              label="Job Title"
              value={form.job_title ?? ''}
              onChange={v => update('job_title', v)}
              placeholder="e.g. Plater II"
            />
            <FormField
              label="Department"
              value={form.department ?? ''}
              onChange={v => update('department', v)}
              placeholder="e.g. Electroplating"
            />
            <FormField
              label="Supervisor Name"
              value={form.supervisor_name ?? ''}
              onChange={v => update('supervisor_name', v)}
            />
          </div>
        </SectionCard>

        <SectionCard title="Address" description="Home address — optional; used for OSHA recordkeeping when required.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="md:col-span-2">
              <FormField
                label="Street Address"
                value={form.street_address ?? ''}
                onChange={v => update('street_address', v)}
              />
            </div>
            <FormField
              label="City"
              value={form.city ?? ''}
              onChange={v => update('city', v)}
            />
            <div className="grid grid-cols-2 gap-4">
              <FormField
                label="State"
                value={form.state ?? ''}
                onChange={v => update('state', v)}
                placeholder="e.g. IL"
              />
              <FormField
                label="ZIP Code"
                value={form.zip ?? ''}
                onChange={v => update('zip', v)}
              />
            </div>
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/employees/${id}` : '/employees')}
          saveLabel={isEdit ? 'Save changes' : 'Create employee'}
        />
      </form>
    </div>
  );
}
