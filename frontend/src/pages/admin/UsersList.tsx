import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router';
import { api } from '../../api';
import { StatusBadge } from '../../components/StatusBadge';
import { formatTimestamp } from '../../utils/date';

interface AdminUser {
  id: number;
  username: string;
  display_name: string;
  role: string;
  is_active: boolean;
  has_security_questions: boolean;
  created_at: string;
  updated_at: string;
  last_login_at?: string;
}

export default function UsersList() {
  const navigate = useNavigate();
  const [users, setUsers] = useState<AdminUser[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.get<AdminUser[]>('/api/users')
      .then(setUsers)
      .catch(e => setError(e instanceof Error ? e.message : 'Failed to load users'));
  }, []);

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">Users</h1>
        <button
          type="button"
          onClick={() => navigate('/admin/users/new')}
          className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
        >
          + New User
        </button>
      </div>

      {error && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {error}
        </div>
      )}

      <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--color-current-line)] bg-[var(--color-bg-dark)]/40">
              <th className="text-left px-4 py-3 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Username</th>
              <th className="text-left px-4 py-3 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Display Name</th>
              <th className="text-left px-4 py-3 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Role</th>
              <th className="text-left px-4 py-3 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Status</th>
              <th className="text-left px-4 py-3 font-semibold text-xs uppercase tracking-wider text-[var(--color-comment)]">Last Login</th>
            </tr>
          </thead>
          <tbody>
            {users === null && (
              <tr><td colSpan={5} className="px-4 py-6 text-center text-[var(--color-comment)]">Loading...</td></tr>
            )}
            {users && users.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-6 text-center text-[var(--color-comment)]">No users</td></tr>
            )}
            {users && users.map(u => (
              <tr
                key={u.id}
                onClick={() => navigate(`/admin/users/${u.id}/edit`)}
                className="border-b border-[var(--color-current-line)] last:border-b-0 hover:bg-[var(--color-bg-lighter)] cursor-pointer transition-colors"
              >
                <td className="px-4 py-3 text-[var(--color-fg)]">{u.username}</td>
                <td className="px-4 py-3 text-[var(--color-fg)]">{u.display_name}</td>
                <td className="px-4 py-3"><StatusBadge status={u.role} /></td>
                <td className="px-4 py-3"><StatusBadge status={u.is_active ? 'active' : 'inactive'} /></td>
                <td className="px-4 py-3 text-[var(--color-comment)]">{u.last_login_at ? formatTimestamp(u.last_login_at) : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
