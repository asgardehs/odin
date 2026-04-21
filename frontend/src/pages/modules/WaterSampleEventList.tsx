import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const sampleTypeLabels: Record<string, string> = {
  grab: 'Grab',
  composite: 'Composite',
  flow_proportional: 'Flow-proportional',
};

const columns: ColumnDef<Row>[] = [
  {
    accessorKey: 'sample_date',
    header: 'Sample Date',
    cell: ({ getValue }) => String(getValue() ?? '—'),
  },
  {
    accessorKey: 'sample_time',
    header: 'Time',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '');
      return v || '—';
    },
  },
  { accessorKey: 'event_number', header: 'Event #' },
  {
    accessorKey: 'sample_type',
    header: 'Type',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '');
      return <span className="text-xs">{sampleTypeLabels[v] ?? v ?? '—'}</span>;
    },
  },
  {
    accessorKey: 'weather_conditions',
    header: 'Weather',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '');
      return <span className="text-xs capitalize">{v || '—'}</span>;
    },
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? 'in_progress').toLowerCase();
      const color =
        v === 'finalized' ? 'var(--color-fn-green)' : 'var(--color-fn-orange)';
      return (
        <span className="capitalize text-xs" style={{ color }}>
          {v.replace('_', ' ')}
        </span>
      );
    },
  },
];

export default function WaterSampleEventList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Water Sample Events</h1>
        <button
          type="button"
          onClick={() => navigate('/ww-sample-events/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Sample Event
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/ww-sample-events"
        onRowClick={(row) => navigate(`/ww-sample-events/${row.id}`)}
      />
    </div>
  );
}
