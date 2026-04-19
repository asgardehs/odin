import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';

interface PPEFormState {
  establishment_id: number | null;
  ppe_type_id: number | null;
  serial_number: string;
  asset_tag: string;
  manufacturer: string;
  model: string;
  size: string;
  manufacture_date: string;
  purchase_date: string;
  in_service_date: string;
  expiration_date: string;
  purchase_order: string;
  purchase_cost: string;
  vendor: string;
}

const empty: PPEFormState = {
  establishment_id: null,
  ppe_type_id: null,
  serial_number: '',
  asset_tag: '',
  manufacturer: '',
  model: '',
  size: '',
  manufacture_date: '',
  purchase_date: '',
  in_service_date: '',
  expiration_date: '',
  purchase_order: '',
  purchase_cost: '',
  vendor: '',
};

function nullIfBlank(s: string): string | null {
  return s.trim() === '' ? null : s.trim();
}
function numOrNull(s: string): number | null {
  if (s.trim() === '') return null;
  const n = parseFloat(s);
  return Number.isNaN(n) ? null : n;
}

function toBody(f: PPEFormState): Record<string, unknown> {
  return {
    establishment_id: f.establishment_id,
    ppe_type_id: f.ppe_type_id,
    serial_number: nullIfBlank(f.serial_number),
    asset_tag: nullIfBlank(f.asset_tag),
    manufacturer: nullIfBlank(f.manufacturer),
    model: nullIfBlank(f.model),
    size: nullIfBlank(f.size),
    manufacture_date: nullIfBlank(f.manufacture_date),
    purchase_date: nullIfBlank(f.purchase_date),
    in_service_date: nullIfBlank(f.in_service_date),
    expiration_date: nullIfBlank(f.expiration_date),
    purchase_order: nullIfBlank(f.purchase_order),
    purchase_cost: numOrNull(f.purchase_cost),
    vendor: nullIfBlank(f.vendor),
  };
}

export default function PPEForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = Boolean(id);

  const [form, setForm] = useState<PPEFormState>(empty);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<Record<string, unknown>>(`/api/ppe/items/${id}`)
      .then(row => {
        const s = (k: string) => (row[k] as string) ?? '';
        const n = (k: string) => (row[k] == null ? '' : String(row[k]));
        setForm({
          establishment_id: (row.establishment_id as number) ?? null,
          ppe_type_id: (row.ppe_type_id as number) ?? null,
          serial_number: s('serial_number'),
          asset_tag: s('asset_tag'),
          manufacturer: s('manufacturer'),
          model: s('model'),
          size: s('size'),
          manufacture_date: s('manufacture_date'),
          purchase_date: s('purchase_date'),
          in_service_date: s('in_service_date'),
          expiration_date: s('expiration_date'),
          purchase_order: s('purchase_order'),
          purchase_cost: n('purchase_cost'),
          vendor: s('vendor'),
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof PPEFormState>(key: K, value: PPEFormState[K]) => {
    setForm(prev => ({ ...prev, [key]: value }));
    setDirty(true);
    setValidationError(null);
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (form.establishment_id == null) { setValidationError('Facility is required.'); return; }
    if (form.ppe_type_id == null) { setValidationError('PPE type is required.'); return; }
    const body = toBody(form);
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/ppe/items/${id}`, body);
      } else {
        const res = await mutate<{ id: number }>('POST', '/api/ppe/items', body);
        nextId = res.id;
      }
      setDirty(false);
      navigate(`/ppe/${nextId}`);
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
  const title = isEdit ? `Edit ${form.asset_tag || form.serial_number || 'PPE Item'}` : 'New PPE Item';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate(isEdit ? `/ppe/${id}` : '/ppe')}
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
        <SectionCard title="Item Identity">
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
                PPE Type<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
              </label>
              <EntitySelector
                entity="ppe/types"
                value={form.ppe_type_id}
                onChange={id => update('ppe_type_id', id)}
                renderLabel={row =>
                  `${String(row.type_code ?? '')} — ${String(row.type_name ?? '')}`
                }
                placeholder="Select a PPE type..."
                required
              />
            </div>
            <FormField
              label="Serial Number"
              value={form.serial_number}
              onChange={v => update('serial_number', v)}
              autoFocus
            />
            <FormField
              label="Asset Tag"
              value={form.asset_tag}
              onChange={v => update('asset_tag', v)}
              placeholder="Internal barcode / sticker"
            />
          </div>
        </SectionCard>

        <SectionCard title="Manufacturer">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Manufacturer"
              value={form.manufacturer}
              onChange={v => update('manufacturer', v)}
            />
            <FormField
              label="Model"
              value={form.model}
              onChange={v => update('model', v)}
            />
            <FormField
              label="Size"
              value={form.size}
              onChange={v => update('size', v)}
              placeholder="e.g. M, L, 9.5, regular"
            />
          </div>
        </SectionCard>

        <SectionCard title="Service Dates">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <FormField
              type="date"
              label="Manufacture Date"
              value={form.manufacture_date}
              onChange={v => update('manufacture_date', v)}
            />
            <FormField
              type="date"
              label="Purchase Date"
              value={form.purchase_date}
              onChange={v => update('purchase_date', v)}
            />
            <FormField
              type="date"
              label="In-Service Date"
              value={form.in_service_date}
              onChange={v => update('in_service_date', v)}
            />
            <FormField
              type="date"
              label="Expiration Date"
              value={form.expiration_date}
              onChange={v => update('expiration_date', v)}
              hint="Manufacturer-specified shelf-life / service limit."
            />
          </div>
        </SectionCard>

        <SectionCard title="Procurement">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <FormField
              label="Purchase Order"
              value={form.purchase_order}
              onChange={v => update('purchase_order', v)}
            />
            <FormField
              type="number"
              label="Purchase Cost ($)"
              value={form.purchase_cost}
              onChange={v => update('purchase_cost', v)}
            />
            <FormField
              label="Vendor"
              value={form.vendor}
              onChange={v => update('vendor', v)}
            />
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate(isEdit ? `/ppe/${id}` : '/ppe')}
          saveLabel={isEdit ? 'Save changes' : 'Create PPE item'}
        />
      </form>
    </div>
  );
}
