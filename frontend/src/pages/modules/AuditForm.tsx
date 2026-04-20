import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

const auditTypeOptions = [
  { value: 'internal', label: 'Internal' },
  { value: 'external_surveillance', label: 'External — Surveillance' },
  { value: 'external_certification', label: 'External — Certification' },
  { value: 'external_recertification', label: 'External — Recertification' },
];

interface AuditFormState {
  establishment_id: number | null;
  audit_number: string;
  audit_title: string;
  audit_type: string;
  standard_id: number | null;
  is_integrated_audit: boolean;
  registrar_name: string;
  scheduled_start_date: string;
  scheduled_end_date: string;
  actual_start_date: string;
  actual_end_date: string;
  lead_auditor_id: number | null;
  lead_auditor_name: string;
  scope_description: string;
  audit_objectives: string;
  audit_criteria: string;
}

const empty: AuditFormState = {
  establishment_id: null,
  audit_number: '',
  audit_title: '',
  audit_type: 'internal',
  standard_id: null,
  is_integrated_audit: false,
  registrar_name: '',
  scheduled_start_date: '',
  scheduled_end_date: '',
  actual_start_date: '',
  actual_end_date: '',
  lead_auditor_id: null,
  lead_auditor_name: '',
  scope_description: '',
  audit_objectives: '',
  audit_criteria: '',
};

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}

function toBody(f: AuditFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    audit_number: nullIfBlank(f.audit_number),
    audit_title: f.audit_title.trim(),
    audit_type: f.audit_type,
    standard_id: f.standard_id,
    is_integrated_audit: f.is_integrated_audit ? 1 : 0,
    registrar_name: nullIfBlank(f.registrar_name),
    scheduled_start_date: nullIfBlank(f.scheduled_start_date),
    scheduled_end_date: nullIfBlank(f.scheduled_end_date),
    actual_start_date: nullIfBlank(f.actual_start_date),
    actual_end_date: nullIfBlank(f.actual_end_date),
    lead_auditor_id: f.lead_auditor_id,
    lead_auditor_name: nullIfBlank(f.lead_auditor_name),
    scope_description: nullIfBlank(f.scope_description),
    audit_objectives: nullIfBlank(f.audit_objectives),
    audit_criteria: nullIfBlank(f.audit_criteria),
  };
}

export default function AuditForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<AuditFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/audits/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          audit_number: s('audit_number'),
          audit_title: s('audit_title'),
          audit_type: s('audit_type') || 'internal',
          standard_id: (row.standard_id as number) ?? null,
          is_integrated_audit: Boolean(row.is_integrated_audit),
          registrar_name: s('registrar_name'),
          scheduled_start_date: s('scheduled_start_date'),
          scheduled_end_date: s('scheduled_end_date'),
          actual_start_date: s('actual_start_date'),
          actual_end_date: s('actual_end_date'),
          lead_auditor_id: (row.lead_auditor_id as number) ?? null,
          lead_auditor_name: s('lead_auditor_name'),
          scope_description: s('scope_description'),
          audit_objectives: s('audit_objectives'),
          audit_criteria: s('audit_criteria'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof AuditFormState>(key: K, value: AuditFormState[K]) => {
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
    if (!form.audit_title.trim()) {
      setValidationError('Audit title is required.');
      return;
    }
    if (!form.audit_type) {
      setValidationError('Audit type is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/audits/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/audits', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/audits/${nextId}`);
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
  const title = isEdit ? `Edit ${form.audit_title || 'Audit'}` : 'New Audit';
  const isExternal = form.audit_type.startsWith('external_');

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/audits/${id}` : '/audits')}
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
        <SectionCard title="Identity" description="What is being audited and where.">
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
              label="Audit Number"
              value={form.audit_number}
              onChange={v => update('audit_number', v)}
              placeholder="e.g. AUD-2026-001"
            />
            <div className="md:col-span-2">
              <FormField
                label="Audit Title"
                required
                value={form.audit_title}
                onChange={v => update('audit_title', v)}
                placeholder="e.g. ISO 14001 Internal Audit — Q1 2026"
                autoFocus
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Type & Standards" description="Audit classification and which standards are in scope.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="select"
              label="Audit Type"
              required
              value={form.audit_type}
              onChange={v => update('audit_type', v)}
              options={auditTypeOptions}
            />
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Primary Standard</label>
              <EntitySelector
                entity="iso-standards"
                value={form.standard_id}
                onChange={id => update('standard_id', id)}
                renderLabel={row =>
                  `${String(row.standard_code ?? '')} — ${String(row.standard_name ?? '')}`
                }
                placeholder="e.g. ISO 14001"
              />
            </div>
            <div className="md:col-span-2">
              <label className="flex items-center gap-2 h-8 cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={form.is_integrated_audit}
                  onChange={e => update('is_integrated_audit', e.target.checked)}
                  className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
                />
                <span className="text-sm text-[var(--color-fg)]">
                  Integrated audit (covers multiple standards)
                </span>
              </label>
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Dates" description="Scheduled vs actual start/end.">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              type="date"
              label="Scheduled Start"
              value={form.scheduled_start_date}
              onChange={v => update('scheduled_start_date', v)}
            />
            <FormField
              type="date"
              label="Scheduled End"
              value={form.scheduled_end_date}
              onChange={v => update('scheduled_end_date', v)}
            />
            <FormField
              type="date"
              label="Actual Start"
              value={form.actual_start_date}
              onChange={v => update('actual_start_date', v)}
            />
            <FormField
              type="date"
              label="Actual End"
              value={form.actual_end_date}
              onChange={v => update('actual_end_date', v)}
            />
          </div>
        </SectionCard>

        <SectionCard
          title="Lead Auditor"
          description={
            isExternal
              ? 'External audit — capture registrar/auditor name and company.'
              : 'Internal audit — pick an employee, or leave blank and use the name fields for a contractor.'
          }
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {!isExternal && (
              <div className="flex flex-col gap-1.5">
                <label className="text-xs text-[var(--color-fg)]">Internal Lead Auditor</label>
                <EntitySelector
                  entity="employees"
                  value={form.lead_auditor_id}
                  onChange={id => update('lead_auditor_id', id)}
                  renderLabel={row =>
                    `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`
                  }
                  placeholder="Pick an employee..."
                />
              </div>
            )}
            <FormField
              label={isExternal ? 'Lead Auditor Name' : 'External Lead Auditor Name'}
              value={form.lead_auditor_name}
              onChange={v => update('lead_auditor_name', v)}
              placeholder={isExternal ? 'Name of the lead auditor' : 'If contractor / leave blank for internal'}
            />
            {isExternal && (
              <FormField
                label="Registrar / Firm"
                value={form.registrar_name}
                onChange={v => update('registrar_name', v)}
                placeholder="e.g. DNV, BSI, NSF-ISR"
              />
            )}
          </div>
        </SectionCard>

        <SectionCard title="Scope" description="What is and isn't in scope, objectives, and criteria.">
          <div className="flex flex-col gap-4">
            <FormField
              type="textarea"
              label="Scope Description"
              value={form.scope_description}
              onChange={v => update('scope_description', v)}
              rows={3}
              placeholder="Processes, sites, and timeframe covered by this audit"
            />
            <FormField
              type="textarea"
              label="Audit Objectives"
              value={form.audit_objectives}
              onChange={v => update('audit_objectives', v)}
              rows={3}
              placeholder="Why this audit — conformity verification, certification decision, readiness, etc."
            />
            <FormField
              type="textarea"
              label="Audit Criteria"
              value={form.audit_criteria}
              onChange={v => update('audit_criteria', v)}
              rows={2}
              placeholder="e.g. ISO 14001:2015, Site EMS Manual rev 4, applicable federal/state/local legal requirements"
            />
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/audits/${id}` : '/audits')}
          saveLabel={isEdit ? 'Save changes' : 'Create audit'}
        />
      </form>
    </div>
  );
}
