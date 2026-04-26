# LookupDropdown — Data-Aware Wrapper

`LookupDropdown` is the form control for any field whose options come
from a server-side lookup table. It fetches `/api/lookup/{table}`,
transforms the rows into `{value, label}` options, and delegates the
actual rendering to `FormField type="select"`.

```tsx
<LookupDropdown
    table="ita_establishment_sizes"
    label="Establishment Size"
    value={form.size_code ?? ''}
    onChange={v => update('size_code', v)}
    placeholder="Select size category"
/>
```

## Rules

- **Use it for any field backed by a whitelisted lookup table.** The
  whitelist is server-side in `internal/repository/lookup.go`; if
  the table isn't there, add it to the whitelist before adding a
  LookupDropdown.
- **Don't re-implement what FormField already does.** LookupDropdown
  delegates rendering. The styling, focus, error display, and
  Nótt & Dagr theming all come from FormField.
- **Hint-layering:** caller's `hint` prop takes precedence; when
  omitted, the selected row's `description` from the API surfaces
  as the hint. This is how regulatory context (CFR citations,
  category descriptions) reaches the user without crowding the
  option list.
- **Loading + error states are handled.** While fetching, the field
  shows a "Loading…" placeholder and is disabled. On fetch error,
  the field shows the error inline via FormField's `error` slot.
  Callers don't need to manage these.

## Why a thin wrapper instead of teaching FormField about HTTP

- **Separation of concerns.** FormField is a pure UI primitive: takes
  `value`, `onChange`, and options. Mixing data-fetching into it
  would couple the input layer to the API layer. Two responsibilities
  in one component.
- **Composable for future data-aware controls.** When odin gets an
  entity-autocomplete for free-text-with-suggestions (against
  establishments, employees, etc.), it follows the same pattern:
  data-aware wrapper around FormField (or a new variant of it).
  Stack data-aware wrappers; never replace FormField.
- **Easier to test.** FormField can be unit-tested without mocking
  HTTP. LookupDropdown can be tested by mocking `useApi` without
  rendering a different component tree.

## Reference

- Frontend: `frontend/src/components/forms/LookupDropdown.tsx`
- Backend whitelist: `internal/repository/lookup.go::lookupQueries`
- Backing data shape: `(code, name, description)` triples — see
  `database/seed-data.md`
