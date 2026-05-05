import { useApi } from '../hooks/useApi';
import { KPICard, type Summary } from './KPICard';
import type { CustomTable, ParentModule } from '../hooks/useCustomTableSchema';

interface TablesResponse {
  tables: CustomTable[];
}

// One KPICard for an admin-defined custom table. Pulled out as its own
// component so we can call useApi once per card without nesting hooks
// inside a .map(). Custom-card summaries are pure row counts via the
// generic /api/records/{slug}/summary endpoint.
function CustomTableCard({
  table,
  scope,
}: {
  table: CustomTable;
  scope: string;
}) {
  const { data, loading, error } = useApi<Summary>(
    `/api/records/${encodeURIComponent(table.name)}/summary${scope}`,
  );
  return (
    <KPICard
      title={table.display_name}
      href={`/custom/${table.name}`}
      icon={
        <span className="flex items-center gap-1">
          <span>{table.icon ?? '📋'}</span>
          <span
            className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--color-current-line)] text-[var(--color-comment)]"
            title="User-added custom table"
          >
            custom
          </span>
        </span>
      }
      data={data}
      loading={loading}
      error={error}
    />
  );
}

// Renders a KPICard for every active custom table whose parent_module
// matches the hub. Returns nothing when the user has no matching tables
// — hubs render their built-in cards regardless.
export function CustomCardsForHub({
  parentModule,
  scope,
}: {
  parentModule: Exclude<ParentModule, 'none'>;
  scope: string;
}) {
  const { data } = useApi<TablesResponse>(
    `/api/schema/tables?active=1&parent_module=${parentModule}`,
  );
  const tables = data?.tables ?? [];
  if (tables.length === 0) return null;
  return (
    <>
      {tables.map(t => (
        <CustomTableCard key={t.id} table={t} scope={scope} />
      ))}
    </>
  );
}
