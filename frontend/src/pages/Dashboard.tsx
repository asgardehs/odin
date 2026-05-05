import type { ReactNode } from 'react';
import { useApi } from '../hooks/useApi';
import { useFacility } from '../context/FacilityContext';
import { KPICard, type Summary } from '../components/KPICard';

// ScopedKPICard fetches a single /api/{module}/summary endpoint and feeds
// it into a KPICard. Encapsulating one fetch per card keeps the
// Dashboard body readable and lets each card render its own loading /
// error state independently.
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
  { module: 'permits',           title: 'Permits',         href: '/permits',          icon: '📄' },
  { module: 'training',          title: 'Training',        href: '/training',         icon: '🎓' },
  { module: 'audits',            title: 'Audit findings',  href: '/audits',           icon: '📋' },
  { module: 'incidents',         title: 'Incidents',       href: '/incidents',        icon: '⚠' },
  { module: 'ww-sample-events',  title: 'Sample events',   href: '/ww-sample-events', icon: '💧' },
  { module: 'osha-300',          title: 'OSHA 300',        href: '/incidents',        icon: '🩺' },
];

export default function Dashboard() {
  const { selected, selectedId } = useFacility();
  const scope = selectedId == null ? '' : `?facility_id=${selectedId}`;
  const subtitle = selected ? selected.name : 'All facilities';

  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Dashboard</h1>
        <p className="text-sm text-[var(--color-comment)] mt-1">{subtitle}</p>
      </header>

      <section
        aria-label="Top-level KPIs"
        className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-3 xl:grid-cols-6 gap-4"
      >
        {cards.map(c => (
          <ScopedKPICard
            key={c.module}
            url={`/api/${c.module}/summary${scope}`}
            title={c.title}
            href={c.href}
            icon={c.icon}
          />
        ))}
      </section>
    </div>
  );
}
