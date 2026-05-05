import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from './DataTable';

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

// Shared employees table — mounted standalone in /employees/full and
// embedded inside the Employees hub's records slot.
export function EmployeesTable() {
  const navigate = useNavigate();
  return (
    <DataTable
      columns={columns}
      apiUrl="/api/employees"
      onRowClick={(row) => navigate(`/employees/${row.id}`)}
    />
  );
}
