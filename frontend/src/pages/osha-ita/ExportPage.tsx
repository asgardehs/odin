import { useEffect, useState } from 'react';
import { apiFetch } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { EntitySelector } from '../../components/forms/EntitySelector';

// OSHA ITA Export page — one-stop exporter for the two CSVs OSHA's
// Injury Tracking Application portal accepts. Users pick establishment
// + year, see a preview (recordable count, no-injuries flag), then
// download the Detail and/or Summary CSV.

interface PreviewData {
  detail_row_count: number;
  detail_columns: string[];
  summary_columns: string[];
  no_injuries_illnesses: string;
  establishment_name: string;
  establishment_known: boolean;
}

// Current calendar year as default; ITA filings are per reporting year,
// and the deadline (March 2 of the following year) means users typically
// export for the year that just ended or the current year mid-cycle.
function currentYear(): string {
  return new Date().getFullYear().toString();
}

// Recent-years options: current year + 4 previous. Covers the typical
// "file for the year that just ended" + "amend a prior-year submission"
// use cases without offering a bottomless dropdown.
function yearOptions(): { value: string; label: string }[] {
  const now = new Date().getFullYear();
  return Array.from({ length: 5 }, (_, i) => {
    const y = (now - i).toString();
    return { value: y, label: y };
  });
}

export default function ExportPage() {
  const [establishmentID, setEstablishmentID] = useState<number | null>(null);
  const [establishmentName, setEstablishmentName] = useState<string>('');
  const [year, setYear] = useState<string>(currentYear());

  const [preview, setPreview] = useState<PreviewData | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [previewError, setPreviewError] = useState<string | null>(null);

  const [downloadError, setDownloadError] = useState<string | null>(null);
  const [downloading, setDownloading] = useState<'detail' | 'summary' | null>(null);

  // Fetch preview whenever both selections are present.
  useEffect(() => {
    if (establishmentID == null || !year) {
      setPreview(null);
      setPreviewError(null);
      return;
    }
    setPreviewLoading(true);
    setPreviewError(null);
    apiFetch(`/api/osha/ita/preview?establishment_id=${establishmentID}&year=${year}`)
      .then(async res => {
        if (!res.ok) {
          throw new Error(`${res.status} ${res.statusText}`);
        }
        return res.json() as Promise<PreviewData>;
      })
      .then(setPreview)
      .catch(e => setPreviewError(e.message))
      .finally(() => setPreviewLoading(false));
  }, [establishmentID, year]);

  async function download(kind: 'detail' | 'summary') {
    if (establishmentID == null || !year) return;
    setDownloading(kind);
    setDownloadError(null);
    try {
      const res = await apiFetch(
        `/api/osha/ita/${kind}.csv?establishment_id=${establishmentID}&year=${year}`,
      );
      if (!res.ok) {
        const text = await res.text();
        throw new Error(`${res.status}: ${text || res.statusText}`);
      }
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `osha-ita-${kind}-${establishmentID}-${year}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (e) {
      setDownloadError(e instanceof Error ? e.message : String(e));
    } finally {
      setDownloading(null);
    }
  }

  const ready = establishmentID != null && !!year;
  const buttonBase =
    'inline-flex items-center justify-center gap-2 h-10 px-4 rounded-lg text-sm font-medium ' +
    'transition-colors disabled:opacity-50 disabled:cursor-not-allowed';
  const primaryButton =
    buttonBase +
    ' bg-[var(--color-fn-purple)] text-[var(--color-bg)] hover:bg-[var(--color-fn-purple)]/90';

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">OSHA ITA Export</h1>
        <p className="text-sm text-[var(--color-comment)] mt-1">
          Generate the two CSVs that OSHA's Injury Tracking Application portal accepts
          for annual injury and illness submission per 29 CFR 1904.41.
        </p>
      </div>

      <div className="flex flex-col gap-6 max-w-4xl">
        <SectionCard
          title="Select submission"
          description="Both fields are required. Establishment filters by its own id; year uses the calendar reporting year."
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-[var(--color-fg)]">
                Establishment <span className="text-[var(--color-fn-red)] ml-0.5">*</span>
              </label>
              <EntitySelector
                entity="establishments"
                value={establishmentID}
                onChange={(id, row) => {
                  setEstablishmentID(id);
                  setEstablishmentName(row ? String(row.name ?? '') : '');
                }}
                renderLabel={row => String(row.name ?? '')}
                placeholder="Search facilities…"
                required
              />
            </div>
            <FormField
              type="select"
              label="Reporting Year"
              required
              value={year}
              onChange={setYear}
              options={yearOptions()}
              hint="ITA filings cover one calendar year at a time."
            />
          </div>
        </SectionCard>

        {ready && (
          <SectionCard
            title="Preview"
            description="What the CSVs will contain. Confirm before downloading."
          >
            {previewLoading && (
              <p className="text-sm text-[var(--color-comment)]">Loading preview…</p>
            )}
            {previewError && (
              <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 text-sm">
                Failed to load preview: {previewError}
              </div>
            )}
            {preview && !previewLoading && !previewError && (
              <div className="flex flex-col gap-2 text-sm text-[var(--color-fg)]">
                <div>
                  <span className="text-[var(--color-comment)]">Establishment: </span>
                  <span className="font-medium">
                    {preview.establishment_known
                      ? preview.establishment_name || establishmentName
                      : '(unknown establishment)'}
                  </span>
                </div>
                <div>
                  <span className="text-[var(--color-comment)]">Reporting year: </span>
                  <span className="font-medium">{year}</span>
                </div>
                <div>
                  <span className="text-[var(--color-comment)]">Recordable incidents: </span>
                  <span className="font-medium">{preview.detail_row_count}</span>
                  {preview.no_injuries_illnesses === 'Y' && (
                    <span className="ml-2 text-[var(--color-comment)]">
                      (no_injuries_illnesses will be "Y" on the summary)
                    </span>
                  )}
                </div>
                <div className="text-xs text-[var(--color-comment)] mt-2">
                  Detail CSV: {preview.detail_columns.length} columns · Summary CSV:{' '}
                  {preview.summary_columns.length} columns
                </div>
              </div>
            )}
          </SectionCard>
        )}

        {ready && (
          <SectionCard title="Download">
            {downloadError && (
              <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 text-sm mb-4">
                {downloadError}
              </div>
            )}
            <div className="flex flex-wrap gap-3">
              <button
                type="button"
                className={primaryButton}
                disabled={downloading !== null}
                onClick={() => download('detail')}
              >
                {downloading === 'detail' ? 'Preparing…' : 'Download Detail CSV'}
              </button>
              <button
                type="button"
                className={primaryButton}
                disabled={downloading !== null}
                onClick={() => download('summary')}
              >
                {downloading === 'summary' ? 'Preparing…' : 'Download Summary CSV'}
              </button>
            </div>
            <p className="text-xs text-[var(--color-comment)] mt-3">
              Each click downloads one CSV. Detail = one row per recordable incident
              (24 columns). Summary = one row aggregating the year (28 columns).
            </p>
          </SectionCard>
        )}

        <SectionCard title="Submitting to OSHA">
          <div className="text-sm text-[var(--color-fg)] flex flex-col gap-2">
            <p>
              After downloading, upload both files to OSHA's Injury Tracking
              Application portal. The ITA submission deadline is March 2 of the year
              following the reporting year (29 CFR 1904.41(c)(2)).
            </p>
            <p>
              <a
                href="https://www.osha.gov/injuryreporting"
                target="_blank"
                rel="noopener noreferrer"
                className="text-[var(--color-fn-purple)] hover:underline"
              >
                Open OSHA ITA portal →
              </a>
            </p>
            <p className="text-xs text-[var(--color-comment)] mt-2">
              If you need to correct a previously submitted year, re-export and
              re-upload; the change_reason field is currently emitted empty and will
              be addressed once the amendment flow is built.
            </p>
          </div>
        </SectionCard>
      </div>
    </div>
  );
}
