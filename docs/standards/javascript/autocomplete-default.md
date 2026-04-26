# FormField autoComplete Default = "off"

`FormField`'s text inputs default `autoComplete="off"`. Every text /
email / number / date / tel / url variant inherits this default.

```tsx
// FormField.tsx
<input
    type={props.type ?? 'text'}
    autoComplete={props.autoComplete ?? 'off'}
    ...
/>
```

## Why

EHS-domain fields (NAICS code, ZIP, hazard codes, severity codes,
case classifications, etc.) don't match any of the categories that
browser autofill recognizes. When the autofill heuristic fires
anyway — which Firefox does aggressively — the result is unpredictable
keystroke interception. NAICS Code accepted only 2 characters before
the default was added; the user could paste fine but typing past 2
chars failed silently.

`autoComplete="off"` per-field tells the browser: "I have no
autofill mapping for this; stay out of the way."

## When to override

Pass an explicit `autoComplete` prop only when the field genuinely
maps to a known browser-autofill type:

```tsx
<FormField type="email" label="Email" autoComplete="email" ... />
<FormField label="Street" autoComplete="street-address" ... />
<FormField label="ZIP" autoComplete="postal-code" ... />
<FormField type="tel" label="Phone" autoComplete="tel" ... />
```

Login forms (rare in odin — mostly the `/auth/login` page) override
to `"username"` and `"current-password"` so password managers work
correctly.

## Hard rule

**Never disable autocomplete site-wide via meta tag or a top-level
form attribute.** Browsers ignore the form-level off, and a site-wide
off would break login + recovery flows where autofill is genuinely
useful. The per-field default is the only correct path.

## Reference

- `frontend/src/components/forms/FormField.tsx`
- Bug history: NAICS field 2-char limit, fixed in 2026-04-22.
- HTML autocomplete reference: https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/autocomplete
