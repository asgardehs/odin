-- Waypoint-EHS - Chemical Inventory & SDS Management Schema
-- Designed to support OSHA HazCom, EPA Tier II (EPCRA 311/312),
-- and SARA 313 (TRI) reporting for manufacturing facilities.
--
-- Regulatory References:
--   OSHA HazCom    - 29 CFR 1910.1200 (SDS availability, labeling, training)
--   EPA Tier II   - EPCRA Sections 311/312 (annual inventory report)
--   SARA 313/TRI  - EPCRA Section 313 (toxic release inventory)
--   GHS           - Globally Harmonized System (classification/labeling)
--
-- Design Philosophy:
--   - Point-in-time inventory snapshots as primary method (Tier II friendly)
--   - Optional transaction tracking for detailed usage analysis
--   - SDS management with revision tracking and review reminders

-- ============================================================================
-- STORAGE LOCATIONS
-- ============================================================================
-- Physical locations where chemicals are stored. Required for Tier II
-- reporting (must report storage locations and conditions).

CREATE TABLE IF NOT EXISTS storage_locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Location hierarchy
    building TEXT NOT NULL,                 -- Building name/number
    room TEXT,                              -- Room name/number
    area TEXT,                              -- Specific area (e.g., "Flammable Cabinet 3")

    -- For Tier II site map coordinates (optional but helpful)
    grid_reference TEXT,                    -- Site-specific grid (e.g., "A-15")
    latitude REAL,
    longitude REAL,

    -- Storage conditions (Tier II asks about this)
    is_indoor INTEGER DEFAULT 1,            -- Indoor vs outdoor
    storage_pressure TEXT DEFAULT 'ambient',-- ambient, above_ambient, below_ambient
    storage_temperature TEXT DEFAULT 'ambient', -- ambient, above_ambient, below_ambient, cryogenic

    -- Storage type descriptions
    container_types TEXT,                   -- tank, drum, bag, cylinder, etc. (comma-separated)
    max_capacity_gallons REAL,              -- Total storage capacity for this location

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_storage_locations_establishment ON storage_locations(establishment_id);

-- ============================================================================
-- CHEMICALS (Master Chemical Record)
-- ============================================================================
-- Core chemical information. One record per unique chemical product.
-- A single CAS number might appear in multiple products (different manufacturers).

CREATE TABLE IF NOT EXISTS chemicals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- ========== IDENTIFICATION ==========
    product_name TEXT NOT NULL,             -- Trade name / product name
    manufacturer TEXT,                      -- Who makes it
    manufacturer_phone TEXT,                -- Emergency contact

    -- CAS number is the universal chemical identifier
    -- Products may contain multiple CAS numbers (mixtures)
    -- Primary CAS stored here; components in chemical_components table
    primary_cas_number TEXT,                -- e.g., "7647-01-0" for HCl

    -- ========== GHS CLASSIFICATION ==========
    -- Globally Harmonized System - basis for HazCom 2012

    signal_word TEXT,                       -- 'Danger' or 'Warning' (or NULL if not hazardous)

    -- GHS Hazard Classes (stored as flags for easy querying)
    -- Physical Hazards
    is_flammable INTEGER DEFAULT 0,
    is_oxidizer INTEGER DEFAULT 0,
    is_explosive INTEGER DEFAULT 0,
    is_self_reactive INTEGER DEFAULT 0,
    is_pyrophoric INTEGER DEFAULT 0,
    is_self_heating INTEGER DEFAULT 0,
    is_organic_peroxide INTEGER DEFAULT 0,
    is_corrosive_to_metal INTEGER DEFAULT 0,
    is_gas_under_pressure INTEGER DEFAULT 0,
    is_water_reactive INTEGER DEFAULT 0,

    -- Health Hazards
    is_acute_toxic INTEGER DEFAULT 0,
    is_skin_corrosion INTEGER DEFAULT 0,
    is_eye_damage INTEGER DEFAULT 0,
    is_skin_sensitizer INTEGER DEFAULT 0,
    is_respiratory_sensitizer INTEGER DEFAULT 0,
    is_germ_cell_mutagen INTEGER DEFAULT 0,
    is_carcinogen INTEGER DEFAULT 0,
    is_reproductive_toxin INTEGER DEFAULT 0,
    is_target_organ_single INTEGER DEFAULT 0,  -- STOT-SE
    is_target_organ_repeat INTEGER DEFAULT 0,  -- STOT-RE
    is_aspiration_hazard INTEGER DEFAULT 0,

    -- Environmental Hazards
    is_aquatic_toxic INTEGER DEFAULT 0,

    -- ========== PHYSICAL PROPERTIES ==========
    -- Needed for storage compatibility and Tier II physical state

    physical_state TEXT,                    -- solid, liquid, gas
    specific_gravity REAL,                  -- For liquid volume/weight conversions
    vapor_pressure_mmhg REAL,
    flash_point_f REAL,
    ph REAL,
    appearance TEXT,                        -- Color, form description
    odor TEXT,

    -- ========== REGULATORY FLAGS ==========

    -- EPA Tier II / EPCRA
    is_ehs INTEGER DEFAULT 0,               -- Extremely Hazardous Substance (EPCRA 302)
    ehs_tpq_lbs REAL,                       -- Threshold Planning Quantity if EHS

    -- SARA 313 / TRI
    is_sara_313 INTEGER DEFAULT 0,          -- Listed on SARA 313 (TRI reporting required)
    sara_313_category TEXT,                 -- 'listed', 'pbt', 'delisted', etc.

    -- OSHA specific
    is_osha_pel INTEGER DEFAULT 0,          -- Has OSHA Permissible Exposure Limit
    osha_pel_value TEXT,                    -- PEL value and units
    is_osha_carcinogen INTEGER DEFAULT 0,   -- OSHA-listed carcinogen

    -- State-specific (California Prop 65 is common)
    is_prop65 INTEGER DEFAULT 0,

    -- ========== STORAGE & HANDLING ==========

    storage_requirements TEXT,              -- Special storage instructions
    incompatible_materials TEXT,            -- What it shouldn't be stored with
    ppe_required TEXT,                      -- Standard PPE for handling

    -- ========== TIER II REPORTING THRESHOLDS ==========
    -- Standard thresholds; user can override per-chemical if needed

    tier2_tpq_lbs REAL DEFAULT 10000,       -- Default 10,000 lbs for hazardous
                                            -- EHS chemicals have lower thresholds

    -- ========== STATUS ==========

    is_active INTEGER DEFAULT 1,            -- Still in use at facility
    discontinued_date TEXT,                 -- When removed from inventory
    discontinued_reason TEXT,               -- Why (replaced, banned, etc.)

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_chemicals_establishment ON chemicals(establishment_id);
CREATE INDEX idx_chemicals_cas ON chemicals(primary_cas_number);
CREATE INDEX idx_chemicals_name ON chemicals(product_name);
CREATE INDEX idx_chemicals_ehs ON chemicals(is_ehs) WHERE is_ehs = 1;
CREATE INDEX idx_chemicals_sara313 ON chemicals(is_sara_313) WHERE is_sara_313 = 1;

-- ============================================================================
-- CHEMICAL COMPONENTS (Mixture Ingredients)
-- ============================================================================
-- For products that are mixtures, track individual components.
-- SDS Section 3 lists these with concentration ranges.

CREATE TABLE IF NOT EXISTS chemical_components (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,

    component_name TEXT NOT NULL,           -- Chemical name of ingredient
    cas_number TEXT,                        -- CAS number of this component

    -- Concentration (SDS often gives ranges)
    concentration_min REAL,                 -- Minimum % (0-100)
    concentration_max REAL,                 -- Maximum % (0-100)
    concentration_exact REAL,               -- If exact value known

    -- Regulatory flags for this specific component
    is_sara_313 INTEGER DEFAULT 0,
    is_ehs INTEGER DEFAULT 0,
    is_carcinogen INTEGER DEFAULT 0,

    -- For SARA 313, the de minimis concentration matters
    sara_313_deminimis REAL,                -- Usually 1% (0.1% for PBTs)

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id) ON DELETE CASCADE
);

CREATE INDEX idx_chemical_components_chemical ON chemical_components(chemical_id);
CREATE INDEX idx_chemical_components_cas ON chemical_components(cas_number);

-- ============================================================================
-- SDS DOCUMENTS
-- ============================================================================
-- Track Safety Data Sheets with revision history.
-- OSHA requires SDSs be "readily accessible" - this proves you have them.

CREATE TABLE IF NOT EXISTS sds_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,

    -- SDS Identification
    revision_date TEXT NOT NULL,            -- Date on the SDS
    revision_number TEXT,                   -- Manufacturer's revision number
    language TEXT DEFAULT 'en',             -- For multilingual workforces

    -- File Storage
    file_path TEXT,                         -- Path to PDF/file
    file_hash TEXT,                         -- SHA-256 for integrity verification

    -- SDS Source
    source TEXT,                            -- 'manufacturer', 'distributor', 'sds_service'
    obtained_date TEXT NOT NULL,            -- When we got this version
    obtained_by TEXT,

    -- Review Status (good practice to review SDSs periodically)
    last_reviewed_date TEXT,
    reviewed_by TEXT,
    next_review_date TEXT,

    -- Currency
    is_current INTEGER DEFAULT 1,           -- Is this the active SDS?
    superseded_date TEXT,                   -- When this version was replaced
    superseded_by_id INTEGER,               -- Link to newer version

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id) ON DELETE CASCADE,
    FOREIGN KEY (superseded_by_id) REFERENCES sds_documents(id)
);

CREATE INDEX idx_sds_documents_chemical ON sds_documents(chemical_id);
CREATE INDEX idx_sds_documents_current ON sds_documents(is_current) WHERE is_current = 1;
CREATE INDEX idx_sds_documents_review ON sds_documents(next_review_date);

-- ============================================================================
-- CHEMICAL INVENTORY (Point-in-Time Snapshots)
-- ============================================================================
-- Primary inventory tracking method. User records quantities periodically.
-- Designed for easy Tier II reporting (max amount, average daily amount).

CREATE TABLE IF NOT EXISTS chemical_inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,
    storage_location_id INTEGER NOT NULL,

    -- Snapshot identification
    snapshot_date TEXT NOT NULL,            -- Date of this inventory count
    snapshot_type TEXT DEFAULT 'manual',    -- manual, monthly, quarterly, annual, tier2

    -- Quantity
    quantity REAL NOT NULL,
    unit TEXT NOT NULL,                     -- lbs, gallons, kg, liters, etc.
    quantity_lbs REAL,                      -- Converted to lbs for Tier II calcs

    -- Container info (useful for Tier II)
    container_type TEXT,                    -- tank, drum, cylinder, bag, box, etc.
    container_count INTEGER,                -- Number of containers
    max_container_size REAL,                -- Size per container
    max_container_size_unit TEXT,

    -- For Tier II calculations - user can override calculated values
    is_tier2_max INTEGER DEFAULT 0,         -- Was this the max for the year?
    is_tier2_average INTEGER DEFAULT 0,     -- Include in average calculation?

    -- Who recorded this
    recorded_by TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id) ON DELETE CASCADE,
    FOREIGN KEY (storage_location_id) REFERENCES storage_locations(id)
);

CREATE INDEX idx_chemical_inventory_chemical ON chemical_inventory(chemical_id);
CREATE INDEX idx_chemical_inventory_location ON chemical_inventory(storage_location_id);
CREATE INDEX idx_chemical_inventory_date ON chemical_inventory(snapshot_date);
CREATE INDEX idx_chemical_inventory_snapshot_type ON chemical_inventory(snapshot_type);

-- ============================================================================
-- CHEMICAL TRANSACTIONS (Optional Detailed Tracking)
-- ============================================================================
-- For users who want to track every receipt/usage. Optional but enables:
--   - Real-time inventory calculations
--   - SARA 313 usage calculations
--   - Cost tracking
--   - Supplier analysis

CREATE TABLE IF NOT EXISTS chemical_transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,
    storage_location_id INTEGER,            -- NULL for some transaction types

    transaction_date TEXT NOT NULL,
    transaction_type TEXT NOT NULL,         -- receipt, usage, transfer_in, transfer_out,
                                            -- disposal, spill, return_to_vendor, adjustment

    -- Quantity (positive for additions, negative for reductions)
    quantity REAL NOT NULL,
    unit TEXT NOT NULL,
    quantity_lbs REAL,                      -- Converted for calcs

    -- Receipt-specific fields
    supplier TEXT,
    purchase_order TEXT,
    lot_number TEXT,
    received_by TEXT,

    -- Transfer-specific fields
    from_location_id INTEGER,               -- For transfers
    to_location_id INTEGER,                 -- For transfers
    transfer_reason TEXT,

    -- Disposal-specific fields (links to waste management module)
    waste_manifest_id INTEGER,              -- Future link to waste_manifests table
    disposal_method TEXT,

    -- Usage tracking (helpful for SARA 313)
    usage_purpose TEXT,                     -- production, cleaning, maintenance, etc.
    work_order TEXT,
    batch_number TEXT,

    -- Cost tracking (optional)
    unit_cost REAL,
    total_cost REAL,

    recorded_by TEXT,
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id) ON DELETE CASCADE,
    FOREIGN KEY (storage_location_id) REFERENCES storage_locations(id),
    FOREIGN KEY (from_location_id) REFERENCES storage_locations(id),
    FOREIGN KEY (to_location_id) REFERENCES storage_locations(id)
);

CREATE INDEX idx_chemical_transactions_chemical ON chemical_transactions(chemical_id);
CREATE INDEX idx_chemical_transactions_date ON chemical_transactions(transaction_date);
CREATE INDEX idx_chemical_transactions_type ON chemical_transactions(transaction_type);
CREATE INDEX idx_chemical_transactions_location ON chemical_transactions(storage_location_id);

-- ============================================================================
-- GHS HAZARD STATEMENTS (Reference Table)
-- ============================================================================
-- Standard GHS H-statements and P-statements for consistent labeling.

CREATE TABLE IF NOT EXISTS ghs_hazard_statements (
    code TEXT PRIMARY KEY,                  -- H200, H300, P201, etc.
    statement_type TEXT NOT NULL,           -- 'hazard' (H) or 'precautionary' (P)
    hazard_class TEXT,                      -- Physical, Health, Environmental
    full_text TEXT NOT NULL,                -- The actual statement text
    category TEXT                           -- Subcategory within hazard class
);

-- Physical Hazards (subset - full list is extensive)
INSERT OR IGNORE INTO ghs_hazard_statements (code, statement_type, hazard_class, full_text, category) VALUES
    ('H200', 'hazard', 'Physical', 'Unstable explosive', 'Explosives'),
    ('H220', 'hazard', 'Physical', 'Extremely flammable gas', 'Flammable gases'),
    ('H224', 'hazard', 'Physical', 'Extremely flammable liquid and vapor', 'Flammable liquids'),
    ('H225', 'hazard', 'Physical', 'Highly flammable liquid and vapor', 'Flammable liquids'),
    ('H226', 'hazard', 'Physical', 'Flammable liquid and vapor', 'Flammable liquids'),
    ('H228', 'hazard', 'Physical', 'Flammable solid', 'Flammable solids'),
    ('H270', 'hazard', 'Physical', 'May cause or intensify fire; oxidizer', 'Oxidizing gases'),
    ('H280', 'hazard', 'Physical', 'Contains gas under pressure; may explode if heated', 'Gases under pressure'),
    ('H290', 'hazard', 'Physical', 'May be corrosive to metals', 'Corrosive to metals');

-- Health Hazards (subset)
INSERT OR IGNORE INTO ghs_hazard_statements (code, statement_type, hazard_class, full_text, category) VALUES
    ('H300', 'hazard', 'Health', 'Fatal if swallowed', 'Acute toxicity'),
    ('H301', 'hazard', 'Health', 'Toxic if swallowed', 'Acute toxicity'),
    ('H302', 'hazard', 'Health', 'Harmful if swallowed', 'Acute toxicity'),
    ('H304', 'hazard', 'Health', 'May be fatal if swallowed and enters airways', 'Aspiration hazard'),
    ('H310', 'hazard', 'Health', 'Fatal in contact with skin', 'Acute toxicity'),
    ('H311', 'hazard', 'Health', 'Toxic in contact with skin', 'Acute toxicity'),
    ('H312', 'hazard', 'Health', 'Harmful in contact with skin', 'Acute toxicity'),
    ('H314', 'hazard', 'Health', 'Causes severe skin burns and eye damage', 'Skin corrosion'),
    ('H315', 'hazard', 'Health', 'Causes skin irritation', 'Skin irritation'),
    ('H317', 'hazard', 'Health', 'May cause an allergic skin reaction', 'Skin sensitization'),
    ('H318', 'hazard', 'Health', 'Causes serious eye damage', 'Eye damage'),
    ('H319', 'hazard', 'Health', 'Causes serious eye irritation', 'Eye irritation'),
    ('H330', 'hazard', 'Health', 'Fatal if inhaled', 'Acute toxicity'),
    ('H331', 'hazard', 'Health', 'Toxic if inhaled', 'Acute toxicity'),
    ('H332', 'hazard', 'Health', 'Harmful if inhaled', 'Acute toxicity'),
    ('H334', 'hazard', 'Health', 'May cause allergy or asthma symptoms or breathing difficulties if inhaled', 'Respiratory sensitization'),
    ('H335', 'hazard', 'Health', 'May cause respiratory irritation', 'STOT-SE'),
    ('H340', 'hazard', 'Health', 'May cause genetic defects', 'Germ cell mutagenicity'),
    ('H350', 'hazard', 'Health', 'May cause cancer', 'Carcinogenicity'),
    ('H360', 'hazard', 'Health', 'May damage fertility or the unborn child', 'Reproductive toxicity'),
    ('H370', 'hazard', 'Health', 'Causes damage to organs', 'STOT-SE'),
    ('H372', 'hazard', 'Health', 'Causes damage to organs through prolonged or repeated exposure', 'STOT-RE');

-- Environmental Hazards
INSERT OR IGNORE INTO ghs_hazard_statements (code, statement_type, hazard_class, full_text, category) VALUES
    ('H400', 'hazard', 'Environmental', 'Very toxic to aquatic life', 'Aquatic toxicity'),
    ('H410', 'hazard', 'Environmental', 'Very toxic to aquatic life with long lasting effects', 'Aquatic toxicity'),
    ('H411', 'hazard', 'Environmental', 'Toxic to aquatic life with long lasting effects', 'Aquatic toxicity');

-- ============================================================================
-- CHEMICAL TO HAZARD STATEMENT MAPPING
-- ============================================================================
-- Links chemicals to their specific H and P statements from the SDS.

CREATE TABLE IF NOT EXISTS chemical_hazard_statements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,
    statement_code TEXT NOT NULL,           -- References ghs_hazard_statements.code

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id) ON DELETE CASCADE,
    UNIQUE(chemical_id, statement_code)
);

CREATE INDEX idx_chemical_hazard_statements_chemical ON chemical_hazard_statements(chemical_id);

-- ============================================================================
-- GHS PICTOGRAMS (Reference Table)
-- ============================================================================
-- The 9 standard GHS pictogram symbols

CREATE TABLE IF NOT EXISTS ghs_pictograms (
    code TEXT PRIMARY KEY,                  -- GHS01, GHS02, etc.
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    symbol_filename TEXT                    -- For UI display
);

INSERT OR IGNORE INTO ghs_pictograms (code, name, description, symbol_filename) VALUES
    ('GHS01', 'Exploding Bomb', 'Explosives, self-reactives, organic peroxides', 'ghs01_exploding_bomb.svg'),
    ('GHS02', 'Flame', 'Flammables, self-reactives, pyrophorics, self-heating, emits flammable gas, organic peroxides', 'ghs02_flame.svg'),
    ('GHS03', 'Flame Over Circle', 'Oxidizers', 'ghs03_flame_over_circle.svg'),
    ('GHS04', 'Gas Cylinder', 'Compressed gases', 'ghs04_gas_cylinder.svg'),
    ('GHS05', 'Corrosion', 'Corrosives, skin corrosion, eye damage, corrosive to metals', 'ghs05_corrosion.svg'),
    ('GHS06', 'Skull and Crossbones', 'Acute toxicity (severe)', 'ghs06_skull_crossbones.svg'),
    ('GHS07', 'Exclamation Mark', 'Irritant, skin sensitizer, acute toxicity (harmful), narcotic effects, respiratory tract irritation', 'ghs07_exclamation_mark.svg'),
    ('GHS08', 'Health Hazard', 'Carcinogen, mutagenicity, reproductive toxicity, respiratory sensitizer, target organ toxicity, aspiration toxicity', 'ghs08_health_hazard.svg'),
    ('GHS09', 'Environment', 'Aquatic toxicity', 'ghs09_environment.svg');

-- ============================================================================
-- CHEMICAL TO PICTOGRAM MAPPING
-- ============================================================================

CREATE TABLE IF NOT EXISTS chemical_pictograms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,
    pictogram_code TEXT NOT NULL,

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id) ON DELETE CASCADE,
    FOREIGN KEY (pictogram_code) REFERENCES ghs_pictograms(code),
    UNIQUE(chemical_id, pictogram_code)
);

CREATE INDEX idx_chemical_pictograms_chemical ON chemical_pictograms(chemical_id);

-- ============================================================================
-- TIER II REPORTS (Annual Submission Records)
-- ============================================================================
-- Stores generated Tier II report data for each year.
-- EPA Tier II is due March 1 for the previous calendar year.

CREATE TABLE IF NOT EXISTS tier2_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    report_year INTEGER NOT NULL,

    -- Report Status
    status TEXT DEFAULT 'draft',            -- draft, submitted, accepted, revised
    submitted_date TEXT,
    submitted_to TEXT,                      -- LEPC, Fire Dept, SERC names
    confirmation_number TEXT,               -- If submitted electronically

    -- Certification
    certified_by TEXT,
    certified_title TEXT,
    certified_date TEXT,

    -- Contacts reported
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    emergency_contact_title TEXT,

    -- Optional second contact
    emergency_contact2_name TEXT,
    emergency_contact2_phone TEXT,
    emergency_contact2_title TEXT,

    notes TEXT,

    generated_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, report_year)
);

-- ============================================================================
-- TIER II REPORT CHEMICALS (Chemicals Included in Each Report)
-- ============================================================================
-- Details for each chemical reported on Tier II.

CREATE TABLE IF NOT EXISTS tier2_report_chemicals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tier2_report_id INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,

    -- Chemical identification (snapshot at time of report)
    chemical_name TEXT NOT NULL,
    cas_number TEXT,
    is_esh INTEGER DEFAULT 0,               -- Extremely Hazardous Substance
    is_trade_secret INTEGER DEFAULT 0,      -- Claimed as trade secret

    -- Quantity Information (Tier II requires these)
    max_amount_lbs REAL NOT NULL,           -- Maximum amount on-site during year
    max_amount_code TEXT,                   -- Range code (01-11) for public report
    avg_daily_amount_lbs REAL NOT NULL,     -- Average daily amount
    avg_daily_amount_code TEXT,             -- Range code
    days_on_site INTEGER DEFAULT 365,       -- Number of days chemical was present

    -- Physical and Health Hazards (checkboxes on form)
    is_fire_hazard INTEGER DEFAULT 0,
    is_sudden_release_pressure INTEGER DEFAULT 0,
    is_reactive INTEGER DEFAULT 0,
    is_immediate_health INTEGER DEFAULT 0,
    is_delayed_health INTEGER DEFAULT 0,

    -- Storage Information
    storage_locations TEXT,                 -- JSON array of location descriptions
    storage_types TEXT,                     -- JSON array: above_ground_tank, below_ground_tank, etc.
    storage_pressure TEXT,                  -- ambient, above_ambient, below_ambient
    storage_temperature TEXT,               -- ambient, above_ambient, below_ambient, cryogenic

    -- Optional confidential location info
    confidential_location INTEGER DEFAULT 0,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (tier2_report_id) REFERENCES tier2_reports(id) ON DELETE CASCADE,
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id)
);

CREATE INDEX idx_tier2_report_chemicals_report ON tier2_report_chemicals(tier2_report_id);
CREATE INDEX idx_tier2_report_chemicals_chemical ON tier2_report_chemicals(chemical_id);

-- ============================================================================
-- UNIT CONVERSIONS (For Inventory Calculations)
-- ============================================================================
-- Tier II reports in pounds. Need to convert various units.

CREATE TABLE IF NOT EXISTS unit_conversions (
    from_unit TEXT NOT NULL,
    to_unit TEXT NOT NULL,
    multiplier REAL NOT NULL,               -- from_unit * multiplier = to_unit
    notes TEXT,

    PRIMARY KEY (from_unit, to_unit)
);

-- Common conversions to pounds (weight)
INSERT OR IGNORE INTO unit_conversions (from_unit, to_unit, multiplier, notes) VALUES
    ('lbs', 'lbs', 1.0, 'Identity'),
    ('kg', 'lbs', 2.20462, 'Kilograms to pounds'),
    ('oz', 'lbs', 0.0625, 'Ounces to pounds'),
    ('tons', 'lbs', 2000.0, 'Short tons to pounds'),
    ('metric_tons', 'lbs', 2204.62, 'Metric tons to pounds'),
    ('g', 'lbs', 0.00220462, 'Grams to pounds');

-- Volume conversions require specific gravity, but we store standard densities
-- User applies: gallons * 8.34 * specific_gravity = lbs for water-like liquids
INSERT OR IGNORE INTO unit_conversions (from_unit, to_unit, multiplier, notes) VALUES
    ('gallons', 'liters', 3.78541, 'US gallons to liters'),
    ('liters', 'gallons', 0.264172, 'Liters to US gallons'),
    ('ml', 'liters', 0.001, 'Milliliters to liters'),
    ('fl_oz', 'gallons', 0.0078125, 'Fluid ounces to gallons'),
    ('quarts', 'gallons', 0.25, 'Quarts to gallons'),
    ('pints', 'gallons', 0.125, 'Pints to gallons'),
    ('barrels', 'gallons', 42.0, 'Oil barrels (42 gal) to gallons'),
    ('drums', 'gallons', 55.0, 'Standard 55-gallon drum');

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Current inventory by chemical (most recent snapshot per location)
CREATE VIEW IF NOT EXISTS v_current_inventory AS
SELECT
    ci.chemical_id,
    c.product_name,
    c.primary_cas_number,
    ci.storage_location_id,
    sl.building,
    sl.room,
    sl.area,
    ci.quantity,
    ci.unit,
    ci.quantity_lbs,
    ci.snapshot_date,
    ci.container_type,
    ci.container_count
FROM chemical_inventory ci
INNER JOIN chemicals c ON ci.chemical_id = c.id
INNER JOIN storage_locations sl ON ci.storage_location_id = sl.id
WHERE ci.snapshot_date = (
    SELECT MAX(ci2.snapshot_date)
    FROM chemical_inventory ci2
    WHERE ci2.chemical_id = ci.chemical_id
      AND ci2.storage_location_id = ci.storage_location_id
)
AND c.is_active = 1;

-- Chemicals requiring Tier II reporting (above threshold)
CREATE VIEW IF NOT EXISTS v_tier2_reportable AS
SELECT
    c.id AS chemical_id,
    c.product_name,
    c.primary_cas_number,
    c.is_ehs,
    c.tier2_tpq_lbs AS threshold_lbs,
    COALESCE(inv.total_lbs, 0) AS current_total_lbs,
    CASE
        WHEN COALESCE(inv.total_lbs, 0) >= c.tier2_tpq_lbs THEN 1
        ELSE 0
    END AS is_reportable
FROM chemicals c
LEFT JOIN (
    SELECT
        chemical_id,
        SUM(quantity_lbs) AS total_lbs
    FROM v_current_inventory
    GROUP BY chemical_id
) inv ON c.id = inv.chemical_id
WHERE c.is_active = 1
  AND (c.signal_word IS NOT NULL OR c.is_ehs = 1);

-- SDS review status (upcoming and overdue reviews)
CREATE VIEW IF NOT EXISTS v_sds_review_status AS
SELECT
    sd.id AS sds_id,
    c.id AS chemical_id,
    c.product_name,
    sd.revision_date,
    sd.last_reviewed_date,
    sd.next_review_date,
    CASE
        WHEN sd.next_review_date < date('now') THEN 'overdue'
        WHEN sd.next_review_date <= date('now', '+30 days') THEN 'due_soon'
        ELSE 'current'
    END AS review_status,
    julianday(sd.next_review_date) - julianday('now') AS days_until_review
FROM sds_documents sd
INNER JOIN chemicals c ON sd.chemical_id = c.id
WHERE sd.is_current = 1
  AND c.is_active = 1
ORDER BY sd.next_review_date;
