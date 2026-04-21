import { useState } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router';
import { useAuth } from '../context/AuthContext';
import { useCustomTablesList } from '../hooks/useCustomTablesList';
import logo from '../assets/OdinEHSlogo_256.png';

const navItems = [
  { to: '/',              label: 'Dashboard',    icon: '⬡' },
  { to: '/establishments', label: 'Facilities',   icon: '🏭' },
  { to: '/employees',     label: 'Employees',    icon: '👥' },
  { to: '/incidents',     label: 'Incidents',    icon: '⚠' },
  { to: '/chemicals',     label: 'Chemicals',    icon: '🧪' },
  { to: '/training',      label: 'Training',     icon: '📋' },
  { to: '/inspections',   label: 'Inspections',  icon: '🔍' },
  { to: '/audits',        label: 'Audits',       icon: '📝' },
  { to: '/permits',       label: 'Permits',      icon: '📄' },
  { to: '/emission-units', label: 'Emissions',   icon: '💨' },
  { to: '/discharge-points', label: 'Outfalls',  icon: '💧' },
  { to: '/ww-sample-events', label: 'Sample Events', icon: '🧫' },
  { to: '/waste',         label: 'Waste',        icon: '♻' },
  { to: '/ppe',           label: 'PPE',          icon: '🦺' },
  { to: '/storage-locations', label: 'Storage',  icon: '📦' },
];

const adminNavItems = [
  { to: '/admin/users',  label: 'Users',  icon: '🔐' },
  { to: '/admin/schema', label: 'Schema', icon: '🧱' },
];

export default function Shell() {
  const { user, readonly, logout } = useAuth();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(true);

  // Custom tables group — only fetched for admins; the endpoint is
  // admin-only and non-admin users simply see no group rendered.
  const customTables = useCustomTablesList(user?.role === 'admin');
  const sortedCustomTables = [...customTables].sort((a, b) =>
    a.display_name.localeCompare(b.display_name),
  );

  return (
    <div className="flex h-screen overflow-hidden">
      {/* Sidebar */}
      <nav className={`flex flex-col ${sidebarOpen ? 'w-48' : 'w-16'} transition-all duration-200 bg-[var(--color-bg-dark)] border-r border-[var(--color-current-line)] overflow-hidden`}>
        {/* Sidebar toggle */}
        <div className="flex items-center justify-center h-14 border-b border-[var(--color-current-line)]">
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="flex items-center justify-center w-8 h-8 bg-transparent border-none cursor-pointer text-[var(--color-fg)] hover:text-[var(--color-fg)] transition-colors"
          >
            <svg width="18" height="14" viewBox="0 0 18 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <line x1="1" y1="1" x2="17" y2="1" />
              <line x1="1" y1="7" x2="17" y2="7" />
              <line x1="1" y1="13" x2="17" y2="13" />
            </svg>
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
                    ? 'text-[var(--color-purple)] bg-[var(--color-bg-lighter)] border-r-2 border-[var(--color-fn-purple)]'
                    : 'text-[var(--color-fg)] hover:text-[var(--color-fg)] hover:bg-[var(--color-bg-lighter)]'
                }`
              }
            >
              <span className="text-base w-5 text-center shrink-0">{item.icon}</span>
              {sidebarOpen && <span>{item.label}</span>}
            </NavLink>
          ))}

          {/* Custom Tables group — visible to admins once ≥1 active
              custom table exists. Refreshes on odin:schema-changed. */}
          {user?.role === 'admin' && sortedCustomTables.length > 0 && (
            <>
              <div className="mt-2 mb-1 px-4 h-px bg-[var(--color-current-line)]" />
              {sidebarOpen && (
                <div className="px-4 pt-2 pb-1 text-[10px] uppercase tracking-wider text-[var(--color-comment)]">
                  Custom Tables
                </div>
              )}
              {sortedCustomTables.map(t => (
                <NavLink
                  key={t.id}
                  to={`/custom/${t.name}`}
                  className={({ isActive }) =>
                    `flex items-center h-10 px-4 gap-3 text-sm transition-colors whitespace-nowrap ${
                      isActive
                        ? 'text-[var(--color-purple)] bg-[var(--color-bg-lighter)] border-r-2 border-[var(--color-fn-purple)]'
                        : 'text-[var(--color-fg)] hover:text-[var(--color-fg)] hover:bg-[var(--color-bg-lighter)]'
                    }`
                  }
                  title={t.display_name}
                >
                  <span className="text-base w-5 text-center shrink-0">{t.icon ?? '🧱'}</span>
                  {sidebarOpen && <span className="truncate">{t.display_name}</span>}
                </NavLink>
              ))}
            </>
          )}

          {user?.role === 'admin' && (
            <>
              <div className="mt-2 mb-1 px-4 h-px bg-[var(--color-current-line)]" />
              {adminNavItems.map(item => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  className={({ isActive }) =>
                    `flex items-center h-10 px-4 gap-3 text-sm transition-colors whitespace-nowrap ${
                      isActive
                        ? 'text-[var(--color-purple)] bg-[var(--color-bg-lighter)] border-r-2 border-[var(--color-fn-purple)]'
                        : 'text-[var(--color-fg)] hover:text-[var(--color-fg)] hover:bg-[var(--color-bg-lighter)]'
                    }`
                  }
                >
                  <span className="text-base w-5 text-center shrink-0">{item.icon}</span>
                  {sidebarOpen && <span>{item.label}</span>}
                </NavLink>
              ))}
            </>
          )}
        </div>

        {/* User area */}
        <div className="border-t border-[var(--color-current-line)] p-3">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-full bg-[var(--color-bg-lighter)] flex items-center justify-center text-xs font-bold text-[var(--color-purple)] shrink-0">
              {readonly ? '👁' : user?.display_name?.charAt(0).toUpperCase() ?? '?'}
            </div>
            {sidebarOpen && (
              <div className="flex flex-col min-w-0">
                <span className="text-xs text-[var(--color-fg)] whitespace-nowrap truncate">
                  {readonly ? 'Read-only' : user?.display_name ?? 'Not signed in'}
                </span>
                {user && (
                  <div className="flex gap-2">
                    <button
                      onClick={() => navigate('/account')}
                      className="text-[10px] text-[var(--color-comment)] hover:text-[var(--color-purple)] text-left cursor-pointer bg-transparent border-none p-0 transition-colors"
                    >
                      Account
                    </button>
                    <span className="text-[10px] text-[var(--color-comment)]">·</span>
                    <button
                      onClick={logout}
                      className="text-[10px] text-[var(--color-comment)] hover:text-[var(--color-fn-red)] text-left cursor-pointer bg-transparent border-none p-0 transition-colors"
                    >
                      Sign out
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </nav>

      {/* Main content */}
      <main className="flex-1 overflow-auto">
        {/* Top bar */}
        <header className="sticky top-0 z-10 flex items-center h-14 px-6 bg-[var(--color-bg-dark)]/80 backdrop-blur-sm border-b border-[var(--color-current-line)]">
          <div className="flex-1" />
          <div className="flex items-center mr-[25px]">
            <img src={logo} alt="Odin EHS" className="h-9" />
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
