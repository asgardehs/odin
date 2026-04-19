import { useParams, useNavigate } from 'react-router';
import { useApi } from '../../hooks/useApi';
import { Field, Section } from '../../components/DetailSection';

type EmployeeRow = Record<string, unknown>;

export default function EmployeeDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data, loading, error } = useApi<EmployeeRow>(`/api/employees/${id}`);

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">
        Loading…
      </div>
    );
  }

  if (error || !data) {
    const notFound = error?.startsWith('404');
    return (
      <div className="flex flex-col items-center gap-4 p-12 text-[var(--color-comment)]">
        <p className="text-sm">{notFound ? 'Employee not found.' : `Error: ${error}`}</p>
        <button onClick={() => navigate('/employees')} className="text-xs text-[var(--color-purple)] hover:underline">
          ← Back to Employees
        </button>
      </div>
    );
  }

  const fullName = [data.first_name, data.last_name].filter(Boolean).join(' ') || 'Employee';

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => navigate('/employees')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Employees
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">{fullName}</h1>
        <span
          className={`ml-auto text-xs font-medium px-2 py-0.5 rounded-full ${
            data.is_active
              ? 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]'
              : 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
          }`}
        >
          {data.is_active ? 'Active' : 'Inactive'}
        </span>
      </div>

      <div className="flex flex-col gap-4">
        <Section title="Personal">
          <Field label="First Name" value={data.first_name} />
          <Field label="Last Name" value={data.last_name} />
          <Field label="Employee #" value={data.employee_number} />
        </Section>

        <Section title="Employment">
          <Field label="Job Title" value={data.job_title} />
          <Field label="Department" value={data.department} />
          <Field label="Date Hired" value={data.date_hired} />
        </Section>

        <Section title="Record">
          <Field label="Created" value={data.created_at} />
          <Field label="Updated" value={data.updated_at} />
        </Section>
      </div>
    </div>
  );
}
