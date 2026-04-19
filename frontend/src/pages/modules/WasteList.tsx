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
        <span className="text-[var(--color-fn-green)] text-xs font-medium">Active</span>
      ) : (
        <span className="text-[var(--color-comment)] text-xs">Inactive</span>
      ),
  },
];

export default function WasteList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Waste Streams</h1>
        <button
          type="button"
          onClick={() => navigate('/waste/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Waste Stream
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/waste-streams"
        onRowClick={(row) => navigate(`/waste/${row.id}`)}
      />
    </div>
  );
}
