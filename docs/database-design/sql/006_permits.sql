-- Waypoint-EHS - Permits Schema
-- Tracks environmental and operational permits with conditions, limits,
-- monitoring requirements, and reporting obligations.
--
-- Regulatory References:
--   Clean Air Act - Title V, NSR, PSD permits
--   Clean Water Act - NPDES permits
--   RCRA - Hazardous waste permits
--   State programs - Delegated authority permits
--
-- Design Philosophy:
--   - Base permit structure first, then specific modules for air/water reporting
--   - Condition and limit tracking at granular level
--   - Compliance calendar integration
--   - Deviation/exceedance tracking
--
-- Connects to:
--   - establishments (001_incidents.sql)
--   - chemicals (002_chemicals.sql) - permitted chemicals/pollutants
--   - waste (004_waste.sql) - waste permits link to waste streams
--   - inspections (005_inspections_audits.sql) - permit inspections

-- ============================================================================
-- REGULATORY AGENCIES
-- ============================================================================
-- Agencies that issue permits. Needed because same permit type might come
-- from EPA, state agency, or local authority depending on delegation.

CREATE TABLE IF NOT EXISTS regulatory_agencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    agency_code TEXT NOT NULL UNIQUE,       -- 'EPA_R5', 'MDEQ', 'COUNTY_AQD'
    agency_name TEXT NOT NULL,
    agency_type TEXT,                       -- 'federal', 'state', 'local', 'tribal'
    
    -- Jurisdiction
    jurisdiction_state TEXT,                -- State code if state/local agency
    jurisdiction_region TEXT,               -- EPA region or local district
    
    -- Contact info
    street_address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    main_phone TEXT,
    website TEXT,
    
    -- Primary contacts by program
    air_contact_name TEXT,
    air_contact_phone TEXT,
    air_contact_email TEXT,
    
    water_contact_name TEXT,
    water_contact_phone TEXT,
    water_contact_email TEXT,
    
    waste_contact_name TEXT,
    waste_contact_phone TEXT,
    waste_contact_email TEXT,
    
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);


-- ============================================================================
-- PERMIT TYPES
-- ============================================================================
-- Categories of permits with their typical characteristics.

CREATE TABLE IF NOT EXISTS permit_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    type_code TEXT NOT NULL UNIQUE,         -- 'TITLE_V', 'NPDES', 'RCRA_TSDF'
    type_name TEXT NOT NULL,
    category TEXT NOT NULL,                 -- 'air', 'water', 'waste', 'other'
    
    description TEXT,
    
    -- Regulatory basis
    federal_authority TEXT,                 -- 'CAA Title V', 'CWA 402', 'RCRA 3005'
    
    -- Typical characteristics
    typical_term_years INTEGER,             -- How long permits typically last
    requires_renewal_application INTEGER DEFAULT 1,
    renewal_lead_time_days INTEGER,         -- How far ahead to apply for renewal
    
    -- Reporting characteristics
    has_periodic_reporting INTEGER DEFAULT 0,
    typical_reporting_frequency TEXT,       -- 'monthly', 'quarterly', 'semi-annual', 'annual'
    
    -- Monitoring characteristics
    has_monitoring_requirements INTEGER DEFAULT 0,
    
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- Seed common permit types
INSERT OR IGNORE INTO permit_types 
    (id, type_code, type_name, category, federal_authority, typical_term_years, 
     renewal_lead_time_days, has_periodic_reporting, typical_reporting_frequency, has_monitoring_requirements) VALUES
    -- Air Permits
    (1, 'TITLE_V', 'Title V Operating Permit', 'air', 'CAA Title V', 
        5, 180, 1, 'semi-annual', 1),
    (2, 'NSR_MAJOR', 'New Source Review - Major', 'air', 'CAA NSR', 
        NULL, 180, 1, 'annual', 1),
    (3, 'PSD', 'Prevention of Significant Deterioration', 'air', 'CAA PSD', 
        NULL, 180, 1, 'annual', 1),
    (4, 'MINOR_SOURCE', 'Minor Source Air Permit', 'air', 'CAA/State', 
        5, 90, 1, 'annual', 1),
    (5, 'PTI', 'Permit to Install', 'air', 'State', 
        NULL, 90, 0, NULL, 0),
    (6, 'GP_AIR', 'General Permit - Air', 'air', 'CAA/State', 
        5, 90, 1, 'annual', 0),
    
    -- Water Permits
    (10, 'NPDES_INDIVIDUAL', 'NPDES Individual Permit', 'water', 'CWA 402', 
        5, 180, 1, 'monthly', 1),
    (11, 'NPDES_GENERAL', 'NPDES General Permit (Industrial)', 'water', 'CWA 402', 
        5, 90, 1, 'quarterly', 1),
    (12, 'NPDES_STORMWATER', 'NPDES Stormwater (MSGP/CGP)', 'water', 'CWA 402', 
        5, 90, 1, 'annual', 1),
    (13, 'PRETREATMENT', 'Industrial Pretreatment Permit', 'water', 'CWA 307', 
        5, 180, 1, 'monthly', 1),
    (14, 'GWDP', 'Groundwater Discharge Permit', 'water', 'State', 
        5, 180, 1, 'quarterly', 1),
    
    -- Waste Permits
    (20, 'RCRA_TSDF', 'RCRA Part B (TSDF)', 'waste', 'RCRA 3005', 
        10, 365, 1, 'annual', 1),
    (21, 'RCRA_GENERATOR', 'RCRA Generator Notification', 'waste', 'RCRA 3010', 
        NULL, 0, 0, NULL, 0),
    (22, 'USED_OIL', 'Used Oil Handler Registration', 'waste', 'RCRA 279', 
        NULL, 0, 0, NULL, 0),
    
    -- Other
    (30, 'SPCC', 'SPCC Plan (Self-Certified)', 'other', '40 CFR 112', 
        5, 0, 0, NULL, 1),
    (31, 'RMP', 'Risk Management Plan', 'other', 'CAA 112(r)', 
        5, 0, 1, 'annual', 0),
    (32, 'TIER2', 'Tier II Notification', 'other', 'EPCRA 312', 
        1, 30, 1, 'annual', 0);


-- ============================================================================
-- PERMITS (Master Table)
-- ============================================================================
-- The core permit record.

CREATE TABLE IF NOT EXISTS permits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    permit_type_id INTEGER NOT NULL,
    issuing_agency_id INTEGER,
    
    -- Permit identification
    permit_number TEXT NOT NULL,            -- Official permit number
    permit_name TEXT,                       -- Descriptive name
    
    -- Application tracking
    application_date TEXT,
    application_number TEXT,
    
    -- Permit dates
    issue_date TEXT,
    effective_date TEXT,
    expiration_date TEXT,
    
    -- Renewal tracking
    renewal_application_date TEXT,
    renewal_application_number TEXT,
    renewal_status TEXT,                    -- 'not_started', 'in_progress', 'submitted', 'approved'
    
    -- For permits that don't expire but need periodic review
    last_review_date TEXT,
    next_review_date TEXT,
    
    -- Status
    status TEXT DEFAULT 'active',           -- 'draft', 'pending', 'active', 'expired', 'revoked', 'superseded'
    
    -- Permit tier/classification (for air permits especially)
    permit_classification TEXT,             -- 'major', 'minor', 'synthetic_minor', 'area_source'
    
    -- Coverage description
    coverage_description TEXT,              -- What operations/equipment the permit covers
    
    -- Fees
    annual_fee REAL,
    fee_due_date TEXT,                      -- Annual fee due date (MM-DD format or specific date)
    last_fee_paid_date TEXT,
    
    -- Document references
    permit_document_path TEXT,              -- Path to permit PDF
    application_document_path TEXT,
    
    -- Administrative
    permit_writer TEXT,                     -- Agency contact who wrote permit
    permit_writer_phone TEXT,
    permit_writer_email TEXT,
    
    -- Internal tracking
    internal_owner_id INTEGER,              -- Employee responsible for this permit
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (permit_type_id) REFERENCES permit_types(id),
    FOREIGN KEY (issuing_agency_id) REFERENCES regulatory_agencies(id),
    FOREIGN KEY (internal_owner_id) REFERENCES employees(id),
    UNIQUE(establishment_id, permit_number)
);

CREATE INDEX idx_permits_establishment ON permits(establishment_id);
CREATE INDEX idx_permits_type ON permits(permit_type_id);
CREATE INDEX idx_permits_status ON permits(status);
CREATE INDEX idx_permits_expiration ON permits(expiration_date);


-- ============================================================================
-- PERMIT CONDITIONS
-- ============================================================================
-- Individual conditions within a permit. Permits typically have dozens
-- of conditions covering everything from operational limits to recordkeeping.

CREATE TABLE IF NOT EXISTS permit_conditions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    permit_id INTEGER NOT NULL,
    
    -- Condition identification
    condition_number TEXT,                  -- 'I.A.1', 'II.B.3.a', etc.
    condition_title TEXT,
    
    -- Condition type
    condition_type TEXT NOT NULL,           -- 'emission_limit', 'operational_limit', 'monitoring', 
                                            -- 'recordkeeping', 'reporting', 'testing', 'general'
    
    -- The actual condition text
    condition_text TEXT NOT NULL,
    
    -- Applicability
    applies_to TEXT,                        -- What unit/process/pollutant this applies to
    emission_unit_id INTEGER,               -- Link to specific emission unit if applicable
    outfall_id INTEGER,                     -- Link to specific outfall if applicable
    
    -- Regulatory citation
    regulatory_basis TEXT,                  -- '40 CFR 63.xxx', 'State Rule xxx'
    
    -- Compliance method
    compliance_method TEXT,                 -- How compliance is demonstrated
    
    -- Frequency (for monitoring/reporting conditions)
    frequency TEXT,                         -- 'continuous', 'daily', 'weekly', 'monthly', etc.
    
    -- Status
    is_active INTEGER DEFAULT 1,
    
    -- Compliance tracking
    last_compliance_review TEXT,
    compliance_status TEXT DEFAULT 'compliant', -- 'compliant', 'non_compliant', 'under_review'
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (permit_id) REFERENCES permits(id) ON DELETE CASCADE
);

CREATE INDEX idx_permit_conditions_permit ON permit_conditions(permit_id);
CREATE INDEX idx_permit_conditions_type ON permit_conditions(condition_type);


-- ============================================================================
-- PERMIT LIMITS
-- ============================================================================
-- Specific numeric limits from permits. Separated from conditions because
-- limits need structured data for compliance tracking and reporting.

CREATE TABLE IF NOT EXISTS permit_limits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    permit_id INTEGER NOT NULL,
    condition_id INTEGER,                   -- Link to parent condition if applicable
    
    -- What is being limited
    limit_name TEXT NOT NULL,               -- 'NOx Emissions', 'TSS Discharge', 'Production Rate'
    parameter_code TEXT,                    -- Standard parameter code if applicable
    
    -- Applicability
    applies_to TEXT,                        -- Emission unit, outfall, process
    emission_unit_id INTEGER,
    outfall_id INTEGER,
    pollutant_id INTEGER,                   -- Link to chemicals table if applicable
    
    -- The limit value(s)
    -- Many limits have multiple forms (hourly, daily, monthly, annual)
    limit_value REAL,
    limit_units TEXT NOT NULL,              -- 'lb/hr', 'mg/L', 'tons/yr', 'ppm'
    limit_type TEXT NOT NULL,               -- 'maximum', 'average', 'minimum', 'range'
    averaging_period TEXT,                  -- 'instantaneous', 'hourly', 'daily', 'monthly', 'annual', 'rolling_12mo'
    
    -- For limits with multiple tiers (e.g., daily max vs monthly avg)
    limit_daily_max REAL,
    limit_weekly_avg REAL,
    limit_monthly_avg REAL,
    limit_annual_total REAL,
    
    -- Statistical basis (for water permits especially)
    statistical_basis TEXT,                 -- 'daily_maximum', 'monthly_average', '4-day_average'
    
    -- Monitoring requirements for this limit
    monitoring_method TEXT,                 -- How the limit is monitored
    monitoring_frequency TEXT,              -- How often
    
    -- Regulatory basis
    regulatory_basis TEXT,                  -- Regulation the limit comes from
    
    -- Effective dates (limits can change within a permit term)
    effective_date TEXT,
    end_date TEXT,
    
    is_active INTEGER DEFAULT 1,
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (permit_id) REFERENCES permits(id) ON DELETE CASCADE,
    FOREIGN KEY (condition_id) REFERENCES permit_conditions(id)
);

CREATE INDEX idx_permit_limits_permit ON permit_limits(permit_id);
CREATE INDEX idx_permit_limits_parameter ON permit_limits(parameter_code);


-- ============================================================================
-- MONITORING REQUIREMENTS
-- ============================================================================
-- Defines what monitoring must be performed under each permit.

CREATE TABLE IF NOT EXISTS permit_monitoring_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    permit_id INTEGER NOT NULL,
    condition_id INTEGER,                   -- Link to parent condition
    limit_id INTEGER,                       -- Link to limit being monitored
    
    -- What is monitored
    monitoring_name TEXT NOT NULL,
    parameter_code TEXT,
    
    -- Where
    monitoring_location TEXT,               -- Description or ID of monitoring point
    emission_unit_id INTEGER,
    outfall_id INTEGER,
    
    -- How
    monitoring_method TEXT NOT NULL,        -- 'CEMS', 'stack_test', 'grab_sample', 'composite', 'calculation'
    method_reference TEXT,                  -- EPA Method number, SM number, etc.
    
    -- When
    monitoring_frequency TEXT NOT NULL,     -- 'continuous', 'daily', 'weekly', 'monthly', 'quarterly', 'annual'
    samples_per_period INTEGER,             -- Number of samples required per period
    
    -- QA/QC requirements
    qaqc_requirements TEXT,
    calibration_frequency TEXT,
    
    -- Detection limits
    detection_limit REAL,
    detection_limit_units TEXT,
    
    -- Data handling
    data_averaging_period TEXT,
    missing_data_procedure TEXT,
    
    is_active INTEGER DEFAULT 1,
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (permit_id) REFERENCES permits(id) ON DELETE CASCADE,
    FOREIGN KEY (condition_id) REFERENCES permit_conditions(id),
    FOREIGN KEY (limit_id) REFERENCES permit_limits(id)
);

CREATE INDEX idx_monitoring_req_permit ON permit_monitoring_requirements(permit_id);


-- ============================================================================
-- REPORTING REQUIREMENTS
-- ============================================================================
-- Defines reports that must be submitted under each permit.

CREATE TABLE IF NOT EXISTS permit_reporting_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    permit_id INTEGER NOT NULL,
    condition_id INTEGER,                   -- Link to parent condition
    
    -- Report identification
    report_name TEXT NOT NULL,              -- 'Semi-Annual Monitoring Report', 'Annual Compliance Certification'
    report_code TEXT,                       -- Short code for internal tracking
    
    -- Report type
    report_type TEXT NOT NULL,              -- 'monitoring', 'compliance_certification', 'emissions_inventory',
                                            -- 'deviation', 'upset', 'dmr', 'excess_emissions', 'annual'
    
    -- Frequency and timing
    frequency TEXT NOT NULL,                -- 'monthly', 'quarterly', 'semi-annual', 'annual', 'event-driven'
    due_day_of_period INTEGER,              -- Day of month (or days after period end)
    due_days_after_period INTEGER,          -- Days after reporting period ends
    
    -- Reporting period
    period_type TEXT,                       -- 'calendar_month', 'calendar_quarter', 'calendar_year', 
                                            -- 'permit_year', 'semi-annual'
    period_start_month INTEGER,             -- For annual reports, which month starts the period (1-12)
    
    -- Submission details
    submit_to TEXT,                         -- Agency/office to submit to
    submission_method TEXT,                 -- 'electronic', 'mail', 'email', 'portal'
    portal_name TEXT,                       -- 'NetDMR', 'CEDRI', 'State portal'
    portal_url TEXT,
    
    -- Certification requirements
    requires_certification INTEGER DEFAULT 0,
    certification_title TEXT,               -- Who must sign (Responsible Official, etc.)
    
    -- Template/form
    form_number TEXT,                       -- EPA form number if applicable
    template_path TEXT,                     -- Path to blank template
    
    is_active INTEGER DEFAULT 1,
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (permit_id) REFERENCES permits(id) ON DELETE CASCADE,
    FOREIGN KEY (condition_id) REFERENCES permit_conditions(id)
);

CREATE INDEX idx_reporting_req_permit ON permit_reporting_requirements(permit_id);
CREATE INDEX idx_reporting_req_type ON permit_reporting_requirements(report_type);


-- ============================================================================
-- REPORT SUBMISSIONS (Tracking)
-- ============================================================================
-- Tracks actual report submissions to demonstrate compliance with reporting requirements.

CREATE TABLE IF NOT EXISTS permit_report_submissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    permit_id INTEGER NOT NULL,
    reporting_requirement_id INTEGER NOT NULL,
    
    -- Reporting period
    period_start_date TEXT NOT NULL,
    period_end_date TEXT NOT NULL,
    
    -- Due date (calculated or explicit)
    due_date TEXT NOT NULL,
    
    -- Submission tracking
    status TEXT DEFAULT 'pending',          -- 'pending', 'in_progress', 'submitted', 'accepted', 'rejected'
    
    submitted_date TEXT,
    submitted_by INTEGER,                   -- Employee who submitted
    submission_method TEXT,
    confirmation_number TEXT,               -- Portal confirmation, certified mail #, etc.
    
    -- Certification
    certified_by TEXT,                      -- Name of certifying official
    certification_date TEXT,
    
    -- Document
    report_document_path TEXT,
    
    -- Agency response
    agency_response TEXT,
    agency_response_date TEXT,
    
    -- If rejected or needs revision
    revision_required INTEGER DEFAULT 0,
    revision_due_date TEXT,
    revision_submitted_date TEXT,
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    FOREIGN KEY (reporting_requirement_id) REFERENCES permit_reporting_requirements(id),
    FOREIGN KEY (submitted_by) REFERENCES employees(id)
);

CREATE INDEX idx_report_submissions_permit ON permit_report_submissions(permit_id);
CREATE INDEX idx_report_submissions_status ON permit_report_submissions(status);
CREATE INDEX idx_report_submissions_due ON permit_report_submissions(due_date);


-- ============================================================================
-- DEVIATIONS AND EXCEEDANCES
-- ============================================================================
-- Tracks any deviations from permit conditions or exceedances of limits.
-- Critical for compliance tracking and deviation reporting.

CREATE TABLE IF NOT EXISTS permit_deviations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    permit_id INTEGER NOT NULL,
    condition_id INTEGER,                   -- Which condition was violated
    limit_id INTEGER,                       -- Which limit was exceeded
    
    -- Deviation identification
    deviation_number TEXT,                  -- Internal tracking number
    
    -- Classification
    deviation_type TEXT NOT NULL,           -- 'exceedance', 'deviation', 'upset', 'malfunction', 
                                            -- 'emergency', 'startup_shutdown'
    severity TEXT DEFAULT 'minor',          -- 'minor', 'major', 'significant'
    
    -- What happened
    deviation_description TEXT NOT NULL,
    
    -- When
    start_datetime TEXT NOT NULL,
    end_datetime TEXT,
    duration_hours REAL,
    
    -- For limit exceedances - the actual values
    limit_value REAL,                       -- What the limit was
    actual_value REAL,                      -- What was measured
    limit_units TEXT,
    percent_over REAL,                      -- Calculated: (actual-limit)/limit * 100
    
    -- Cause
    cause_description TEXT,
    root_cause_category TEXT,               -- 'equipment_failure', 'operator_error', 'process_upset',
                                            -- 'weather', 'power_outage', 'startup_shutdown', 'other'
    
    -- Impact
    environmental_impact TEXT,
    estimated_excess_emissions REAL,
    excess_emissions_units TEXT,
    
    -- Response actions
    immediate_actions TEXT,
    corrective_actions TEXT,
    preventive_actions TEXT,
    
    -- Reporting
    reporting_required INTEGER DEFAULT 0,
    report_due_date TEXT,
    report_submitted_date TEXT,
    report_type TEXT,                       -- 'immediate_notification', 'deviation_report', 'upset_report'
    
    -- Agency notification
    agency_notified INTEGER DEFAULT 0,
    agency_notification_date TEXT,
    agency_notification_method TEXT,        -- 'phone', 'email', 'portal'
    agency_contact TEXT,
    
    -- CAR linkage
    car_id INTEGER,
    
    -- Status
    status TEXT DEFAULT 'open',             -- 'open', 'reported', 'closed'
    closed_date TEXT,
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    FOREIGN KEY (condition_id) REFERENCES permit_conditions(id),
    FOREIGN KEY (limit_id) REFERENCES permit_limits(id),
    FOREIGN KEY (car_id) REFERENCES corrective_actions(id)
);

CREATE INDEX idx_deviations_permit ON permit_deviations(permit_id);
CREATE INDEX idx_deviations_status ON permit_deviations(status);
CREATE INDEX idx_deviations_type ON permit_deviations(deviation_type);
CREATE INDEX idx_deviations_date ON permit_deviations(start_datetime);


-- ============================================================================
-- COMPLIANCE CALENDAR
-- ============================================================================
-- Master calendar of all permit-related deadlines and obligations.
-- Can be auto-populated from permit requirements or manually added.

CREATE TABLE IF NOT EXISTS compliance_calendar (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    
    -- Source of the obligation
    source_type TEXT NOT NULL,              -- 'permit', 'regulation', 'internal', 'other'
    permit_id INTEGER,
    reporting_requirement_id INTEGER,
    
    -- Event details
    event_name TEXT NOT NULL,
    event_description TEXT,
    event_type TEXT NOT NULL,               -- 'report_due', 'fee_due', 'renewal_due', 'monitoring',
                                            -- 'inspection', 'certification', 'testing', 'training'
    
    -- Timing
    due_date TEXT NOT NULL,
    
    -- Recurrence
    is_recurring INTEGER DEFAULT 0,
    recurrence_pattern TEXT,                -- 'monthly', 'quarterly', 'annual', etc.
    next_occurrence_date TEXT,
    
    -- Assignment
    responsible_person_id INTEGER,
    
    -- Reminders
    reminder_days_before INTEGER DEFAULT 14,
    reminder_sent INTEGER DEFAULT 0,
    reminder_sent_date TEXT,
    
    -- Status
    status TEXT DEFAULT 'pending',          -- 'pending', 'in_progress', 'completed', 'overdue', 'cancelled'
    completed_date TEXT,
    completed_by INTEGER,
    
    -- Linkage to completion record
    report_submission_id INTEGER,           -- If this is a report deadline
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    FOREIGN KEY (reporting_requirement_id) REFERENCES permit_reporting_requirements(id),
    FOREIGN KEY (responsible_person_id) REFERENCES employees(id),
    FOREIGN KEY (completed_by) REFERENCES employees(id),
    FOREIGN KEY (report_submission_id) REFERENCES permit_report_submissions(id)
);

CREATE INDEX idx_compliance_calendar_establishment ON compliance_calendar(establishment_id);
CREATE INDEX idx_compliance_calendar_due ON compliance_calendar(due_date);
CREATE INDEX idx_compliance_calendar_status ON compliance_calendar(status);
CREATE INDEX idx_compliance_calendar_type ON compliance_calendar(event_type);


-- ============================================================================
-- PERMIT AMENDMENTS/MODIFICATIONS
-- ============================================================================
-- Tracks changes to permits over time.

CREATE TABLE IF NOT EXISTS permit_modifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    permit_id INTEGER NOT NULL,
    
    -- Modification identification
    modification_number TEXT,               -- Agency-assigned mod number
    modification_type TEXT NOT NULL,        -- 'administrative', 'minor', 'significant', 'renewal'
    
    -- Description
    modification_description TEXT NOT NULL,
    
    -- What changed
    conditions_added TEXT,                  -- Condition numbers added
    conditions_removed TEXT,                -- Condition numbers removed
    conditions_modified TEXT,               -- Condition numbers changed
    
    -- Dates
    application_date TEXT,
    approval_date TEXT,
    effective_date TEXT,
    
    -- Document
    modification_document_path TEXT,
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (permit_id) REFERENCES permits(id)
);

CREATE INDEX idx_permit_mods_permit ON permit_modifications(permit_id);


-- ============================================================================
-- VIEWS: Permit Management
-- ============================================================================

-- ----------------------------------------------------------------------------
-- V_PERMITS_EXPIRING
-- ----------------------------------------------------------------------------
-- Permits approaching expiration or renewal deadline.

CREATE VIEW IF NOT EXISTS v_permits_expiring AS
SELECT 
    p.id AS permit_id,
    p.permit_number,
    p.permit_name,
    p.establishment_id,
    e.name AS establishment_name,
    pt.type_name AS permit_type,
    pt.category,
    p.expiration_date,
    CAST(julianday(p.expiration_date) - julianday('now') AS INTEGER) AS days_until_expiration,
    pt.renewal_lead_time_days,
    date(p.expiration_date, '-' || pt.renewal_lead_time_days || ' days') AS renewal_deadline,
    CAST(julianday(date(p.expiration_date, '-' || pt.renewal_lead_time_days || ' days')) - julianday('now') AS INTEGER) AS days_until_renewal_deadline,
    p.renewal_status,
    CASE 
        WHEN p.renewal_status = 'submitted' THEN 'RENEWAL_SUBMITTED'
        WHEN date(p.expiration_date) < date('now') THEN 'EXPIRED'
        WHEN date(p.expiration_date) <= date('now', '+30 days') THEN 'EXPIRES_SOON'
        WHEN date(p.expiration_date, '-' || pt.renewal_lead_time_days || ' days') < date('now') THEN 'RENEWAL_OVERDUE'
        WHEN date(p.expiration_date, '-' || pt.renewal_lead_time_days || ' days') <= date('now', '+30 days') THEN 'RENEWAL_DUE_SOON'
        ELSE 'OK'
    END AS urgency
FROM permits p
INNER JOIN establishments e ON p.establishment_id = e.id
INNER JOIN permit_types pt ON p.permit_type_id = pt.id
WHERE p.status = 'active'
  AND p.expiration_date IS NOT NULL
ORDER BY p.expiration_date ASC;


-- ----------------------------------------------------------------------------
-- V_REPORTS_DUE
-- ----------------------------------------------------------------------------
-- Upcoming report submissions.

CREATE VIEW IF NOT EXISTS v_reports_due AS
SELECT 
    prs.id AS submission_id,
    prs.establishment_id,
    e.name AS establishment_name,
    p.permit_number,
    p.permit_name,
    prr.report_name,
    prr.report_type,
    prs.period_start_date,
    prs.period_end_date,
    prs.due_date,
    CAST(julianday(prs.due_date) - julianday('now') AS INTEGER) AS days_until_due,
    prs.status,
    prr.submission_method,
    prr.portal_name,
    CASE 
        WHEN prs.status = 'submitted' THEN 'SUBMITTED'
        WHEN date(prs.due_date) < date('now') THEN 'OVERDUE'
        WHEN date(prs.due_date) <= date('now', '+7 days') THEN 'DUE_THIS_WEEK'
        WHEN date(prs.due_date) <= date('now', '+30 days') THEN 'DUE_THIS_MONTH'
        ELSE 'UPCOMING'
    END AS urgency
FROM permit_report_submissions prs
INNER JOIN establishments e ON prs.establishment_id = e.id
INNER JOIN permits p ON prs.permit_id = p.id
INNER JOIN permit_reporting_requirements prr ON prs.reporting_requirement_id = prr.id
WHERE prs.status NOT IN ('submitted', 'accepted')
ORDER BY prs.due_date ASC;


-- ----------------------------------------------------------------------------
-- V_COMPLIANCE_CALENDAR_UPCOMING
-- ----------------------------------------------------------------------------
-- All upcoming compliance obligations.

CREATE VIEW IF NOT EXISTS v_compliance_calendar_upcoming AS
SELECT 
    cc.id AS calendar_id,
    cc.establishment_id,
    e.name AS establishment_name,
    cc.event_name,
    cc.event_type,
    cc.due_date,
    CAST(julianday(cc.due_date) - julianday('now') AS INTEGER) AS days_until_due,
    cc.status,
    p.permit_number,
    emp.first_name || ' ' || emp.last_name AS responsible_person,
    CASE 
        WHEN cc.status = 'completed' THEN 'COMPLETED'
        WHEN date(cc.due_date) < date('now') THEN 'OVERDUE'
        WHEN date(cc.due_date) <= date('now', '+7 days') THEN 'DUE_THIS_WEEK'
        WHEN date(cc.due_date) <= date('now', '+14 days') THEN 'DUE_SOON'
        ELSE 'UPCOMING'
    END AS urgency
FROM compliance_calendar cc
INNER JOIN establishments e ON cc.establishment_id = e.id
LEFT JOIN permits p ON cc.permit_id = p.id
LEFT JOIN employees emp ON cc.responsible_person_id = emp.id
WHERE cc.status NOT IN ('completed', 'cancelled')
ORDER BY cc.due_date ASC;


-- ----------------------------------------------------------------------------
-- V_OPEN_DEVIATIONS
-- ----------------------------------------------------------------------------
-- All open deviations/exceedances.

CREATE VIEW IF NOT EXISTS v_open_deviations AS
SELECT 
    pd.id AS deviation_id,
    pd.deviation_number,
    pd.establishment_id,
    e.name AS establishment_name,
    p.permit_number,
    pd.deviation_type,
    pd.severity,
    pd.deviation_description,
    pd.start_datetime,
    pd.duration_hours,
    pd.actual_value,
    pd.limit_value,
    pd.limit_units,
    pd.percent_over,
    pd.reporting_required,
    pd.report_due_date,
    pd.status,
    CASE 
        WHEN pd.reporting_required = 1 AND pd.report_submitted_date IS NULL 
             AND date(pd.report_due_date) < date('now') THEN 'REPORT_OVERDUE'
        WHEN pd.reporting_required = 1 AND pd.report_submitted_date IS NULL THEN 'REPORT_PENDING'
        WHEN pd.severity = 'significant' THEN 'SIGNIFICANT'
        WHEN pd.severity = 'major' THEN 'MAJOR'
        ELSE 'MINOR'
    END AS urgency
FROM permit_deviations pd
INNER JOIN establishments e ON pd.establishment_id = e.id
INNER JOIN permits p ON pd.permit_id = p.id
WHERE pd.status != 'closed'
ORDER BY pd.start_datetime DESC;


-- ----------------------------------------------------------------------------
-- V_PERMIT_SUMMARY
-- ----------------------------------------------------------------------------
-- Summary of permits by establishment.

CREATE VIEW IF NOT EXISTS v_permit_summary AS
SELECT 
    e.id AS establishment_id,
    e.name AS establishment_name,
    
    -- Count by category
    SUM(CASE WHEN pt.category = 'air' THEN 1 ELSE 0 END) AS air_permits,
    SUM(CASE WHEN pt.category = 'water' THEN 1 ELSE 0 END) AS water_permits,
    SUM(CASE WHEN pt.category = 'waste' THEN 1 ELSE 0 END) AS waste_permits,
    SUM(CASE WHEN pt.category = 'other' THEN 1 ELSE 0 END) AS other_permits,
    COUNT(p.id) AS total_permits,
    
    -- Expiring soon (next 90 days)
    SUM(CASE WHEN p.expiration_date IS NOT NULL 
             AND date(p.expiration_date) <= date('now', '+90 days') 
             AND date(p.expiration_date) > date('now') THEN 1 ELSE 0 END) AS expiring_soon,
    
    -- Renewal needed
    SUM(CASE WHEN p.renewal_status IN ('not_started', 'in_progress') 
             AND p.expiration_date IS NOT NULL
             AND date(p.expiration_date, '-' || pt.renewal_lead_time_days || ' days') < date('now') 
             THEN 1 ELSE 0 END) AS renewal_overdue,
    
    -- Open deviations
    (SELECT COUNT(*) FROM permit_deviations pd 
     WHERE pd.establishment_id = e.id AND pd.status != 'closed') AS open_deviations

FROM establishments e
LEFT JOIN permits p ON e.id = p.establishment_id AND p.status = 'active'
LEFT JOIN permit_types pt ON p.permit_type_id = pt.id
GROUP BY e.id, e.name;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Calculate percent over limit for exceedances
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_deviation_percent_over
AFTER INSERT ON permit_deviations
WHEN NEW.actual_value IS NOT NULL AND NEW.limit_value IS NOT NULL AND NEW.limit_value > 0
BEGIN
    UPDATE permit_deviations
    SET percent_over = ROUND(((NEW.actual_value - NEW.limit_value) / NEW.limit_value) * 100, 2)
    WHERE id = NEW.id;
END;

-- ----------------------------------------------------------------------------
-- Auto-generate compliance calendar entries from reporting requirements
-- ----------------------------------------------------------------------------
-- Note: In practice, this would be done by application code that calculates
-- the actual due dates based on reporting period. This trigger is a placeholder
-- showing the relationship.

-- ----------------------------------------------------------------------------
-- Update permit status when expired
-- ----------------------------------------------------------------------------
-- Note: This would typically be a scheduled job, not a trigger.
-- Shown here for documentation purposes.


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================
/*
-- 1. Get all permits expiring in next 6 months
SELECT * FROM v_permits_expiring 
WHERE days_until_expiration <= 180;

-- 2. Check what reports are due this month
SELECT * FROM v_reports_due 
WHERE urgency IN ('DUE_THIS_WEEK', 'DUE_THIS_MONTH', 'OVERDUE');

-- 3. View compliance calendar for an establishment
SELECT * FROM v_compliance_calendar_upcoming 
WHERE establishment_id = 1
ORDER BY due_date;

-- 4. Get all open deviations needing attention
SELECT * FROM v_open_deviations 
WHERE urgency IN ('REPORT_OVERDUE', 'SIGNIFICANT', 'MAJOR');

-- 5. Create a report submission record for a due report
INSERT INTO permit_report_submissions 
    (establishment_id, permit_id, reporting_requirement_id, 
     period_start_date, period_end_date, due_date)
SELECT 
    p.establishment_id,
    prr.permit_id,
    prr.id,
    date('now', 'start of month', '-1 month'),  -- Previous month start
    date('now', 'start of month', '-1 day'),    -- Previous month end
    date('now', 'start of month', '+' || prr.due_days_after_period || ' days')
FROM permit_reporting_requirements prr
INNER JOIN permits p ON prr.permit_id = p.id
WHERE prr.report_type = 'dmr'
  AND prr.frequency = 'monthly';

-- 6. Record a permit deviation/exceedance
INSERT INTO permit_deviations 
    (establishment_id, permit_id, limit_id, deviation_type, severity,
     deviation_description, start_datetime, end_datetime, duration_hours,
     limit_value, actual_value, limit_units, cause_description)
VALUES 
    (1, 1, 5, 'exceedance', 'minor',
     'TSS exceeded daily maximum during storm event',
     '2025-12-01 14:30', '2025-12-01 16:00', 1.5,
     30.0, 45.0, 'mg/L',
     'Heavy rainfall caused stormwater infiltration into process wastewater');

-- 7. Get permit summary by establishment
SELECT * FROM v_permit_summary;

-- 8. Find all conditions for a specific permit
SELECT 
    condition_number,
    condition_title,
    condition_type,
    condition_text,
    frequency
FROM permit_conditions
WHERE permit_id = 1
ORDER BY condition_number;

-- 9. Get all limits for a permit with their monitoring requirements
SELECT 
    pl.limit_name,
    pl.limit_value,
    pl.limit_units,
    pl.averaging_period,
    pmr.monitoring_method,
    pmr.monitoring_frequency
FROM permit_limits pl
LEFT JOIN permit_monitoring_requirements pmr ON pl.id = pmr.limit_id
WHERE pl.permit_id = 1
ORDER BY pl.limit_name;

-- 10. Deviation trending by root cause
SELECT 
    root_cause_category,
    strftime('%Y-%m', start_datetime) AS month,
    COUNT(*) AS deviation_count,
    SUM(CASE WHEN severity = 'significant' THEN 1 ELSE 0 END) AS significant,
    SUM(CASE WHEN severity = 'major' THEN 1 ELSE 0 END) AS major,
    SUM(CASE WHEN severity = 'minor' THEN 1 ELSE 0 END) AS minor
FROM permit_deviations
WHERE root_cause_category IS NOT NULL
GROUP BY root_cause_category, strftime('%Y-%m', start_datetime)
ORDER BY month DESC, deviation_count DESC;
*/


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
PERMITS MODULE (006_permits.sql)

PURPOSE:
Base permit tracking structure supporting all permit types (air, water, waste).
Provides foundation for specific reporting modules to be added later.

REFERENCE TABLES:
    - regulatory_agencies: Agencies that issue permits (EPA, state, local)
    - permit_types: Categories of permits with typical characteristics

CORE PERMIT TABLES:
    - permits: Master permit record with dates, status, renewal tracking
    - permit_conditions: Individual conditions within permits
    - permit_limits: Specific numeric limits (emission, discharge, etc.)
    - permit_modifications: Amendment/modification history

MONITORING & REPORTING:
    - permit_monitoring_requirements: What monitoring must be performed
    - permit_reporting_requirements: Reports that must be submitted
    - permit_report_submissions: Tracking of actual report submissions

COMPLIANCE TRACKING:
    - permit_deviations: Exceedances and deviations from permit conditions
    - compliance_calendar: Master calendar of all permit obligations

VIEWS:
    - v_permits_expiring: Permits approaching expiration/renewal
    - v_reports_due: Upcoming report submissions
    - v_compliance_calendar_upcoming: All upcoming compliance obligations
    - v_open_deviations: Deviations needing attention
    - v_permit_summary: Summary by establishment

PRE-SEEDED DATA:
  Permit Types (17 types):
    Air: TITLE_V, NSR_MAJOR, PSD, MINOR_SOURCE, PTI, GP_AIR
    Water: NPDES_INDIVIDUAL, NPDES_GENERAL, NPDES_STORMWATER, PRETREATMENT, GWDP
    Waste: RCRA_TSDF, RCRA_GENERATOR, USED_OIL
    Other: SPCC, RMP, TIER2

KEY FEATURES:
  1. Multi-permit tracking with expiration/renewal alerts
  2. Condition and limit management at granular level
  3. Deviation/exceedance tracking with root cause
  4. Reporting requirement calendar
  5. Submission tracking with portal/confirmation support
  6. Links to CAR system for corrective actions
  7. Permit modification history

PLANNED EXTENSIONS (Separate Files):
  - 006b_air_permits.sql: Air-specific tables
    * Emission units, stacks, control devices
    * CEMS data tracking
    * Stack test records
    * Emissions inventory
    * Deviation reports (excess emissions)
    
  - 006c_water_permits.sql: Water-specific tables
    * Outfalls and monitoring points
    * DMR data entry and submission
    * Benchmark monitoring
    * Effluent limits by parameter

REGULATORY DRIVERS:
  - Clean Air Act (Title V, NSR, PSD, NESHAP, NSPS)
  - Clean Water Act (NPDES, Pretreatment)
  - RCRA (Hazardous Waste Permits)
  - EPCRA (Tier II, RMP)
  - State delegated programs
*/
