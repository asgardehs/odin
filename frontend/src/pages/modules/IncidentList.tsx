import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const SEVERITY_COLORS: Record<string, string> = {
  fatal:    'var(--color-status-danger)',
  serious:  'var(--color-status-warn)',
  moderate: 'var(--color-status-info)',
  minor:    'var(--color-status-ok)',
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
      const color = SEVERITY_COLORS[v] ?? 'var(--color-text-muted)';
      return <span style={{ color }} className="text-xs font-medium capitalize">{v || '—'}</span>;
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

export default function IncidentList() {
  const navigate = useNavigate();
  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-text-primary)] mb-6">Incidents</h1>
      <DataTable
        columns={columns}
        apiUrl="/api/incidents"
        onRowClick={(row) => navigate(`/incidents/${row.id}`)}
      />
    </div>
  );
}
