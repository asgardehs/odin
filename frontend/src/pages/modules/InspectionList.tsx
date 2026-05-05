import { useNavigate } from 'react-router';
import { InspectionsTable } from '../../components/InspectionsTable';

// Standalone fullscreen table view. Mounted at /inspections/full as the
// Expand target from the Inspections hub.
export default function InspectionList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Inspections</h1>
        <button
          type="button"
          onClick={() => navigate('/inspections/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Inspection
        </button>
      </div>
      <InspectionsTable />
    </div>
  );
}
