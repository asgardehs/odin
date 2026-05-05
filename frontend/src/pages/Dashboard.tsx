import { useApi } from '../hooks/useApi';
import { statusForOpenItems } from '../utils/status';

interface DashboardCounts {
  establishments: number | null;
  employees: number | null;
  open_incidents: number | null;
  open_cas: number | null;
  chemicals: number | null;
  active_permits: number | null;
  expiring_permits: number | null;
}

// Cards split into two kinds:
//   neutral  — "stuff you have" counts; cyan, no threshold meaning
//   threshold — "open work item" counts; color derives from
//               statusForOpenItems (0 ok / 1-3 warn / 4+ alert)
type CardKind = 'neutral' | 'threshold';

const cards: {
  key: keyof DashboardCounts;
  label: string;
  icon: string;
  route: string;
  kind: CardKind;
}[] = [
  { key: 'establishments',   label: 'Facilities',         icon: '🏭', route: '/establishments', kind: 'neutral' },
  { key: 'employees',        label: 'Active Employees',   icon: '👥', route: '/employees',      kind: 'neutral' },
  { key: 'open_incidents',   label: 'Open Incidents',     icon: '⚠',  route: '/incidents',      kind: 'threshold' },
  { key: 'open_cas',         label: 'Open Actions',       icon: '🔧', route: '/incidents',      kind: 'threshold' },
  { key: 'chemicals',        label: 'Active Chemicals',   icon: '🧪', route: '/chemicals',      kind: 'neutral' },
  { key: 'active_permits',   label: 'Active Permits',     icon: '📄', route: '/permits',        kind: 'neutral' },
  { key: 'expiring_permits', label: 'Permits Expiring',   icon: '⏰', route: '/permits',        kind: 'threshold' },
];

const statusColor: Record<'ok' | 'warn' | 'alert', string> = {
  ok:    'var(--color-fn-green)',
  warn:  'var(--color-fn-yellow)',
  alert: 'var(--color-fn-red)',
};

function colorForCard(kind: CardKind, value: number | null | undefined): string {
  if (kind === 'neutral') return 'var(--color-fn-cyan)';
  const s = statusForOpenItems(value);
  if (s === '') return 'var(--color-fn-cyan)';
  return statusColor[s];
}

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
                style={{ color: colorForCard(card.kind, data?.[card.key]) }}
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
