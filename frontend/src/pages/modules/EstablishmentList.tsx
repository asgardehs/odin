import { useNavigate } from 'react-router';
import { EstablishmentsTable } from '../../components/EstablishmentsTable';

// Standalone fullscreen table view. Mounted at /establishments/full as the
// Expand target from the Facilities hub. Existing direct links to
// /establishments now resolve to the hub; deep links from elsewhere in
// the app still hit the table via /establishments/full.
export default function EstablishmentList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Facilities</h1>
        <button
          type="button"
          onClick={() => navigate('/establishments/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Facility
        </button>
      </div>
      <EstablishmentsTable />
    </div>
  );
}
