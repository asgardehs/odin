import type { ReactNode } from 'react';

const inputClass =
  'w-full h-10 px-3 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] ' +
  'text-[var(--color-fg)] text-sm outline-none focus:border-[var(--color-fn-purple)] ' +
  'transition-colors placeholder:text-[var(--color-comment)] ' +
  'disabled:opacity-50 disabled:cursor-not-allowed';

const textareaClass =
  'w-full px-3 py-2 rounded-lg bg-[var(--color-bg)] border border-[var(--color-current-line)] ' +
  'text-[var(--color-fg)] text-sm outline-none focus:border-[var(--color-fn-purple)] ' +
  'transition-colors placeholder:text-[var(--color-comment)] resize-y ' +
  'disabled:opacity-50 disabled:cursor-not-allowed';

interface BaseProps {
  label: string;
  required?: boolean;
  error?: string;
  hint?: string;
  disabled?: boolean;
}

interface TextFieldProps extends BaseProps {
  type?: 'text' | 'email' | 'password' | 'number' | 'date' | 'tel' | 'url';
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  autoFocus?: boolean;
}

interface TextareaFieldProps extends BaseProps {
  type: 'textarea';
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  rows?: number;
}

interface SelectFieldProps extends BaseProps {
  type: 'select';
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
  placeholder?: string;
}

interface CheckboxFieldProps extends BaseProps {
  type: 'checkbox';
  value: boolean;
  onChange: (value: boolean) => void;
}

interface CustomFieldProps extends BaseProps {
  type: 'custom';
  children: ReactNode;
}

type FormFieldProps =
  | TextFieldProps
  | TextareaFieldProps
  | SelectFieldProps
  | CheckboxFieldProps
  | CustomFieldProps;

export function FormField(props: FormFieldProps) {
  const { label, required, error, hint, disabled } = props;

  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-xs text-[var(--color-fg)]">
        {label}
        {required && <span className="text-[var(--color-fn-red)] ml-0.5">*</span>}
      </label>

      {props.type === 'textarea' && (
        <textarea
          value={props.value}
          onChange={e => props.onChange(e.target.value)}
          placeholder={props.placeholder}
          required={required}
          disabled={disabled}
          rows={props.rows ?? 3}
          className={textareaClass}
        />
      )}

      {props.type === 'select' && (
        <select
          value={props.value}
          onChange={e => props.onChange(e.target.value)}
          required={required}
          disabled={disabled}
          className={inputClass + ' cursor-pointer'}
        >
          {props.placeholder !== undefined && (
            <option value="">{props.placeholder}</option>
          )}
          {props.options.map(opt => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
      )}

      {props.type === 'checkbox' && (
        <div className="flex items-center gap-2 h-10">
          <input
            type="checkbox"
            checked={props.value}
            onChange={e => props.onChange(e.target.checked)}
            disabled={disabled}
            className="h-4 w-4 rounded accent-[var(--color-fn-purple)] cursor-pointer disabled:cursor-not-allowed"
          />
          <span className="text-sm text-[var(--color-fg)]">{hint ?? 'Enabled'}</span>
        </div>
      )}

      {props.type === 'custom' && props.children}

      {(props.type === undefined ||
        props.type === 'text' ||
        props.type === 'email' ||
        props.type === 'password' ||
        props.type === 'number' ||
        props.type === 'date' ||
        props.type === 'tel' ||
        props.type === 'url') && (
        <input
          type={props.type ?? 'text'}
          value={props.value}
          onChange={e => props.onChange(e.target.value)}
          placeholder={props.placeholder}
          required={required}
          disabled={disabled}
          autoFocus={props.autoFocus}
          className={inputClass}
        />
      )}

      {hint && props.type !== 'checkbox' && (
        <p className="text-xs text-[var(--color-comment)]">{hint}</p>
      )}
      {error && (
        <p className="text-xs text-[var(--color-fn-red)]">{error}</p>
      )}
    </div>
  );
}
