import type { ReactNode } from 'react';

interface HubLayoutProps {
  title: string;
  // Optional context line under the title — typically the selected facility
  // name, or "All facilities" when no facility is scoped.
  subtitle?: string;
  // KPI cards rendered in the upper-third grid. Caller passes ready-built
  // <KPICard /> children; HubLayout owns the grid.
  kpis: ReactNode;
  // Records table area (lower 2/3). Typically a wrapped DataTable.
  table: ReactNode;
  // Route the Expand button navigates to (the full-screen records view).
  expandHref: string;
  // Optional override for the expand label.
  expandLabel?: string;
}

export function HubLayout({
  title,
  subtitle,
  kpis,
  table,
  expandHref,
  expandLabel = 'Expand',
}: HubLayoutProps) {
  return (
    <div className="flex flex-col gap-6">
      <header className="flex items-end justify-between flex-wrap gap-2">
        <div>
          <h1 className="text-2xl font-bold text-[var(--color-fg)]">{title}</h1>
          {subtitle && (
            <p className="text-sm text-[var(--color-comment)] mt-1">{subtitle}</p>
          )}
        </div>
      </header>

      <section
        aria-label={`${title} key metrics`}
        className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4"
      >
        {kpis}
      </section>

      <section
        aria-label={`${title} records`}
        className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] overflow-hidden"
      >
        <div className="flex items-center justify-between px-4 py-3 border-b border-[var(--color-current-line)]">
          <h2 className="text-sm font-semibold text-[var(--color-purple)]">Records</h2>
          <a
            href={expandHref}
            className="text-xs font-medium text-[var(--color-fn-cyan)] hover:text-[var(--color-selection)] transition-colors"
          >
            {expandLabel} →
          </a>
        </div>
        <div className="p-4">{table}</div>
      </section>
    </div>
  );
}
