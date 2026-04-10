-- Waypoint-EHS - Licenses Schema
-- Tracks business licenses, professional certifications, and operator licenses.
--
-- Different from Permits:
--   Permits: Regulatory authorizations for specific operations with ongoing
--            monitoring, reporting, and limit compliance requirements
--   Licenses: Authorizations to operate or practice, primarily renewal-focused
--            with less ongoing compliance tracking
--
-- Examples:
--   Business: Business license, fire department permits, occupancy permits
--   Professional: PE, CIH, CSP, ASP certifications
--   Operator: Wastewater operator, boiler operator, crane operator
--   Equipment: Boiler/pressure vessel registrations, elevator permits
--
-- Connects to:
--   - establishments (001_incidents.sql)
--   - employees (001_incidents.sql) - for professional/operator licenses
--   - training (003_training.sql) - licenses may require training

-- ============================================================================
-- LICENSE TYPES
-- ============================================================================
-- Categories of licenses with their typical characteristics.

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

-- Seed common license types
INSERT OR IGNORE INTO license_types 
    (id, type_code, type_name, category, holder_type, typical_term_years, 
     requires_exam, requires_continuing_education, ce_hours_required, ce_period_years,
     issuing_authority_type, renewal_lead_time_days) VALUES
    
    -- Business Licenses
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
        
    -- Professional Certifications
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
        
    -- Operator Licenses
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
        
    -- Equipment Registrations
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
-- ISSUING AUTHORITIES
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
-- Individual license records. Can be held by establishment, employee, or equipment.

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
-- CONTINUING EDUCATION RECORDS
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
-- EXAMPLE QUERIES
-- ============================================================================
/*
-- 1. Get all licenses expiring in next 90 days
SELECT * FROM v_licenses_expiring 
WHERE days_until_expiration <= 90
ORDER BY expiration_date;

-- 2. Check CE status for all licenses
SELECT * FROM v_license_ce_status
WHERE ce_status IN ('BEHIND', 'PERIOD_ENDED');

-- 3. Get all licenses for a specific employee
SELECT * FROM v_employee_licenses
WHERE employee_id = 5;

-- 4. License summary by establishment
SELECT * FROM v_license_summary;

-- 5. Add a continuing education record
INSERT INTO license_continuing_education 
    (license_id, activity_date, activity_name, provider_name, ce_hours, ce_type)
VALUES 
    (1, '2025-11-15', 'Annual Environmental Law Update', 'State DEQ', 4.0, 'technical');
-- Note: Trigger will automatically update ce_hours_completed on the license

-- 6. Find employees with expired or expiring operator licenses
SELECT 
    employee_name,
    license_type,
    license_class,
    expiration_date,
    license_status
FROM v_employee_licenses
WHERE category = 'operator'
  AND license_status IN ('EXPIRED', 'EXPIRES_SOON');

-- 7. Get all wastewater operators and their license classes
SELECT 
    emp.first_name || ' ' || emp.last_name AS operator_name,
    l.license_number,
    l.license_class,
    l.expiration_date,
    l.ce_hours_completed || ' / ' || l.ce_hours_required AS ce_progress
FROM licenses l
INNER JOIN license_types lt ON l.license_type_id = lt.id
INNER JOIN employees emp ON l.holder_employee_id = emp.id
WHERE lt.type_code = 'WASTEWATER_OP'
  AND l.status = 'active';

-- 8. Record a license renewal
INSERT INTO license_renewal_history 
    (license_id, renewal_period_start, renewal_period_end, application_date,
     application_fee, ce_hours_submitted, renewal_date, new_expiration_date, status)
VALUES 
    (1, '2022-12-01', '2025-11-30', '2025-10-15',
     150.00, 30, '2025-11-20', '2028-11-30', 'approved');

-- Update the license with new dates
UPDATE licenses
SET current_issue_date = '2025-11-20',
    expiration_date = '2028-11-30',
    last_renewal_date = '2025-11-20',
    renewal_status = 'current',
    ce_period_start = '2025-12-01',
    ce_period_end = '2028-11-30',
    ce_hours_completed = 0
WHERE id = 1;

-- 9. Business licenses due for renewal
SELECT 
    license_number,
    license_name,
    expiration_date,
    days_until_expiration,
    urgency
FROM v_licenses_expiring
WHERE category = 'business';

-- 10. Compliance calendar integration - get all license renewals
SELECT 
    l.establishment_id,
    lt.type_name || ' - ' || l.license_number AS event_name,
    'license_renewal' AS event_type,
    date(l.expiration_date, '-' || lt.renewal_lead_time_days || ' days') AS due_date,
    l.holder_employee_id AS responsible_person_id
FROM licenses l
INNER JOIN license_types lt ON l.license_type_id = lt.id
WHERE l.status = 'active'
  AND l.expiration_date IS NOT NULL;
*/


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
LICENSES MODULE (006a_licenses.sql)

PURPOSE:
Tracks business licenses, professional certifications, and operator licenses
that are distinct from environmental/operational permits.

DISTINCTION FROM PERMITS:
- Permits: Operations-focused with ongoing monitoring, reporting, limits
- Licenses: Authorization-focused with renewal tracking and CE requirements

TABLES:
  Reference:
    - license_types: Categories of licenses with characteristics
    - license_issuing_authorities: Bodies that issue licenses
    
  Core:
    - licenses: Master license record (establishment, employee, or equipment holder)
    - license_continuing_education: CE credit tracking
    - license_renewal_history: Historical renewal records

VIEWS:
    - v_licenses_expiring: Licenses approaching expiration
    - v_license_ce_status: CE progress for licenses requiring it
    - v_employee_licenses: All licenses held by employees
    - v_license_summary: Summary counts by establishment

TRIGGERS:
    - trg_license_ce_add: Auto-update CE hours on CE record insert
    - trg_license_ce_delete: Auto-update CE hours on CE record delete

PRE-SEEDED LICENSE TYPES (24 types):

  Business (5):
    - BUSINESS, FIRE_PERMIT, OCCUPANCY, ZONING, SALES_TAX
    
  Professional (7):
    - PE (Professional Engineer)
    - CIH (Certified Industrial Hygienist)
    - CSP (Certified Safety Professional)
    - ASP (Associate Safety Professional)
    - CHMM (Certified Hazardous Materials Manager)
    - QEP (Qualified Environmental Professional)
    - REM (Registered Environmental Manager)
    
  Operator (7):
    - WASTEWATER_OP, WATER_OP, BOILER_OP
    - CRANE_OP (NCCCO), FORKLIFT_TRAINER
    - CDL, HAZMAT_CDL
    
  Equipment (6):
    - BOILER_REG, PRESSURE_VESSEL, ELEVATOR
    - UST, AST, SCALE

KEY FEATURES:
  1. Three holder types: establishment, employee, equipment
  2. Continuing education tracking with auto-calculation
  3. License class/level tracking (for tiered licenses)
  4. Renewal history preservation
  5. Integration point with training module
  6. Expiration alerting via views

INTEGRATION POINTS:
  - employees: Professional/operator licenses linked to employees
  - training: CE activities may link to training completions
  - compliance_calendar: License renewals feed into master calendar
*/
