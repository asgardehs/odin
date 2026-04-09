-- Module A: EPCRA Chemical Inventory & TRI Reporting
-- (EPCRA Sections 302, 304, 311, 312, 313)
-- Derived from ehs-ontology-v3.1.ttl — Module A classes + v3.1 TRI expansion
--
-- Design principle: separate INVENTORY (what's on site) from DETERMINATION
-- (is it reportable, and under which program?) from REPORT (the submitted form).
-- The ontology defines explicit decision points — EHS designation, Tier II
-- threshold evaluation, TRI three-prong applicability test, Form R vs Form A
-- eligibility — that this schema makes auditable rather than boolean flags.
--
-- An inspector can trace: chemical present → threshold exceeded → notification
-- sent → determination documented → report submitted. Every regulatory gate
-- has a record, not just the final outcome.
--
-- Regulatory References:
--   OSHA HazCom    - 29 CFR 1910.1200 (SDS availability, labeling, training)
--   EPCRA 302/303  - Emergency planning (EHS at/above TPQ)
--   EPCRA 304      - Release notification (EHS/CERCLA above RQ)
--   EPCRA 311      - Initial chemical notification (SDS or list)
--   EPCRA 312      - Annual Tier II inventory report (due March 1)
--   EPCRA 313/TRI  - Toxics Release Inventory (Form R/A, due July 1)
--   GHS            - Globally Harmonized System (classification/labeling)
--
-- Depends on: shared foundation tables (establishments, employees) from Module C.
-- Cross-module: TRI release quantities link to emission units (Module B) via
-- releaseFromEmissionUnit property in the ontology.


-- ============================================================================
-- STORAGE LOCATIONS (ontology: implicit in InventoryChemical storage attributes)
-- ============================================================================
-- Physical locations where chemicals are stored. Required for Tier II
-- reporting — must report storage locations, conditions, and container types.

CREATE TABLE IF NOT EXISTS storage_locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Location hierarchy
    building TEXT NOT NULL,
    room TEXT,
    area TEXT,                              -- e.g., "Flammable Cabinet 3"

    -- Site map coordinates (Tier II site plan reference)
    grid_reference TEXT,
    latitude REAL,
    longitude REAL,

    -- Storage conditions (Tier II form fields)
    is_indoor INTEGER DEFAULT 1,
    storage_pressure TEXT DEFAULT 'ambient',     -- ambient, above_ambient, below_ambient
    storage_temperature TEXT DEFAULT 'ambient',  -- ambient, above_ambient, below_ambient, cryogenic

    -- Container description
    container_types TEXT,                   -- tank, drum, bag, cylinder, etc. (comma-separated)
    max_capacity_gallons REAL,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_storage_locations_establishment ON storage_locations(establishment_id);


-- ============================================================================
-- CHEMICALS (ontology: InventoryChemical)
-- ============================================================================
-- Master chemical record. One record per unique chemical product at a facility.
-- Ontology class hierarchy: InventoryChemical → TRIChemical → PBT Chemical
-- is modeled via flags (is_sara_313, is_pbt) rather than separate tables,
-- because the same product may have components at different classification levels.

CREATE TABLE IF NOT EXISTS chemicals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- ========== IDENTIFICATION ==========
    product_name TEXT NOT NULL,
    manufacturer TEXT,
    manufacturer_phone TEXT,

    -- CAS number — universal chemical identifier
    -- Products may contain multiple CAS numbers (mixtures → chemical_components)
    primary_cas_number TEXT,

    -- ========== GHS CLASSIFICATION (ontology: ChemicalHazard subclasses) ==========

    signal_word TEXT,                       -- 'Danger', 'Warning', or NULL

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
    is_target_organ_single INTEGER DEFAULT 0,   -- STOT-SE
    is_target_organ_repeat INTEGER DEFAULT 0,   -- STOT-RE
    is_aspiration_hazard INTEGER DEFAULT 0,

    -- Environmental Hazards
    is_aquatic_toxic INTEGER DEFAULT 0,

    -- ========== PHYSICAL PROPERTIES ==========

    physical_state TEXT,                    -- solid, liquid, gas
    specific_gravity REAL,
    vapor_pressure_mmhg REAL,
    flash_point_f REAL,
    ph REAL,
    appearance TEXT,
    odor TEXT,

    -- ========== REGULATORY CLASSIFICATION ==========
    -- These flags encode the ontology class hierarchy:
    --   InventoryChemical (all chemicals here)
    --     └─ TRIChemical (is_sara_313 = 1)
    --         └─ TRIPersistentBioaccumulativeChemical (is_pbt = 1)
    --   ExtremelyHazardousSubstance (is_ehs = 1, cross-cutting)

    -- EPCRA 302 / EHS (ontology: ExtremelyHazardousSubstance)
    is_ehs INTEGER DEFAULT 0,
    ehs_tpq_lbs REAL,                      -- Threshold Planning Quantity (40 CFR 355)
    ehs_rq_lbs REAL,                       -- Reportable Quantity for Section 304

    -- SARA 313 / TRI (ontology: TRIChemical)
    is_sara_313 INTEGER DEFAULT 0,
    sara_313_category TEXT,                 -- 'listed', 'pbt', 'delisted'

    -- PBT (ontology: TRIPersistentBioaccumulativeChemical)
    is_pbt INTEGER DEFAULT 0,

    -- OSHA specific
    is_osha_pel INTEGER DEFAULT 0,
    osha_pel_value TEXT,
    is_osha_carcinogen INTEGER DEFAULT 0,

    -- State-specific
    is_prop65 INTEGER DEFAULT 0,

    -- ========== STORAGE & HANDLING ==========

    storage_requirements TEXT,
    incompatible_materials TEXT,
    ppe_required TEXT,

    -- ========== STATUS ==========

    is_active INTEGER DEFAULT 1,
    discontinued_date TEXT,
    discontinued_reason TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_chemicals_establishment ON chemicals(establishment_id);
CREATE INDEX idx_chemicals_cas ON chemicals(primary_cas_number);
CREATE INDEX idx_chemicals_name ON chemicals(product_name);
CREATE INDEX idx_chemicals_ehs ON chemicals(is_ehs) WHERE is_ehs = 1;
CREATE INDEX idx_chemicals_sara313 ON chemicals(is_sara_313) WHERE is_sara_313 = 1;
CREATE INDEX idx_chemicals_pbt ON chemicals(is_pbt) WHERE is_pbt = 1;


-- ============================================================================
-- CHEMICAL COMPONENTS (Mixture Ingredients — SDS Section 3)
-- ============================================================================
-- For mixtures, track individual components. Critical for TRI because
-- de minimis exemptions operate at the component level: a component below
-- its de minimis concentration in a mixture is exempt from TRI threshold
-- counting (but NOT from release reporting).

CREATE TABLE IF NOT EXISTS chemical_components (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,

    component_name TEXT NOT NULL,
    cas_number TEXT,

    -- Concentration (SDS often gives ranges)
    concentration_min REAL,                 -- Minimum % (0-100)
    concentration_max REAL,                 -- Maximum % (0-100)
    concentration_exact REAL,

    -- Regulatory flags per component
    is_sara_313 INTEGER DEFAULT 0,
    is_ehs INTEGER DEFAULT 0,
    is_carcinogen INTEGER DEFAULT 0,
    is_pbt INTEGER DEFAULT 0,

    -- De minimis for this component (ontology: TRIDeMinimisExemption)
    -- Standard: 1% for most TRI chemicals
    -- Reduced: 0.1% for OSHA carcinogens and PBTs
    deminimis_percent REAL,
    is_below_deminimis INTEGER DEFAULT 0,   -- Pre-calculated: concentration < deminimis

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id) ON DELETE CASCADE
);

CREATE INDEX idx_chemical_components_chemical ON chemical_components(chemical_id);
CREATE INDEX idx_chemical_components_cas ON chemical_components(cas_number);


-- ============================================================================
-- GHS HAZARD STATEMENTS (Reference)
-- ============================================================================

CREATE TABLE IF NOT EXISTS ghs_hazard_statements (
    code TEXT PRIMARY KEY,                  -- H200, H300, P201, etc.
    statement_type TEXT NOT NULL,           -- 'hazard' (H) or 'precautionary' (P)
    hazard_class TEXT,                      -- Physical, Health, Environmental
    full_text TEXT NOT NULL,
    category TEXT
);

-- Physical Hazards
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

-- Health Hazards
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

CREATE TABLE IF NOT EXISTS chemical_hazard_statements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,
    statement_code TEXT NOT NULL,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id) ON DELETE CASCADE,
    UNIQUE(chemical_id, statement_code)
);

CREATE INDEX idx_chemical_hazard_statements_chemical ON chemical_hazard_statements(chemical_id);


-- ============================================================================
-- GHS PICTOGRAMS (Reference)
-- ============================================================================

CREATE TABLE IF NOT EXISTS ghs_pictograms (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    symbol_filename TEXT
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
-- SDS DOCUMENTS (ontology: linkedToSDS property)
-- ============================================================================
-- Track Safety Data Sheets with revision history.
-- OSHA requires SDSs be "readily accessible" — this proves you have them.
-- Section 311 initial notification requires providing the SDS to SERC/LEPC/Fire.

CREATE TABLE IF NOT EXISTS sds_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,

    revision_date TEXT NOT NULL,
    revision_number TEXT,
    language TEXT DEFAULT 'en',

    -- File storage
    file_path TEXT,
    file_hash TEXT,                         -- SHA-256 for integrity

    -- Source
    source TEXT,                            -- 'manufacturer', 'distributor', 'sds_service'
    obtained_date TEXT NOT NULL,
    obtained_by TEXT,

    -- Review status
    last_reviewed_date TEXT,
    reviewed_by TEXT,
    next_review_date TEXT,

    -- Currency
    is_current INTEGER DEFAULT 1,
    superseded_date TEXT,
    superseded_by_id INTEGER,

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
-- CHEMICAL INVENTORY (ontology: ChemicalInventory / InventoryChemical)
-- ============================================================================
-- Point-in-time snapshots. Primary inventory tracking method.
-- Designed for Tier II reporting: max amount and average daily amount
-- are derived from these snapshots across the calendar year.

CREATE TABLE IF NOT EXISTS chemical_inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,
    storage_location_id INTEGER NOT NULL,

    snapshot_date TEXT NOT NULL,
    snapshot_type TEXT DEFAULT 'manual',    -- manual, monthly, quarterly, annual, tier2

    -- Quantity
    quantity REAL NOT NULL,
    unit TEXT NOT NULL,                     -- lbs, gallons, kg, liters, etc.
    quantity_lbs REAL,                      -- Converted to lbs for Tier II calcs

    -- Container info (Tier II form fields)
    container_type TEXT,
    container_count INTEGER,
    max_container_size REAL,
    max_container_size_unit TEXT,

    -- Tier II calculation flags
    is_tier2_max INTEGER DEFAULT 0,        -- Was this the max for the year?
    is_tier2_average INTEGER DEFAULT 0,    -- Include in average calculation?

    recorded_by TEXT,
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id) ON DELETE CASCADE,
    FOREIGN KEY (storage_location_id) REFERENCES storage_locations(id)
);

CREATE INDEX idx_chemical_inventory_chemical ON chemical_inventory(chemical_id);
CREATE INDEX idx_chemical_inventory_location ON chemical_inventory(storage_location_id);
CREATE INDEX idx_chemical_inventory_date ON chemical_inventory(snapshot_date);


-- ============================================================================
-- CHEMICAL TRANSACTIONS (Optional — detailed receipt/usage tracking)
-- ============================================================================
-- For facilities that track every receipt/usage. Enables:
--   - Real-time running inventory
--   - SARA 313 usage calculations (manufacture/process/otherwise use)
--   - Cost tracking and supplier analysis

CREATE TABLE IF NOT EXISTS chemical_transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,
    storage_location_id INTEGER,

    transaction_date TEXT NOT NULL,
    transaction_type TEXT NOT NULL,         -- receipt, usage, transfer_in, transfer_out,
                                            -- disposal, spill, return_to_vendor, adjustment

    -- Quantity (positive for additions, negative for reductions)
    quantity REAL NOT NULL,
    unit TEXT NOT NULL,
    quantity_lbs REAL,

    -- Receipt-specific
    supplier TEXT,
    purchase_order TEXT,
    lot_number TEXT,
    received_by TEXT,

    -- Transfer-specific
    from_location_id INTEGER,
    to_location_id INTEGER,
    transfer_reason TEXT,

    -- Disposal-specific
    waste_manifest_id INTEGER,             -- Future link to waste management module
    disposal_method TEXT,

    -- Usage tracking (critical for TRI activity determination)
    -- Maps to ontology TRIActivityThreshold categories:
    --   manufacture = produced, imported, created as byproduct
    --   process = incorporated into product, repackaged
    --   otherwise_use = cleaning, maintenance, catalyst, etc.
    usage_purpose TEXT,
    tri_activity_category TEXT,             -- manufacture, process, otherwise_use
    work_order TEXT,
    batch_number TEXT,

    -- Cost tracking
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


-- ============================================================================
-- UNIT CONVERSIONS (Reference — Tier II reports in pounds)
-- ============================================================================

CREATE TABLE IF NOT EXISTS unit_conversions (
    from_unit TEXT NOT NULL,
    to_unit TEXT NOT NULL,
    multiplier REAL NOT NULL,
    notes TEXT,

    PRIMARY KEY (from_unit, to_unit)
);

INSERT OR IGNORE INTO unit_conversions (from_unit, to_unit, multiplier, notes) VALUES
    ('lbs', 'lbs', 1.0, 'Identity'),
    ('kg', 'lbs', 2.20462, 'Kilograms to pounds'),
    ('oz', 'lbs', 0.0625, 'Ounces to pounds'),
    ('tons', 'lbs', 2000.0, 'Short tons to pounds'),
    ('metric_tons', 'lbs', 2204.62, 'Metric tons to pounds'),
    ('g', 'lbs', 0.00220462, 'Grams to pounds'),
    ('gallons', 'liters', 3.78541, 'US gallons to liters'),
    ('liters', 'gallons', 0.264172, 'Liters to US gallons'),
    ('ml', 'liters', 0.001, 'Milliliters to liters'),
    ('fl_oz', 'gallons', 0.0078125, 'Fluid ounces to gallons'),
    ('quarts', 'gallons', 0.25, 'Quarts to gallons'),
    ('pints', 'gallons', 0.125, 'Pints to gallons'),
    ('barrels', 'gallons', 42.0, 'Oil barrels (42 gal) to gallons'),
    ('drums', 'gallons', 55.0, 'Standard 55-gallon drum');


-- ============================================================================
-- EPCRA EXEMPTIONS (ontology: EPCRAExemption)
-- ============================================================================
-- Conditions under which a chemical is exempt from EPCRA 311/312.
-- Mirrors OSHA HCS exclusions. When an exemption is claimed, it must be
-- documented in the threshold determination (below).

CREATE TABLE IF NOT EXISTS epcra_exemptions (
    code TEXT PRIMARY KEY,
    description TEXT NOT NULL,
    regulatory_basis TEXT NOT NULL
);

INSERT OR IGNORE INTO epcra_exemptions (code, description, regulatory_basis) VALUES
    ('ARTICLE',       'Article formed to specific shape, no chemical release under normal use', 'EPCRA 311(e)(2), OSHA HCS 1910.1200(b)(6)(v)'),
    ('FOOD_DRUG',     'Food, drug, cosmetic, or tobacco for personal consumption by employees', 'EPCRA 311(e)(3), OSHA HCS 1910.1200(b)(6)(vi)'),
    ('CONSUMER_USE',  'Consumer product used in workplace in same manner/frequency as consumer', 'EPCRA 311(e)(4)'),
    ('RESEARCH_LAB',  'Chemical in research laboratory under direct supervision of qualified individual', 'EPCRA 311(e)(5), OSHA HCS 1910.1200(b)(6)(i)'),
    ('AGRICULTURE',   'Substance used in routine agricultural operations', 'EPCRA 311(e)(6)'),
    ('TRANSPORT',     'Substance in transportation or stored incident to transportation (<24 hrs)', 'EPCRA 327'),
    ('SOLID_ITEM',    'Substance present as a solid in any manufactured item to the extent exposure does not occur', 'OSHA HCS 1910.1200(b)(6)(v)'),
    ('WOOD_PRODUCT',  'Wood or wood products that are not chemically treated', 'OSHA HCS 1910.1200(b)(6)(ii)');


-- ============================================================================
-- REPORTING ENTITY CONTACTS (ontology: SERC, LEPC)
-- ============================================================================
-- Track the specific SERC, LEPC, and fire department contacts for each
-- establishment. Sections 302, 304, 311, and 312 all require submission
-- to these entities — having them per-establishment avoids re-entering.

CREATE TABLE IF NOT EXISTS reporting_entity_contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    entity_type TEXT NOT NULL,              -- 'serc', 'lepc', 'fire_department'
    entity_name TEXT NOT NULL,
    contact_name TEXT,
    contact_title TEXT,
    phone TEXT,
    email TEXT,
    mailing_address TEXT,

    -- For electronic submission systems
    submission_portal_url TEXT,
    portal_account_id TEXT,

    notes TEXT,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_reporting_entity_contacts_establishment ON reporting_entity_contacts(establishment_id);


-- ############################################################################
-- EPCRA NOTIFICATIONS (ontology: Section302, Section304, Section311)
-- ############################################################################
-- The ontology models three distinct notification obligations that the
-- original schema did not track. Each is a separate regulatory event
-- with its own timeline and recipients.


-- ============================================================================
-- SECTION 302 NOTIFICATIONS (EHS Emergency Planning)
-- ============================================================================
-- Required within 60 days when an EHS is first present at/above the TPQ.
-- Notifies SERC and LEPC to include the facility in the local emergency
-- response plan (Section 303).

CREATE TABLE IF NOT EXISTS section302_notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,

    -- When EHS first exceeded TPQ at this facility
    tpq_exceeded_date TEXT NOT NULL,
    tpq_lbs REAL NOT NULL,                 -- The applicable TPQ
    quantity_present_lbs REAL NOT NULL,     -- Quantity that triggered notification

    -- Notification deadline and status
    notification_deadline TEXT NOT NULL,    -- tpq_exceeded_date + 60 days
    notified_serc_date TEXT,
    notified_lepc_date TEXT,

    -- Emergency coordinator designated per Section 303
    emergency_coordinator_name TEXT,
    emergency_coordinator_phone TEXT,
    emergency_coordinator_title TEXT,

    status TEXT DEFAULT 'pending',         -- pending, notified, acknowledged
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id)
);

CREATE INDEX idx_section302_establishment ON section302_notifications(establishment_id);


-- ============================================================================
-- SECTION 311 NOTIFICATIONS (Initial Chemical Notification)
-- ============================================================================
-- One-time notification when a hazardous chemical first exceeds the
-- reporting threshold. Must provide SDS or list with hazard info to
-- SERC, LEPC, and local fire department within 3 months.

CREATE TABLE IF NOT EXISTS section311_notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,

    -- When chemical first exceeded reporting threshold
    threshold_exceeded_date TEXT NOT NULL,
    threshold_lbs REAL NOT NULL,           -- 10,000 lbs (or TPQ/500 for EHS)
    max_quantity_present_lbs REAL NOT NULL,

    -- Notification type and deadline
    notification_type TEXT NOT NULL,        -- 'sds' or 'chemical_list'
    notification_deadline TEXT NOT NULL,    -- threshold_exceeded_date + 90 days

    -- Delivery tracking (ontology: submitted to SERC, LEPC, Fire Department)
    notified_serc_date TEXT,
    notified_lepc_date TEXT,
    notified_fire_dept_date TEXT,

    status TEXT DEFAULT 'pending',         -- pending, notified, confirmed
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id)
);

CREATE INDEX idx_section311_establishment ON section311_notifications(establishment_id);
CREATE INDEX idx_section311_status ON section311_notifications(status) WHERE status = 'pending';


-- ============================================================================
-- SECTION 304 RELEASE NOTIFICATIONS (Emergency Release)
-- ============================================================================
-- Immediate notification when a release of an EHS or CERCLA hazardous
-- substance meets/exceeds the Reportable Quantity (RQ). Verbal notice
-- to SERC and LEPC immediately, written follow-up within 7 days.
-- CERCLA substances also require NRC notification.

CREATE TABLE IF NOT EXISTS section304_release_notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,
    incident_id INTEGER,                   -- Optional link to Module C/D incident

    -- Release details
    release_date TEXT NOT NULL,
    release_time TEXT,                      -- HH:MM
    release_quantity_lbs REAL NOT NULL,
    reportable_quantity_lbs REAL NOT NULL,  -- The applicable RQ
    release_medium TEXT,                    -- air, water, land
    release_duration_hours REAL,
    release_description TEXT,

    -- Actions taken
    health_risks TEXT,
    precautions_advised TEXT,
    response_actions TEXT,

    -- Verbal notification (immediate)
    notified_serc_date TEXT,
    notified_serc_time TEXT,
    notified_lepc_date TEXT,
    notified_lepc_time TEXT,
    notified_nrc_date TEXT,                -- For CERCLA substances
    notified_nrc_time TEXT,
    nrc_report_number TEXT,

    -- Written follow-up (within 7 days)
    written_followup_deadline TEXT,
    written_followup_date TEXT,

    status TEXT DEFAULT 'active',          -- active, followup_pending, closed
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id),
    FOREIGN KEY (incident_id) REFERENCES incidents(id)
);

CREATE INDEX idx_section304_establishment ON section304_release_notifications(establishment_id);
CREATE INDEX idx_section304_date ON section304_release_notifications(release_date);


-- ############################################################################
-- TIER II REPORTING (ontology: Section312TierIIReport)
-- ############################################################################


-- ============================================================================
-- TIER II THRESHOLD DETERMINATIONS (ontology: ReportingThreshold)
-- ============================================================================
-- Makes the Tier II threshold evaluation auditable. For each chemical,
-- each year: what was the max quantity? what threshold applies? is it
-- reportable? was an exemption claimed?
--
-- Parallel to Module C's recording_decisions: an inspector can see
-- exactly WHY a chemical was or was not included on the Tier II report.

CREATE TABLE IF NOT EXISTS tier2_threshold_determinations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chemical_id INTEGER NOT NULL,
    determination_year INTEGER NOT NULL,

    -- Maximum quantity present at any one time during calendar year
    max_quantity_present_lbs REAL NOT NULL,

    -- Threshold evaluation (ontology: ReportingThreshold)
    -- EHS chemicals: TPQ or 500 lbs, whichever is LESS
    -- All other hazardous: 10,000 lbs
    is_ehs INTEGER NOT NULL DEFAULT 0,
    applicable_threshold_lbs REAL NOT NULL,

    -- Determination result
    is_above_threshold INTEGER NOT NULL,

    -- Exemption (if chemical is otherwise reportable but exempt)
    exemption_code TEXT,                   -- FK → epcra_exemptions
    exemption_notes TEXT,

    -- Average daily amount (for Tier II report, if reportable)
    avg_daily_amount_lbs REAL,
    days_on_site INTEGER,

    -- Decision metadata
    determined_by TEXT,
    determined_date TEXT,
    review_notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id),
    FOREIGN KEY (exemption_code) REFERENCES epcra_exemptions(code),
    UNIQUE(chemical_id, determination_year)
);

CREATE INDEX idx_tier2_determinations_year ON tier2_threshold_determinations(determination_year);
CREATE INDEX idx_tier2_determinations_reportable ON tier2_threshold_determinations(is_above_threshold)
    WHERE is_above_threshold = 1;


-- ============================================================================
-- TIER II REPORTS (Annual Submission — due March 1)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tier2_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    report_year INTEGER NOT NULL,

    status TEXT DEFAULT 'draft',           -- draft, submitted, accepted, revised
    submitted_date TEXT,
    confirmation_number TEXT,

    -- Certification
    certified_by TEXT,
    certified_title TEXT,
    certified_date TEXT,

    -- Emergency contacts (reported on form)
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    emergency_contact_title TEXT,
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
-- TIER II REPORT CHEMICALS (Detail lines on the Tier II form)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tier2_report_chemicals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tier2_report_id INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,
    determination_id INTEGER,              -- Link to auditable threshold determination

    -- Chemical identification (snapshot at time of report)
    chemical_name TEXT NOT NULL,
    cas_number TEXT,
    is_ehs INTEGER DEFAULT 0,
    is_trade_secret INTEGER DEFAULT 0,

    -- Quantity Information (Tier II required fields)
    max_amount_lbs REAL NOT NULL,
    max_amount_code TEXT,                  -- Range code (01-11) for public report
    avg_daily_amount_lbs REAL NOT NULL,
    avg_daily_amount_code TEXT,
    days_on_site INTEGER DEFAULT 365,

    -- Physical and Health Hazards (checkboxes on form)
    is_fire_hazard INTEGER DEFAULT 0,
    is_sudden_release_pressure INTEGER DEFAULT 0,
    is_reactive INTEGER DEFAULT 0,
    is_immediate_health INTEGER DEFAULT 0,
    is_delayed_health INTEGER DEFAULT 0,

    -- Storage Information
    storage_locations TEXT,                -- JSON array of location descriptions
    storage_types TEXT,                    -- JSON array: above_ground_tank, etc.
    storage_pressure TEXT,
    storage_temperature TEXT,
    confidential_location INTEGER DEFAULT 0,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (tier2_report_id) REFERENCES tier2_reports(id) ON DELETE CASCADE,
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id),
    FOREIGN KEY (determination_id) REFERENCES tier2_threshold_determinations(id)
);

CREATE INDEX idx_tier2_report_chemicals_report ON tier2_report_chemicals(tier2_report_id);


-- ############################################################################
-- TRI SECTION 313 REPORTING (ontology: Section313TRI + v3.1 expansion)
-- ############################################################################


-- ============================================================================
-- SARA 313 CHEMICAL LIST (Reference — ontology: TRIChemical instances)
-- ============================================================================
-- EPA's list of TRI-reportable chemicals. ~800 individual chemicals and
-- 33 chemical categories. Updated annually by EPA.

CREATE TABLE IF NOT EXISTS sara313_chemicals (
    cas_number TEXT PRIMARY KEY,
    chemical_name TEXT NOT NULL,

    -- Category reporting (some reported by category, not individual CAS)
    category_code TEXT,                    -- e.g., 'N096' for Nickel Compounds
    category_name TEXT,

    -- Activity thresholds (ontology: TRIActivityThreshold)
    manufacture_threshold REAL DEFAULT 25000,
    process_threshold REAL DEFAULT 25000,
    otherwise_use_threshold REAL DEFAULT 10000,

    -- PBT flags (ontology: TRIPersistentBioaccumulativeChemical)
    -- PBT chemicals have lower thresholds and are NOT eligible for Form A
    is_pbt INTEGER DEFAULT 0,
    pbt_threshold REAL,                    -- 0.1g for dioxins, 10 lbs mercury, etc.

    -- De minimis (ontology: TRIDeMinimisExemption)
    -- Standard: 1% by weight
    -- Reduced: 0.1% for OSHA carcinogens and PBTs
    deminimis_percent REAL DEFAULT 1.0,

    -- Metal compound flag (affects release calculation method)
    is_metal_compound INTEGER DEFAULT 0,
    parent_metal TEXT,

    -- List currency
    effective_date TEXT,
    delisted_date TEXT,

    notes TEXT
);

CREATE INDEX idx_sara313_chemicals_category ON sara313_chemicals(category_code);
CREATE INDEX idx_sara313_chemicals_pbt ON sara313_chemicals(is_pbt) WHERE is_pbt = 1;

-- Common manufacturing chemicals (subset — full EPA list has 800+)
INSERT OR IGNORE INTO sara313_chemicals
    (cas_number, chemical_name, category_code, category_name, deminimis_percent, is_metal_compound, parent_metal) VALUES
    -- Metals and Metal Compounds
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
    -- Solvents
    ('67-64-1', 'Acetone', NULL, NULL, 1.0, 0, NULL),
    ('78-93-3', 'Methyl ethyl ketone (MEK)', NULL, NULL, 1.0, 0, NULL),
    ('108-88-3', 'Toluene', NULL, NULL, 1.0, 0, NULL),
    ('1330-20-7', 'Xylene (mixed isomers)', NULL, NULL, 1.0, 0, NULL),
    ('111-76-2', 'Ethylene glycol monobutyl ether', NULL, NULL, 1.0, 0, NULL),
    ('79-01-6', 'Trichloroethylene', NULL, NULL, 0.1, 0, NULL),
    ('127-18-4', 'Tetrachloroethylene (Perc)', NULL, NULL, 0.1, 0, NULL),
    ('71-43-2', 'Benzene', NULL, NULL, 0.1, 0, NULL),
    ('100-41-4', 'Ethylbenzene', NULL, NULL, 0.1, 0, NULL),
    -- Acids
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

-- Fix: MEK was DELISTED from TRI (70 FR 37727, June 30 2005) — remove from list
-- Ontology v3.1 documents this correction. MEK remains an InventoryChemical
-- for EPCRA 311/312 but is NOT a TRI chemical.
DELETE FROM sara313_chemicals WHERE cas_number = '78-93-3';

-- PBT chemicals (ontology: TRIPersistentBioaccumulativeChemical)
-- Lead: 100 lbs, Mercury: 10 lbs, Dioxins: 0.1 grams
UPDATE sara313_chemicals SET is_pbt = 1, pbt_threshold = 100, deminimis_percent = 0.1
    WHERE cas_number = '7439-92-1';
UPDATE sara313_chemicals SET is_pbt = 1, pbt_threshold = 100, deminimis_percent = 0.1
    WHERE cas_number = 'N420';


-- ============================================================================
-- TRI APPLICABILITY DETERMINATIONS (ontology: hasTRIObligation)
-- ============================================================================
-- The three-prong test that determines whether an establishment has TRI
-- reporting obligations. Made auditable — parallel to Module C's
-- recording_decisions. An inspector can see exactly how the facility
-- determined its TRI status for each reporting year.
--
-- Three prongs (ALL must be met):
--   1. Covered NAICS code (manufacturing 31-33, mining, utilities, etc.)
--   2. 10+ full-time equivalent employees
--   3. At least one TRI chemical above activity thresholds

CREATE TABLE IF NOT EXISTS tri_applicability_determinations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    determination_year INTEGER NOT NULL,

    -- Prong 1: Covered NAICS (ontology: hasNAICSCode on Establishment)
    naics_code TEXT NOT NULL,
    is_covered_naics INTEGER NOT NULL,
    naics_notes TEXT,                       -- e.g., "3361xx — Motor Vehicle Manufacturing"

    -- Prong 2: Employee threshold (ontology: hasEstablishmentSize)
    fte_count INTEGER NOT NULL,
    meets_employee_threshold INTEGER NOT NULL,  -- 10+ FTE

    -- Prong 3: Chemical above threshold
    -- Detailed per-chemical determinations are in tri_form_determinations
    has_chemical_above_threshold INTEGER NOT NULL,

    -- Final determination
    is_tri_applicable INTEGER NOT NULL,    -- All three prongs met

    -- Decision metadata
    determined_by TEXT,
    determined_date TEXT,
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, determination_year)
);


-- ============================================================================
-- TRI ANNUAL ACTIVITY (ontology: TRIActivityThreshold evaluation)
-- ============================================================================
-- Tracks how TRI chemicals are manufactured, processed, or otherwise used
-- each year. The activity category determines which threshold applies.

CREATE TABLE IF NOT EXISTS tri_annual_activity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,
    report_year INTEGER NOT NULL,

    sara313_cas TEXT,                       -- CAS or category code

    -- Activity quantities (lbs/year) — ontology: TRIActivityThreshold categories
    quantity_manufactured REAL DEFAULT 0,   -- Produced, prepared, imported, byproduct
    quantity_processed REAL DEFAULT 0,      -- Incorporated into product, repackaged
    quantity_otherwise_used REAL DEFAULT 0, -- Cleaning, maintenance, catalyst, etc.
    quantity_total REAL DEFAULT 0,

    -- Data source for quantities
    data_source TEXT,                       -- inventory_calc, mass_balance, engineering_estimate, direct_measurement
    calculation_notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id),
    UNIQUE(establishment_id, chemical_id, report_year)
);

CREATE INDEX idx_tri_annual_activity_establishment ON tri_annual_activity(establishment_id);
CREATE INDEX idx_tri_annual_activity_year ON tri_annual_activity(report_year);


-- ============================================================================
-- TRI FORM DETERMINATIONS (ontology: requiresFormR / eligibleForFormA)
-- ============================================================================
-- Makes the Form R vs Form A decision auditable. For each TRI chemical
-- above threshold, documents WHY Form R is required or WHY Form A is
-- eligible. This is the TRI equivalent of Module C's recording_decisions.
--
-- Form A eligibility (ontology: TRIFormA):
--   1. Annual reportable amount ≤ 500 lbs total
--   2. Chemical was NOT manufactured (including as byproduct)
--   3. Chemical is NOT a PBT (always requires Form R)

CREATE TABLE IF NOT EXISTS tri_form_determinations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tri_activity_id INTEGER NOT NULL UNIQUE,

    -- Threshold evaluation
    applicable_threshold_lbs REAL NOT NULL,
    is_above_threshold INTEGER NOT NULL,

    -- Form A eligibility criteria (evaluated only if above threshold)
    annual_reportable_amount_lbs REAL,
    is_within_500lb_limit INTEGER,          -- ≤500 lbs total releases + waste mgmt
    was_manufactured INTEGER,               -- Including as byproduct
    is_pbt INTEGER,                         -- PBTs always require Form R

    -- Determination
    eligible_for_form_a INTEGER NOT NULL DEFAULT 0,
    required_form TEXT NOT NULL,            -- 'R' or 'A'

    -- Decision metadata
    determined_by TEXT,
    determined_date TEXT,
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (tri_activity_id) REFERENCES tri_annual_activity(id) ON DELETE CASCADE
);


-- ============================================================================
-- TRI RELEASES & TRANSFERS (ontology: TRIReleaseQuantity)
-- ============================================================================
-- Where the chemical went — releases to environment and off-site transfers.
-- Form R Sections 5 & 6.

CREATE TABLE IF NOT EXISTS tri_releases_transfers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tri_activity_id INTEGER NOT NULL,

    -- ON-SITE RELEASES (Form R Section 5.1-5.4) — all lbs/year

    -- Fugitive Air (ontology: fugitive air emissions)
    fugitive_air_lbs REAL DEFAULT 0,
    fugitive_air_basis TEXT,               -- emission_factor, mass_balance, monitoring

    -- Stack/Point Air (ontology: point source air emissions)
    stack_air_lbs REAL DEFAULT 0,
    stack_air_basis TEXT,

    -- Water Discharges
    discharge_to_potw_lbs REAL DEFAULT 0,
    potw_name TEXT,
    discharge_to_water_lbs REAL DEFAULT 0,
    receiving_water_name TEXT,

    -- Land Disposal (on-site)
    land_disposal_lbs REAL DEFAULT 0,
    land_disposal_method TEXT,

    -- Underground Injection
    underground_injection_lbs REAL DEFAULT 0,
    uic_well_code TEXT,

    -- OFF-SITE TRANSFERS (Form R Section 6)

    transfer_potw_lbs REAL DEFAULT 0,
    transfer_potw_name TEXT,
    transfer_potw_address TEXT,
    transfer_disposal_lbs REAL DEFAULT 0,
    transfer_recycling_lbs REAL DEFAULT 0,
    transfer_energy_recovery_lbs REAL DEFAULT 0,
    transfer_treatment_lbs REAL DEFAULT 0,

    -- WASTE MANAGEMENT (Form R Section 8)

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
-- TRI RELEASE EMISSION UNIT LINK (ontology: releaseFromEmissionUnit)
-- ============================================================================
-- Cross-module link: connects TRI release quantities to the specific
-- emission units (Module B) that generated them. This is the three-way
-- linkage the ontology defines:
--   Chemical inventory (Module A) → Emission unit (Module B) → TRI release (Module A)
--
-- For automotive paint spray booths: the transfer efficiency, capture
-- efficiency, and control device efficiency used in PTE calculations
-- (Module B) directly inform the Form R air release estimates here.

CREATE TABLE IF NOT EXISTS tri_release_emission_units (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tri_releases_id INTEGER NOT NULL,
    emission_unit_id INTEGER,              -- FK to Module B emission_units (nullable until B exists)

    release_medium TEXT NOT NULL,           -- fugitive_air, stack_air, water, land
    quantity_lbs REAL NOT NULL,

    -- Calculation method (same data feeds both PTE and TRI)
    calculation_method TEXT,               -- emission_factor, mass_balance, monitoring, engineering_estimate
    calculation_notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (tri_releases_id) REFERENCES tri_releases_transfers(id) ON DELETE CASCADE
    -- FOREIGN KEY (emission_unit_id) REFERENCES emission_units(id)  -- uncomment when Module B exists
);

CREATE INDEX idx_tri_release_eu_releases ON tri_release_emission_units(tri_releases_id);


-- ============================================================================
-- TRI OFF-SITE FACILITIES (Receiving Facilities)
-- ============================================================================

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
    rcra_id TEXT,
    trifid TEXT,

    -- Facility function
    facility_type TEXT,                    -- potw, recycler, disposal, treatment, energy_recovery
    accepts_chemical_types TEXT,

    contact_name TEXT,
    contact_phone TEXT,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_tri_offsite_facilities_establishment ON tri_offsite_facilities(establishment_id);


-- ============================================================================
-- TRI TRANSFER DETAILS (Links transfers to specific receiving facilities)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tri_transfer_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tri_releases_id INTEGER NOT NULL,
    offsite_facility_id INTEGER NOT NULL,

    transfer_type TEXT NOT NULL,            -- disposal, recycling, energy_recovery, treatment
    quantity_lbs REAL NOT NULL,

    rcra_waste_codes TEXT,                 -- Comma-separated RCRA codes
    treatment_method TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (tri_releases_id) REFERENCES tri_releases_transfers(id) ON DELETE CASCADE,
    FOREIGN KEY (offsite_facility_id) REFERENCES tri_offsite_facilities(id)
);

CREATE INDEX idx_tri_transfer_details_release ON tri_transfer_details(tri_releases_id);
CREATE INDEX idx_tri_transfer_details_facility ON tri_transfer_details(offsite_facility_id);


-- ============================================================================
-- TRI REPORTS (Submitted Form R / Form A — due July 1)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tri_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    report_year INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,
    sara313_cas TEXT NOT NULL,

    -- Form type (ontology: TRIFormR / TRIFormA)
    form_type TEXT NOT NULL,               -- 'R' or 'A'
    form_determination_id INTEGER,         -- Link to auditable form determination

    -- Status
    status TEXT DEFAULT 'draft',           -- draft, submitted, accepted, revised, withdrawn

    -- Submission
    submitted_date TEXT,
    trifid TEXT,
    submission_method TEXT,                -- triMEweb, paper, cdx
    confirmation_number TEXT,

    -- Trade Secret (Form R Section 1.3)
    is_trade_secret INTEGER DEFAULT 0,
    trade_secret_category TEXT,

    -- Certification (Form R Section 1.2)
    certified_by TEXT,
    certified_title TEXT,
    certified_date TEXT,
    certifier_email TEXT,
    certifier_phone TEXT,

    -- Revision
    is_revision INTEGER DEFAULT 0,
    revision_number INTEGER,
    original_report_id INTEGER,
    revision_reason TEXT,

    -- Snapshot of key values at submission
    total_releases_lbs REAL,
    total_transfers_lbs REAL,
    max_onsite_lbs REAL,

    notes TEXT,

    generated_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id),
    FOREIGN KEY (form_determination_id) REFERENCES tri_form_determinations(id),
    FOREIGN KEY (original_report_id) REFERENCES tri_reports(id)
);

CREATE INDEX idx_tri_reports_establishment ON tri_reports(establishment_id);
CREATE INDEX idx_tri_reports_year ON tri_reports(report_year);
CREATE INDEX idx_tri_reports_status ON tri_reports(status);


-- ============================================================================
-- TRI SOURCE REDUCTION (Form R Section 8.10)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tri_source_reduction (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tri_activity_id INTEGER NOT NULL,

    activity_code TEXT NOT NULL,            -- EPA W-codes (W01-W89)
    activity_description TEXT,

    implementation_year INTEGER,
    implementation_status TEXT,             -- implemented, in_progress, planned

    estimated_reduction_lbs REAL,
    estimated_reduction_percent REAL,
    estimation_method TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (tri_activity_id) REFERENCES tri_annual_activity(id) ON DELETE CASCADE
);

CREATE INDEX idx_tri_source_reduction_activity ON tri_source_reduction(tri_activity_id);


-- ============================================================================
-- TRI SOURCE REDUCTION CODES (Reference — EPA W-codes)
-- ============================================================================

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
    ('W21', 'Inventory Control', 'Instituted procedures to ensure materials do not stay in inventory beyond shelf-life'),
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


-- ############################################################################
-- VIEWS
-- ############################################################################


-- Current inventory by chemical (most recent snapshot per location)
CREATE VIEW IF NOT EXISTS v_current_inventory AS
SELECT
    ci.chemical_id,
    c.product_name,
    c.primary_cas_number,
    c.establishment_id,
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


-- Chemicals above Tier II threshold (uses determination table)
CREATE VIEW IF NOT EXISTS v_tier2_reportable AS
SELECT
    c.id AS chemical_id,
    c.product_name,
    c.primary_cas_number,
    c.establishment_id,
    c.is_ehs,
    td.applicable_threshold_lbs,
    td.max_quantity_present_lbs,
    td.is_above_threshold,
    td.exemption_code,
    td.determination_year
FROM chemicals c
INNER JOIN tier2_threshold_determinations td ON c.id = td.chemical_id
WHERE c.is_active = 1
  AND td.is_above_threshold = 1
  AND td.exemption_code IS NULL;


-- SDS review status
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


-- TRI-reportable chemicals (above activity threshold)
CREATE VIEW IF NOT EXISTS v_tri_reportable_chemicals AS
SELECT
    c.id AS chemical_id,
    c.product_name,
    c.primary_cas_number,
    c.establishment_id,
    s.chemical_name AS sara313_name,
    s.category_code,
    s.is_pbt,
    s.deminimis_percent,
    ta.report_year,
    ta.quantity_manufactured,
    ta.quantity_processed,
    ta.quantity_otherwise_used,
    ta.quantity_total,
    fd.applicable_threshold_lbs,
    fd.is_above_threshold,
    fd.required_form,
    fd.eligible_for_form_a
FROM chemicals c
INNER JOIN sara313_chemicals s ON c.primary_cas_number = s.cas_number
    OR c.primary_cas_number = s.category_code
INNER JOIN tri_annual_activity ta ON c.id = ta.chemical_id
LEFT JOIN tri_form_determinations fd ON ta.id = fd.tri_activity_id
WHERE c.is_sara_313 = 1
  AND c.is_active = 1;


-- Pending TRI reports (above threshold, not yet submitted)
CREATE VIEW IF NOT EXISTS v_tri_pending_reports AS
SELECT
    ta.establishment_id,
    ta.report_year,
    c.id AS chemical_id,
    c.product_name,
    c.primary_cas_number,
    ta.quantity_total,
    fd.applicable_threshold_lbs,
    fd.required_form,
    tr.status AS report_status,
    tr.submitted_date
FROM tri_annual_activity ta
INNER JOIN chemicals c ON ta.chemical_id = c.id
INNER JOIN tri_form_determinations fd ON ta.id = fd.tri_activity_id
LEFT JOIN tri_reports tr ON ta.establishment_id = tr.establishment_id
    AND ta.report_year = tr.report_year
    AND ta.chemical_id = tr.chemical_id
WHERE fd.is_above_threshold = 1
  AND (tr.id IS NULL OR tr.status = 'draft');


-- TRI annual summary by establishment
CREATE VIEW IF NOT EXISTS v_tri_annual_summary AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,
    ta.report_year,
    ad.is_tri_applicable,
    COUNT(DISTINCT ta.chemical_id) AS chemicals_tracked,
    SUM(CASE WHEN fd.is_above_threshold = 1 THEN 1 ELSE 0 END) AS chemicals_reportable,
    SUM(ta.quantity_total) AS total_quantity_lbs,
    SUM(rt.fugitive_air_lbs + rt.stack_air_lbs) AS total_air_releases,
    SUM(rt.discharge_to_potw_lbs + rt.discharge_to_water_lbs) AS total_water_releases,
    SUM(rt.land_disposal_lbs) AS total_land_releases,
    SUM(rt.transfer_disposal_lbs + rt.transfer_recycling_lbs +
        rt.transfer_energy_recovery_lbs + rt.transfer_treatment_lbs) AS total_offsite_transfers
FROM establishments e
LEFT JOIN tri_applicability_determinations ad ON e.id = ad.establishment_id
LEFT JOIN tri_annual_activity ta ON e.id = ta.establishment_id
    AND ta.report_year = ad.determination_year
LEFT JOIN tri_form_determinations fd ON ta.id = fd.tri_activity_id
LEFT JOIN tri_releases_transfers rt ON ta.id = rt.tri_activity_id
GROUP BY e.id, ta.report_year;


-- EPCRA notification status (pending actions across all sections)
CREATE VIEW IF NOT EXISTS v_epcra_pending_notifications AS
SELECT
    establishment_id,
    '302' AS epcra_section,
    chemical_id,
    notification_deadline AS deadline,
    status
FROM section302_notifications
WHERE status = 'pending'
UNION ALL
SELECT
    establishment_id,
    '311' AS epcra_section,
    chemical_id,
    notification_deadline AS deadline,
    status
FROM section311_notifications
WHERE status = 'pending'
UNION ALL
SELECT
    establishment_id,
    '304' AS epcra_section,
    chemical_id,
    written_followup_deadline AS deadline,
    status
FROM section304_release_notifications
WHERE status IN ('active', 'followup_pending');
