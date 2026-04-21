-- Module: CSV / Excel Import Framework
-- Derived from plan docs/plans/2026-04-20-module-d-csv-import-pdf-forms.md (Phase 2)
--
-- The _imports table holds in-flight import sessions. An upload stores the
-- parsed rows + file-header-to-field mapping keyed by a UUID token; preview
-- and commit both operate against this row. Tokens expire after 30 minutes
-- (configurable via expires_at) to bound memory / storage growth.
--
-- Admin-only at the API level. One row per import attempt.

CREATE TABLE IF NOT EXISTS _imports (
    token TEXT PRIMARY KEY,                  -- UUID (generated server-side)
    module TEXT NOT NULL,                    -- 'employees', 'chemicals', ...

    -- Lifecycle status
    status TEXT NOT NULL DEFAULT 'pending',  -- 'pending', 'committed', 'discarded', 'expired'

    -- Who / when / what
    uploaded_by TEXT,                        -- username (from session)
    uploaded_at TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT NOT NULL,                -- uploaded_at + 30 min by default

    original_filename TEXT,
    row_count INTEGER NOT NULL DEFAULT 0,

    -- Target context: the UI can preset one establishment for every row
    -- (e.g. employees import for facility X). Mappers interpret as needed.
    target_establishment_id INTEGER,

    -- Raw data as parsed from the CSV (all cells are TEXT at this stage;
    -- mappers handle type coercion / validation).
    headers_json TEXT NOT NULL,              -- JSON array of source headers
    rows_json TEXT NOT NULL,                 -- JSON array of {header: value} objects

    -- Column mapping: source_header -> target_field. Initially populated
    -- with fuzzy-match suggestions; user can override via PUT .../mapping.
    -- Value '__ignore__' means the column is dropped.
    mapping_json TEXT,                       -- JSON object

    -- Result of the most recent validation pass (run on upload + on every
    -- mapping change). Array of {row, column, message}.
    validation_errors_json TEXT,

    -- Commit results (populated when status flips to 'committed').
    committed_at TEXT,
    committed_count INTEGER,
    skipped_count INTEGER,
    commit_error TEXT,                       -- NULL on success; populated on failure

    FOREIGN KEY (target_establishment_id) REFERENCES establishments(id)
);

CREATE INDEX IF NOT EXISTS idx_imports_module ON _imports(module);
CREATE INDEX IF NOT EXISTS idx_imports_status ON _imports(status);
CREATE INDEX IF NOT EXISTS idx_imports_expires ON _imports(expires_at);
CREATE INDEX IF NOT EXISTS idx_imports_uploaded_by ON _imports(uploaded_by);
