import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

interface EstablishmentInput {
  name: string;
  street_address: string;
  city: string;
  state: string;
  zip: string;
  industry_description?: string | null;
  naics_code?: string | null;
  sic_code?: string | null;
  peak_employees?: number | null;
  annual_avg_employees?: number | null;
}

const empty: EstablishmentInput = {
  name: '',
  street_address: '',
  city: '',
  state: '',
  zip: '',
  industry_description: '',
  naics_code: '',
  sic_code: '',
  peak_employees: null,
  annual_avg_employees: null,
};

function normalizeForSubmit(form: EstablishmentInput): EstablishmentInput {
  const nullIfBlank = (s: string | null | undefined) =>
    s == null || s.trim() === '' ? null : s.trim();
  return {
    name: form.name.trim(),
    street_address: form.street_address.trim(),
    city: form.city.trim(),
    state: form.state.trim(),
    zip: form.zip.trim(),
    industry_description: nullIfBlank(form.industry_description),
    naics_code: nullIfBlank(form.naics_code),
    sic_code: nullIfBlank(form.sic_code),
    peak_employees: form.peak_employees == null ? null : form.peak_employees,
    annual_avg_employees: form.annual_avg_employees == null ? null : form.annual_avg_employees,
  };
}

export default function EstablishmentForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<EstablishmentInput>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/establishments/${id}`)
      .then(row => {
        setForm({
          name: (row.name as string) ?? '',
          street_address: (row.street_address as string) ?? '',
          city: (row.city as string) ?? '',
          state: (row.state as string) ?? '',
          zip: (row.zip as string) ?? '',
          industry_description: (row.industry_description as string) ?? '',
          naics_code: (row.naics_code as string) ?? '',
          sic_code: (row.sic_code as string) ?? '',
          peak_employees: (row.peak_employees as number) ?? null,
          annual_avg_employees: (row.annual_avg_employees as number) ?? null,
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof EstablishmentInput>(key: K, value: EstablishmentInput[K]) => {
    setForm(prev => ({ ...prev, [key]: value }));
    setDirty(true);
  };

  const intField = (raw: string): number | null => {
    if (raw.trim() === '') return null;
    const n = parseInt(raw, 10);
    return Number.isNaN(n) ? null : n;
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const body = normalizeForSubmit(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/establishments/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/establishments', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/establishments/${nextId}`);
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

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/establishments/${id}` : '/establishments')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Cancel
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">
          {isEdit ? `Edit ${form.name || 'Facility'}` : 'New Facility'}
        </h1>
      </div>

      {saveError && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {saveError}
        </div>
      )}

      <form onSubmit={submit} className="flex flex-col gap-6 max-w-4xl">
        <SectionCard title="Identity" description="Facility name and industry classification.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Facility Name"
              required
              value={form.name}
              onChange={v => update('name', v)}
              autoFocus
            />
            <FormField
              label="Industry Description"
              value={form.industry_description ?? ''}
              onChange={v => update('industry_description', v)}
              placeholder="e.g. Electroplating and polishing"
            />
            <FormField
              label="NAICS Code"
              value={form.naics_code ?? ''}
              onChange={v => update('naics_code', v)}
              placeholder="e.g. 332813"
            />
            <FormField
              label="SIC Code"
              value={form.sic_code ?? ''}
              onChange={v => update('sic_code', v)}
              placeholder="e.g. 3471"
            />
          </div>
        </SectionCard>

        <SectionCard title="Address">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="md:col-span-2">
              <FormField
                label="Street Address"
                required
                value={form.street_address}
                onChange={v => update('street_address', v)}
              />
            </div>
            <FormField
              label="City"
              required
              value={form.city}
              onChange={v => update('city', v)}
            />
            <div className="grid grid-cols-2 gap-4">
              <FormField
                label="State"
                required
                value={form.state}
                onChange={v => update('state', v)}
                placeholder="e.g. IL"
              />
              <FormField
                label="ZIP Code"
                required
                value={form.zip}
                onChange={v => update('zip', v)}
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Workforce" description="Employee counts used for OSHA reporting.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="number"
              label="Peak Employees"
              value={form.peak_employees?.toString() ?? ''}
              onChange={v => update('peak_employees', intField(v))}
              hint="Highest headcount during the year"
            />
            <FormField
              type="number"
              label="Annual Average Employees"
              value={form.annual_avg_employees?.toString() ?? ''}
              onChange={v => update('annual_avg_employees', intField(v))}
            />
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/establishments/${id}` : '/establishments')}
          saveLabel={isEdit ? 'Save changes' : 'Create facility'}
        />
      </form>
    </div>
  );
}
