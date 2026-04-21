import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'revision_number', header: 'Revision' },
  {
    accessorKey: 'effective_date',
    header: 'Effective',
    cell: ({ getValue }) => String(getValue() ?? '—'),
  },
  {
    accessorKey: 'next_annual_review_due',
    header: 'Next Review',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '');
      if (!v) return '—';
      const daysLeft = Math.ceil((new Date(v).getTime() - Date.now()) / 86_400_000);
      const color =
        daysLeft < 0
          ? 'var(--color-fn-red)'
          : daysLeft <= 30
          ? 'var(--color-fn-orange)'
          : 'var(--color-fg)';
      return <span style={{ color }}>{v}</span>;
    },
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? 'active').toLowerCase();
      const color =
        v === 'active'
          ? 'var(--color-fg)'
          : v === 'superseded'
          ? 'var(--color-comment)'
          : 'var(--color-comment)';
      return (
        <span className="capitalize text-xs" style={{ color }}>
          {v}
        </span>
      );
    },
  },
];

export default function SWPPPList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">SWPPPs</h1>
        <button
          type="button"
          onClick={() => navigate('/swpps/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New SWPPP
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/swpps"
        onRowClick={(row) => navigate(`/swpps/${row.id}`)}
      />
    </div>
  );
}
