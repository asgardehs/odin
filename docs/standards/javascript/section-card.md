# SectionCard — Form Section Grouping

`SectionCard` is the standard wrapper for grouping fields inside a
form. Every multi-field section in odin uses it.

```tsx
<SectionCard
    title="OSHA Reporting"
    description="Fields required for OSHA Injury Tracking Application (ITA) submission per 29 CFR 1904.41."
>
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <FormField label="EIN" ... />
        <FormField label="Company Name" ... />
        ...
    </div>
</SectionCard>
```

## Rules

- **Multi-field sections use SectionCard.** Raw `<div>` + className
  for a section is a smell — it means the form's grouping isn't
  styled consistently with the rest of odin.
- **Single-field "sections" don't need it.** A standalone field at
  the top of a page (e.g. a search box) isn't a section.
- **Title is required, description is optional.** Both render in the
  same Nótt & Dagr-themed styles; consistency is automatic.

## When to use the description

The description is the single best place to surface non-expert
ergonomics in a form. It's where a new user reads what the section
is *for* before figuring out what each field means.

Strong examples currently in odin:
- "OSHA Reporting" → "Fields required for OSHA Injury Tracking
  Application (ITA) submission per 29 CFR 1904.41."
- "ITA Reporting" → "Fields required for OSHA ITA submission. Leave
  blank for non-recordable cases."

The description is also where the regulatory citation goes when
relevant. See `feedback_user_vs_expert_ux` (memory): default to
non-expert users, and the description is half the battle.

## Why a card, not just a header + divs

- **Visual grouping.** Forms with 6+ sections (Identity, Address,
  Workforce, OSHA Reporting, etc.) need clear card boundaries to
  stay scannable.
- **Single source of truth for section styling.** Padding, border,
  internal heading typography, dark/light theme tokens — all
  centralized. Edits propagate to every form.
- **Slot for future structural additions.** If sections later need
  collapse/expand, validation summary, or per-section help-link
  buttons, the change lands inside SectionCard, not in 12 form
  files.

## Reference

- `frontend/src/components/forms/SectionCard.tsx`
- Examples in use: `frontend/src/pages/modules/EstablishmentForm.tsx`,
  `frontend/src/pages/modules/IncidentForm.tsx`,
  `frontend/src/pages/osha-ita/ExportPage.tsx`
