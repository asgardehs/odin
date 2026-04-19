import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'serial_number', header: 'Serial #', cell: ({ getValue }) => String(getValue() ?? '—') },
  { accessorKey: 'manufacturer', header: 'Manufacturer', cell: ({ getValue }) => String(getValue() ?? '—') },
  { accessorKey: 'model', header: 'Model', cell: ({ getValue }) => String(getValue() ?? '—') },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '').toLowerCase();
      const color =
        v === 'active' ? 'var(--color-fn-green)'
        : v === 'retired' || v === 'expired' ? 'var(--color-fn-red)'
        : 'var(--color-comment)';
      return <span style={{ color }} className="text-xs font-medium capitalize">{v || '—'}</span>;
    },
  },
];

export default function PPEList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">PPE</h1>
        <button
          type="button"
          onClick={() => navigate('/ppe/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New PPE Item
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/ppe/items"
        onRowClick={(row) => navigate(`/ppe/${row.id}`)}
      />
    </div>
  );
}
