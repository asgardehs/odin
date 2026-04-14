import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'permit_number', header: 'Permit #' },
  { accessorKey: 'permit_name', header: 'Name' },
  {
    accessorKey: 'expiration_date',
    header: 'Expires',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '');
      if (!v) return '—';
      const daysLeft = Math.ceil((new Date(v).getTime() - Date.now()) / 86_400_000);
      const color =
        daysLeft < 0 ? 'var(--color-status-danger)'
        : daysLeft <= 90 ? 'var(--color-status-warn)'
        : 'var(--color-text-secondary)';
      return <span style={{ color }}>{v}</span>;
    },
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ getValue }) => (
      <span className="capitalize text-[var(--color-text-secondary)] text-xs">
        {String(getValue() ?? '—')}
      </span>
    ),
  },
];

export default function PermitList() {
  const navigate = useNavigate();
  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-text-primary)] mb-6">Permits</h1>
      <DataTable
        columns={columns}
        apiUrl="/api/permits"
        onRowClick={(row) => navigate(`/permits/${row.id}`)}
      />
    </div>
  );
}
