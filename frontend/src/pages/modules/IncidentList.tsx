import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const SEVERITY_COLORS: Record<string, string> = {
  fatal:    'var(--color-fn-red)',
  serious:  'var(--color-fn-orange)',
  moderate: 'var(--color-fn-cyan)',
  minor:    'var(--color-fn-green)',
};

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'case_number', header: 'Case #' },
  { accessorKey: 'incident_date', header: 'Date' },
  {
    accessorKey: 'incident_description',
    header: 'Description',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '');
      return v.length > 55 ? v.slice(0, 55) + '…' : v || '—';
    },
  },
  {
    accessorKey: 'severity_code',
    header: 'Severity',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '').toLowerCase();
      const color = SEVERITY_COLORS[v] ?? 'var(--color-comment)';
      return <span style={{ color }} className="text-xs font-medium capitalize">{v || '—'}</span>;
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

export default function IncidentList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Incidents</h1>
        <button
          type="button"
          onClick={() => navigate('/incidents/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Incident
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/incidents"
        onRowClick={(row) => navigate(`/incidents/${row.id}`)}
      />
    </div>
  );
}
