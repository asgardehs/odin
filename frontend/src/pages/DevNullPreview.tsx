import { KPICard, type Summary } from '../components/KPICard';
import { HubLayout } from '../components/HubLayout';
import { useApi } from '../hooks/useApi';

// /devnull — Phase 2 preview surface. Not in any nav. Renders KPICard
// variants (loading / error / empty / ok / warn / alert) and HubLayout
// shell, and exercises one live summary endpoint to confirm the
// frontend↔backend contract round-trips. Delete once Phase 3 wires the
// real Dashboard.

export default function DevNullPreview() {
  const live = useApi<Summary>('/api/permits/summary');

  const samples: { title: string; data: Summary }[] = [
    {
      title: 'Empty state',
      data: { empty: true },
    },
    {
      title: 'Neutral',
      data: {
        empty: false,
        primary: { label: 'total', value: 12 },
      },
    },
    {
      title: 'OK',
      data: {
        empty: false,
        status: 'ok',
        primary: { label: 'active', value: 42 },
        secondary: { label: 'closed this year', value: 8 },
      },
    },
    {
      title: 'Warn',
      data: {
        empty: false,
        status: 'warn',
        primary: { label: 'expiring 90d', value: 3 },
        secondary: { label: 'active total', value: 42 },
      },
    },
    {
      title: 'Alert',
      data: {
        empty: false,
        status: 'alert',
        primary: { label: 'overdue', value: 7 },
        secondary: { label: 'lapsing 30d', value: 2 },
      },
    },
  ];

  const liveCard = (
    <KPICard
      key="live-permits"
      title="Permits (live stub)"
      href="/permits"
      icon="📄"
      data={live.data}
      loading={live.loading}
      error={live.error}
    />
  );

  const sampleCards = samples.map(s => (
    <KPICard
      key={s.title}
      title={s.title}
      href="/devnull"
      data={s.data}
    />
  ));

  return (
    <HubLayout
      title="Component preview"
      subtitle="Phase 2 — KPICard + HubLayout. Not user-facing."
      kpis={
        <>
          {liveCard}
          {sampleCards}
        </>
      }
      table={
        <p className="text-sm text-[var(--color-comment)]">
          Records-table slot — a wrapped DataTable lands here in each hub.
        </p>
      }
      expandHref="/devnull"
      expandLabel="Expand (no-op)"
    />
  );
}
