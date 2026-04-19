interface StatusBadgeProps {
  status: string | null | undefined;
}

type ToneKey = 'success' | 'warning' | 'danger' | 'info' | 'neutral';

const toneClasses: Record<ToneKey, string> = {
  success:
    'bg-[var(--color-fn-green)]/10 border-[var(--color-fn-green)]/30 text-[var(--color-fn-green)]',
  warning:
    'bg-[var(--color-fn-yellow)]/10 border-[var(--color-fn-yellow)]/30 text-[var(--color-fn-yellow)]',
  danger:
    'bg-[var(--color-fn-red)]/10 border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)]',
  info:
    'bg-[var(--color-fn-purple)]/10 border-[var(--color-fn-purple)]/30 text-[var(--color-fn-purple)]',
  neutral:
    'bg-[var(--color-current-line)]/40 border-[var(--color-current-line)] text-[var(--color-comment)]',
};

function classifyStatus(raw: string): ToneKey {
  const s = raw.toLowerCase();
  if (['active', 'completed', 'verified', 'passed', 'effective', 'open'].includes(s)) return 'success';
  if (['pending', 'scheduled', 'assigned', 'in_progress', 'reported', 'draft'].includes(s)) return 'info';
  if (['expiring', 'due_soon', 'warning'].includes(s)) return 'warning';
  if (['inactive', 'closed', 'cancelled', 'canceled', 'retired', 'discontinued', 'revoked', 'expired', 'failed', 'rejected'].includes(s)) return 'danger';
  return 'neutral';
}

export function StatusBadge({ status }: StatusBadgeProps) {
  if (!status) {
    return (
      <span className={`inline-flex items-center px-2 py-0.5 rounded-md border text-xs font-medium ${toneClasses.neutral}`}>
        —
      </span>
    );
  }
  const tone = classifyStatus(status);
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-md border text-xs font-medium ${toneClasses[tone]}`}>
      {status.replace(/_/g, ' ')}
    </span>
  );
}
