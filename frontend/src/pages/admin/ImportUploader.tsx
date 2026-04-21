import { useRef, useState } from 'react';
import { apiFetch, ApiError } from '../../api';
import { EntitySelector } from '../../components/forms/EntitySelector';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import type { ImportModuleDescriptor, ImportPreview } from './importTypes';

interface ImportUploaderProps {
  modules: ImportModuleDescriptor[];
  onUploaded: (preview: ImportPreview) => void;
}

/**
 * Step 1 of the import flow: pick a module, pick a target facility,
 * drop a CSV. On success the parent transitions to the mapping step
 * with the returned preview.
 */
export default function ImportUploader({ modules, onUploaded }: ImportUploaderProps) {
  const [moduleSlug, setModuleSlug] = useState('');
  const [establishmentId, setEstablishmentId] = useState<number | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const moduleOptions = [
    { value: '', label: '— select a module —' },
    ...modules.map((m) => ({ value: m.slug, label: m.label })),
  ];

  const selectedModule = modules.find((m) => m.slug === moduleSlug);
  const needsEstablishment = Boolean(selectedModule); // all current modules need a target facility

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (!moduleSlug) {
      setError('Pick a module to import into.');
      return;
    }
    if (needsEstablishment && establishmentId == null) {
      setError('Pick a target facility — every row will land there.');
      return;
    }
    if (!file) {
      setError('Pick a CSV file to upload.');
      return;
    }

    const form = new FormData();
    form.append('file', file);
    if (establishmentId != null) {
      form.append('target_establishment_id', String(establishmentId));
    }

    setUploading(true);
    try {
      const res = await apiFetch(`/api/import/csv/${moduleSlug}`, {
        method: 'POST',
        body: form,
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new ApiError(res.status, body.error || res.statusText);
      }
      const preview = (await res.json()) as ImportPreview;
      onUploaded(preview);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Upload failed');
    } finally {
      setUploading(false);
    }
  }

  function onDrop(e: React.DragEvent<HTMLLabelElement>) {
    e.preventDefault();
    setDragOver(false);
    const dropped = e.dataTransfer.files?.[0];
    if (dropped) setFile(dropped);
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-6 max-w-3xl">
      <SectionCard
        title="Import target"
        description="Pick the module you're importing into, then the facility that should own every row."
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <FormField
            type="select"
            label="Module"
            required
            value={moduleSlug}
            onChange={setModuleSlug}
            options={moduleOptions}
          />
          {needsEstablishment && (
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">
                Target Facility<span className="text-[var(--color-fn-red)] ml-0.5">*</span>
              </label>
              <EntitySelector
                entity="establishments"
                value={establishmentId}
                onChange={setEstablishmentId}
                renderLabel={(row) => String(row.name ?? `Facility ${row.id}`)}
                placeholder="Select a facility..."
                required
              />
            </div>
          )}
        </div>
        {selectedModule && (
          <p className="mt-3 text-xs text-[var(--color-comment)]">
            Target fields: {selectedModule.target_fields.map((f) => f.label).join(', ')}
          </p>
        )}
      </SectionCard>

      <SectionCard title="CSV file" description="UTF-8, comma-delimited, one header row.">
        <label
          onDragOver={(e) => {
            e.preventDefault();
            setDragOver(true);
          }}
          onDragLeave={() => setDragOver(false)}
          onDrop={onDrop}
          className={`flex flex-col items-center justify-center gap-2 border-2 border-dashed rounded-xl px-6 py-12 text-sm cursor-pointer transition-colors ${
            dragOver
              ? 'border-[var(--color-fn-purple)] bg-[var(--color-fn-purple)]/5'
              : 'border-[var(--color-current-line)] hover:border-[var(--color-selection)]'
          }`}
        >
          <input
            ref={fileInput}
            type="file"
            accept=".csv,text/csv"
            className="hidden"
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
          <span className="text-2xl">📁</span>
          {file ? (
            <>
              <span className="text-[var(--color-fg)] font-medium">{file.name}</span>
              <span className="text-xs text-[var(--color-comment)]">
                {(file.size / 1024).toFixed(1)} KB · click to choose a different file
              </span>
            </>
          ) : (
            <>
              <span className="text-[var(--color-fg)]">Drop a CSV here or click to pick</span>
              <span className="text-xs text-[var(--color-comment)]">10 MB maximum</span>
            </>
          )}
        </label>
      </SectionCard>

      {error && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 text-sm">
          {error}
        </div>
      )}

      <div className="flex items-center justify-end">
        <button
          type="submit"
          disabled={uploading}
          className="h-10 px-6 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {uploading ? 'Uploading…' : 'Upload and preview'}
        </button>
      </div>
    </form>
  );
}
