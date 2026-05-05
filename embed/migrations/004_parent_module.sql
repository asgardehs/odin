-- Phase 8 of the UI restructure: each custom table declares which hub
-- it shows up on. 'none' = top-level (sidebar entry), 'facilities' /
-- 'employees' / 'inspections' = extra KPI card on that hub after the
-- built-in cards. CHECK constrains the enum at the DB level.

ALTER TABLE _custom_tables
    ADD COLUMN parent_module TEXT NOT NULL DEFAULT 'none'
    CHECK (parent_module IN ('none', 'facilities', 'employees', 'inspections'));
