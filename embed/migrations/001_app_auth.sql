-- Application-level user authentication and session management.
-- Separate from EHS domain tables; these are Odin application concerns.

CREATE TABLE IF NOT EXISTS app_users (
    id              INTEGER PRIMARY KEY,
    username        TEXT    NOT NULL UNIQUE COLLATE NOCASE,
    display_name    TEXT    NOT NULL,
    password_hash   TEXT    NOT NULL,
    role            TEXT    NOT NULL DEFAULT 'user'
                    CHECK (role IN ('admin', 'user', 'readonly')),
    is_active       INTEGER NOT NULL DEFAULT 1,
    security_q1     TEXT,
    security_a1     TEXT,           -- bcrypt hash, case-sensitive
    security_q2     TEXT,
    security_a2     TEXT,
    security_q3     TEXT,
    security_a3     TEXT,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    last_login_at   TEXT
);

CREATE TABLE IF NOT EXISTS app_sessions (
    token       TEXT    PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
    expires_at  TEXT    NOT NULL,
    ip_address  TEXT
);

CREATE INDEX IF NOT EXISTS idx_app_sessions_user    ON app_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_app_sessions_expires ON app_sessions(expires_at);

-- Application-level configuration (recovery key, etc.)
CREATE TABLE IF NOT EXISTS app_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
