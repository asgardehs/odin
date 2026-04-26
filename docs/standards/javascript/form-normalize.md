# Form Normalization on Submit

Every module form defines a `normalizeForSubmit(form)` function that
runs in the submit handler — never on change. The function trims
strings, converts blank → null for nullable fields, and produces the
exact JSON shape the backend expects.

```tsx
function nullIfBlank(s: string | null | undefined) {
    return s == null || s.trim() === '' ? null : s.trim();
}

function normalizeForSubmit(form: EstablishmentInput): EstablishmentInput {
    return {
        name: form.name.trim(),                                  // required
        street_address: form.street_address.trim(),              // required
        industry_description: nullIfBlank(form.industry_description),
        naics_code: nullIfBlank(form.naics_code),
        peak_employees: form.peak_employees == null ? null : form.peak_employees,
        ein: nullIfBlank(form.ein),
        size_code: nullIfBlank(form.size_code),
        // ...
    };
}

async function submit(e: React.FormEvent) {
    e.preventDefault();
    const body = normalizeForSubmit(form);
    await mutate('POST', '/api/establishments', body);
}
```

## Rules

- **Every form has its own `normalizeForSubmit`.** No generic
  utility tries to handle all forms; per-form normalization keeps
  the function readable and the per-field rules explicit.
- **Required fields trim only.** Their values are guaranteed
  non-empty by the form's validation; trimming is enough.
- **Optional fields go through `nullIfBlank`.** Empty strings
  don't survive the trip to the API — they become `null`.
- **Numbers stay as-is.** `peak_employees == null ? null :
  peak_employees` preserves the number / null distinction without
  trying to coerce.

## Why on submit, not on change

- **Typing feels responsive.** Trimming or normalizing on every
  keystroke means the user can't enter a space mid-word without it
  vanishing. Inputs should hold raw text exactly as typed.
- **Single boundary between UI and API.** Form state is for the
  user; the normalize function is the one place that translates UI
  state into wire shape. Every form follows this contract, so the
  shape conversion is predictable across modules.
- **Reduces test surface.** The submit handler is the only place
  that needs to be tested for shape correctness; on-change handlers
  stay simple.

## Why blank → null specifically

The Go backend uses pointer-to-optional fields (`*string`, `*int`)
for nullable columns. An empty string and a NULL are different
values:

- `*string` field set to `""` → persists as empty string in the DB.
- `*string` field set to `nil` → persists as NULL in the DB.

For nullable columns, NULL is the correct "absent" representation.
Without `nullIfBlank`, every "the user didn't fill this in" case
would become a row with `column = ''` instead of `column IS NULL`,
which fights downstream queries (`WHERE col IS NULL` would miss
those rows).

See also `backend/repository.md` for the pointer-to-optional
pattern.

## Reference

- Examples: `frontend/src/pages/modules/EstablishmentForm.tsx`,
  `IncidentForm.tsx`, every other `*Form.tsx` in `pages/modules/`.
