import { useNavigate } from 'react-router';
import { SWPPPsTable } from '../components/SWPPPsTable';

// /documents — lightweight aggregator for compliance documents. Two
// sections in v1: SWPPPs (live, embeds the existing list) and SDS
// Library (placeholder describing the future feature). The SDS empty
// state communicates intent — chemical-linked PDFs, search, expiry —
// without committing the implementation today.
export default function Documents() {
  const navigate = useNavigate();

  return (
    <div className="flex flex-col gap-8">
      <header>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">SDS and Documents</h1>
        <p className="text-sm text-[var(--color-comment)] mt-1">
          Compliance documents, plans, and chemical safety data sheets.
        </p>
      </header>

      <section
        aria-label="SWPPPs"
        className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] overflow-hidden"
      >
        <div className="flex items-center justify-between px-4 py-3 border-b border-[var(--color-current-line)]">
          <div>
            <h2 className="text-sm font-semibold text-[var(--color-purple)]">SWPPPs</h2>
            <p className="text-xs text-[var(--color-comment)] mt-0.5">
              Stormwater Pollution Prevention Plans, by revision and review date.
            </p>
          </div>
          <button
            type="button"
            onClick={() => navigate('/swpps/new')}
            className="h-8 px-3 rounded-md bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-medium text-xs cursor-pointer border-none hover:opacity-90 transition-opacity"
          >
            + New SWPPP
          </button>
        </div>
        <div className="p-4">
          <SWPPPsTable />
        </div>
      </section>

      <section
        aria-label="SDS Library"
        className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] border-dashed p-8 text-center"
      >
        <h2 className="text-sm font-semibold text-[var(--color-purple)] mb-2">SDS Library</h2>
        <p className="text-sm text-[var(--color-fg)] mb-1">Coming soon</p>
        <p className="text-xs text-[var(--color-comment)] max-w-xl mx-auto">
          Chemical-linked Safety Data Sheets — upload PDFs, search by product
          name or CAS number, track manufacturer revisions and expiry. Each
          chemical in the inventory will link to its current SDS.
        </p>
      </section>
    </div>
  );
}
