-- Waypoint-EHS - PPE Tracking Schema
-- Tracks personal protective equipment inventory, assignments, inspections,
-- fit testing, and replacement for serialized PPE items.
--
-- Regulatory References:
--   OSHA 1910.132 - General PPE requirements
--   OSHA 1910.134 - Respiratory protection (fit testing, training)
--   OSHA 1910.140 - Fall protection (inspection requirements)
--   OSHA 1910.135 - Head protection
--   ANSI Z87.1 - Eye and face protection
--   ANSI Z89.1 - Head protection
--
-- Design Philosophy:
--   - Serialized items tracked individually (harnesses, respirators, PAPRs)
--   - Assignment eligibility based on training + fit test completion
--   - Inspection schedules vary by PPE category
--   - Replacement history with reason tracking
--   - Employee size profiles for ordering/stocking
--
-- Connects to:
--   - establishments (001_incidents.sql)
--   - employees (001_incidents.sql) - who has what, sizes
--   - training_courses (003_training.sql) - required training before issue
--   - employee_training (003_training.sql) - completed training lookup

-- ============================================================================
-- PPE CATEGORIES
-- ============================================================================
-- High-level groupings of PPE by body area protected.

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

-- Seed PPE categories
INSERT OR IGNORE INTO ppe_categories
    (id, category_code, category_name, description, default_inspection_frequency_days, display_order) VALUES
    (1, 'RESPIRATORY', 'Respiratory Protection', 'Respirators, PAPRs, SAPRs, SCBAs', 30, 1),
    (2, 'FALL_PROTECTION', 'Fall Protection', 'Harnesses, lanyards, SRLs, anchors', 180, 2),
    (3, 'HEAD', 'Head Protection', 'Hard hats, bump caps', 365, 3),
    (4, 'EYE', 'Eye Protection', 'Safety glasses, goggles', NULL, 4),
    (5, 'FACE', 'Face Protection', 'Face shields, welding helmets', NULL, 5),
    (6, 'HAND', 'Hand Protection', 'Gloves - chemical, cut, heat, general', NULL, 6),
    (7, 'FOOT', 'Foot Protection', 'Safety boots, wellingtons, metatarsal guards', NULL, 7),
    (8, 'BODY', 'Body Protection', 'Coveralls, aprons, chemical suits', NULL, 8),
    (9, 'HEARING', 'Hearing Protection', 'Earplugs, earmuffs', NULL, 9);


-- ============================================================================
-- PPE TYPES
-- ============================================================================
-- Specific types of PPE within each category.

CREATE TABLE IF NOT EXISTS ppe_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER NOT NULL,

    type_code TEXT NOT NULL UNIQUE,         -- 'HALF_MASK_APR', 'FULL_HARNESS', 'CHEM_GLOVE'
    type_name TEXT NOT NULL,                -- 'Half-Mask Air Purifying Respirator'
    description TEXT,

    -- Requirements
    requires_fit_test INTEGER DEFAULT 0,    -- 1 = must have valid fit test before issue
    requires_training INTEGER DEFAULT 0,    -- 1 = must complete training before issue
    requires_inspection INTEGER DEFAULT 0,  -- 1 = periodic inspection required
    
    -- Inspection schedule (overrides category default if set)
    inspection_frequency_days INTEGER,      -- Days between required inspections
    
    -- Expiration (for items with shelf life or max service life)
    has_expiration INTEGER DEFAULT 0,
    default_service_life_months INTEGER,    -- Max months in service (NULL = no limit)

    -- Fit test specifics
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


-- ============================================================================
-- PPE SIZE TYPES
-- ============================================================================
-- Different sizing systems for different PPE.

CREATE TABLE IF NOT EXISTS ppe_size_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    size_type_code TEXT NOT NULL UNIQUE,    -- 'GLOVE', 'BOOT', 'RESPIRATOR', 'COVERALL'
    size_type_name TEXT NOT NULL,           -- 'Glove Size', 'Boot Size'
    
    -- Available sizes for this type (JSON array for flexibility)
    available_sizes TEXT NOT NULL,          -- '["S", "M", "L", "XL", "2XL"]' or '["7", "8", "9", "10", "11", "12"]'
    
    description TEXT,

    created_at TEXT DEFAULT (datetime('now'))
);

-- Seed common size types
INSERT OR IGNORE INTO ppe_size_types
    (id, size_type_code, size_type_name, available_sizes) VALUES
    (1, 'GLOVE', 'Glove Size', '["XS", "S", "M", "L", "XL", "2XL"]'),
    (2, 'BOOT', 'Boot Size', '["6", "7", "8", "9", "10", "11", "12", "13", "14", "15"]'),
    (3, 'RESPIRATOR', 'Respirator Size', '["S", "M", "L"]'),
    (4, 'HARD_HAT', 'Hard Hat Size', '["6.5-8", "Universal"]'),
    (5, 'COVERALL', 'Coverall Size', '["S", "M", "L", "XL", "2XL", "3XL", "4XL"]'),
    (6, 'HARNESS', 'Harness Size', '["S", "M/L", "XL", "2XL/3XL"]');


-- Seed PPE types (after size_types so FK works)
INSERT OR IGNORE INTO ppe_types
    (id, category_id, type_code, type_name, requires_fit_test, requires_training, 
     requires_inspection, inspection_frequency_days, fit_test_frequency_months, 
     fit_test_protocol, size_type_id, has_expiration, default_service_life_months) VALUES
    
    -- Respiratory (category 1)
    (1, 1, 'HALF_MASK_APR', 'Half-Mask Air Purifying Respirator', 1, 1, 1, 30, 12, 'qualitative', 3, 0, 60),
    (2, 1, 'FULL_FACE_APR', 'Full-Face Air Purifying Respirator', 1, 1, 1, 30, 12, 'quantitative', 3, 0, 60),
    (3, 1, 'PAPR', 'Powered Air Purifying Respirator', 1, 1, 1, 30, 12, 'quantitative', NULL, 0, NULL),
    (4, 1, 'SAPR', 'Supplied Air Respirator', 1, 1, 1, 30, 12, 'quantitative', 3, 0, NULL),
    (5, 1, 'SCBA', 'Self-Contained Breathing Apparatus', 1, 1, 1, 30, 12, 'quantitative', 3, 0, NULL),
    
    -- Fall Protection (category 2)
    (10, 2, 'FULL_HARNESS', 'Full Body Harness', 0, 1, 1, 180, NULL, NULL, 6, 1, 60),
    (11, 2, 'SHOCK_LANYARD', 'Shock-Absorbing Lanyard', 0, 1, 1, 180, NULL, NULL, NULL, 1, 60),
    (12, 2, 'SRL', 'Self-Retracting Lifeline', 0, 1, 1, 365, NULL, NULL, NULL, 0, NULL),
    (13, 2, 'POSITIONING_LANYARD', 'Positioning Lanyard', 0, 1, 1, 180, NULL, NULL, NULL, 1, 60),
    
    -- Head (category 3)
    (20, 3, 'HARD_HAT_TYPE1', 'Hard Hat - Type I (Top Impact)', 0, 0, 1, 365, NULL, NULL, 4, 1, 60),
    (21, 3, 'HARD_HAT_TYPE2', 'Hard Hat - Type II (Top & Side Impact)', 0, 0, 1, 365, NULL, NULL, 4, 1, 60),
    (22, 3, 'BUMP_CAP', 'Bump Cap', 0, 0, 0, NULL, NULL, NULL, 4, 0, NULL),
    
    -- Eye (category 4)
    (30, 4, 'SAFETY_GLASSES', 'Safety Glasses', 0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (31, 4, 'SAFETY_GOGGLES', 'Safety Goggles', 0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (32, 4, 'RX_SAFETY_GLASSES', 'Prescription Safety Glasses', 0, 0, 0, NULL, NULL, NULL, NULL, 0, 24),
    
    -- Face (category 5)
    (40, 5, 'FACE_SHIELD', 'Face Shield', 0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (41, 5, 'WELDING_HELMET', 'Welding Helmet', 0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (42, 5, 'AUTO_DARK_HELMET', 'Auto-Darkening Welding Helmet', 0, 0, 1, 365, NULL, NULL, NULL, 0, NULL),
    
    -- Hand (category 6)
    (50, 6, 'CHEM_GLOVE_NITRILE', 'Chemical Resistant Gloves - Nitrile', 0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (51, 6, 'CHEM_GLOVE_NEOPRENE', 'Chemical Resistant Gloves - Neoprene', 0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (52, 6, 'CHEM_GLOVE_BUTYL', 'Chemical Resistant Gloves - Butyl', 0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (53, 6, 'CUT_RESIST_GLOVE', 'Cut Resistant Gloves', 0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (54, 6, 'HEAT_RESIST_GLOVE', 'Heat Resistant Gloves', 0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    (55, 6, 'WELDING_GLOVE', 'Welding Gloves', 0, 0, 0, NULL, NULL, NULL, 1, 0, NULL),
    
    -- Foot (category 7)
    (60, 7, 'SAFETY_BOOT_STEEL', 'Safety Boot - Steel Toe', 0, 0, 0, NULL, NULL, NULL, 2, 0, NULL),
    (61, 7, 'SAFETY_BOOT_COMP', 'Safety Boot - Composite Toe', 0, 0, 0, NULL, NULL, NULL, 2, 0, NULL),
    (62, 7, 'WELLINGTON', 'Wellington Boots (Chemical)', 0, 0, 0, NULL, NULL, NULL, 2, 0, NULL),
    (63, 7, 'METATARSAL_GUARD', 'Metatarsal Guard', 0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    
    -- Body (category 8)
    (70, 8, 'COVERALL_STD', 'Coveralls - Standard', 0, 0, 0, NULL, NULL, NULL, 5, 0, NULL),
    (71, 8, 'COVERALL_FR', 'Coveralls - Flame Resistant', 0, 0, 0, NULL, NULL, NULL, 5, 0, NULL),
    (72, 8, 'CHEM_SUIT', 'Chemical Suit', 0, 1, 0, NULL, NULL, NULL, 5, 1, 24),
    (73, 8, 'WELDING_JACKET', 'Welding Jacket', 0, 0, 0, NULL, NULL, NULL, 5, 0, NULL),
    (74, 8, 'LEATHER_APRON', 'Leather Apron', 0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    
    -- Hearing (category 9)
    (80, 9, 'EARMUFF', 'Earmuffs', 0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL),
    (81, 9, 'EARPLUG_REUSABLE', 'Reusable Earplugs', 0, 0, 0, NULL, NULL, NULL, NULL, 0, NULL);


-- ============================================================================
-- PPE TRAINING REQUIREMENTS
-- ============================================================================
-- Links PPE types to required training courses. Must complete ALL linked
-- courses before PPE can be issued.

CREATE TABLE IF NOT EXISTS ppe_training_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ppe_type_id INTEGER NOT NULL,
    training_course_id INTEGER NOT NULL,

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

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (ppe_type_id) REFERENCES ppe_types(id),
    FOREIGN KEY (current_employee_id) REFERENCES employees(id),
    UNIQUE(establishment_id, asset_tag)
);

CREATE INDEX idx_ppe_items_establishment ON ppe_items(establishment_id);
CREATE INDEX idx_ppe_items_type ON ppe_items(ppe_type_id);
CREATE INDEX idx_ppe_items_status ON ppe_items(status);
CREATE INDEX idx_ppe_items_employee ON ppe_items(current_employee_id);
CREATE INDEX idx_ppe_items_serial ON ppe_items(serial_number);
CREATE INDEX idx_ppe_items_asset ON ppe_items(asset_tag);
CREATE INDEX idx_ppe_items_expiration ON ppe_items(expiration_date);


-- ============================================================================
-- PPE ASSIGNMENTS
-- ============================================================================
-- Current and historical assignments of PPE to employees.

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
    
    -- Training status
    CASE 
        WHEN pt.requires_training = 0 THEN 1
        WHEN (
            SELECT COUNT(*) FROM ppe_training_requirements ptr
            WHERE ptr.ppe_type_id = pt.id
              AND ptr.required_for_initial_issue = 1
              AND NOT EXISTS (
                  SELECT 1 FROM employee_training et
                  WHERE et.employee_id = e.id
                    AND et.course_id = ptr.training_course_id
                    AND et.status = 'completed'
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
    
    -- Overall eligibility
    CASE
        WHEN pt.requires_training = 1 AND (
            SELECT COUNT(*) FROM ppe_training_requirements ptr
            WHERE ptr.ppe_type_id = pt.id
              AND ptr.required_for_initial_issue = 1
              AND NOT EXISTS (
                  SELECT 1 FROM employee_training et
                  WHERE et.employee_id = e.id
                    AND et.course_id = ptr.training_course_id
                    AND et.status = 'completed'
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
                  SELECT 1 FROM employee_training et
                  WHERE et.employee_id = e.id
                    AND et.course_id = ptr.training_course_id
                    AND et.status = 'completed'
              )
        ) > 0 THEN 'Training not complete'
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
-- Shows all current (not returned) PPE assignments.
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
-- PPE items needing inspection.
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
-- PPE items approaching or past expiration date.
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
-- Summary of PPE inventory by type and status.
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
-- Summary of PPE assigned to each employee.
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
-- Update ppe_items status after inspection
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


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================
/*

-- 1. Check if employee can be assigned a half-mask respirator
SELECT * FROM v_ppe_assignment_eligibility
WHERE employee_id = 1
  AND type_code = 'HALF_MASK_APR';

-- 2. Record a new PPE item
INSERT INTO ppe_items
    (establishment_id, ppe_type_id, asset_tag, serial_number,
     manufacturer, model, size, purchase_date, in_service_date, expiration_date)
VALUES
    (1, 10, 'HAR-001', 'FP-2025-12345',
     '3M', 'DBI-SALA ExoFit', 'M/L', '2025-01-15', '2025-01-20',
     date('2025-01-20', '+5 years'));

-- 3. Assign PPE to employee (only if eligible!)
-- First check eligibility:
SELECT eligible_for_assignment, ineligibility_reason
FROM v_ppe_assignment_eligibility
WHERE employee_id = 1 AND ppe_type_id = 10;

-- If eligible, create assignment:
INSERT INTO ppe_assignments
    (ppe_item_id, employee_id, assigned_date, assigned_by_employee_id)
VALUES
    (1, 1, '2025-01-20', 2);

-- 4. Record fit test
INSERT INTO ppe_fit_tests
    (employee_id, ppe_type_id, test_date, expiration_date,
     test_protocol, test_method, respirator_manufacturer, respirator_model,
     respirator_size, passed, conducted_by)
VALUES
    (1, 1, '2025-01-15', '2026-01-15',
     'qualitative', 'saccharin', '3M', '6200',
     'M', 1, 'Safety Services Inc.');

-- 5. Record inspection
INSERT INTO ppe_inspections
    (ppe_item_id, inspection_date, inspected_by_employee_id,
     passed, condition, checklist_results, next_inspection_due)
VALUES
    (1, '2025-01-20', 2,
     1, 'good',
     '{"straps": "pass", "buckles": "pass", "D_rings": "pass", "stitching": "pass", "labels": "pass"}',
     date('2025-01-20', '+180 days'));

-- 6. Return PPE
UPDATE ppe_assignments
SET 
    returned_date = '2025-06-01',
    returned_condition = 'good',
    return_notes = 'Employee transferred to different department'
WHERE id = 1;

-- 7. Record replacement (item damaged)
INSERT INTO ppe_replacements
    (ppe_item_id, replacement_date, replaced_by_employee_id,
     replacement_reason, reason_details, condition_at_replacement, disposal_method)
VALUES
    (1, '2025-06-15', 2,
     'damaged', 'Fall arrest deployed - shock absorber activated',
     'damaged', 'disposed');

-- Update original item status
UPDATE ppe_items SET status = 'retired' WHERE id = 1;

-- 8. View all current assignments
SELECT * FROM v_ppe_current_assignments
WHERE establishment_id = 1;

-- 9. What PPE inspections are due?
SELECT * FROM v_ppe_inspections_due
WHERE establishment_id = 1
  AND urgency IN ('OVERDUE', 'DUE_THIS_WEEK');

-- 10. Who needs fit tests?
SELECT * FROM v_ppe_fit_tests_due
WHERE fit_test_status IN ('EXPIRED', 'EXPIRING_SOON', 'NEVER_TESTED');

-- 11. Inventory summary
SELECT * FROM v_ppe_inventory_summary
WHERE establishment_id = 1;

-- 12. Employee's PPE profile
SELECT * FROM v_employee_ppe_summary
WHERE employee_id = 1;

-- 13. Set up employee sizes
INSERT INTO employee_ppe_sizes (employee_id, size_type_id, size_value, measured_date)
VALUES 
    (1, 1, 'L', '2025-01-15'),      -- Glove: L
    (1, 2, '10', '2025-01-15'),     -- Boot: 10
    (1, 3, 'M', '2025-01-15'),      -- Respirator: M
    (1, 5, 'L', '2025-01-15'),      -- Coverall: L
    (1, 6, 'M/L', '2025-01-15');    -- Harness: M/L

-- 14. Link PPE type to required training
-- (Assumes training courses exist in training_courses table)
INSERT INTO ppe_training_requirements (ppe_type_id, training_course_id, required_for_initial_issue)
VALUES
    (1, 10, 1),   -- Half-mask requires Respiratory Protection training
    (10, 15, 1);  -- Harness requires Fall Protection training

-- 15. Find expiring items
SELECT * FROM v_ppe_expiring_items
WHERE establishment_id = 1;

*/


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
PPE TRACKING MODULE (007_ppe.sql)

PURPOSE:
Track serialized PPE inventory, assignments, inspections, fit testing,
and replacements with training/fit test enforcement before issue.

REFERENCE TABLES:
    - ppe_categories: High-level groupings (respiratory, fall protection, etc.)
    - ppe_types: Specific PPE types with requirements (fit test, training, inspection)
    - ppe_size_types: Sizing systems (glove, boot, respirator, etc.)
    - ppe_training_requirements: Links PPE types to required training courses

EMPLOYEE TABLES:
    - employee_ppe_sizes: Stores each employee's sizes
    - ppe_fit_tests: Fit test records (respirators)

INVENTORY & ASSIGNMENT:
    - ppe_items: Serialized PPE inventory with status tracking
    - ppe_assignments: Assignment history (who has/had what, when)

MAINTENANCE TABLES:
    - ppe_inspections: Periodic inspection records
    - ppe_replacements: Replacement/retirement history with reasons

VIEWS:
    - v_ppe_assignment_eligibility: Can employee be assigned this PPE?
    - v_ppe_current_assignments: Who has what currently
    - v_ppe_inspections_due: Items needing inspection
    - v_ppe_fit_tests_due: Employees needing fit tests
    - v_ppe_expiring_items: Items approaching expiration
    - v_ppe_inventory_summary: Counts by type and status
    - v_employee_ppe_summary: Summary per employee

TRIGGERS:
    - trg_ppe_assignment_insert: Updates item status when assigned
    - trg_ppe_assignment_return: Updates item status when returned
    - trg_ppe_inspection_status: Marks item out of service if inspection fails

PRE-SEEDED DATA:
    Categories (9):
        Respiratory, Fall Protection, Head, Eye, Face, Hand, Foot, Body, Hearing
    
    Types (35+):
        Respirators: Half-mask APR, Full-face APR, PAPR, SAPR, SCBA
        Fall Protection: Full harness, Shock lanyard, SRL, Positioning lanyard
        Head: Hard hat Type I/II, Bump cap
        Eye: Safety glasses, Goggles, Rx safety glasses
        Face: Face shield, Welding helmet, Auto-darkening helmet
        Hand: Chemical gloves (nitrile/neoprene/butyl), Cut/heat resistant, Welding
        Foot: Safety boots (steel/composite), Wellingtons, Metatarsal guards
        Body: Coveralls (standard/FR), Chemical suit, Welding jacket
        Hearing: Earmuffs, Reusable earplugs
    
    Size Types (6):
        Glove, Boot, Respirator, Hard Hat, Coverall, Harness

KEY FEATURES:
    1. Assignment eligibility checking (training + fit test validation)
    2. Serialized tracking with asset tags and serial numbers
    3. Fit test management with expiration tracking
    4. Inspection scheduling by PPE type
    5. Replacement history with reason tracking
    6. Employee size profiles
    7. Expiration tracking for items with shelf life

ENFORCEMENT MODEL:
    - v_ppe_assignment_eligibility view answers "can this employee have this PPE?"
    - Application checks view before allowing assignment
    - Database doesn't block (triggers don't enforce) - clean separation
    - Audit trail maintained regardless

INTEGRATION POINTS:
    - employees (001): Who has what, sizes, fit tests
    - training_courses (003): Required training before issue
    - employee_training (003): Completed training lookup
    - establishments (001): Multi-site inventory

REGULATORY DRIVERS:
    - OSHA 1910.132: General PPE requirements
    - OSHA 1910.134: Respiratory protection (fit testing, training)
    - OSHA 1910.140: Fall protection (inspection requirements)
    - OSHA 1910.135: Head protection
    - ANSI Z87.1/Z89.1: Eye and head protection standards

INSPECTION FREQUENCIES (Pre-configured):
    - Respiratory: 30 days
    - Fall Protection: 180 days
    - Hard Hats: 365 days
    - Auto-darkening helmets: 365 days

FIT TEST REQUIREMENTS:
    - All respirators: Annual (12 months)
    - Half-mask: Qualitative OK
    - Full-face/PAPR/SAPR/SCBA: Quantitative recommended

NEXT STEPS (Future Enhancements):
    - Consumable PPE tracking (non-serialized)
    - Automatic reorder alerts based on inventory levels
    - Cost tracking and reporting
    - QR code/barcode scanning integration
    - Mobile inspection app
*/
