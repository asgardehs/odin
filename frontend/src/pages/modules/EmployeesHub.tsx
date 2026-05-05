import type { ReactNode } from 'react';
import { useApi } from '../../hooks/useApi';
import { useFacility } from '../../context/FacilityContext';
import { HubLayout } from '../../components/HubLayout';
import { KPICard, type Summary } from '../../components/KPICard';
import { CustomCardsForHub } from '../../components/CustomCardsForHub';
import { EmployeesTable } from '../../components/EmployeesTable';

function ScopedKPICard({
  url,
  title,
  href,
  icon,
}: {
  url: string;
  title: string;
  href: string;
  icon?: ReactNode;
}) {
  const { data, loading, error } = useApi<Summary>(url);
  return (
    <KPICard
      title={title}
      href={href}
      icon={icon}
      data={data}
      loading={loading}
      error={error}
    />
  );
}

const cards: { module: string; title: string; href: string; icon: string }[] = [
  { module: 'training',  title: 'Training',  href: '/training',  icon: '🎓' },
  { module: 'ppe',       title: 'PPE',       href: '/ppe',       icon: '🦺' },
  { module: 'incidents', title: 'Incidents', href: '/incidents', icon: '⚠' },
];

// Employees hub — three glance cards over the Employees records table.
// Cards re-scope to the selected facility via useFacility().
export default function EmployeesHub() {
  const { selected, selectedId } = useFacility();
  const scope = selectedId == null ? '' : `?facility_id=${selectedId}`;
  const subtitle = selected ? selected.name : 'All facilities';

  return (
    <HubLayout
      title="Employees"
      subtitle={subtitle}
      kpis={
        <>
          {cards.map(c => (
            <ScopedKPICard
              key={c.module}
              url={`/api/${c.module}/summary${scope}`}
              title={c.title}
              href={c.href}
              icon={c.icon}
            />
          ))}
          <CustomCardsForHub parentModule="employees" scope={scope} />
        </>
      }
      table={<EmployeesTable />}
      expandHref="/employees/full"
    />
  );
}
