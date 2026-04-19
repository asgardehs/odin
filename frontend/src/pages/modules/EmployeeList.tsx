import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const columns: ColumnDef<Row>[] = [
  {
    id: 'name',
    header: 'Name',
    accessorFn: (row) => `${String(row.last_name ?? '')}, ${String(row.first_name ?? '')}`,
  },
  { accessorKey: 'job_title', header: 'Job Title', cell: ({ getValue }) => String(getValue() ?? '—') },
  { accessorKey: 'department', header: 'Department', cell: ({ getValue }) => String(getValue() ?? '—') },
  {
    accessorKey: 'is_active',
    header: 'Status',
    cell: ({ getValue }) =>
      getValue() ? (
        <span className="text-[var(--color-fn-green)] text-xs font-medium">Active</span>
      ) : (
        <span className="text-[var(--color-comment)] text-xs">Inactive</span>
      ),
  },
];

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
      <DataTable
        columns={columns}
        apiUrl="/api/employees"
        onRowClick={(row) => navigate(`/employees/${row.id}`)}
      />
    </div>
  );
}
