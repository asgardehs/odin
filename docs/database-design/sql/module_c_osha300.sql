-- Module C: OSHA 300 Recordkeeping (29 CFR 1904)
-- Derived from ehs-ontology-v3.1.ttl — Module C + relevant Module D classes
--
-- Design principle: separate the EVENT (what happened) from the RECORDING
-- DECISION (is it recordable?) from the LOG ENTRY (the OSHA form data).
-- The ontology models recordability as a two-gate decision tree:
--   Gate 1: Work-relatedness (1904.5)
--   Gate 2: Recording criteria (1904.7)
-- This schema makes that decision chain explicit and auditable.


-- ============================================================================
-- SHARED FOUNDATION (referenced by all modules)
-- ============================================================================

CREATE TABLE IF NOT EXISTS establishments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    street_address TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,                        -- 2-letter code
    zip TEXT NOT NULL,
    industry_description TEXT,
    naics_code TEXT,                            -- Determines TRI coverage, OSHA exemptions, ITA tier
    sic_code TEXT,                              -- Legacy, still used by some OSHA systems

    -- Establishment size (drives ITA submission tier)
    peak_employees INTEGER,                    -- Peak count during calendar year
    annual_avg_employees INTEGER,
    total_hours_worked INTEGER,                -- Updated yearly for rate calculations

    -- OSHA ITA reporting fields (v3.3, 29 CFR 1904.41)
    ein TEXT,                                   -- IRS Employer Identification Number (XX-XXXXXXX)
    company_name TEXT,                          -- Parent legal entity name (distinct from establishment name)
    size_code TEXT,                             -- FK → ita_establishment_sizes
    establishment_type_code TEXT,               -- FK → ita_establishment_types

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (size_code) REFERENCES ita_establishment_sizes(code),
    FOREIGN KEY (establishment_type_code) REFERENCES ita_establishment_types(code)
);

CREATE TABLE IF NOT EXISTS employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Identity
    employee_number TEXT,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,

    -- OSHA 301 required fields
    street_address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    date_of_birth TEXT,                        -- YYYY-MM-DD
    date_hired TEXT,                            -- YYYY-MM-DD
    gender TEXT,                                -- M/F/X for OSHA reporting

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
-- REFERENCE: RECORDING CRITERIA (from ontology RecordingCriteria subclasses)
-- ============================================================================
-- The 9 recording criteria from 29 CFR 1904.7-1904.10.
-- Each is an independent trigger — meeting ANY ONE makes a case recordable.

CREATE TABLE IF NOT EXISTS recording_criteria (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    cfr_reference TEXT NOT NULL,               -- Specific CFR section
    description TEXT NOT NULL,
    is_osha_reportable INTEGER DEFAULT 0,      -- Also requires direct OSHA notification?
    osha_report_hours INTEGER,                 -- Hours to report (8 for fatality, 24 for others)
    is_privacy_case INTEGER DEFAULT 0          -- Auto-flags as privacy case on 300 Log
);

INSERT OR IGNORE INTO recording_criteria (code, name, cfr_reference, description, is_osha_reportable, osha_report_hours, is_privacy_case) VALUES
    ('DEATH',          'Death',                             '1904.7(b)(2)',  'Work-related fatality. No time limit on when death occurs relative to injury.', 1, 8, 0),
    ('DAYS_AWAY',      'Days Away from Work',               '1904.7(b)(3)',  'One or more calendar days unable to work. Count starts day after event, capped at 180 days.', 0, NULL, 0),
    ('RESTRICTED',     'Restricted Work or Job Transfer',   '1904.7(b)(4)',  'Cannot perform routine functions, full shift, or transferred to another job. Capped at 180 days.', 0, NULL, 0),
    ('MEDICAL_TX',     'Medical Treatment Beyond First Aid', '1904.7(b)(5)', 'Any treatment NOT on the exhaustive first aid list. Provider status irrelevant.', 0, NULL, 0),
    ('LOC',            'Loss of Consciousness',             '1904.7(b)(6)',  'Any work-related loss of consciousness, regardless of duration.', 0, NULL, 0),
    ('SIG_DIAGNOSIS',  'Significant Diagnosed Condition',   '1904.7(b)(7)',  'Cancer, chronic irreversible disease, fractured/cracked bone, or punctured eardrum diagnosed by PLHCP.', 0, NULL, 0),
    ('NEEDLESTICK',    'Needlestick/Sharps Injury',         '1904.8',       'Needlestick or cut from sharp contaminated with blood or OPIM.', 0, NULL, 1),
    ('HEARING_LOSS',   'Standard Threshold Shift',          '1904.10',      'STS of avg 10+ dB at 2k/3k/4k Hz AND total hearing 25+ dB above audiometric zero.', 0, NULL, 0),
    ('MEDICAL_REMOVAL','Medical Removal',                   '1904.9',       'Removed under OSHA substance-specific standard surveillance (lead, cadmium, benzene, etc).', 0, NULL, 0);


-- ============================================================================
-- REFERENCE: OSHA REPORTING OBLIGATIONS (separate from 300 Log recording)
-- ============================================================================
-- Events that must be reported DIRECTLY to OSHA, independent of the 300 Log.
-- The clock starts when the employer LEARNS of the event, not when it occurs.

CREATE TABLE IF NOT EXISTS osha_reporting_triggers (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    report_within_hours INTEGER NOT NULL,
    cfr_reference TEXT NOT NULL,
    description TEXT NOT NULL
);

INSERT OR IGNORE INTO osha_reporting_triggers (code, name, report_within_hours, cfr_reference, description) VALUES
    ('FATALITY',        'Work-related fatality',     8,  '1904.39(a)(1)', 'Report within 8 hours of learning of the death.'),
    ('HOSPITALIZATION', 'In-patient hospitalization', 24, '1904.39(a)(2)', 'Admitted as an in-patient. ER visit without admission is NOT reportable.'),
    ('AMPUTATION',      'Amputation',                24, '1904.39(a)(2)', 'Any work-related amputation.'),
    ('EYE_LOSS',        'Loss of an eye',            24, '1904.39(a)(2)', 'Any work-related loss of an eye.');


-- ============================================================================
-- REFERENCE: WORK-RELATEDNESS EXCEPTIONS (1904.5(b)(2))
-- ============================================================================
-- If an exception applies, the case is NOT work-related and recording stops.
-- This is Gate 1 of the decision tree.

CREATE TABLE IF NOT EXISTS work_relatedness_exceptions (
    code TEXT PRIMARY KEY,
    description TEXT NOT NULL,
    cfr_reference TEXT DEFAULT '1904.5(b)(2)'
);

INSERT OR IGNORE INTO work_relatedness_exceptions (code, description) VALUES
    ('GENERAL_PUBLIC',   'Present at workplace as member of the general public'),
    ('PREEXISTING',      'Symptoms of non-work-related condition surface at work'),
    ('WELLNESS',         'Voluntary participation in wellness/fitness/recreation program'),
    ('FOOD_PERSONAL',    'Eating/drinking food/beverage not provided by employer'),
    ('PERSONAL_TASK',    'Personal tasks outside assigned working hours'),
    ('GROOMING',         'Personal grooming, self-medication for non-work condition, self-inflicted'),
    ('MVA_COMMUTE',      'Motor vehicle accident in parking lot/access road during commute'),
    ('COLD_FLU',         'Common cold or flu (not work-related contagious disease)'),
    ('MENTAL_ILLNESS',   'Mental illness, unless PLHCP opinion provided voluntarily by employee');


-- ============================================================================
-- REFERENCE: FIRST AID TREATMENTS (exhaustive list from 1904.7(b)(5)(ii))
-- ============================================================================
-- If the ONLY treatment provided is on this list, the case is NOT recordable
-- under the medical treatment criterion. Anything NOT on this list = medical
-- treatment = recordable.

CREATE TABLE IF NOT EXISTS first_aid_treatments (
    code TEXT PRIMARY KEY,
    description TEXT NOT NULL
);

INSERT OR IGNORE INTO first_aid_treatments (code, description) VALUES
    ('OTC_MEDS',         'Non-prescription medications at non-prescription strength'),
    ('TETANUS',          'Tetanus immunizations (other immunizations = medical treatment)'),
    ('WOUND_CLEAN',      'Cleaning, flushing, soaking surface wounds'),
    ('WOUND_COVER',      'Wound coverings: bandages, Band-Aids, gauze, butterfly, Steri-Strips'),
    ('HOT_COLD',         'Hot or cold therapy'),
    ('NONRIGID_SUPPORT', 'Non-rigid support: elastic bandages, wraps, non-rigid back belts'),
    ('TEMP_IMMOBILIZE',  'Temporary immobilization devices used solely for transport'),
    ('NAIL_BLISTER',     'Drilling nail to relieve pressure, draining fluid from blister'),
    ('EYE_PATCH',        'Eye patches'),
    ('EYE_FOREIGN_BODY', 'Removing foreign body from eye using irrigation or cotton swab'),
    ('SPLINTER',         'Removing splinters/foreign material by irrigation, tweezers, cotton swab'),
    ('FINGER_GUARD',     'Finger guards'),
    ('MASSAGE',          'Massages'),
    ('FLUIDS_HEAT',      'Drinking fluids for relief of heat stress');


-- ============================================================================
-- REFERENCE: CASE CLASSIFICATIONS (OSHA 300 Log columns)
-- ============================================================================

CREATE TABLE IF NOT EXISTS case_classifications (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    osha_300_column TEXT NOT NULL,             -- Which column on the 300 Log
    is_illness INTEGER DEFAULT 0
);

INSERT OR IGNORE INTO case_classifications (code, name, osha_300_column, is_illness) VALUES
    ('INJURY',    'Injury',                 'F',  0),
    ('SKIN',      'Skin disorder',          'M1', 1),
    ('RESP',      'Respiratory condition',  'M2', 1),
    ('POISON',    'Poisoning',              'M3', 1),
    ('HEARING',   'Hearing loss',           'M4', 1),
    ('OTHER_ILL', 'All other illnesses',    'M5', 1);


-- ============================================================================
-- REFERENCE: BODY PARTS (OSHA BLS codes)
-- ============================================================================

CREATE TABLE IF NOT EXISTS body_parts (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT                               -- head, torso, upper_extremity, lower_extremity, multiple
);

INSERT OR IGNORE INTO body_parts (code, name, category) VALUES
    ('HEAD',       'Head',                    'head'),
    ('EYE',        'Eye(s)',                  'head'),
    ('EAR',        'Ear(s)',                  'head'),
    ('FACE',       'Face',                    'head'),
    ('NECK',       'Neck',                    'head'),
    ('SHOULDER',   'Shoulder',                'upper_extremity'),
    ('ARM_UPPER',  'Upper arm',              'upper_extremity'),
    ('ELBOW',      'Elbow',                  'upper_extremity'),
    ('ARM_LOWER',  'Lower arm/forearm',      'upper_extremity'),
    ('WRIST',      'Wrist',                  'upper_extremity'),
    ('HAND',       'Hand (except fingers)',   'upper_extremity'),
    ('FINGER',     'Finger(s)',              'upper_extremity'),
    ('CHEST',      'Chest',                  'torso'),
    ('BACK_UPPER', 'Upper back',             'torso'),
    ('BACK_LOWER', 'Lower back',             'torso'),
    ('ABDOMEN',    'Abdomen',                'torso'),
    ('HIP',        'Hip',                    'lower_extremity'),
    ('THIGH',      'Thigh',                  'lower_extremity'),
    ('KNEE',       'Knee',                   'lower_extremity'),
    ('LEG_LOWER',  'Lower leg',             'lower_extremity'),
    ('ANKLE',      'Ankle',                  'lower_extremity'),
    ('FOOT',       'Foot (except toes)',     'lower_extremity'),
    ('TOE',        'Toe(s)',                 'lower_extremity'),
    ('MULTIPLE',   'Multiple body parts',    'multiple'),
    ('BODY_SYS',   'Body systems',           'multiple');


-- ============================================================================
-- REFERENCE: INCIDENT SEVERITY (Module D — needed for C cross-reference)
-- ============================================================================
-- Maps to Module D IncidentSeverity subclasses.
-- alignsWithRecordingCriteria links severity → recording outcome.

CREATE TABLE IF NOT EXISTS incident_severity_levels (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    is_osha_recordable INTEGER DEFAULT 0,      -- Does this severity ALWAYS imply recordability?
    aligned_recording_criteria TEXT,            -- FK to recording_criteria.code (NULL = not recordable)
    description TEXT NOT NULL
);

INSERT OR IGNORE INTO incident_severity_levels (code, name, is_osha_recordable, aligned_recording_criteria, description) VALUES
    ('FATALITY',    'Fatality',                    1, 'DEATH',      'Death. OSHA 8-hour report + full RCA required.'),
    ('LOST_TIME',   'Lost Time Incident',          1, 'DAYS_AWAY',  'One or more days away from work beyond day of event.'),
    ('RESTRICTED',  'Restricted Duty Incident',    1, 'RESTRICTED', 'Employee restricted from routine functions or transferred.'),
    ('MEDICAL_TX',  'Medical Treatment Incident',  1, 'MEDICAL_TX', 'Medical treatment beyond first aid, no days away or restriction.'),
    ('FIRST_AID',   'First Aid Incident',          0, NULL,         'First aid only. NOT recordable. Track as leading indicator.'),
    ('NEAR_MISS',   'Near Miss',                   0, NULL,         'No injury but potential for harm. Best practice to investigate.'),
    ('PROPERTY',    'Property Damage',             0, NULL,         'Equipment/facility damage, no human injury.'),
    ('ENVIRONMENTAL','Environmental Incident',     0, NULL,         'Unplanned release. May trigger EPA/EPCRA, not OSHA 300.');


-- ============================================================================
-- INCIDENTS (the event — Module D, but foundation for Module C)
-- ============================================================================
-- This is WHAT HAPPENED. The recording decision is separate.
-- An incident exists whether or not it ends up on the 300 Log.

CREATE TABLE IF NOT EXISTS incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    employee_id INTEGER,                       -- NULL for non-employee or property/environmental

    -- Case tracking
    case_number TEXT UNIQUE,                   -- Format: YYYY-NNN per establishment per year

    -- When and where
    incident_date TEXT NOT NULL,                -- YYYY-MM-DD
    incident_time TEXT,                         -- HH:MM (24-hour)
    time_employee_began_work TEXT,              -- OSHA 301 item 11
    location_description TEXT,

    -- What happened (OSHA 301 items 13-15)
    activity_description TEXT,                  -- What was employee doing?
    incident_description TEXT NOT NULL,         -- How did the injury/illness occur?
    object_or_substance TEXT,                   -- What harmed the employee?

    -- Injury/illness details
    case_classification_code TEXT,              -- FK → case_classifications
    body_part_code TEXT,                        -- FK → body_parts

    -- Severity (Module D)
    severity_code TEXT NOT NULL DEFAULT 'FIRST_AID', -- FK → incident_severity_levels

    -- Treatment
    treatment_provided TEXT,                    -- What treatment was given
    treating_physician TEXT,                    -- OSHA 301 item 6
    treatment_facility TEXT,                    -- OSHA 301 item 7 (facility name/address, free text)
    treatment_facility_type_code TEXT,          -- FK → ita_treatment_facility_types (v3.3)
    was_hospitalized INTEGER DEFAULT 0,         -- In-patient admission (triggers OSHA 24-hr report)
    was_er_visit INTEGER DEFAULT 0,

    -- OSHA ITA fields (v3.3)
    days_away_from_work INTEGER,                -- 29 CFR 1904.7(b)(3), 180-day cap
    days_restricted_or_transferred INTEGER,     -- 29 CFR 1904.7(b)(4), 180-day cap shared with days_away_from_work
    date_of_death TEXT,                         -- YYYY-MM-DD; nullable; populated when case transitions to fatality
    time_unknown INTEGER DEFAULT 0,             -- Boolean; 1 when incident_time cannot be determined
    injury_illness_description TEXT,            -- OSHA 301 item 16 / ITA nar_injury_illness (distinct from incident_description)

    -- Reporting
    reported_by TEXT,
    reported_date TEXT,

    -- Status
    status TEXT DEFAULT 'reported',             -- reported, investigating, pending_review, closed
    closed_date TEXT,
    closed_by TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (case_classification_code) REFERENCES case_classifications(code),
    FOREIGN KEY (body_part_code) REFERENCES body_parts(code),
    FOREIGN KEY (severity_code) REFERENCES incident_severity_levels(code),
    FOREIGN KEY (treatment_facility_type_code) REFERENCES ita_treatment_facility_types(code)
);

CREATE INDEX idx_incidents_establishment ON incidents(establishment_id);
CREATE INDEX idx_incidents_date ON incidents(incident_date);
CREATE INDEX idx_incidents_employee ON incidents(employee_id);
CREATE INDEX idx_incidents_severity ON incidents(severity_code);
CREATE INDEX idx_incidents_case_number ON incidents(case_number);


-- ============================================================================
-- RECORDING DECISIONS (the two-gate decision tree — Module C core)
-- ============================================================================
-- This is WHERE THE ONTOLOGY LIVES in the database. Every incident gets a
-- recording decision that documents the two-gate process:
--   Gate 1: Is it work-related? (presumed yes unless exception applies)
--   Gate 2: Does it meet any recording criteria?
--
-- This table makes the decision auditable — an OSHA inspector can see
-- exactly WHY a case was or was not recorded, not just a boolean flag.

CREATE TABLE IF NOT EXISTS recording_decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL UNIQUE,        -- One decision per incident

    -- Gate 1: Work-relatedness (1904.5)
    occurred_in_work_environment INTEGER NOT NULL DEFAULT 1,  -- Presumed yes
    exception_code TEXT,                        -- FK → work_relatedness_exceptions (NULL = no exception)
    is_work_related INTEGER NOT NULL,           -- Final determination (gate 1 result)
    work_relatedness_notes TEXT,                -- Reasoning for non-obvious cases

    -- Gate 2: Recording criteria (1904.7-1904.10)
    -- Which criteria were evaluated and which fired
    is_recordable INTEGER NOT NULL DEFAULT 0,   -- Final determination (gate 2 result)

    -- Day counts (if applicable)
    days_away_from_work INTEGER DEFAULT 0,      -- Calendar days, starts day after, capped 180
    days_restricted_duty INTEGER DEFAULT 0,     -- Calendar days, capped 180
    days_job_transfer INTEGER DEFAULT 0,        -- Calendar days, capped 180

    -- Privacy case flag
    is_privacy_case INTEGER DEFAULT 0,          -- Hide employee name on 300 Log

    -- Decision metadata
    determined_by TEXT,
    determined_date TEXT,
    review_notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (incident_id) REFERENCES incidents(id),
    FOREIGN KEY (exception_code) REFERENCES work_relatedness_exceptions(code)
);

CREATE INDEX idx_recording_decisions_incident ON recording_decisions(incident_id);
CREATE INDEX idx_recording_decisions_recordable ON recording_decisions(is_recordable);


-- ============================================================================
-- RECORDING CRITERIA MET (junction table — which criteria fired)
-- ============================================================================
-- An incident can meet multiple recording criteria simultaneously
-- (e.g., days away AND medical treatment AND loss of consciousness).
-- Only one 300 Log entry is made, but tracking ALL criteria that fired
-- matters for audits and for guiding users through the decision.

CREATE TABLE IF NOT EXISTS recording_criteria_met (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    recording_decision_id INTEGER NOT NULL,
    criteria_code TEXT NOT NULL,                -- FK → recording_criteria
    notes TEXT,                                 -- Specifics: "STS confirmed on retest 2026-03-15"

    FOREIGN KEY (recording_decision_id) REFERENCES recording_decisions(id) ON DELETE CASCADE,
    FOREIGN KEY (criteria_code) REFERENCES recording_criteria(code),
    UNIQUE(recording_decision_id, criteria_code)
);


-- ============================================================================
-- OSHA DIRECT REPORTS (8-hour / 24-hour reporting obligations)
-- ============================================================================
-- Separate from the 300 Log. Tracks whether required reports were filed.

CREATE TABLE IF NOT EXISTS osha_direct_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL,
    trigger_code TEXT NOT NULL,                 -- FK → osha_reporting_triggers

    -- Reporting timeline
    employer_learned_at TEXT NOT NULL,          -- Datetime — clock starts here
    report_deadline TEXT NOT NULL,              -- Calculated: learned_at + trigger hours
    reported_at TEXT,                           -- When actually reported (NULL = not yet)
    reported_via TEXT,                          -- 'phone' or 'online'
    osha_reference_number TEXT,                 -- Confirmation number from OSHA

    -- Status
    is_overdue INTEGER GENERATED ALWAYS AS (
        reported_at IS NULL AND datetime('now') > report_deadline
    ) STORED,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (incident_id) REFERENCES incidents(id),
    FOREIGN KEY (trigger_code) REFERENCES osha_reporting_triggers(code)
);

CREATE INDEX idx_osha_direct_reports_incident ON osha_direct_reports(incident_id);


-- ============================================================================
-- TREATMENTS PROVIDED (tracks what was actually done — first aid vs medical)
-- ============================================================================
-- Links to first_aid_treatments reference table where applicable.
-- If the treatment IS on the first aid list → not recordable via MEDICAL_TX.
-- If the treatment is NOT on the list → medical treatment → recordable.

CREATE TABLE IF NOT EXISTS incident_treatments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL,
    treatment_description TEXT NOT NULL,
    first_aid_code TEXT,                        -- FK → first_aid_treatments (NULL = medical treatment)
    is_first_aid INTEGER NOT NULL,              -- Explicit flag for clarity
    provided_by TEXT,
    provided_date TEXT,

    FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE CASCADE,
    FOREIGN KEY (first_aid_code) REFERENCES first_aid_treatments(code)
);

CREATE INDEX idx_incident_treatments_incident ON incident_treatments(incident_id);


-- ============================================================================
-- WITNESSES (normalized out of the incident table)
-- ============================================================================

CREATE TABLE IF NOT EXISTS incident_witnesses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL,
    witness_name TEXT NOT NULL,
    witness_phone TEXT,
    statement TEXT,
    statement_date TEXT,

    FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE CASCADE
);


-- ============================================================================
-- OSHA 300A ANNUAL SUMMARIES
-- ============================================================================
-- Calculated from incident + recording_decision data.
-- Stored for historical reference and certification tracking.

CREATE TABLE IF NOT EXISTS osha_300a_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    year INTEGER NOT NULL,

    -- Establishment info at time of summary
    annual_avg_employees INTEGER,
    total_hours_worked INTEGER,

    -- Case counts by severity (OSHA 300A Section 1)
    total_deaths INTEGER DEFAULT 0,
    total_days_away_cases INTEGER DEFAULT 0,
    total_restricted_transfer_cases INTEGER DEFAULT 0,
    total_other_recordable_cases INTEGER DEFAULT 0,

    -- Day counts (OSHA 300A Section 2)
    total_days_away INTEGER DEFAULT 0,
    total_days_restricted INTEGER DEFAULT 0,

    -- Case counts by type (OSHA 300A Section 3)
    injury_count INTEGER DEFAULT 0,
    skin_disorder_count INTEGER DEFAULT 0,
    respiratory_count INTEGER DEFAULT 0,
    poisoning_count INTEGER DEFAULT 0,
    hearing_loss_count INTEGER DEFAULT 0,
    other_illness_count INTEGER DEFAULT 0,

    -- Calculated rates (stored for convenience, derived from above)
    trir REAL,                                  -- (total recordable × 200000) / hours worked
    dart_rate REAL,                             -- ((days_away + restricted_transfer) × 200000) / hours worked
    ltir REAL,                                  -- (days_away_cases × 200000) / hours worked
    severity_rate REAL,                         -- ((total_days_away + total_days_restricted) × 200000) / hours worked

    -- Certification (must be company executive)
    certified_by TEXT,
    certified_title TEXT,
    certified_phone TEXT,
    certified_date TEXT,                        -- Must be completed by Feb 1, posted Feb 1 - Apr 30

    -- ITA electronic submission
    ita_submission_required INTEGER DEFAULT 0,
    ita_submission_tier TEXT,                   -- '300A_only' or '300_301_300A'
    ita_submitted_date TEXT,                    -- Due March 2

    generated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, year)
);


-- ============================================================================
-- INVESTIGATION + CORRECTIVE ACTIONS (Module D, needed for complete workflow)
-- ============================================================================

CREATE TABLE IF NOT EXISTS incident_investigations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL,

    -- Investigation metadata
    initiated_date TEXT NOT NULL,
    completed_date TEXT,
    lead_investigator TEXT,

    -- Root cause analysis
    rca_method TEXT,                            -- 'five_whys', 'fishbone', 'fault_tree', 'taproot'
    root_causes TEXT,                           -- Systemic failures, NOT "employee error"
    contributing_factors TEXT,
    immediate_actions_taken TEXT,

    -- ARECC connection (which phase does this feed back into?)
    arecc_phase TEXT,                           -- 'anticipate', 'recognize', 'evaluate', 'control', 'confirm'

    -- Status
    status TEXT DEFAULT 'open',                 -- open, in_progress, completed, reviewed

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (incident_id) REFERENCES incidents(id)
);

CREATE INDEX idx_investigations_incident ON incident_investigations(incident_id);

CREATE TABLE IF NOT EXISTS investigation_team_members (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    investigation_id INTEGER NOT NULL,
    employee_id INTEGER,                        -- NULL for external participants
    name TEXT NOT NULL,
    role TEXT,                                   -- 'lead', 'supervisor', 'ehs', 'employee_rep', 'sme'

    FOREIGN KEY (investigation_id) REFERENCES incident_investigations(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE TABLE IF NOT EXISTS corrective_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    investigation_id INTEGER NOT NULL,

    description TEXT NOT NULL,

    -- Hierarchy of Controls link (from ontology ControlMeasure)
    hierarchy_level TEXT NOT NULL,              -- 'elimination', 'substitution', 'engineering', 'administrative', 'ppe'
    hierarchy_justification TEXT,               -- Required if administrative or PPE: why not higher?

    -- Assignment and tracking
    assigned_to TEXT,
    due_date TEXT,

    -- Status lifecycle (from ontology CorrectiveActionStatus)
    status TEXT DEFAULT 'open',                -- open, in_progress, completed, verified, overdue

    -- Completion
    completed_date TEXT,
    completed_by TEXT,

    -- Verification (the critical step — action isn't done until effectiveness confirmed)
    verified_date TEXT,
    verified_by TEXT,
    verification_notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (investigation_id) REFERENCES incident_investigations(id) ON DELETE CASCADE
);

CREATE INDEX idx_corrective_actions_investigation ON corrective_actions(investigation_id);
CREATE INDEX idx_corrective_actions_status ON corrective_actions(status);
CREATE INDEX idx_corrective_actions_due_date ON corrective_actions(due_date);


-- ============================================================================
-- v3.3 ADDITIONS — OSHA ITA CSV EXPORT (Phase 4a.2)
-- ============================================================================
-- Derived from ehs-ontology-v3.3.ttl (ITA vocabulary: EstablishmentSize,
-- EstablishmentType, TreatmentFacilityType, ITAIncidentOutcome,
-- ITAIncidentType + SKOS exactMatch mappings).
--
-- Ontology-to-SQL translation rules applied here:
--   - skos:notation on each concept becomes the SQL lookup table's `code`.
--   - dcterms:source becomes the cfr_reference column.
--   - rdfs:label becomes `name`.
--   - skos:definition becomes `description`.
--   - skos:exactMatch triples seed the mapping tables.
--
-- Deferred to the migration-runner ticket:
--   - Adding 4 new columns to `establishments` (ein, company_name,
--     size_code, establishment_type_code).
--   - Adding 6 new columns to `incidents` (days_away_from_work,
--     days_restricted_or_transferred, date_of_death,
--     treatment_facility_type_code, time_unknown,
--     injury_illness_description).
-- Both are stubbed below as comments. Fresh installs will pick them up
-- once the migration runner handles ALTER TABLE idempotency properly.


-- ============================================================================
-- REFERENCE: ITA ESTABLISHMENT SIZE CATEGORIES
-- ============================================================================
-- Three tiers per 29 CFR 1904.41 submission requirements. Sizing is by
-- annual-average peak employment count at the establishment level, not the
-- parent company.

CREATE TABLE IF NOT EXISTS ita_establishment_sizes (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_reference TEXT NOT NULL,
    min_employees INTEGER,                      -- Inclusive lower bound (NULL = no lower)
    max_employees INTEGER                       -- Inclusive upper bound (NULL = no upper)
);

INSERT OR IGNORE INTO ita_establishment_sizes (code, name, description, cfr_reference, min_employees, max_employees) VALUES
    ('SMALL',  'Small (≤ 19 employees)',  'Partially exempt from 29 CFR 1904 recordkeeping unless in a non-partially-exempt industry. Not required to submit electronically via ITA.', '29 CFR 1904.1(a)(1); 29 CFR 1904.41', NULL, 19),
    ('MEDIUM', 'Medium (20–249 employees)', 'Must submit 300A summary electronically via ITA if in a designated high-hazard industry (29 CFR 1904.41 Appendix A).', '29 CFR 1904.41(a)(2)', 20, 249),
    ('LARGE',  'Large (≥ 250 employees)',  'Must submit full 300 Log, 300A summary, AND 301 Incident Reports electronically via ITA regardless of industry.', '29 CFR 1904.41(a)(1)', 250, NULL);


-- ============================================================================
-- REFERENCE: ITA ESTABLISHMENT TYPE CATEGORIES
-- ============================================================================
-- Drives submission routing between federal OSHA and State Plan authorities.

CREATE TABLE IF NOT EXISTS ita_establishment_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_reference TEXT NOT NULL
);

INSERT OR IGNORE INTO ita_establishment_types (code, name, description, cfr_reference) VALUES
    ('PRIVATE',   'Private Industry', 'Non-governmental employer. Default federal OSHA jurisdiction unless superseded by an approved State Plan.',                                                              'OSH Act of 1970, Section 3(5); 29 CFR 1975'),
    ('STATE_GOV', 'State Government', 'State-level government employer. Covered ONLY in states with OSHA-approved State Plans — federal OSHA has no jurisdiction over state government employees.',           'OSH Act Section 3(5); 29 CFR 1956'),
    ('LOCAL_GOV', 'Local Government', 'County, city, or other political-subdivision government employer. Same State Plan coverage logic as state government — federal OSHA has no jurisdiction.',            'OSH Act Section 3(5); 29 CFR 1956');


-- ============================================================================
-- REFERENCE: ITA TREATMENT FACILITY TYPES
-- ============================================================================
-- Per OSHA Form 301 Item 15 and ITA detail CSV treatment_facility_type column.

CREATE TABLE IF NOT EXISTS ita_treatment_facility_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL
);

INSERT OR IGNORE INTO ita_treatment_facility_types (code, name, description) VALUES
    ('HOSPITAL_ER',  'Hospital Emergency Room',       'Emergency department of a hospital; acute unscheduled care.'),
    ('HOSPITAL_OP',  'Hospital Outpatient Clinic',    'Scheduled non-emergency care at a hospital-affiliated outpatient clinic.'),
    ('PHYSICIAN',    'Physician''s Office',           'Private physician''s office, non-hospital-affiliated, not specialized for occupational medicine.'),
    ('URGENT_CARE',  'Urgent Care Center',            'Walk-in urgent-care facility providing non-emergency acute care without appointment.'),
    ('OCC_HEALTH',   'Occupational Health Clinic',    'Clinic specializing in work-related injury and illness, typically under employer contract.'),
    ('OTHER',        'Other Facility',                'A medical facility not matching any other category (e.g. on-site first-aid room with a nurse, ambulance-only treatment).'),
    ('UNKNOWN',      'Unknown',                       'Treatment facility not known at time of 301 completion. Acceptable only for backfilled historical records.');


-- ============================================================================
-- REFERENCE: ITA INCIDENT OUTCOMES (29 CFR 1904.7(b)(2)-(5))
-- ============================================================================
-- Four recordable-case outcomes as emitted on the ITA detail CSV.
-- Not in the original Phase 4a.2 plan as a lookup table, but added here to
-- give ita_outcome_mapping a proper FK target rather than a bare TEXT column.

CREATE TABLE IF NOT EXISTS ita_incident_outcomes (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_reference TEXT NOT NULL,
    ita_csv_column TEXT                         -- Which ITA detail CSV column (G/H/I/J)
);

INSERT OR IGNORE INTO ita_incident_outcomes (code, name, description, cfr_reference, ita_csv_column) VALUES
    ('DEATH',                    'Death',                        'Work-related fatality. Also triggers 8-hour notification under 29 CFR 1904.39.',                                                                    '29 CFR 1904.7(b)(2)',                  'G'),
    ('DAYS_AWAY',                'Days Away From Work',          'Case involves one or more calendar days away from work beyond the day of the event. 180-day cap per 1904.7(b)(3)(v).',                            '29 CFR 1904.7(b)(3)',                  'H'),
    ('JOB_TRANSFER_RESTRICTION', 'Job Transfer or Restriction',  'Restricted work or transfer to another job, no days away beyond event day. 180-day cap per 1904.7(b)(4)(iii).',                                 '29 CFR 1904.7(b)(4)',                  'I'),
    ('OTHER_RECORDABLE',         'Other Recordable',             'Recordable case not meeting death, days-away, or restriction thresholds — typically medical treatment beyond first aid only.',                   '29 CFR 1904.7(b)(5); 1904.7(b)(6)-(10)', 'J');


-- ============================================================================
-- REFERENCE: ITA INCIDENT TYPES
-- ============================================================================
-- Injury-or-illness classification for the ITA CSV incident_type column.
-- 1:1 with the existing case_classifications table via ita_case_type_mapping.
-- Like ita_incident_outcomes above, not in the original plan but added here
-- for FK integrity.

CREATE TABLE IF NOT EXISTS ita_incident_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    osha_300_column TEXT NOT NULL               -- Which 300 Log column (F, M1-M5)
);

INSERT OR IGNORE INTO ita_incident_types (code, name, description, osha_300_column) VALUES
    ('INJURY',                 'Injury',                  'Physical wound or damage to the body from a workplace event.',                                   'F'),
    ('SKIN_DISORDER',          'Skin Disorder',           'Occupational skin illness.',                                                                     'M1'),
    ('RESPIRATORY_CONDITION',  'Respiratory Condition',   'Occupational respiratory illness.',                                                              'M2'),
    ('POISONING',              'Poisoning',               'Systemic illness from absorbed toxic substances.',                                               'M3'),
    ('HEARING_LOSS',           'Hearing Loss',            'Standard Threshold Shift per 29 CFR 1904.10.',                                                   'M4'),
    ('OTHER_ILLNESS',          'All Other Illnesses',     'Occupational illness not matching skin, respiratory, poisoning, or hearing-loss categories.',   'M5');


-- ============================================================================
-- MAPPING: OSHA SEVERITY → ITA INCIDENT OUTCOME
-- ============================================================================
-- Declarative translation from Odin's internal severity taxonomy to the ITA
-- outcome vocabulary. Seeded from ehs-ontology-v3.3.ttl skos:exactMatch
-- triples between ehs:IncidentSeverity subclasses and ehs:ITAIncidentOutcome
-- subclasses.
--
-- Only the 4 OSHA-recordable severities have a mapping. The 4 non-recordable
-- severities (FIRST_AID, NEAR_MISS, PROPERTY, ENVIRONMENTAL) deliberately
-- have NO row here — their absence is the statement of the regulatory fact
-- that these cases do not flow to ITA export. Exporter must left-join to
-- filter out unmapped incidents.

CREATE TABLE IF NOT EXISTS ita_outcome_mapping (
    severity_code TEXT PRIMARY KEY,
    ita_outcome_code TEXT NOT NULL,
    cfr_reference TEXT NOT NULL,
    notes TEXT,
    FOREIGN KEY (severity_code) REFERENCES incident_severity_levels(code),
    FOREIGN KEY (ita_outcome_code) REFERENCES ita_incident_outcomes(code)
);

INSERT OR IGNORE INTO ita_outcome_mapping (severity_code, ita_outcome_code, cfr_reference, notes) VALUES
    ('FATALITY',   'DEATH',                    '29 CFR 1904.7(b)(2)', 'Also triggers 8-hour OSHA notification per 1904.39 — independent of ITA cycle.'),
    ('LOST_TIME',  'DAYS_AWAY',                '29 CFR 1904.7(b)(3)', 'Day-count cap of 180 days applies.'),
    ('RESTRICTED', 'JOB_TRANSFER_RESTRICTION', '29 CFR 1904.7(b)(4)', 'Day-count cap of 180 days shared with LOST_TIME across the life of one case.'),
    ('MEDICAL_TX', 'OTHER_RECORDABLE',         '29 CFR 1904.7(b)(5)', 'Medical treatment beyond first aid is the most common occupant of the OTHER_RECORDABLE bucket.');


-- ============================================================================
-- MAPPING: CASE CLASSIFICATION → ITA INCIDENT TYPE
-- ============================================================================
-- Clean 1:1 translation. Seeded from ehs-ontology-v3.3.ttl skos:exactMatch
-- triples between ehs:CaseClassification subclasses and ehs:ITAIncidentType
-- subclasses.

CREATE TABLE IF NOT EXISTS ita_case_type_mapping (
    case_classification_code TEXT PRIMARY KEY,
    ita_case_type_code TEXT NOT NULL,
    FOREIGN KEY (case_classification_code) REFERENCES case_classifications(code),
    FOREIGN KEY (ita_case_type_code) REFERENCES ita_incident_types(code)
);

INSERT OR IGNORE INTO ita_case_type_mapping (case_classification_code, ita_case_type_code) VALUES
    ('INJURY',     'INJURY'),
    ('SKIN',       'SKIN_DISORDER'),
    ('RESP',       'RESPIRATORY_CONDITION'),
    ('POISON',     'POISONING'),
    ('HEARING',    'HEARING_LOSS'),
    ('OTHER_ILL',  'OTHER_ILLNESS');


-- ============================================================================
-- MIGRATION-RUNNER TICKET (still deferred)
-- ============================================================================
-- For FRESH installs, the 4 + 6 new ITA columns now land directly via the
-- CREATE TABLE definitions above (establishments + incidents). No ALTER
-- TABLE statements appear in this file.
--
-- For EXISTING installed databases, a separate migration runner (tracked as
-- its own ticket) must issue the equivalent ALTER TABLE ADD COLUMN statements
-- with pragma_table_info idempotency guards. That ticket is outside this
-- file's scope.
--
-- Views below still emit only existing-column shape; they widen to the full
-- ITA detail / summary shape in a follow-up commit once the Go repository
-- and frontend plumbing lands.


-- ============================================================================
-- VIEW: v_osha_ita_detail
-- ============================================================================
-- Source for the ITA detail CSV export (one row per recordable incident,
-- combining old 300 Log and 301 Incident Report fields).
--
-- Exporter reads this view directly; business logic (severity → ITA outcome,
-- case classification → ITA type) is resolved here via the mapping tables,
-- not in Go. If OSHA reclassifies an ITA code, update the mapping table and
-- every downstream consumer picks up the change without a rebuild.
--
-- Filters to OSHA-recordable incidents only (inner-joined to
-- ita_outcome_mapping). Non-recordable severities are excluded by design —
-- their absence from the mapping table is the normative statement.
--
-- Note: this view references existing-column shape only. The 10 new columns
-- on establishments + incidents (deferred above) will be added in a follow-up
-- commit once the migration runner lands; the view body will be extended at
-- that point to emit the full 24-column ITA detail shape.

DROP VIEW IF EXISTS v_osha_ita_detail;
CREATE VIEW v_osha_ita_detail AS
SELECT
    -- 24 ITA CSV columns in spec order. Go exporter SELECTs these by
    -- name to guarantee CSV column order regardless of view layout.
    est.name                                  AS establishment_name,     -- 1
    strftime('%Y', i.incident_date)           AS year_of_filing,         -- 2
    i.case_number                             AS case_number,             -- 3
    emp.job_title                             AS job_title,               -- 4
    i.incident_date                           AS date_of_incident,        -- 5
    i.location_description                    AS incident_location,       -- 6
    i.incident_description                    AS incident_description,    -- 7
    iio.name                                  AS incident_outcome,        -- 8
    i.days_away_from_work                     AS dafw_num_away,           -- 9
    i.days_restricted_or_transferred          AS djtr_num_tr,             -- 10
    iit.name                                  AS type_of_incident,        -- 11
    emp.date_of_birth                         AS date_of_birth,           -- 12
    emp.date_hired                            AS date_of_hire,            -- 13
    emp.gender                                AS sex,                     -- 14
    tft.name                                  AS treatment_facility_type, -- 15
    CASE WHEN i.was_hospitalized = 1 THEN 'Y' ELSE 'N' END
                                              AS treatment_in_patient,    -- 16
    i.time_employee_began_work                AS time_started_work,       -- 17
    i.incident_time                           AS time_of_incident,        -- 18
    CASE WHEN i.time_unknown = 1 THEN 'Y' ELSE 'N' END
                                              AS time_unknown,            -- 19
    i.activity_description                    AS nar_before_incident,     -- 20
    i.incident_description                    AS nar_what_happened,       -- 21
    i.injury_illness_description              AS nar_injury_illness,      -- 22
    i.object_or_substance                     AS nar_object_substance,    -- 23
    i.date_of_death                           AS date_of_death,           -- 24

    -- Auxiliary filter columns (NOT emitted in CSV; used by Go
    -- exporter's WHERE clause). Keeping them inside the view lets the
    -- filter live next to the shape.
    i.establishment_id                        AS establishment_id,
    i.id                                      AS incident_id
FROM incidents i
-- INNER JOIN: only OSHA-recordable severities flow to ITA.
-- Non-recordable severities (FirstAid / NearMiss / PropertyDamage /
-- Environmental) have no row in ita_outcome_mapping and are filtered
-- out here by design. This matches the ontology's "absence-is-
-- normative" SKOS modeling from v3.3.
INNER JOIN ita_outcome_mapping iom
    ON iom.severity_code = i.severity_code
INNER JOIN ita_incident_outcomes iio
    ON iio.code = iom.ita_outcome_code
LEFT JOIN ita_case_type_mapping itm
    ON itm.case_classification_code = i.case_classification_code
LEFT JOIN ita_incident_types iit
    ON iit.code = itm.ita_case_type_code
INNER JOIN establishments est
    ON est.id = i.establishment_id
LEFT JOIN employees emp
    ON emp.id = i.employee_id
LEFT JOIN ita_treatment_facility_types tft
    ON tft.code = i.treatment_facility_type_code;


-- ============================================================================
-- VIEW: v_osha_ita_summary
-- ============================================================================
-- Source for the ITA summary CSV export (one row per establishment + year,
-- equivalent to the OSHA 300A annual summary).
--
-- Aggregates recordable incidents by outcome. no_injuries_illnesses fires
-- when the establishment had zero recordables in the reporting year — still
-- required to submit under 29 CFR 1904.41 if size/industry triggers apply.
--
-- As with v_osha_ita_detail, this view emits only columns that already exist
-- on the current schema. The 28-column ITA summary shape will be reached in
-- a follow-up patch once the establishment-level new columns (EIN, company
-- name, size_code, type_code) are alterable.

DROP VIEW IF EXISTS v_osha_ita_summary;
CREATE VIEW v_osha_ita_summary AS
SELECT
    est.id                                                                      AS establishment_id,
    est.name                                                                    AS establishment_name,
    est.street_address                                                          AS establishment_street,
    est.city                                                                    AS establishment_city,
    est.state                                                                    AS establishment_state,
    est.zip                                                                      AS establishment_zip,
    est.naics_code,
    est.annual_avg_employees,
    est.total_hours_worked,
    strftime('%Y', i.incident_date)                                             AS reporting_year,
    SUM(CASE WHEN iom.ita_outcome_code = 'DEATH'                    THEN 1 ELSE 0 END) AS total_deaths,
    SUM(CASE WHEN iom.ita_outcome_code = 'DAYS_AWAY'                THEN 1 ELSE 0 END) AS total_days_away_cases,
    SUM(CASE WHEN iom.ita_outcome_code = 'JOB_TRANSFER_RESTRICTION' THEN 1 ELSE 0 END) AS total_job_transfer_restriction_cases,
    SUM(CASE WHEN iom.ita_outcome_code = 'OTHER_RECORDABLE'         THEN 1 ELSE 0 END) AS total_other_recordable_cases,
    COUNT(*)                                                                    AS total_recordable_cases,
    CASE WHEN COUNT(*) = 0 THEN 'Y' ELSE 'N' END                                AS no_injuries_illnesses
FROM establishments est
LEFT JOIN incidents i
    ON i.establishment_id = est.id
LEFT JOIN ita_outcome_mapping iom
    ON iom.severity_code = i.severity_code
GROUP BY est.id, strftime('%Y', i.incident_date);


-- ============================================================================
-- END OF v3.3 ADDITIONS (Phase 4a.2)
-- ============================================================================
