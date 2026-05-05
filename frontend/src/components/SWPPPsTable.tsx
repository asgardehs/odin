import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from './DataTable';

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
          : 'var(--color-comment)';
      return (
        <span className="capitalize text-xs" style={{ color }}>
          {v}
        </span>
      );
    },
  },
];

// Shared SWPPPs table — mounted standalone in /swpps and embedded
// inside the SDS and Documents page's SWPPPs section.
export function SWPPPsTable() {
  const navigate = useNavigate();
  return (
    <DataTable
      columns={columns}
      apiUrl="/api/swpps"
      onRowClick={(row) => navigate(`/swpps/${row.id}`)}
    />
  );
}
