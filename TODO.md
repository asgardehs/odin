# Odin — Backlog

Post-plan / post-release items preserved from `docs/plans/2026-04-19-data-entry.md`.
Not in scope for the current phase; tracked here so they don't get lost.

## Future enhancements (post-plan backlog)

Ideas we want to preserve but are explicitly not in scope for this plan.

- **NAICS / SIC code lookup helper on the Establishment form.** Currently the
  user types raw codes into free-text inputs. For EHS professionals new to the
  field, this is easy to get wrong. Integrate an NAICS lookup (NAICS Association
  API or the Census Bureau's NAICS data; evaluate license + API stability before
  committing) so the user can search by keyword ("electroplating" → 332813) and
  pick. The matching 4-digit SIC can be inferred from the 6-digit NAICS via a
  lookup table or the same API. Value: reduces data-entry errors and lowers the
  learning curve for first-time EHS managers. Implementation notes: same
  `EntitySelector`-style popup but backed by a remote API instead of a local
  list; cache results since these codes don't change often.

- **SDS PDF storage on Chemicals.** Every chemical on the inventory should have
  its Safety Data Sheet attached — it's the source of truth for the GHS flags,
  physical properties, and PPE already captured in the form, and OSHA 29 CFR
  1910.1200(g) requires SDSs be "readily accessible" to employees. Need to add:
  - Backend: new `chemical_documents` table (or reuse a generic `attachments`
    table) keyed by `chemical_id`, storing `filename`, `mime_type`,
    `size_bytes`, `uploaded_by`, `uploaded_at`, plus the file itself. For a
    single-tenant desktop app like Odin, filesystem under
    `ODIN_DATA_DIR/chemical_sds/{chemical_id}/` is simplest; SQLite BLOB works
    but bloats backups.
  - Endpoints: `POST /api/chemicals/{id}/documents` (multipart upload),
    `GET /api/chemicals/{id}/documents` (list),
    `GET /api/chemicals/{id}/documents/{docId}` (stream with
    Content-Disposition), `DELETE /api/chemicals/{id}/documents/{docId}`.
    Admin-only for delete.
  - Frontend: a Documents section on Chemical detail with drop zone + list +
    preview link. Bonus — inline PDF viewer (embed pdf.js) so users don't have
    to download to read, but MVP can just open in new tab.
  - Versioning: store each new upload as a new row with `superseded_at` on the
    old one rather than overwriting — SDSs get revised and the history matters
    for OSHA recordkeeping.
  - Future tie-ins: auto-populate chemical flags from SDS text extraction
    (Section 2 GHS classification, Section 9 physical properties) — would save
    significant data entry. Could live behind a feature flag initially.

- **Clickable Inspection Findings — read-only detail modal.** Today findings
  are listed on the Inspection detail page but can't be opened. A user should
  be able to click a row and see the full record (description, citation,
  immediate action + by-whom, closure notes, etc.) in a read-only modal —
  the list row truncates description at 120 chars, which is fine for the
  summary view but not for review. Keep it read-only for now; "edit finding"
  can follow the same pattern as the other detail → edit transitions. Low
  effort: reuse `Modal` + `Field`/`Section`, open on row click, close on
  escape/backdrop. Close button already-open close-finding flow stays on
  its own "Close" button to keep destructive/state-changing actions explicit.
