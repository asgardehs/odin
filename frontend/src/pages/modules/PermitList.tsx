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
        daysLeft < 0 ? 'var(--color-fn-red)'
        : daysLeft <= 90 ? 'var(--color-fn-orange)'
        : 'var(--color-fg)';
      return <span style={{ color }}>{v}</span>;
    },
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ getValue }) => (
      <span className="capitalize text-[var(--color-fg)] text-xs">
        {String(getValue() ?? '—')}
      </span>
    ),
  },
];

export default function PermitList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Permits</h1>
        <button
          type="button"
          onClick={() => navigate('/permits/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Permit
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/permits"
        onRowClick={(row) => navigate(`/permits/${row.id}`)}
      />
    </div>
  );
}
