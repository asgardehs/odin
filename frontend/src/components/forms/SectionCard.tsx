import type { ReactNode } from 'react';

interface SectionCardProps {
  title: string;
  description?: string;
  children: ReactNode;
}

export function SectionCard({ title, description, children }: SectionCardProps) {
  return (
    <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5">
      <h2 className="text-lg font-semibold text-[var(--color-purple)] mb-1">{title}</h2>
      {description && (
        <p className="text-sm text-[var(--color-comment)] mb-4">{description}</p>
      )}
      <div className={description ? '' : 'mt-4'}>{children}</div>
    </div>
  );
}
