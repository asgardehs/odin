import { useApi } from '../../hooks/useApi';
import { FormField } from './FormField';

// LookupDropdown — data-aware wrapper around FormField's select.
// Fetches rows from /api/lookup/{table} (server-side whitelisted, see
// internal/repository/lookup.go) and feeds them into the standard
// select UI.
//
// Response shape from the backend is uniform: each row has code, name,
// and description. We bind `code` to the value, `name` to the label,
// and surface `description` under the field as a hint when nothing is
// manually specified — that's the pedagogical payload (e.g. CFR
// citation, category) in the dropdown UX without crowding the options.

interface LookupItem {
  code: string;
  name: string;
  description: string;
}

interface LookupResponse {
  items: LookupItem[];
  total: number;
}

interface LookupDropdownProps {
  table: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  required?: boolean;
  error?: string;
  /**
   * Static hint. When omitted, the selected row's `description`
   * (from the API) is shown instead. Pass '' to suppress both.
   */
  hint?: string;
  disabled?: boolean;
}

export function LookupDropdown({
  table,
  label,
  value,
  onChange,
  placeholder,
  required,
  error,
  hint,
  disabled,
}: LookupDropdownProps) {
  const { data, loading, error: fetchError } = useApi<LookupResponse>(`/api/lookup/${table}`);

  const options = (data?.items ?? []).map(item => ({
    value: item.code,
    label: item.name,
  }));

  const selectedItem = data?.items.find(item => item.code === value);
  // Caller's hint takes precedence; fall back to the selected row's
  // description so users see regulatory context inline.
  const effectiveHint =
    hint !== undefined
      ? hint
      : selectedItem?.description || undefined;

  const effectivePlaceholder = loading
    ? 'Loading…'
    : (placeholder ?? 'Select one');

  const effectiveError = fetchError
    ? `Failed to load options (${fetchError})`
    : error;

  return (
    <FormField
      type="select"
      label={label}
      value={value}
      onChange={onChange}
      options={options}
      placeholder={effectivePlaceholder}
      required={required}
      error={effectiveError}
      hint={effectiveHint}
      disabled={disabled || loading}
    />
  );
}
