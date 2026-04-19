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
      <h1 className="text-2xl font-bold text-[var(--color-fg)] mb-6">Chemicals</h1>
      <DataTable
        columns={columns}
        apiUrl="/api/chemicals"
        onRowClick={(row) => navigate(`/chemicals/${row.id}`)}
      />
    </div>
  );
}
