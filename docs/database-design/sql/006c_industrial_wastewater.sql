-- Waypoint-EHS - Industrial Wastewater Monitoring Schema
-- Tracks industrial wastewater discharge monitoring, lab results, and compliance
-- with discharge limits (POTW, NPDES, or voluntary monitoring programs).
--
-- Regulatory References:
--   Clean Water Act - NPDES permits, pretreatment requirements
--   40 CFR 403 - General Pretreatment Regulations
--   State/Local programs - POTW discharge requirements
--
-- Design Philosophy:
--   - Configurable monitoring requirements per facility
--   - Sample event as anchor with multiple parameter results
--   - Lab tracking for chain of custody and external certifications
--   - Equipment calibration tracking for field instruments
--   - Flow measurement support for facilities that track discharge volume
--
-- Connects to:
--   - establishments (001_incidents.sql)
--   - employees (001_incidents.sql) - who sampled, who calibrated
--   - permits (006_permits.sql) - links to NPDES/pretreatment permits
--   - corrective_actions (005_inspections_audits.sql) - for exceedances

-- ============================================================================
-- MONITORING LOCATIONS
-- ============================================================================
-- Sample points within the facility. Could be outfalls, internal sampling points,
-- or equipment locations (clarifiers, separators, etc.).

CREATE TABLE IF NOT EXISTS ww_monitoring_locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    location_code TEXT NOT NULL,            -- 'COMP-TANK', 'CLARIFIER', 'OUTFALL-001'
    location_name TEXT,
    location_type TEXT,                     -- 'outfall', 'internal_sample_point', 'equipment'
    description TEXT,

    -- Geographic info (optional)
    latitude REAL,
    longitude REAL,

    -- Permit reference (if this location is in a permit)
    permit_id INTEGER,                      -- NULL for voluntary monitoring points

    -- Status
    is_active INTEGER DEFAULT 1,
    installation_date TEXT,                 -- When this location was established
    decommission_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    UNIQUE(establishment_id, location_code)
);

CREATE INDEX idx_ww_locations_establishment ON ww_monitoring_locations(establishment_id);
CREATE INDEX idx_ww_locations_permit ON ww_monitoring_locations(permit_id);


-- ============================================================================
-- WATER PARAMETERS
-- ============================================================================
-- Pollutants and parameters that can be tested (metals, conventional pollutants,
-- physical properties, etc.).

CREATE TABLE IF NOT EXISTS ww_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    parameter_code TEXT NOT NULL UNIQUE,    -- 'CR-T', 'NI-T', 'BOD5', 'TSS', 'PH'
    parameter_name TEXT NOT NULL,           -- 'Chromium (Total)', 'Nickel (Total)'
    parameter_category TEXT,                -- 'metal', 'conventional', 'physical', 'nutrient', 'other'

    cas_number TEXT,                        -- Chemical Abstracts Service number

    -- Typical measurement info
    typical_units TEXT,                     -- 'mg/L', 'μg/L', 'pH units', 'SU'
    typical_method TEXT,                    -- EPA method number (e.g., '200.7', '405.1')

    -- Lab requirements
    requires_certified_lab INTEGER DEFAULT 0,  -- 0=can be field measured, 1=needs certified lab

    -- Regulatory info
    priority_pollutant INTEGER DEFAULT 0,   -- Is this a CWA priority pollutant?
    toxic_pollutant INTEGER DEFAULT 0,      -- Is this a toxic pollutant?

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_ww_parameters_category ON ww_parameters(parameter_category);

-- Seed common parameters
INSERT OR IGNORE INTO ww_parameters
    (id, parameter_code, parameter_name, parameter_category, cas_number, typical_units, typical_method,
     requires_certified_lab, priority_pollutant, toxic_pollutant) VALUES
    -- Metals (Total)
    (1, 'CD-T', 'Cadmium (Total)', 'metal', '7440-43-9', 'mg/L', 'EPA 200.7', 1, 1, 1),
    (2, 'CR-T', 'Chromium (Total)', 'metal', '7440-47-3', 'mg/L', 'EPA 200.7', 1, 1, 1),
    (3, 'CR-HEX', 'Chromium (Hexavalent)', 'metal', '18540-29-9', 'mg/L', 'EPA 218.6', 1, 1, 1),
    (4, 'CU-T', 'Copper (Total)', 'metal', '7440-50-8', 'mg/L', 'EPA 200.7', 1, 1, 1),
    (5, 'CN-T', 'Cyanide (Total)', 'metal', '57-12-5', 'mg/L', 'EPA 335.4', 1, 1, 1),
    (6, 'PB-T', 'Lead (Total)', 'metal', '7439-92-1', 'mg/L', 'EPA 200.7', 1, 1, 1),
    (7, 'NI-T', 'Nickel (Total)', 'metal', '7440-02-0', 'mg/L', 'EPA 200.7', 1, 1, 1),
    (8, 'AG-T', 'Silver (Total)', 'metal', '7440-22-4', 'mg/L', 'EPA 200.7', 1, 1, 1),
    (9, 'ZN-T', 'Zinc (Total)', 'metal', '7440-66-6', 'mg/L', 'EPA 200.7', 1, 1, 1),

    -- Nutrients
    (10, 'NH3-N', 'Ammonia Nitrogen (as N)', 'nutrient', '7664-41-7', 'mg/L', 'EPA 350.1', 1, 0, 0),
    (11, 'P-T', 'Phosphorus (Total)', 'nutrient', '7723-14-0', 'mg/L', 'EPA 365.1', 1, 0, 0),
    (12, 'N-T', 'Nitrogen (Total)', 'nutrient', NULL, 'mg/L', 'EPA 351.2', 1, 0, 0),

    -- Conventional Pollutants
    (20, 'BOD5', 'Biochemical Oxygen Demand (5-day)', 'conventional', NULL, 'mg/L', 'EPA 405.1', 1, 0, 0),
    (21, 'TSS', 'Total Suspended Solids', 'conventional', NULL, 'mg/L', 'EPA 160.2', 1, 0, 0),
    (22, 'OG', 'Oil and Grease', 'conventional', NULL, 'mg/L', 'EPA 1664A', 1, 0, 0),

    -- Physical
    (30, 'PH', 'pH', 'physical', NULL, 'SU', 'EPA 150.1', 0, 0, 0),
    (31, 'TEMP', 'Temperature', 'physical', NULL, '°C', 'EPA 170.1', 0, 0, 0),
    (32, 'FLOW', 'Flow Rate', 'physical', NULL, 'MGD', 'Measured', 0, 0, 0);


-- ============================================================================
-- MONITORING REQUIREMENTS
-- ============================================================================
-- Configuration table: defines what must be tested, where, how often, and what
-- the limits are. Each facility configures this based on their permit or
-- voluntary monitoring program.

CREATE TABLE IF NOT EXISTS ww_monitoring_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,
    parameter_id INTEGER NOT NULL,

    -- Monitoring schedule
    frequency_type TEXT,                    -- 'daily', 'weekly', 'monthly', 'quarterly', 'annual'
    frequency_count INTEGER DEFAULT 1,      -- e.g., 2 for "2x weekly"

    -- Sample type
    sample_type TEXT,                       -- 'grab', 'composite', 'flow_proportional'

    -- Limits (all nullable - not all parameters have limits)
    limit_daily_max REAL,
    limit_monthly_avg REAL,
    limit_annual_avg REAL,
    limit_units TEXT,                       -- Should match parameter typical_units

    -- Regulatory basis
    is_permit_required INTEGER DEFAULT 0,   -- 0=voluntary, 1=permit requirement
    permit_id INTEGER,                      -- Which permit requires this
    permit_condition_id INTEGER,            -- Specific permit condition

    -- Dates
    effective_date TEXT,                    -- When this requirement starts
    end_date TEXT,                          -- NULL if ongoing

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (location_id) REFERENCES ww_monitoring_locations(id),
    FOREIGN KEY (parameter_id) REFERENCES ww_parameters(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    FOREIGN KEY (permit_condition_id) REFERENCES permit_conditions(id)
);

CREATE INDEX idx_ww_requirements_establishment ON ww_monitoring_requirements(establishment_id);
CREATE INDEX idx_ww_requirements_location ON ww_monitoring_requirements(location_id);
CREATE INDEX idx_ww_requirements_parameter ON ww_monitoring_requirements(parameter_id);
CREATE INDEX idx_ww_requirements_permit ON ww_monitoring_requirements(permit_id);


-- ============================================================================
-- SAMPLING EQUIPMENT
-- ============================================================================
-- Field instruments and lab equipment that need calibration tracking.

CREATE TABLE IF NOT EXISTS ww_equipment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    equipment_code TEXT NOT NULL,           -- 'PH-METER-01', 'COMPOSITE-SAMPLER-01'
    equipment_name TEXT,
    equipment_type TEXT,                    -- 'ph_meter', 'composite_sampler', 'flow_meter'

    manufacturer TEXT,
    model_number TEXT,
    serial_number TEXT,

    -- Calibration schedule
    calibration_frequency_days INTEGER,     -- How often to calibrate
    last_calibration_date TEXT,
    next_calibration_due TEXT,

    -- Status
    is_active INTEGER DEFAULT 1,
    purchase_date TEXT,
    retire_date TEXT,

    location TEXT,                          -- Where is this equipment normally stored/used

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, equipment_code)
);

CREATE INDEX idx_ww_equipment_establishment ON ww_equipment(establishment_id);
CREATE INDEX idx_ww_equipment_calibration_due ON ww_equipment(next_calibration_due);


-- ============================================================================
-- EQUIPMENT CALIBRATIONS
-- ============================================================================
-- Record of each calibration performed.

CREATE TABLE IF NOT EXISTS ww_equipment_calibrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    equipment_id INTEGER NOT NULL,

    calibration_date TEXT NOT NULL,         -- Format: YYYY-MM-DD
    calibration_time TEXT,                  -- Format: HH:MM

    calibrated_by_employee_id INTEGER,

    -- Calibration details
    calibration_standard_used TEXT,         -- e.g., "pH 7.0 buffer", "4.0 mg/L Ni standard"
    standard_lot_number TEXT,
    standard_expiration_date TEXT,

    -- Results
    passed INTEGER DEFAULT 1,               -- 0=failed, 1=passed
    pre_calibration_reading REAL,           -- What it read before calibration
    post_calibration_reading REAL,          -- What it reads after calibration
    expected_reading REAL,                  -- What standard should read

    -- Next calibration
    next_calibration_due TEXT,              -- Format: YYYY-MM-DD

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (equipment_id) REFERENCES ww_equipment(id),
    FOREIGN KEY (calibrated_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_ww_calibrations_equipment ON ww_equipment_calibrations(equipment_id);
CREATE INDEX idx_ww_calibrations_date ON ww_equipment_calibrations(calibration_date);


-- ============================================================================
-- LAB CERTIFICATIONS
-- ============================================================================
-- External labs and their certifications. Useful for tracking which labs can
-- perform which analyses and ensuring they're properly certified.

CREATE TABLE IF NOT EXISTS ww_labs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    lab_name TEXT NOT NULL,
    lab_code TEXT UNIQUE,                   -- Short code for easy reference

    -- Contact info
    street_address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    phone TEXT,
    website TEXT,
    primary_contact_name TEXT,
    primary_contact_email TEXT,

    -- Certifications
    state_certification_number TEXT,
    nelac_certification TEXT,               -- National Environmental Laboratory Accreditation
    certification_expiration_date TEXT,

    -- Lab capabilities
    certified_parameters TEXT,              -- JSON array of parameter_codes they're certified for

    -- Status
    is_active INTEGER DEFAULT 1,
    is_preferred INTEGER DEFAULT 0,         -- Preferred vendor?

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_ww_labs_active ON ww_labs(is_active);


-- ============================================================================
-- LAB SUBMISSIONS
-- ============================================================================
-- Tracking samples sent to external labs. Multiple sampling events can be
-- included in one lab submission.

CREATE TABLE IF NOT EXISTS ww_lab_submissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    lab_id INTEGER NOT NULL,

    -- Identification
    submission_number TEXT,                 -- Internal tracking number
    chain_of_custody_number TEXT,           -- COC form number

    -- Dates
    submitted_date TEXT NOT NULL,           -- When samples were sent/dropped off
    received_by_lab_date TEXT,              -- When lab received them
    report_due_date TEXT,                   -- Expected turnaround
    report_received_date TEXT,              -- When we got results back

    -- Lab info
    lab_project_number TEXT,                -- Lab's internal job number
    lab_contact_name TEXT,

    -- Documents
    coc_document_path TEXT,                 -- Scanned COC form
    lab_report_path TEXT,                   -- Lab report PDF

    -- Status
    status TEXT DEFAULT 'submitted',        -- 'submitted', 'received_by_lab', 'results_received', 'cancelled'

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (lab_id) REFERENCES ww_labs(id)
);

CREATE INDEX idx_ww_lab_submissions_establishment ON ww_lab_submissions(establishment_id);
CREATE INDEX idx_ww_lab_submissions_lab ON ww_lab_submissions(lab_id);
CREATE INDEX idx_ww_lab_submissions_status ON ww_lab_submissions(status);


-- ============================================================================
-- SAMPLING EVENTS (Anchor Table)
-- ============================================================================
-- Each sampling event represents one trip to collect samples. Multiple parameters
-- are tested from each event.

CREATE TABLE IF NOT EXISTS ww_sampling_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,

    -- Event identification
    event_number TEXT,                      -- Optional internal tracking number

    -- When and who
    sample_date TEXT NOT NULL,              -- Format: YYYY-MM-DD
    sample_time TEXT,                       -- Format: HH:MM (24-hour)
    sampled_by_employee_id INTEGER,

    -- Sample details
    sample_type TEXT,                       -- 'grab', 'composite'
    composite_period_hours REAL,            -- If composite, how many hours

    -- Weather (relevant for some permits)
    weather_conditions TEXT,                -- 'dry', 'rain', 'snow'

    -- Equipment used
    equipment_id INTEGER,                   -- Sampler or meter used (if field measurement)

    -- Lab submission (if samples sent to external lab)
    lab_submission_id INTEGER,

    -- Photo/documentation
    photo_paths TEXT,                       -- JSON array of photo file paths

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (location_id) REFERENCES ww_monitoring_locations(id),
    FOREIGN KEY (sampled_by_employee_id) REFERENCES employees(id),
    FOREIGN KEY (equipment_id) REFERENCES ww_equipment(id),
    FOREIGN KEY (lab_submission_id) REFERENCES ww_lab_submissions(id)
);

CREATE INDEX idx_ww_events_establishment ON ww_sampling_events(establishment_id);
CREATE INDEX idx_ww_events_location ON ww_sampling_events(location_id);
CREATE INDEX idx_ww_events_date ON ww_sampling_events(sample_date);
CREATE INDEX idx_ww_events_lab_submission ON ww_sampling_events(lab_submission_id);


-- ============================================================================
-- SAMPLE RESULTS
-- ============================================================================
-- Individual test results. Each result is one parameter from one sampling event.
-- This is where actual data lives.

CREATE TABLE IF NOT EXISTS ww_sample_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id INTEGER NOT NULL,
    parameter_id INTEGER NOT NULL,

    -- Result
    result_value REAL,                      -- Numeric value (NULL if non-detect)
    result_units TEXT NOT NULL,             -- Should match parameter's typical_units

    -- Lab qualifiers (if from certified lab)
    result_qualifier TEXT,                  -- 'ND', 'J', 'U', '<', '>', etc.
    detection_limit REAL,                   -- Method detection limit
    reporting_limit REAL,                   -- Practical quantitation limit

    -- Analysis details
    analyzed_date TEXT,                     -- When was this sample analyzed (may differ from sample_date)
    analyzed_by TEXT,                       -- 'field' or lab name
    analysis_method TEXT,                   -- EPA method number

    -- QA/QC
    is_duplicate INTEGER DEFAULT 0,         -- Is this a duplicate sample?
    duplicate_of_result_id INTEGER,         -- If duplicate, which result is it duplicating?
    is_blank INTEGER DEFAULT 0,             -- Is this a blank sample?

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (event_id) REFERENCES ww_sampling_events(id) ON DELETE CASCADE,
    FOREIGN KEY (parameter_id) REFERENCES ww_parameters(id),
    FOREIGN KEY (duplicate_of_result_id) REFERENCES ww_sample_results(id)
);

CREATE INDEX idx_ww_results_event ON ww_sample_results(event_id);
CREATE INDEX idx_ww_results_parameter ON ww_sample_results(parameter_id);
CREATE INDEX idx_ww_results_date ON ww_sample_results(analyzed_date);


-- ============================================================================
-- FLOW MEASUREMENTS
-- ============================================================================
-- Optional table for facilities that track discharge flow/volume.
-- Some permits require flow monitoring, others don't.

CREATE TABLE IF NOT EXISTS ww_flow_measurements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,

    measurement_date TEXT NOT NULL,         -- Format: YYYY-MM-DD
    measurement_time TEXT,                  -- Format: HH:MM

    -- Flow data
    flow_rate REAL,
    flow_units TEXT,                        -- 'MGD', 'GPM', 'GPD', 'liters/min'

    -- Measurement method
    measurement_method TEXT,                -- 'meter', 'calculated', 'estimated', 'totalizer'
    meter_reading REAL,                     -- If using totalizer/meter

    -- Equipment
    equipment_id INTEGER,                   -- Flow meter used

    -- Daily total (if calculating)
    daily_total_volume REAL,
    daily_total_units TEXT,                 -- 'gallons', 'cubic_meters'

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (location_id) REFERENCES ww_monitoring_locations(id),
    FOREIGN KEY (equipment_id) REFERENCES ww_equipment(id)
);

CREATE INDEX idx_ww_flow_establishment ON ww_flow_measurements(establishment_id);
CREATE INDEX idx_ww_flow_location ON ww_flow_measurements(location_id);
CREATE INDEX idx_ww_flow_date ON ww_flow_measurements(measurement_date);


-- ============================================================================
-- VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- v_ww_results_with_limits
-- Show all results alongside their applicable limits for easy compliance checking
-- ----------------------------------------------------------------------------
CREATE VIEW v_ww_results_with_limits AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    se.id AS event_id,
    se.event_number,
    se.sample_date,
    se.sample_time,

    ml.location_code,
    ml.location_name,

    p.parameter_code,
    p.parameter_name,

    sr.result_value,
    sr.result_units,
    sr.result_qualifier,
    sr.detection_limit,
    sr.reporting_limit,

    mr.limit_daily_max,
    mr.limit_monthly_avg,
    mr.limit_units,

    -- Compliance check
    CASE
        WHEN mr.limit_daily_max IS NOT NULL AND sr.result_value > mr.limit_daily_max
            THEN 1
        ELSE 0
    END AS exceeds_daily_max,

    -- Percent of limit
    CASE
        WHEN mr.limit_daily_max IS NOT NULL AND mr.limit_daily_max > 0
            THEN ROUND((sr.result_value / mr.limit_daily_max) * 100, 1)
        ELSE NULL
    END AS percent_of_limit,

    sr.analyzed_by,
    sr.notes

FROM ww_sample_results sr
INNER JOIN ww_sampling_events se ON sr.event_id = se.id
INNER JOIN establishments e ON se.establishment_id = e.id
INNER JOIN ww_monitoring_locations ml ON se.location_id = ml.id
INNER JOIN ww_parameters p ON sr.parameter_id = p.id
LEFT JOIN ww_monitoring_requirements mr ON
    se.establishment_id = mr.establishment_id AND
    se.location_id = mr.location_id AND
    sr.parameter_id = mr.parameter_id AND
    (mr.end_date IS NULL OR se.sample_date <= mr.end_date) AND
    se.sample_date >= mr.effective_date;


-- ----------------------------------------------------------------------------
-- v_ww_exceedances
-- Only show results that exceeded limits
-- ----------------------------------------------------------------------------
CREATE VIEW v_ww_exceedances AS
SELECT * FROM v_ww_results_with_limits
WHERE exceeds_daily_max = 1
ORDER BY sample_date DESC;


-- ----------------------------------------------------------------------------
-- v_ww_calibrations_due
-- Equipment needing calibration soon
-- ----------------------------------------------------------------------------
CREATE VIEW v_ww_calibrations_due AS
SELECT
    e.id AS establishment_id,
    eq.id AS equipment_id,
    eq.equipment_code,
    eq.equipment_name,
    eq.equipment_type,
    eq.last_calibration_date,
    eq.next_calibration_due,

    julianday(eq.next_calibration_due) - julianday('now') AS days_until_due,

    CASE
        WHEN eq.next_calibration_due < date('now') THEN 'OVERDUE'
        WHEN eq.next_calibration_due <= date('now', '+7 days') THEN 'DUE_THIS_WEEK'
        WHEN eq.next_calibration_due <= date('now', '+30 days') THEN 'DUE_THIS_MONTH'
        ELSE 'UPCOMING'
    END AS urgency

FROM ww_equipment eq
INNER JOIN establishments e ON eq.establishment_id = e.id
WHERE eq.is_active = 1
  AND eq.next_calibration_due IS NOT NULL
ORDER BY eq.next_calibration_due;


-- ----------------------------------------------------------------------------
-- v_ww_sampling_schedule
-- What monitoring is required, when, and at which locations
-- ----------------------------------------------------------------------------
CREATE VIEW v_ww_sampling_schedule AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    ml.location_code,
    ml.location_name,

    p.parameter_code,
    p.parameter_name,

    mr.frequency_type,
    mr.frequency_count,
    mr.sample_type,

    mr.limit_daily_max,
    mr.limit_monthly_avg,
    mr.limit_units,

    CASE WHEN mr.is_permit_required = 1 THEN 'Required' ELSE 'Voluntary' END AS requirement_type,

    perm.permit_number,

    mr.notes

FROM ww_monitoring_requirements mr
INNER JOIN establishments e ON mr.establishment_id = e.id
INNER JOIN ww_monitoring_locations ml ON mr.location_id = ml.id
INNER JOIN ww_parameters p ON mr.parameter_id = p.id
LEFT JOIN permits perm ON mr.permit_id = perm.id
WHERE mr.end_date IS NULL OR mr.end_date >= date('now')
ORDER BY e.name, ml.location_code, p.parameter_name;


-- ----------------------------------------------------------------------------
-- v_ww_lab_submissions_summary
-- Track status of lab submissions
-- ----------------------------------------------------------------------------
CREATE VIEW v_ww_lab_submissions_summary AS
SELECT
    ls.id AS submission_id,
    ls.submission_number,
    ls.chain_of_custody_number,

    e.name AS establishment_name,
    lab.lab_name,

    ls.submitted_date,
    ls.received_by_lab_date,
    ls.report_due_date,
    ls.report_received_date,

    ls.status,

    -- How many samples in this submission
    (SELECT COUNT(DISTINCT se.id)
     FROM ww_sampling_events se
     WHERE se.lab_submission_id = ls.id) AS sample_count,

    -- Days since submission
    julianday('now') - julianday(ls.submitted_date) AS days_since_submission,

    -- Days until report due
    julianday(ls.report_due_date) - julianday('now') AS days_until_due,

    CASE
        WHEN ls.status = 'results_received' THEN 'COMPLETE'
        WHEN ls.report_due_date < date('now') THEN 'OVERDUE'
        WHEN ls.report_due_date <= date('now', '+3 days') THEN 'DUE_SOON'
        ELSE 'ON_TRACK'
    END AS urgency

FROM ww_lab_submissions ls
INNER JOIN establishments e ON ls.establishment_id = e.id
INNER JOIN ww_labs lab ON ls.lab_id = lab.id
ORDER BY ls.submitted_date DESC;


-- ----------------------------------------------------------------------------
-- v_ww_compliance_summary
-- High-level summary by establishment
-- ----------------------------------------------------------------------------
CREATE VIEW v_ww_compliance_summary AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    -- Sample counts
    (SELECT COUNT(*) FROM ww_sampling_events se
     WHERE se.establishment_id = e.id
       AND se.sample_date >= date('now', '-12 months')) AS samples_last_12_months,

    -- Result counts
    (SELECT COUNT(*) FROM ww_sample_results sr
     INNER JOIN ww_sampling_events se ON sr.event_id = se.id
     WHERE se.establishment_id = e.id
       AND se.sample_date >= date('now', '-12 months')) AS results_last_12_months,

    -- Exceedances
    (SELECT COUNT(*) FROM v_ww_exceedances ex
     WHERE ex.establishment_id = e.id
       AND ex.sample_date >= date('now', '-12 months')) AS exceedances_last_12_months,

    -- Equipment needing calibration
    (SELECT COUNT(*) FROM ww_equipment eq
     WHERE eq.establishment_id = e.id
       AND eq.is_active = 1
       AND eq.next_calibration_due <= date('now', '+30 days')) AS calibrations_due_30_days,

    -- Pending lab submissions
    (SELECT COUNT(*) FROM ww_lab_submissions ls
     WHERE ls.establishment_id = e.id
       AND ls.status IN ('submitted', 'received_by_lab')) AS pending_lab_results

FROM establishments e;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-update next calibration due date when calibration is performed
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_ww_update_equipment_calibration
AFTER INSERT ON ww_equipment_calibrations
FOR EACH ROW
WHEN NEW.passed = 1
BEGIN
    UPDATE ww_equipment
    SET
        last_calibration_date = NEW.calibration_date,
        next_calibration_due = NEW.next_calibration_due,
        updated_at = datetime('now')
    WHERE id = NEW.equipment_id;
END;


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================
/*
-- 1. Get all sampling results for a specific date range with limits
SELECT * FROM v_ww_results_with_limits
WHERE establishment_id = 1
  AND sample_date BETWEEN '2025-01-01' AND '2025-03-31'
ORDER BY sample_date, location_code, parameter_name;

-- 2. Find all exceedances
SELECT * FROM v_ww_exceedances
WHERE establishment_id = 1
ORDER BY sample_date DESC;

-- 3. Check what's due for sampling this month (manual query based on schedule)
SELECT * FROM v_ww_sampling_schedule
WHERE establishment_id = 1
  AND frequency_type IN ('monthly', 'quarterly');

-- 4. Track lab submissions
SELECT * FROM v_ww_lab_submissions_summary
WHERE establishment_id = 1
  AND status != 'results_received'
ORDER BY urgency DESC, submitted_date;

-- 5. Equipment needing calibration
SELECT * FROM v_ww_calibrations_due
WHERE establishment_id = 1
  AND urgency IN ('OVERDUE', 'DUE_THIS_WEEK');

-- 6. Calculate monthly averages for a parameter
SELECT
    strftime('%Y-%m', se.sample_date) AS month,
    ml.location_code,
    p.parameter_name,
    ROUND(AVG(sr.result_value), 2) AS monthly_avg,
    mr.limit_monthly_avg,
    CASE
        WHEN AVG(sr.result_value) > mr.limit_monthly_avg THEN 'EXCEEDS'
        ELSE 'COMPLIANT'
    END AS status
FROM ww_sample_results sr
INNER JOIN ww_sampling_events se ON sr.event_id = se.id
INNER JOIN ww_monitoring_locations ml ON se.location_id = ml.id
INNER JOIN ww_parameters p ON sr.parameter_id = p.id
LEFT JOIN ww_monitoring_requirements mr ON
    se.establishment_id = mr.establishment_id AND
    se.location_id = mr.location_id AND
    sr.parameter_id = mr.parameter_id
WHERE se.establishment_id = 1
  AND p.parameter_code = 'CR-T'
  AND se.sample_date >= date('now', '-12 months')
GROUP BY strftime('%Y-%m', se.sample_date), ml.location_code, p.parameter_name
ORDER BY month DESC;

-- 7. Add a new monitoring requirement
INSERT INTO ww_monitoring_requirements
    (establishment_id, location_id, parameter_id, frequency_type, frequency_count,
     sample_type, limit_daily_max, limit_units, is_permit_required, effective_date)
VALUES
    (1, 1, 2, 'weekly', 1, 'grab', 1.00, 'mg/L', 0, '2025-01-01');

-- 8. Record a sampling event with results
-- First, create the event
INSERT INTO ww_sampling_events
    (establishment_id, location_id, sample_date, sample_time,
     sampled_by_employee_id, sample_type)
VALUES
    (1, 1, '2025-12-02', '08:30', 1, 'grab');

-- Then add results (multiple inserts, one per parameter)
INSERT INTO ww_sample_results
    (event_id, parameter_id, result_value, result_units, analyzed_by)
VALUES
    (last_insert_rowid(), 2, 0.45, 'mg/L', 'field'),  -- Chromium
    (last_insert_rowid(), 7, 0.62, 'mg/L', 'field'),  -- Nickel
    (last_insert_rowid(), 11, 3.2, 'mg/L', 'field');  -- Phosphorus

-- 9. Get compliance summary
SELECT * FROM v_ww_compliance_summary
WHERE establishment_id = 1;
*/


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
INDUSTRIAL WASTEWATER MODULE (006c_industrial_wastewater.sql)

PURPOSE:
Track industrial wastewater discharge monitoring, analytical results, and
compliance with discharge limits (NPDES, POTW pretreatment, or voluntary programs).

CONFIGURATION TABLES:
    - ww_monitoring_locations: Sample points (outfalls, internal points, equipment)
    - ww_parameters: Pollutants and parameters that can be tested
    - ww_monitoring_requirements: What must be tested, where, how often, and limits
    - ww_equipment: Field instruments requiring calibration
    - ww_labs: External certified laboratories

OPERATIONAL TABLES:
    - ww_sampling_events: Anchor table - each sample collection trip
    - ww_sample_results: Individual test results (one row per parameter per event)
    - ww_equipment_calibrations: Calibration records for field equipment
    - ww_lab_submissions: Tracking samples sent to external labs
    - ww_flow_measurements: Optional flow/discharge volume tracking

VIEWS:
    - v_ww_results_with_limits: All results with applicable limits for compliance
    - v_ww_exceedances: Results that exceeded limits
    - v_ww_calibrations_due: Equipment needing calibration
    - v_ww_sampling_schedule: What monitoring is required
    - v_ww_lab_submissions_summary: Track lab submission status
    - v_ww_compliance_summary: High-level metrics by establishment

TRIGGERS:
    - trg_ww_update_equipment_calibration: Update equipment calibration dates

PRE-SEEDED DATA:
    Parameters (32 common pollutants):
        Metals: Cd, Cr(Total), Cr(Hex), Cu, Cn, Pb, Ni, Ag, Zn
        Nutrients: NH3-N, P(Total), N(Total)
        Conventional: BOD5, TSS, Oil & Grease
        Physical: pH, Temperature, Flow

KEY FEATURES:
    1. Configurable per-facility monitoring requirements
    2. Sample event as anchor with multiple parameter results
    3. Lab chain of custody tracking
    4. Equipment calibration management
    5. Flow measurement support (optional)
    6. Automated exceedance detection
    7. Links to permit conditions
    8. Monthly averaging calculations

INTEGRATION POINTS:
    - establishments (001): Multi-site support
    - employees (001): Who sampled, who calibrated
    - permits (006): Link monitoring to permit conditions
    - permit_deviations (006): Exceedances can trigger deviation records
    - corrective_actions (005): Exceedances can generate CARs

REGULATORY DRIVERS:
    - Clean Water Act (NPDES permits, pretreatment)
    - 40 CFR 403 (General Pretreatment Regulations)
    - State/local POTW discharge requirements
    - Voluntary environmental monitoring programs

DESIGN DECISIONS:
    1. One result per parameter per event (not "wide table")
    2. Limits stored in monitoring_requirements (configured once)
    3. Lab submissions separate from events (multiple events per submission)
    4. Equipment calibration as separate module (reusable pattern)
    5. Flow measurements optional (not all facilities need this)

NEXT STEPS (Future Enhancements):
    - DMR (Discharge Monitoring Report) generation
    - Automated report submission tracking
    - Statistical analysis (geometric means, percentiles)
    - Trend charts and control charts
    - Integration with POTW limits database
    - Automated sampling schedule generation
*/
