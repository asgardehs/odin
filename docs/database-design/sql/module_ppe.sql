-- Module PPE: Personal Protective Equipment
-- Derived from ehs-ontology-v3.1.ttl — ehs:PPE (subclass of ehs:ControlMeasure)
--
-- Ontology position: PPE is hierarchyRank 5 in the Hierarchy of Controls —
-- the LAST line of defense. The ontology explicitly notes that PPE is "least
-- effective because it relies on consistent and correct worker usage."
-- This is why the schema enforces prerequisites: you cannot hand someone a
-- respirator without proving they were trained (Education) and fit-tested.
--
-- Connection to the 5 E's framework:
--   Education   — PPE assignments require completed training (ppe_training_requirements)
--   Evaluation  — PPE condition verified via periodic inspections (ppe_inspections)
--   Enforcement — Assignment eligibility view blocks issue to unqualified workers
--   Engineering — PPE is what you use when engineering controls aren't sufficient
--   Elimination — PPE exists because elimination/substitution weren't feasible
--
-- Regulatory References:
--   OSHA 1910.132 — General PPE requirements
--   OSHA 1910.134 — Respiratory protection (fit testing, training, medical eval)
--   OSHA 1910.140 — Fall protection (inspection requirements)
--   OSHA 1910.135 — Head protection
--   ANSI Z87.1    — Eye and face protection
--   ANSI Z89.1    — Head protection
--
-- Design Philosophy:
--   - Serialized items tracked individually (harnesses, respirators, PAPRs)
--   - Assignment eligibility based on training + fit test completion
--   - Inspection schedules vary by PPE category
--   - Replacement history with reason tracking
--   - Employee size profiles for ordering/stocking
--   - Hazard-type mapping enables "hazard → PPE suggestion" workflows
--
-- Cross-module references:
--   - establishments (shared foundation)  — multi-site inventory
--   - employees (shared foundation)       — who has what, sizes, fit tests
--   - training_courses (module_training)  — required training before issue
--   - training_completions (module_training) — completed training lookup
--   - hazard_type_codes (module_training) — links PPE categories to hazard types
--   - corrective_actions (module_c_osha300) — PPE as corrective action from investigation
--   - incidents (module_c_osha300)        — PPE damaged/contaminated during incident


-- ============================================================================
-- PPE CATEGORIES
-- ============================================================================
-- High-level groupings of PPE by body area protected.
-- Maps to ehs:PPE subclasses in the ontology. Each category corresponds
-- to a family of hazard types — the ppe_hazard_type_map junction table
-- makes this relationship explicit and queryable.

CREATE TABLE IF NOT EXISTS ppe_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    category_code TEXT NOT NULL UNIQUE,     -- 'RESPIRATORY', 'FALL_PROTECTION', 'HAND'
    category_name TEXT NOT NULL,            -- 'Respiratory Protection', 'Fall Protection'
    description TEXT,

    -- Inspection requirements (defaults, can override at type level)
    default_inspection_frequency_days INTEGER,  -- NULL if no inspection required

    display_order INTEGER,

    created_at TEXT DEFAULT (datetime('now'))
);

-- Seed PPE categories (9 categories covering all body areas)
INSERT OR IGNORE INTO ppe_categories
    (id, category_code, category_name, description, default_inspection_frequency_days, display_order) VALUES
    (1, 'RESPIRATORY',      'Respiratory Protection', 'Respirators, PAPRs, SAPRs, SCBAs',                    30,   1),
    (2, 'FALL_PROTECTION',  'Fall Protection',        'Harnesses, lanyards, SRLs, anchors',                   180,  2),
    (3, 'HEAD',             'Head Protection',        'Hard hats, bump caps',                                 365,  3),
    (4, 'EYE',              'Eye Protection',         'Safety glasses, goggles',                               NULL, 4),
    (5, 'FACE',             'Face Protection',        'Face shields, welding helmets',                         NULL, 5),
    (6, 'HAND',             'Hand Protection',        'Gloves - chemical, cut, heat, general',                 NULL, 6),
    (7, 'FOOT',             'Foot Protection',        'Safety boots, wellingtons, metatarsal guards',          NULL, 7),
    (8, 'BODY',             'Body Protection',        'Coveralls, aprons, chemical suits',                     NULL, 8),
    (9, 'HEARING',          'Hearing Protection',     'Earplugs, earmuffs',                                    NULL, 9);


-- ============================================================================
-- PPE HAZARD TYPE MAP (junction: PPE categories ↔ hazard types)
-- ============================================================================
-- Enables the hazard-based PPE suggestion workflow:
--   "This work area has CHEMICAL hazards"
--   → query this table
--   → "You need: respiratory protection, chemical gloves, eye protection"
--
-- Hazard type codes are defined in module_training.sql and map directly
-- to ontology ehs:HazardType subclasses.

CREATE TABLE IF NOT EXISTS ppe_hazard_type_map (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ppe_category_id INTEGER NOT NULL,
    hazard_type_code TEXT NOT NULL,         -- FK → hazard_type_codes.code

    -- How strongly this PPE category relates to the hazard
    relevance TEXT DEFAULT 'primary',       -- 'primary' = directly protective,
                                            -- 'secondary' = situationally needed

    notes TEXT,                             -- e.g. "Respiratory needed for airborne chemical exposure"

    FOREIGN KEY (ppe_category_id) REFERENCES ppe_categories(id),
    FOREIGN KEY (hazard_type_code) REFERENCES hazard_type_codes(code),
    UNIQUE(ppe_category_id, hazard_type_code)
);

CREATE INDEX idx_ppe_hazard_map_category ON ppe_hazard_type_map(ppe_category_id);
CREATE INDEX idx_ppe_hazard_map_hazard ON ppe_hazard_type_map(hazard_type_code);

-- Seed PPE ↔ hazard type mappings
-- These reflect real-world PPE selection logic from hazard assessments.
INSERT OR IGNORE INTO ppe_hazard_type_map
    (ppe_category_id, hazard_type_code, relevance, notes) VALUES
    -- Respiratory → chemical (airborne), biological (pathogens)
    (1, 'CHEMICAL',    'primary',   'Airborne chemical exposure: vapors, fumes, dusts, mists'),
    (1, 'BIOLOGICAL',  'primary',   'Airborne pathogens, mold spores, biological aerosols'),

    -- Fall protection → physical (falls from height)
    (2, 'PHYSICAL',    'primary',   'Fall hazards: elevated work, leading edges, holes'),

    -- Head protection → physical (struck-by, falling objects), mechanical (overhead hazards)
    (3, 'PHYSICAL',    'primary',   'Falling objects, overhead obstructions'),
    (3, 'MECHANICAL',  'primary',   'Struck-by hazards from moving equipment'),
    (3, 'ELECTRICAL',  'secondary', 'Class E hard hats for electrical arc protection'),

    -- Eye protection → chemical (splashes), physical (particles, UV), mechanical (flying debris)
    (4, 'CHEMICAL',    'primary',   'Chemical splashes, acid/caustic spray'),
    (4, 'PHYSICAL',    'primary',   'Flying particles, dust, UV/IR radiation'),
    (4, 'MECHANICAL',  'primary',   'Flying debris from grinding, cutting, machining'),
    (4, 'BIOLOGICAL',  'secondary', 'Splash protection from potentially infectious materials'),

    -- Face protection → chemical (full-face splash), physical (heat, particles)
    (5, 'CHEMICAL',    'primary',   'Full-face chemical splash protection'),
    (5, 'PHYSICAL',    'primary',   'Radiant heat, molten metal splash, large particle impact'),

    -- Hand protection → chemical (contact), mechanical (cuts), physical (heat, cold)
    (6, 'CHEMICAL',    'primary',   'Chemical contact: dermal absorption, corrosive burns'),
    (6, 'MECHANICAL',  'primary',   'Cut, puncture, abrasion hazards'),
    (6, 'PHYSICAL',    'secondary', 'Extreme temperatures: heat-resistant, cryogenic gloves'),
    (6, 'BIOLOGICAL',  'secondary', 'Bloodborne pathogen barrier (exam/surgical gloves)'),

    -- Foot protection → mechanical (crush, puncture), chemical (spills), electrical (static)
    (7, 'MECHANICAL',  'primary',   'Crush, compression, puncture hazards'),
    (7, 'CHEMICAL',    'secondary', 'Chemical spill protection (wellington boots)'),
    (7, 'ELECTRICAL',  'secondary', 'ESD/static dissipative footwear'),

    -- Body protection → chemical (full-body contact), physical (heat, flame)
    (8, 'CHEMICAL',    'primary',   'Full-body chemical exposure: suits, aprons'),
    (8, 'PHYSICAL',    'primary',   'Flame, radiant heat, molten metal splash'),
    (8, 'BIOLOGICAL',  'secondary', 'Biological contamination barrier (Tyvek suits)'),

    -- Hearing protection → physical (noise)
    (9, 'PHYSICAL',    'primary',   'Noise exposure above OSHA PEL (90 dBA TWA) or action level (85 dBA)');


-- ============================================================================
-- PPE SIZE TYPES
-- ============================================================================
-- Different sizing systems for different PPE. Defined before ppe_types
-- because ppe_types.size_type_id references this table.

CREATE TABLE IF NOT EXISTS ppe_size_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    size_type_code TEXT NOT NULL UNIQUE,    -- 'GLOVE', 'BOOT', 'RESPIRATOR', 'COVERALL'
    size_type_name TEXT NOT NULL,           -- 'Glove Size', 'Boot Size'

    -- Available sizes for this type (JSON array for flexibility)
    available_sizes TEXT NOT NULL,          -- '["S", "M", "L", "XL", "2XL"]'

    description TEXT,

    created_at TEXT DEFAULT (datetime('now'))
);

-- Seed common size types (6 sizing systems)
INSERT OR IGNORE INTO ppe_size_types
    (id, size_type_code, size_type_name, available_sizes) VALUES
    (1, 'GLOVE',    'Glove Size',      '["XS", "S", "M", "L", "XL", "2XL"]'),
    (2, 'BOOT',     'Boot Size',       '["6", "7", "8", "9", "10", "11", "12", "13", "14", "15"]'),
    (3, 'RESPIRATOR','Respirator Size', '["S", "M", "L"]'),
    (4, 'HARD_HAT', 'Hard Hat Size',   '["6.5-8", "Universal"]'),
    (5, 'COVERALL', 'Coverall Size',   '["S", "M", "L", "XL", "2XL", "3XL", "4XL"]'),
    (6, 'HARNESS',  'Harness Size',    '["S", "M/L", "XL", "2XL/3XL"]');


-- ============================================================================
-- PPE TYPES
-- ============================================================================
-- Specific types of PPE within each category. Each type carries its own
-- requirements for fit testing, training, and inspection — these are the
-- gates that the eligibility view enforces.

CREATE TABLE IF NOT EXISTS ppe_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER NOT NULL,

    type_code TEXT NOT NULL UNIQUE,         -- 'HALF_MASK_APR', 'FULL_HARNESS', 'CHEM_GLOVE'
    type_name TEXT NOT NULL,                -- 'Half-Mask Air Purifying Respirator'
    description TEXT,

    -- Requirements (the Education + Evaluation gates)
    requires_fit_test INTEGER DEFAULT 0,    -- 1 = must have valid fit test before issue
    requires_training INTEGER DEFAULT 0,    -- 1 = must complete training before issue
    requires_inspection INTEGER DEFAULT 0,  -- 1 = periodic inspection required

    -- Inspection schedule (overrides category default if set)
    inspection_frequency_days INTEGER,      -- Days between required inspections

    -- Expiration (for items with shelf life or max service life)
    has_expiration INTEGER DEFAULT 0,
    default_service_life_months INTEGER,    -- Max months in service (NULL = no limit)

    -- Fit test specifics (respiratory only, per 1910.134)
    fit_test_frequency_months INTEGER,      -- How often fit test required (12 for annual)
    fit_test_protocol TEXT,                 -- 'qualitative', 'quantitative'

    -- Sizing
    size_type_id INTEGER,                   -- FK to ppe_size_types (NULL if one-size)

    -- Status
    is_active INTEGER DEFAULT 1,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (category_id) REFERENCES ppe_categories(id),
    FOREIGN KEY (size_type_id) REFERENCES ppe_size_types(id)
);

CREATE INDEX idx_ppe_types_category ON ppe_types(category_id);
CREATE INDEX idx_ppe_types_fit_test ON ppe_types(requires_fit_test);

-- Seed PPE types (33 types across 9 categories)
INSERT OR IGNORE INTO ppe_types
    (id, category_id, type_code, type_name, requires_fit_test, requires_training,
     requires_inspection, inspection_frequency_days, fit_test_frequency_months,
     fit_test_protocol, size_type_id, has_expiration, default_service_life_months) VALUES

    -- Respiratory (category 1) — all require fit test + training per 1910.134
    (1,  1, 'HALF_MASK_APR',       'Half-Mask Air Purifying Respirator',   1, 1, 1, 30,  12, 'qualitative',  3, 0, 60),
    (2,  1, 'FULL_FACE_APR',       'Full-Face Air Purifying Respirator',   1, 1, 1, 30,  12, 'quantitative', 3, 0, 60),
    (3,  1, 'PAPR',                'Powered Air Purifying Respirator',     1, 1, 1, 30,  12, 'quantitative', NULL, 0, NULL),
    (4,  1, 'SAPR',                'Supplied Air Respirator',              1, 1, 1, 30,  12, 'quantitative', 3, 0, NULL),
    (5,  1, 'SCBA',                'Self-Contained Breathing Apparatus',   1, 1, 1, 30,  12, 'quantitative', 3, 0, NULL),

    -- Fall Protection (category 2) — training required per 1910.140, no fit test
    (10, 2, 'FULL_HARNESS',        'Full Body Harness',                    0, 1, 1, 180, NULL, NULL, 6, 1, 60),
    (11, 2, 'SHOCK_LANYARD',       'Shock-Absorbing Lanyard',             0, 1, 1, 180, NULL, NULL, NULL, 1, 60),
    (12, 2, 'SRL',                 'Self-Retracting Lifeline',            0, 1, 1, 365, NULL, NULL, NULL, 0, NULL),
    (13, 2, 'POSITIONING_LANYARD', 'Positioning Lanyard',                 0, 1, 1, 180, NULL, NULL, NULL, 1, 60),

    -- Head (category 3) — no training or fit test, periodic inspection
    (20, 3, 'HARD_HAT_TYPE1',      'Hard Hat - Type I (Top Impact)',       0, 0, 1, 365, NULL, NULL, 4, 1, 60),
    (21, 3, 'HARD_HAT_TYPE2',      'Hard Hat - Type II (Top & Side Impact)', 0, 0, 1, 365, NULL, NULL, 4, 1, 60),
    (22, 3, 'BUMP_CAP',            'Bump Cap',                            0, 0, 0, NULL, NULL, NULL, 4, 0, NULL),

    -- Eye (category 4) — no special requirements
    (30, 4, 'SAFETY_GLASSES',      'Safety Glasses',                      0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (31, 4, 'SAFETY_GOGGLES',      'Safety Goggles',                      0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (32, 4, 'RX_SAFETY_GLASSES',   'Prescription Safety Glasses',         0, 0, 0, NULL, NULL, NULL, NULL, 0, 24),

    -- Face (category 5) — auto-darkening helmets get annual inspection
    (40, 5, 'FACE_SHIELD',         'Face Shield',                         0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (41, 5, 'WELDING_HELMET',      'Welding Helmet',                      0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (42, 5, 'AUTO_DARK_HELMET',    'Auto-Darkening Welding Helmet',       0, 0, 1, 365, NULL, NULL, NULL, 0, NULL),

    -- Hand (category 6) — no special requirements, consumable-adjacent
    (50, 6, 'CHEM_GLOVE_NITRILE',  'Chemical Resistant Gloves - Nitrile',  0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (51, 6, 'CHEM_GLOVE_NEOPRENE', 'Chemical Resistant Gloves - Neoprene', 0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (52, 6, 'CHEM_GLOVE_BUTYL',    'Chemical Resistant Gloves - Butyl',    0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (53, 6, 'CUT_RESIST_GLOVE',    'Cut Resistant Gloves',                0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (54, 6, 'HEAT_RESIST_GLOVE',   'Heat Resistant Gloves',               0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (55, 6, 'WELDING_GLOVE',       'Welding Gloves',                      0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),

    -- Foot (category 7)
    (60, 7, 'SAFETY_BOOT_STEEL',   'Safety Boot - Steel Toe',             0, 0, 0, NULL, NULL, NULL, 2, 0, NULL),
    (61, 7, 'SAFETY_BOOT_COMP',    'Safety Boot - Composite Toe',         0, 0, 0, NULL, NULL, NULL, 2, 0, NULL),
    (62, 7, 'WELLINGTON',          'Wellington Boots (Chemical)',          0, 0, 0, NULL, NULL, NULL, 2, 0, NULL),
    (63, 7, 'METATARSAL_GUARD',    'Metatarsal Guard',                    0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),

    -- Body (category 8) — chemical suits require training
    (70, 8, 'COVERALL_STD',        'Coveralls - Standard',                0, 0, 0, NULL, NULL, NULL, 5, 0, NULL),
    (71, 8, 'COVERALL_FR',         'Coveralls - Flame Resistant',         0, 0, 0, NULL, NULL, NULL, 5, 0, NULL),
    (72, 8, 'CHEM_SUIT',           'Chemical Suit',                       0, 1, 0, NULL, NULL, NULL, 5, 1, 24),
    (73, 8, 'WELDING_JACKET',      'Welding Jacket',                      0, 0, 0, NULL, NULL, NULL, 5, 0, NULL),
    (74, 8, 'LEATHER_APRON',       'Leather Apron',                       0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),

    -- Hearing (category 9) — no special requirements
    (80, 9, 'EARMUFF',             'Earmuffs',                            0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (81, 9, 'EARPLUG_REUSABLE',    'Reusable Earplugs',                   0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL);


-- ============================================================================
-- PPE TRAINING REQUIREMENTS (junction: PPE types ↔ training courses)
-- ============================================================================
-- Links PPE types to required training courses. Must complete ALL linked
-- courses before PPE can be issued.
-- Cross-module FK: training_course_id → training_courses (module_training)

CREATE TABLE IF NOT EXISTS ppe_training_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ppe_type_id INTEGER NOT NULL,
    training_course_id INTEGER NOT NULL,    -- FK → training_courses (module_training)

    -- Is this training required before initial issue, or just periodic?
    required_for_initial_issue INTEGER DEFAULT 1,  -- 1 = must have before first assignment

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (ppe_type_id) REFERENCES ppe_types(id),
    FOREIGN KEY (training_course_id) REFERENCES training_courses(id),
    UNIQUE(ppe_type_id, training_course_id)
);

CREATE INDEX idx_ppe_training_req_type ON ppe_training_requirements(ppe_type_id);
CREATE INDEX idx_ppe_training_req_course ON ppe_training_requirements(training_course_id);


-- ============================================================================
-- EMPLOYEE PPE SIZES
-- ============================================================================
-- Stores each employee's sizes for different PPE types.
-- Useful for ordering and ensuring correct fit.

CREATE TABLE IF NOT EXISTS employee_ppe_sizes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    size_type_id INTEGER NOT NULL,

    size_value TEXT NOT NULL,               -- 'M', '10', 'XL', etc.

    -- Measurement details (optional)
    measured_date TEXT,
    measured_by_employee_id INTEGER,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (size_type_id) REFERENCES ppe_size_types(id),
    FOREIGN KEY (measured_by_employee_id) REFERENCES employees(id),
    UNIQUE(employee_id, size_type_id)
);

CREATE INDEX idx_emp_sizes_employee ON employee_ppe_sizes(employee_id);
CREATE INDEX idx_emp_sizes_type ON employee_ppe_sizes(size_type_id);


-- ============================================================================
-- PPE FIT TESTS
-- ============================================================================
-- Fit test records for respirators. Required annually by OSHA 1910.134.
-- Both qualitative (saccharin, Bitrex, irritant smoke) and quantitative
-- (PortaCount) protocols are supported.

CREATE TABLE IF NOT EXISTS ppe_fit_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    ppe_type_id INTEGER NOT NULL,           -- Which respirator type was tested

    -- Test details
    test_date TEXT NOT NULL,                -- Format: YYYY-MM-DD
    expiration_date TEXT NOT NULL,          -- Typically test_date + 12 months

    -- Test protocol
    test_protocol TEXT NOT NULL,            -- 'qualitative', 'quantitative'
    test_method TEXT,                       -- 'saccharin', 'bitrex', 'irritant_smoke', 'portacount'

    -- Respirator tested
    respirator_manufacturer TEXT,
    respirator_model TEXT,
    respirator_size TEXT,                   -- Size that passed fit test

    -- Results
    passed INTEGER NOT NULL,                -- 0 = failed, 1 = passed
    fit_factor REAL,                        -- Quantitative fit factor (if applicable)

    -- Conducted by
    conducted_by TEXT,                      -- Name/company of person conducting test
    conducted_by_employee_id INTEGER,       -- If internal (nullable)

    -- Documentation
    certificate_path TEXT,                  -- Path to fit test certificate

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (ppe_type_id) REFERENCES ppe_types(id),
    FOREIGN KEY (conducted_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_fit_tests_employee ON ppe_fit_tests(employee_id);
CREATE INDEX idx_fit_tests_type ON ppe_fit_tests(ppe_type_id);
CREATE INDEX idx_fit_tests_date ON ppe_fit_tests(test_date);
CREATE INDEX idx_fit_tests_expiration ON ppe_fit_tests(expiration_date);


-- ============================================================================
-- PPE ITEMS (Serialized Inventory)
-- ============================================================================
-- Individual PPE items tracked by serial number or asset tag.
-- Cross-module FKs: corrective_action_id and incident_id link PPE items
-- back to the incident/investigation workflow. A damaged respirator found
-- during incident investigation can be traced to its corrective action
-- (e.g., "replace all half-masks in Bldg 3 with full-face APRs").

CREATE TABLE IF NOT EXISTS ppe_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    ppe_type_id INTEGER NOT NULL,

    -- Identification
    serial_number TEXT,                     -- Manufacturer serial (nullable)
    asset_tag TEXT,                         -- Internal asset tag

    -- Item details
    manufacturer TEXT,
    model TEXT,
    size TEXT,                              -- Size of this specific item

    -- Dates
    manufacture_date TEXT,                  -- Format: YYYY-MM-DD (if known)
    purchase_date TEXT,
    in_service_date TEXT,                   -- When first put into service
    expiration_date TEXT,                   -- Hard expiration (if applicable)

    -- Purchase info
    purchase_order TEXT,
    purchase_cost REAL,
    vendor TEXT,

    -- Status
    status TEXT DEFAULT 'available',        -- 'available', 'assigned', 'inspection_due',
                                            -- 'out_of_service', 'retired', 'lost'

    -- Current assignment (denormalized for quick lookup)
    current_employee_id INTEGER,            -- Who has it now (NULL if available)
    assigned_date TEXT,

    -- Location (if not assigned)
    storage_location TEXT,                  -- Where stored when not assigned

    -- Cross-module: incident/investigation linkage
    -- PPE replacement or upgrade ordered as a corrective action
    corrective_action_id INTEGER,           -- FK → corrective_actions (module_c_osha300)
    -- PPE item damaged, contaminated, or involved in an incident
    incident_id INTEGER,                    -- FK → incidents (module_c_osha300)

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (ppe_type_id) REFERENCES ppe_types(id),
    FOREIGN KEY (current_employee_id) REFERENCES employees(id),
    FOREIGN KEY (corrective_action_id) REFERENCES corrective_actions(id),
    FOREIGN KEY (incident_id) REFERENCES incidents(id),
    UNIQUE(establishment_id, asset_tag)
);

CREATE INDEX idx_ppe_items_establishment ON ppe_items(establishment_id);
CREATE INDEX idx_ppe_items_type ON ppe_items(ppe_type_id);
CREATE INDEX idx_ppe_items_status ON ppe_items(status);
CREATE INDEX idx_ppe_items_employee ON ppe_items(current_employee_id);
CREATE INDEX idx_ppe_items_serial ON ppe_items(serial_number);
CREATE INDEX idx_ppe_items_asset ON ppe_items(asset_tag);
CREATE INDEX idx_ppe_items_expiration ON ppe_items(expiration_date);
CREATE INDEX idx_ppe_items_corrective_action ON ppe_items(corrective_action_id);
CREATE INDEX idx_ppe_items_incident ON ppe_items(incident_id);


-- ============================================================================
-- PPE ASSIGNMENTS
-- ============================================================================
-- Current and historical assignments of PPE to employees.
-- The assignment itself is the Enforcement point — the application checks
-- v_ppe_assignment_eligibility before allowing an INSERT here.

CREATE TABLE IF NOT EXISTS ppe_assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ppe_item_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,

    -- Assignment dates
    assigned_date TEXT NOT NULL,            -- Format: YYYY-MM-DD
    assigned_by_employee_id INTEGER,

    -- Return info (NULL if still assigned)
    returned_date TEXT,
    returned_condition TEXT,                -- 'good', 'fair', 'poor', 'damaged', 'lost'
    return_notes TEXT,

    -- Acknowledgment
    employee_acknowledged INTEGER DEFAULT 0,  -- Employee signed for receipt
    acknowledged_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (ppe_item_id) REFERENCES ppe_items(id),
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (assigned_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_ppe_assign_item ON ppe_assignments(ppe_item_id);
CREATE INDEX idx_ppe_assign_employee ON ppe_assignments(employee_id);
CREATE INDEX idx_ppe_assign_date ON ppe_assignments(assigned_date);
CREATE INDEX idx_ppe_assign_returned ON ppe_assignments(returned_date);


-- ============================================================================
-- PPE INSPECTIONS
-- ============================================================================
-- Periodic inspection records for PPE items.
-- This is the Evaluation leg of the 5 E's — confirming that PPE remains
-- in serviceable condition between assignments and during use.

CREATE TABLE IF NOT EXISTS ppe_inspections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ppe_item_id INTEGER NOT NULL,

    -- Inspection details
    inspection_date TEXT NOT NULL,          -- Format: YYYY-MM-DD
    inspected_by_employee_id INTEGER NOT NULL,

    -- Results
    passed INTEGER NOT NULL,                -- 0 = failed, 1 = passed
    condition TEXT,                         -- 'good', 'fair', 'poor', 'failed'

    -- Checklist results (JSON for flexibility across PPE types)
    checklist_results TEXT,                 -- JSON: {"straps": "pass", "buckles": "pass", ...}

    -- Issues found
    issues_found TEXT,                      -- Description of any issues
    corrective_action TEXT,                 -- What was done to address issues

    -- Next inspection
    next_inspection_due TEXT,               -- Format: YYYY-MM-DD

    -- If failed, what happened to the item
    removed_from_service INTEGER DEFAULT 0,
    removal_reason TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (ppe_item_id) REFERENCES ppe_items(id),
    FOREIGN KEY (inspected_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_ppe_insp_item ON ppe_inspections(ppe_item_id);
CREATE INDEX idx_ppe_insp_date ON ppe_inspections(inspection_date);
CREATE INDEX idx_ppe_insp_next ON ppe_inspections(next_inspection_due);
CREATE INDEX idx_ppe_insp_passed ON ppe_inspections(passed);


-- ============================================================================
-- PPE REPLACEMENTS
-- ============================================================================
-- Records when and why PPE items were replaced/retired.
-- Links back to the inventory for chain-of-custody tracking.

CREATE TABLE IF NOT EXISTS ppe_replacements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ppe_item_id INTEGER NOT NULL,

    -- Replacement details
    replacement_date TEXT NOT NULL,         -- Format: YYYY-MM-DD
    replaced_by_employee_id INTEGER,        -- Who processed the replacement

    -- Reason
    replacement_reason TEXT NOT NULL,       -- 'expired', 'damaged', 'worn', 'failed_inspection',
                                            -- 'lost', 'contaminated', 'upgrade', 'employee_terminated'
    reason_details TEXT,                    -- Additional context

    -- Condition at replacement
    condition_at_replacement TEXT,          -- 'serviceable', 'worn', 'damaged', 'destroyed', 'unknown'

    -- Replacement item (if replaced with new item)
    replacement_item_id INTEGER,            -- FK to new ppe_items record (nullable)

    -- Disposal
    disposal_method TEXT,                   -- 'disposed', 'returned_to_vendor', 'recycled', 'retained'

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (ppe_item_id) REFERENCES ppe_items(id),
    FOREIGN KEY (replaced_by_employee_id) REFERENCES employees(id),
    FOREIGN KEY (replacement_item_id) REFERENCES ppe_items(id)
);

CREATE INDEX idx_ppe_replace_item ON ppe_replacements(ppe_item_id);
CREATE INDEX idx_ppe_replace_date ON ppe_replacements(replacement_date);
CREATE INDEX idx_ppe_replace_reason ON ppe_replacements(replacement_reason);


-- ============================================================================
-- VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- v_ppe_assignment_eligibility
-- Shows whether an employee is eligible to be assigned a specific PPE type.
-- Checks training completion and fit test validity.
--
-- FIXED: References training_completions (module_training) instead of the
-- nonexistent employee_training table. Checks for passed completions with
-- valid (non-expired) status.
-- ----------------------------------------------------------------------------
CREATE VIEW v_ppe_assignment_eligibility AS
SELECT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.job_title,

    pt.id AS ppe_type_id,
    pt.type_code,
    pt.type_name,
    pc.category_name,

    pt.requires_training,
    pt.requires_fit_test,

    -- Training status: all required courses must have a passed, non-expired completion
    CASE
        WHEN pt.requires_training = 0 THEN 1
        WHEN (
            SELECT COUNT(*) FROM ppe_training_requirements ptr
            WHERE ptr.ppe_type_id = pt.id
              AND ptr.required_for_initial_issue = 1
              AND NOT EXISTS (
                  SELECT 1 FROM training_completions tc
                  WHERE tc.employee_id = e.id
                    AND tc.course_id = ptr.training_course_id
                    AND tc.passed = 1
                    AND (tc.expiration_date IS NULL OR tc.expiration_date >= date('now'))
              )
        ) = 0 THEN 1
        ELSE 0
    END AS training_complete,

    -- Fit test status (for respirators)
    CASE
        WHEN pt.requires_fit_test = 0 THEN 1
        WHEN EXISTS (
            SELECT 1 FROM ppe_fit_tests ft
            WHERE ft.employee_id = e.id
              AND ft.ppe_type_id = pt.id
              AND ft.passed = 1
              AND ft.expiration_date >= date('now')
        ) THEN 1
        ELSE 0
    END AS fit_test_valid,

    -- Fit test expiration (if applicable)
    (SELECT MAX(ft.expiration_date) FROM ppe_fit_tests ft
     WHERE ft.employee_id = e.id
       AND ft.ppe_type_id = pt.id
       AND ft.passed = 1) AS fit_test_expiration,

    -- Overall eligibility (both gates must pass)
    CASE
        WHEN pt.requires_training = 1 AND (
            SELECT COUNT(*) FROM ppe_training_requirements ptr
            WHERE ptr.ppe_type_id = pt.id
              AND ptr.required_for_initial_issue = 1
              AND NOT EXISTS (
                  SELECT 1 FROM training_completions tc
                  WHERE tc.employee_id = e.id
                    AND tc.course_id = ptr.training_course_id
                    AND tc.passed = 1
                    AND (tc.expiration_date IS NULL OR tc.expiration_date >= date('now'))
              )
        ) > 0 THEN 0
        WHEN pt.requires_fit_test = 1 AND NOT EXISTS (
            SELECT 1 FROM ppe_fit_tests ft
            WHERE ft.employee_id = e.id
              AND ft.ppe_type_id = pt.id
              AND ft.passed = 1
              AND ft.expiration_date >= date('now')
        ) THEN 0
        ELSE 1
    END AS eligible_for_assignment,

    -- Reason if not eligible
    CASE
        WHEN pt.requires_training = 1 AND (
            SELECT COUNT(*) FROM ppe_training_requirements ptr
            WHERE ptr.ppe_type_id = pt.id
              AND ptr.required_for_initial_issue = 1
              AND NOT EXISTS (
                  SELECT 1 FROM training_completions tc
                  WHERE tc.employee_id = e.id
                    AND tc.course_id = ptr.training_course_id
                    AND tc.passed = 1
                    AND (tc.expiration_date IS NULL OR tc.expiration_date >= date('now'))
              )
        ) > 0 THEN 'Training not complete or expired'
        WHEN pt.requires_fit_test = 1 AND NOT EXISTS (
            SELECT 1 FROM ppe_fit_tests ft
            WHERE ft.employee_id = e.id
              AND ft.ppe_type_id = pt.id
              AND ft.passed = 1
              AND ft.expiration_date >= date('now')
        ) THEN 'Fit test required or expired'
        ELSE NULL
    END AS ineligibility_reason

FROM employees e
CROSS JOIN ppe_types pt
INNER JOIN ppe_categories pc ON pt.category_id = pc.id
WHERE e.is_active = 1
  AND pt.is_active = 1;


-- ----------------------------------------------------------------------------
-- v_ppe_current_assignments
-- Shows all current (not returned) PPE assignments with expiration and
-- inspection status at a glance.
-- ----------------------------------------------------------------------------
CREATE VIEW v_ppe_current_assignments AS
SELECT
    pa.id AS assignment_id,

    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.job_title,
    e.department,

    pi.id AS item_id,
    pi.asset_tag,
    pi.serial_number,
    pi.manufacturer,
    pi.model,
    pi.size,

    pt.type_code,
    pt.type_name,
    pc.category_name,

    pa.assigned_date,
    julianday('now') - julianday(pa.assigned_date) AS days_assigned,

    pi.expiration_date,
    CASE
        WHEN pi.expiration_date IS NOT NULL AND pi.expiration_date < date('now') THEN 'EXPIRED'
        WHEN pi.expiration_date IS NOT NULL AND pi.expiration_date <= date('now', '+30 days') THEN 'EXPIRING_SOON'
        ELSE 'OK'
    END AS expiration_status,

    -- Next inspection due
    (SELECT MAX(insp.next_inspection_due) FROM ppe_inspections insp
     WHERE insp.ppe_item_id = pi.id) AS next_inspection_due,

    est.name AS establishment_name

FROM ppe_assignments pa
INNER JOIN ppe_items pi ON pa.ppe_item_id = pi.id
INNER JOIN employees e ON pa.employee_id = e.id
INNER JOIN ppe_types pt ON pi.ppe_type_id = pt.id
INNER JOIN ppe_categories pc ON pt.category_id = pc.id
INNER JOIN establishments est ON pi.establishment_id = est.id
WHERE pa.returned_date IS NULL
ORDER BY e.last_name, e.first_name, pc.display_order;


-- ----------------------------------------------------------------------------
-- v_ppe_inspections_due
-- PPE items needing inspection, ordered by urgency.
-- ----------------------------------------------------------------------------
CREATE VIEW v_ppe_inspections_due AS
SELECT
    pi.id AS item_id,
    pi.asset_tag,
    pi.serial_number,

    pt.type_code,
    pt.type_name,
    pc.category_name,

    pi.status,

    e.first_name || ' ' || e.last_name AS assigned_to,

    -- Last inspection
    (SELECT MAX(insp.inspection_date) FROM ppe_inspections insp
     WHERE insp.ppe_item_id = pi.id) AS last_inspection_date,

    -- Next due
    (SELECT MAX(insp.next_inspection_due) FROM ppe_inspections insp
     WHERE insp.ppe_item_id = pi.id) AS next_inspection_due,

    -- Days until due (negative = overdue)
    julianday(
        COALESCE(
            (SELECT MAX(insp.next_inspection_due) FROM ppe_inspections insp WHERE insp.ppe_item_id = pi.id),
            date(pi.in_service_date, '+' || COALESCE(pt.inspection_frequency_days, pc.default_inspection_frequency_days) || ' days')
        )
    ) - julianday('now') AS days_until_due,

    CASE
        WHEN (SELECT MAX(insp.next_inspection_due) FROM ppe_inspections insp WHERE insp.ppe_item_id = pi.id) < date('now')
            THEN 'OVERDUE'
        WHEN (SELECT MAX(insp.next_inspection_due) FROM ppe_inspections insp WHERE insp.ppe_item_id = pi.id) <= date('now', '+7 days')
            THEN 'DUE_THIS_WEEK'
        WHEN (SELECT MAX(insp.next_inspection_due) FROM ppe_inspections insp WHERE insp.ppe_item_id = pi.id) <= date('now', '+30 days')
            THEN 'DUE_THIS_MONTH'
        ELSE 'UPCOMING'
    END AS urgency,

    est.name AS establishment_name

FROM ppe_items pi
INNER JOIN ppe_types pt ON pi.ppe_type_id = pt.id
INNER JOIN ppe_categories pc ON pt.category_id = pc.id
INNER JOIN establishments est ON pi.establishment_id = est.id
LEFT JOIN employees e ON pi.current_employee_id = e.id
WHERE pi.status NOT IN ('retired', 'lost')
  AND pt.requires_inspection = 1
  AND COALESCE(pt.inspection_frequency_days, pc.default_inspection_frequency_days) IS NOT NULL
ORDER BY days_until_due;


-- ----------------------------------------------------------------------------
-- v_ppe_fit_tests_due
-- Employees needing fit tests (expired or never tested).
-- Only shows employees who have been assigned the respirator type or
-- have a prior fit test on record.
-- ----------------------------------------------------------------------------
CREATE VIEW v_ppe_fit_tests_due AS
SELECT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.job_title,
    e.department,

    pt.id AS ppe_type_id,
    pt.type_code,
    pt.type_name,
    pt.fit_test_frequency_months,

    -- Last fit test
    (SELECT MAX(ft.test_date) FROM ppe_fit_tests ft
     WHERE ft.employee_id = e.id AND ft.ppe_type_id = pt.id AND ft.passed = 1) AS last_fit_test_date,

    -- Current expiration
    (SELECT MAX(ft.expiration_date) FROM ppe_fit_tests ft
     WHERE ft.employee_id = e.id AND ft.ppe_type_id = pt.id AND ft.passed = 1) AS fit_test_expiration,

    -- Days until expiration (negative = expired)
    julianday(
        (SELECT MAX(ft.expiration_date) FROM ppe_fit_tests ft
         WHERE ft.employee_id = e.id AND ft.ppe_type_id = pt.id AND ft.passed = 1)
    ) - julianday('now') AS days_until_expiration,

    CASE
        WHEN (SELECT MAX(ft.expiration_date) FROM ppe_fit_tests ft
              WHERE ft.employee_id = e.id AND ft.ppe_type_id = pt.id AND ft.passed = 1) IS NULL
            THEN 'NEVER_TESTED'
        WHEN (SELECT MAX(ft.expiration_date) FROM ppe_fit_tests ft
              WHERE ft.employee_id = e.id AND ft.ppe_type_id = pt.id AND ft.passed = 1) < date('now')
            THEN 'EXPIRED'
        WHEN (SELECT MAX(ft.expiration_date) FROM ppe_fit_tests ft
              WHERE ft.employee_id = e.id AND ft.ppe_type_id = pt.id AND ft.passed = 1) <= date('now', '+30 days')
            THEN 'EXPIRING_SOON'
        ELSE 'VALID'
    END AS fit_test_status,

    -- Currently has this type assigned?
    CASE WHEN EXISTS (
        SELECT 1 FROM ppe_assignments pa
        INNER JOIN ppe_items pi ON pa.ppe_item_id = pi.id
        WHERE pa.employee_id = e.id
          AND pi.ppe_type_id = pt.id
          AND pa.returned_date IS NULL
    ) THEN 1 ELSE 0 END AS currently_assigned

FROM employees e
CROSS JOIN ppe_types pt
WHERE e.is_active = 1
  AND pt.requires_fit_test = 1
  AND pt.is_active = 1
  -- Only show employees who have been assigned this type or have had a fit test
  AND (
      EXISTS (
          SELECT 1 FROM ppe_assignments pa
          INNER JOIN ppe_items pi ON pa.ppe_item_id = pi.id
          WHERE pa.employee_id = e.id AND pi.ppe_type_id = pt.id
      )
      OR EXISTS (
          SELECT 1 FROM ppe_fit_tests ft
          WHERE ft.employee_id = e.id AND ft.ppe_type_id = pt.id
      )
  )
ORDER BY days_until_expiration NULLS FIRST;


-- ----------------------------------------------------------------------------
-- v_ppe_expiring_items
-- PPE items approaching or past expiration date (90-day lookahead).
-- ----------------------------------------------------------------------------
CREATE VIEW v_ppe_expiring_items AS
SELECT
    pi.id AS item_id,
    pi.asset_tag,
    pi.serial_number,
    pi.manufacturer,
    pi.model,

    pt.type_code,
    pt.type_name,
    pc.category_name,

    pi.expiration_date,
    julianday(pi.expiration_date) - julianday('now') AS days_until_expiration,

    CASE
        WHEN pi.expiration_date < date('now') THEN 'EXPIRED'
        WHEN pi.expiration_date <= date('now', '+30 days') THEN 'EXPIRING_30_DAYS'
        WHEN pi.expiration_date <= date('now', '+90 days') THEN 'EXPIRING_90_DAYS'
        ELSE 'OK'
    END AS expiration_status,

    pi.status AS item_status,

    e.first_name || ' ' || e.last_name AS assigned_to,

    est.name AS establishment_name

FROM ppe_items pi
INNER JOIN ppe_types pt ON pi.ppe_type_id = pt.id
INNER JOIN ppe_categories pc ON pt.category_id = pc.id
INNER JOIN establishments est ON pi.establishment_id = est.id
LEFT JOIN employees e ON pi.current_employee_id = e.id
WHERE pi.expiration_date IS NOT NULL
  AND pi.status NOT IN ('retired', 'lost')
  AND pi.expiration_date <= date('now', '+90 days')
ORDER BY pi.expiration_date;


-- ----------------------------------------------------------------------------
-- v_ppe_inventory_summary
-- Summary of PPE inventory by type and status per establishment.
-- ----------------------------------------------------------------------------
CREATE VIEW v_ppe_inventory_summary AS
SELECT
    est.id AS establishment_id,
    est.name AS establishment_name,

    pc.category_name,
    pt.type_code,
    pt.type_name,

    COUNT(*) AS total_items,
    SUM(CASE WHEN pi.status = 'available' THEN 1 ELSE 0 END) AS available,
    SUM(CASE WHEN pi.status = 'assigned' THEN 1 ELSE 0 END) AS assigned,
    SUM(CASE WHEN pi.status = 'inspection_due' THEN 1 ELSE 0 END) AS inspection_due,
    SUM(CASE WHEN pi.status = 'out_of_service' THEN 1 ELSE 0 END) AS out_of_service,
    SUM(CASE WHEN pi.status = 'retired' THEN 1 ELSE 0 END) AS retired,
    SUM(CASE WHEN pi.status = 'lost' THEN 1 ELSE 0 END) AS lost,

    -- Expiring soon
    SUM(CASE WHEN pi.expiration_date IS NOT NULL
              AND pi.expiration_date <= date('now', '+90 days')
              AND pi.status NOT IN ('retired', 'lost') THEN 1 ELSE 0 END) AS expiring_soon

FROM ppe_items pi
INNER JOIN ppe_types pt ON pi.ppe_type_id = pt.id
INNER JOIN ppe_categories pc ON pt.category_id = pc.id
INNER JOIN establishments est ON pi.establishment_id = est.id
GROUP BY est.id, est.name, pc.category_name, pt.type_code, pt.type_name
ORDER BY est.name, pc.display_order, pt.type_name;


-- ----------------------------------------------------------------------------
-- v_employee_ppe_summary
-- Summary of PPE assigned to each employee with alert counts.
-- ----------------------------------------------------------------------------
CREATE VIEW v_employee_ppe_summary AS
SELECT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.job_title,
    e.department,

    COUNT(DISTINCT pa.ppe_item_id) AS items_assigned,
    GROUP_CONCAT(DISTINCT pt.type_code) AS ppe_types_assigned,

    -- Any expiring items?
    SUM(CASE WHEN pi.expiration_date IS NOT NULL
              AND pi.expiration_date <= date('now', '+30 days') THEN 1 ELSE 0 END) AS items_expiring_soon,

    -- Any inspections due?
    SUM(CASE WHEN (SELECT MAX(insp.next_inspection_due) FROM ppe_inspections insp
                   WHERE insp.ppe_item_id = pi.id) <= date('now', '+30 days') THEN 1 ELSE 0 END) AS inspections_due_soon,

    -- Any fit tests expiring?
    (SELECT COUNT(*) FROM v_ppe_fit_tests_due ftd
     WHERE ftd.employee_id = e.id
       AND ftd.fit_test_status IN ('EXPIRED', 'EXPIRING_SOON')) AS fit_tests_expiring

FROM employees e
LEFT JOIN ppe_assignments pa ON e.id = pa.employee_id AND pa.returned_date IS NULL
LEFT JOIN ppe_items pi ON pa.ppe_item_id = pi.id
LEFT JOIN ppe_types pt ON pi.ppe_type_id = pt.id
WHERE e.is_active = 1
GROUP BY e.id, e.first_name, e.last_name, e.job_title, e.department
ORDER BY e.last_name, e.first_name;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Update ppe_items status and assignment info when assigned
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_ppe_assignment_insert
AFTER INSERT ON ppe_assignments
FOR EACH ROW
BEGIN
    UPDATE ppe_items
    SET
        status = 'assigned',
        current_employee_id = NEW.employee_id,
        assigned_date = NEW.assigned_date,
        updated_at = datetime('now')
    WHERE id = NEW.ppe_item_id;
END;


-- ----------------------------------------------------------------------------
-- Update ppe_items status when returned
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_ppe_assignment_return
AFTER UPDATE ON ppe_assignments
FOR EACH ROW
WHEN OLD.returned_date IS NULL AND NEW.returned_date IS NOT NULL
BEGIN
    UPDATE ppe_items
    SET
        status = CASE
            WHEN NEW.returned_condition IN ('damaged', 'lost') THEN 'out_of_service'
            ELSE 'available'
        END,
        current_employee_id = NULL,
        assigned_date = NULL,
        updated_at = datetime('now')
    WHERE id = NEW.ppe_item_id;
END;


-- ----------------------------------------------------------------------------
-- Update ppe_items status after failed inspection (removed from service)
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_ppe_inspection_status
AFTER INSERT ON ppe_inspections
FOR EACH ROW
WHEN NEW.removed_from_service = 1
BEGIN
    UPDATE ppe_items
    SET
        status = 'out_of_service',
        updated_at = datetime('now')
    WHERE id = NEW.ppe_item_id;
END;
