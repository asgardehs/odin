import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'stream_code', header: 'Code' },
  { accessorKey: 'stream_name', header: 'Stream Name' },
  { accessorKey: 'waste_category', header: 'Category', cell: ({ getValue }) => String(getValue() ?? '—') },
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

export default function WasteList() {
  const navigate = useNavigate();
  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-text-primary)] mb-6">Waste Streams</h1>
      <DataTable
        columns={columns}
        apiUrl="/api/waste-streams"
        onRowClick={(row) => navigate(`/waste/${row.id}`)}
      />
    </div>
  );
}
