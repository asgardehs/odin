import { useLocation } from 'react-router';

export default function Placeholder() {
  const location = useLocation();
  const name = location.pathname.slice(1).replace(/-/g, ' ');
  const title = name.charAt(0).toUpperCase() + name.slice(1);

  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-text-primary)] mb-4">{title || 'Page'}</h1>
      <div className="rounded-xl bg-[var(--color-bg-card)] border border-[var(--color-border)] border-dashed p-12 text-center">
        <p className="text-[var(--color-text-muted)] text-lg">Module view coming soon</p>
      </div>
    </div>
  );
}
