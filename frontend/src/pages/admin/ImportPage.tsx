import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { api } from '../../api';
import ImportUploader from './ImportUploader';
import ImportMappingPanel from './ImportMappingPanel';
import type { ImportCommitResult, ImportModuleDescriptor, ImportPreview } from './importTypes';

type Phase = 'upload' | 'mapping' | 'committed';

/**
 * /admin/import — three-phase CSV import flow. State lives in this
 * component; the two phase components are pure presentations that call
 * back up on success.
 */
export default function ImportPage() {
  const navigate = useNavigate();
  const [modules, setModules] = useState<ImportModuleDescriptor[]>([]);
  const [modulesError, setModulesError] = useState<string | null>(null);
  const [phase, setPhase] = useState<Phase>('upload');
  const [preview, setPreview] = useState<ImportPreview | null>(null);
  const [result, setResult] = useState<ImportCommitResult | null>(null);

  useEffect(() => {
    api
      .get<{ modules: ImportModuleDescriptor[] }>('/api/import/modules')
      .then((r) => setModules(r.modules ?? []))
      .catch((e: Error) => setModulesError(e.message));
  }, []);

  function handleUploaded(p: ImportPreview) {
    setPreview(p);
    setPhase('mapping');
  }

  function handleCommitted(r: ImportCommitResult) {
    setResult(r);
    setPhase('committed');
  }

  function reset() {
    setPreview(null);
    setResult(null);
    setPhase('upload');
  }

  return (
    <div>
      <div className="flex items-center gap-4 mb-6 flex-wrap">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Bulk Import</h1>
        <span className="text-xs text-[var(--color-comment)]">
          {phase === 'upload' && 'Step 1 of 3 · Upload a CSV'}
          {phase === 'mapping' && 'Step 2 of 3 · Review mapping and validate'}
          {phase === 'committed' && 'Step 3 of 3 · Done'}
        </span>
      </div>

      {modulesError && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          Could not load import modules: {modulesError}
        </div>
      )}

      {phase === 'upload' && (
        <ImportUploader modules={modules} onUploaded={handleUploaded} />
      )}

      {phase === 'mapping' && preview && (
        <ImportMappingPanel
          preview={preview}
          onCommitted={handleCommitted}
          onDiscard={reset}
        />
      )}

      {phase === 'committed' && result && (
        <div className="max-w-2xl">
          <div className="rounded-xl bg-[var(--color-fn-green)]/10 border border-[var(--color-fn-green)]/30 p-6 mb-6">
            <div className="flex items-center gap-3 mb-3">
              <span className="text-3xl">✅</span>
              <h2 className="text-xl font-semibold text-[var(--color-fg)]">Import complete</h2>
            </div>
            <p className="text-sm text-[var(--color-fg)] mb-2">{result.audit_summary}</p>
            <dl className="grid grid-cols-2 gap-4 text-sm mt-4">
              <div>
                <dt className="text-xs uppercase tracking-wider text-[var(--color-comment)]">
                  Rows inserted
                </dt>
                <dd className="text-[var(--color-fg)] font-semibold">{result.inserted_count}</dd>
              </div>
              <div>
                <dt className="text-xs uppercase tracking-wider text-[var(--color-comment)]">
                  Rows skipped
                </dt>
                <dd
                  className={
                    result.skipped_count > 0
                      ? 'text-[var(--color-fn-orange)] font-semibold'
                      : 'text-[var(--color-comment)]'
                  }
                >
                  {result.skipped_count}
                </dd>
              </div>
              <div>
                <dt className="text-xs uppercase tracking-wider text-[var(--color-comment)]">
                  Module
                </dt>
                <dd className="text-[var(--color-fg)] font-mono text-xs">{result.module}</dd>
              </div>
              <div>
                <dt className="text-xs uppercase tracking-wider text-[var(--color-comment)]">
                  Committed
                </dt>
                <dd className="text-[var(--color-fg)] text-xs">{result.committed_at}</dd>
              </div>
            </dl>
          </div>

          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={reset}
              className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
            >
              Start another import
            </button>
            <button
              type="button"
              onClick={() => navigate(`/${result.module}`)}
              className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              View {result.module}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
