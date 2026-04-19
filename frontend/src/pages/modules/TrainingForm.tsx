import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const deliveryMethodOptions = [
  { value: 'classroom', label: 'Classroom' },
  { value: 'online', label: 'Online' },
  { value: 'blended', label: 'Blended' },
  { value: 'on_the_job', label: 'On the job' },
  { value: 'self_study', label: 'Self-study' },
];

interface TrainingFormState {
  establishment_id: number | null;
  course_code: string;
  course_name: string;
  description: string;
  duration_minutes: string;
  delivery_method: string;
  has_test: boolean;
  passing_score: string;
  validity_months: string;
  is_external: boolean;
  vendor_name: string;
}

const empty: TrainingFormState = {
  establishment_id: null,
  course_code: '',
  course_name: '',
  description: '',
  duration_minutes: '',
  delivery_method: '',
  has_test: false,
  passing_score: '',
  validity_months: '',
  is_external: false,
  vendor_name: '',
};

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}

function intOrNull(s: string): number | null {
  if (s.trim() === '') return null;
  const n = parseInt(s, 10);
  return Number.isNaN(n) ? null : n;
}

function numOrNull(s: string): number | null {
  if (s.trim() === '') return null;
  const n = parseFloat(s);
  return Number.isNaN(n) ? null : n;
}

function toBody(f: TrainingFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    course_code: nullIfBlank(f.course_code),
    course_name: f.course_name.trim(),
    description: nullIfBlank(f.description),
    duration_minutes: intOrNull(f.duration_minutes),
    delivery_method: nullIfBlank(f.delivery_method),
    has_test: f.has_test ? 1 : 0,
    passing_score: numOrNull(f.passing_score),
    validity_months: intOrNull(f.validity_months),
    is_external: f.is_external ? 1 : 0,
    vendor_name: nullIfBlank(f.vendor_name),
  };
}

export default function TrainingForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<TrainingFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/training/courses/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        const n = (k: string) => (row[k] == null ? '' : String(row[k]));
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          course_code: s('course_code'),
          course_name: s('course_name'),
          description: s('description'),
          duration_minutes: n('duration_minutes'),
          delivery_method: s('delivery_method'),
          has_test: Boolean(row.has_test),
          passing_score: n('passing_score'),
          validity_months: n('validity_months'),
          is_external: Boolean(row.is_external),
          vendor_name: s('vendor_name'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof TrainingFormState>(key: K, value: TrainingFormState[K]) => {
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
    if (!form.course_name.trim()) {
      setValidationError('Course name is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/training/courses/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/training/courses', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/training/${nextId}`);
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
  const title = isEdit ? `Edit ${form.course_name || 'Training Course'}` : 'New Training Course';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/training/${id}` : '/training')}
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
        <SectionCard title="Course Identity" description="What this course is and who owns it.">
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
              label="Course Code"
              value={form.course_code}
              onChange={v => update('course_code', v)}
              placeholder="e.g. SAF-101"
              hint="Short internal identifier."
            />
            <div className="md:col-span-2">
              <FormField
                label="Course Name"
                required
                value={form.course_name}
                onChange={v => update('course_name', v)}
                autoFocus
              />
            </div>
            <div className="md:col-span-2">
              <FormField
                type="textarea"
                label="Description"
                value={form.description}
                onChange={v => update('description', v)}
                rows={3}
                placeholder="What the course covers, target audience, regulatory basis."
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Delivery">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="select"
              label="Delivery Method"
              value={form.delivery_method}
              onChange={v => update('delivery_method', v)}
              options={deliveryMethodOptions}
              placeholder="— select —"
            />
            <FormField
              type="number"
              label="Duration (minutes)"
              value={form.duration_minutes}
              onChange={v => update('duration_minutes', v)}
              placeholder="e.g. 60"
            />
            <label className="flex items-center gap-2 h-10 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={form.is_external}
                onChange={e => update('is_external', e.target.checked)}
                className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
              />
              <span className="text-sm text-[var(--color-fg)]">External / vendor-delivered</span>
            </label>
            {form.is_external && (
              <FormField
                label="Vendor Name"
                value={form.vendor_name}
                onChange={v => update('vendor_name', v)}
                placeholder="e.g. OSHA Training Institute"
              />
            )}
          </div>
        </SectionCard>

        <SectionCard title="Assessment &amp; Validity">
          <div className="flex flex-col gap-4">
            <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
              <input
                type="checkbox"
                checked={form.has_test}
                onChange={e => update('has_test', e.target.checked)}
                className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
              />
              <span className="text-sm text-[var(--color-fg)]">Course includes a test</span>
            </label>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {form.has_test && (
                <FormField
                  type="number"
                  label="Passing Score"
                  value={form.passing_score}
                  onChange={v => update('passing_score', v)}
                  placeholder="e.g. 80"
                  hint="Percentage required to pass."
                />
              )}
              <FormField
                type="number"
                label="Validity (months)"
                value={form.validity_months}
                onChange={v => update('validity_months', v)}
                placeholder="e.g. 12"
                hint="Leave blank for one-time training with no expiration."
              />
            </div>
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/training/${id}` : '/training')}
          saveLabel={isEdit ? 'Save changes' : 'Create course'}
        />
      </form>
    </div>
  );
}
