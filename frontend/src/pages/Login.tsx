import { useState, useRef } from 'react';
import { useAuth, type User } from '../context/AuthContext';
import { api, setToken } from '../api';
import logo from '../assets/OdinEHSlogo_256.png';

type Mode = 'login' | 'setup';

export default function Login() {
  const { login, enterReadonly } = useAuth();
  const [mode, setMode] = useState<Mode>('login');
  const [username, setUsername] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  // Recovery key modal state.
  const [recoveryKey, setRecoveryKey] = useState<string | null>(null);
  const [setupToken, setSetupToken] = useState<string | null>(null);
  const [setupUser, setSetupUser] = useState<User | null>(null);
  const keyRef = useRef<HTMLDivElement>(null);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login(username, password);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  async function handleSetup(e: React.FormEvent) {
    e.preventDefault();
    setError('');

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }

    setLoading(true);
    try {
      const res = await api.post<{ token: string; user: User; recovery_key: string }>(
        '/api/auth/setup',
        { username, display_name: displayName || username, password, role: 'admin' },
      );
      // Hold the token — don't set it yet. Show recovery key first.
      setSetupToken(res.token);
      setSetupUser(res.user);
      setRecoveryKey(res.recovery_key);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Setup failed');
    } finally {
      setLoading(false);
    }
  }

  function handleRecoveryAcknowledged() {
    if (setupToken && setupUser) {
      setToken(setupToken);
      // Login directly via AuthProvider by re-using the token.
      login(username, password).catch(() => {
        // Token is already set — reload as fallback.
        window.location.reload();
      });
    }
  }

  function handlePrintRecoveryKey() {
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;
    printWindow.document.write(`
      <html>
        <head><title>Odin EHS Recovery Key</title></head>
        <body style="font-family: monospace; padding: 48px; max-width: 600px;">
          <h1 style="font-size: 18px; margin-bottom: 8px;">Odin EHS Recovery Key</h1>
          <p style="font-size: 13px; color: #666; margin-bottom: 24px;">
            Store this key in a secure location. It is the only way to regain
            access if all admin passwords are lost.
          </p>
          <div style="font-size: 20px; letter-spacing: 2px; padding: 16px; border: 2px solid #333; display: inline-block;">
            ${recoveryKey}
          </div>
          <p style="font-size: 11px; color: #999; margin-top: 24px;">
            Generated: ${new Date().toLocaleDateString()}
          </p>
        </body>
      </html>
    `);
    printWindow.document.close();
    printWindow.print();
  }

  function switchMode(next: Mode) {
    setMode(next);
    setError('');
    setUsername('');
    setDisplayName('');
    setPassword('');
    setConfirmPassword('');
  }

  // --- Recovery key modal ---
  if (recoveryKey) {
    return (
      <div className="flex flex-col h-screen bg-[var(--color-bg-primary)]">
        <header className="flex items-center h-24 px-6 mt-6">
          <img src={logo} alt="Odin EHS" className="h-24" />
        </header>

        <div className="flex-1 flex items-center justify-center">
          <div className="w-full max-w-md">
            <div className="rounded-xl bg-[var(--color-bg-card)] border border-[var(--color-border)] p-8">
              <h1 className="text-xl font-semibold text-[var(--color-text-primary)] mb-2">
                Recovery Key
              </h1>
              <p className="text-sm text-[var(--color-text-secondary)] mb-6">
                Save this key somewhere safe. It is the only way to regain access
                if all admin passwords are lost. This key will not be shown again.
              </p>

              <div
                ref={keyRef}
                className="rounded-lg bg-[var(--color-bg-primary)] border border-[var(--color-border)] p-4 text-center font-mono text-lg tracking-widest text-[var(--color-accent-light)] select-all mb-6"
              >
                {recoveryKey}
              </div>

              <div className="flex gap-3">
                <button
                  onClick={handlePrintRecoveryKey}
                  className="flex-1 h-10 rounded-lg bg-[var(--color-bg-hover)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm cursor-pointer hover:border-[var(--color-border-light)] transition-colors"
                >
                  Print
                </button>
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(recoveryKey);
                  }}
                  className="flex-1 h-10 rounded-lg bg-[var(--color-bg-hover)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm cursor-pointer hover:border-[var(--color-border-light)] transition-colors"
                >
                  Copy
                </button>
              </div>

              <button
                onClick={handleRecoveryAcknowledged}
                className="w-full h-10 mt-4 rounded-lg bg-[var(--color-accent)] text-[var(--color-bg-primary)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
              >
                I've saved my recovery key
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // --- Login / Setup form ---
  return (
    <div className="flex flex-col h-screen bg-[var(--color-bg-primary)]">
      {/* Top bar with logo */}
      <header className="flex items-center h-24 px-6 mt-6">
        <img src={logo} alt="Odin EHS" className="h-24" />
      </header>

      {/* Centered form */}
      <div className="flex-1 flex items-center justify-center">
        <div className="w-full max-w-sm">
          <div className="rounded-xl bg-[var(--color-bg-card)] border border-[var(--color-border)] p-8">
            <h1 className="text-xl font-semibold text-[var(--color-text-primary)] mb-6">
              {mode === 'login' ? 'Sign in' : 'Create account'}
            </h1>

            {error && (
              <div className="rounded-lg bg-[var(--color-status-danger)]/10 border border-[var(--color-status-danger)]/30 text-[var(--color-status-danger)] px-4 py-3 mb-4 text-sm">
                {error}
              </div>
            )}

            <form onSubmit={mode === 'login' ? handleLogin : handleSetup} className="flex flex-col gap-4">
              <div>
                <label className="block text-xs text-[var(--color-text-secondary)] mb-1.5">Username</label>
                <input
                  type="text"
                  value={username}
                  onChange={e => setUsername(e.target.value)}
                  required
                  autoFocus
                  className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg-primary)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm outline-none focus:border-[var(--color-accent)] transition-colors"
                />
              </div>

              {mode === 'setup' && (
                <div>
                  <label className="block text-xs text-[var(--color-text-secondary)] mb-1.5">Display name</label>
                  <input
                    type="text"
                    value={displayName}
                    onChange={e => setDisplayName(e.target.value)}
                    placeholder={username || 'Optional'}
                    className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg-primary)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm outline-none focus:border-[var(--color-accent)] transition-colors placeholder:text-[var(--color-text-muted)]"
                  />
                </div>
              )}

              <div>
                <label className="block text-xs text-[var(--color-text-secondary)] mb-1.5">Password</label>
                <input
                  type="password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  required
                  className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg-primary)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm outline-none focus:border-[var(--color-accent)] transition-colors"
                />
              </div>

              {mode === 'setup' && (
                <div>
                  <label className="block text-xs text-[var(--color-text-secondary)] mb-1.5">Confirm password</label>
                  <input
                    type="password"
                    value={confirmPassword}
                    onChange={e => setConfirmPassword(e.target.value)}
                    required
                    className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg-primary)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm outline-none focus:border-[var(--color-accent)] transition-colors"
                  />
                </div>
              )}

              <button
                type="submit"
                disabled={loading}
                className="h-10 mt-2 rounded-lg bg-[var(--color-accent)] text-[var(--color-bg-primary)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading
                  ? (mode === 'login' ? 'Signing in...' : 'Creating account...')
                  : (mode === 'login' ? 'Sign in' : 'Create account')
                }
              </button>
            </form>
          </div>

          {/* Mode toggle */}
          <p className="text-center text-sm text-[var(--color-text-muted)] mt-4">
            {mode === 'login' ? (
              <>
                No account yet?{' '}
                <button
                  onClick={() => switchMode('setup')}
                  className="text-[var(--color-accent)] hover:text-[var(--color-accent-light)] bg-transparent border-none cursor-pointer text-sm p-0 transition-colors"
                >
                  Create new user
                </button>
              </>
            ) : (
              <>
                Already have an account?{' '}
                <button
                  onClick={() => switchMode('login')}
                  className="text-[var(--color-accent)] hover:text-[var(--color-accent-light)] bg-transparent border-none cursor-pointer text-sm p-0 transition-colors"
                >
                  Sign in
                </button>
              </>
            )}
          </p>

          <p className="text-center text-sm text-[var(--color-text-muted)] mt-2">
            <button
              onClick={enterReadonly}
              className="text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] bg-transparent border-none cursor-pointer text-sm p-0 transition-colors"
            >
              Continue as read-only
            </button>
          </p>
        </div>
      </div>
    </div>
  );
}
