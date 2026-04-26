# FormField — Discriminated Union

`FormField` is the single primitive for every form input in odin. The
input shape is selected via a `type` prop with a discriminated TS
union behind it.

```tsx
<FormField label="Facility Name" required value={form.name} onChange={v => update('name', v)} />

<FormField type="select" label="Severity" required
    value={form.severity_code} onChange={v => update('severity_code', v)}
    options={severityOptions} />

<FormField type="checkbox" label="Active"
    value={form.is_active} onChange={v => update('is_active', v)} />

<FormField type="textarea" label="Description"
    value={form.description} onChange={v => update('description', v)} rows={4} />
```

## Rules

- **Every form input goes through FormField.** Raw `<input>`,
  `<select>`, `<textarea>` should not appear in module form pages.
  Anything custom enough to bypass FormField needs to be discussed
  before it lands.
- **New input variants extend the union**, not via subclassing or
  wrapper components. Add a new prop interface
  (`MyVariantFieldProps extends BaseProps`) and a new branch in
  the render switch. Do not create `MySpecialField` that wraps
  FormField.
- **Discriminated by the `type` prop.** When `type` is omitted,
  the field is plain text. Other variants (`'textarea' | 'select'
  | 'checkbox' | 'custom'`) require their type-specific props.
- **`autoComplete="off"` is the default.** EHS-domain fields don't
  match browser-autofill heuristics; aggressive autofill broke
  text input in NAICS/ZIP fields before this default landed.
  Override only when the field genuinely maps to a known autofill
  type (e.g. `autoComplete="email"` on a login email).

## Why a discriminated union

- TypeScript enforces the right props per variant at the call site.
  `type="select"` requires `options`; `type="checkbox"` requires a
  `boolean` value. Mismatches fail the build, not runtime.
- One render path keeps styling, focus behavior, error placement,
  and accessibility consistent across every input type. Adding a
  new variant doesn't drift the existing ones.
- Theming via Nótt & Dagr lives in one set of class strings, not
  scattered across N input components.

## Reference

- `frontend/src/components/forms/FormField.tsx` — the component.
- `frontend/src/components/forms/LookupDropdown.tsx` — example of a
  data-aware wrapper that delegates to FormField rather than
  reimplementing.
