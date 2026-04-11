import { useState } from 'react';
import { NavLink, Outlet } from 'react-router';

const navItems = [
  { to: '/',              label: 'Dashboard',    icon: '⬡' },
  { to: '/establishments', label: 'Facilities',   icon: '🏭' },
  { to: '/employees',     label: 'Employees',    icon: '👥' },
  { to: '/incidents',     label: 'Incidents',    icon: '⚠' },
  { to: '/chemicals',     label: 'Chemicals',    icon: '🧪' },
  { to: '/training',      label: 'Training',     icon: '📋' },
  { to: '/inspections',   label: 'Inspections',  icon: '🔍' },
  { to: '/permits',       label: 'Permits',      icon: '📄' },
  { to: '/waste',         label: 'Waste',        icon: '♻' },
  { to: '/ppe',           label: 'PPE',          icon: '🦺' },
];

export default function Shell() {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="flex h-screen overflow-hidden">
      {/* Sidebar */}
      <nav className={`flex flex-col ${sidebarOpen ? 'w-48' : 'w-16'} transition-all duration-200 bg-[var(--color-bg-secondary)] border-r border-[var(--color-border)] overflow-hidden`}>
        {/* Logo + toggle */}
        <div className="flex items-center h-14 px-4 border-b border-[var(--color-border)]">
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="flex items-center gap-2 bg-transparent border-none cursor-pointer"
          >
            <img src="/favicon.svg" alt="Odin" className="w-7 h-7 shrink-0" />
            {sidebarOpen && (
              <span className="text-sm font-semibold text-[var(--color-accent-light)] whitespace-nowrap">
                ODIN
              </span>
            )}
          </button>
        </div>

        {/* Nav items */}
        <div className="flex-1 flex flex-col py-2 gap-0.5">
          {navItems.map(item => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) =>
                `flex items-center h-10 px-4 gap-3 text-sm transition-colors whitespace-nowrap ${
                  isActive
                    ? 'text-[var(--color-accent-light)] bg-[var(--color-bg-hover)] border-r-2 border-[var(--color-accent)]'
                    : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:bg-[var(--color-bg-hover)]'
                }`
              }
            >
              <span className="text-base w-5 text-center shrink-0">{item.icon}</span>
              {sidebarOpen && <span>{item.label}</span>}
            </NavLink>
          ))}
        </div>

        {/* User area */}
        <div className="border-t border-[var(--color-border)] p-3">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-full bg-[var(--color-accent-muted)] flex items-center justify-center text-xs font-bold text-[var(--color-accent-light)] shrink-0">
              A
            </div>
            {sidebarOpen && (
              <span className="text-xs text-[var(--color-text-secondary)] whitespace-nowrap">
                adam
              </span>
            )}
          </div>
        </div>
      </nav>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        {/* Top bar */}
        <header className="sticky top-0 z-10 flex items-center h-14 px-6 bg-[var(--color-bg-secondary)]/80 backdrop-blur-sm border-b border-[var(--color-border)]">
          <div className="flex-1" />
          <div className="flex items-center gap-4 text-[var(--color-text-secondary)] text-base mr-[25px]">
            <span>Odin EHS</span>
          </div>
        </header>

        {/* Page content */}
        <div className="p-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
