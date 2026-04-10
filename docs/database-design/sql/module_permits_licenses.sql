-- Module: Permits & Licenses
-- Derived from ehs-ontology-v3.1.ttl — RegulatoryFramework + Evaluation classes
--
-- Permits are how the ontology's RegulatoryFramework requirements become specific,
-- facility-level obligations. Each permit type maps to a regulatory framework:
--   Title V, NSR, PSD → CAA_Framework
--   NPDES → CWA_Framework
--   RCRA permits → EPA_Framework (RCRA subtitle C)
--   EPCRA → EPA_Framework (EPCRA)
--
-- Licenses are authorizations to operate or practice — renewal-focused with
-- less ongoing compliance tracking than permits. Business, professional,
-- operator, and equipment categories.
--
-- The compliance_calendar operationalizes the ontology's Evaluation concept
-- (the 5th E in the hierarchy of controls feedback loop). Every calendar entry
-- is an evaluation obligation — monitoring, reporting, renewal, certification —
-- that confirms controls are working as designed.
--
-- Cross-module references:
--   - establishments, employees: shared foundation (Module C)
--   - corrective_actions: Module C/D — deviations generate corrective actions
--   - incidents: Module C/D — some deviations are incident-related
--   - air_emission_units: Module B — emission units reference permits


-- ============================================================================
-- REFERENCE: REGULATORY AGENCIES
-- ============================================================================
-- Agencies that issue permits. Same permit type might come from EPA, state
-- agency, or local authority depending on delegation status.

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
-- REFERENCE: PERMIT TYPES (maps to ontology RegulatoryFramework subclasses)
-- ============================================================================
-- Each permit type connects to a specific regulatory framework in the ontology.
-- The regulatory_framework_code links permits to the compliance routing engine:
-- when a hazard is identified, the framework determines which permits apply.

CREATE TABLE IF NOT EXISTS permit_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    type_code TEXT NOT NULL UNIQUE,         -- 'TITLE_V', 'NPDES', 'RCRA_TSDF'
    type_name TEXT NOT NULL,
    category TEXT NOT NULL,                 -- 'air', 'water', 'waste', 'other'

    description TEXT,

    -- Ontology connection: links this permit type to a RegulatoryFramework
    -- This is the bridge between the ontology's abstract framework classes
    -- and concrete, facility-level permit obligations.
    regulatory_framework_code TEXT,         -- 'CAA_Framework', 'CWA_Framework', 'EPA_Framework', etc.

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

-- Seed all 17 permit types with regulatory framework mapping
INSERT OR IGNORE INTO permit_types
    (id, type_code, type_name, category, regulatory_framework_code, federal_authority,
     typical_term_years, renewal_lead_time_days, has_periodic_reporting,
     typical_reporting_frequency, has_monitoring_requirements) VALUES
    -- Air Permits → CAA_Framework
    (1, 'TITLE_V', 'Title V Operating Permit', 'air', 'CAA_Framework', 'CAA Title V',
        5, 180, 1, 'semi-annual', 1),
    (2, 'NSR_MAJOR', 'New Source Review - Major', 'air', 'CAA_Framework', 'CAA NSR',
        NULL, 180, 1, 'annual', 1),
    (3, 'PSD', 'Prevention of Significant Deterioration', 'air', 'CAA_Framework', 'CAA PSD',
        NULL, 180, 1, 'annual', 1),
    (4, 'MINOR_SOURCE', 'Minor Source Air Permit', 'air', 'CAA_Framework', 'CAA/State',
        5, 90, 1, 'annual', 1),
    (5, 'PTI', 'Permit to Install', 'air', 'CAA_Framework', 'State',
        NULL, 90, 0, NULL, 0),
    (6, 'GP_AIR', 'General Permit - Air', 'air', 'CAA_Framework', 'CAA/State',
        5, 90, 1, 'annual', 0),

    -- Water Permits → CWA_Framework
    (10, 'NPDES_INDIVIDUAL', 'NPDES Individual Permit', 'water', 'CWA_Framework', 'CWA 402',
        5, 180, 1, 'monthly', 1),
    (11, 'NPDES_GENERAL', 'NPDES General Permit (Industrial)', 'water', 'CWA_Framework', 'CWA 402',
        5, 90, 1, 'quarterly', 1),
    (12, 'NPDES_STORMWATER', 'NPDES Stormwater (MSGP/CGP)', 'water', 'CWA_Framework', 'CWA 402',
        5, 90, 1, 'annual', 1),
    (13, 'PRETREATMENT', 'Industrial Pretreatment Permit', 'water', 'CWA_Framework', 'CWA 307',
        5, 180, 1, 'monthly', 1),
    (14, 'GWDP', 'Groundwater Discharge Permit', 'water', 'CWA_Framework', 'State',
        5, 180, 1, 'quarterly', 1),

    -- Waste Permits → EPA_Framework (RCRA subtitle C)
    (20, 'RCRA_TSDF', 'RCRA Part B (TSDF)', 'waste', 'EPA_Framework', 'RCRA 3005',
        10, 365, 1, 'annual', 1),
    (21, 'RCRA_GENERATOR', 'RCRA Generator Notification', 'waste', 'EPA_Framework', 'RCRA 3010',
        NULL, 0, 0, NULL, 0),
    (22, 'USED_OIL', 'Used Oil Handler Registration', 'waste', 'EPA_Framework', 'RCRA 279',
        NULL, 0, 0, NULL, 0),

    -- Other → EPA_Framework (EPCRA/CAA 112(r))
    (30, 'SPCC', 'SPCC Plan (Self-Certified)', 'other', 'EPA_Framework', '40 CFR 112',
        5, 0, 0, NULL, 1),
    (31, 'RMP', 'Risk Management Plan', 'other', 'CAA_Framework', 'CAA 112(r)',
        5, 0, 1, 'annual', 0),
    (32, 'TIER2', 'Tier II Notification', 'other', 'EPA_Framework', 'EPCRA 312',
        1, 30, 1, 'annual', 0);


-- ============================================================================
-- PERMITS (Master Table)
-- ============================================================================
-- The core permit record. Each permit is a concrete instantiation of the
-- ontology's RegulatoryFramework at a specific facility. Module B's
-- air_emission_units.permit_id references this table to link equipment
-- to its authorizing permit.

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
-- Each condition traces back to a regulatory requirement in the ontology.

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
-- PERMIT MONITORING REQUIREMENTS
-- ============================================================================
-- Defines what monitoring must be performed under each permit.
-- Monitoring is the ontology's Evaluation in action — confirming that
-- controls meet the limits the regulatory framework requires.

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
-- PERMIT REPORTING REQUIREMENTS
-- ============================================================================
-- Defines reports that must be submitted under each permit.
-- Reporting is Evaluation made visible to the regulator — the proof loop
-- that the facility's controls satisfy the regulatory framework.

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
-- PERMIT REPORT SUBMISSIONS
-- ============================================================================
-- Tracks actual report submissions to demonstrate compliance with
-- reporting requirements. Each submission closes an Evaluation cycle.

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
-- PERMIT DEVIATIONS AND EXCEEDANCES
-- ============================================================================
-- Tracks any deviations from permit conditions or exceedances of limits.
-- Critical for compliance tracking and deviation reporting.
--
-- Cross-module FKs:
--   corrective_action_id → corrective_actions (Module C/D): deviations
--     generate corrective actions through the investigation workflow.
--   incident_id → incidents (Module C/D): some deviations are discovered
--     through or cause incidents (e.g., release event triggers both an
--     incident record and a permit deviation).

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

    -- Cross-module: corrective action linkage (Module C/D)
    -- Deviations generate corrective actions through the investigation workflow.
    corrective_action_id INTEGER,           -- FK → corrective_actions

    -- Cross-module: incident linkage (Module C/D)
    -- Some deviations are discovered through or cause incidents.
    incident_id INTEGER,                    -- FK → incidents

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
    FOREIGN KEY (corrective_action_id) REFERENCES corrective_actions(id),
    FOREIGN KEY (incident_id) REFERENCES incidents(id)
);

CREATE INDEX idx_deviations_permit ON permit_deviations(permit_id);
CREATE INDEX idx_deviations_status ON permit_deviations(status);
CREATE INDEX idx_deviations_type ON permit_deviations(deviation_type);
CREATE INDEX idx_deviations_date ON permit_deviations(start_datetime);
CREATE INDEX idx_deviations_corrective_action ON permit_deviations(corrective_action_id);
CREATE INDEX idx_deviations_incident ON permit_deviations(incident_id);


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
-- REFERENCE: COMPLIANCE OBLIGATION TYPES (ontology Evaluation subclasses)
-- ============================================================================
-- Categorizes compliance calendar entries by obligation type. Replaces
-- free-text event_type with a controlled vocabulary derived from the
-- ontology's Evaluation concept. Each type represents a different form
-- of Evaluation that confirms regulatory controls are effective.

CREATE TABLE IF NOT EXISTS compliance_obligation_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    applies_to TEXT NOT NULL               -- 'permit', 'license', 'both'
);

INSERT OR IGNORE INTO compliance_obligation_types (code, name, description, applies_to) VALUES
    ('REPORT_SUBMISSION',  'Report Submission',      'Periodic or event-driven report due to a regulatory agency.',         'permit'),
    ('PERMIT_RENEWAL',     'Permit Renewal',         'Permit renewal application deadline.',                                'permit'),
    ('LICENSE_RENEWAL',    'License Renewal',         'License, certification, or registration renewal deadline.',           'license'),
    ('FEE_PAYMENT',        'Fee Payment',            'Annual fee, renewal fee, or other regulatory payment due.',           'both'),
    ('INSPECTION_DUE',     'Inspection Due',         'Scheduled self-inspection or regulatory inspection window.',          'both'),
    ('CERTIFICATION_DUE',  'Certification Due',      'Compliance certification, annual certification, or re-certification.','both'),
    ('MONITORING_DUE',     'Monitoring Due',         'Sampling, testing, CEMS audit, or other monitoring obligation.',      'permit'),
    ('CE_DEADLINE',        'Continuing Education',   'CE hours completion deadline for a licensed professional/operator.',  'license'),
    ('TESTING_DUE',        'Testing Due',            'Stack test, performance test, or other required testing event.',      'permit'),
    ('TRAINING_DUE',       'Training Due',           'Required training completion or refresher deadline.',                 'both');


-- ============================================================================
-- COMPLIANCE CALENDAR (ontology Evaluation operationalized)
-- ============================================================================
-- Master calendar of all permit and license compliance deadlines.
-- This is where the ontology's Evaluation concept becomes operational:
-- every entry represents an evaluation obligation that confirms controls
-- are working as the regulatory framework requires. Can be auto-populated
-- from permit/license requirements or manually added.

CREATE TABLE IF NOT EXISTS compliance_calendar (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Source of the obligation
    source_type TEXT NOT NULL,              -- 'permit', 'license', 'regulation', 'internal', 'other'
    permit_id INTEGER,
    license_id INTEGER,                     -- For license-sourced obligations
    reporting_requirement_id INTEGER,

    -- Event details
    event_name TEXT NOT NULL,
    event_description TEXT,
    obligation_type_code TEXT NOT NULL,     -- FK → compliance_obligation_types

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
    FOREIGN KEY (license_id) REFERENCES licenses(id),
    FOREIGN KEY (reporting_requirement_id) REFERENCES permit_reporting_requirements(id),
    FOREIGN KEY (obligation_type_code) REFERENCES compliance_obligation_types(code),
    FOREIGN KEY (responsible_person_id) REFERENCES employees(id),
    FOREIGN KEY (completed_by) REFERENCES employees(id),
    FOREIGN KEY (report_submission_id) REFERENCES permit_report_submissions(id)
);

CREATE INDEX idx_compliance_calendar_establishment ON compliance_calendar(establishment_id);
CREATE INDEX idx_compliance_calendar_due ON compliance_calendar(due_date);
CREATE INDEX idx_compliance_calendar_status ON compliance_calendar(status);
CREATE INDEX idx_compliance_calendar_type ON compliance_calendar(obligation_type_code);
CREATE INDEX idx_compliance_calendar_license ON compliance_calendar(license_id);


-- ============================================================================
-- REFERENCE: LICENSE TYPES
-- ============================================================================
-- Categories of licenses with their typical characteristics.
-- Licenses are authorizations to operate or practice — distinct from
-- permits which authorize specific operations with ongoing monitoring.

CREATE TABLE IF NOT EXISTS license_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    type_code TEXT NOT NULL UNIQUE,         -- 'BUSINESS', 'WASTEWATER_OP', 'PE'
    type_name TEXT NOT NULL,
    category TEXT NOT NULL,                 -- 'business', 'professional', 'operator', 'equipment'

    description TEXT,

    -- Who holds this license type
    holder_type TEXT NOT NULL,              -- 'establishment', 'employee', 'equipment'

    -- Typical characteristics
    typical_term_years INTEGER,
    requires_exam INTEGER DEFAULT 0,
    requires_continuing_education INTEGER DEFAULT 0,
    ce_hours_required INTEGER,              -- CE hours per renewal period
    ce_period_years INTEGER,                -- CE tracking period

    -- Issuing authority type
    issuing_authority_type TEXT,            -- 'state', 'local', 'professional_board', 'federal'

    -- Renewal characteristics
    renewal_lead_time_days INTEGER DEFAULT 60,
    late_renewal_allowed INTEGER DEFAULT 1,
    late_fee_applies INTEGER DEFAULT 1,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- Seed all 24 license types
INSERT OR IGNORE INTO license_types
    (id, type_code, type_name, category, holder_type, typical_term_years,
     requires_exam, requires_continuing_education, ce_hours_required, ce_period_years,
     issuing_authority_type, renewal_lead_time_days) VALUES

    -- Business Licenses (5)
    (1, 'BUSINESS', 'Business License', 'business', 'establishment',
        1, 0, 0, NULL, NULL, 'local', 30),
    (2, 'FIRE_PERMIT', 'Fire Department Permit', 'business', 'establishment',
        1, 0, 0, NULL, NULL, 'local', 30),
    (3, 'OCCUPANCY', 'Certificate of Occupancy', 'business', 'establishment',
        NULL, 0, 0, NULL, NULL, 'local', 0),
    (4, 'ZONING', 'Zoning Permit/Variance', 'business', 'establishment',
        NULL, 0, 0, NULL, NULL, 'local', 0),
    (5, 'SALES_TAX', 'Sales Tax License', 'business', 'establishment',
        1, 0, 0, NULL, NULL, 'state', 30),

    -- Professional Certifications (7)
    (10, 'PE', 'Professional Engineer', 'professional', 'employee',
        2, 1, 1, 30, 2, 'state', 90),
    (11, 'CIH', 'Certified Industrial Hygienist', 'professional', 'employee',
        5, 1, 1, 50, 5, 'professional_board', 90),
    (12, 'CSP', 'Certified Safety Professional', 'professional', 'employee',
        5, 1, 1, 25, 5, 'professional_board', 90),
    (13, 'ASP', 'Associate Safety Professional', 'professional', 'employee',
        5, 1, 0, NULL, NULL, 'professional_board', 90),
    (14, 'CHMM', 'Certified Hazardous Materials Manager', 'professional', 'employee',
        5, 1, 1, 20, 5, 'professional_board', 90),
    (15, 'QEP', 'Qualified Environmental Professional', 'professional', 'employee',
        5, 1, 1, 30, 5, 'professional_board', 90),
    (16, 'REM', 'Registered Environmental Manager', 'professional', 'employee',
        5, 1, 1, 30, 5, 'professional_board', 90),

    -- Operator Licenses (7)
    (20, 'WASTEWATER_OP', 'Wastewater Treatment Operator', 'operator', 'employee',
        3, 1, 1, 30, 3, 'state', 90),
    (21, 'WATER_OP', 'Water Treatment Operator', 'operator', 'employee',
        3, 1, 1, 30, 3, 'state', 90),
    (22, 'BOILER_OP', 'Boiler Operator', 'operator', 'employee',
        1, 1, 0, NULL, NULL, 'state', 60),
    (23, 'CRANE_OP', 'Crane Operator (NCCCO)', 'operator', 'employee',
        5, 1, 0, NULL, NULL, 'professional_board', 90),
    (24, 'FORKLIFT_TRAINER', 'Forklift Train-the-Trainer', 'operator', 'employee',
        3, 0, 0, NULL, NULL, 'professional_board', 60),
    (25, 'CDL', 'Commercial Drivers License', 'operator', 'employee',
        5, 1, 0, NULL, NULL, 'state', 60),
    (26, 'HAZMAT_CDL', 'CDL Hazmat Endorsement', 'operator', 'employee',
        5, 1, 0, NULL, NULL, 'federal', 60),

    -- Equipment Registrations (6)
    (30, 'BOILER_REG', 'Boiler Registration', 'equipment', 'equipment',
        1, 0, 0, NULL, NULL, 'state', 60),
    (31, 'PRESSURE_VESSEL', 'Pressure Vessel Registration', 'equipment', 'equipment',
        1, 0, 0, NULL, NULL, 'state', 60),
    (32, 'ELEVATOR', 'Elevator Permit', 'equipment', 'equipment',
        1, 0, 0, NULL, NULL, 'local', 60),
    (33, 'UST', 'Underground Storage Tank Registration', 'equipment', 'equipment',
        1, 0, 0, NULL, NULL, 'state', 90),
    (34, 'AST', 'Aboveground Storage Tank Registration', 'equipment', 'equipment',
        1, 0, 0, NULL, NULL, 'state', 90),
    (35, 'SCALE', 'Commercial Scale License', 'equipment', 'equipment',
        1, 0, 0, NULL, NULL, 'state', 60);


-- ============================================================================
-- REFERENCE: LICENSE ISSUING AUTHORITIES
-- ============================================================================
-- Bodies that issue licenses (different from regulatory agencies for permits).

CREATE TABLE IF NOT EXISTS license_issuing_authorities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    authority_code TEXT NOT NULL UNIQUE,
    authority_name TEXT NOT NULL,
    authority_type TEXT,                    -- 'state_board', 'professional_org', 'local_govt', 'federal'

    -- Jurisdiction
    jurisdiction_state TEXT,
    jurisdiction_scope TEXT,                -- 'national', 'state', 'local'

    -- Contact
    street_address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,
    renewal_portal_url TEXT,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);


-- ============================================================================
-- LICENSES (Master Table)
-- ============================================================================
-- Individual license records. Can be held by establishment, employee, or
-- equipment. Unlike permits, licenses are primarily renewal-focused with
-- less ongoing monitoring/reporting compliance tracking.

CREATE TABLE IF NOT EXISTS licenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,      -- Always linked to establishment
    license_type_id INTEGER NOT NULL,
    issuing_authority_id INTEGER,

    -- Holder - only one will be populated based on license_type.holder_type
    holder_employee_id INTEGER,             -- For professional/operator licenses
    holder_equipment_id INTEGER,            -- For equipment registrations
    -- If both NULL, license is held by the establishment itself

    -- License identification
    license_number TEXT NOT NULL,
    license_name TEXT,                      -- Optional descriptive name

    -- Classification/level (for operator licenses)
    license_class TEXT,                     -- 'A', 'B', 'C', 'D', 'I', 'II', etc.
    license_level TEXT,                     -- 'Journeyman', 'Master', etc.

    -- Dates
    original_issue_date TEXT,
    current_issue_date TEXT,
    expiration_date TEXT,

    -- Renewal tracking
    renewal_status TEXT DEFAULT 'current',  -- 'current', 'renewal_due', 'renewal_submitted', 'expired', 'lapsed'
    renewal_application_date TEXT,
    renewal_fee REAL,
    last_renewal_date TEXT,

    -- For CE-required licenses
    ce_period_start TEXT,
    ce_period_end TEXT,
    ce_hours_required INTEGER,
    ce_hours_completed INTEGER DEFAULT 0,

    -- Status
    status TEXT DEFAULT 'active',           -- 'active', 'expired', 'suspended', 'revoked', 'inactive'

    -- Document
    license_document_path TEXT,

    -- Internal tracking
    internal_owner_id INTEGER,              -- Employee responsible for renewals

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (license_type_id) REFERENCES license_types(id),
    FOREIGN KEY (issuing_authority_id) REFERENCES license_issuing_authorities(id),
    FOREIGN KEY (holder_employee_id) REFERENCES employees(id),
    FOREIGN KEY (internal_owner_id) REFERENCES employees(id)
);

CREATE INDEX idx_licenses_establishment ON licenses(establishment_id);
CREATE INDEX idx_licenses_type ON licenses(license_type_id);
CREATE INDEX idx_licenses_holder_employee ON licenses(holder_employee_id);
CREATE INDEX idx_licenses_status ON licenses(status);
CREATE INDEX idx_licenses_expiration ON licenses(expiration_date);


-- ============================================================================
-- LICENSE CONTINUING EDUCATION
-- ============================================================================
-- Tracks CE hours for licenses that require them.

CREATE TABLE IF NOT EXISTS license_continuing_education (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    license_id INTEGER NOT NULL,

    -- Course/activity information
    activity_date TEXT NOT NULL,
    activity_name TEXT NOT NULL,
    provider_name TEXT,
    provider_approval_number TEXT,          -- If provider must be pre-approved

    -- Hours
    ce_hours REAL NOT NULL,
    ce_type TEXT,                           -- 'general', 'ethics', 'technical', 'safety', etc.

    -- Approval
    activity_approval_number TEXT,          -- If activity must be pre-approved
    is_approved INTEGER DEFAULT 1,

    -- Documentation
    certificate_path TEXT,

    -- Verification
    verified INTEGER DEFAULT 0,
    verified_by INTEGER,
    verified_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (license_id) REFERENCES licenses(id) ON DELETE CASCADE,
    FOREIGN KEY (verified_by) REFERENCES employees(id)
);

CREATE INDEX idx_license_ce_license ON license_continuing_education(license_id);
CREATE INDEX idx_license_ce_date ON license_continuing_education(activity_date);


-- ============================================================================
-- LICENSE RENEWAL HISTORY
-- ============================================================================
-- Historical record of license renewals.

CREATE TABLE IF NOT EXISTS license_renewal_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    license_id INTEGER NOT NULL,

    -- Renewal cycle
    renewal_period_start TEXT,
    renewal_period_end TEXT,

    -- Application
    application_date TEXT,
    application_fee REAL,
    late_fee REAL,

    -- CE documentation (for that period)
    ce_hours_submitted INTEGER,

    -- Result
    renewal_date TEXT,                      -- When renewal was granted
    new_expiration_date TEXT,

    -- Status
    status TEXT,                            -- 'approved', 'denied', 'pending'
    denial_reason TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (license_id) REFERENCES licenses(id)
);

CREATE INDEX idx_license_renewal_history_license ON license_renewal_history(license_id);


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
    pt.regulatory_framework_code,
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
-- All upcoming compliance obligations (permits and licenses unified).

CREATE VIEW IF NOT EXISTS v_compliance_calendar_upcoming AS
SELECT
    cc.id AS calendar_id,
    cc.establishment_id,
    e.name AS establishment_name,
    cc.event_name,
    cot.name AS obligation_type,
    cc.obligation_type_code,
    cc.source_type,
    cc.due_date,
    CAST(julianday(cc.due_date) - julianday('now') AS INTEGER) AS days_until_due,
    cc.status,
    p.permit_number,
    l.license_number,
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
INNER JOIN compliance_obligation_types cot ON cc.obligation_type_code = cot.code
LEFT JOIN permits p ON cc.permit_id = p.id
LEFT JOIN licenses l ON cc.license_id = l.id
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
    pd.corrective_action_id,
    pd.incident_id,
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
-- VIEWS: License Management
-- ============================================================================

-- ----------------------------------------------------------------------------
-- V_LICENSES_EXPIRING
-- ----------------------------------------------------------------------------
-- Licenses approaching expiration.

CREATE VIEW IF NOT EXISTS v_licenses_expiring AS
SELECT
    l.id AS license_id,
    l.license_number,
    l.license_name,
    l.establishment_id,
    e.name AS establishment_name,
    lt.type_name AS license_type,
    lt.category,
    lt.holder_type,
    -- Holder info
    CASE lt.holder_type
        WHEN 'employee' THEN emp.first_name || ' ' || emp.last_name
        WHEN 'establishment' THEN e.name
        ELSE 'Equipment: ' || COALESCE(l.holder_equipment_id, '')
    END AS holder_name,
    l.license_class,
    l.expiration_date,
    CAST(julianday(l.expiration_date) - julianday('now') AS INTEGER) AS days_until_expiration,
    lt.renewal_lead_time_days,
    date(l.expiration_date, '-' || lt.renewal_lead_time_days || ' days') AS renewal_deadline,
    l.renewal_status,
    CASE
        WHEN l.renewal_status = 'renewal_submitted' THEN 'RENEWAL_PENDING'
        WHEN date(l.expiration_date) < date('now') THEN 'EXPIRED'
        WHEN date(l.expiration_date) <= date('now', '+30 days') THEN 'EXPIRES_SOON'
        WHEN date(l.expiration_date, '-' || lt.renewal_lead_time_days || ' days') < date('now') THEN 'RENEWAL_DUE'
        ELSE 'OK'
    END AS urgency
FROM licenses l
INNER JOIN establishments e ON l.establishment_id = e.id
INNER JOIN license_types lt ON l.license_type_id = lt.id
LEFT JOIN employees emp ON l.holder_employee_id = emp.id
WHERE l.status = 'active'
  AND l.expiration_date IS NOT NULL
ORDER BY l.expiration_date ASC;


-- ----------------------------------------------------------------------------
-- V_LICENSE_CE_STATUS
-- ----------------------------------------------------------------------------
-- CE progress for licenses requiring continuing education.

CREATE VIEW IF NOT EXISTS v_license_ce_status AS
SELECT
    l.id AS license_id,
    l.license_number,
    l.establishment_id,
    lt.type_name AS license_type,
    emp.first_name || ' ' || emp.last_name AS holder_name,
    l.ce_period_start,
    l.ce_period_end,
    l.ce_hours_required,
    l.ce_hours_completed,
    l.ce_hours_required - l.ce_hours_completed AS ce_hours_remaining,
    ROUND(100.0 * l.ce_hours_completed / NULLIF(l.ce_hours_required, 0), 1) AS percent_complete,
    CAST(julianday(l.ce_period_end) - julianday('now') AS INTEGER) AS days_until_period_end,
    CASE
        WHEN l.ce_hours_completed >= l.ce_hours_required THEN 'COMPLETE'
        WHEN date(l.ce_period_end) < date('now') THEN 'PERIOD_ENDED'
        WHEN date(l.ce_period_end) <= date('now', '+90 days')
             AND l.ce_hours_completed < l.ce_hours_required THEN 'BEHIND'
        ELSE 'ON_TRACK'
    END AS ce_status
FROM licenses l
INNER JOIN license_types lt ON l.license_type_id = lt.id
LEFT JOIN employees emp ON l.holder_employee_id = emp.id
WHERE l.status = 'active'
  AND lt.requires_continuing_education = 1
  AND l.ce_period_end IS NOT NULL
ORDER BY l.ce_period_end ASC;


-- ----------------------------------------------------------------------------
-- V_EMPLOYEE_LICENSES
-- ----------------------------------------------------------------------------
-- All licenses held by employees.

CREATE VIEW IF NOT EXISTS v_employee_licenses AS
SELECT
    emp.id AS employee_id,
    emp.first_name || ' ' || emp.last_name AS employee_name,
    emp.job_title,
    l.id AS license_id,
    l.license_number,
    lt.type_name AS license_type,
    lt.category,
    l.license_class,
    l.license_level,
    l.expiration_date,
    l.status,
    l.ce_hours_required,
    l.ce_hours_completed,
    CASE
        WHEN l.status != 'active' THEN 'INACTIVE'
        WHEN date(l.expiration_date) < date('now') THEN 'EXPIRED'
        WHEN date(l.expiration_date) <= date('now', '+30 days') THEN 'EXPIRES_SOON'
        ELSE 'CURRENT'
    END AS license_status
FROM employees emp
INNER JOIN licenses l ON emp.id = l.holder_employee_id
INNER JOIN license_types lt ON l.license_type_id = lt.id
ORDER BY emp.last_name, emp.first_name, l.expiration_date;


-- ----------------------------------------------------------------------------
-- V_LICENSE_SUMMARY
-- ----------------------------------------------------------------------------
-- Summary of licenses by establishment.

CREATE VIEW IF NOT EXISTS v_license_summary AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    -- Counts by category
    SUM(CASE WHEN lt.category = 'business' THEN 1 ELSE 0 END) AS business_licenses,
    SUM(CASE WHEN lt.category = 'professional' THEN 1 ELSE 0 END) AS professional_licenses,
    SUM(CASE WHEN lt.category = 'operator' THEN 1 ELSE 0 END) AS operator_licenses,
    SUM(CASE WHEN lt.category = 'equipment' THEN 1 ELSE 0 END) AS equipment_registrations,
    COUNT(l.id) AS total_licenses,

    -- Status counts
    SUM(CASE WHEN l.status = 'active' THEN 1 ELSE 0 END) AS active_licenses,
    SUM(CASE WHEN l.status = 'expired' THEN 1 ELSE 0 END) AS expired_licenses,

    -- Expiring soon (next 60 days)
    SUM(CASE WHEN l.expiration_date IS NOT NULL
             AND date(l.expiration_date) <= date('now', '+60 days')
             AND date(l.expiration_date) > date('now')
             AND l.status = 'active' THEN 1 ELSE 0 END) AS expiring_soon,

    -- CE behind
    (SELECT COUNT(*) FROM v_license_ce_status vcs
     WHERE vcs.establishment_id = e.id
       AND vcs.ce_status = 'BEHIND') AS ce_behind_count

FROM establishments e
LEFT JOIN licenses l ON e.id = l.establishment_id
LEFT JOIN license_types lt ON l.license_type_id = lt.id
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
-- Update CE hours completed when CE record added
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_license_ce_add
AFTER INSERT ON license_continuing_education
BEGIN
    UPDATE licenses
    SET ce_hours_completed = (
            SELECT COALESCE(SUM(ce_hours), 0)
            FROM license_continuing_education
            WHERE license_id = NEW.license_id
              AND activity_date >= (SELECT ce_period_start FROM licenses WHERE id = NEW.license_id)
              AND activity_date <= (SELECT ce_period_end FROM licenses WHERE id = NEW.license_id)
        ),
        updated_at = datetime('now')
    WHERE id = NEW.license_id;
END;

-- ----------------------------------------------------------------------------
-- Update CE hours when CE record deleted
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_license_ce_delete
AFTER DELETE ON license_continuing_education
BEGIN
    UPDATE licenses
    SET ce_hours_completed = (
            SELECT COALESCE(SUM(ce_hours), 0)
            FROM license_continuing_education
            WHERE license_id = OLD.license_id
              AND activity_date >= (SELECT ce_period_start FROM licenses WHERE id = OLD.license_id)
              AND activity_date <= (SELECT ce_period_end FROM licenses WHERE id = OLD.license_id)
        ),
        updated_at = datetime('now')
    WHERE id = OLD.license_id;
END;


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
MODULE: PERMITS & LICENSES (module_permits_licenses.sql)
Derived from ehs-ontology-v3.1.ttl — RegulatoryFramework + Evaluation classes

PURPOSE:
Combined module tracking environmental/operational permits and business/
professional/operator licenses. Permits are concrete instantiations of the
ontology's RegulatoryFramework at a facility level. The compliance calendar
operationalizes the ontology's Evaluation concept.

ONTOLOGY CONNECTIONS:
  - permit_types.regulatory_framework_code → RegulatoryFramework subclasses
    (CAA_Framework, CWA_Framework, EPA_Framework)
  - compliance_calendar → Evaluation (the 5th E feedback loop)
  - compliance_obligation_types → Evaluation subclasses
  - permit_deviations.corrective_action_id → corrective_actions (Module C/D)
  - permit_deviations.incident_id → incidents (Module C/D)
  - Module B air_emission_units.permit_id → permits.id

REFERENCE TABLES:
    - regulatory_agencies: Agencies that issue permits
    - permit_types: 17 seeded types with regulatory framework mapping
    - compliance_obligation_types: 10 seeded obligation categories
    - license_types: 24 seeded types across 4 categories
    - license_issuing_authorities: Bodies that issue licenses

PERMIT TABLES:
    - permits: Master permit record with dates, status, renewal tracking
    - permit_conditions: Individual conditions within permits
    - permit_limits: Specific numeric limits (emission, discharge, etc.)
    - permit_modifications: Amendment/modification history
    - permit_monitoring_requirements: What monitoring must be performed
    - permit_reporting_requirements: Reports that must be submitted
    - permit_report_submissions: Tracking of actual report submissions
    - permit_deviations: Exceedances and deviations with cross-module FKs

LICENSE TABLES:
    - licenses: Master license record (establishment, employee, or equipment)
    - license_continuing_education: CE credit tracking
    - license_renewal_history: Historical renewal records

COMPLIANCE TRACKING:
    - compliance_calendar: Unified calendar for permit + license obligations
      with obligation_type_code FK to controlled vocabulary

VIEWS (9):
  Permits:
    - v_permits_expiring: Permits approaching expiration/renewal
    - v_reports_due: Upcoming report submissions
    - v_compliance_calendar_upcoming: All upcoming obligations (unified)
    - v_open_deviations: Deviations needing attention
    - v_permit_summary: Summary by establishment
  Licenses:
    - v_licenses_expiring: Licenses approaching expiration
    - v_license_ce_status: CE progress for CE-required licenses
    - v_employee_licenses: All licenses held by employees
    - v_license_summary: Summary counts by establishment

TRIGGERS (3):
    - trg_deviation_percent_over: Auto-calculate exceedance percentage
    - trg_license_ce_add: Auto-update CE hours on CE record insert
    - trg_license_ce_delete: Auto-update CE hours on CE record delete

PRE-SEEDED PERMIT TYPES (17):
    Air (6): TITLE_V, NSR_MAJOR, PSD, MINOR_SOURCE, PTI, GP_AIR
    Water (5): NPDES_INDIVIDUAL, NPDES_GENERAL, NPDES_STORMWATER, PRETREATMENT, GWDP
    Waste (3): RCRA_TSDF, RCRA_GENERATOR, USED_OIL
    Other (3): SPCC, RMP, TIER2

PRE-SEEDED LICENSE TYPES (24):
    Business (5): BUSINESS, FIRE_PERMIT, OCCUPANCY, ZONING, SALES_TAX
    Professional (7): PE, CIH, CSP, ASP, CHMM, QEP, REM
    Operator (7): WASTEWATER_OP, WATER_OP, BOILER_OP, CRANE_OP, FORKLIFT_TRAINER, CDL, HAZMAT_CDL
    Equipment (6): BOILER_REG, PRESSURE_VESSEL, ELEVATOR, UST, AST, SCALE

COMPLIANCE OBLIGATION TYPES (10):
    REPORT_SUBMISSION, PERMIT_RENEWAL, LICENSE_RENEWAL, FEE_PAYMENT,
    INSPECTION_DUE, CERTIFICATION_DUE, MONITORING_DUE, CE_DEADLINE,
    TESTING_DUE, TRAINING_DUE

CROSS-MODULE REFERENCES:
    - establishments (shared foundation) — referenced, not redefined
    - employees (shared foundation) — referenced, not redefined
    - corrective_actions (Module C/D) — permit_deviations.corrective_action_id
    - incidents (Module C/D) — permit_deviations.incident_id
    - air_emission_units (Module B) — references permits.id
*/
