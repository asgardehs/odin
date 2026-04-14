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
        v === 'active' ? 'var(--color-status-ok)'
        : v === 'retired' || v === 'expired' ? 'var(--color-status-danger)'
        : 'var(--color-text-muted)';
      return <span style={{ color }} className="text-xs font-medium capitalize">{v || '—'}</span>;
    },
  },
];

export default function PPEList() {
  const navigate = useNavigate();
  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-text-primary)] mb-6">PPE</h1>
      <DataTable
        columns={columns}
        apiUrl="/api/ppe/items"
        onRowClick={(row) => navigate(`/ppe/${row.id}`)}
      />
    </div>
  );
}
