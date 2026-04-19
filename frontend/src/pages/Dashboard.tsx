import { useApi } from '../hooks/useApi';

interface DashboardCounts {
  establishments: number | null;
  employees: number | null;
  open_incidents: number | null;
  open_cas: number | null;
  chemicals: number | null;
  active_permits: number | null;
  expiring_permits: number | null;
}

const cards: { key: keyof DashboardCounts; label: string; icon: string; color: string; route: string }[] = [
  { key: 'establishments',   label: 'Facilities',         icon: '🏭', color: 'var(--color-fn-cyan)',   route: '/establishments' },
  { key: 'employees',        label: 'Active Employees',   icon: '👥', color: 'var(--color-fn-cyan)',   route: '/employees' },
  { key: 'open_incidents',   label: 'Open Incidents',     icon: '⚠',  color: 'var(--color-fn-red)', route: '/incidents' },
  { key: 'open_cas',         label: 'Open Actions',       icon: '🔧', color: 'var(--color-fn-orange)',   route: '/incidents' },
  { key: 'chemicals',        label: 'Active Chemicals',   icon: '🧪', color: 'var(--color-fn-cyan)',   route: '/chemicals' },
  { key: 'active_permits',   label: 'Active Permits',     icon: '📄', color: 'var(--color-fn-green)',     route: '/permits' },
  { key: 'expiring_permits', label: 'Permits Expiring',   icon: '⏰', color: 'var(--color-fn-orange)',   route: '/permits' },
];

export default function Dashboard() {
  const { data, loading, error } = useApi<DashboardCounts>('/api/dashboard/counts');

  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-fg)] mb-6">Dashboard</h1>

      {error && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-6 text-sm">
          Failed to load dashboard: {error}
        </div>
      )}

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        {cards.map(card => (
          <a
            key={card.key}
            href={card.route}
            className="block rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5 hover:border-[var(--color-selection)] hover:bg-[var(--color-bg-lighter)] transition-all group"
          >
            <div className="flex items-center justify-between mb-3">
              <span className="text-2xl">{card.icon}</span>
              <span
                className="text-3xl font-bold tabular-nums"
                style={{ color: card.color }}
              >
                {loading ? (
                  <span className="inline-block w-8 h-8 rounded bg-[var(--color-current-line)] animate-pulse" />
                ) : (
                  data?.[card.key] ?? 0
                )}
              </span>
            </div>
            <p className="text-sm text-[var(--color-fg)] group-hover:text-[var(--color-fg)] transition-colors">
              {card.label}
            </p>
          </a>
        ))}
      </div>

      {/* Quick status section */}
      <div className="mt-8 grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <h2 className="text-lg font-semibold text-[var(--color-purple)] mb-3">Recent Incidents</h2>
          <p className="text-sm text-[var(--color-comment)]">No incidents recorded yet.</p>
        </div>
        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
          <h2 className="text-lg font-semibold text-[var(--color-purple)] mb-3">Upcoming Deadlines</h2>
          <p className="text-sm text-[var(--color-comment)]">No upcoming deadlines.</p>
        </div>
      </div>
    </div>
  );
}
