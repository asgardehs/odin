import { useCallback, useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router';
import { api } from '../../api';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { Modal } from '../../components/Modal';
import { FormField } from '../../components/forms/FormField';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useAuth } from '../../context/AuthContext';
import { AuditHistory } from '../../components/AuditHistory';

type EventRow = Record<string, unknown>;
type ResultRow = Record<string, unknown>;

interface PagedResult<T> {
  data: T[];
  total: number;
}

// ============ Result modal (add a single parameter result) ============

function ResultModal({
  eventId,
  open,
  onClose,
  onSaved,
}: {
  eventId: number;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [parameterId, setParameterId] = useState<number | null>(null);
  const [paramLabel, setParamLabel] = useState('');
  const [resultValue, setResultValue] = useState('');
  const [resultUnits, setResultUnits] = useState('');
  const [resultQualifier, setResultQualifier] = useState('');
  const [detectionLimit, setDetectionLimit] = useState('');
  const [reportingLimit, setReportingLimit] = useState('');
  const [analyzedDate, setAnalyzedDate] = useState('');
  const [analyzedBy, setAnalyzedBy] = useState('');
  const [analysisMethod, setAnalysisMethod] = useState('');
  const [notes, setNotes] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const { mutate, loading } = useEntityMutation();

  function reset() {
    setParameterId(null);
    setParamLabel('');
    setResultValue('');
    setResultUnits('');
    setResultQualifier('');
    setDetectionLimit('');
    setReportingLimit('');
    setAnalyzedDate('');
    setAnalyzedBy('');
    setAnalysisMethod('');
    setNotes('');
    setErr(null);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    if (parameterId == null) {
      setErr('Parameter is required.');
      return;
    }
    if (!resultUnits.trim()) {
      setErr('Units are required (match the parameter default if unsure).');
      return;
    }
    const val = resultValue.trim() === '' ? null : parseFloat(resultValue);
    if (val !== null && Number.isNaN(val)) {
      setErr('Result value must be a number (leave blank for non-detect).');
      return;
    }
    try {
      await mutate('POST', '/api/ww-sample-results', {
        event_id: eventId,
        parameter_id: parameterId,
        result_value: val,
        result_units: resultUnits.trim(),
        result_qualifier: resultQualifier.trim() || null,
        detection_limit: detectionLimit.trim() === '' ? null : parseFloat(detectionLimit),
        reporting_limit: reportingLimit.trim() === '' ? null : parseFloat(reportingLimit),
        analyzed_date: analyzedDate || null,
        analyzed_by: analyzedBy.trim() || null,
        analysis_method: analysisMethod.trim() || null,
        notes: notes.trim() || null,
      });
      reset();
      onSaved();
      onClose();
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Failed to save');
    }
  }

  return (
    <Modal
      open={open}
      onClose={() => {
        reset();
        onClose();
      }}
      title="Add sample result"
      size="lg"
    >
      {err && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
          {err}
        </div>
      )}
      <form onSubmit={submit} className="flex flex-col gap-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="flex flex-col gap-1.5 md:col-span-2">
            <label className="text-xs text-[var(--color-fg)]">
              Parameter<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
            </label>
            <EntitySelector
              entity="ww-parameters"
              value={parameterId}
              onChange={(id, row) => {
                setParameterId(id);
                if (row) {
                  const label = `${String(row.parameter_code ?? '')} — ${String(row.parameter_name ?? '')}`;
                  setParamLabel(label);
                  if (!resultUnits && row.typical_units) {
                    setResultUnits(String(row.typical_units));
                  }
                  if (!analysisMethod && row.typical_method) {
                    setAnalysisMethod(String(row.typical_method));
                  }
                }
              }}
              renderLabel={(row) =>
                `${String(row.parameter_code ?? '')} — ${String(row.parameter_name ?? '')}`
              }
              placeholder="Search by code or name (e.g. Zinc, BOD5, pH)..."
              required
            />
            {paramLabel && (
              <p className="text-[10px] text-[var(--color-comment)]">
                Selected: {paramLabel}
              </p>
            )}
          </div>
          <div className="grid grid-cols-[1fr_auto] gap-2">
            <FormField
              type="number"
              label="Result"
              value={resultValue}
              onChange={setResultValue}
              placeholder="Leave blank if non-detect"
              hint="Numeric value."
            />
            <FormField
              label="Units"
              required
              value={resultUnits}
              onChange={setResultUnits}
              placeholder="mg/L"
            />
          </div>
          <FormField
            label="Qualifier"
            value={resultQualifier}
            onChange={setResultQualifier}
            placeholder="ND, J, U, <, >"
            hint="Lab qualifier code (if from a certified lab)."
          />
          <FormField
            type="number"
            label="Detection Limit (MDL)"
            value={detectionLimit}
            onChange={setDetectionLimit}
          />
          <FormField
            type="number"
            label="Reporting Limit (PQL)"
            value={reportingLimit}
            onChange={setReportingLimit}
          />
          <FormField
            type="date"
            label="Analyzed Date"
            value={analyzedDate}
            onChange={setAnalyzedDate}
          />
          <FormField
            label="Analyzed By"
            value={analyzedBy}
            onChange={setAnalyzedBy}
            placeholder="Lab name or 'field'"
          />
          <FormField
            label="Analysis Method"
            value={analysisMethod}
            onChange={setAnalysisMethod}
            placeholder="EPA 200.7, EPA 405.1"
          />
        </div>
        <FormField type="textarea" label="Notes" value={notes} onChange={setNotes} rows={2} />
        <div className="flex items-center justify-end gap-3 pt-3 border-t border-[var(--color-current-line)]">
          <button
            type="button"
            onClick={() => {
              reset();
              onClose();
            }}
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50"
          >
            {loading ? 'Saving...' : 'Add result'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ============ Results list (nested sub-collection) ============

function ResultsList({
  eventId,
  refreshKey,
  canEdit,
  onDeleted,
}: {
  eventId: number;
  refreshKey: number;
  canEdit: boolean;
  onDeleted: () => void;
}) {
  const [rows, setRows] = useState<ResultRow[] | null>(null);
  const [deleting, setDeleting] = useState<number | null>(null);
  const { mutate } = useEntityMutation();

  const refresh = useCallback(() => {
    api
      .get<PagedResult<ResultRow>>('/api/ww-sample-results?per_page=500')
      .then((r) =>
        setRows((r.data ?? []).filter((x) => (x.event_id as number) === eventId)),
      )
      .catch(() => setRows([]));
  }, [eventId]);

  useEffect(() => {
    refresh();
  }, [refresh, refreshKey]);

  async function deleteResult(resultId: number) {
    if (!confirm('Delete this result?')) return;
    setDeleting(resultId);
    try {
      await mutate('DELETE', `/api/ww-sample-results/${resultId}`);
      onDeleted();
    } finally {
      setDeleting(null);
    }
  }

  if (rows === null) {
    return <p className="text-xs text-[var(--color-comment)]">Loading…</p>;
  }
  if (rows.length === 0) {
    return (
      <p className="text-xs text-[var(--color-comment)]">
        No parameter results recorded yet. Click <strong>Add result</strong> above to log one.
      </p>
    );
  }
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b border-[var(--color-current-line)]">
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            Parameter
          </th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            Result
          </th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            Qualifier
          </th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            MDL / PQL
          </th>
          <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
            Analysis
          </th>
          {canEdit && (
            <th className="text-right py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
              &nbsp;
            </th>
          )}
        </tr>
      </thead>
      <tbody>
        {rows.map((r) => {
          const resultValue = r.result_value;
          const units = String(r.result_units ?? '');
          const displayValue =
            resultValue == null
              ? <span className="text-[var(--color-comment)]">ND</span>
              : <span>{String(resultValue)} {units}</span>;
          const mdl = r.detection_limit == null ? '—' : String(r.detection_limit);
          const pql = r.reporting_limit == null ? '—' : String(r.reporting_limit);
          return (
            <tr key={String(r.id)} className="border-b border-[var(--color-current-line)] last:border-b-0">
              <td className="py-2 text-[var(--color-fg)]">
                <code className="text-xs bg-[var(--color-bg)] px-1.5 py-0.5 rounded">
                  #{String(r.parameter_id)}
                </code>
              </td>
              <td className="py-2 text-[var(--color-fg)]">{displayValue}</td>
              <td className="py-2 text-[var(--color-fg)] text-xs">
                {String(r.result_qualifier ?? '—')}
              </td>
              <td className="py-2 text-[var(--color-comment)] text-xs">
                {mdl} / {pql}
              </td>
              <td className="py-2 text-[var(--color-comment)] text-xs">
                {String(r.analyzed_by ?? '—')}
                {r.analysis_method ? ` · ${String(r.analysis_method)}` : ''}
              </td>
              {canEdit && (
                <td className="py-2 text-right">
                  <button
                    type="button"
                    onClick={() => deleteResult(r.id as number)}
                    disabled={deleting === (r.id as number)}
                    className="text-[10px] text-[var(--color-fn-red)] hover:underline disabled:opacity-50 cursor-pointer bg-transparent border-none"
                  >
                    {deleting === (r.id as number) ? 'Deleting…' : 'Delete'}
                  </button>
                </td>
              )}
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}

// ============ Detail page ============

const SAMPLE_TYPE_LABELS: Record<string, string> = {
  grab: 'Grab',
  composite: 'Composite',
  flow_proportional: 'Flow-proportional',
};

export default function WaterSampleEventDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';
  const { data, loading, error } = useApi<EventRow>(`/api/ww-sample-events/${id}`);
  const { mutate, loading: mutating, error: mutateError } = useEntityMutation();
  const [confirm, setConfirm] = useState<null | 'finalize' | 'delete'>(null);
  const [resultModalOpen, setResultModalOpen] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'finalize') {
        await mutate('POST', `/api/ww-sample-events/${id}/finalize`);
        window.location.reload();
      } else {
        await mutate('DELETE', `/api/ww-sample-events/${id}`);
        navigate('/ww-sample-events');
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
        <p className="text-sm">{notFound ? 'Sample event not found.' : `Error: ${error}`}</p>
        <button
          onClick={() => navigate('/ww-sample-events')}
          className="text-xs text-[var(--color-purple)] hover:underline"
        >
          ← Back to Sample Events
        </button>
      </div>
    );
  }

  const status = String(data.status ?? 'in_progress').toLowerCase();
  const isFinalized = status === 'finalized';
  const sampleType = String(data.sample_type ?? '');
  const sampleTypeLabel = SAMPLE_TYPE_LABELS[sampleType] ?? sampleType;
  const eventIdNum = data.id as number;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6 flex-wrap">
        <button
          onClick={() => navigate('/ww-sample-events')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Sample Events
        </button>
        <div>
          <p className="text-xs text-[var(--color-comment)] mb-0.5">
            {String(data.event_number ?? '—')}
          </p>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">
            Sample from {String(data.sample_date ?? '')}
            {data.sample_time ? ` at ${String(data.sample_time)}` : ''}
          </h1>
        </div>
        <span
          className="text-xs font-medium px-2 py-0.5 rounded-full capitalize"
          style={{
            background: isFinalized
              ? 'color-mix(in srgb, var(--color-fn-green) 15%, transparent)'
              : 'color-mix(in srgb, var(--color-fn-orange) 15%, transparent)',
            color: isFinalized ? 'var(--color-fn-green)' : 'var(--color-fn-orange)',
          }}
        >
          {status.replace('_', ' ')}
        </span>

        <div className="ml-auto flex items-center gap-2">
          {!isFinalized && (
            <>
              <button
                type="button"
                onClick={() => navigate(`/ww-sample-events/${id}/edit`)}
                className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
              >
                Edit
              </button>
              <button
                type="button"
                onClick={() => setConfirm('finalize')}
                className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-xs cursor-pointer hover:border-[var(--color-selection)] transition-colors"
              >
                Finalize
              </button>
            </>
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

      <div className="flex flex-col gap-4">
        <Section title="Event">
          <Field label="Event Number" value={data.event_number} />
          <Field label="Sample Date" value={data.sample_date} />
          <Field label="Sample Time" value={data.sample_time} />
          <Field label="Sampled By" value={data.sampled_by_employee_id} />
          <Field label="Sample Type" value={sampleTypeLabel} />
          <Field label="Composite Period (hours)" value={data.composite_period_hours} />
          <Field label="Weather" value={data.weather_conditions} />
        </Section>

        <Section title="Location & Equipment">
          <Field label="Establishment" value={data.establishment_id} />
          <Field label="Monitoring Location" value={data.location_id} />
          <Field label="Equipment" value={data.equipment_id} />
          <Field label="Lab Submission" value={data.lab_submission_id} />
        </Section>

        <Section title="Finalization">
          <Field label="Status" value={status.replace('_', ' ')} />
          <Field label="Finalized Date" value={data.finalized_date} />
          <Field label="Finalized By" value={data.finalized_by_employee_id} />
        </Section>

        {/* Results sub-collection */}
        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-lg font-semibold text-[var(--color-purple)] mb-0.5">
                Parameter Results
              </h2>
              <p className="text-xs text-[var(--color-comment)]">
                One row per tested parameter. Qualifiers (ND, J, U) and detection /
                reporting limits come from the lab report.
              </p>
            </div>
            {!isFinalized && (
              <button
                type="button"
                onClick={() => setResultModalOpen(true)}
                className="h-9 px-3 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
              >
                + Add result
              </button>
            )}
          </div>
          <ResultsList
            eventId={eventIdNum}
            refreshKey={refreshKey}
            canEdit={!isFinalized}
            onDeleted={() => setRefreshKey((k) => k + 1)}
          />
        </div>

        <Section title="Notes">
          <Field label="Notes" value={data.notes} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>

        <AuditHistory module="water_sample_events" entityId={id} />
      </div>

      <ResultModal
        eventId={eventIdNum}
        open={resultModalOpen}
        onClose={() => setResultModalOpen(false)}
        onSaved={() => setRefreshKey((k) => k + 1)}
      />

      {confirm && (
        <ConfirmDialog
          open
          title={confirm === 'finalize' ? 'Finalize sample event?' : 'Delete sample event?'}
          message={
            confirm === 'finalize'
              ? 'Marks this sample event DMR-ready. After finalizing, results can no longer be added or deleted (open a new event for corrections). Stamps today as the finalization date.'
              : 'Permanently deletes the sample event and cascades through any results. Use with care — an audit trail is preserved but the data is gone.'
          }
          confirmLabel={confirm === 'finalize' ? 'Finalize' : 'Delete'}
          destructive={confirm === 'delete'}
          loading={mutating}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
