// Backend stores timestamps via SQLite's datetime('now'), which produces
// "YYYY-MM-DD HH:MM:SS" in UTC with no timezone suffix. JavaScript's
// Date parser treats that format ambiguously — some engines assume local
// time, others UTC. We normalize by rewriting to ISO-8601 with an
// explicit Z, then use Intl to render in the user's locale + timezone.

const TIMESTAMP_RE = /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function parseUTC(s: string): Date | null {
  let iso = s.trim();
  if (iso.length < 19) return null;
  if (iso[10] === ' ') iso = iso.slice(0, 10) + 'T' + iso.slice(11);
  if (!/Z|[+-]\d{2}:?\d{2}$/.test(iso)) iso += 'Z';
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
}

/** Detect values that look like UTC timestamps from the backend. */
export function looksLikeTimestamp(v: unknown): boolean {
  return typeof v === 'string' && TIMESTAMP_RE.test(v.trim());
}

/** Detect values that look like plain dates (no time component). */
export function looksLikeDate(v: unknown): boolean {
  return typeof v === 'string' && DATE_RE.test(v.trim());
}

/** Format a UTC timestamp string as local date + time + tz abbreviation. */
export function formatTimestamp(s: string | null | undefined): string {
  if (!s) return '';
  const d = parseUTC(s);
  if (!d) return s;
  // dateStyle/timeStyle can't be combined with timeZoneName — use the
  // individual field options instead.
  return new Intl.DateTimeFormat(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZoneName: 'short',
  }).format(d);
}

/** Format a YYYY-MM-DD date-only string as a locale-aware date. */
export function formatDate(s: string | null | undefined): string {
  if (!s) return '';
  // Parse as UTC midnight so the locale render doesn't shift the day.
  const d = new Date(s + 'T00:00:00Z');
  if (Number.isNaN(d.getTime())) return s;
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeZone: 'UTC',
  }).format(d);
}
