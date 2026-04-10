-- Waypoint-EHS - SARA 313 / Toxic Release Inventory (TRI) Schema
-- Extension to 002_chemicals.sql for EPA TRI reporting
--
-- Regulatory Reference:
--   EPCRA Section 313 - Toxic Release Inventory (TRI)
--   Form R  - Full reporting form
--   Form A  - Certification for limited annual reportable amounts
--
-- Applicability (ALL must be met):
--   1. Facility has 10+ full-time equivalent employees
--   2. Facility is in a covered NAICS code (manufacturing, mining, utilities, etc.)
--   3. Facility manufactures, processes, or otherwise uses a listed chemical
--      above threshold quantities:
--        - 25,000 lbs/year manufactured or processed
--        - 10,000 lbs/year otherwise used
--        - Lower thresholds for PBT chemicals (varies by chemical)
--
-- Key Concepts:
--   - "Manufacture" = produce, prepare, import, or compound
--   - "Process" = incorporate into a product, prepare for distribution
--   - "Otherwise Use" = any use not manufacture or process (cleaning, maintenance, etc.)

-- ============================================================================
-- SARA 313 CHEMICAL LIST (Reference Table)
-- ============================================================================
-- EPA's list of TRI-reportable chemicals. Updated annually.
-- This supplements the chemicals table - links via CAS number.

CREATE TABLE IF NOT EXISTS sara313_chemicals (
    cas_number TEXT PRIMARY KEY,
    chemical_name TEXT NOT NULL,
    
    -- Chemical category (some are reported by category, not individual CAS)
    category_code TEXT,                     -- e.g., 'N096' for Nickel Compounds
    category_name TEXT,
    
    -- Thresholds (lbs/year)
    manufacture_threshold REAL DEFAULT 25000,
    process_threshold REAL DEFAULT 25000,
    otherwise_use_threshold REAL DEFAULT 10000,
    
    -- PBT (Persistent Bioaccumulative Toxic) flags - lower thresholds
    is_pbt INTEGER DEFAULT 0,
    pbt_threshold REAL,                     -- Some PBTs have thresholds as low as 0.1 grams
    
    -- De minimis concentration (below this %, doesn't count toward threshold)
    deminimis_percent REAL DEFAULT 1.0,     -- Usually 1%, but 0.1% for carcinogens/PBTs
    
    -- Metal compound flag (affects how releases are calculated)
    is_metal_compound INTEGER DEFAULT 0,
    parent_metal TEXT,                      -- e.g., 'Nickel' for nickel compounds
    
    -- Effective dates (chemicals get added/removed)
    effective_date TEXT,
    delisted_date TEXT,
    
    notes TEXT
);

CREATE INDEX idx_sara313_chemicals_category ON sara313_chemicals(category_code);
CREATE INDEX idx_sara313_chemicals_pbt ON sara313_chemicals(is_pbt) WHERE is_pbt = 1;

-- ============================================================================
-- Common SARA 313 Chemicals (Manufacturing Focus)
-- ============================================================================
-- Subset of commonly encountered chemicals in manufacturing.
-- Full EPA list has 700+ chemicals - user can import complete list.

INSERT OR IGNORE INTO sara313_chemicals 
    (cas_number, chemical_name, category_code, category_name, deminimis_percent, is_metal_compound, parent_metal) VALUES
    -- Metals and Metal Compounds (common in plating, coating)
    ('7440-47-3', 'Chromium', NULL, NULL, 1.0, 0, NULL),
    ('N090', 'Chromium Compounds', 'N090', 'Chromium Compounds', 0.1, 1, 'Chromium'),
    ('7440-02-0', 'Nickel', NULL, NULL, 0.1, 0, NULL),
    ('N096', 'Nickel Compounds', 'N096', 'Nickel Compounds', 0.1, 1, 'Nickel'),
    ('7440-66-6', 'Zinc', NULL, NULL, 1.0, 0, NULL),
    ('N982', 'Zinc Compounds', 'N982', 'Zinc Compounds', 1.0, 1, 'Zinc'),
    ('7439-92-1', 'Lead', NULL, NULL, 0.1, 0, NULL),
    ('N420', 'Lead Compounds', 'N420', 'Lead Compounds', 0.1, 1, 'Lead'),
    ('7440-43-9', 'Cadmium', NULL, NULL, 0.1, 0, NULL),
    ('N078', 'Cadmium Compounds', 'N078', 'Cadmium Compounds', 0.1, 1, 'Cadmium'),
    ('7440-50-8', 'Copper', NULL, NULL, 1.0, 0, NULL),
    ('N084', 'Copper Compounds', 'N084', 'Copper Compounds', 1.0, 1, 'Copper'),
    
    -- Solvents (common in coating, cleaning, degreasing)
    ('67-64-1', 'Acetone', NULL, NULL, 1.0, 0, NULL),
    ('78-93-3', 'Methyl ethyl ketone (MEK)', NULL, NULL, 1.0, 0, NULL),
    ('108-88-3', 'Toluene', NULL, NULL, 1.0, 0, NULL),
    ('1330-20-7', 'Xylene (mixed isomers)', NULL, NULL, 1.0, 0, NULL),
    ('111-76-2', 'Ethylene glycol monobutyl ether', NULL, NULL, 1.0, 0, NULL),
    ('79-01-6', 'Trichloroethylene', NULL, NULL, 0.1, 0, NULL),
    ('127-18-4', 'Tetrachloroethylene (Perc)', NULL, NULL, 0.1, 0, NULL),
    ('71-43-2', 'Benzene', NULL, NULL, 0.1, 0, NULL),
    ('100-41-4', 'Ethylbenzene', NULL, NULL, 0.1, 0, NULL),
    
    -- Acids (plating, cleaning, etching)
    ('7647-01-0', 'Hydrochloric acid', NULL, NULL, 1.0, 0, NULL),
    ('7664-93-9', 'Sulfuric acid', NULL, NULL, 1.0, 0, NULL),
    ('7697-37-2', 'Nitric acid', NULL, NULL, 1.0, 0, NULL),
    ('7664-38-2', 'Phosphoric acid', NULL, NULL, 1.0, 0, NULL),
    ('7664-39-3', 'Hydrogen fluoride', NULL, NULL, 1.0, 0, NULL),
    
    -- Other common manufacturing chemicals
    ('50-00-0', 'Formaldehyde', NULL, NULL, 0.1, 0, NULL),
    ('7722-84-1', 'Hydrogen peroxide', NULL, NULL, 1.0, 0, NULL),
    ('7681-52-9', 'Sodium hypochlorite', NULL, NULL, 1.0, 0, NULL),
    ('107-21-1', 'Ethylene glycol', NULL, NULL, 1.0, 0, NULL),
    ('75-09-2', 'Dichloromethane (Methylene chloride)', NULL, NULL, 0.1, 0, NULL);

-- Set carcinogen-level de minimis for applicable chemicals
UPDATE sara313_chemicals SET deminimis_percent = 0.1 
WHERE cas_number IN ('71-43-2', '50-00-0', '79-01-6', '127-18-4', '100-41-4', '75-09-2');


-- ============================================================================
-- TRI ACTIVITY TRACKING (Annual Usage Tracking)
-- ============================================================================
-- Tracks how chemicals are manufactured, processed, or otherwise used.
-- This determines if threshold is exceeded and how to report.

CREATE TABLE IF NOT EXISTS tri_annual_activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,           -- Links to chemicals table
    report_year INTEGER NOT NULL,
    
    -- Which SARA 313 chemical this maps to (for category reporting)
    sara313_cas TEXT,                       -- CAS or category code
    
    -- ========== ACTIVITY TYPE QUANTITIES (lbs/year) ==========
    -- These determine which threshold applies
    
    quantity_manufactured REAL DEFAULT 0,   -- Produced, prepared, imported
    quantity_processed REAL DEFAULT 0,      -- Incorporated into product
    quantity_otherwise_used REAL DEFAULT 0, -- Cleaning, maintenance, etc.
    
    -- Total = sum of above, but stored for quick queries
    quantity_total REAL DEFAULT 0,
    
    -- ========== THRESHOLD DETERMINATION ==========
    
    applicable_threshold REAL,              -- Which threshold applies
    is_above_threshold INTEGER DEFAULT 0,   -- Does this require Form R?
    qualifies_form_a INTEGER DEFAULT 0,     -- Can use simplified Form A?
    
    -- Form A eligibility: <500 lbs total annual reportable amount 
    -- AND no releases to water AND meets other criteria
    
    -- ========== DATA SOURCES ==========
    -- How were these quantities determined?
    
    data_source TEXT,                       -- 'inventory_calc', 'mass_balance', 'engineering_estimate', 'direct_measurement'
    calculation_notes TEXT,                 -- How the numbers were derived
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id),
    UNIQUE(establishment_id, chemical_id, report_year)
);

CREATE INDEX idx_tri_annual_activity_establishment ON tri_annual_activity(establishment_id);
CREATE INDEX idx_tri_annual_activity_year ON tri_annual_activity(report_year);
CREATE INDEX idx_tri_annual_activity_above ON tri_annual_activity(is_above_threshold) WHERE is_above_threshold = 1;

-- ============================================================================
-- TRI RELEASE & TRANSFER DATA (Form R Sections 5 & 6)
-- ============================================================================
-- Captures where the chemical went - releases to environment and off-site transfers.

CREATE TABLE IF NOT EXISTS tri_releases_transfers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tri_activity_id INTEGER NOT NULL,       -- Links to tri_annual_activity
    
    -- ========== ON-SITE RELEASES (Form R Section 5.1-5.4) ==========
    -- All quantities in lbs/year
    
    -- Fugitive Air (non-point source - evaporation, leaks, etc.)
    fugitive_air_lbs REAL DEFAULT 0,
    fugitive_air_basis TEXT,                -- Emission factor, mass balance, monitoring, etc.
    
    -- Stack/Point Air (from stacks, vents)
    stack_air_lbs REAL DEFAULT 0,
    stack_air_basis TEXT,
    
    -- Water Discharges
    discharge_to_potw_lbs REAL DEFAULT 0,   -- To publicly owned treatment works
    potw_name TEXT,
    discharge_to_water_lbs REAL DEFAULT 0,  -- Direct to surface water (permitted)
    receiving_water_name TEXT,
    
    -- Land Disposal (on-site)
    land_disposal_lbs REAL DEFAULT 0,
    land_disposal_method TEXT,              -- Landfill, land treatment, surface impoundment, etc.
    
    -- Underground Injection
    underground_injection_lbs REAL DEFAULT 0,
    uic_well_code TEXT,                     -- Underground Injection Control well ID
    
    -- ========== OFF-SITE TRANSFERS (Form R Section 6) ==========
    -- Quantities sent to off-site facilities
    
    -- Transfers to POTWs (if not direct discharge)
    transfer_potw_lbs REAL DEFAULT 0,
    transfer_potw_name TEXT,
    transfer_potw_address TEXT,
    
    -- Disposal transfers
    transfer_disposal_lbs REAL DEFAULT 0,
    
    -- Recycling transfers
    transfer_recycling_lbs REAL DEFAULT 0,
    
    -- Energy recovery transfers
    transfer_energy_recovery_lbs REAL DEFAULT 0,
    
    -- Treatment transfers
    transfer_treatment_lbs REAL DEFAULT 0,
    
    -- ========== WASTE MANAGEMENT (Form R Section 8) ==========
    
    total_waste_managed_lbs REAL DEFAULT 0,
    recycled_onsite_lbs REAL DEFAULT 0,
    recycled_offsite_lbs REAL DEFAULT 0,
    energy_recovery_onsite_lbs REAL DEFAULT 0,
    energy_recovery_offsite_lbs REAL DEFAULT 0,
    treated_onsite_lbs REAL DEFAULT 0,
    treated_offsite_lbs REAL DEFAULT 0,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (tri_activity_id) REFERENCES tri_annual_activity(id) ON DELETE CASCADE
);

CREATE INDEX idx_tri_releases_activity ON tri_releases_transfers(tri_activity_id);

-- ============================================================================
-- TRI OFF-SITE FACILITIES (Receiving Facilities)
-- ============================================================================
-- Track facilities that receive your waste/recycling for TRI reporting.

CREATE TABLE IF NOT EXISTS tri_offsite_facilities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    
    facility_name TEXT NOT NULL,
    street_address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    country TEXT DEFAULT 'US',
    
    -- EPA IDs
    rcra_id TEXT,                           -- RCRA generator/TSDF ID
    trifid TEXT,                            -- TRI Facility ID (if they report)
    
    -- What they do with your waste
    facility_type TEXT,                     -- potw, recycler, disposal, treatment, energy_recovery
    accepts_chemical_types TEXT,            -- What types of waste they accept
    
    -- Contact
    contact_name TEXT,
    contact_phone TEXT,
    
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_tri_offsite_facilities_establishment ON tri_offsite_facilities(establishment_id);


-- ============================================================================
-- TRI TRANSFER DETAILS (Links Transfers to Receiving Facilities)
-- ============================================================================
-- Detail records for each off-site transfer to a specific facility.

CREATE TABLE IF NOT EXISTS tri_transfer_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tri_releases_id INTEGER NOT NULL,       -- Links to tri_releases_transfers
    offsite_facility_id INTEGER NOT NULL,   -- Links to tri_offsite_facilities
    
    transfer_type TEXT NOT NULL,            -- disposal, recycling, energy_recovery, treatment
    quantity_lbs REAL NOT NULL,
    
    -- Waste codes (if applicable)
    rcra_waste_codes TEXT,                  -- Comma-separated RCRA codes
    
    -- Treatment method codes (Form R uses EPA codes)
    treatment_method TEXT,
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (tri_releases_id) REFERENCES tri_releases_transfers(id) ON DELETE CASCADE,
    FOREIGN KEY (offsite_facility_id) REFERENCES tri_offsite_facilities(id)
);

CREATE INDEX idx_tri_transfer_details_release ON tri_transfer_details(tri_releases_id);
CREATE INDEX idx_tri_transfer_details_facility ON tri_transfer_details(offsite_facility_id);

-- ============================================================================
-- TRI FORM R REPORTS (Submitted Reports)
-- ============================================================================
-- Stores submitted Form R/Form A reports for historical reference.

CREATE TABLE IF NOT EXISTS tri_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    report_year INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,
    sara313_cas TEXT NOT NULL,              -- CAS or category code reported
    
    -- Form Type
    form_type TEXT NOT NULL,                -- 'R' or 'A'
    
    -- Report Status
    status TEXT DEFAULT 'draft',            -- draft, submitted, accepted, revised, withdrawn
    
    -- Submission Info (due July 1 each year)
    submitted_date TEXT,
    trifid TEXT,                            -- TRI Facility ID
    submission_method TEXT,                 -- 'triMEweb', 'paper', 'cdx'
    confirmation_number TEXT,
    
    -- Trade Secret (Section 1.3)
    is_trade_secret INTEGER DEFAULT 0,
    trade_secret_category TEXT,
    
    -- Certification (Section 1.2)
    certified_by TEXT,
    certified_title TEXT,
    certified_date TEXT,
    certifier_email TEXT,
    certifier_phone TEXT,
    
    -- Revision info (if this is a revision)
    is_revision INTEGER DEFAULT 0,
    revision_number INTEGER,
    original_report_id INTEGER,
    revision_reason TEXT,
    
    -- Store snapshot of key values at time of submission
    total_releases_lbs REAL,
    total_transfers_lbs REAL,
    max_onsite_lbs REAL,
    
    notes TEXT,
    
    generated_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id),
    FOREIGN KEY (original_report_id) REFERENCES tri_reports(id)
);

CREATE INDEX idx_tri_reports_establishment ON tri_reports(establishment_id);
CREATE INDEX idx_tri_reports_year ON tri_reports(report_year);
CREATE INDEX idx_tri_reports_status ON tri_reports(status);

-- ============================================================================
-- SOURCE REDUCTION ACTIVITIES (Form R Section 8.10)
-- ============================================================================
-- EPA wants to know what you're doing to reduce releases.

CREATE TABLE IF NOT EXISTS tri_source_reduction (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tri_activity_id INTEGER NOT NULL,
    
    -- Source Reduction Activity Code (EPA W codes)
    activity_code TEXT NOT NULL,            -- W01-W89 codes
    activity_description TEXT,
    
    -- Implementation
    implementation_year INTEGER,
    implementation_status TEXT,             -- implemented, in_progress, planned
    
    -- Estimated reduction
    estimated_reduction_lbs REAL,
    estimated_reduction_percent REAL,
    
    -- Method used for estimate
    estimation_method TEXT,
    
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (tri_activity_id) REFERENCES tri_annual_activity(id) ON DELETE CASCADE
);

CREATE INDEX idx_tri_source_reduction_activity ON tri_source_reduction(tri_activity_id);

-- ============================================================================
-- TRI SOURCE REDUCTION CODES (Reference Table)
-- ============================================================================
-- EPA's standard codes for source reduction activities.

CREATE TABLE IF NOT EXISTS tri_source_reduction_codes (
    code TEXT PRIMARY KEY,
    category TEXT NOT NULL,
    description TEXT NOT NULL
);

INSERT OR IGNORE INTO tri_source_reduction_codes (code, category, description) VALUES
    -- Good Operating Practices
    ('W13', 'Good Operating Practices', 'Improved maintenance scheduling, recordkeeping, or procedures'),
    ('W14', 'Good Operating Practices', 'Changed production schedule to minimize equipment and feedstock changeovers'),
    ('W19', 'Good Operating Practices', 'Other changes in operating practices'),
    
    -- Inventory Control
    ('W21', 'Inventory Control', 'Instituted procedures to ensure that materials do not stay in inventory beyond shelf-life'),
    ('W22', 'Inventory Control', 'Began to test outdated material - Loss of unverified material'),
    ('W24', 'Inventory Control', 'Reduced the size of containers or of transfer vehicles'),
    ('W28', 'Inventory Control', 'Instituted better labeling procedures'),
    ('W29', 'Inventory Control', 'Other changes in inventory control'),
    
    -- Spill and Leak Prevention
    ('W31', 'Spill and Leak Prevention', 'Improved storage or stacking procedures'),
    ('W32', 'Spill and Leak Prevention', 'Improved procedures for loading, unloading, and transfer operations'),
    ('W35', 'Spill and Leak Prevention', 'Installed spill or overflow alarms'),
    ('W36', 'Spill and Leak Prevention', 'Installed vapor recovery systems'),
    ('W38', 'Spill and Leak Prevention', 'Installed secondary containment'),
    ('W39', 'Spill and Leak Prevention', 'Other changes in spill or leak prevention'),
    
    -- Raw Material Modifications
    ('W41', 'Raw Material Modifications', 'Increased the purity of raw materials'),
    ('W42', 'Raw Material Modifications', 'Substituted a less toxic raw material'),
    ('W44', 'Raw Material Modifications', 'Other raw material modifications'),
    
    -- Process Modifications
    ('W51', 'Process Modifications', 'Instituted recirculation within a process'),
    ('W52', 'Process Modifications', 'Modified equipment, layout, or piping'),
    ('W53', 'Process Modifications', 'Changed process catalyst'),
    ('W54', 'Process Modifications', 'Instituted better controls on operating bulk containers'),
    ('W55', 'Process Modifications', 'Changed from small volume containers to bulk containers'),
    ('W58', 'Process Modifications', 'Other process modifications'),
    
    -- Cleaning and Degreasing
    ('W59', 'Cleaning and Degreasing', 'Modified stripping/cleaning equipment'),
    ('W60', 'Cleaning and Degreasing', 'Changed to mechanical stripping/cleaning devices'),
    ('W61', 'Cleaning and Degreasing', 'Changed to aqueous cleaners'),
    ('W62', 'Cleaning and Degreasing', 'Changed to less hazardous cleaners'),
    ('W63', 'Cleaning and Degreasing', 'Reduced the number of solvents used'),
    
    -- Surface Preparation and Finishing
    ('W64', 'Surface Preparation and Finishing', 'Modified spray equipment or spray practices'),
    ('W65', 'Surface Preparation and Finishing', 'Changed paint/coating or ink formulation'),
    ('W66', 'Surface Preparation and Finishing', 'Improved application techniques'),
    
    -- Product Modifications
    ('W71', 'Product Modifications', 'Changed product specifications'),
    ('W72', 'Product Modifications', 'Modified design or composition of product'),
    ('W73', 'Product Modifications', 'Modified packaging'),
    ('W79', 'Product Modifications', 'Other product modifications');


-- ============================================================================
-- VIEWS FOR TRI REPORTING
-- ============================================================================

-- Chemicals potentially requiring TRI reporting (above any threshold)
CREATE VIEW IF NOT EXISTS v_tri_reportable_chemicals AS
SELECT 
    c.id AS chemical_id,
    c.product_name,
    c.primary_cas_number,
    c.establishment_id,
    s.chemical_name AS sara313_name,
    s.category_code,
    s.category_name,
    s.manufacture_threshold,
    s.process_threshold,
    s.otherwise_use_threshold,
    s.deminimis_percent,
    s.is_pbt,
    ta.report_year,
    ta.quantity_manufactured,
    ta.quantity_processed,
    ta.quantity_otherwise_used,
    ta.quantity_total,
    ta.is_above_threshold,
    CASE 
        WHEN ta.quantity_manufactured > 0 OR ta.quantity_processed > 0 THEN s.manufacture_threshold
        ELSE s.otherwise_use_threshold
    END AS applicable_threshold
FROM chemicals c
INNER JOIN sara313_chemicals s ON c.primary_cas_number = s.cas_number 
    OR c.primary_cas_number = s.category_code
LEFT JOIN tri_annual_activity ta ON c.id = ta.chemical_id
WHERE c.is_sara_313 = 1
  AND c.is_active = 1;

-- TRI reporting summary by year
CREATE VIEW IF NOT EXISTS v_tri_annual_summary AS
SELECT 
    e.id AS establishment_id,
    e.name AS establishment_name,
    ta.report_year,
    COUNT(DISTINCT ta.chemical_id) AS chemicals_tracked,
    SUM(CASE WHEN ta.is_above_threshold = 1 THEN 1 ELSE 0 END) AS chemicals_reportable,
    SUM(ta.quantity_total) AS total_quantity_lbs,
    SUM(rt.fugitive_air_lbs + rt.stack_air_lbs) AS total_air_releases,
    SUM(rt.discharge_to_potw_lbs + rt.discharge_to_water_lbs) AS total_water_releases,
    SUM(rt.land_disposal_lbs) AS total_land_releases,
    SUM(rt.transfer_disposal_lbs + rt.transfer_recycling_lbs + 
        rt.transfer_energy_recovery_lbs + rt.transfer_treatment_lbs) AS total_offsite_transfers
FROM establishments e
LEFT JOIN tri_annual_activity ta ON e.id = ta.establishment_id
LEFT JOIN tri_releases_transfers rt ON ta.id = rt.tri_activity_id
GROUP BY e.id, ta.report_year;

-- Pending TRI reports (above threshold but not yet submitted)
CREATE VIEW IF NOT EXISTS v_tri_pending_reports AS
SELECT 
    ta.establishment_id,
    ta.report_year,
    c.id AS chemical_id,
    c.product_name,
    c.primary_cas_number,
    ta.quantity_total,
    ta.applicable_threshold,
    ta.qualifies_form_a,
    tr.status AS report_status,
    tr.submitted_date
FROM tri_annual_activity ta
INNER JOIN chemicals c ON ta.chemical_id = c.id
LEFT JOIN tri_reports tr ON ta.establishment_id = tr.establishment_id 
    AND ta.report_year = tr.report_year 
    AND ta.chemical_id = tr.chemical_id
WHERE ta.is_above_threshold = 1
  AND (tr.id IS NULL OR tr.status = 'draft');

-- ============================================================================
-- REGULATORY REQUIREMENTS (Bridge Table)
-- ============================================================================
-- Links regulatory sources to their requirements.
-- This bridges chemicals, training, inspections, permits, etc.
--
-- Key concept: A requirement can be triggered by:
--   - Presence of a chemical (e.g., HazCom training)
--   - A hazard class (e.g., flammable storage inspection)
--   - An activity (e.g., forklift operation)
--   - A regulatory threshold (e.g., SPCC plan for oil storage)

CREATE TABLE IF NOT EXISTS regulatory_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Source identification
    agency TEXT NOT NULL,                   -- OSHA, EPA, DOT, State, Local
    regulation_code TEXT NOT NULL,          -- e.g., '29 CFR 1910.1200', 'EPCRA 312'
    regulation_name TEXT NOT NULL,          -- Human-readable name
    
    -- Source document
    document_url TEXT,                      -- Link to regulation text
    summary TEXT,                           -- Brief description
    
    -- Applicability
    applies_to_naics TEXT,                  -- Comma-separated NAICS codes (NULL = all)
    applies_to_sic TEXT,                    -- Legacy SIC codes
    employee_threshold INTEGER,             -- Minimum employees (NULL = any)
    
    is_active INTEGER DEFAULT 1,
    effective_date TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_regulatory_sources_agency ON regulatory_sources(agency);
CREATE INDEX idx_regulatory_sources_code ON regulatory_sources(regulation_code);


-- ============================================================================
-- REGULATORY REQUIREMENTS
-- ============================================================================
-- Specific requirements from each regulatory source.

CREATE TABLE IF NOT EXISTS regulatory_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id INTEGER NOT NULL,
    
    -- Requirement identification
    requirement_code TEXT,                  -- Internal reference code
    requirement_name TEXT NOT NULL,
    requirement_type TEXT NOT NULL,         -- training, inspection, permit, record, report, plan
    
    -- Description
    description TEXT,
    citation TEXT,                          -- Specific section (e.g., '1910.1200(h)(1)')
    
    -- Frequency (for recurring requirements)
    frequency TEXT,                         -- initial, annual, quarterly, monthly, per_incident, as_needed
    frequency_days INTEGER,                 -- For custom intervals
    
    -- Timing
    due_within_days INTEGER,                -- Days to complete after trigger (e.g., 30 days for new hire training)
    advance_notice_days INTEGER,            -- Days before due date to alert
    
    -- Documentation requirements
    documentation_required TEXT,            -- What records to keep
    retention_years INTEGER,                -- How long to keep records
    
    is_active INTEGER DEFAULT 1,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (source_id) REFERENCES regulatory_sources(id)
);

CREATE INDEX idx_regulatory_requirements_source ON regulatory_requirements(source_id);
CREATE INDEX idx_regulatory_requirements_type ON regulatory_requirements(requirement_type);

-- ============================================================================
-- REQUIREMENT TRIGGERS (What activates a requirement)
-- ============================================================================
-- Links requirements to their activation conditions.

CREATE TABLE IF NOT EXISTS requirement_triggers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    requirement_id INTEGER NOT NULL,
    
    -- Trigger type
    trigger_type TEXT NOT NULL,             -- chemical_hazard, chemical_specific, activity, threshold, all_employees
    
    -- Chemical-based triggers
    hazard_flag TEXT,                       -- Column name from chemicals table (e.g., 'is_flammable')
    chemical_id INTEGER,                    -- Specific chemical (for chemical_specific type)
    cas_number TEXT,                        -- Or by CAS number
    
    -- Threshold-based triggers
    threshold_field TEXT,                   -- What to measure (e.g., 'quantity_lbs')
    threshold_value REAL,                   -- Trigger point
    threshold_operator TEXT,                -- '>=', '>', '=', etc.
    
    -- Activity-based triggers
    activity_code TEXT,                     -- Links to activities table (future)
    job_role TEXT,                          -- Job title/role that requires this
    
    -- Condition description (human readable)
    condition_description TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (requirement_id) REFERENCES regulatory_requirements(id) ON DELETE CASCADE,
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id)
);

CREATE INDEX idx_requirement_triggers_requirement ON requirement_triggers(requirement_id);
CREATE INDEX idx_requirement_triggers_hazard ON requirement_triggers(hazard_flag);
CREATE INDEX idx_requirement_triggers_chemical ON requirement_triggers(chemical_id);

-- ============================================================================
-- SEED DATA: Common Regulatory Sources
-- ============================================================================

INSERT OR IGNORE INTO regulatory_sources (id, agency, regulation_code, regulation_name, summary) VALUES
    -- OSHA General Industry
    (1, 'OSHA', '29 CFR 1910.1200', 'Hazard Communication (HazCom)', 
        'Requires employers to inform employees about chemical hazards through labels, SDSs, and training'),
    (2, 'OSHA', '29 CFR 1910.134', 'Respiratory Protection', 
        'Requirements for respirator use, fit testing, and medical evaluations'),
    (3, 'OSHA', '29 CFR 1910.132', 'Personal Protective Equipment', 
        'General requirements for PPE assessment, selection, and training'),
    (4, 'OSHA', '29 CFR 1910.147', 'Control of Hazardous Energy (Lockout/Tagout)', 
        'Procedures to prevent unexpected energization during maintenance'),
    (5, 'OSHA', '29 CFR 1910.178', 'Powered Industrial Trucks', 
        'Forklift operator training and certification requirements'),
    (6, 'OSHA', '29 CFR 1910.38', 'Emergency Action Plans', 
        'Requirements for emergency plans and employee training'),
    (7, 'OSHA', '29 CFR 1910.157', 'Portable Fire Extinguishers', 
        'Fire extinguisher placement, maintenance, and training'),
    (8, 'OSHA', '29 CFR 1910.151', 'Medical Services and First Aid', 
        'First aid training and supplies requirements'),
    
    -- EPA
    (10, 'EPA', 'EPCRA 311/312', 'Tier II Reporting', 
        'Annual hazardous chemical inventory reporting to local agencies'),
    (11, 'EPA', 'EPCRA 313', 'Toxic Release Inventory (TRI)', 
        'Annual reporting of releases and transfers of toxic chemicals'),
    (12, 'EPA', '40 CFR 112', 'SPCC - Spill Prevention Control and Countermeasure', 
        'Oil spill prevention plan for facilities with oil storage'),
    (13, 'EPA', '40 CFR 262', 'RCRA Hazardous Waste Generator', 
        'Requirements for generating, storing, and disposing of hazardous waste'),
    (14, 'EPA', '40 CFR 68', 'Risk Management Program (RMP)', 
        'Process safety requirements for extremely hazardous substances'),
    
    -- DOT
    (20, 'DOT', '49 CFR 172', 'Hazardous Materials Training', 
        'Training for employees who handle hazardous materials in transport');


-- ============================================================================
-- SEED DATA: Common Regulatory Requirements
-- ============================================================================

-- HazCom Requirements (triggered by presence of hazardous chemicals)
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (1, 1, 'HAZCOM-TRAIN-INIT', 'HazCom Initial Training', 'training',
        'Initial training on hazardous chemicals in the work area', '1910.1200(h)(1)', 'initial', 30, 3),
    (2, 1, 'HAZCOM-TRAIN-NEW', 'HazCom New Hazard Training', 'training',
        'Training when new chemical hazards are introduced', '1910.1200(h)(1)', 'as_needed', 7, 3),
    (3, 1, 'HAZCOM-SDS', 'SDS Availability', 'record',
        'Safety Data Sheets must be readily accessible during shifts', '1910.1200(g)(8)', 'as_needed', NULL, 0),
    (4, 1, 'HAZCOM-LABELS', 'Container Labeling', 'inspection',
        'All chemical containers must be properly labeled', '1910.1200(f)', 'as_needed', NULL, 0),
    (5, 1, 'HAZCOM-PROGRAM', 'Written HazCom Program', 'plan',
        'Written hazard communication program', '1910.1200(e)', 'as_needed', NULL, 0);

-- Respiratory Protection Requirements
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (10, 2, 'RESP-FITTEST', 'Respirator Fit Test', 'training',
        'Annual fit testing for tight-fitting respirators', '1910.134(f)', 'annual', 365, 3),
    (11, 2, 'RESP-MEDICAL', 'Respirator Medical Evaluation', 'record',
        'Medical evaluation before respirator use', '1910.134(e)', 'initial', 30, 30),
    (12, 2, 'RESP-TRAIN', 'Respirator Training', 'training',
        'Training on respirator use, limitations, and maintenance', '1910.134(k)', 'annual', 365, 3),
    (13, 2, 'RESP-PROGRAM', 'Written Respiratory Protection Program', 'plan',
        'Written program for respirator use', '1910.134(c)', 'as_needed', NULL, 0);

-- PPE Requirements
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (20, 3, 'PPE-HAZARD-ASSESS', 'PPE Hazard Assessment', 'inspection',
        'Workplace hazard assessment to determine PPE needs', '1910.132(d)(1)', 'as_needed', NULL, 0),
    (21, 3, 'PPE-TRAIN', 'PPE Training', 'training',
        'Training on when and how to use required PPE', '1910.132(f)', 'initial', 30, 3);

-- Lockout/Tagout Requirements
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (30, 4, 'LOTO-TRAIN-AUTH', 'LOTO Authorized Employee Training', 'training',
        'Training for employees who perform lockout/tagout', '1910.147(c)(7)(i)', 'initial', 30, 3),
    (31, 4, 'LOTO-TRAIN-AFF', 'LOTO Affected Employee Training', 'training',
        'Training for employees affected by lockout/tagout', '1910.147(c)(7)(i)', 'initial', 30, 3),
    (32, 4, 'LOTO-INSPECT', 'LOTO Periodic Inspection', 'inspection',
        'Annual inspection of energy control procedures', '1910.147(c)(6)', 'annual', 365, 3),
    (33, 4, 'LOTO-PROGRAM', 'Written LOTO Program', 'plan',
        'Written energy control program', '1910.147(c)(1)', 'as_needed', NULL, 0);

-- Forklift Requirements
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (40, 5, 'FORKLIFT-TRAIN', 'Forklift Operator Training', 'training',
        'Initial training and evaluation for forklift operators', '1910.178(l)(1)', 'initial', 30, 3),
    (41, 5, 'FORKLIFT-EVAL', 'Forklift Operator Evaluation', 'training',
        'Evaluation of operator performance every 3 years', '1910.178(l)(4)(iii)', 'annual', 1095, 3),
    (42, 5, 'FORKLIFT-REFRESH', 'Forklift Refresher Training', 'training',
        'Refresher training after incidents, near misses, or deficiencies', '1910.178(l)(4)(ii)', 'as_needed', 7, 3);

-- Emergency Action Plan Requirements
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (50, 6, 'EAP-TRAIN', 'Emergency Action Plan Training', 'training',
        'Training on emergency procedures and evacuation', '1910.38(e)', 'initial', 30, 3),
    (51, 6, 'EAP-PLAN', 'Written Emergency Action Plan', 'plan',
        'Written emergency action plan', '1910.38(b)', 'as_needed', NULL, 0);

-- Fire Extinguisher Requirements  
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (60, 7, 'FE-TRAIN', 'Fire Extinguisher Training', 'training',
        'Training on fire extinguisher use (if expected to use)', '1910.157(g)(1)', 'annual', 365, 3),
    (61, 7, 'FE-INSPECT-MONTHLY', 'Fire Extinguisher Monthly Inspection', 'inspection',
        'Monthly visual inspection of fire extinguishers', '1910.157(e)(2)', 'monthly', 30, 3),
    (62, 7, 'FE-MAINT-ANNUAL', 'Fire Extinguisher Annual Maintenance', 'inspection',
        'Annual maintenance check by qualified person', '1910.157(e)(3)', 'annual', 365, 3);

-- First Aid Requirements
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (70, 8, 'FIRSTAID-TRAIN', 'First Aid Training', 'training',
        'First aid training for designated responders', '1910.151(b)', 'initial', 30, 3);

-- Tier II Requirements
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (80, 10, 'TIER2-REPORT', 'Tier II Annual Report', 'report',
        'Annual hazardous chemical inventory report', 'EPCRA 312', 'annual', NULL, 3);

-- TRI Requirements
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (90, 11, 'TRI-REPORT', 'TRI Form R Report', 'report',
        'Annual toxic release inventory report', 'EPCRA 313', 'annual', NULL, 3);

-- HazMat Transportation Requirements
INSERT OR IGNORE INTO regulatory_requirements 
    (id, source_id, requirement_code, requirement_name, requirement_type, description, citation, frequency, due_within_days, retention_years) VALUES
    (100, 20, 'HAZMAT-TRAIN-GEN', 'HazMat General Awareness Training', 'training',
        'General awareness training for hazmat employees', '172.704(a)(1)', 'initial', 90, 3),
    (101, 20, 'HAZMAT-TRAIN-FUNC', 'HazMat Function-Specific Training', 'training',
        'Function-specific training for hazmat duties', '172.704(a)(2)', 'initial', 90, 3),
    (102, 20, 'HAZMAT-TRAIN-SEC', 'HazMat Security Awareness Training', 'training',
        'Security awareness training for hazmat employees', '172.704(a)(4)', 'initial', 90, 3),
    (103, 20, 'HAZMAT-RECERT', 'HazMat Training Recertification', 'training',
        'Recurrent hazmat training every 3 years', '172.704(c)(2)', 'annual', 1095, 3);


-- ============================================================================
-- SEED DATA: Requirement Triggers
-- ============================================================================
-- These link requirements to their activation conditions.

-- HazCom triggers (any hazardous chemical)
INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, hazard_flag, condition_description) VALUES
    (1, 'chemical_hazard', 'signal_word', 'Any chemical with a GHS signal word (Danger or Warning)'),
    (2, 'chemical_hazard', 'signal_word', 'Any chemical with a GHS signal word'),
    (3, 'chemical_hazard', 'signal_word', 'Any chemical with a GHS signal word'),
    (4, 'chemical_hazard', 'signal_word', 'Any chemical with a GHS signal word'),
    (5, 'chemical_hazard', 'signal_word', 'Any chemical with a GHS signal word');

-- Respiratory protection triggers (chemicals that could require respirators)
INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, hazard_flag, condition_description) VALUES
    (10, 'chemical_hazard', 'is_acute_toxic', 'Acute inhalation toxicity hazard'),
    (11, 'chemical_hazard', 'is_acute_toxic', 'Acute inhalation toxicity hazard'),
    (12, 'chemical_hazard', 'is_acute_toxic', 'Acute inhalation toxicity hazard'),
    (13, 'chemical_hazard', 'is_acute_toxic', 'Acute inhalation toxicity hazard');

INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, hazard_flag, condition_description) VALUES
    (10, 'chemical_hazard', 'is_respiratory_sensitizer', 'Respiratory sensitizer present'),
    (11, 'chemical_hazard', 'is_respiratory_sensitizer', 'Respiratory sensitizer present'),
    (12, 'chemical_hazard', 'is_respiratory_sensitizer', 'Respiratory sensitizer present'),
    (13, 'chemical_hazard', 'is_respiratory_sensitizer', 'Respiratory sensitizer present');

-- PPE triggers (various hazards)
INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, hazard_flag, condition_description) VALUES
    (20, 'chemical_hazard', 'signal_word', 'Any hazardous chemical present'),
    (21, 'chemical_hazard', 'signal_word', 'Any hazardous chemical present');

-- Tier II trigger (threshold based)
INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, threshold_field, threshold_value, threshold_operator, condition_description) VALUES
    (80, 'threshold', 'quantity_lbs', 10000, '>=', 'Hazardous chemicals at or above 10,000 lbs (or EHS TPQ)');

-- TRI trigger (threshold based)
INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, threshold_field, threshold_value, threshold_operator, condition_description) VALUES
    (90, 'threshold', 'quantity_lbs', 10000, '>=', 'SARA 313 chemicals above threshold');

-- Activity-based triggers (not chemical-dependent)
INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, activity_code, job_role, condition_description) VALUES
    (40, 'activity', 'FORKLIFT_OP', 'Forklift Operator', 'Employee operates powered industrial truck'),
    (41, 'activity', 'FORKLIFT_OP', 'Forklift Operator', 'Employee operates powered industrial truck'),
    (42, 'activity', 'FORKLIFT_OP', 'Forklift Operator', 'After incident or observed deficiency');

INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, activity_code, condition_description) VALUES
    (30, 'activity', 'LOTO_AUTH', 'Employee performs lockout/tagout'),
    (31, 'activity', 'LOTO_AFF', 'Employee works in areas where LOTO is performed'),
    (32, 'activity', 'LOTO_AUTH', 'LOTO procedures in use');

INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, trigger_type, condition_description) VALUES
    (50, 'all_employees', 'all_employees', 'All employees must know emergency procedures'),
    (70, 'activity', 'FIRST_AID', 'Designated first aid responders');

INSERT OR IGNORE INTO requirement_triggers (requirement_id, trigger_type, activity_code, condition_description) VALUES
    (100, 'activity', 'HAZMAT_HANDLER', 'Employee handles hazardous materials for transport'),
    (101, 'activity', 'HAZMAT_HANDLER', 'Employee handles hazardous materials for transport'),
    (102, 'activity', 'HAZMAT_HANDLER', 'Employee handles hazardous materials for transport'),
    (103, 'activity', 'HAZMAT_HANDLER', 'Employee handles hazardous materials for transport');

-- ============================================================================
-- VIEW: Chemical Training Requirements
-- ============================================================================
-- Shows which training requirements apply to each chemical based on its hazards.
-- This is the bridge between chemicals and training modules.

CREATE VIEW IF NOT EXISTS v_chemical_training_requirements AS
SELECT DISTINCT
    c.id AS chemical_id,
    c.product_name,
    c.primary_cas_number,
    c.establishment_id,
    rr.id AS requirement_id,
    rr.requirement_code,
    rr.requirement_name,
    rr.requirement_type,
    rr.frequency,
    rr.due_within_days,
    rs.agency,
    rs.regulation_code,
    rt.condition_description AS trigger_reason
FROM chemicals c
CROSS JOIN regulatory_requirements rr
INNER JOIN requirement_triggers rt ON rr.id = rt.requirement_id
INNER JOIN regulatory_sources rs ON rr.source_id = rs.id
WHERE c.is_active = 1
  AND rr.is_active = 1
  AND rs.is_active = 1
  AND rr.requirement_type = 'training'
  AND (
    -- Match hazard flags
    (rt.trigger_type = 'chemical_hazard' AND (
        (rt.hazard_flag = 'signal_word' AND c.signal_word IS NOT NULL) OR
        (rt.hazard_flag = 'is_flammable' AND c.is_flammable = 1) OR
        (rt.hazard_flag = 'is_oxidizer' AND c.is_oxidizer = 1) OR
        (rt.hazard_flag = 'is_explosive' AND c.is_explosive = 1) OR
        (rt.hazard_flag = 'is_acute_toxic' AND c.is_acute_toxic = 1) OR
        (rt.hazard_flag = 'is_carcinogen' AND c.is_carcinogen = 1) OR
        (rt.hazard_flag = 'is_respiratory_sensitizer' AND c.is_respiratory_sensitizer = 1) OR
        (rt.hazard_flag = 'is_skin_sensitizer' AND c.is_skin_sensitizer = 1) OR
        (rt.hazard_flag = 'is_corrosive_to_metal' AND c.is_corrosive_to_metal = 1) OR
        (rt.hazard_flag = 'is_skin_corrosion' AND c.is_skin_corrosion = 1) OR
        (rt.hazard_flag = 'is_eye_damage' AND c.is_eye_damage = 1)
    ))
    -- Specific chemical match
    OR (rt.trigger_type = 'chemical_specific' AND rt.chemical_id = c.id)
    OR (rt.trigger_type = 'chemical_specific' AND rt.cas_number = c.primary_cas_number)
  )
ORDER BY c.product_name, rs.agency, rr.requirement_name;

-- ============================================================================
-- VIEW: All Requirements by Chemical (not just training)
-- ============================================================================
-- Shows all regulatory requirements triggered by each chemical.

CREATE VIEW IF NOT EXISTS v_chemical_all_requirements AS
SELECT DISTINCT
    c.id AS chemical_id,
    c.product_name,
    c.primary_cas_number,
    c.establishment_id,
    rr.id AS requirement_id,
    rr.requirement_code,
    rr.requirement_name,
    rr.requirement_type,
    rr.description,
    rr.frequency,
    rr.citation,
    rs.agency,
    rs.regulation_code,
    rs.regulation_name,
    rt.condition_description AS trigger_reason
FROM chemicals c
CROSS JOIN regulatory_requirements rr
INNER JOIN requirement_triggers rt ON rr.id = rt.requirement_id
INNER JOIN regulatory_sources rs ON rr.source_id = rs.id
WHERE c.is_active = 1
  AND rr.is_active = 1
  AND rs.is_active = 1
  AND (
    -- Match hazard flags
    (rt.trigger_type = 'chemical_hazard' AND (
        (rt.hazard_flag = 'signal_word' AND c.signal_word IS NOT NULL) OR
        (rt.hazard_flag = 'is_flammable' AND c.is_flammable = 1) OR
        (rt.hazard_flag = 'is_oxidizer' AND c.is_oxidizer = 1) OR
        (rt.hazard_flag = 'is_explosive' AND c.is_explosive = 1) OR
        (rt.hazard_flag = 'is_acute_toxic' AND c.is_acute_toxic = 1) OR
        (rt.hazard_flag = 'is_carcinogen' AND c.is_carcinogen = 1) OR
        (rt.hazard_flag = 'is_respiratory_sensitizer' AND c.is_respiratory_sensitizer = 1) OR
        (rt.hazard_flag = 'is_skin_sensitizer' AND c.is_skin_sensitizer = 1) OR
        (rt.hazard_flag = 'is_corrosive_to_metal' AND c.is_corrosive_to_metal = 1) OR
        (rt.hazard_flag = 'is_skin_corrosion' AND c.is_skin_corrosion = 1) OR
        (rt.hazard_flag = 'is_eye_damage' AND c.is_eye_damage = 1)
    ))
    OR (rt.trigger_type = 'chemical_specific' AND rt.chemical_id = c.id)
    OR (rt.trigger_type = 'chemical_specific' AND rt.cas_number = c.primary_cas_number)
  )
ORDER BY c.product_name, rr.requirement_type, rs.agency;

-- ============================================================================
-- VIEW: Establishment Regulatory Profile
-- ============================================================================
-- Summary of all regulatory requirements for an establishment based on 
-- their chemical inventory.

CREATE VIEW IF NOT EXISTS v_establishment_regulatory_profile AS
SELECT 
    e.id AS establishment_id,
    e.name AS establishment_name,
    rs.agency,
    rs.regulation_code,
    rs.regulation_name,
    COUNT(DISTINCT rr.id) AS requirement_count,
    GROUP_CONCAT(DISTINCT rr.requirement_type) AS requirement_types,
    COUNT(DISTINCT c.id) AS triggering_chemicals
FROM establishments e
INNER JOIN chemicals c ON e.id = c.establishment_id AND c.is_active = 1
CROSS JOIN regulatory_requirements rr
INNER JOIN requirement_triggers rt ON rr.id = rt.requirement_id
INNER JOIN regulatory_sources rs ON rr.source_id = rs.id
WHERE rr.is_active = 1
  AND rs.is_active = 1
  AND (
    (rt.trigger_type = 'chemical_hazard' AND (
        (rt.hazard_flag = 'signal_word' AND c.signal_word IS NOT NULL) OR
        (rt.hazard_flag = 'is_flammable' AND c.is_flammable = 1) OR
        (rt.hazard_flag = 'is_acute_toxic' AND c.is_acute_toxic = 1) OR
        (rt.hazard_flag = 'is_carcinogen' AND c.is_carcinogen = 1) OR
        (rt.hazard_flag = 'is_respiratory_sensitizer' AND c.is_respiratory_sensitizer = 1)
    ))
    OR (rt.trigger_type = 'chemical_specific' AND rt.chemical_id = c.id)
  )
GROUP BY e.id, rs.id
ORDER BY e.name, rs.agency;
