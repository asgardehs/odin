import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

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
        <span className="text-[var(--color-status-ok)] text-xs font-medium">Active</span>
      ) : (
        <span className="text-[var(--color-text-muted)] text-xs">Inactive</span>
      ),
  },
];

export default function EstablishmentList() {
  const navigate = useNavigate();
  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-text-primary)] mb-6">Facilities</h1>
      <DataTable
        columns={columns}
        apiUrl="/api/establishments"
        onRowClick={(row) => navigate(`/establishments/${row.id}`)}
      />
    </div>
  );
}
