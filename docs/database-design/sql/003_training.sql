-- Waypoint-EHS - Training Records Schema
-- Tracks employee training completions, requirements, and gap analysis
--
-- Design Philosophy:
--   - Courses can satisfy multiple regulatory requirements (many-to-many)
--   - Training requirements determined by: all_employees, job role/activity, or work area hazards
--   - Track completions with scores, not attempts
--   - Automatic expiration tracking based on course validity period
--
-- Connects to:
--   - employees (001_incidents.sql)
--   - regulatory_requirements, requirement_triggers (002a_sara313.sql)

-- ============================================================================
-- TRAINING COURSES
-- ============================================================================
-- The actual training courses/curricula offered.
-- A course can satisfy one or more regulatory requirements.

CREATE TABLE IF NOT EXISTS training_courses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    
    -- Course identification
    course_code TEXT,                       -- Internal code (e.g., 'SAF-101')
    course_name TEXT NOT NULL,
    description TEXT,
    
    -- Delivery details
    duration_minutes INTEGER,               -- Expected duration
    delivery_method TEXT,                   -- classroom, online, ojt, blended, self_study
    
    -- Testing/Scoring
    has_test INTEGER DEFAULT 0,             -- Does this course have a test?
    passing_score REAL,                     -- Minimum score to pass (NULL if no test)
    max_score REAL DEFAULT 100,
    
    -- Validity period
    validity_months INTEGER,                -- Months until retraining required (NULL = never expires)
    
    -- External/Vendor courses
    is_external INTEGER DEFAULT 0,          -- Provided by external vendor?
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
-- might cover HazCom, PPE, and Fire Extinguisher requirements).

CREATE TABLE IF NOT EXISTS course_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_id INTEGER NOT NULL,
    requirement_id INTEGER NOT NULL,
    
    -- A course might fully or partially satisfy a requirement
    satisfaction_type TEXT DEFAULT 'full',  -- full, partial, supplemental
    notes TEXT,                             -- Explanation if partial
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (course_id) REFERENCES training_courses(id) ON DELETE CASCADE,
    FOREIGN KEY (requirement_id) REFERENCES regulatory_requirements(id),
    UNIQUE(course_id, requirement_id)
);

CREATE INDEX idx_course_requirements_course ON course_requirements(course_id);
CREATE INDEX idx_course_requirements_requirement ON course_requirements(requirement_id);


-- ============================================================================
-- TRAINING COMPLETIONS
-- ============================================================================
-- Records of completed training. This is the core compliance record.
-- Each row = one employee completing one course on one date.

CREATE TABLE IF NOT EXISTS training_completions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    
    -- When
    completion_date TEXT NOT NULL,          -- Date training was completed
    expiration_date TEXT,                   -- When retraining is due (calculated from validity_months)
    
    -- Results
    score REAL,                             -- Test score (NULL if no test)
    passed INTEGER DEFAULT 1,               -- 1 if passed, 0 if failed (failed shouldn't count as completion)
    
    -- Delivery details for this instance
    instructor TEXT,                        -- Who delivered the training
    delivery_method TEXT,                   -- How it was delivered (may differ from course default)
    location TEXT,                          -- Where (classroom, online platform, etc.)
    
    -- Documentation
    certificate_number TEXT,                -- External certificate ID if applicable
    documentation_path TEXT,                -- Path to signed roster, certificate, etc.
    
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
-- Used for: new hires, role changes, remedial training, special circumstances.
-- Complements the automatic requirement determination.

CREATE TABLE IF NOT EXISTS training_assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    
    -- Assignment details
    assigned_date TEXT DEFAULT (datetime('now')),
    due_date TEXT,                          -- When must this be completed?
    
    assigned_by TEXT,                       -- Who assigned this
    reason TEXT,                            -- Why (new hire, role change, incident follow-up, etc.)
    priority TEXT DEFAULT 'normal',         -- urgent, high, normal, low
    
    -- Status tracking
    status TEXT DEFAULT 'assigned',         -- assigned, in_progress, completed, overdue, waived, cancelled
    
    -- Completion link (once completed)
    completion_id INTEGER,                  -- Links to training_completions when done
    
    -- Waiver info (if waived instead of completed)
    waived_by TEXT,
    waived_date TEXT,
    waiver_reason TEXT,
    waiver_expiration TEXT,                 -- Some waivers are temporary
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (course_id) REFERENCES training_courses(id),
    FOREIGN KEY (completion_id) REFERENCES training_completions(id)
);

CREATE INDEX idx_training_assignments_employee ON training_assignments(employee_id);
CREATE INDEX idx_training_assignments_course ON training_assignments(course_id);
CREATE INDEX idx_training_assignments_status ON training_assignments(status);
CREATE INDEX idx_training_assignments_due ON training_assignments(due_date);


-- ============================================================================
-- EMPLOYEE ACTIVITIES
-- ============================================================================
-- Tracks which activities employees perform that trigger training requirements.
-- Links to requirement_triggers where trigger_type = 'activity'.
--
-- Examples: FORKLIFT_OP, LOTO_AUTH, LOTO_AFF, HAZMAT_HANDLER, FIRST_AID

CREATE TABLE IF NOT EXISTS employee_activities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    activity_code TEXT NOT NULL,            -- Matches requirement_triggers.activity_code
    
    -- When this activity applies
    start_date TEXT NOT NULL,
    end_date TEXT,                          -- NULL if still active
    
    -- Context
    notes TEXT,
    authorized_by TEXT,                     -- Who authorized this activity assignment
    authorization_date TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (employee_id) REFERENCES employees(id),
    UNIQUE(employee_id, activity_code, start_date)
);

CREATE INDEX idx_employee_activities_employee ON employee_activities(employee_id);
CREATE INDEX idx_employee_activities_code ON employee_activities(activity_code);
CREATE INDEX idx_employee_activities_active ON employee_activities(end_date) WHERE end_date IS NULL;


-- ============================================================================
-- WORK AREA HAZARD PROFILES
-- ============================================================================
-- Defines what hazards exist in each work area/department.
-- Used to determine chemical-hazard-based training requirements.
--
-- This could be derived from chemical inventory, but explicitly tracking it:
--   1. Allows for non-chemical hazards (confined spaces, noise, etc.)
--   2. Handles areas where chemicals are used but not stored
--   3. Provides documentation for hazard assessments

CREATE TABLE IF NOT EXISTS work_areas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    
    -- Identification
    area_name TEXT NOT NULL,                -- e.g., "Plating Department", "Paint Line 1"
    area_code TEXT,                         -- Short code
    area_type TEXT,                         -- department, building, room, line, cell
    
    -- Hierarchy (optional - for organizing areas)
    parent_area_id INTEGER,                 -- For nested areas
    
    -- Location reference (links to storage_locations if applicable)
    building TEXT,
    floor_level TEXT,
    
    -- GHS Chemical Hazard Flags (TRUE if ANY chemical with this hazard is present/used)
    has_flammables INTEGER DEFAULT 0,
    has_oxidizers INTEGER DEFAULT 0,
    has_compressed_gases INTEGER DEFAULT 0,
    has_explosives INTEGER DEFAULT 0,
    has_self_reactives INTEGER DEFAULT 0,
    has_pyrophorics INTEGER DEFAULT 0,
    has_acute_toxics INTEGER DEFAULT 0,
    has_carcinogens INTEGER DEFAULT 0,
    has_mutagens INTEGER DEFAULT 0,
    has_reproductive_toxics INTEGER DEFAULT 0,
    has_respiratory_sensitizers INTEGER DEFAULT 0,
    has_skin_sensitizers INTEGER DEFAULT 0,
    has_corrosives INTEGER DEFAULT 0,
    has_eye_hazards INTEGER DEFAULT 0,
    
    -- Physical Hazards (non-chemical)
    has_confined_spaces INTEGER DEFAULT 0,
    has_electrical_hazards INTEGER DEFAULT 0,
    has_fall_hazards INTEGER DEFAULT 0,
    has_noise_hazards INTEGER DEFAULT 0,
    has_heat_hazards INTEGER DEFAULT 0,
    has_cold_hazards INTEGER DEFAULT 0,
    has_radiation_hazards INTEGER DEFAULT 0,
    has_machine_hazards INTEGER DEFAULT 0,
    
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
-- EMPLOYEE WORK AREA ASSIGNMENTS
-- ============================================================================
-- Links employees to the work areas where they work.
-- An employee can work in multiple areas (cross-trained, floater, etc.)

CREATE TABLE IF NOT EXISTS employee_work_areas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    work_area_id INTEGER NOT NULL,
    
    is_primary INTEGER DEFAULT 0,           -- Primary work area (for reporting)
    
    -- When assigned
    start_date TEXT DEFAULT (date('now')),
    end_date TEXT,                          -- NULL if currently assigned
    
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
-- ACTIVITY CODES (Reference Table)
-- ============================================================================
-- Defines the activity codes that can trigger training requirements.
-- These match the activity_code values in requirement_triggers.

CREATE TABLE IF NOT EXISTS activity_codes (
    code TEXT PRIMARY KEY,
    activity_name TEXT NOT NULL,
    description TEXT,
    
    -- What role/position typically performs this
    typical_roles TEXT,                     -- Comma-separated job titles
    
    -- Category for grouping
    category TEXT                           -- operations, maintenance, safety, logistics
);

INSERT OR IGNORE INTO activity_codes (code, activity_name, description, typical_roles, category) VALUES
    ('FORKLIFT_OP', 'Forklift Operation', 
        'Operates powered industrial trucks (forklifts, pallet jacks, etc.)', 
        'Forklift Operator, Warehouse, Material Handler', 'logistics'),
    ('LOTO_AUTH', 'Lockout/Tagout Authorized', 
        'Authorized to perform lockout/tagout on equipment', 
        'Maintenance, Mechanic, Electrician, Technician', 'maintenance'),
    ('LOTO_AFF', 'Lockout/Tagout Affected', 
        'Works in areas where LOTO is performed but does not perform it', 
        'Operator, Production', 'operations'),
    ('HAZMAT_HANDLER', 'HazMat Handler', 
        'Handles hazardous materials for shipping/receiving per DOT', 
        'Shipping, Receiving, Logistics', 'logistics'),
    ('FIRST_AID', 'First Aid Responder', 
        'Designated to provide first aid response', 
        'Safety, Supervisor, Lead', 'safety'),
    ('CONFINED_ENTRY', 'Confined Space Entry', 
        'Authorized for confined space entry', 
        'Maintenance, Operator', 'maintenance'),
    ('CONFINED_RESCUE', 'Confined Space Rescue', 
        'Trained for confined space rescue operations', 
        'Safety, Rescue Team', 'safety'),
    ('HOT_WORK', 'Hot Work Operations', 
        'Performs welding, cutting, brazing, or other hot work', 
        'Welder, Maintenance, Fabricator', 'maintenance'),
    ('CRANE_OP', 'Crane/Hoist Operation', 
        'Operates overhead cranes or hoists', 
        'Crane Operator, Rigger, Maintenance', 'operations'),
    ('AERIAL_LIFT', 'Aerial Lift Operation', 
        'Operates aerial lifts, scissor lifts, boom lifts', 
        'Maintenance, Facilities', 'maintenance'),
    ('ELECTRICAL_QUAL', 'Qualified Electrical Worker', 
        'Works on or near exposed energized electrical equipment', 
        'Electrician, Electrical Technician', 'maintenance'),
    ('RESPIRATOR_USER', 'Respirator User', 
        'Required to wear respiratory protection', 
        'Painter, Plater, Chemical Handler', 'operations'),
    ('FALL_PROTECT', 'Fall Protection Required', 
        'Works at heights requiring fall protection', 
        'Maintenance, Roofer, Construction', 'maintenance'),
    ('SPILL_RESPONSE', 'Spill Response Team', 
        'Member of chemical spill response team', 
        'Safety, Environmental, Operations Lead', 'safety'),
    ('HAZWOPER_OP', 'HAZWOPER Operations Level', 
        'Hazardous waste operations - operations level', 
        'Environmental, Waste Handler', 'safety'),
    ('FIRE_BRIGADE', 'Fire Brigade Member', 
        'Member of facility fire brigade', 
        'Safety, Maintenance', 'safety');


-- ============================================================================
-- VIEWS: Training Requirements Determination
-- ============================================================================
-- These views calculate what training each employee needs based on:
--   1. All-employee requirements (emergency procedures, etc.)
--   2. Activity/role-based requirements (forklift, LOTO, etc.)
--   3. Work area hazard exposure (HazCom, respiratory, etc.)
--   4. Direct assignments

-- ----------------------------------------------------------------------------
-- V_EMPLOYEE_REQUIRED_REQUIREMENTS
-- ----------------------------------------------------------------------------
-- Lists all regulatory requirements that apply to each active employee.
-- This is the foundation - determines WHAT is required before mapping to courses.

CREATE VIEW IF NOT EXISTS v_employee_required_requirements AS

-- 1. All-employee requirements
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.establishment_id,
    rr.id AS requirement_id,
    rr.requirement_code,
    rr.requirement_name,
    rr.frequency,
    rr.due_within_days,
    rs.agency,
    rs.regulation_code,
    'all_employees' AS trigger_source,
    'Applies to all employees' AS trigger_reason
FROM employees e
INNER JOIN establishments est ON e.establishment_id = est.id
CROSS JOIN regulatory_requirements rr
INNER JOIN requirement_triggers rt ON rr.id = rt.requirement_id
INNER JOIN regulatory_sources rs ON rr.source_id = rs.id
WHERE e.is_active = 1
  AND rr.is_active = 1
  AND rr.requirement_type = 'training'
  AND rt.trigger_type = 'all_employees'

UNION

-- 2. Activity-based requirements (from employee_activities)
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.establishment_id,
    rr.id AS requirement_id,
    rr.requirement_code,
    rr.requirement_name,
    rr.frequency,
    rr.due_within_days,
    rs.agency,
    rs.regulation_code,
    'activity' AS trigger_source,
    'Activity: ' || ea.activity_code AS trigger_reason
FROM employees e
INNER JOIN employee_activities ea ON e.id = ea.employee_id AND ea.end_date IS NULL
INNER JOIN requirement_triggers rt ON rt.activity_code = ea.activity_code
INNER JOIN regulatory_requirements rr ON rt.requirement_id = rr.id
INNER JOIN regulatory_sources rs ON rr.source_id = rs.id
WHERE e.is_active = 1
  AND rr.is_active = 1
  AND rr.requirement_type = 'training'
  AND rt.trigger_type = 'activity'

UNION

-- 3. Job role-based requirements (from job_title matching)
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.establishment_id,
    rr.id AS requirement_id,
    rr.requirement_code,
    rr.requirement_name,
    rr.frequency,
    rr.due_within_days,
    rs.agency,
    rs.regulation_code,
    'job_role' AS trigger_source,
    'Job role: ' || e.job_title AS trigger_reason
FROM employees e
INNER JOIN requirement_triggers rt ON e.job_title LIKE '%' || rt.job_role || '%'
INNER JOIN regulatory_requirements rr ON rt.requirement_id = rr.id
INNER JOIN regulatory_sources rs ON rr.source_id = rs.id
WHERE e.is_active = 1
  AND rr.is_active = 1
  AND rr.requirement_type = 'training'
  AND rt.trigger_type = 'activity'
  AND rt.job_role IS NOT NULL

UNION

-- 4. Work area hazard-based requirements
SELECT DISTINCT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.establishment_id,
    rr.id AS requirement_id,
    rr.requirement_code,
    rr.requirement_name,
    rr.frequency,
    rr.due_within_days,
    rs.agency,
    rs.regulation_code,
    'work_area_hazard' AS trigger_source,
    'Work area: ' || wa.area_name || ' (' || rt.hazard_flag || ')' AS trigger_reason
FROM employees e
INNER JOIN employee_work_areas ewa ON e.id = ewa.employee_id AND ewa.end_date IS NULL
INNER JOIN work_areas wa ON ewa.work_area_id = wa.id
INNER JOIN requirement_triggers rt ON rt.trigger_type = 'chemical_hazard'
INNER JOIN regulatory_requirements rr ON rt.requirement_id = rr.id
INNER JOIN regulatory_sources rs ON rr.source_id = rs.id
WHERE e.is_active = 1
  AND rr.is_active = 1
  AND rr.requirement_type = 'training'
  AND (
    (rt.hazard_flag = 'is_flammable' AND wa.has_flammables = 1) OR
    (rt.hazard_flag = 'is_oxidizer' AND wa.has_oxidizers = 1) OR
    (rt.hazard_flag = 'is_explosive' AND wa.has_explosives = 1) OR
    (rt.hazard_flag = 'is_acute_toxic' AND wa.has_acute_toxics = 1) OR
    (rt.hazard_flag = 'is_carcinogen' AND wa.has_carcinogens = 1) OR
    (rt.hazard_flag = 'is_respiratory_sensitizer' AND wa.has_respiratory_sensitizers = 1) OR
    (rt.hazard_flag = 'is_skin_sensitizer' AND wa.has_skin_sensitizers = 1) OR
    (rt.hazard_flag = 'signal_word' AND (
        wa.has_flammables = 1 OR wa.has_oxidizers = 1 OR wa.has_acute_toxics = 1 OR
        wa.has_corrosives = 1 OR wa.has_carcinogens = 1
    ))
  );


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
-- Most recent completion for each employee/course combination.
-- Includes expiration status.

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
-- Shows only missing or expired training - the action items.
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
-- Summary counts for each employee - useful for dashboard/overview.

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
-- Summary for each course - how many need it, have it, missing it.

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
    e.id AS establishment_id,
    e.name AS establishment_name,
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
FROM establishments e
LEFT JOIN v_employee_training_status ets ON e.id = ets.establishment_id
GROUP BY e.id, e.name;


-- ----------------------------------------------------------------------------
-- V_TRAINING_EXPIRING
-- ----------------------------------------------------------------------------
-- Training that will expire in the next 90 days - for scheduling retraining.

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
-- SAMPLE TRAINING COURSES - DEFERRED TO SETUP
-- ============================================================================
-- Pre-seeded courses are loaded after the first establishment is created.
-- This prevents foreign key failures during initial migration.
-- See: internal/database/seeds.go for the seed data that will be applied
-- programmatically after first-run setup completes.


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

CREATE INDEX IF NOT EXISTS idx_requirement_triggers_type 
    ON requirement_triggers(trigger_type);

CREATE INDEX IF NOT EXISTS idx_employees_active_establishment 
    ON employees(establishment_id) WHERE is_active = 1;


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

-- 5. Get training requirements for a specific work area
SELECT DISTINCT
    rr.requirement_name,
    rr.agency,
    tc.course_name
FROM work_areas wa
INNER JOIN requirement_triggers rt ON (
    (rt.hazard_flag = 'is_flammable' AND wa.has_flammables = 1) OR
    (rt.hazard_flag = 'is_acute_toxic' AND wa.has_acute_toxics = 1) OR
    (rt.hazard_flag = 'signal_word' AND (wa.has_flammables = 1 OR wa.has_corrosives = 1))
)
INNER JOIN regulatory_requirements rr ON rt.requirement_id = rr.id
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

-- 7. Record a training completion
INSERT INTO training_completions 
    (employee_id, course_id, completion_date, score, passed, instructor, delivery_method)
VALUES 
    (1, 1, date('now'), 85, 1, 'John Smith', 'classroom');
-- Note: expiration_date is auto-calculated by trigger

-- 8. Check overall compliance for the establishment
SELECT * FROM v_training_compliance_summary;
*/


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
TRAINING MODULE (003_training.sql)

TABLES:
  - training_courses: Course definitions with validity periods
  - course_requirements: Many-to-many link to regulatory requirements
  - training_completions: Employee completion records with scores
  - training_assignments: Direct/manual training assignments
  - employee_activities: Activity codes assigned to employees (forklift, LOTO, etc.)
  - work_areas: Hazard profiles for work areas/departments
  - employee_work_areas: Links employees to their work areas
  - activity_codes: Reference table of activity codes

VIEWS:
  - v_employee_required_requirements: What requirements apply to each employee
  - v_employee_required_courses: What courses satisfy those requirements
  - v_employee_current_training: Most recent completion status per employee/course
  - v_employee_training_status: Full status combining required vs completed
  - v_training_gap_analysis: Missing/expired training only (action items)
  - v_training_summary_by_employee: Compliance counts per employee
  - v_training_summary_by_course: Compliance counts per course
  - v_training_compliance_summary: Overall establishment compliance
  - v_training_expiring: Training expiring in next 90 days
  - v_pending_training_assignments: Active direct assignments

TRIGGERS:
  - Auto-calculate expiration_date on completion
  - Auto-update assignment status when completed

TRAINING REQUIREMENT DETERMINATION:
  Requirements flow to employees through:
  1. All-employee triggers (emergency procedures)
  2. Activity-based triggers (forklift operation, LOTO authorization)
  3. Job role matching (job_title contains trigger role)
  4. Work area hazard exposure (employee in area with flammables, etc.)
  5. Direct assignment (manual override)
*/
