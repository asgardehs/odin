import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const dischargeTypeLabels: Record<string, string> = {
  process_wastewater: 'Process wastewater',
  stormwater: 'Stormwater',
  combined: 'Combined',
  non_contact_cooling: 'Non-contact cooling',
  sanitary: 'Sanitary',
  boiler_blowdown: 'Boiler blowdown',
};

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'outfall_code', header: 'Outfall #' },
  { accessorKey: 'outfall_name', header: 'Name' },
  {
    accessorKey: 'discharge_type',
    header: 'Type',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '');
      return <span className="text-xs">{dischargeTypeLabels[v] ?? v}</span>;
    },
  },
  { accessorKey: 'receiving_waterbody', header: 'Receiving water' },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? 'active').toLowerCase();
      const color =
        v === 'decommissioned'
          ? 'var(--color-comment)'
          : 'var(--color-fg)';
      return (
        <span className="capitalize text-xs" style={{ color }}>
          {v}
        </span>
      );
    },
  },
];

export default function DischargePointList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Discharge Points</h1>
        <button
          type="button"
          onClick={() => navigate('/discharge-points/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Discharge Point
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/discharge-points"
        onRowClick={(row) => navigate(`/discharge-points/${row.id}`)}
      />
    </div>
  );
}
