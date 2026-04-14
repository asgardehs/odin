import { useNavigate } from 'react-router';
import { type ColumnDef } from '@tanstack/react-table';
import { DataTable, type Row } from '../../components/DataTable';

const columns: ColumnDef<Row>[] = [
  { accessorKey: 'course_code', header: 'Code' },
  { accessorKey: 'course_name', header: 'Course Name' },
  {
    accessorKey: 'duration_minutes',
    header: 'Duration',
    cell: ({ getValue }) => {
      const mins = getValue() as number | null;
      if (mins == null) return '—';
      return mins >= 60 ? `${Math.floor(mins / 60)}h ${mins % 60}m` : `${mins}m`;
    },
  },
  { accessorKey: 'delivery_method', header: 'Delivery', cell: ({ getValue }) => String(getValue() ?? '—') },
];

export default function TrainingList() {
  const navigate = useNavigate();
  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-text-primary)] mb-6">Training</h1>
      <DataTable
        columns={columns}
        apiUrl="/api/training/courses"
        onRowClick={(row) => navigate(`/training/${row.id}`)}
      />
    </div>
  );
}
