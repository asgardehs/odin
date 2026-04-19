interface FormActionsProps {
  saving?: boolean;
  onCancel?: () => void;
  onSaveAndNew?: () => void;
  saveLabel?: string;
  cancelLabel?: string;
  destructive?: boolean;
}

export function FormActions({
  saving,
  onCancel,
  onSaveAndNew,
  saveLabel = 'Save',
  cancelLabel = 'Cancel',
  destructive,
}: FormActionsProps) {
  const saveColor = destructive
    ? 'bg-[var(--color-fn-red)]'
    : 'bg-[var(--color-fn-purple)]';

  return (
    <div className="flex flex-wrap items-center justify-end gap-3 pt-4 border-t border-[var(--color-current-line)]">
      {onCancel && (
        <button
          type="button"
          onClick={onCancel}
          disabled={saving}
          className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {cancelLabel}
        </button>
      )}
      {onSaveAndNew && (
        <button
          type="button"
          onClick={onSaveAndNew}
          disabled={saving}
          className="h-10 px-4 rounded-lg bg-[var(--color-bg-lighter)] border border-[var(--color-current-line)] text-[var(--color-fg)] text-sm cursor-pointer hover:border-[var(--color-selection)] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {saving ? 'Saving...' : 'Save and add another'}
        </button>
      )}
      <button
        type="submit"
        disabled={saving}
        className={`h-10 px-6 rounded-lg ${saveColor} text-[var(--color-bg)] font-semibold text-sm cursor-pointer border-none hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed`}
      >
        {saving ? 'Saving...' : saveLabel}
      </button>
    </div>
  );
}
