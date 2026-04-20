import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const SOURCE_LABELS: Record<string, string> = {
  welding: 'Welding',
  coating: 'Coating',
  combustion: 'Combustion',
  solvent: 'Solvent',
  material_handling: 'Material handling',
};

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'unit_name', header: 'Unit' },
  {
    accessorKey: 'source_category',
    header: 'Category',
    cell: ({ getValue }) => {
      const v = String(getValue() ?? '');
      return SOURCE_LABELS[v] ?? v;
    },
  },
  { accessorKey: 'scc_code', header: 'SCC', cell: ({ getValue }) => String(getValue() ?? '—') },
  {
    accessorKey: 'is_fugitive',
    header: 'Fugitive',
    cell: ({ getValue }) => (Number(getValue()) ? 'Yes' : 'No'),
  },
  {
    accessorKey: 'is_active',
    header: 'Status',
    cell: ({ getValue }) => (
      <span className="text-xs text-[var(--color-fg)]">
        {Number(getValue()) ? 'Active' : 'Decommissioned'}
      </span>
    ),
  },
];

export default function EmissionUnitList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Emission Units</h1>
        <button
          type="button"
          onClick={() => navigate('/emission-units/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Emission Unit
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/emission-units"
        onRowClick={(row) => navigate(`/emission-units/${row.id}`)}
      />
    </div>
  );
}
