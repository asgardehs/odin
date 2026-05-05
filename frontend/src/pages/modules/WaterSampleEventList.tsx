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

// Polymorphic Sample Events page. Wastewater is the only implemented
// sample family in v1; Industrial Hygiene and Air are reserved as
// future types per the UI restructure plan. The chips communicate the
// system's intended scope while staying honest about what's wired.
type SampleType = 'ww' | 'ih' | 'air';

const sampleTypes: { id: SampleType; label: string; available: boolean }[] = [
  { id: 'ww',  label: 'Wastewater',         available: true  },
  { id: 'ih',  label: 'Industrial Hygiene', available: false },
  { id: 'air', label: 'Air',                available: false },
];

export default function WaterSampleEventList() {
  const navigate = useNavigate();
  const activeType: SampleType = 'ww';

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Sample Events</h1>
        <button
          type="button"
          onClick={() => navigate('/ww-sample-events/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Sample Event
        </button>
      </div>

      <div className="flex items-center gap-2 mb-6" role="tablist" aria-label="Sample type">
        {sampleTypes.map(t => {
          const isActive = t.id === activeType;
          const base = 'h-8 px-3 rounded-full text-xs font-medium border transition-colors';
          const cls = isActive
            ? `${base} bg-[var(--color-fn-purple)] text-[var(--color-bg)] border-[var(--color-fn-purple)]`
            : t.available
              ? `${base} bg-[var(--color-bg-light)] text-[var(--color-fg)] border-[var(--color-current-line)] hover:border-[var(--color-selection)] cursor-pointer`
              : `${base} bg-[var(--color-bg-light)] text-[var(--color-comment)] border-[var(--color-current-line)] cursor-not-allowed`;
          return (
            <button
              key={t.id}
              type="button"
              role="tab"
              aria-selected={isActive}
              disabled={!t.available}
              title={t.available ? '' : 'Coming soon'}
              className={cls}
            >
              {t.label}
              {!t.available && <span className="ml-1 opacity-70">· soon</span>}
            </button>
          );
        })}
      </div>

      <DataTable
        columns={columns}
        apiUrl="/api/ww-sample-events"
        onRowClick={(row) => navigate(`/ww-sample-events/${row.id}`)}
      />
    </div>
  );
}
