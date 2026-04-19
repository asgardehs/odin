import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api } from '../api';

export default function Account() {
  const { user } = useAuth();
  const isAdmin = user?.role === 'admin';

  // --- Security questions ---
  const [questions, setQuestions] = useState([
    { question: '', answer: '' },
    { question: '', answer: '' },
    { question: '', answer: '' },
  ]);
  const [sqSaving, setSqSaving] = useState(false);
  const [sqError, setSqError] = useState('');
  const [sqSuccess, setSqSuccess] = useState('');

  function updateQuestion(index: number, field: 'question' | 'answer', value: string) {
    setQuestions(prev => prev.map((q, i) => i === index ? { ...q, [field]: value } : q));
  }

  async function handleSaveQuestions(e: React.FormEvent) {
    e.preventDefault();
    setSqError('');
    setSqSuccess('');

    for (let i = 0; i < 3; i++) {
      if (!questions[i].question.trim() || !questions[i].answer.trim()) {
        setSqError(`Question and answer ${i + 1} are required`);
        return;
      }
    }

    setSqSaving(true);
    try {
      await api.post('/api/auth/security-questions', {
        questions: questions.map(q => ({
          question: q.question.trim(),
          answer: q.answer.trim(),
        })),
      });
      setSqSuccess('Security questions saved');
      setQuestions(prev => prev.map(q => ({ question: q.question, answer: '' })));
    } catch (err) {
      setSqError(err instanceof Error ? err.message : 'Failed to save');
    } finally {
      setSqSaving(false);
    }
  }

  // --- Change password ---
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [pwSaving, setPwSaving] = useState(false);
  const [pwError, setPwError] = useState('');
  const [pwSuccess, setPwSuccess] = useState('');

  async function handleChangePassword(e: React.FormEvent) {
    e.preventDefault();
    setPwError('');
    setPwSuccess('');
    if (!user) return;
    if (newPassword.length < 6) {
      setPwError('Password must be at least 6 characters');
      return;
    }
    if (newPassword !== confirmPassword) {
      setPwError('Passwords do not match');
      return;
    }
    setPwSaving(true);
    try {
      await api.post(`/api/users/${user.id}/password`, { password: newPassword });
      setPwSuccess('Password changed');
      setNewPassword('');
      setConfirmPassword('');
    } catch (err) {
      setPwError(err instanceof Error ? err.message : 'Failed to change password');
    } finally {
      setPwSaving(false);
    }
  }

  // --- Regenerate recovery key ---
  const [rkGenerating, setRkGenerating] = useState(false);
  const [rkError, setRkError] = useState('');
  const [rkNewKey, setRkNewKey] = useState<string | null>(null);
  const [rkConfirming, setRkConfirming] = useState(false);

  async function handleRegenerateRecoveryKey() {
    setRkError('');
    setRkGenerating(true);
    try {
      const res = await api.post<{ recovery_key: string }>(
        '/api/auth/regenerate-recovery-key',
      );
      setRkNewKey(res.recovery_key);
      setRkConfirming(false);
    } catch (err) {
      setRkError(err instanceof Error ? err.message : 'Failed to regenerate key');
    } finally {
      setRkGenerating(false);
    }
  }

  function handlePrintRecoveryKey() {
    if (!rkNewKey) return;
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;
    printWindow.document.write(`
      <html>
        <head><title>Odin EHS Recovery Key</title></head>
        <body style="font-family: monospace; padding: 48px; max-width: 600px;">
          <h1 style="font-size: 18px; margin-bottom: 8px;">Odin EHS Recovery Key</h1>
          <p style="font-size: 13px; color: #666; margin-bottom: 24px;">
            Store this key in a secure location. It is the only way to regain
            access if all admin passwords are lost. This replaces any prior key.
          </p>
          <div style="font-size: 20px; letter-spacing: 2px; padding: 16px; border: 2px solid #333; display: inline-block;">
            ${rkNewKey}
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

  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-fg)] mb-6">Account</h1>

      {/* Profile */}
      <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5 mb-6 max-w-lg">
        <h2 className="text-lg font-semibold text-[var(--color-purple)] mb-3">Profile</h2>
        <div className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
          <span className="text-[var(--color-comment)]">Username</span>
          <span className="text-[var(--color-fg)]">{user?.username}</span>
          <span className="text-[var(--color-comment)]">Display name</span>
          <span className="text-[var(--color-fg)]">{user?.display_name}</span>
          <span className="text-[var(--color-comment)]">Role</span>
          <span className="text-[var(--color-fg)]">{user?.role}</span>
        </div>
      </div>

      {/* Security questions */}
      <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5 mb-6 max-w-lg">
        <h2 className="text-lg font-semibold text-[var(--color-purple)] mb-1">Security Questions</h2>
        <p className="text-sm text-[var(--color-comment)] mb-4">
          Set 3 security questions for self-service password reset. Answers are case-sensitive.
        </p>

        {user?.has_security_questions && !sqSuccess && (
          <div className="rounded-lg bg-[var(--color-fn-green)]/10 border border-[var(--color-fn-green)]/30 text-[var(--color-fn-green)] px-4 py-2.5 mb-4 text-sm">
            Security questions are configured. Saving new questions will replace the existing ones.
          </div>
        )}

        {sqError && (
          <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
            {sqError}
          </div>
        )}

        {sqSuccess && (
          <div className="rounded-lg bg-[var(--color-fn-green)]/10 border border-[var(--color-fn-green)]/30 text-[var(--color-fn-green)] px-4 py-2.5 mb-4 text-sm">
            {sqSuccess}
          </div>
        )}

        <form onSubmit={handleSaveQuestions} className="flex flex-col gap-5">
          {questions.map((q, i) => (
            <div key={i} className="flex flex-col gap-2">
              <label className="text-xs text-[var(--color-fg)]">Question {i + 1}</label>
              <input
                type="text"
                value={q.question}
                onChange={e => updateQuestion(i, 'question', e.target.value)}
                placeholder="e.g. What was the name of your first pet?"
                required
                className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm outline-none focus:border-[var(--color-fn-purple)] transition-colors placeholder:text-[var(--color-comment)]"
              />
              <input
                type="text"
                value={q.answer}
                onChange={e => updateQuestion(i, 'answer', e.target.value)}
                placeholder="Answer (case-sensitive)"
                required
                className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm outline-none focus:border-[var(--color-fn-purple)] transition-colors placeholder:text-[var(--color-comment)]"
              />
            </div>
          ))}

          <button
            type="submit"
            disabled={sqSaving}
            className="h-10 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {sqSaving ? 'Saving...' : 'Save security questions'}
          </button>
        </form>
      </div>

      {/* Change password — admin only */}
      {isAdmin && (
        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5 mb-6 max-w-lg">
          <h2 className="text-lg font-semibold text-[var(--color-purple)] mb-1">Change Password</h2>
          <p className="text-sm text-[var(--color-comment)] mb-4">
            Minimum 6 characters. Changing your password does not sign you out on this device.
          </p>

          {pwError && (
            <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
              {pwError}
            </div>
          )}

          {pwSuccess && (
            <div className="rounded-lg bg-[var(--color-fn-green)]/10 border border-[var(--color-fn-green)]/30 text-[var(--color-fn-green)] px-4 py-2.5 mb-4 text-sm">
              {pwSuccess}
            </div>
          )}

          <form onSubmit={handleChangePassword} className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <label className="text-xs text-[var(--color-fg)]">New password</label>
              <input
                type="password"
                value={newPassword}
                onChange={e => setNewPassword(e.target.value)}
                required
                className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm outline-none focus:border-[var(--color-fn-purple)] transition-colors"
              />
            </div>
            <div className="flex flex-col gap-2">
              <label className="text-xs text-[var(--color-fg)]">Confirm new password</label>
              <input
                type="password"
                value={confirmPassword}
                onChange={e => setConfirmPassword(e.target.value)}
                required
                className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm outline-none focus:border-[var(--color-fn-purple)] transition-colors"
              />
            </div>
            <button
              type="submit"
              disabled={pwSaving}
              className="h-10 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {pwSaving ? 'Changing...' : 'Change password'}
            </button>
          </form>
        </div>
      )}

      {/* Recovery key — admin only */}
      {isAdmin && (
        <div className="rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] p-5 max-w-lg">
          <h2 className="text-lg font-semibold text-[var(--color-purple)] mb-1">Recovery Key</h2>
          <p className="text-sm text-[var(--color-comment)] mb-4">
            The recovery key is the last-resort way to regain access if all admin passwords
            are lost. Regenerating produces a new key and invalidates the previous one.
          </p>

          {rkError && (
            <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-2.5 mb-4 text-sm">
              {rkError}
            </div>
          )}

          {rkNewKey ? (
            <>
              <div className="rounded-lg bg-[var(--color-fn-yellow)]/10 border border-[var(--color-fn-yellow)]/30 text-[var(--color-fn-yellow)] px-4 py-2.5 mb-4 text-sm">
                Save this key now — it will not be shown again. The previous key is invalid.
              </div>
              <div className="rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] p-4 text-center font-mono text-base tracking-widest text-[var(--color-purple)] select-all mb-4 break-all">
                {rkNewKey}
              </div>
              <div className="flex gap-3">
                <button
                  onClick={handlePrintRecoveryKey}
                  className="flex-1 h-10 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors"
                >
                  Print
                </button>
                <button
                  onClick={() => navigator.clipboard.writeText(rkNewKey)}
                  className="flex-1 h-10 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors"
                >
                  Copy
                </button>
                <button
                  onClick={() => setRkNewKey(null)}
                  className="flex-1 h-10 rounded-lg bg-[var(--color-fn-purple)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity"
                >
                  Done
                </button>
              </div>
            </>
          ) : rkConfirming ? (
            <div className="flex flex-col gap-3">
              <div className="rounded-lg bg-[var(--color-fn-yellow)]/10 border border-[var(--color-fn-yellow)]/30 text-[var(--color-fn-yellow)] px-4 py-2.5 text-sm">
                This will invalidate the current recovery key. Continue?
              </div>
              <div className="flex gap-3">
                <button
                  onClick={() => setRkConfirming(false)}
                  disabled={rkGenerating}
                  className="flex-1 h-10 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  onClick={handleRegenerateRecoveryKey}
                  disabled={rkGenerating}
                  className="flex-1 h-10 rounded-lg bg-[var(--color-fn-red)] text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {rkGenerating ? 'Generating...' : 'Yes, regenerate'}
                </button>
              </div>
            </div>
          ) : (
            <button
              onClick={() => setRkConfirming(true)}
              className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors"
            >
              Regenerate recovery key
            </button>
          )}
        </div>
      )}
    </div>
  );
}
