import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import {
  IMPORT_IGNORE_MARKER,
  type ImportCommitResult,
  type ImportPreview,
  type ImportValidationError,
} from './importTypes';

interface ImportMappingPanelProps {
  preview: ImportPreview;
  onCommitted: (result: ImportCommitResult) => void;
  onDiscard: () => void;
}

/**
 * Step 2 of the import flow: review the auto-mapped columns, correct
 * anything that's wrong, watch the validation panel update live, commit.
 *
 * Mapping changes autosave with a 400ms debounce — chatty enough to feel
 * responsive, not so chatty that every keystroke hits the backend.
 */
export default function ImportMappingPanel({
  preview: initialPreview,
  onCommitted,
  onDiscard,
}: ImportMappingPanelProps) {
  const [preview, setPreview] = useState<ImportPreview>(initialPreview);
  const [mapping, setMapping] = useState<Record<string, string>>(initialPreview.mapping);
  const [skipInvalid, setSkipInvalid] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<null | 'discard' | 'commit'>(null);
  const debounceRef = useRef<number | null>(null);

  // Per-target conflict detection: if two source headers both pick the
  // same target field, highlight them for the user to resolve.
  const targetUsage = useMemo(() => {
    const count: Record<string, number> = {};
    for (const tgt of Object.values(mapping)) {
      if (tgt && tgt !== IMPORT_IGNORE_MARKER) {
        count[tgt] = (count[tgt] ?? 0) + 1;
      }
    }
    return count;
  }, [mapping]);

  // Required-field gap detection: flag any required field that no source
  // column is mapped to.
  const missingRequired = useMemo(() => {
    const mapped = new Set(Object.values(mapping));
    return preview.target_fields
      .filter((f) => f.required && !mapped.has(f.name))
      .map((f) => f.label);
  }, [mapping, preview.target_fields]);

  const updateSourceMapping = useCallback((source: string, target: string) => {
    setMapping((prev) => ({ ...prev, [source]: target }));
  }, []);

  // Debounced PUT whenever the mapping changes.
  useEffect(() => {
    if (debounceRef.current) {
      window.clearTimeout(debounceRef.current);
    }
    const sameAsServer =
      Object.keys(mapping).length === Object.keys(preview.mapping).length &&
      Object.entries(mapping).every(([k, v]) => preview.mapping[k] === v);
    if (sameAsServer) return;

    debounceRef.current = window.setTimeout(() => {
      setSaving(true);
      api
        .put<ImportPreview>(`/api/import/csv/${preview.module}/${preview.token}/mapping`, {
          mapping,
        })
        .then((next) => {
          setPreview(next);
          setMapping(next.mapping);
          setError(null);
        })
        .catch((e: Error) => setError(e.message))
        .finally(() => setSaving(false));
    }, 400);

    return () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
    };
    // preview.mapping intentionally excluded so we compare against the last
    // server-acked mapping without looping on our own updates.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mapping, preview.module, preview.token]);

  async function commit() {
    setSaving(true);
    setError(null);
    try {
      const q = skipInvalid ? '?skip_invalid=1' : '';
      const result = await api.post<ImportCommitResult>(
        `/api/import/csv/${preview.module}/${preview.token}/commit${q}`,
      );
      onCommitted(result);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Commit failed');
    } finally {
      setSaving(false);
      setConfirm(null);
    }
  }

  async function discard() {
    try {
      await api.del(`/api/import/csv/${preview.module}/${preview.token}`);
    } catch {
      // Fall through — parent reset will happen regardless.
    }
    onDiscard();
  }

  const errorsByRow = groupErrorsByRow(preview.validation_errors);
  const invalidRowCount = errorsByRow.size;
  const validRowCount = preview.row_count - invalidRowCount;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-[var(--color-fg)]">
            Review mapping
          </h2>
          <p className="text-xs text-[var(--color-comment)]">
            {preview.row_count} row{preview.row_count === 1 ? '' : 's'} parsed ·{' '}
            <span className={invalidRowCount > 0 ? 'text-[var(--color-fn-orange)]' : ''}>
              {validRowCount} valid
            </span>
            {invalidRowCount > 0 ? ` · ${invalidRowCount} invalid` : ''}
            {saving && ' · saving…'}
          </p>
        </div>
        <button
          type="button"
          onClick={() => setConfirm('discard')}
          className="h-9 px-3 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-comment)] text-xs cursor-pointer hover:border-[var(--color-fn-red)]/50 hover:text-[var(--color-fn-red)] transition-colors"
        >
          Discard and restart
        </button>
      </div>

      {error && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 text-sm">
          {error}
        </div>
      )}

      {missingRequired.length > 0 && (
        <div className="rounded-lg bg-[var(--color-fn-orange)]/10 border border-[var(--color-fn-orange)]/30 text-[var(--color-fn-orange)] px-4 py-3 text-sm">
          Required field{missingRequired.length === 1 ? '' : 's'} not mapped:{' '}
          <strong>{missingRequired.join(', ')}</strong>
        </div>
      )}

      <SectionCard
        title="Column mapping"
        description="Every source column maps to one target field — or to “ignore.” Auto-suggestions come from fuzzy header matching; correct anything off."
      >
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--color-current-line)]">
              <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
                Source Column
              </th>
              <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
                Target Field
              </th>
              <th className="text-left py-2 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">
                Hint
              </th>
            </tr>
          </thead>
          <tbody>
            {preview.headers.map((src) => {
              const chosen = mapping[src] ?? IMPORT_IGNORE_MARKER;
              const conflict = chosen !== IMPORT_IGNORE_MARKER && targetUsage[chosen] > 1;
              const fieldMeta = preview.target_fields.find((f) => f.name === chosen);
              return (
                <tr
                  key={src}
                  className="border-b border-[var(--color-current-line)] last:border-b-0"
                >
                  <td className="py-2 text-[var(--color-fg)] font-mono text-xs">{src}</td>
                  <td className="py-2">
                    <select
                      value={chosen}
                      onChange={(e) => updateSourceMapping(src, e.target.value)}
                      className={`h-9 px-2 rounded-lg bg-[var(--color-bg)] border text-[var(--color-fg)] text-sm outline-none focus:border-[var(--color-fn-purple)] transition-colors ${
                        conflict
                          ? 'border-[var(--color-fn-orange)]'
                          : 'border-[var(--color-current-line)]'
                      }`}
                    >
                      <option value={IMPORT_IGNORE_MARKER}>— ignore —</option>
                      {preview.target_fields.map((f) => (
                        <option key={f.name} value={f.name}>
                          {f.label}
                          {f.required ? ' *' : ''}
                        </option>
                      ))}
                    </select>
                    {conflict && (
                      <div className="text-[10px] text-[var(--color-fn-orange)] mt-0.5">
                        Also mapped by another source column
                      </div>
                    )}
                  </td>
                  <td className="py-2 text-[var(--color-comment)] text-xs">
                    {fieldMeta?.description ?? '—'}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </SectionCard>

      <SectionCard
        title="Row preview"
        description={`First ${Math.min(preview.rows_preview.length, preview.row_count)} of ${preview.row_count} rows as they were parsed from the file.`}
      >
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className="border-b border-[var(--color-current-line)]">
                <th className="text-left py-2 font-semibold text-[10px] uppercase text-[var(--color-comment)] pr-4">
                  #
                </th>
                {preview.headers.map((h) => (
                  <th
                    key={h}
                    className="text-left py-2 font-semibold text-[10px] uppercase text-[var(--color-comment)] pr-4 whitespace-nowrap"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {preview.rows_preview.map((row, i) => {
                const rowNum = i + 1;
                const rowErrors = errorsByRow.get(rowNum);
                return (
                  <tr
                    key={rowNum}
                    className={`border-b border-[var(--color-current-line)] last:border-b-0 ${
                      rowErrors ? 'bg-[var(--color-fn-red)]/5' : ''
                    }`}
                  >
                    <td
                      className={`py-1.5 pr-4 text-xs ${
                        rowErrors ? 'text-[var(--color-fn-red)]' : 'text-[var(--color-comment)]'
                      }`}
                    >
                      {rowNum}
                    </td>
                    {preview.headers.map((h) => (
                      <td key={h} className="py-1.5 pr-4 text-[var(--color-fg)] whitespace-nowrap">
                        {row[h] ?? ''}
                      </td>
                    ))}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </SectionCard>

      {preview.validation_errors.length > 0 && (
        <SectionCard
          title={`Validation errors (${preview.validation_errors.length})`}
          description="Fix by adjusting the mapping above, by editing the source file, or (if you have permission) by committing with “skip invalid rows” checked."
        >
          <div className="max-h-64 overflow-y-auto">
            <table className="w-full text-sm">
              <thead className="sticky top-0 bg-[var(--color-bg-light)]">
                <tr className="border-b border-[var(--color-current-line)]">
                  <th className="text-left py-2 font-semibold text-xs uppercase text-[var(--color-comment)] w-16">
                    Row
                  </th>
                  <th className="text-left py-2 font-semibold text-xs uppercase text-[var(--color-comment)] w-48">
                    Column
                  </th>
                  <th className="text-left py-2 font-semibold text-xs uppercase text-[var(--color-comment)]">
                    Message
                  </th>
                </tr>
              </thead>
              <tbody>
                {preview.validation_errors.map((e, i) => (
                  <tr
                    key={i}
                    className="border-b border-[var(--color-current-line)] last:border-b-0"
                  >
                    <td className="py-1.5 text-[var(--color-fg)] font-mono text-xs">{e.row}</td>
                    <td className="py-1.5 text-[var(--color-fg)] font-mono text-xs">
                      {e.column || '—'}
                    </td>
                    <td className="py-1.5 text-[var(--color-fn-red)]">{e.message}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </SectionCard>
      )}

      <div className="flex items-center justify-between pt-4 border-t border-[var(--color-current-line)]">
        <label className="flex items-center gap-2 cursor-pointer select-none">
          <input
            type="checkbox"
            checked={skipInvalid}
            onChange={(e) => setSkipInvalid(e.target.checked)}
            className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer"
          />
          <span className="text-sm text-[var(--color-fg)]">
            Skip invalid rows ({invalidRowCount} row{invalidRowCount === 1 ? '' : 's'} will be
            skipped)
          </span>
        </label>
        <button
          type="button"
          onClick={() => setConfirm('commit')}
          disabled={saving || (invalidRowCount > 0 && !skipInvalid) || validRowCount === 0}
          className="h-10 px-6 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {saving ? 'Working…' : `Commit ${validRowCount} row${validRowCount === 1 ? '' : 's'}`}
        </button>
      </div>

      {confirm === 'discard' && (
        <ConfirmDialog
          open
          title="Discard this import?"
          message="The uploaded file and any mapping edits will be dropped. The token is invalidated on the server."
          confirmLabel="Discard"
          destructive
          onConfirm={discard}
          onCancel={() => setConfirm(null)}
        />
      )}
      {confirm === 'commit' && (
        <ConfirmDialog
          open
          title={`Commit ${validRowCount} row${validRowCount === 1 ? '' : 's'} into ${preview.module}?`}
          message={
            invalidRowCount > 0
              ? `${invalidRowCount} invalid row${invalidRowCount === 1 ? ' will be' : 's will be'} skipped. The committed rows cannot be rolled back without deleting them one by one.`
              : 'The committed rows cannot be rolled back without deleting them one by one.'
          }
          confirmLabel="Commit"
          loading={saving}
          onConfirm={commit}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}

function groupErrorsByRow(errors: ImportValidationError[]) {
  const out = new Map<number, ImportValidationError[]>();
  for (const e of errors) {
    const bucket = out.get(e.row) ?? [];
    bucket.push(e);
    out.set(e.row, bucket);
  }
  return out;
}
