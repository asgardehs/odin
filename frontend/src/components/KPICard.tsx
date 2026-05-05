import type { ReactNode } from 'react';

export interface SummaryMetric {
  label: string;
  value: number;
}

export type SummaryStatus = 'ok' | 'warn' | 'alert' | '';

// Summary mirrors the backend Summary type returned by /api/{module}/summary.
// Keep in sync with internal/server/api_summary.go.
export interface Summary {
  primary?: SummaryMetric;
  secondary?: SummaryMetric;
  status?: SummaryStatus;
  empty: boolean;
}

interface KPICardProps {
  title: string;
  href: string;
  icon?: ReactNode;
  data?: Summary | null;
  loading?: boolean;
  error?: string | null;
  emptyCta?: string;
}

const statusBand: Record<Exclude<SummaryStatus, ''>, string> = {
  ok: 'border-l-[var(--color-fn-green)]',
  warn: 'border-l-[var(--color-fn-yellow)]',
  alert: 'border-l-[var(--color-fn-red)]',
};

const statusValueColor: Record<Exclude<SummaryStatus, ''>, string> = {
  ok: 'var(--color-fn-green)',
  warn: 'var(--color-fn-yellow)',
  alert: 'var(--color-fn-red)',
};

export function KPICard({
  title,
  href,
  icon,
  data,
  loading,
  error,
  emptyCta = 'No records yet — add your first',
}: KPICardProps) {
  const status = data?.status && data.status !== '' ? data.status : null;
  const bandClass = status ? statusBand[status] : 'border-l-[var(--color-current-line)]';
  const valueColor = status ? statusValueColor[status] : 'var(--color-fg)';

  return (
    <a
      href={href}
      className={`block rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] border-l-4 ${bandClass} p-5 hover:border-[var(--color-selection)] hover:bg-[var(--color-bg-lighter)] transition-all group`}
    >
      <div className="flex items-start justify-between mb-3">
        <p className="text-sm font-medium text-[var(--color-fg)]">{title}</p>
        {icon && <span className="text-xl leading-none">{icon}</span>}
      </div>

      {error ? (
        <p className="text-sm text-[var(--color-fn-red)]">Failed to load</p>
      ) : loading ? (
        <div className="space-y-2">
          <div className="h-8 w-16 rounded bg-[var(--color-current-line)] animate-pulse" />
          <div className="h-3 w-24 rounded bg-[var(--color-current-line)] animate-pulse" />
        </div>
      ) : data?.empty ? (
        <p className="text-sm text-[var(--color-comment)]">{emptyCta}</p>
      ) : (
        <>
          <div className="flex items-baseline gap-2 mb-1">
            <span
              className="text-3xl font-bold tabular-nums"
              style={{ color: valueColor }}
            >
              {data?.primary?.value ?? '—'}
            </span>
            {data?.primary?.label && (
              <span className="text-xs text-[var(--color-comment)]">
                {data.primary.label}
              </span>
            )}
          </div>
          {data?.secondary && (
            <p className="text-xs text-[var(--color-comment)] tabular-nums">
              <span className="text-[var(--color-fg)]">{data.secondary.value}</span>{' '}
              {data.secondary.label}
            </p>
          )}
        </>
      )}
    </a>
  );
}
