import { useState, useRef } from 'react';
import { useAuth, type User } from '../context/AuthContext';
import { api, setToken } from '../api';
import logo from '../assets/OdinEHSlogo_256.png';

type Mode = 'login' | 'setup' | 'forgot' | 'reset';

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

  // Forgot password flow state.
  const [securityQuestions, setSecurityQuestions] = useState<string[]>([]);
  const [answers, setAnswers] = useState(['', '', '']);
  const [newPassword, setNewPassword] = useState('');
  const [resetSuccess, setResetSuccess] = useState(false);

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

  async function handleForgotSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    if (!username.trim()) {
      setError('Username is required');
      return;
    }
    setLoading(true);
    try {
      const res = await api.get<{ questions: string[] }>(
        `/api/auth/security-questions/${encodeURIComponent(username.trim())}`,
      );
      setSecurityQuestions(res.questions);
      setAnswers(['', '', '']);
      setNewPassword('');
      setMode('reset');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load security questions');
    } finally {
      setLoading(false);
    }
  }

  async function handleResetSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    if (newPassword.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }
    setLoading(true);
    try {
      await api.post('/api/auth/reset-password', {
        username: username.trim(),
        answers: answers as [string, string, string],
        new_password: newPassword,
      });
      setResetSuccess(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Password reset failed');
    } finally {
      setLoading(false);
    }
  }

  function switchMode(next: Mode) {
    setMode(next);
    setError('');
    setUsername('');
    setDisplayName('');
    setPassword('');
    setConfirmPassword('');
    setSecurityQuestions([]);
    setAnswers(['', '', '']);
    setNewPassword('');
    setResetSuccess(false);
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
      {/* Top bar with logo + read-only */}
      <header className="flex items-center justify-between h-24 px-6 mt-6">
        <img src={logo} alt="Odin EHS" className="h-24" />
        <button
          onClick={enterReadonly}
          className="h-9 px-4 rounded-lg bg-[var(--color-bg-card)] border border-[var(--color-border)] text-[var(--color-text-secondary)] text-sm cursor-pointer hover:border-[var(--color-border-light)] hover:text-[var(--color-text-primary)] transition-colors"
        >
          Read-only mode
        </button>
      </header>

      {/* Centered form */}
      <div className="flex-1 flex items-center justify-center">
        <div className="w-full max-w-sm">
          <div className="rounded-xl bg-[var(--color-bg-card)] border border-[var(--color-border)] p-8">
            <h1 className="text-xl font-semibold text-[var(--color-text-primary)] mb-6">
              {mode === 'login' && 'Sign in'}
              {mode === 'setup' && 'Create account'}
              {mode === 'forgot' && 'Forgot password'}
              {mode === 'reset' && 'Reset password'}
            </h1>

            {error && (
              <div className="rounded-lg bg-[var(--color-status-danger)]/10 border border-[var(--color-status-danger)]/30 text-[var(--color-status-danger)] px-4 py-3 mb-4 text-sm">
                {error}
              </div>
            )}

            {/* Reset success message */}
            {resetSuccess && (
              <div>
                <div className="rounded-lg bg-[var(--color-status-ok)]/10 border border-[var(--color-status-ok)]/30 text-[var(--color-status-ok)] px-4 py-3 mb-4 text-sm">
                  Password reset successfully.
                </div>
                <button
                  onClick={() => switchMode('login')}
                  className="w-full h-10 rounded-lg bg-[var(--color-accent)] text-[var(--color-bg-primary)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
                >
                  Back to sign in
                </button>
              </div>
            )}

            {/* Login form */}
            {mode === 'login' && (
              <form onSubmit={handleLogin} className="flex flex-col gap-4">
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
                <button
                  type="submit"
                  disabled={loading}
                  className="h-10 mt-2 rounded-lg bg-[var(--color-accent)] text-[var(--color-bg-primary)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? 'Signing in...' : 'Sign in'}
                </button>
              </form>
            )}

            {/* Setup form */}
            {mode === 'setup' && (
              <form onSubmit={handleSetup} className="flex flex-col gap-4">
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
                <button
                  type="submit"
                  disabled={loading}
                  className="h-10 mt-2 rounded-lg bg-[var(--color-accent)] text-[var(--color-bg-primary)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? 'Creating account...' : 'Create account'}
                </button>
              </form>
            )}

            {/* Forgot password — enter username */}
            {mode === 'forgot' && (
              <form onSubmit={handleForgotSubmit} className="flex flex-col gap-4">
                <p className="text-sm text-[var(--color-text-secondary)] -mt-2 mb-1">
                  Enter your username to retrieve your security questions.
                </p>
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
                <button
                  type="submit"
                  disabled={loading}
                  className="h-10 mt-2 rounded-lg bg-[var(--color-accent)] text-[var(--color-bg-primary)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? 'Loading...' : 'Continue'}
                </button>
              </form>
            )}

            {/* Reset password — answer questions + new password */}
            {mode === 'reset' && !resetSuccess && (
              <form onSubmit={handleResetSubmit} className="flex flex-col gap-4">
                <p className="text-sm text-[var(--color-text-secondary)] -mt-2 mb-1">
                  Answer your security questions. Answers are case-sensitive.
                </p>
                {securityQuestions.map((q, i) => (
                  <div key={i}>
                    <label className="block text-xs text-[var(--color-text-secondary)] mb-1.5">{q}</label>
                    <input
                      type="text"
                      value={answers[i]}
                      onChange={e => setAnswers(prev => prev.map((a, j) => j === i ? e.target.value : a))}
                      required
                      autoFocus={i === 0}
                      className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg-primary)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm outline-none focus:border-[var(--color-accent)] transition-colors"
                    />
                  </div>
                ))}
                <div>
                  <label className="block text-xs text-[var(--color-text-secondary)] mb-1.5">New password</label>
                  <input
                    type="password"
                    value={newPassword}
                    onChange={e => setNewPassword(e.target.value)}
                    required
                    className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg-primary)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm outline-none focus:border-[var(--color-accent)] transition-colors"
                  />
                </div>
                <button
                  type="submit"
                  disabled={loading}
                  className="h-10 mt-2 rounded-lg bg-[var(--color-accent)] text-[var(--color-bg-primary)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? 'Resetting...' : 'Reset password'}
                </button>
              </form>
            )}
          </div>

          {/* Mode toggle */}
          <div className="text-center text-sm text-[var(--color-text-muted)] mt-4 flex flex-col gap-2">
            {mode === 'login' && (
              <>
                <p>
                  No account yet?{' '}
                  <button
                    onClick={() => switchMode('setup')}
                    className="text-[var(--color-accent)] hover:text-[var(--color-accent-light)] bg-transparent border-none cursor-pointer text-sm p-0 transition-colors"
                  >
                    Create new user
                  </button>
                </p>
                <p>
                  <button
                    onClick={() => switchMode('forgot')}
                    className="text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] bg-transparent border-none cursor-pointer text-sm p-0 transition-colors"
                  >
                    Forgot password?
                  </button>
                </p>
              </>
            )}
            {(mode === 'setup' || mode === 'forgot' || mode === 'reset') && (
              <p>
                <button
                  onClick={() => switchMode('login')}
                  className="text-[var(--color-accent)] hover:text-[var(--color-accent-light)] bg-transparent border-none cursor-pointer text-sm p-0 transition-colors"
                >
                  Back to sign in
                </button>
              </p>
            )}
          </div>

        </div>
      </div>
    </div>
  );
}
