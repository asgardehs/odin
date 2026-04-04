-- Waypoint-EHS - Stormwater Monitoring Schema
-- Tracks visual discharge monitoring for NPDES stormwater general permits.
-- Focused on visual observations during qualifying storm events, NOT analytical sampling.
--
-- Regulatory References:
--   Clean Water Act - NPDES stormwater permits
--   EPA MSGP (Multi-Sector General Permit)
--   State stormwater general permits
--   40 CFR 122.26 - Stormwater discharge requirements
--
-- Design Philosophy:
--   - Storm event tracking to prove "qualifying event" occurred
--   - Visual observations (qualitative) not analytical results (quantitative)
--   - Monthly/quarterly inspection tracking per outfall
--   - Annual report aggregation
--   - Links to existing SWPPP/BMP inspection framework in 005
--
-- Connects to:
--   - establishments (001_incidents.sql)
--   - employees (001_incidents.sql) - who inspected
--   - permits (006_permits.sql) - links to NPDES stormwater permit
--   - swppp_outfalls (005_inspections_audits.sql) - outfall definitions
--   - corrective_actions (005_inspections_audits.sql) - for findings

-- ============================================================================
-- VISUAL OBSERVATION PARAMETERS
-- ============================================================================
-- Standard EPA MSGP visual observation categories. These are consistent across
-- most stormwater general permits in North America.

CREATE TABLE IF NOT EXISTS sw_observation_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    parameter_code TEXT NOT NULL UNIQUE,    -- 'COLOR', 'ODOR', 'SHEEN', 'FLOATABLES'
    parameter_name TEXT NOT NULL,
    description TEXT,
    observation_type TEXT,                  -- 'yes_no', 'descriptive', 'severity'

    -- Typical values (for dropdown selection)
    typical_values TEXT,                    -- JSON array of common responses

    display_order INTEGER,                  -- Order to show parameters in UI

    created_at TEXT DEFAULT (datetime('now'))
);

-- Seed standard MSGP visual observation parameters
INSERT OR IGNORE INTO sw_observation_parameters
    (id, parameter_code, parameter_name, description, observation_type, typical_values, display_order) VALUES
    (1, 'DISCHARGE_PRESENT', 'Discharge Present',
        'Is there discharge from this outfall?', 'yes_no', '["Yes", "No"]', 1),

    (2, 'COLOR', 'Color',
        'Color of discharge (if present)', 'descriptive',
        '["Clear", "Light Brown", "Brown", "Dark Brown", "Yellow", "Green", "Orange", "Red", "Other"]', 2),

    (3, 'ODOR', 'Odor',
        'Unusual odor present', 'yes_no', '["None", "Slight", "Moderate", "Strong"]', 3),

    (4, 'SHEEN', 'Sheen',
        'Oil sheen or petroleum products visible on surface', 'yes_no', '["None", "Slight", "Moderate", "Heavy"]', 4),

    (5, 'FLOATABLES', 'Floatables',
        'Floating materials, debris, or foam', 'yes_no', '["None", "Minor", "Moderate", "Significant"]', 5),

    (6, 'SUSPENDED_SOLIDS', 'Suspended Solids/Turbidity',
        'Visible suspended solids or cloudiness', 'descriptive',
        '["Clear", "Slightly Cloudy", "Cloudy", "Very Cloudy", "Opaque"]', 6),

    (7, 'FOAM', 'Foam',
        'Suds or foam present', 'yes_no', '["None", "Slight", "Moderate", "Excessive"]', 7),

    (8, 'EROSION', 'Erosion',
        'Erosion or sediment at outfall', 'yes_no', '["None", "Minor", "Moderate", "Severe"]', 8),

    (9, 'FLOW_RATE', 'Flow Rate',
        'Visual estimate of discharge flow', 'descriptive',
        '["No Flow", "Trickle", "Moderate", "Heavy"]', 9),

    (10, 'OUTFALL_CONDITION', 'Outfall Condition',
        'Physical condition of outfall structure', 'descriptive',
        '["Good", "Fair", "Poor", "Needs Repair"]', 10);


-- ============================================================================
-- STORM EVENTS
-- ============================================================================
-- Track qualifying storm events. Most permits define "qualifying event" as
-- rainfall above a threshold (e.g., 0.1 inches) that generates runoff.

CREATE TABLE IF NOT EXISTS sw_storm_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Event identification
    event_number TEXT,                      -- Optional tracking number

    -- Storm timing
    storm_start_datetime TEXT NOT NULL,     -- Format: YYYY-MM-DD HH:MM
    storm_end_datetime TEXT,                -- NULL if ongoing or unknown
    duration_hours REAL,                    -- Calculated or estimated

    -- Rainfall
    rainfall_amount REAL,                   -- Inches or mm
    rainfall_units TEXT DEFAULT 'inches',   -- 'inches' or 'mm'
    rainfall_estimated INTEGER DEFAULT 1,   -- 1=estimated, 0=measured

    -- Source of rainfall data
    rainfall_source TEXT,                   -- 'on-site gauge', 'weather service', 'estimated', 'nearby station'
    weather_station_id TEXT,                -- If using weather service

    -- Event characteristics
    is_qualifying_event INTEGER DEFAULT 0,  -- Does this meet permit threshold?
    qualifying_criteria TEXT,               -- Why/why not qualifying (e.g., "exceeds 0.1 inch threshold")

    -- Time since last storm (some permits require this)
    hours_since_last_storm REAL,

    -- Notes
    weather_conditions TEXT,                -- 'thunderstorm', 'steady rain', 'snow melt', etc.
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_sw_events_establishment ON sw_storm_events(establishment_id);
CREATE INDEX idx_sw_events_start ON sw_storm_events(storm_start_datetime);
CREATE INDEX idx_sw_events_qualifying ON sw_storm_events(is_qualifying_event);


-- ============================================================================
-- OUTFALL INSPECTIONS (Anchor Table)
-- ============================================================================
-- Visual monitoring of stormwater outfalls. Each inspection is one visit to
-- one outfall to make visual observations.

CREATE TABLE IF NOT EXISTS sw_outfall_inspections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    outfall_id INTEGER NOT NULL,           -- References swppp_outfalls from 005

    -- Inspection identification
    inspection_number TEXT,                 -- Optional tracking number

    -- When and who
    inspection_date TEXT NOT NULL,          -- Format: YYYY-MM-DD
    inspection_time TEXT,                   -- Format: HH:MM (24-hour)
    inspected_by_employee_id INTEGER,

    -- Inspection type
    inspection_type TEXT NOT NULL,          -- 'monthly', 'quarterly', 'storm_event', 'follow_up'

    -- Storm event relationship (if inspection is storm-event based)
    storm_event_id INTEGER,                 -- Which storm event triggered this inspection
    hours_after_storm REAL,                 -- How long after storm started
    within_72_hours INTEGER DEFAULT 0,      -- Did inspection occur within 72 hours of qualifying event?

    -- Weather at time of inspection
    weather_at_inspection TEXT,             -- 'dry', 'raining', 'cloudy', 'snow'
    temperature_f REAL,

    -- Overall assessment
    discharge_observed INTEGER DEFAULT 0,   -- Was there any discharge present?
    overall_condition TEXT,                 -- 'satisfactory', 'concerning', 'unsatisfactory'

    -- Corrective actions needed
    corrective_action_needed INTEGER DEFAULT 0,
    corrective_action_description TEXT,
    corrective_action_taken TEXT,           -- Immediate actions taken during inspection

    -- Follow-up
    requires_follow_up INTEGER DEFAULT 0,
    follow_up_date TEXT,                    -- When to re-inspect

    -- Photos/documentation
    photo_paths TEXT,                       -- JSON array of photo file paths

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (outfall_id) REFERENCES swppp_outfalls(id),
    FOREIGN KEY (inspected_by_employee_id) REFERENCES employees(id),
    FOREIGN KEY (storm_event_id) REFERENCES sw_storm_events(id)
);

CREATE INDEX idx_sw_inspections_establishment ON sw_outfall_inspections(establishment_id);
CREATE INDEX idx_sw_inspections_outfall ON sw_outfall_inspections(outfall_id);
CREATE INDEX idx_sw_inspections_date ON sw_outfall_inspections(inspection_date);
CREATE INDEX idx_sw_inspections_storm ON sw_outfall_inspections(storm_event_id);
CREATE INDEX idx_sw_inspections_type ON sw_outfall_inspections(inspection_type);


-- ============================================================================
-- VISUAL OBSERVATIONS
-- ============================================================================
-- Individual observations made during each outfall inspection.
-- This is qualitative data (descriptions, yes/no) not quantitative (numeric values).

CREATE TABLE IF NOT EXISTS sw_visual_observations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    inspection_id INTEGER NOT NULL,
    parameter_id INTEGER NOT NULL,

    -- Observation value (varies by parameter type)
    observation_value TEXT,                 -- 'Yes', 'No', 'Clear', 'Brown', 'Slight', etc.

    -- Additional details
    observation_notes TEXT,                 -- Free-text elaboration

    -- Severity flag (for parameters where applicable)
    is_concerning INTEGER DEFAULT 0,        -- Is this observation concerning/actionable?

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (inspection_id) REFERENCES sw_outfall_inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (parameter_id) REFERENCES sw_observation_parameters(id)
);

CREATE INDEX idx_sw_observations_inspection ON sw_visual_observations(inspection_id);
CREATE INDEX idx_sw_observations_parameter ON sw_visual_observations(parameter_id);


-- ============================================================================
-- INSPECTION SCHEDULE
-- ============================================================================
-- Defines recurring inspection requirements. Most permits require monthly
-- visual monitoring plus quarterly inspections during qualifying events.

CREATE TABLE IF NOT EXISTS sw_inspection_schedule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    outfall_id INTEGER NOT NULL,

    -- Schedule definition
    frequency_type TEXT NOT NULL,           -- 'monthly', 'quarterly', 'storm_event'
    is_active INTEGER DEFAULT 1,

    -- For storm event inspections
    within_hours_of_storm INTEGER,          -- Must inspect within X hours (typically 72)

    -- Next scheduled
    next_scheduled_date TEXT,               -- For monthly/quarterly (not storm-based)

    -- Permit requirement
    permit_id INTEGER,                      -- Which permit requires this
    permit_condition_id INTEGER,            -- Specific permit condition

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (outfall_id) REFERENCES swppp_outfalls(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    FOREIGN KEY (permit_condition_id) REFERENCES permit_conditions(id),
    UNIQUE(establishment_id, outfall_id, frequency_type)
);

CREATE INDEX idx_sw_schedule_establishment ON sw_inspection_schedule(establishment_id);
CREATE INDEX idx_sw_schedule_outfall ON sw_inspection_schedule(outfall_id);
CREATE INDEX idx_sw_schedule_next_date ON sw_inspection_schedule(next_scheduled_date);


-- ============================================================================
-- ANNUAL REPORTS
-- ============================================================================
-- Track annual stormwater report submissions (EPA MSGP requires annual reports).

CREATE TABLE IF NOT EXISTS sw_annual_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    permit_id INTEGER NOT NULL,

    -- Reporting period
    report_year INTEGER NOT NULL,           -- Calendar year or permit year
    period_start_date TEXT NOT NULL,        -- Format: YYYY-MM-DD
    period_end_date TEXT NOT NULL,          -- Format: YYYY-MM-DD

    -- Summary statistics (calculated from inspection data)
    total_storm_events INTEGER,
    qualifying_storm_events INTEGER,
    total_inspections_conducted INTEGER,
    inspections_with_discharge INTEGER,
    inspections_with_concerns INTEGER,

    -- Corrective actions
    corrective_actions_implemented INTEGER,

    -- Submission tracking
    report_due_date TEXT,
    report_submitted_date TEXT,
    submission_confirmation_number TEXT,
    submission_method TEXT,                 -- 'eNOI', 'mail', 'email', 'portal'

    -- Documents
    report_document_path TEXT,              -- Path to PDF report

    -- Status
    status TEXT DEFAULT 'draft',            -- 'draft', 'submitted', 'accepted'

    -- Certification
    certified_by TEXT,
    certified_title TEXT,
    certified_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    UNIQUE(establishment_id, permit_id, report_year)
);

CREATE INDEX idx_sw_reports_establishment ON sw_annual_reports(establishment_id);
CREATE INDEX idx_sw_reports_permit ON sw_annual_reports(permit_id);
CREATE INDEX idx_sw_reports_year ON sw_annual_reports(report_year);
CREATE INDEX idx_sw_reports_status ON sw_annual_reports(status);


-- ============================================================================
-- VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- v_sw_inspections_due
-- Upcoming and overdue inspections
-- ----------------------------------------------------------------------------
CREATE VIEW v_sw_inspections_due AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    o.id AS outfall_id,
    o.outfall_name,
    o.discharge_point_id,

    sch.frequency_type,
    sch.next_scheduled_date,

    -- Last inspection date for this outfall/frequency
    (SELECT MAX(i.inspection_date)
     FROM sw_outfall_inspections i
     WHERE i.outfall_id = o.id
       AND i.inspection_type = sch.frequency_type) AS last_inspection_date,

    -- Days until due
    julianday(sch.next_scheduled_date) - julianday('now') AS days_until_due,

    CASE
        WHEN sch.next_scheduled_date < date('now') THEN 'OVERDUE'
        WHEN sch.next_scheduled_date <= date('now', '+7 days') THEN 'DUE_THIS_WEEK'
        WHEN sch.next_scheduled_date <= date('now', '+30 days') THEN 'DUE_THIS_MONTH'
        ELSE 'UPCOMING'
    END AS urgency,

    sch.permit_id

FROM sw_inspection_schedule sch
INNER JOIN establishments e ON sch.establishment_id = e.id
INNER JOIN swppp_outfalls o ON sch.outfall_id = o.id
WHERE sch.is_active = 1
  AND sch.next_scheduled_date IS NOT NULL
ORDER BY sch.next_scheduled_date;


-- ----------------------------------------------------------------------------
-- v_sw_storm_event_compliance
-- Storm events and whether required inspections were completed within 72 hours
-- ----------------------------------------------------------------------------
CREATE VIEW v_sw_storm_event_compliance AS
SELECT
    se.id AS storm_event_id,
    se.storm_start_datetime,
    se.rainfall_amount,
    se.rainfall_units,
    se.is_qualifying_event,

    e.id AS establishment_id,
    e.name AS establishment_name,

    -- How many outfalls need inspection
    (SELECT COUNT(*) FROM swppp_outfalls o
     WHERE o.establishment_id = e.id AND o.is_active = 1) AS total_outfalls,

    -- How many were inspected within 72 hours
    (SELECT COUNT(DISTINCT i.outfall_id)
     FROM sw_outfall_inspections i
     WHERE i.storm_event_id = se.id
       AND i.within_72_hours = 1) AS outfalls_inspected_on_time,

    -- Compliance status
    CASE
        WHEN se.is_qualifying_event = 0 THEN 'N/A - Not Qualifying'
        WHEN (SELECT COUNT(DISTINCT i.outfall_id)
              FROM sw_outfall_inspections i
              WHERE i.storm_event_id = se.id
                AND i.within_72_hours = 1) >=
             (SELECT COUNT(*) FROM swppp_outfalls o
              WHERE o.establishment_id = e.id AND o.is_active = 1)
            THEN 'COMPLIANT'
        ELSE 'NON-COMPLIANT'
    END AS compliance_status

FROM sw_storm_events se
INNER JOIN establishments e ON se.establishment_id = e.id
WHERE se.is_qualifying_event = 1
ORDER BY se.storm_start_datetime DESC;


-- ----------------------------------------------------------------------------
-- v_sw_inspection_summary
-- Summary of inspections by outfall and type
-- ----------------------------------------------------------------------------
CREATE VIEW v_sw_inspection_summary AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    o.id AS outfall_id,
    o.outfall_name,
    o.discharge_point_id,

    i.inspection_type,

    COUNT(*) AS total_inspections,
    SUM(CASE WHEN i.discharge_observed = 1 THEN 1 ELSE 0 END) AS inspections_with_discharge,
    SUM(CASE WHEN i.corrective_action_needed = 1 THEN 1 ELSE 0 END) AS inspections_needing_action,
    SUM(CASE WHEN i.overall_condition = 'unsatisfactory' THEN 1 ELSE 0 END) AS unsatisfactory_inspections,

    MAX(i.inspection_date) AS most_recent_inspection,

    -- Date range
    MIN(i.inspection_date) AS first_inspection,
    MAX(i.inspection_date) AS last_inspection

FROM sw_outfall_inspections i
INNER JOIN establishments e ON i.establishment_id = e.id
INNER JOIN swppp_outfalls o ON i.outfall_id = o.id
GROUP BY e.id, e.name, o.id, o.outfall_name, i.inspection_type
ORDER BY e.name, o.outfall_name, i.inspection_type;


-- ----------------------------------------------------------------------------
-- v_sw_concerning_observations
-- Visual observations that were flagged as concerning
-- ----------------------------------------------------------------------------
CREATE VIEW v_sw_concerning_observations AS
SELECT
    i.id AS inspection_id,
    i.inspection_date,
    i.inspection_time,

    e.name AS establishment_name,
    o.outfall_name,

    p.parameter_name,
    vo.observation_value,
    vo.observation_notes,

    i.corrective_action_needed,
    i.corrective_action_description,
    i.corrective_action_taken

FROM sw_visual_observations vo
INNER JOIN sw_outfall_inspections i ON vo.inspection_id = i.id
INNER JOIN establishments e ON i.establishment_id = e.id
INNER JOIN swppp_outfalls o ON i.outfall_id = o.id
INNER JOIN sw_observation_parameters p ON vo.parameter_id = p.id
WHERE vo.is_concerning = 1
ORDER BY i.inspection_date DESC;


-- ----------------------------------------------------------------------------
-- v_sw_annual_report_data
-- Aggregate data for annual report generation
-- ----------------------------------------------------------------------------
CREATE VIEW v_sw_annual_report_data AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,
    strftime('%Y', i.inspection_date) AS report_year,

    -- Storm event counts
    (SELECT COUNT(*) FROM sw_storm_events se
     WHERE se.establishment_id = e.id
       AND strftime('%Y', se.storm_start_datetime) = strftime('%Y', i.inspection_date)) AS total_storm_events,

    (SELECT COUNT(*) FROM sw_storm_events se
     WHERE se.establishment_id = e.id
       AND se.is_qualifying_event = 1
       AND strftime('%Y', se.storm_start_datetime) = strftime('%Y', i.inspection_date)) AS qualifying_storm_events,

    -- Inspection counts
    COUNT(DISTINCT i.id) AS total_inspections,
    SUM(CASE WHEN i.discharge_observed = 1 THEN 1 ELSE 0 END) AS inspections_with_discharge,
    SUM(CASE WHEN i.corrective_action_needed = 1 THEN 1 ELSE 0 END) AS inspections_needing_action,

    -- Observation concerns
    (SELECT COUNT(*) FROM sw_visual_observations vo
     INNER JOIN sw_outfall_inspections i2 ON vo.inspection_id = i2.id
     WHERE i2.establishment_id = e.id
       AND vo.is_concerning = 1
       AND strftime('%Y', i2.inspection_date) = strftime('%Y', i.inspection_date)) AS concerning_observations

FROM sw_outfall_inspections i
INNER JOIN establishments e ON i.establishment_id = e.id
GROUP BY e.id, e.name, strftime('%Y', i.inspection_date)
ORDER BY e.name, report_year DESC;


-- ----------------------------------------------------------------------------
-- v_sw_compliance_dashboard
-- High-level compliance overview
-- ----------------------------------------------------------------------------
CREATE VIEW v_sw_compliance_dashboard AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    -- Active outfalls
    (SELECT COUNT(*) FROM swppp_outfalls o
     WHERE o.establishment_id = e.id AND o.is_active = 1) AS active_outfalls,

    -- Inspections last 90 days
    (SELECT COUNT(*) FROM sw_outfall_inspections i
     WHERE i.establishment_id = e.id
       AND i.inspection_date >= date('now', '-90 days')) AS inspections_last_90_days,

    -- Inspections needing follow-up
    (SELECT COUNT(*) FROM sw_outfall_inspections i
     WHERE i.establishment_id = e.id
       AND i.requires_follow_up = 1
       AND i.follow_up_date >= date('now')) AS pending_follow_ups,

    -- Overdue inspections
    (SELECT COUNT(*) FROM v_sw_inspections_due vid
     WHERE vid.establishment_id = e.id
       AND vid.urgency = 'OVERDUE') AS overdue_inspections,

    -- Storm events last 90 days
    (SELECT COUNT(*) FROM sw_storm_events se
     WHERE se.establishment_id = e.id
       AND se.storm_start_datetime >= datetime('now', '-90 days')) AS storm_events_last_90_days,

    -- Qualifying events last 90 days
    (SELECT COUNT(*) FROM sw_storm_events se
     WHERE se.establishment_id = e.id
       AND se.is_qualifying_event = 1
       AND se.storm_start_datetime >= datetime('now', '-90 days')) AS qualifying_events_last_90_days,

    -- Annual report status
    (SELECT status FROM sw_annual_reports ar
     WHERE ar.establishment_id = e.id
     ORDER BY ar.report_year DESC LIMIT 1) AS latest_annual_report_status

FROM establishments e;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-calculate hours_after_storm when inspection is linked to storm event
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_sw_calculate_hours_after_storm
AFTER INSERT ON sw_outfall_inspections
FOR EACH ROW
WHEN NEW.storm_event_id IS NOT NULL
BEGIN
    UPDATE sw_outfall_inspections
    SET
        hours_after_storm =
            ROUND((julianday(NEW.inspection_date || ' ' || COALESCE(NEW.inspection_time, '12:00')) -
                   julianday((SELECT storm_start_datetime FROM sw_storm_events WHERE id = NEW.storm_event_id))) * 24, 1),
        within_72_hours =
            CASE WHEN (julianday(NEW.inspection_date || ' ' || COALESCE(NEW.inspection_time, '12:00')) -
                       julianday((SELECT storm_start_datetime FROM sw_storm_events WHERE id = NEW.storm_event_id))) * 24 <= 72
                 THEN 1 ELSE 0 END,
        updated_at = datetime('now')
    WHERE id = NEW.id;
END;


-- ----------------------------------------------------------------------------
-- Update next scheduled date after inspection is completed
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_sw_update_schedule_after_inspection
AFTER INSERT ON sw_outfall_inspections
FOR EACH ROW
BEGIN
    -- For monthly inspections, schedule next month
    UPDATE sw_inspection_schedule
    SET
        next_scheduled_date = date(NEW.inspection_date, '+1 month', 'start of month'),
        updated_at = datetime('now')
    WHERE establishment_id = NEW.establishment_id
      AND outfall_id = NEW.outfall_id
      AND frequency_type = 'monthly'
      AND NEW.inspection_type = 'monthly';

    -- For quarterly inspections, schedule next quarter
    UPDATE sw_inspection_schedule
    SET
        next_scheduled_date = date(NEW.inspection_date, '+3 months', 'start of month'),
        updated_at = datetime('now')
    WHERE establishment_id = NEW.establishment_id
      AND outfall_id = NEW.outfall_id
      AND frequency_type = 'quarterly'
      AND NEW.inspection_type = 'quarterly';
END;


-- ----------------------------------------------------------------------------
-- Auto-calculate storm duration if end time provided
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_sw_calculate_storm_duration
AFTER INSERT ON sw_storm_events
FOR EACH ROW
WHEN NEW.storm_end_datetime IS NOT NULL
BEGIN
    UPDATE sw_storm_events
    SET
        duration_hours = ROUND((julianday(NEW.storm_end_datetime) - julianday(NEW.storm_start_datetime)) * 24, 1),
        updated_at = datetime('now')
    WHERE id = NEW.id;
END;


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================
/*
-- 1. Log a qualifying storm event
INSERT INTO sw_storm_events
    (establishment_id, storm_start_datetime, storm_end_datetime,
     rainfall_amount, rainfall_units, rainfall_estimated, rainfall_source,
     is_qualifying_event, qualifying_criteria)
VALUES
    (1, '2025-12-01 14:30', '2025-12-01 16:45',
     0.35, 'inches', 1, 'estimated',
     1, 'Exceeds 0.1 inch minimum threshold per NPDES permit');

-- 2. Record an outfall inspection during storm event
INSERT INTO sw_outfall_inspections
    (establishment_id, outfall_id, inspection_date, inspection_time,
     inspected_by_employee_id, inspection_type, storm_event_id,
     weather_at_inspection, discharge_observed, overall_condition)
VALUES
    (1, 1, '2025-12-02', '08:30', 1, 'storm_event', 1,
     'cloudy', 1, 'satisfactory');

-- 3. Add visual observations for that inspection
INSERT INTO sw_visual_observations
    (inspection_id, parameter_id, observation_value, is_concerning)
VALUES
    (last_insert_rowid(), 1, 'Yes', 0),  -- Discharge present
    (last_insert_rowid(), 2, 'Light Brown', 0),  -- Color
    (last_insert_rowid(), 3, 'None', 0),  -- Odor
    (last_insert_rowid(), 4, 'None', 0),  -- Sheen
    (last_insert_rowid(), 5, 'Minor', 0),  -- Floatables
    (last_insert_rowid(), 6, 'Slightly Cloudy', 0),  -- Turbidity
    (last_insert_rowid(), 8, 'None', 0);  -- Erosion

-- 4. Check what inspections are due
SELECT * FROM v_sw_inspections_due
WHERE establishment_id = 1
  AND urgency IN ('OVERDUE', 'DUE_THIS_WEEK')
ORDER BY next_scheduled_date;

-- 5. Review storm event compliance
SELECT * FROM v_sw_storm_event_compliance
WHERE establishment_id = 1
  AND compliance_status = 'NON-COMPLIANT';

-- 6. Get data for annual report
SELECT * FROM v_sw_annual_report_data
WHERE establishment_id = 1
  AND report_year = '2025';

-- 7. Find concerning observations that need attention
SELECT * FROM v_sw_concerning_observations
WHERE establishment_id = 1
ORDER BY inspection_date DESC;

-- 8. Setup inspection schedule for an outfall
INSERT INTO sw_inspection_schedule
    (establishment_id, outfall_id, frequency_type, within_hours_of_storm,
     next_scheduled_date, permit_id)
VALUES
    (1, 1, 'monthly', NULL, date('now', 'start of month', '+1 month'), 1),
    (1, 1, 'quarterly', NULL, date('now', 'start of month', '+3 months'), 1),
    (1, 1, 'storm_event', 72, NULL, 1);

-- 9. Get compliance dashboard
SELECT * FROM v_sw_compliance_dashboard
WHERE establishment_id = 1;

-- 10. Find inspections needing follow-up
SELECT
    i.inspection_date,
    o.outfall_name,
    i.follow_up_date,
    i.corrective_action_description,
    julianday(i.follow_up_date) - julianday('now') AS days_until_followup
FROM sw_outfall_inspections i
INNER JOIN swppp_outfalls o ON i.outfall_id = o.id
WHERE i.establishment_id = 1
  AND i.requires_follow_up = 1
  AND i.follow_up_date >= date('now')
ORDER BY i.follow_up_date;

-- 11. Create annual report record
INSERT INTO sw_annual_reports
    (establishment_id, permit_id, report_year,
     period_start_date, period_end_date, report_due_date)
SELECT
    1,  -- establishment_id
    1,  -- permit_id
    2025,  -- report_year
    '2025-01-01',
    '2025-12-31',
    '2026-01-31';  -- Typically due 30 days after year end

-- Then update with calculated statistics
UPDATE sw_annual_reports
SET
    total_storm_events = (SELECT total_storm_events FROM v_sw_annual_report_data
                          WHERE establishment_id = 1 AND report_year = '2025'),
    qualifying_storm_events = (SELECT qualifying_storm_events FROM v_sw_annual_report_data
                               WHERE establishment_id = 1 AND report_year = '2025'),
    total_inspections_conducted = (SELECT total_inspections FROM v_sw_annual_report_data
                                   WHERE establishment_id = 1 AND report_year = '2025')
WHERE establishment_id = 1 AND report_year = 2025;
*/


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
STORMWATER MONITORING MODULE (006d_stormwater.sql)

PURPOSE:
Track visual discharge monitoring for NPDES stormwater general permits.
Focused on qualitative observations (not analytical sampling).

REFERENCE TABLES:
    - sw_observation_parameters: Standard EPA MSGP visual parameters (10 pre-seeded)

CORE TABLES:
    - sw_storm_events: Qualifying storm events that trigger inspections
    - sw_outfall_inspections: Visual monitoring of outfalls (anchor table)
    - sw_visual_observations: Individual observations per inspection
    - sw_inspection_schedule: Recurring inspection requirements

REPORTING TABLES:
    - sw_annual_reports: Annual stormwater report submissions

VIEWS:
    - v_sw_inspections_due: Upcoming/overdue inspections
    - v_sw_storm_event_compliance: 72-hour inspection compliance
    - v_sw_inspection_summary: Summary by outfall and type
    - v_sw_concerning_observations: Flagged observations needing attention
    - v_sw_annual_report_data: Aggregate data for annual reports
    - v_sw_compliance_dashboard: High-level overview

TRIGGERS:
    - trg_sw_calculate_hours_after_storm: Auto-calc time between storm and inspection
    - trg_sw_update_schedule_after_inspection: Update next scheduled date
    - trg_sw_calculate_storm_duration: Auto-calc storm duration

PRE-SEEDED DATA:
    Visual Observation Parameters (10 standard MSGP parameters):
        - Discharge Present (yes/no)
        - Color (descriptive)
        - Odor (severity)
        - Sheen (severity)
        - Floatables (severity)
        - Suspended Solids/Turbidity (descriptive)
        - Foam (severity)
        - Erosion (severity)
        - Flow Rate (descriptive)
        - Outfall Condition (descriptive)

KEY FEATURES:
    1. Storm event tracking with qualifying thresholds
    2. 72-hour inspection compliance verification
    3. Qualitative observations (not quantitative analytical data)
    4. Monthly/quarterly/storm-event inspection types
    5. Visual observation standardization across permits
    6. Annual report data aggregation
    7. Follow-up tracking for concerning observations
    8. Photo documentation support

INTEGRATION POINTS:
    - establishments (001): Multi-site support
    - employees (001): Who inspected
    - permits (006): Link to NPDES stormwater permit
    - swppp_outfalls (005): Outfall definitions
    - corrective_actions (005): Findings can generate CARs
    - inspections (005): BMP inspections stay in 005, visual monitoring in 006d

REGULATORY DRIVERS:
    - EPA MSGP (Multi-Sector General Permit)
    - State NPDES stormwater general permits
    - 40 CFR 122.26 (Stormwater discharge)
    - Visual monitoring requirements (monthly/quarterly)
    - Annual reporting requirements

DESIGN DECISIONS:
    1. Qualitative observations (text) not quantitative results (numeric)
    2. Storm events as separate entity to prove "qualifying event"
    3. 72-hour compliance calculated automatically
    4. Visual parameters pre-seeded with typical values for consistency
    5. Inspection schedule separate from events (recurring vs. one-time)
    6. Links to existing SWPPP framework in 005 (avoids duplication)

DIFFERENCE FROM 006c (INDUSTRIAL WASTEWATER):
    - 006c = Analytical monitoring (numeric results, lab samples, limits)
    - 006d = Visual monitoring (descriptive observations, photos, concerns)
    - Both follow similar pattern: configuration → events → observations

NEXT STEPS (Future Enhancements):
    - Photo analysis/OCR for documentation
    - Weather API integration for automatic rainfall data
    - Inspection reminder notifications
    - Mobile app integration for field inspections
    - Heat map visualization of concerning observations
*/
