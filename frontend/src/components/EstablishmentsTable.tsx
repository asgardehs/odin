import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from './DataTable';

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'name', header: 'Name' },
  { accessorKey: 'city', header: 'City' },
  { accessorKey: 'state', header: 'State' },
  { accessorKey: 'naics_code', header: 'NAICS Code', cell: ({ getValue }) => String(getValue() ?? '—') },
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

// Shared establishments table — mounted standalone in /establishments/full
// and embedded inside the Facilities hub's records slot.
export function EstablishmentsTable() {
  const navigate = useNavigate();
  return (
    <DataTable
      columns={columns}
      apiUrl="/api/establishments"
      onRowClick={(row) => navigate(`/establishments/${row.id}`)}
    />
  );
}
