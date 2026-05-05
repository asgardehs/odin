import type { ReactNode } from 'react';
import { useApi } from '../../hooks/useApi';
import { useFacility } from '../../context/FacilityContext';
import { HubLayout } from '../../components/HubLayout';
import { KPICard, type Summary } from '../../components/KPICard';
import { CustomCardsForHub } from '../../components/CustomCardsForHub';
import { EstablishmentsTable } from '../../components/EstablishmentsTable';

// ScopedKPICard mirrors the helper in Dashboard — fetch one summary
// endpoint per card so each card renders its own loading / error state
// independently.
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
  { module: 'permits',           title: 'Permits',          href: '/permits',           icon: '📄' },
  { module: 'permits/npdes',     title: 'NPDES permits',    href: '/permits/npdes',     icon: '💧' },
  { module: 'emission-units',    title: 'Emission units',   href: '/emission-units',    icon: '🏭' },
  { module: 'waste-streams',     title: 'Waste streams',    href: '/waste',             icon: '🛢' },
  { module: 'chemicals',         title: 'Chemicals',        href: '/chemicals',         icon: '🧪' },
  { module: 'storage-locations', title: 'Storage locations', href: '/storage-locations', icon: '📦' },
  { module: 'discharge-points',  title: 'Outfalls',         href: '/discharge-points',  icon: '🚰' },
];

// Facilities hub — first hub built per the UI restructure plan, validates
// the HubLayout pattern at scale. Cards re-scope to the selected facility
// via useFacility(); the records table always shows all establishments
// so users can browse to other facilities from the hub.
export default function EstablishmentsHub() {
  const { selected, selectedId } = useFacility();
  const scope = selectedId == null ? '' : `?facility_id=${selectedId}`;
  const subtitle = selected ? selected.name : 'All facilities';

  return (
    <HubLayout
      title="Facilities"
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
          <CustomCardsForHub parentModule="facilities" scope={scope} />
        </>
      }
      table={<EstablishmentsTable />}
      expandHref="/establishments/full"
    />
  );
}
