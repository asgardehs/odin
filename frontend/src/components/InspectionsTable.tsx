import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from './DataTable';

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'inspection_number', header: 'Inspection #' },
  { accessorKey: 'inspection_date', header: 'Date', cell: ({ getValue }) => String(getValue() ?? '—') },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ getValue }) => (
      <span className="capitalize text-[var(--color-fg)] text-xs">
        {String(getValue() ?? '—')}
      </span>
    ),
  },
  { accessorKey: 'overall_result', header: 'Result', cell: ({ getValue }) => String(getValue() ?? '—') },
];

// Shared inspections table — mounted standalone in /inspections/full
// and embedded inside the Inspections hub's records slot.
export function InspectionsTable() {
  const navigate = useNavigate();
  return (
    <DataTable
      columns={columns}
      apiUrl="/api/inspections"
      onRowClick={(row) => navigate(`/inspections/${row.id}`)}
    />
  );
}
