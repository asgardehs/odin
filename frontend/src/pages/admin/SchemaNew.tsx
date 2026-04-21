import { useState } from 'react';
import { useNavigate } from 'react-router';
import { SectionCard } from '../../components/forms/SectionCard';
import { FormField } from '../../components/forms/FormField';
import { FormActions } from '../../components/forms/FormActions';
import { useEntityMutation } from '../../hooks/useEntityMutation';

/**
 * Normalize a human display name into a legal metadata name matching
 * the backend regex ^[a-z][a-z0-9_]{1,58}$. Lowercases, replaces any
 * non-alphanumeric sequence with a single underscore, drops a leading
 * digit if present, trims trailing underscores.
 */
function toSnakeCase(input: string): string {
  const lowered = input.toLowerCase();
  // Replace non-alphanumeric runs with a single underscore.
  let s = lowered.replace(/[^a-z0-9]+/g, '_');
  // Collapse repeated underscores.
  s = s.replace(/_+/g, '_');
  // Trim leading/trailing underscores.
  s = s.replace(/^_+|_+$/g, '');
  // Ensure first char is a letter.
  if (s.length > 0 && !/^[a-z]/.test(s)) {
    s = 't_' + s;
  }
  // Clamp to 59 chars (the regex allows 2-59 after the leading letter).
  if (s.length > 59) s = s.slice(0, 59);
  return s;
}

const ICON_CHOICES = ['📋', '📦', '🔧', '🧾', '📊', '📝', '⚙️', '📌', '🗂️', '📁', '🔖', '⭐'];

export default function SchemaNew() {
  const navigate = useNavigate();
  const [displayName, setDisplayName] = useState('');
  const [name, setName] = useState('');
  const [nameTouched, setNameTouched] = useState(false);
  const [description, setDescription] = useState('');
  const [icon, setIcon] = useState<string>('📋');
  const [validationError, setValidationError] = useState<string | null>(null);
  const { mutate, loading: saving, error: saveError } = useEntityMutation();

  function onDisplayNameChange(v: string) {
    setDisplayName(v);
    if (!nameTouched) setName(toSnakeCase(v));
    setValidationError(null);
  }

  function onNameChange(v: string) {
    setName(v);
    setNameTouched(true);
    setValidationError(null);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!displayName.trim()) {
      setValidationError('Display name is required.');
      return;
    }
    if (!name.trim()) {
      setValidationError('Name is required.');
      return;
    }
    try {
      const res = await mutate<{ id: number }>('POST', '/api/schema/tables', {
        name: name.trim(),
        display_name: displayName.trim(),
        description: description.trim() || null,
        icon: icon || null,
      });
      navigate(`/admin/schema/${res.id}`);
    } catch {
      // saveError surfaces
    }
  }

  const errorMessage = validationError ?? saveError;

  return (
    <div>
      <div className="flex items-center gap-4 mb-6">
        <button
          type="button"
          onClick={() => navigate('/admin/schema')}
          className="text-[var(--color-comment)] hover:text-[var(--color-fg)] text-sm transition-colors"
        >
          ← Custom Tables
        </button>
        <h1 className="text-2xl font-bold text-[var(--color-fg)]">New custom table</h1>
      </div>

      {errorMessage && (
        <div className="rounded-lg bg-[var(--color-fn-red)]/10 border border-[var(--color-fn-red)]/30 text-[var(--color-fn-red)] px-4 py-3 mb-4 text-sm">
          {errorMessage}
        </div>
      )}

      <form onSubmit={submit} className="flex flex-col gap-6 max-w-3xl">
        <SectionCard
          title="Identity"
          description="Pick a human label. The physical SQLite name is derived from it and prefixed with cx_ at creation time."
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              label="Display Name"
              required
              value={displayName}
              onChange={onDisplayNameChange}
              placeholder="e.g. Equipment Checkouts"
              autoFocus
            />
            <FormField
              label="Name"
              required
              value={name}
              onChange={onNameChange}
              placeholder="e.g. equipment_checkouts"
              hint={`Physical table will be cx_${name || 'name'}. Lowercase letters, digits, underscores; 2–59 chars.`}
            />
            <div className="md:col-span-2">
              <FormField
                type="textarea"
                label="Description"
                value={description}
                onChange={setDescription}
                rows={2}
                placeholder="What does this table track? Shown to users on the list page."
              />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Icon" description="Shown in the sidebar when the Custom Tables group is enabled (Phase 4).">
          <div className="flex flex-wrap gap-2">
            {ICON_CHOICES.map(opt => (
              <button
                type="button"
                key={opt}
                onClick={() => setIcon(opt)}
                className={`w-10 h-10 rounded-lg border text-lg cursor-pointer transition-colors ${
                  icon === opt
                    ? 'bg-[var(--color-fn-purple)]/15 border-[var(--color-fn-purple)]'
                    : 'bg-[var(--color-bg)] border-[var(--color-current-line)] hover:border-[var(--color-selection)]'
                }`}
              >
                {opt}
              </button>
            ))}
          </div>
        </SectionCard>

        <FormActions
          saving={saving}
          onCancel={() => navigate('/admin/schema')}
          saveLabel="Create table"
        />
      </form>
    </div>
  );
}
