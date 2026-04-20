import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const AUDIT_TYPE_LABELS: Record<string, string> = {
  internal: 'Internal',
  external_surveillance: 'Surveillance',
  external_certification: 'Certification',
  external_recertification: 'Recertification',
};

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'audit_number', header: 'Audit #', cell: ({ getValue }) => String(getValue() ?? '—') },
  { accessorKey: 'audit_title', header: 'Title' },
  {
    accessorKey: 'audit_type',
    header: 'Type',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '');
      return AUDIT_TYPE_LABELS[v] ?? v;
    },
  },
  {
    accessorKey: 'scheduled_start_date',
    header: 'Scheduled',
    cell: ({ getValue }) => String(getValue() ?? '—'),
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ getValue }) => (
      <span className="capitalize text-[var(--color-fg)] text-xs">
        {String(getValue() ?? '—').replace(/_/g, ' ')}
      </span>
    ),
  },
];

export default function AuditList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Audits</h1>
        <button
          type="button"
          onClick={() => navigate('/audits/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Audit
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/audits"
        onRowClick={(row) => navigate(`/audits/${row.id}`)}
      />
    </div>
  );
}
