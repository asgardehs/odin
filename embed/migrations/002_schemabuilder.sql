-- Schema Builder metadata.
--
-- Lets admins design their own tables ("custom tables") at runtime.
-- Every user-defined table is created with the prefix `cx_`; pre-built
-- EHS modules are never altered here. Schema changes are additive only
-- (no DROP / RENAME at runtime) and every DDL event is recorded in
-- _custom_table_versions for an auditable trail.
--
-- Reserved system namespace: leading underscore on table names here
-- keeps these metadata tables out of the `cx_*` space users can create.

CREATE TABLE IF NOT EXISTS _custom_tables (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT    NOT NULL UNIQUE,            -- post-cx_ portion
    display_name  TEXT    NOT NULL,
    description   TEXT,
    icon          TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active     INTEGER NOT NULL DEFAULT 1,
    created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_custom_tables_active ON _custom_tables(is_active);

CREATE TABLE IF NOT EXISTS _custom_fields (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    custom_table_id  INTEGER NOT NULL REFERENCES _custom_tables(id),
    name             TEXT    NOT NULL,
    display_name     TEXT    NOT NULL,
    field_type       TEXT    NOT NULL
                     CHECK (field_type IN (
                         'text', 'number', 'decimal', 'date',
                         'datetime', 'boolean', 'select', 'relation'
                     )),
    is_required      INTEGER NOT NULL DEFAULT 0,
    default_value    TEXT,
    config           TEXT,                            -- JSON, type-specific
    display_order    INTEGER NOT NULL DEFAULT 0,
    is_active        INTEGER NOT NULL DEFAULT 1,
    created_at       TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at       TEXT    NOT NULL DEFAULT (datetime('now')),
    UNIQUE(custom_table_id, name)
);

CREATE INDEX IF NOT EXISTS idx_custom_fields_table  ON _custom_fields(custom_table_id);
CREATE INDEX IF NOT EXISTS idx_custom_fields_active ON _custom_fields(is_active);

CREATE TABLE IF NOT EXISTS _custom_relations (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    source_table_id    INTEGER NOT NULL REFERENCES _custom_tables(id),
    source_field_id    INTEGER NOT NULL REFERENCES _custom_fields(id),
    target_table_name  TEXT    NOT NULL,              -- cx_foo or whitelisted pre-built
    display_field      TEXT    NOT NULL,              -- column on target used as dropdown label
    relation_type      TEXT    NOT NULL DEFAULT 'belongs_to'
                       CHECK (relation_type IN ('belongs_to', 'has_many', 'many_to_many')),
    is_active          INTEGER NOT NULL DEFAULT 1,
    created_at         TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at         TEXT    NOT NULL DEFAULT (datetime('now')),
    UNIQUE(source_field_id)
);

CREATE INDEX IF NOT EXISTS idx_custom_relations_source ON _custom_relations(source_table_id);
CREATE INDEX IF NOT EXISTS idx_custom_relations_active ON _custom_relations(is_active);

CREATE TABLE IF NOT EXISTS _custom_table_versions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    custom_table_id INTEGER NOT NULL REFERENCES _custom_tables(id),
    change_type     TEXT    NOT NULL
                    CHECK (change_type IN (
                        'create_table', 'add_field', 'deactivate_field',
                        'add_relation', 'deactivate_relation', 'deactivate_table',
                        'reactivate_table'
                    )),
    change_payload  TEXT    NOT NULL,                 -- JSON
    changed_by      TEXT    NOT NULL,
    changed_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_custom_versions_table ON _custom_table_versions(custom_table_id);
CREATE INDEX IF NOT EXISTS idx_custom_versions_time  ON _custom_table_versions(changed_at);
