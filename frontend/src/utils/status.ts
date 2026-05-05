import type { SummaryStatus } from '../components/KPICard';

// statusForOpenItems applies the project-wide convention for "open work
// item" KPIs (open incidents, expiring permits, overdue training,
// outstanding corrective actions, etc.) — metrics where zero means good
// and higher means worse:
//
//   0   → ok      (green band)
//   1-3 → warn    (yellow band)
//   4+  → alert   (red band)
//
// Use this for any backend Summary whose primary metric counts open work.
// Metrics where higher is better (e.g. completed trainings) or that are
// pure neutral counts (e.g. number of facilities) should NOT use this —
// pass status='' or omit it entirely.
export function statusForOpenItems(count: number | null | undefined): SummaryStatus {
  if (count == null) return '';
  if (count === 0) return 'ok';
  if (count <= 3) return 'warn';
  return 'alert';
}
