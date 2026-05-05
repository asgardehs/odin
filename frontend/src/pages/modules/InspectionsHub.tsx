import type { ReactNode } from 'react';
import { useApi } from '../../hooks/useApi';
import { useFacility } from '../../context/FacilityContext';
import { HubLayout } from '../../components/HubLayout';
import { KPICard, type Summary } from '../../components/KPICard';
import { CustomCardsForHub } from '../../components/CustomCardsForHub';
import { InspectionsTable } from '../../components/InspectionsTable';

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
  { module: 'audits',           title: 'Audit findings', href: '/audits',           icon: '📋' },
  { module: 'ww-sample-events', title: 'Sample events',  href: '/ww-sample-events', icon: '💧' },
];

// Inspections hub — groups the verification activities (audits and
// sample events as glance cards; routine site inspections as the
// records table). Cards re-scope via useFacility().
export default function InspectionsHub() {
  const { selected, selectedId } = useFacility();
  const scope = selectedId == null ? '' : `?facility_id=${selectedId}`;
  const subtitle = selected ? selected.name : 'All facilities';

  return (
    <HubLayout
      title="Inspections"
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
          <CustomCardsForHub parentModule="inspections" scope={scope} />
        </>
      }
      table={<InspectionsTable />}
      expandHref="/inspections/full"
    />
  );
}
