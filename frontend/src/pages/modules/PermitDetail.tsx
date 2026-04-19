import { useMemo, useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import { AuditHistory } from '../../components/AuditHistory';

type PermitRow = Record<string, unknown>;

export default function PermitDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<PermitRow>(`/api/permits/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'revoke' | 'delete'>(null);

  // All hooks before early returns. data may be null during loading.
  const expirationStr = data ? String(data.expiration_date ?? '') : '';
  const daysUntilExpiry = useMemo(
    () =>
      expirationStr
        ? Math.ceil((new Date(expirationStr).getTime() - Date.now()) / 86_400_000) // eslint-disable-line react-hooks/purity
        : null,
    [expirationStr],
  );
  const expiryWarning =
    daysUntilExpiry !== null && daysUntilExpiry <= 90
      ? daysUntilExpiry < 0
        ? 'Expired'
        : `Expires in ${daysUntilExpiry} day${daysUntilExpiry === 1 ? '' : 's'}`
      : null;

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'revoke') {
        await mutate('POST', `/api/permits/${id}/revoke`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/permits/${id}`);
        navigate('/permits');
      }
    } catch {
      // mutateError surfaces
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">
        Loading…
      </div>
    );
  }

  if (error || !data) {
    const notFound = error?.startsWith('404');
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-comment)]">
        <p className="text-sm">{notFound ? 'Permit not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/permits')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Permits
        </button>
      </div>
    );
  }

  const status = String(data.status ?? 'active').toLowerCase();
  const canRevoke = status === 'active';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/permits')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Permits
        </button>
        <div>
          <p className="text-xs text-[var(--color-comment)] mb-0.5">{String(data.permit_number ?? '')}</p>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">
            {String(data.permit_name ?? 'Permit')}
          </h1>
        </div>
        <span className="text-xs font-medium px-2 py-0.5 rounded-full capitalize bg-[var(--color-current-line)] text-[var(--color-fg)]">
          {status}
        </span>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={() => navigate(`/permits/${id}/edit`)}
            className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            Edit
          </button>
          {canRevoke && (
            <button
              type="button"
              onClick={() => setConfirm('revoke')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Revoke
            </button>
          )}
          {isAdmin && (
            <button
              type="button"
              onClick={() => setConfirm('delete')}
              className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fn-red)] text-xs cursor-pointer hover:border-[var(--color-fn-red)]/50 transition-colors"
            >
              Delete
            </button>
          )}
        </div>
      </div>

      {mutateError && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {mutateError}
        </div>
      )}

      {!!expiryWarning && (
        <div
          className={`rounded-xl border px-5 py-4 mb-4 ${
            daysUntilExpiry !== null && daysUntilExpiry < 0
              ? 'bg-[var(--color-fn-red)]/10 border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)]'
              : 'bg-[var(--color-fn-orange)]/10 border-[var(--color-fn-orange)]/30 text-[var(--color-fn-orange)]'
          }`}
        >
          <p className="text-sm font-medium">⏰ {expiryWarning}</p>
        </div>
      )}

      <div className="flex flex-col gap-4">
        <Section title="Identity">
          <Field label="Permit Number" value={data.permit_number} />
          <Field label="Permit Name" value={data.permit_name} />
          <Field label="Classification" value={data.permit_classification} />
          <Field label="Status" value={status} />
        </Section>

        <Section title="Coverage">
          <Field label="Coverage Description" value={data.coverage_description} />
        </Section>

        <Section title="Application & Dates">
          <Field label="Application Date" value={data.application_date} />
          <Field label="Application Number" value={data.application_number} />
          <Field label="Issue Date" value={data.issue_date} />
          <Field label="Effective Date" value={data.effective_date} />
          <Field label="Expiration Date" value={data.expiration_date} />
        </Section>

        <Section title="Renewal">
          <Field label="Renewal Status" value={data.renewal_status} />
          <Field label="Renewal Application Date" value={data.renewal_application_date} />
          <Field label="Renewal Application #" value={data.renewal_application_number} />
          <Field label="Last Review Date" value={data.last_review_date} />
          <Field label="Next Review Date" value={data.next_review_date} />
        </Section>

        <Section title="Fees">
          <Field label="Annual Fee" value={data.annual_fee} />
          <Field label="Fee Due Date" value={data.fee_due_date} />
        </Section>

        <Section title="Notes">
          <Field label="Notes" value={data.notes} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="permits" entityId={id} />
      </div>

      {confirm && (
        <ConfirmDialog
          open
          title={confirm === 'revoke' ? 'Revoke permit?' : 'Delete permit?'}
          message={
            confirm === 'revoke'
              ? 'Marks this permit revoked. Typically used when an agency has terminated the permit or it has been replaced by a new one.'
              : 'Permanently deletes the permit record. Related records (conditions, limits, reports) may block the delete — revoke instead.'
          }
          confirmLabel={confirm === 'revoke' ? 'Revoke' : 'Delete'}
          destructive
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
