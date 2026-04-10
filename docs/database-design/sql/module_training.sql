-- Module: Training (ehs:Education — one of the 5 E's of Safety)
-- Derived from ehs-ontology-v3.1.ttl — ehs:Education, ehs:TrainingStatus,
-- ehs:WorkerCharacteristic, ehs:HazardType subclasses
--
-- Design principle: requirements flow to employees through TRIGGERS — typed
-- rules that match employee characteristics (activities, job roles, work area
-- hazards) to regulatory training obligations. The ontology models this as:
--   ehs:TrainingStatus  a subclass of  ehs:WorkerCharacteristic
--   ehs:Education       a subclass of  ehs:SafetyProcess
--
-- This module is SELF-CONTAINED. It defines its own regulatory requirement
-- and trigger reference tables rather than depending on archived schemas.
-- Cross-module links to incidents/corrective_actions (Module C/D) are
-- optional FKs — the training module functions independently.
--
-- Shared tables (establishments, employees) are defined in module_c_osha300.sql
-- and are NOT recreated here.


-- ============================================================================
-- REFERENCE: TRAINING REGULATORY REQUIREMENTS
-- ============================================================================
-- Each row is a training obligation imposed by a specific regulation.
-- Encodes expert knowledge: CFR citations, agency, frequency, initial
-- completion window. Same pattern as recording_criteria in Module C.
--
-- These replace the dependency on the archived 002a_sara313.sql
-- regulatory_requirements table.

CREATE TABLE IF NOT EXISTS training_regulatory_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,                  -- Short code (e.g., 'HAZCOM')
    name TEXT NOT NULL,                         -- Human-readable name
    cfr_reference TEXT NOT NULL,                -- Specific CFR/NFPA section
    agency TEXT NOT NULL,                       -- OSHA, EPA, DOT, NFPA
    description TEXT NOT NULL,                  -- What the requirement actually demands
    frequency TEXT NOT NULL DEFAULT 'initial',  -- initial, annual, triennial, as_needed
    due_within_days INTEGER DEFAULT 90,         -- Days from trigger to complete initial training
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO training_regulatory_requirements (code, name, cfr_reference, agency, description, frequency, due_within_days) VALUES
    ('HAZCOM',           'Hazard Communication',
        '29 CFR 1910.1200(h)',       'OSHA',
        'Training on chemical hazards, SDS access, labeling, and protective measures. Required at initial assignment and when new hazards are introduced.',
        'initial', 30),
    ('BBP',              'Bloodborne Pathogens',
        '29 CFR 1910.1030(g)(2)',    'OSHA',
        'Annual training on bloodborne pathogen exposure risks, universal precautions, and post-exposure procedures.',
        'annual', 30),
    ('LOTO_AUTH',        'Lockout/Tagout — Authorized Employees',
        '29 CFR 1910.147(c)(7)(i)',  'OSHA',
        'Training on recognition of applicable hazardous energy sources, type and magnitude of energy, and methods/means for isolation and control.',
        'initial', 30),
    ('LOTO_AFF',         'Lockout/Tagout — Affected Employees',
        '29 CFR 1910.147(c)(7)(i)',  'OSHA',
        'Training on the purpose and use of energy control procedures. Affected employees must understand they shall not attempt to restart or reenergize equipment.',
        'initial', 30),
    ('RESP_PROT',        'Respiratory Protection',
        '29 CFR 1910.134(k)',        'OSHA',
        'Training on proper use, limitations, maintenance, and fit of respirators. Annual retraining and fit testing required.',
        'annual', 30),
    ('HEARING_CONS',     'Hearing Conservation',
        '29 CFR 1910.95(k)',         'OSHA',
        'Annual training for employees exposed at or above 85 dBA TWA. Covers effects of noise, purpose and use of hearing protectors, audiometric testing.',
        'annual', 30),
    ('CONFINED_ENTRY',   'Confined Space Entry',
        '29 CFR 1910.146(g)',        'OSHA',
        'Training for permit-required confined space entrants. Duties, hazard recognition, equipment use, emergency procedures.',
        'initial', 30),
    ('CONFINED_RESCUE',  'Confined Space Rescue',
        '29 CFR 1910.146(k)',        'OSHA',
        'Rescue team training including CPR/first aid, simulated rescue exercises. Practice rescue at least annually.',
        'annual', 30),
    ('FALL_PROT',        'Fall Protection',
        '29 CFR 1926.503',           'OSHA',
        'Training on fall hazards, fall protection systems (guardrails, safety nets, PFAS), proper use and inspection of equipment.',
        'initial', 30),
    ('FORKLIFT_OP',      'Powered Industrial Truck Operation',
        '29 CFR 1910.178(l)',        'OSHA',
        'Operator training including formal instruction, practical training, and workplace evaluation. Refresher every 3 years or after incident/near-miss/deficiency.',
        'triennial', 30),
    ('HOT_WORK',         'Hot Work Operations',
        '29 CFR 1910.252(a)',        'OSHA',
        'Training on fire prevention for welding, cutting, brazing. Permit procedures, fire watch duties, area preparation.',
        'initial', 30),
    ('FIRE_EXTINGUISHER', 'Fire Extinguisher Use',
        '29 CFR 1910.157(g)',        'OSHA',
        'Training on general principles of fire extinguisher use and hazards of incipient stage fire fighting. Required at initial assignment and annually.',
        'annual', 30),
    ('EMERG_ACTION',     'Emergency Action Plan',
        '29 CFR 1910.38(e)',         'OSHA',
        'Training on emergency procedures, evacuation routes, alarm systems. Initial assignment and whenever plan changes.',
        'initial', 30),
    ('HAZWOPER',         'HAZWOPER',
        '29 CFR 1910.120(e)',        'OSHA',
        'Hazardous waste operations and emergency response. 40-hour initial (site workers), 24-hour (occasional), 8-hour annual refresher.',
        'annual', 90),
    ('DOT_GENERAL',      'DOT HazMat — General Awareness',
        '49 CFR 172.704(a)(1)',      'DOT',
        'General awareness of hazardous materials requirements, hazard communication, and the HMR structure.',
        'triennial', 90),
    ('DOT_FUNCTION',     'DOT HazMat — Function-Specific',
        '49 CFR 172.704(a)(2)',      'DOT',
        'Training on HMR requirements specific to each function the employee performs (shipping, receiving, packaging, etc.).',
        'triennial', 90),
    ('DOT_SECURITY',     'DOT HazMat — Security Awareness',
        '49 CFR 172.704(a)(4)',      'DOT',
        'Security awareness training to recognize and respond to possible security threats related to hazmat transportation.',
        'triennial', 90),
    ('ELEC_SAFETY',      'Electrical Safety / NFPA 70E',
        '29 CFR 1910.332 / NFPA 70E', 'OSHA',
        'Training for qualified and unqualified persons working on or near exposed energized parts. Arc flash awareness, PPE selection, approach boundaries.',
        'initial', 30),
    ('CRANE_HOIST',      'Crane and Hoist Operation',
        '29 CFR 1910.179(b)(8) / 1926.1427', 'OSHA',
        'Operator training on crane/hoist operation, load limits, inspections, signals. Certification required for construction cranes.',
        'initial', 30),
    ('AERIAL_LIFT',      'Aerial Lift Operation',
        '29 CFR 1910.67(c) / 1926.453', 'OSHA',
        'Training on safe operation of aerial lifts, scissor lifts, and boom lifts. Pre-use inspection, fall protection, load capacity.',
        'initial', 30);


-- ============================================================================
-- REFERENCE: HAZARD TYPE CODES (from ontology ehs:HazardType subclasses)
-- ============================================================================
-- The ontology defines 7 top-level HazardType subclasses. These replace the
-- 22+ boolean flag columns on the old work_areas table with a normalized
-- junction design. Each hazard type can carry a specificity note at the
-- junction level (e.g., chemical → "flammable liquids, corrosives").

CREATE TABLE IF NOT EXISTS hazard_type_codes (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    ontology_class TEXT NOT NULL,               -- Corresponding ehs:HazardType subclass IRI
    description TEXT NOT NULL
);

INSERT OR IGNORE INTO hazard_type_codes (code, name, ontology_class, description) VALUES
    ('PHYSICAL',     'Physical Hazard',      'ehs:PhysicalHazard',
        'Noise, vibration, radiation, temperature extremes, pressure. Includes fall hazards and confined spaces.'),
    ('MECHANICAL',   'Mechanical Hazard',    'ehs:MechanicalHazard',
        'Moving parts, pinch points, struck-by, caught-in/between. Machine guarding concerns.'),
    ('CHEMICAL',     'Chemical Hazard',      'ehs:ChemicalHazard',
        'Exposure to hazardous chemicals — inhalation, skin contact, ingestion. GHS-classified substances.'),
    ('BIOLOGICAL',   'Biological Hazard',    'ehs:BiologicalHazard',
        'Bloodborne pathogens, mold, bacteria, viruses, animal-borne agents.'),
    ('PSYCHOSOCIAL', 'Psychosocial Hazard',  'ehs:PsychosocialHazard',
        'Workplace violence, stress, harassment, shift work, fatigue.'),
    ('ERGONOMIC',    'Ergonomic Hazard',     'ehs:ErgonomicHazard',
        'Repetitive motion, awkward postures, forceful exertions, manual material handling.'),
    ('ELECTRICAL',   'Electrical Hazard',    'ehs:ElectricalHazard',
        'Contact with energized conductors, arc flash/blast, static discharge.');


-- ============================================================================
-- REFERENCE: ACTIVITY CODES
-- ============================================================================
-- Defines the activity codes that trigger training requirements.
-- Maps to ontology ehs:WorkerCharacteristic → ehs:JobRole concepts.

CREATE TABLE IF NOT EXISTS activity_codes (
    code TEXT PRIMARY KEY,
    activity_name TEXT NOT NULL,
    description TEXT,
    typical_roles TEXT,                         -- Comma-separated job titles
    category TEXT                               -- operations, maintenance, safety, logistics
);

INSERT OR IGNORE INTO activity_codes (code, activity_name, description, typical_roles, category) VALUES
    ('FORKLIFT_OP',     'Forklift Operation',
        'Operates powered industrial trucks (forklifts, pallet jacks, etc.)',
        'Forklift Operator, Warehouse, Material Handler', 'logistics'),
    ('LOTO_AUTH',       'Lockout/Tagout Authorized',
        'Authorized to perform lockout/tagout on equipment',
        'Maintenance, Mechanic, Electrician, Technician', 'maintenance'),
    ('LOTO_AFF',        'Lockout/Tagout Affected',
        'Works in areas where LOTO is performed but does not perform it',
        'Operator, Production', 'operations'),
    ('HAZMAT_HANDLER',  'HazMat Handler',
        'Handles hazardous materials for shipping/receiving per DOT',
        'Shipping, Receiving, Logistics', 'logistics'),
    ('FIRST_AID',       'First Aid Responder',
        'Designated to provide first aid response',
        'Safety, Supervisor, Lead', 'safety'),
    ('CONFINED_ENTRY',  'Confined Space Entry',
        'Authorized for confined space entry',
        'Maintenance, Operator', 'maintenance'),
    ('CONFINED_RESCUE', 'Confined Space Rescue',
        'Trained for confined space rescue operations',
        'Safety, Rescue Team', 'safety'),
    ('HOT_WORK',        'Hot Work Operations',
        'Performs welding, cutting, brazing, or other hot work',
        'Welder, Maintenance, Fabricator', 'maintenance'),
    ('CRANE_OP',        'Crane/Hoist Operation',
        'Operates overhead cranes or hoists',
        'Crane Operator, Rigger, Maintenance', 'operations'),
    ('AERIAL_LIFT',     'Aerial Lift Operation',
        'Operates aerial lifts, scissor lifts, boom lifts',
        'Maintenance, Facilities', 'maintenance'),
    ('ELECTRICAL_QUAL', 'Qualified Electrical Worker',
        'Works on or near exposed energized electrical equipment',
        'Electrician, Electrical Technician', 'maintenance'),
    ('RESPIRATOR_USER', 'Respirator User',
        'Required to wear respiratory protection',
        'Painter, Plater, Chemical Handler', 'operations'),
    ('FALL_PROTECT',    'Fall Protection Required',
        'Works at heights requiring fall protection',
        'Maintenance, Roofer, Construction', 'maintenance'),
    ('SPILL_RESPONSE',  'Spill Response Team',
        'Member of chemical spill response team',
        'Safety, Environmental, Operations Lead', 'safety'),
    ('HAZWOPER_OP',     'HAZWOPER Operations Level',
        'Hazardous waste operations — operations level',
        'Environmental, Waste Handler', 'safety'),
    ('FIRE_BRIGADE',    'Fire Brigade Member',
        'Member of facility fire brigade',
        'Safety, Maintenance', 'safety');


-- ============================================================================
-- REFERENCE: TRAINING REQUIREMENT TRIGGERS
-- ============================================================================
-- Defines HOW regulatory requirements flow to employees. Each trigger is a
-- typed rule: when an employee matches the condition, the linked requirement
-- applies. Three trigger types:
--
--   all_employees  — applies to every active employee at the establishment
--   activity       — matches employee_activities.activity_code
--   hazard_type    — matches work_area_hazards.hazard_type_code
--
-- A single requirement can have multiple triggers (e.g., HAZCOM fires for
-- both 'all_employees' and specific chemical hazard types).

CREATE TABLE IF NOT EXISTS training_requirement_triggers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    requirement_id INTEGER NOT NULL,            -- FK → training_regulatory_requirements
    trigger_type TEXT NOT NULL,                 -- all_employees, activity, hazard_type
    activity_code TEXT,                         -- Matches activity_codes.code (when trigger_type = 'activity')
    hazard_type_code TEXT,                      -- Matches hazard_type_codes.code (when trigger_type = 'hazard_type')
    job_role TEXT,                              -- Pattern for job_title LIKE matching (optional secondary match)
    notes TEXT,                                 -- Why this trigger exists

    FOREIGN KEY (requirement_id) REFERENCES training_regulatory_requirements(id),
    FOREIGN KEY (activity_code) REFERENCES activity_codes(code),
    FOREIGN KEY (hazard_type_code) REFERENCES hazard_type_codes(code),

    -- Enforce that the correct field is populated for each trigger_type
    CHECK (
        (trigger_type = 'all_employees' AND activity_code IS NULL AND hazard_type_code IS NULL) OR
        (trigger_type = 'activity' AND activity_code IS NOT NULL) OR
        (trigger_type = 'hazard_type' AND hazard_type_code IS NOT NULL)
    )
);

CREATE INDEX idx_training_req_triggers_requirement ON training_requirement_triggers(requirement_id);
CREATE INDEX idx_training_req_triggers_type ON training_requirement_triggers(trigger_type);
CREATE INDEX idx_training_req_triggers_activity ON training_requirement_triggers(activity_code);
CREATE INDEX idx_training_req_triggers_hazard ON training_requirement_triggers(hazard_type_code);

-- Seed trigger rules: link requirements to the conditions that activate them.
-- IDs reference the training_regulatory_requirements rows seeded above.
-- We use subqueries to resolve codes → IDs for portability.

INSERT OR IGNORE INTO training_requirement_triggers (requirement_id, trigger_type, activity_code, hazard_type_code, notes) VALUES
    -- HAZCOM: all employees + chemical hazard areas
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'HAZCOM'),
        'all_employees', NULL, NULL, 'All employees must understand SDS access and labeling'),
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'HAZCOM'),
        'hazard_type', NULL, 'CHEMICAL', 'Enhanced HazCom for chemical hazard work areas'),

    -- BBP: biological hazard areas
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'BBP'),
        'hazard_type', NULL, 'BIOLOGICAL', 'Occupational exposure to blood/OPIM'),

    -- LOTO: activity-based
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'LOTO_AUTH'),
        'activity', 'LOTO_AUTH', NULL, 'Authorized to perform energy isolation'),
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'LOTO_AFF'),
        'activity', 'LOTO_AFF', NULL, 'Works in areas where LOTO is performed'),

    -- Respiratory Protection: activity-based
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'RESP_PROT'),
        'activity', 'RESPIRATOR_USER', NULL, 'Required respirator use per exposure assessment'),

    -- Hearing Conservation: physical hazard (noise)
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'HEARING_CONS'),
        'hazard_type', NULL, 'PHYSICAL', 'Work areas with noise exposure >= 85 dBA TWA'),

    -- Confined Space: activity-based
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'CONFINED_ENTRY'),
        'activity', 'CONFINED_ENTRY', NULL, 'Permit-required confined space entrants'),
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'CONFINED_RESCUE'),
        'activity', 'CONFINED_RESCUE', NULL, 'Confined space rescue team members'),

    -- Fall Protection: activity-based
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'FALL_PROT'),
        'activity', 'FALL_PROTECT', NULL, 'Works at heights requiring fall protection'),

    -- Forklift: activity-based
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'FORKLIFT_OP'),
        'activity', 'FORKLIFT_OP', NULL, 'Powered industrial truck operators'),

    -- Hot Work: activity-based
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'HOT_WORK'),
        'activity', 'HOT_WORK', NULL, 'Welding, cutting, brazing operations'),

    -- Fire Extinguisher: all employees (if employer provides extinguishers)
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'FIRE_EXTINGUISHER'),
        'all_employees', NULL, NULL, 'All employees where portable extinguishers are provided'),

    -- Emergency Action Plan: all employees
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'EMERG_ACTION'),
        'all_employees', NULL, NULL, 'All employees must know evacuation procedures'),

    -- HAZWOPER: activity-based
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'HAZWOPER'),
        'activity', 'HAZWOPER_OP', NULL, 'Hazardous waste operations personnel'),

    -- DOT HazMat: activity-based (hazmat handlers)
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'DOT_GENERAL'),
        'activity', 'HAZMAT_HANDLER', NULL, 'HazMat employees per 49 CFR 171.8'),
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'DOT_FUNCTION'),
        'activity', 'HAZMAT_HANDLER', NULL, 'Function-specific training for HazMat employees'),
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'DOT_SECURITY'),
        'activity', 'HAZMAT_HANDLER', NULL, 'Security awareness for HazMat employees'),

    -- Electrical Safety: activity-based + electrical hazard areas
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'ELEC_SAFETY'),
        'activity', 'ELECTRICAL_QUAL', NULL, 'Qualified electrical workers'),
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'ELEC_SAFETY'),
        'hazard_type', NULL, 'ELECTRICAL', 'Unqualified persons in electrical hazard areas'),

    -- Crane/Hoist: activity-based
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'CRANE_HOIST'),
        'activity', 'CRANE_OP', NULL, 'Crane and hoist operators'),

    -- Aerial Lift: activity-based
    ((SELECT id FROM training_regulatory_requirements WHERE code = 'AERIAL_LIFT'),
        'activity', 'AERIAL_LIFT', NULL, 'Aerial lift operators');


-- ============================================================================
-- TRAINING COURSES
-- ============================================================================
-- The actual training courses/curricula offered.
-- A course can satisfy one or more regulatory requirements (many-to-many
-- through course_requirements junction).

CREATE TABLE IF NOT EXISTS training_courses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Course identification
    course_code TEXT,                           -- Internal code (e.g., 'SAF-101')
    course_name TEXT NOT NULL,
    description TEXT,

    -- Delivery details
    duration_minutes INTEGER,                  -- Expected duration
    delivery_method TEXT,                       -- classroom, online, ojt, blended, self_study

    -- Testing/Scoring
    has_test INTEGER DEFAULT 0,                -- Does this course have a test?
    passing_score REAL,                        -- Minimum score to pass (NULL if no test)
    max_score REAL DEFAULT 100,

    -- Validity period
    validity_months INTEGER,                   -- Months until retraining required (NULL = never expires)

    -- External/Vendor courses
    is_external INTEGER DEFAULT 0,             -- Provided by external vendor?
    vendor_name TEXT,
    vendor_course_id TEXT,

    -- Course materials (file paths or URLs)
    materials_path TEXT,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_training_courses_establishment ON training_courses(establishment_id);
CREATE INDEX idx_training_courses_code ON training_courses(course_code);
CREATE INDEX idx_training_courses_active ON training_courses(is_active) WHERE is_active = 1;


-- ============================================================================
-- COURSE REQUIREMENTS JUNCTION (Many-to-Many)
-- ============================================================================
-- Links courses to the regulatory requirements they satisfy.
-- One course can satisfy multiple requirements (e.g., "Annual Safety Refresher"
-- covers HazCom, PPE, and Fire Extinguisher). One requirement can be
-- satisfied by multiple courses (e.g., HazCom can be classroom or online).

CREATE TABLE IF NOT EXISTS course_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_id INTEGER NOT NULL,
    requirement_id INTEGER NOT NULL,            -- FK → training_regulatory_requirements

    -- A course might fully or partially satisfy a requirement
    satisfaction_type TEXT DEFAULT 'full',      -- full, partial, supplemental
    notes TEXT,                                -- Explanation if partial

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (course_id) REFERENCES training_courses(id) ON DELETE CASCADE,
    FOREIGN KEY (requirement_id) REFERENCES training_regulatory_requirements(id),
    UNIQUE(course_id, requirement_id)
);

CREATE INDEX idx_course_requirements_course ON course_requirements(course_id);
CREATE INDEX idx_course_requirements_requirement ON course_requirements(requirement_id);


-- ============================================================================
-- TRAINING COMPLETIONS
-- ============================================================================
-- Records of completed training. This is the core compliance record.
-- Each row = one employee completing one course on one date.
-- Maps to ontology ehs:TrainingStatus values (current, expired, etc.)

CREATE TABLE IF NOT EXISTS training_completions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,

    -- When
    completion_date TEXT NOT NULL,              -- Date training was completed
    expiration_date TEXT,                       -- When retraining is due (auto-calculated by trigger)

    -- Results
    score REAL,                                -- Test score (NULL if no test)
    passed INTEGER DEFAULT 1,                  -- 1 if passed, 0 if failed

    -- Delivery details for this instance
    instructor TEXT,                           -- Who delivered the training
    delivery_method TEXT,                      -- How it was delivered (may differ from course default)
    location TEXT,                             -- Where (classroom, online platform, etc.)

    -- Documentation
    certificate_number TEXT,                   -- External certificate ID if applicable
    documentation_path TEXT,                   -- Path to signed roster, certificate, etc.

    -- Verification (auditors may ask)
    verified_by TEXT,
    verified_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (course_id) REFERENCES training_courses(id)
);

CREATE INDEX idx_training_completions_employee ON training_completions(employee_id);
CREATE INDEX idx_training_completions_course ON training_completions(course_id);
CREATE INDEX idx_training_completions_date ON training_completions(completion_date);
CREATE INDEX idx_training_completions_expiration ON training_completions(expiration_date);
CREATE INDEX idx_training_completions_emp_course ON training_completions(employee_id, course_id);


-- ============================================================================
-- TRAINING ASSIGNMENTS (Direct Assignment)
-- ============================================================================
-- Manual assignment of training to specific employees.
-- Used for: new hires, role changes, remedial training, incident follow-up.
-- Complements the automatic requirement determination from triggers.
--
-- Cross-module wiring: corrective_action_id and incident_id link back to
-- Module C/D when training is assigned as a corrective action or in direct
-- response to an incident.

CREATE TABLE IF NOT EXISTS training_assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,

    -- Assignment details
    assigned_date TEXT DEFAULT (datetime('now')),
    due_date TEXT,                              -- When must this be completed?

    assigned_by TEXT,                           -- Who assigned this
    reason TEXT,                                -- Why (new hire, role change, incident follow-up, etc.)
    priority TEXT DEFAULT 'normal',             -- urgent, high, normal, low

    -- Status tracking
    status TEXT DEFAULT 'assigned',             -- assigned, in_progress, completed, overdue, waived, cancelled

    -- Completion link (once completed)
    completion_id INTEGER,                     -- Links to training_completions when done

    -- Cross-module links (Module C/D)
    corrective_action_id INTEGER,              -- FK → corrective_actions. When an investigation
                                               -- generates a CA that includes training.
    incident_id INTEGER,                       -- FK → incidents. Direct link for incident-triggered training.

    -- Waiver info (if waived instead of completed)
    waived_by TEXT,
    waived_date TEXT,
    waiver_reason TEXT,
    waiver_expiration TEXT,                    -- Some waivers are temporary

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (course_id) REFERENCES training_courses(id),
    FOREIGN KEY (completion_id) REFERENCES training_completions(id),
    FOREIGN KEY (corrective_action_id) REFERENCES corrective_actions(id),
    FOREIGN KEY (incident_id) REFERENCES incidents(id)
);

CREATE INDEX idx_training_assignments_employee ON training_assignments(employee_id);
CREATE INDEX idx_training_assignments_course ON training_assignments(course_id);
CREATE INDEX idx_training_assignments_status ON training_assignments(status);
CREATE INDEX idx_training_assignments_due ON training_assignments(due_date);
CREATE INDEX idx_training_assignments_corrective_action ON training_assignments(corrective_action_id);
CREATE INDEX idx_training_assignments_incident ON training_assignments(incident_id);


-- ============================================================================
-- EMPLOYEE ACTIVITIES
-- ============================================================================
-- Tracks which activities employees perform that trigger training requirements.
-- Links to training_requirement_triggers where trigger_type = 'activity'.
-- Maps to ontology ehs:WorkerCharacteristic → ehs:JobRole.

CREATE TABLE IF NOT EXISTS employee_activities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    activity_code TEXT NOT NULL,                -- FK → activity_codes

    -- When this activity applies
    start_date TEXT NOT NULL,
    end_date TEXT,                              -- NULL if still active

    -- Context
    notes TEXT,
    authorized_by TEXT,                        -- Who authorized this activity assignment
    authorization_date TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (activity_code) REFERENCES activity_codes(code),
    UNIQUE(employee_id, activity_code, start_date)
);

CREATE INDEX idx_employee_activities_employee ON employee_activities(employee_id);
CREATE INDEX idx_employee_activities_code ON employee_activities(activity_code);
CREATE INDEX idx_employee_activities_active ON employee_activities(end_date) WHERE end_date IS NULL;


-- ============================================================================
-- WORK AREAS (Hazard Profiles)
-- ============================================================================
-- Defines work areas/departments within an establishment.
-- Hazard flags are now rows in work_area_hazards (junction table) rather than
-- 22+ boolean columns. This table retains identification, hierarchy, and
-- assessment tracking fields.

CREATE TABLE IF NOT EXISTS work_areas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Identification
    area_name TEXT NOT NULL,                    -- e.g., "Plating Department", "Paint Line 1"
    area_code TEXT,                             -- Short code
    area_type TEXT,                             -- department, building, room, line, cell

    -- Hierarchy (optional — for organizing areas)
    parent_area_id INTEGER,                    -- For nested areas

    -- Location reference
    building TEXT,
    floor_level TEXT,

    -- Assessment tracking
    last_assessment_date TEXT,
    next_assessment_date TEXT,
    assessed_by TEXT,

    description TEXT,
    is_active INTEGER DEFAULT 1,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (parent_area_id) REFERENCES work_areas(id),
    UNIQUE(establishment_id, area_name)
);

CREATE INDEX idx_work_areas_establishment ON work_areas(establishment_id);
CREATE INDEX idx_work_areas_parent ON work_areas(parent_area_id);


-- ============================================================================
-- WORK AREA HAZARDS (Junction: work_areas ↔ hazard_type_codes)
-- ============================================================================
-- Replaces the 22+ boolean flag columns on the old work_areas table.
-- Each row links a work area to one of the 7 ontology hazard types.
-- The specificity field captures detail (e.g., chemical → "flammable liquids,
-- corrosives") without requiring additional columns for every GHS class.

CREATE TABLE IF NOT EXISTS work_area_hazards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    work_area_id INTEGER NOT NULL,
    hazard_type_code TEXT NOT NULL,             -- FK → hazard_type_codes

    -- Optional specificity within the hazard type
    specificity TEXT,                           -- e.g., "flammable liquids, corrosives" for CHEMICAL
                                               --       "noise > 85 dBA, confined spaces" for PHYSICAL
                                               --       "overhead crane, conveyor" for MECHANICAL

    -- Assessment linkage
    identified_date TEXT DEFAULT (date('now')),
    identified_by TEXT,
    notes TEXT,

    FOREIGN KEY (work_area_id) REFERENCES work_areas(id) ON DELETE CASCADE,
    FOREIGN KEY (hazard_type_code) REFERENCES hazard_type_codes(code),
    UNIQUE(work_area_id, hazard_type_code)
);

CREATE INDEX idx_work_area_hazards_area ON work_area_hazards(work_area_id);
CREATE INDEX idx_work_area_hazards_type ON work_area_hazards(hazard_type_code);


-- ============================================================================
-- EMPLOYEE WORK AREA ASSIGNMENTS
-- ============================================================================
-- Links employees to the work areas where they work.
-- An employee can work in multiple areas (cross-trained, floater, etc.)

CREATE TABLE IF NOT EXISTS employee_work_areas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    work_area_id INTEGER NOT NULL,

    is_primary INTEGER DEFAULT 0,              -- Primary work area (for reporting)

    -- When assigned
    start_date TEXT DEFAULT (date('now')),
    end_date TEXT,                              -- NULL if currently assigned

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (work_area_id) REFERENCES work_areas(id),
    UNIQUE(employee_id, work_area_id, start_date)
);

CREATE INDEX idx_employee_work_areas_employee ON employee_work_areas(employee_id);
CREATE INDEX idx_employee_work_areas_area ON employee_work_areas(work_area_id);
CREATE INDEX idx_employee_work_areas_active ON employee_work_areas(end_date) WHERE end_date IS NULL;


-- ============================================================================
-- VIEWS: Training Requirements Determination
-- ============================================================================
-- These views calculate what training each employee needs based on:
--   1. All-employee requirements (emergency procedures, etc.)
--   2. Activity/role-based requirements (forklift, LOTO, etc.)
--   3. Job role pattern matching (job_title LIKE trigger.job_role)
--   4. Work area hazard exposure (from work_area_hazards junction)
--   5. Direct assignments


-- ----------------------------------------------------------------------------
-- V_EMPLOYEE_REQUIRED_REQUIREMENTS
-- ----------------------------------------------------------------------------
-- Lists all regulatory requirements that apply to each active employee.
-- This is the foundation — determines WHAT is required before mapping to courses.
-- Four-path UNION: all_employees, activity, job_role, work_area_hazard.

CREATE VIEW IF NOT EXISTS v_employee_required_requirements AS

-- 1. All-employee requirements
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.establishment_id,
    rr.id AS requirement_id,
    rr.code AS requirement_code,
    rr.name AS requirement_name,
    rr.frequency,
    rr.due_within_days,
    rr.agency,
    rr.cfr_reference,
    'all_employees' AS trigger_source,
    'Applies to all employees' AS trigger_reason
FROM employees e
CROSS JOIN training_regulatory_requirements rr
INNER JOIN training_requirement_triggers trt ON rr.id = trt.requirement_id
WHERE e.is_active = 1
  AND rr.is_active = 1
  AND trt.trigger_type = 'all_employees'

UNION

-- 2. Activity-based requirements (from employee_activities)
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.establishment_id,
    rr.id AS requirement_id,
    rr.code AS requirement_code,
    rr.name AS requirement_name,
    rr.frequency,
    rr.due_within_days,
    rr.agency,
    rr.cfr_reference,
    'activity' AS trigger_source,
    'Activity: ' || ea.activity_code AS trigger_reason
FROM employees e
INNER JOIN employee_activities ea ON e.id = ea.employee_id AND ea.end_date IS NULL
INNER JOIN training_requirement_triggers trt ON trt.activity_code = ea.activity_code
INNER JOIN training_regulatory_requirements rr ON trt.requirement_id = rr.id
WHERE e.is_active = 1
  AND rr.is_active = 1
  AND trt.trigger_type = 'activity'

UNION

-- 3. Job role-based requirements (from job_title pattern matching)
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.establishment_id,
    rr.id AS requirement_id,
    rr.code AS requirement_code,
    rr.name AS requirement_name,
    rr.frequency,
    rr.due_within_days,
    rr.agency,
    rr.cfr_reference,
    'job_role' AS trigger_source,
    'Job role: ' || e.job_title AS trigger_reason
FROM employees e
INNER JOIN training_requirement_triggers trt ON e.job_title LIKE '%' || trt.job_role || '%'
INNER JOIN training_regulatory_requirements rr ON trt.requirement_id = rr.id
WHERE e.is_active = 1
  AND rr.is_active = 1
  AND trt.trigger_type = 'activity'
  AND trt.job_role IS NOT NULL

UNION

-- 4. Work area hazard-based requirements
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.establishment_id,
    rr.id AS requirement_id,
    rr.code AS requirement_code,
    rr.name AS requirement_name,
    rr.frequency,
    rr.due_within_days,
    rr.agency,
    rr.cfr_reference,
    'work_area_hazard' AS trigger_source,
    'Work area: ' || wa.area_name || ' (' || wah.hazard_type_code || ')' AS trigger_reason
FROM employees e
INNER JOIN employee_work_areas ewa ON e.id = ewa.employee_id AND ewa.end_date IS NULL
INNER JOIN work_areas wa ON ewa.work_area_id = wa.id
INNER JOIN work_area_hazards wah ON wa.id = wah.work_area_id
INNER JOIN training_requirement_triggers trt
    ON trt.trigger_type = 'hazard_type'
   AND trt.hazard_type_code = wah.hazard_type_code
INNER JOIN training_regulatory_requirements rr ON trt.requirement_id = rr.id
WHERE e.is_active = 1
  AND rr.is_active = 1;


-- ----------------------------------------------------------------------------
-- V_EMPLOYEE_REQUIRED_COURSES
-- ----------------------------------------------------------------------------
-- Maps required requirements to the courses that satisfy them.
-- An employee needs a course if it satisfies any of their required requirements.

CREATE VIEW IF NOT EXISTS v_employee_required_courses AS
SELECT DISTINCT
    err.employee_id,
    err.employee_name,
    err.establishment_id,
    tc.id AS course_id,
    tc.course_code,
    tc.course_name,
    tc.validity_months,
    tc.has_test,
    tc.passing_score,
    err.requirement_id,
    err.requirement_code,
    err.requirement_name,
    err.frequency,
    err.due_within_days,
    err.agency,
    err.trigger_source,
    err.trigger_reason
FROM v_employee_required_requirements err
INNER JOIN course_requirements cr ON err.requirement_id = cr.requirement_id
INNER JOIN training_courses tc ON cr.course_id = tc.id
WHERE tc.is_active = 1;


-- ----------------------------------------------------------------------------
-- V_EMPLOYEE_CURRENT_TRAINING
-- ----------------------------------------------------------------------------
-- Most recent passing completion for each employee/course combination.
-- Includes expiration status derived from ontology ehs:TrainingStatus.

CREATE VIEW IF NOT EXISTS v_employee_current_training AS
SELECT
    tc.employee_id,
    tc.course_id,
    tc.id AS completion_id,
    tc.completion_date,
    tc.expiration_date,
    tc.score,
    tc.passed,
    tc.instructor,
    tc.certificate_number,
    CASE
        WHEN tc.expiration_date IS NULL THEN 'never_expires'
        WHEN date(tc.expiration_date) < date('now') THEN 'expired'
        WHEN date(tc.expiration_date) < date('now', '+30 days') THEN 'expiring_soon'
        WHEN date(tc.expiration_date) < date('now', '+90 days') THEN 'expiring_90_days'
        ELSE 'current'
    END AS status,
    CASE
        WHEN tc.expiration_date IS NOT NULL
        THEN CAST(julianday(tc.expiration_date) - julianday('now') AS INTEGER)
        ELSE NULL
    END AS days_until_expiration
FROM training_completions tc
WHERE tc.id = (
    SELECT tc2.id
    FROM training_completions tc2
    WHERE tc2.employee_id = tc.employee_id
      AND tc2.course_id = tc.course_id
      AND tc2.passed = 1
    ORDER BY tc2.completion_date DESC
    LIMIT 1
);


-- ----------------------------------------------------------------------------
-- V_EMPLOYEE_TRAINING_STATUS
-- ----------------------------------------------------------------------------
-- Comprehensive status of each required training for each employee.
-- Shows what's required, what's completed, and what's missing/expired.

CREATE VIEW IF NOT EXISTS v_employee_training_status AS
SELECT
    erc.employee_id,
    erc.employee_name,
    erc.establishment_id,
    erc.course_id,
    erc.course_code,
    erc.course_name,
    erc.requirement_id,
    erc.requirement_code,
    erc.requirement_name,
    erc.agency,
    erc.frequency,
    erc.trigger_source,
    erc.trigger_reason,
    ect.completion_id,
    ect.completion_date,
    ect.expiration_date,
    ect.score,
    ect.instructor,
    CASE
        WHEN ect.completion_id IS NULL THEN 'not_completed'
        WHEN ect.status = 'expired' THEN 'expired'
        WHEN ect.status = 'expiring_soon' THEN 'expiring_soon'
        ELSE 'current'
    END AS training_status,
    ect.days_until_expiration,
    -- Priority for sorting/UI
    CASE
        WHEN ect.completion_id IS NULL THEN 1      -- Never completed = highest priority
        WHEN ect.status = 'expired' THEN 2          -- Expired = high priority
        WHEN ect.status = 'expiring_soon' THEN 3    -- Expiring in 30 days
        WHEN ect.status = 'expiring_90_days' THEN 4 -- Expiring in 90 days
        ELSE 5                                       -- Current = lowest priority
    END AS priority_order
FROM v_employee_required_courses erc
LEFT JOIN v_employee_current_training ect
    ON erc.employee_id = ect.employee_id
   AND erc.course_id = ect.course_id;


-- ----------------------------------------------------------------------------
-- V_TRAINING_GAP_ANALYSIS
-- ----------------------------------------------------------------------------
-- Shows only missing or expired training — the action items.
-- This is what you'd use for compliance reports and scheduling.

CREATE VIEW IF NOT EXISTS v_training_gap_analysis AS
SELECT
    ets.employee_id,
    ets.employee_name,
    ets.establishment_id,
    ets.course_id,
    ets.course_code,
    ets.course_name,
    ets.requirement_code,
    ets.requirement_name,
    ets.agency,
    ets.training_status,
    ets.trigger_source,
    ets.trigger_reason,
    ets.completion_date AS last_completion_date,
    ets.expiration_date,
    ets.days_until_expiration,
    ets.priority_order,
    -- Action needed
    CASE
        WHEN ets.training_status = 'not_completed' THEN 'Initial training required'
        WHEN ets.training_status = 'expired' THEN 'Retraining required (expired)'
        WHEN ets.training_status = 'expiring_soon' THEN 'Retraining due within 30 days'
    END AS action_needed
FROM v_employee_training_status ets
WHERE ets.training_status IN ('not_completed', 'expired', 'expiring_soon')
ORDER BY ets.priority_order, ets.employee_name, ets.course_name;


-- ----------------------------------------------------------------------------
-- V_TRAINING_SUMMARY_BY_EMPLOYEE
-- ----------------------------------------------------------------------------
-- Summary counts for each employee — useful for dashboard/overview.

CREATE VIEW IF NOT EXISTS v_training_summary_by_employee AS
SELECT
    employee_id,
    employee_name,
    establishment_id,
    COUNT(DISTINCT course_id) AS total_required,
    SUM(CASE WHEN training_status = 'current' THEN 1 ELSE 0 END) AS completed_current,
    SUM(CASE WHEN training_status = 'not_completed' THEN 1 ELSE 0 END) AS not_completed,
    SUM(CASE WHEN training_status = 'expired' THEN 1 ELSE 0 END) AS expired,
    SUM(CASE WHEN training_status = 'expiring_soon' THEN 1 ELSE 0 END) AS expiring_soon,
    ROUND(
        100.0 * SUM(CASE WHEN training_status = 'current' THEN 1 ELSE 0 END) /
        COUNT(DISTINCT course_id),
        1
    ) AS compliance_percent
FROM v_employee_training_status
GROUP BY employee_id, employee_name, establishment_id
ORDER BY compliance_percent ASC, employee_name;


-- ----------------------------------------------------------------------------
-- V_TRAINING_SUMMARY_BY_COURSE
-- ----------------------------------------------------------------------------
-- Summary for each course — how many need it, have it, missing it.

CREATE VIEW IF NOT EXISTS v_training_summary_by_course AS
SELECT
    course_id,
    course_code,
    course_name,
    establishment_id,
    COUNT(DISTINCT employee_id) AS total_employees_need,
    SUM(CASE WHEN training_status = 'current' THEN 1 ELSE 0 END) AS completed_current,
    SUM(CASE WHEN training_status = 'not_completed' THEN 1 ELSE 0 END) AS not_completed,
    SUM(CASE WHEN training_status = 'expired' THEN 1 ELSE 0 END) AS expired,
    SUM(CASE WHEN training_status = 'expiring_soon' THEN 1 ELSE 0 END) AS expiring_soon,
    ROUND(
        100.0 * SUM(CASE WHEN training_status = 'current' THEN 1 ELSE 0 END) /
        COUNT(DISTINCT employee_id),
        1
    ) AS compliance_percent
FROM v_employee_training_status
GROUP BY course_id, course_code, course_name, establishment_id
ORDER BY compliance_percent ASC, course_name;


-- ----------------------------------------------------------------------------
-- V_TRAINING_COMPLIANCE_SUMMARY
-- ----------------------------------------------------------------------------
-- Overall compliance numbers for establishment.

CREATE VIEW IF NOT EXISTS v_training_compliance_summary AS
SELECT
    est.id AS establishment_id,
    est.name AS establishment_name,
    COUNT(DISTINCT ets.employee_id) AS total_employees,
    COUNT(*) AS total_training_requirements,
    SUM(CASE WHEN ets.training_status = 'current' THEN 1 ELSE 0 END) AS current_count,
    SUM(CASE WHEN ets.training_status = 'not_completed' THEN 1 ELSE 0 END) AS not_completed_count,
    SUM(CASE WHEN ets.training_status = 'expired' THEN 1 ELSE 0 END) AS expired_count,
    SUM(CASE WHEN ets.training_status = 'expiring_soon' THEN 1 ELSE 0 END) AS expiring_soon_count,
    ROUND(
        100.0 * SUM(CASE WHEN ets.training_status = 'current' THEN 1 ELSE 0 END) /
        COUNT(*),
        1
    ) AS overall_compliance_percent
FROM establishments est
LEFT JOIN v_employee_training_status ets ON est.id = ets.establishment_id
GROUP BY est.id, est.name;


-- ----------------------------------------------------------------------------
-- V_TRAINING_EXPIRING
-- ----------------------------------------------------------------------------
-- Training that will expire in the next 90 days — for scheduling retraining.

CREATE VIEW IF NOT EXISTS v_training_expiring AS
SELECT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.department,
    tc.id AS course_id,
    tc.course_code,
    tc.course_name,
    comp.completion_date,
    comp.expiration_date,
    CAST(julianday(comp.expiration_date) - julianday('now') AS INTEGER) AS days_until_expiration,
    CASE
        WHEN date(comp.expiration_date) < date('now') THEN 'EXPIRED'
        WHEN date(comp.expiration_date) < date('now', '+30 days') THEN 'URGENT'
        WHEN date(comp.expiration_date) < date('now', '+60 days') THEN 'SOON'
        ELSE 'UPCOMING'
    END AS urgency
FROM training_completions comp
INNER JOIN employees e ON comp.employee_id = e.id
INNER JOIN training_courses tc ON comp.course_id = tc.id
WHERE e.is_active = 1
  AND comp.passed = 1
  AND comp.expiration_date IS NOT NULL
  AND date(comp.expiration_date) < date('now', '+90 days')
  -- Only show most recent completion per employee/course
  AND comp.id = (
    SELECT c2.id FROM training_completions c2
    WHERE c2.employee_id = comp.employee_id
      AND c2.course_id = comp.course_id
      AND c2.passed = 1
    ORDER BY c2.completion_date DESC LIMIT 1
  )
ORDER BY comp.expiration_date ASC;


-- ----------------------------------------------------------------------------
-- V_PENDING_TRAINING_ASSIGNMENTS
-- ----------------------------------------------------------------------------
-- Direct training assignments that aren't completed yet.

CREATE VIEW IF NOT EXISTS v_pending_training_assignments AS
SELECT
    ta.id AS assignment_id,
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.department,
    tc.id AS course_id,
    tc.course_code,
    tc.course_name,
    ta.assigned_date,
    ta.due_date,
    ta.assigned_by,
    ta.reason,
    ta.priority,
    ta.status,
    ta.corrective_action_id,
    ta.incident_id,
    CASE
        WHEN ta.due_date IS NULL THEN NULL
        WHEN date(ta.due_date) < date('now') THEN 'OVERDUE'
        WHEN date(ta.due_date) < date('now', '+7 days') THEN 'DUE_THIS_WEEK'
        WHEN date(ta.due_date) < date('now', '+30 days') THEN 'DUE_THIS_MONTH'
        ELSE 'UPCOMING'
    END AS due_status,
    CAST(julianday(ta.due_date) - julianday('now') AS INTEGER) AS days_until_due
FROM training_assignments ta
INNER JOIN employees e ON ta.employee_id = e.id
INNER JOIN training_courses tc ON ta.course_id = tc.id
WHERE ta.status IN ('assigned', 'in_progress', 'overdue')
  AND e.is_active = 1
ORDER BY
    CASE ta.priority
        WHEN 'urgent' THEN 1
        WHEN 'high' THEN 2
        WHEN 'normal' THEN 3
        ELSE 4
    END,
    ta.due_date ASC;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-calculate expiration_date when inserting training completion
CREATE TRIGGER IF NOT EXISTS trg_training_completion_expiration
AFTER INSERT ON training_completions
WHEN NEW.expiration_date IS NULL
BEGIN
    UPDATE training_completions
    SET expiration_date = (
        SELECT CASE
            WHEN tc.validity_months IS NOT NULL
            THEN date(NEW.completion_date, '+' || tc.validity_months || ' months')
            ELSE NULL
        END
        FROM training_courses tc
        WHERE tc.id = NEW.course_id
    )
    WHERE id = NEW.id;
END;

-- Auto-update training_assignments status when completion is recorded
CREATE TRIGGER IF NOT EXISTS trg_training_completion_assignment
AFTER INSERT ON training_completions
WHEN NEW.passed = 1
BEGIN
    UPDATE training_assignments
    SET status = 'completed',
        completion_id = NEW.id,
        updated_at = datetime('now')
    WHERE employee_id = NEW.employee_id
      AND course_id = NEW.course_id
      AND status IN ('assigned', 'in_progress', 'overdue');
END;


-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
-- Additional indexes to optimize the complex views

CREATE INDEX IF NOT EXISTS idx_employees_active_establishment
    ON employees(establishment_id) WHERE is_active = 1;


-- ============================================================================
-- SAMPLE TRAINING COURSES (Seed Data)
-- ============================================================================
-- Pre-seeded courses for the first establishment (id = 1).
-- These map to the most common regulatory requirements above.
-- In production, seeds are applied programmatically after first-run setup;
-- these INSERTs serve as a reference and for development/testing.

INSERT OR IGNORE INTO training_courses (id, establishment_id, course_code, course_name, description, duration_minutes, delivery_method, has_test, passing_score, validity_months) VALUES
    (1,  1, 'SAF-100', 'New Employee Safety Orientation',
        'Covers emergency procedures, reporting, general safety rules. Satisfies EAP and general HazCom initial requirements.',
        120, 'classroom', 1, 80, NULL),
    (2,  1, 'SAF-101', 'Hazard Communication (HazCom)',
        'GHS labeling, SDS access/interpretation, chemical hazard awareness per 29 CFR 1910.1200(h).',
        60, 'classroom', 1, 80, 12),
    (3,  1, 'SAF-102', 'Bloodborne Pathogens',
        'Universal precautions, exposure control plan, post-exposure procedures per 29 CFR 1910.1030.',
        45, 'online', 1, 80, 12),
    (4,  1, 'SAF-103', 'Fire Extinguisher Use',
        'Portable fire extinguisher types, PASS technique, hands-on practice per 29 CFR 1910.157(g).',
        30, 'blended', 1, 70, 12),
    (5,  1, 'SAF-104', 'Emergency Action Plan',
        'Evacuation routes, assembly points, alarm systems, shelter-in-place per 29 CFR 1910.38.',
        30, 'classroom', 0, NULL, 12),
    (6,  1, 'SAF-105', 'Lockout/Tagout — Authorized',
        'Energy isolation procedures, lock/tag application, verification per 29 CFR 1910.147. For authorized employees.',
        90, 'blended', 1, 80, 12),
    (7,  1, 'SAF-106', 'Lockout/Tagout — Affected',
        'Recognition of energy control procedures, restrictions during LOTO per 29 CFR 1910.147. For affected employees.',
        30, 'classroom', 1, 80, 12),
    (8,  1, 'SAF-107', 'Respiratory Protection',
        'Respirator selection, fit testing, use, maintenance, and medical clearance per 29 CFR 1910.134.',
        60, 'blended', 1, 80, 12),
    (9,  1, 'SAF-108', 'Hearing Conservation',
        'Effects of noise, audiometric testing, hearing protector use per 29 CFR 1910.95(k).',
        30, 'classroom', 1, 70, 12),
    (10, 1, 'SAF-109', 'Confined Space Entry',
        'Permit system, atmospheric testing, entry/rescue procedures per 29 CFR 1910.146.',
        120, 'blended', 1, 80, 12),
    (11, 1, 'SAF-110', 'Fall Protection',
        'Fall hazard recognition, PFAS inspection/use, guardrails, safety nets per 29 CFR 1926.503.',
        60, 'blended', 1, 80, 12),
    (12, 1, 'DOT-101', 'DOT HazMat General Awareness',
        'HMR overview, hazard classes, shipping papers, marking/labeling per 49 CFR 172.704.',
        60, 'classroom', 1, 80, 36),
    (13, 1, 'DOT-103', 'DOT HazMat Security Awareness',
        'Security plans, threat recognition, reporting procedures per 49 CFR 172.704(a)(4).',
        30, 'online', 1, 80, 36);


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================
-- These demonstrate how to use the training module.
-- Uncomment and run in your SQL client to test.

/*
-- 1. See what training an employee needs and their current status
SELECT * FROM v_employee_training_status
WHERE employee_id = 1
ORDER BY priority_order;

-- 2. Get gap analysis for all employees (missing/expired training)
SELECT * FROM v_training_gap_analysis
ORDER BY priority_order, employee_name;

-- 3. Get compliance summary by employee
SELECT * FROM v_training_summary_by_employee
ORDER BY compliance_percent ASC;

-- 4. See what's expiring in the next 90 days
SELECT * FROM v_training_expiring
ORDER BY days_until_expiration;

-- 5. Get training requirements for a specific work area via hazard types
SELECT DISTINCT
    rr.name AS requirement_name,
    rr.agency,
    rr.cfr_reference,
    wah.hazard_type_code,
    wah.specificity,
    tc.course_name
FROM work_areas wa
INNER JOIN work_area_hazards wah ON wa.id = wah.work_area_id
INNER JOIN training_requirement_triggers trt
    ON trt.trigger_type = 'hazard_type'
   AND trt.hazard_type_code = wah.hazard_type_code
INNER JOIN training_regulatory_requirements rr ON trt.requirement_id = rr.id
LEFT JOIN course_requirements cr ON rr.id = cr.requirement_id
LEFT JOIN training_courses tc ON cr.course_id = tc.id
WHERE wa.id = 1;

-- 6. Assign training to a new hire (all initial training)
INSERT INTO training_assignments (employee_id, course_id, due_date, assigned_by, reason, priority)
SELECT
    999,  -- Replace with actual employee_id
    course_id,
    date('now', '+30 days'),
    'System',
    'New hire initial training',
    'high'
FROM v_employee_required_courses
WHERE employee_id = 999;

-- 7. Record a training completion (expiration auto-calculated by trigger)
INSERT INTO training_completions
    (employee_id, course_id, completion_date, score, passed, instructor, delivery_method)
VALUES
    (1, 1, date('now'), 85, 1, 'John Smith', 'classroom');

-- 8. Assign training from a corrective action (cross-module link)
INSERT INTO training_assignments
    (employee_id, course_id, due_date, assigned_by, reason, priority, corrective_action_id, incident_id)
VALUES
    (1, 6, date('now', '+14 days'), 'EHS Manager', 'LOTO incident follow-up', 'urgent', 42, 17);

-- 9. View pending assignments including incident-triggered ones
SELECT * FROM v_pending_training_assignments
WHERE incident_id IS NOT NULL;
*/
