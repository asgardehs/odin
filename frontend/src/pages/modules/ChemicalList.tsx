import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'product_name', header: 'Product Name' },
  { accessorKey: 'primary_cas_number', header: 'CAS Number', cell: ({ getValue }) => String(getValue() ?? '—') },
  { accessorKey: 'manufacturer', header: 'Manufacturer', cell: ({ getValue }) => String(getValue() ?? '—') },
  {
    accessorKey: 'is_ehs',
    header: 'EHS',
    cell: ({ getValue }) =>
      getValue() ? (
        <span className="text-[var(--color-fn-red)] text-xs font-medium">⚠ EHS</span>
      ) : (
        <span className="text-[var(--color-comment)] text-xs">—</span>
      ),
  },
  {
    accessorKey: 'is_active',
    header: 'Status',
    cell: ({ getValue }) =>
      getValue() ? (
        <span className="text-[var(--color-fn-green)] text-xs font-medium">Active</span>
      ) : (
        <span className="text-[var(--color-comment)] text-xs">Inactive</span>
      ),
  },
];

export default function ChemicalList() {
  const navigate = useNavigate();
  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Chemicals</h1>
        <button
          type="button"
          onClick={() => navigate('/chemicals/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New Chemical
        </button>
      </div>
      <DataTable
        columns={columns}
        apiUrl="/api/chemicals"
        onRowClick={(row) => navigate(`/chemicals/${row.id}`)}
      />
    </div>
  );
}
