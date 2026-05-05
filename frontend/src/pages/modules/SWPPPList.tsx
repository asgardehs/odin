import { useNavigate } from 'react-router';
import { SWPPPsTable } from '../../components/SWPPPsTable';

// Standalone fullscreen SWPPPs list. Same data is embedded as a
// section inside /documents — the SWPPPsTable component is shared.
export default function SWPPPList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">SWPPPs</h1>
        <button
          type="button"
          onClick={() => navigate('/swpps/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New SWPPP
        </button>
      </div>
      <SWPPPsTable />
    </div>
  );
}
