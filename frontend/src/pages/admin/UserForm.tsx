import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { api } from '../../api';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { ConfirmDialog } from '../../components/ConfirmDialog';
import { useEntityMutation } from '../../hooks/useEntityMutation';
import { useUnsavedGuard } from '../../hooks/useUnsavedGuard';
import { useAuth } from '../../context/AuthContext';

interface UserRecord {
  id: number;
  username: string;
  display_name: string;
  role: string;
  is_active: boolean;
  last_login_at?: string;
}

interface UserInput {
  username: string;
  display_name: string;
  password?: string;
  role: string;
}

const roleOptions = [
  { value: 'admin', label: 'Admin' },
  { value: 'user', label: 'User' },
  { value: 'readonly', label: 'Read-only' },
];

const empty: UserInput = {
  username: '',
  display_name: '',
  password: '',
  role: 'user',
};

export default function UserForm() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user: currentUser } = useAuth();
  const isEdit = Boolean(id);
  const isSelf = isEdit && currentUser?.id === Number(id);

  const [form, setForm] = useState<UserInput>(empty);
  const [loadedUser, setLoadedUser] = useState<UserRecord | null>(null);
  const [loading, setLoading] = useState(isEdit);
  const [dirty, setDirty] = useState(false);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  // Password reset (admin resetting another user) state.
  const [resetPassword, setResetPassword] = useState('');
  const [resetConfirm, setResetConfirm] = useState('');
  const [resetError, setResetError] = useState<string | null>(null);
  const [resetSuccess, setResetSuccess] = useState(false);
  const { mutate: pwMutate, loading: pwSaving } = useEntityMutation();

  // Deactivate / reactivate / delete confirmations.
  const [confirm, setConfirm] = useState<null | 'deactivate' | 'reactivate' | 'delete'>(null);
  const { mutate: actionMutate, loading: actionSaving, error: actionError } = useEntityMutation();

  useUnsavedGuard(dirty && !saving);

  useEffect(() => {
    if (!isEdit) return;
    api.get<UserRecord>(`/api/users/${id}`)
      .then(u => {
        setLoadedUser(u);
        setForm({
          username: u.username,
          display_name: u.display_name,
          password: '',
          role: u.role,
        });
      })
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const update = <K extends keyof UserInput>(key: K, value: UserInput[K]) => {
    setForm(prev => ({ ...prev, [key]: value }));
    setDirty(true);
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const body: UserInput = {
      username: form.username.trim(),
      display_name: form.display_name.trim() || form.username.trim(),
      role: form.role,
    };
    if (!isEdit) {
      body.password = form.password ?? '';
    }
    try {
      let nextId: number | string | undefined = id;
      if (isEdit) {
        await mutate('PUT', `/api/users/${id}`, body);
      } else {
        const res = await mutate<UserRecord>('POST', '/api/users', body);
        nextId = res.id;
      }
      setDirty(false);
      if (isEdit) {
        navigate('/admin/users');
      } else {
        navigate(`/admin/users/${nextId}/edit`);
      }
    } catch {
      // saveError is set by the hook
    }
  }

  async function doResetPassword(e: React.FormEvent) {
    e.preventDefault();
    setResetError(null);
    setResetSuccess(false);
    if (resetPassword.length < 6) {
      setResetError('Password must be at least 6 characters');
      return;
    }
    if (resetPassword !== resetConfirm) {
      setResetError('Passwords do not match');
      return;
    }
    try {
      await pwMutate('POST', `/api/users/${id}/password`, { password: resetPassword });
      setResetPassword('');
      setResetConfirm('');
      setResetSuccess(true);
    } catch (err) {
      setResetError(err instanceof Error ? err.message : 'Reset failed');
    }
  }

  async function runAction() {
    if (!id || !confirm) return;
    try {
      if (confirm === 'deactivate') {
        await actionMutate('POST', `/api/users/${id}/deactivate`);
      } else if (confirm === 'reactivate') {
        await actionMutate('POST', `/api/users/${id}/reactivate`);
      } else {
        // No DELETE endpoint for users — deactivate only.
        return;
      }
      setConfirm(null);
      // Reload user data to reflect the new status.
      const u = await api.get<UserRecord>(`/api/users/${id}`);
      setLoadedUser(u);
      setForm(prev => ({ ...prev, role: u.role }));
    } catch {
      // actionError set by the hook
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-12 text-[var(--color-comment)] text-sm">
        Loading…
      </div>
    );
  }

  const title = isEdit ? `Edit ${loadedUser?.display_name ?? 'User'}` : 'New User';
  const active = loadedUser?.is_active ?? true;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate('/admin/users')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Users
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">{title}</h1>
        {isEdit && (
          <span
            className={`text-xs font-medium px-2 py-0.5 rounded-full ${
              active
                ? 'bg-[var(--color-fn-green)]/15 text-[var(--color-fn-green)]'
                : 'bg-[var(--color-current-line)] text-[var(--color-comment)]'
            }`}
          >
            {active ? 'Active' : 'Inactive'}
          </span>
        )}
      </div>

      {saveError && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {saveError}
        </div>
      )}
      {actionError && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {actionError}
        </div>
      )}

      <form onSubmit={submit} className="flex flex-col gap-6 max-w-2xl">
        <SectionCard title="Account">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Username"
              required
              value={form.username}
              onChange={v => update('username', v)}
              disabled={isEdit}
              hint={isEdit ? 'Username cannot be changed.' : undefined}
              autoFocus={!isEdit}
            />
            <FormField
              label="Display Name"
              value={form.display_name}
              onChange={v => update('display_name', v)}
              placeholder="Defaults to username"
            />
            <FormField
              type="select"
              label="Role"
              required
              value={form.role}
              onChange={v => update('role', v)}
              options={roleOptions}
              disabled={isSelf}
              hint={isSelf ? 'You cannot change your own role.' : undefined}
            />
            {!isEdit && (
              <FormField
                type="password"
                label="Initial Password"
                required
                value={form.password ?? ''}
                onChange={v => update('password', v)}
                hint="Minimum 6 characters. User can change after first login."
              />
            )}
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate('/admin/users')}
          saveLabel={isEdit ? 'Save changes' : 'Create user'}
        />
      </form>

      {isEdit && !isSelf && (
        <div className="max-w-2xl mt-6">
          <SectionCard
            title="Reset Password"
            description="Set a new password for this user. They can change it themselves after signing in."
          >
            {resetError && (
              <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
                {resetError}
              </div>
            )}
            {resetSuccess && (
              <div className="rounded-lg bg-[var(--color-fn-green)]/10 border border-[var(--color-fn-green)]/30 text-[var(--color-fn-green)] px-4 py-2.5 mb-4 text-sm">
                Password reset.
              </div>
            )}
            <form onSubmit={doResetPassword} className="flex flex-col gap-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  type="password"
                  label="New Password"
                  required
                  value={resetPassword}
                  onChange={setResetPassword}
                />
                <FormField
                  type="password"
                  label="Confirm Password"
                  required
                  value={resetConfirm}
                  onChange={setResetConfirm}
                />
              </div>
              <div className="flex justify-end">
                <button
                  type="submit"
                  disabled={pwSaving}
                  className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {pwSaving ? 'Resetting...' : 'Reset password'}
                </button>
              </div>
            </form>
          </SectionCard>
        </div>
      )}

      {isEdit && !isSelf && (
        <div className="max-w-2xl mt-6">
          <SectionCard
            title="Account Status"
            description={
              active
                ? 'Deactivating will sign the user out and block future logins until reactivated.'
                : 'Reactivate to allow this user to sign in again.'
            }
          >
            {active ? (
              <button
                type="button"
                onClick={() => setConfirm('deactivate')}
                className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-fn-red)]/50 text-[var(--color-fn-red)] text-sm cursor-pointer hover:bg-[var(--color-fn-red)]/10 transition-colors"
              >
                Deactivate user
              </button>
            ) : (
              <button
                type="button"
                onClick={() => setConfirm('reactivate')}
                className="h-10 px-4 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
              >
                Reactivate user
              </button>
            )}
          </SectionCard>
        </div>
      )}

      {confirm && (
        <ConfirmDialog
          open
          title={
            confirm === 'deactivate' ? 'Deactivate user?' : 'Reactivate user?'
          }
          message={
            confirm === 'deactivate'
              ? 'This signs the user out of all sessions and blocks future logins. You can reactivate later.'
              : 'This allows the user to sign in again.'
          }
          confirmLabel={confirm === 'deactivate' ? 'Deactivate' : 'Reactivate'}
          destructive={confirm === 'deactivate'}
          loading={actionSaving}
          onConfirm={runAction}
          onCancel={() => setConfirm(null)}
        />
      )}
    </div>
  );
}
