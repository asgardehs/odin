import type { ReactNode } from 'react';

/** A labelled key-value field inside a detail section. */
export function Field({ label, value }: { label: string; value: unknown }) {
  let display: string;
  if (value == null || value === '') {
    display = '—';
  } else if (typeof value === 'number' && (value === 0 || value === 1) && label.toLowerCase().includes('active')) {
    // SQLite booleans stored as 0/1 for is_active-style fields
    display = value ? 'Yes' : 'No';
  } else {
    display = String(value);
  }

  return (
    <div>
      <dt className="text-xs text-[var(--color-comment)] uppercase tracking-wide mb-0.5">{label}</dt>
      <dd className="text-[var(--color-fg)] text-sm">{display}</dd>
    </div>
  );
}

/** A titled card grouping several Fields in a responsive grid. */
export function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
      <h2 className="text-xs font-semibold text-[var(--color-purple)] uppercase tracking-wider mb-4">
        {title}
      </h2>
      <dl className="grid grid-cols-2 md:grid-cols-3 gap-x-6 gap-y-4">{children}</dl>
    </div>
  );
}
