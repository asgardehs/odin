-- Per-user preferences keyed by (user_id, key). Generic on purpose so
-- the selected facility today and future prefs (default landing page,
-- table column visibility, last-opened tab, etc.) live here without
-- another migration.

CREATE TABLE IF NOT EXISTS app_user_preferences (
    user_id    INTEGER NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    key        TEXT    NOT NULL,
    value      TEXT,
    updated_at TEXT    NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, key)
);

CREATE INDEX IF NOT EXISTS idx_app_user_preferences_user
    ON app_user_preferences(user_id);
