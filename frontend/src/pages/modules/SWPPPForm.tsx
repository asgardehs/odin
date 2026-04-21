import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

interface SWPPPFormState {
  establishment_id: number | null;
  revision_number: string;
  effective_date: string;
  supersedes_swppp_id: number | null;
  last_annual_review_date: string;
  next_annual_review_due: string;
  pollution_prevention_team_lead_employee_id: number | null;
  pollution_prevention_team: string;
  document_path: string;
  permit_id: number | null;
  site_description_summary: string;
  industrial_activities_summary: string;
  notes: string;
}

const empty: SWPPPFormState = {
  establishment_id: null,
  revision_number: '',
  effective_date: '',
  supersedes_swppp_id: null,
  last_annual_review_date: '',
  next_annual_review_due: '',
  pollution_prevention_team_lead_employee_id: null,
  pollution_prevention_team: '',
  document_path: '',
  permit_id: null,
  site_description_summary: '',
  industrial_activities_summary: '',
  notes: '',
};

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}

function toBody(f: SWPPPFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    revision_number: f.revision_number.trim(),
    effective_date: f.effective_date,
    supersedes_swppp_id: f.supersedes_swppp_id,
    last_annual_review_date: nullIfBlank(f.last_annual_review_date),
    next_annual_review_due: nullIfBlank(f.next_annual_review_due),
    pollution_prevention_team_lead_employee_id: f.pollution_prevention_team_lead_employee_id,
    pollution_prevention_team: nullIfBlank(f.pollution_prevention_team),
    document_path: nullIfBlank(f.document_path),
    permit_id: f.permit_id,
    site_description_summary: nullIfBlank(f.site_description_summary),
    industrial_activities_summary: nullIfBlank(f.industrial_activities_summary),
    notes: nullIfBlank(f.notes),
  };
}

export default function SWPPPForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<SWPPPFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api
      .get<Record<string, unknown>>(`/api/swpps/${id}`)
      .then((row) => {
        const s = (k: string) => (row[k] as string) ?? '';
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          revision_number: s('revision_number'),
          effective_date: s('effective_date'),
          supersedes_swppp_id: (row.supersedes_swppp_id as number) ?? null,
          last_annual_review_date: s('last_annual_review_date'),
          next_annual_review_due: s('next_annual_review_due'),
          pollution_prevention_team_lead_employee_id:
            (row.pollution_prevention_team_lead_employee_id as number) ?? null,
          pollution_prevention_team: s('pollution_prevention_team'),
          document_path: s('document_path'),
          permit_id: (row.permit_id as number) ?? null,
          site_description_summary: s('site_description_summary'),
          industrial_activities_summary: s('industrial_activities_summary'),
          notes: s('notes'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof SWPPPFormState>(key: K, value: SWPPPFormState[K]) => {
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
    if (!form.revision_number.trim()) {
      setValidationError('Revision number is required.');
      return;
    }
    if (!form.effective_date) {
      setValidationError('Effective date is required.');
      return;
    }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/swpps/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/swpps', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/swpps/${nextId}`);
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
  const title = isEdit ? `Edit SWPPP ${form.revision_number || ''}` : 'New SWPPP';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/swpps/${id}` : '/swpps')}
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
        <SectionCard
          title="Revision"
          description="SWPPPs are living documents — each revision supersedes the last."
        >
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
            <FormField
              label="Revision Number"
              required
              value={form.revision_number}
              onChange={(v) => update('revision_number', v)}
              placeholder="v1.0, v2.1, 2026-Q2, etc."
              autoFocus
            />
            <FormField
              type="date"
              label="Effective Date"
              required
              value={form.effective_date}
              onChange={(v) => update('effective_date', v)}
            />
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Supersedes Revision</label>
              <EntitySelector
                entity="swpps"
                value={form.supersedes_swppp_id}
                onChange={(id) => update('supersedes_swppp_id', id)}
                renderLabel={(row) =>
                  `${String(row.revision_number ?? '')} (eff. ${String(row.effective_date ?? '')})`
                }
                placeholder="Optional — leave blank for first revision"
              />
            </div>
            <FormField
              type="date"
              label="Last Annual Review"
              value={form.last_annual_review_date}
              onChange={(v) => update('last_annual_review_date', v)}
              hint="Required by 40 CFR 122.26 — at least annually."
            />
            <FormField
              type="date"
              label="Next Review Due"
              value={form.next_annual_review_due}
              onChange={(v) => update('next_annual_review_due', v)}
            />
          </div>
        </SectionCard>

        <SectionCard
          title="Permit & Team"
          description="Which permit this SWPPP supports, and who leads the pollution-prevention team."
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Governing Permit</label>
              <EntitySelector
                entity="permits"
                value={form.permit_id}
                onChange={(id) => update('permit_id', id)}
                renderLabel={(row) =>
                  `${String(row.permit_number ?? '')} — ${String(row.permit_name ?? '')}`
                }
                placeholder="Typically an MSGP or individual stormwater permit..."
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">Team Lead (Employee)</label>
              <EntitySelector
                entity="employees"
                value={form.pollution_prevention_team_lead_employee_id}
                onChange={(id) =>
                  update('pollution_prevention_team_lead_employee_id', id)
                }
                renderLabel={(row) =>
                  `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`
                }
                placeholder="Select the P2 team lead..."
              />
            </div>
            <div className="md:col-span-2">
              <FormField
                type="textarea"
                label="Pollution Prevention Team"
                value={form.pollution_prevention_team}
                onChange={(v) => update('pollution_prevention_team', v)}
                rows={2}
                placeholder='JSON array of employee IDs, e.g. [2, 5, 12]'
                hint="Team composition beyond the lead. Optional."
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Document">
          <FormField
            label="Document Path"
            value={form.document_path}
            onChange={(v) => update('document_path', v)}
            placeholder="/docs/swppp/v1.0.pdf"
            hint="Path to the full SWPPP document."
          />
        </SectionCard>

        <SectionCard title="Narrative (for search + preview)">
          <div className="grid grid-cols-1 gap-4">
            <FormField
              type="textarea"
              label="Site Description"
              value={form.site_description_summary}
              onChange={(v) => update('site_description_summary', v)}
              rows={3}
              placeholder="Brief site description — detailed version lives in the full document."
            />
            <FormField
              type="textarea"
              label="Industrial Activities"
              value={form.industrial_activities_summary}
              onChange={(v) => update('industrial_activities_summary', v)}
              rows={3}
              placeholder="Activities covered by this SWPPP (e.g. metal fabrication, outdoor material storage)."
            />
          </div>
        </SectionCard>

        <SectionCard title="Notes">
          <FormField
            type="textarea"
            label="Notes"
            value={form.notes}
            onChange={(v) => update('notes', v)}
            rows={2}
          />
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/swpps/${id}` : '/swpps')}
        />
      </form>
    </div>
  );
}
