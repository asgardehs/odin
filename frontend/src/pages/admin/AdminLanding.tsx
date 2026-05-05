interface AdminCardProps {
  title: string;
  description: string;
  href: string;
  icon: string;
}

function AdminCard({ title, description, href, icon }: AdminCardProps) {
  return (
    <a
      href={href}
      className="block rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5 hover:border-[var(--color-selection)] hover:bg-[var(--color-bg-lighter)] transition-all"
    >
      <div className="flex items-start gap-3">
        <span className="text-2xl leading-none">{icon}</span>
        <div className="flex-1">
          <h2 className="text-sm font-semibold text-[var(--color-fg)] mb-1">{title}</h2>
          <p className="text-xs text-[var(--color-comment)] leading-relaxed">{description}</p>
        </div>
      </div>
    </a>
  );
}

const cards: AdminCardProps[] = [
  {
    title: 'Users',
    description: 'Add, deactivate, and reset passwords for application users.',
    href: '/admin/users',
    icon: '👤',
  },
  {
    title: 'Custom Table Builder',
    description: 'Define your own tables to track data Odin’s built-in modules don’t cover.',
    href: '/admin/schema',
    icon: '🛠',
  },
  {
    title: 'Import',
    description: 'Bulk-load records from CSV or Excel into any table.',
    href: '/admin/import',
    icon: '📥',
  },
  {
    title: 'OSHA ITA Export',
    description: 'Generate the CSV for the OSHA Injury Tracking Application annual submission.',
    href: '/osha-ita',
    icon: '📤',
  },
];

// /admin — landing page for administrative tools. Four nav tiles, each
// linking into an existing admin page. Routes for those pages are
// unchanged; only the entry surface is new.
export default function AdminLanding() {
  return (
    <div className="flex flex-col gap-6">
      <header>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Admin</h1>
        <p className="text-sm text-[var(--color-comment)] mt-1">
          Application administration tools.
        </p>
      </header>

      <section
        aria-label="Admin tools"
        className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4"
      >
        {cards.map(c => (
          <AdminCard key={c.href} {...c} />
        ))}
      </section>
    </div>
  );
}
