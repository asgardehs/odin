import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { api } from '../api';

export default function Account() {
  const { user } = useAuth();

  const [questions, setQuestions] = useState([
    { question: '', answer: '' },
    { question: '', answer: '' },
    { question: '', answer: '' },
  ]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  function updateQuestion(index: number, field: 'question' | 'answer', value: string) {
    setQuestions(prev => prev.map((q, i) => i === index ? { ...q, [field]: value } : q));
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setSuccess('');

    for (let i = 0; i < 3; i++) {
      if (!questions[i].question.trim() || !questions[i].answer.trim()) {
        setError(`Question and answer ${i + 1} are required`);
        return;
      }
    }

    setSaving(true);
    try {
      await api.post('/api/auth/security-questions', {
        questions: questions.map(q => ({
          question: q.question.trim(),
          answer: q.answer.trim(),
        })),
      });
      setSuccess('Security questions saved');
      // Clear answers from form after save — they're hashed server-side.
      setQuestions(prev => prev.map(q => ({ question: q.question, answer: '' })));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-bold text-[var(--color-text-primary)] mb-6">Account</h1>

      {/* User info */}
      <div className="rounded-xl bg-[var(--color-bg-card)] border border-[var(--color-border)] p-5 mb-6 max-w-lg">
        <h2 className="text-lg font-semibold text-[var(--color-accent-light)] mb-3">Profile</h2>
        <div className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
          <span className="text-[var(--color-text-muted)]">Username</span>
          <span className="text-[var(--color-text-primary)]">{user?.username}</span>
          <span className="text-[var(--color-text-muted)]">Display name</span>
          <span className="text-[var(--color-text-primary)]">{user?.display_name}</span>
          <span className="text-[var(--color-text-muted)]">Role</span>
          <span className="text-[var(--color-text-primary)]">{user?.role}</span>
        </div>
      </div>

      {/* Security questions */}
      <div className="rounded-xl bg-[var(--color-bg-card)] border border-[var(--color-border)] p-5 max-w-lg">
        <h2 className="text-lg font-semibold text-[var(--color-accent-light)] mb-1">Security Questions</h2>
        <p className="text-sm text-[var(--color-text-muted)] mb-4">
          Set 3 security questions for self-service password reset. Answers are case-sensitive.
        </p>

        {user?.has_security_questions && !success && (
          <div className="rounded-lg bg-[var(--color-status-ok)]/10 border border-[var(--color-status-ok)]/30 text-[var(--color-status-ok)] px-4 py-2.5 mb-4 text-sm">
            Security questions are configured. Saving new questions will replace the existing ones.
          </div>
        )}

        {error && (
          <div className="rounded-lg bg-[var(--color-status-danger)]/10 border border-[var(--color-status-danger)]/30 text-[var(--color-status-danger)] px-4 py-2.5 mb-4 text-sm">
            {error}
          </div>
        )}

        {success && (
          <div className="rounded-lg bg-[var(--color-status-ok)]/10 border border-[var(--color-status-ok)]/30 text-[var(--color-status-ok)] px-4 py-2.5 mb-4 text-sm">
            {success}
          </div>
        )}

        <form onSubmit={handleSave} className="flex flex-col gap-5">
          {questions.map((q, i) => (
            <div key={i} className="flex flex-col gap-2">
              <label className="text-xs text-[var(--color-text-secondary)]">Question {i + 1}</label>
              <input
                type="text"
                value={q.question}
                onChange={e => updateQuestion(i, 'question', e.target.value)}
                placeholder="e.g. What was the name of your first pet?"
                required
                className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg-primary)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm outline-none focus:border-[var(--color-accent)] transition-colors placeholder:text-[var(--color-text-muted)]"
              />
              <input
                type="text"
                value={q.answer}
                onChange={e => updateQuestion(i, 'answer', e.target.value)}
                placeholder="Answer (case-sensitive)"
                required
                className="w-full h-10 px-3 rounded-lg bg-[var(--color-bg-primary)] border border-[var(--color-border)] text-[var(--color-text-primary)] text-sm outline-none focus:border-[var(--color-accent)] transition-colors placeholder:text-[var(--color-text-muted)]"
              />
            </div>
          ))}

          <button
            type="submit"
            disabled={saving}
            className="h-10 rounded-lg bg-[var(--color-accent)] text-[var(--color-bg-primary)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {saving ? 'Saving...' : 'Save security questions'}
          </button>
        </form>
      </div>
    </div>
  );
}
