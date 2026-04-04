-- Waypoint-EHS - Incident Reporting Schema
-- Designed to support OSHA 300/300A/301 generation while capturing
-- richer data for actual safety management.
--
-- OSHA Form Reference:
--   300  = Log of Work-Related Injuries and Illnesses (annual log)
--   300A = Summary of Work-Related Injuries and Illnesses (posted Feb-Apr)
--   301  = Injury and Illness Incident Report (detailed per-incident form)

-- ============================================================================
-- ESTABLISHMENT (Company/Site Information)
-- ============================================================================
-- OSHA requires tracking by "establishment" - a single physical location.
-- Small companies often have one, but this supports multiple sites.

CREATE TABLE IF NOT EXISTS establishments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    street_address TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,                    -- 2-letter code
    zip TEXT NOT NULL,
    industry_description TEXT,              -- What the company does
    naics_code TEXT,                        -- North American Industry Classification
    sic_code TEXT,                          -- Standard Industrial Classification (legacy)

    -- For OSHA 300A annual summary
    annual_avg_employees INTEGER,           -- Updated yearly
    total_hours_worked INTEGER,             -- Updated yearly

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- EMPLOYEES
-- ============================================================================
-- We need employee info for incidents, but also for training tracking later.
-- OSHA 301 requires: name, address, DOB, hire date, gender

CREATE TABLE IF NOT EXISTS employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Identity
    employee_number TEXT,                   -- Company's internal ID
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,

    -- OSHA 301 required fields
    street_address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    date_of_birth TEXT,                     -- Format: YYYY-MM-DD
    date_hired TEXT,                        -- Format: YYYY-MM-DD
    gender TEXT,                            -- M/F/X for OSHA reporting

    -- Job info
    job_title TEXT,
    department TEXT,
    supervisor_name TEXT,

    -- Status
    is_active INTEGER DEFAULT 1,
    termination_date TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_employees_establishment ON employees(establishment_id);
CREATE INDEX idx_employees_name ON employees(last_name, first_name);

-- ============================================================================
-- INCIDENTS
-- ============================================================================
-- The core incident record. Captures everything needed for OSHA forms
-- plus additional fields for real safety management.

CREATE TABLE IF NOT EXISTS incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    employee_id INTEGER,                    -- NULL for non-employee incidents

    -- OSHA Case Number (auto-generated per establishment per year)
    -- Format: YYYY-NNN (e.g., 2024-001)
    case_number TEXT UNIQUE,

    -- ========== OSHA 300/301 REQUIRED FIELDS ==========

    -- When and Where (OSHA 301: items 10-12)
    incident_date TEXT NOT NULL,            -- Format: YYYY-MM-DD
    incident_time TEXT,                     -- Format: HH:MM (24-hour)
    time_employee_began_work TEXT,          -- OSHA 301 item 11
    location_description TEXT,              -- Where in the facility

    -- What Happened (OSHA 301: items 13-15)
    activity_description TEXT,              -- What was employee doing?
    incident_description TEXT NOT NULL,     -- How did the injury occur?
    object_or_substance TEXT,               -- What harmed the employee?

    -- Injury/Illness Details (OSHA 300: columns F-M)
    injury_illness_type TEXT NOT NULL,      -- See injury_illness_types table
    body_part TEXT NOT NULL,                -- See body_parts table

    -- Classification (OSHA 300: column G-J)
    resulted_in_death INTEGER DEFAULT 0,
    days_away_from_work INTEGER DEFAULT 0,
    days_restricted_duty INTEGER DEFAULT 0,
    days_job_transfer INTEGER DEFAULT 0,

    -- Treatment
    treatment_type TEXT,                    -- first_aid, medical, emergency, hospitalized
    treating_physician TEXT,                -- OSHA 301 item 6
    treatment_facility TEXT,                -- OSHA 301 item 7
    was_hospitalized INTEGER DEFAULT 0,     -- Overnight stay
    was_er_visit INTEGER DEFAULT 0,

    -- ========== OSHA CLASSIFICATION FLAGS ==========

    is_recordable INTEGER DEFAULT 0,        -- Does this go on OSHA 300?
    is_privacy_case INTEGER DEFAULT 0,      -- OSHA allows hiding name for certain injuries

    -- ========== BEYOND OSHA - SAFETY MANAGEMENT ==========

    -- Incident Classification
    incident_type TEXT DEFAULT 'injury',    -- injury, illness, near_miss, property_damage, first_aid_only
    severity TEXT,                          -- minor, moderate, serious, severe, fatal

    -- Investigation
    root_cause TEXT,
    contributing_factors TEXT,              -- JSON array or comma-separated
    immediate_actions_taken TEXT,

    -- Witness and Reporting
    reported_by TEXT,
    reported_date TEXT,
    witness_names TEXT,                     -- Comma-separated or JSON array

    -- Status Tracking
    status TEXT DEFAULT 'open',             -- open, investigating, pending_review, closed
    closed_date TEXT,
    closed_by TEXT,

    -- Attachments (stored as file paths)
    attachment_paths TEXT,                  -- JSON array of file paths

    -- Notes
    internal_notes TEXT,                    -- Not for OSHA, internal use

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_incidents_establishment ON incidents(establishment_id);
CREATE INDEX idx_incidents_date ON incidents(incident_date);
CREATE INDEX idx_incidents_employee ON incidents(employee_id);
CREATE INDEX idx_incidents_recordable ON incidents(is_recordable);
CREATE INDEX idx_incidents_case_number ON incidents(case_number);

-- ============================================================================
-- CORRECTIVE ACTIONS
-- ============================================================================
-- Track actions taken to prevent recurrence. Critical for demonstrating
-- due diligence during audits.

CREATE TABLE IF NOT EXISTS corrective_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL,

    description TEXT NOT NULL,
    action_type TEXT,                       -- engineering, administrative, ppe, training
    assigned_to TEXT,
    due_date TEXT,
    completed_date TEXT,
    status TEXT DEFAULT 'open',             -- open, in_progress, completed, verified
    verification_notes TEXT,
    verified_by TEXT,
    verified_date TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE CASCADE
);

CREATE INDEX idx_corrective_actions_incident ON corrective_actions(incident_id);
CREATE INDEX idx_corrective_actions_status ON corrective_actions(status);
CREATE INDEX idx_corrective_actions_due_date ON corrective_actions(due_date);

-- ============================================================================
-- REFERENCE TABLES (OSHA Standard Codes)
-- ============================================================================
-- These match OSHA's standard categories for consistent reporting.

CREATE TABLE IF NOT EXISTS injury_illness_types (
    code TEXT PRIMARY KEY,
    description TEXT NOT NULL,
    osha_column TEXT,                       -- Which OSHA 300 column (M1-M6)
    is_illness INTEGER DEFAULT 0            -- 0=injury, 1=illness
);

-- OSHA 300 Column F injury/illness types
INSERT OR IGNORE INTO injury_illness_types (code, description, osha_column, is_illness) VALUES
    ('INJ', 'Injury', 'F', 0),
    ('SKIN', 'Skin disorder', 'M1', 1),
    ('RESP', 'Respiratory condition', 'M2', 1),
    ('POISON', 'Poisoning', 'M3', 1),
    ('HEARING', 'Hearing loss', 'M4', 1),
    ('OTHER_ILL', 'All other illnesses', 'M5', 1);

CREATE TABLE IF NOT EXISTS body_parts (
    code TEXT PRIMARY KEY,
    description TEXT NOT NULL,
    category TEXT                           -- head, torso, upper_extremity, lower_extremity, multiple
);

-- Common body part codes (subset - full OSHA BLS list is extensive)
INSERT OR IGNORE INTO body_parts (code, description, category) VALUES
    ('HEAD', 'Head', 'head'),
    ('EYE', 'Eye(s)', 'head'),
    ('EAR', 'Ear(s)', 'head'),
    ('FACE', 'Face', 'head'),
    ('NECK', 'Neck', 'head'),
    ('SHOULDER', 'Shoulder', 'upper_extremity'),
    ('ARM_UPPER', 'Upper arm', 'upper_extremity'),
    ('ELBOW', 'Elbow', 'upper_extremity'),
    ('ARM_LOWER', 'Lower arm/forearm', 'upper_extremity'),
    ('WRIST', 'Wrist', 'upper_extremity'),
    ('HAND', 'Hand (except fingers)', 'upper_extremity'),
    ('FINGER', 'Finger(s)', 'upper_extremity'),
    ('CHEST', 'Chest', 'torso'),
    ('BACK_UPPER', 'Upper back', 'torso'),
    ('BACK_LOWER', 'Lower back', 'torso'),
    ('ABDOMEN', 'Abdomen', 'torso'),
    ('HIP', 'Hip', 'lower_extremity'),
    ('THIGH', 'Thigh', 'lower_extremity'),
    ('KNEE', 'Knee', 'lower_extremity'),
    ('LEG_LOWER', 'Lower leg', 'lower_extremity'),
    ('ANKLE', 'Ankle', 'lower_extremity'),
    ('FOOT', 'Foot (except toes)', 'lower_extremity'),
    ('TOE', 'Toe(s)', 'lower_extremity'),
    ('MULTIPLE', 'Multiple body parts', 'multiple'),
    ('BODY_SYSTEM', 'Body systems', 'multiple');

-- ============================================================================
-- OSHA 300A ANNUAL SUMMARY
-- ============================================================================
-- Stores the calculated values for each year's summary.
-- Generated from incident data but stored for historical reference.

CREATE TABLE IF NOT EXISTS osha_300a_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    year INTEGER NOT NULL,

    -- Establishment info at time of summary
    annual_avg_employees INTEGER,
    total_hours_worked INTEGER,

    -- Injury/Illness counts (OSHA 300A Section 1)
    total_deaths INTEGER DEFAULT 0,
    total_days_away INTEGER DEFAULT 0,
    total_job_transfer_restriction INTEGER DEFAULT 0,
    total_other_recordable INTEGER DEFAULT 0,

    -- Days counts (OSHA 300A Section 2)
    total_days_away_count INTEGER DEFAULT 0,
    total_days_restricted_count INTEGER DEFAULT 0,

    -- Illness breakdown (OSHA 300A Section 3)
    injury_count INTEGER DEFAULT 0,
    skin_disorder_count INTEGER DEFAULT 0,
    respiratory_count INTEGER DEFAULT 0,
    poisoning_count INTEGER DEFAULT 0,
    hearing_loss_count INTEGER DEFAULT 0,
    other_illness_count INTEGER DEFAULT 0,

    -- Certification
    certified_by TEXT,
    certified_title TEXT,
    certified_phone TEXT,
    certified_date TEXT,

    generated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, year)
);

-- ============================================================================
-- AUDIT LOG
-- ============================================================================
-- Track all changes for compliance. OSHA can ask about record modifications.

CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name TEXT NOT NULL,
    record_id INTEGER NOT NULL,
    action TEXT NOT NULL,                   -- INSERT, UPDATE, DELETE
    changed_fields TEXT,                    -- JSON of what changed
    old_values TEXT,                        -- JSON of previous values
    new_values TEXT,                        -- JSON of new values
    changed_by TEXT,
    changed_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_timestamp ON audit_log(changed_at);

-- ============================================================================
-- APPLICATION SETTINGS
-- ============================================================================
-- Configuration that persists across sessions

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    description TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Default settings
INSERT OR IGNORE INTO settings (key, value, description) VALUES
    ('current_establishment_id', '1', 'Default establishment for data entry'),
    ('case_number_format', 'YYYY-NNN', 'Format for auto-generated case numbers'),
    ('fiscal_year_start', '01-01', 'MM-DD when fiscal year begins'),
    ('auto_backup_enabled', '1', 'Enable automatic database backups'),
    ('backup_path', '', 'Directory for database backups');
