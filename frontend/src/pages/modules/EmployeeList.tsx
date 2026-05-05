import { useNavigate } from 'react-router';
import { EmployeesTable } from '../../components/EmployeesTable';

// Standalone fullscreen table view. Mounted at /employees/full as the
// Expand target from the Employees hub.
export default function EmployeeList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Employees</h1>
        <button
          type="button"
          onClick={() => navigate('/employees/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Employee
        </button>
      </div>
      <EmployeesTable />
    </div>
  );
}
