# Form Hooks: useEntityMutation + useUnsavedGuard

Every module form pairs two hooks. They handle separate concerns;
neither subsumes the other.

```tsx
const [dirty, setDirty] = useState(false);
const { mutate, loading: saving, error: saveError } = useEntityMutation();
useUnsavedGuard(dirty && !saving);

const update = <K extends keyof FormState>(key: K, v: FormState[K]) => {
    setForm(prev => ({ ...prev, [key]: v }));
    setDirty(true);              // any field change marks the form dirty
};

async function submit(e: React.FormEvent) {
    e.preventDefault();
    try {
        await mutate('PUT', `/api/establishments/${id}`, normalizeForSubmit(form));
        setDirty(false);         // clear after successful mutation
        navigate(...);
    } catch {
        // saveError is populated by the hook
    }
}
```

## What each hook owns

**`useEntityMutation`** — owns the HTTP mutation lifecycle:

- Issues POST / PUT / DELETE via `apiFetch`.
- Returns `{ mutate, loading, error }`.
- `loading` flips true during the request.
- `error` populates with the API's error message on failure.

**`useUnsavedGuard`** — owns browser-level navigation protection:

- Takes a single boolean argument (the "should I block navigation?"
  signal).
- Attaches `beforeunload` listeners; React Router's navigation
  prompt; etc.
- Inert when the argument is false.

## Rules

- **Always paired.** Every form uses both. A form without
  `useUnsavedGuard` silently loses the user's typed data on
  accidental navigation.
- **`dirty` flips true on the first `update()` call and back to
  false after a successful `mutate()`.** That's the contract — guard
  argument is `dirty && !saving` so the prompt doesn't fire during
  the submit redirect.
- **Don't bypass `useEntityMutation` with raw `apiFetch` for
  mutations.** The hook normalizes loading/error state across all
  forms. Inconsistent error UI across forms is a smell.
- **Don't roll your own `beforeunload` handler.** That belongs in
  `useUnsavedGuard`. Per-form custom handlers diverge over time and
  break the SPA's navigation behavior.

## Why two hooks instead of one

The two concerns are orthogonal in time. A user might sit on a
dirty form for 10 minutes before submitting:

- `useUnsavedGuard` is active that entire time.
- `useEntityMutation` is idle for 9:59 of that time, then briefly
  active during the submit, then idle again.

Combining them would force a single component to manage state for
both phases via one hook's signature, which gets confusing fast.
Separation lets each hook do one thing well; the form composes them.

## Reference

- `frontend/src/hooks/useEntityMutation.ts`
- `frontend/src/hooks/useUnsavedGuard.ts`
- Pattern in use: every `*Form.tsx` under `frontend/src/pages/modules/`.
