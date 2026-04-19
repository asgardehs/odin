import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'building', header: 'Building' },
  { accessorKey: 'room', header: 'Room', cell: ({ getValue }) => String(getValue() ?? '—') },
  { accessorKey: 'area', header: 'Area', cell: ({ getValue }) => String(getValue() ?? '—') },
  { accessorKey: 'container_types', header: 'Container Types', cell: ({ getValue }) => String(getValue() ?? '—') },
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

export default function StorageLocationList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Storage Locations</h1>
        <button
          type="button"
          onClick={() => navigate('/storage-locations/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Storage Location
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/storage-locations"
        onRowClick={(row) => navigate(`/storage-locations/${row.id}`)}
      />
    </div>
  );
}
