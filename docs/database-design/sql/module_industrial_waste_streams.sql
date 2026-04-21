-- Module: Industrial Waste Streams (RCRA Hazardous Waste + Industrial Wastewater)
-- Derived from ehs-ontology-v3.1.ttl — ehs:WasteHandlingAction (ActionContext)
-- Connects to EPA_Framework routing via ontology compliance engine.
--
-- This module combines two regulatory programs under a single "industrial waste
-- leaving the facility" concept:
--   1. RCRA Hazardous Waste (40 CFR 260-265, 273, 279) — solid/liquid hazardous
--      waste, universal waste, used oil
--   2. CWA Industrial Wastewater (40 CFR 403, NPDES) — liquid discharge via
--      pretreatment and direct discharge permits
--
-- They share:
--   - The ontology's EPA_Framework (RCRA routing + CWA routing)
--   - The ontology's WasteHandlingAction as the common ActionContext
--   - Monitoring, sampling, limits, compliance tracking patterns
--   - Source chemicals from Module A (ehs:ChemicalSubstance)
--   - Connection to permits module (RCRA permits, NPDES/pretreatment permits)
--
-- Does NOT include stormwater — that remains a separate module (MSGP/CGP
-- have different permit structures, triggers, and inspection patterns).
--
-- Cross-module dependencies:
--   - chemicals (Module A) — source chemicals for waste streams
--   - air_emission_units (Module B) — wastewater can originate from emission unit processes
--   - corrective_actions (Module C/Inspections) — waste container issues, exceedances
--   - incidents (Module C) — spill cleanups generate waste manifests
--   - permits (Permits module) — RCRA permits, NPDES/pretreatment permits


-- ============================================================================
-- PART 1: RCRA HAZARDOUS WASTE MANAGEMENT
-- ============================================================================
-- 40 CFR 260-265: Identification, generation, accumulation, manifesting, disposal
-- 40 CFR 273: Universal Waste Rule
-- 40 CFR 279: Used Oil Management Standards
--
-- Ontology mapping: ehs:WasteHandlingAction → ehs:RCRAWasteGeneration
-- EPA_Framework route: RCRA Subtitle C → Generator Requirements


-- ============================================================================
-- REFERENCE: GENERATOR STATUS LEVELS
-- ============================================================================
-- Formalizes the VSQG/SQG/LQG classification from 40 CFR 262.
-- Generator status determines accumulation time, training requirements,
-- contingency planning, biennial reporting, and emergency procedures.
-- Ontology: ehs:GeneratorStatus subclasses.

CREATE TABLE IF NOT EXISTS generator_status_levels (
    code TEXT PRIMARY KEY,                         -- 'vsqg', 'sqg', 'lqg'
    name TEXT NOT NULL,
    cfr_reference TEXT NOT NULL,

    -- Thresholds (kg/month)
    hazardous_min_kg REAL,                         -- Lower bound (inclusive)
    hazardous_max_kg REAL,                         -- Upper bound (exclusive), NULL = no upper
    acute_hazardous_max_kg REAL,                   -- Acute hazardous threshold (kg/month)

    -- Accumulation rules
    accumulation_limit_days INTEGER,               -- 90, 180, or NULL (VSQG no federal limit)
    accumulation_limit_days_extended INTEGER,       -- 270 for SQG >200mi from TSDF
    satellite_limit_gallons REAL DEFAULT 55.0,     -- SAA limit (same for all)
    max_onsite_quantity_kg REAL,                   -- Max quantity on-site at any time

    -- Requirements by level
    requires_epa_id INTEGER DEFAULT 0,             -- Must have EPA ID number
    requires_manifest INTEGER DEFAULT 0,           -- Must use uniform manifest
    requires_biennial_report INTEGER DEFAULT 0,    -- Must file biennial report
    requires_contingency_plan INTEGER DEFAULT 0,   -- Must have written contingency plan
    requires_personnel_training INTEGER DEFAULT 0, -- Must train waste handlers
    requires_preparedness_prevention INTEGER DEFAULT 0, -- Must meet P&P requirements
    requires_land_disposal_restriction INTEGER DEFAULT 0, -- Must comply with LDR

    -- Exception report deadlines (days after shipment to receive signed copy back)
    exception_report_deadline_days INTEGER,         -- 35 for LQG, 60 for SQG

    description TEXT NOT NULL
);

INSERT OR IGNORE INTO generator_status_levels (code, name, cfr_reference, hazardous_min_kg, hazardous_max_kg, acute_hazardous_max_kg, accumulation_limit_days, accumulation_limit_days_extended, max_onsite_quantity_kg, requires_epa_id, requires_manifest, requires_biennial_report, requires_contingency_plan, requires_personnel_training, requires_preparedness_prevention, requires_land_disposal_restriction, exception_report_deadline_days, description) VALUES
    ('vsqg', 'Very Small Quantity Generator', '40 CFR 262.14',
        0, 100, 1, NULL, NULL, 1000,
        0, 0, 0, 0, 0, 0, 0, NULL,
        'Generates <100 kg/month hazardous waste and <1 kg/month acute hazardous waste. No federal accumulation time limit. Must not exceed 1000 kg on-site. May send waste to RCRA facility or state-approved solid waste facility.'),
    ('sqg', 'Small Quantity Generator', '40 CFR 262.16',
        100, 1000, 1, 180, 270, 6000,
        1, 1, 0, 0, 1, 1, 1, 60,
        'Generates 100-1000 kg/month hazardous waste and <1 kg/month acute hazardous waste. 180-day accumulation (270 if >200 miles from TSDF). Max 6000 kg on-site. Must have EPA ID, use manifests, train personnel, meet preparedness & prevention.'),
    ('lqg', 'Large Quantity Generator', '40 CFR 262.17',
        1000, NULL, NULL, 90, NULL, NULL,
        1, 1, 1, 1, 1, 1, 1, 35,
        'Generates >=1000 kg/month hazardous waste or >1 kg/month acute hazardous waste. 90-day accumulation limit (no extension). No quantity cap on-site. Full RCRA compliance: EPA ID, manifests, biennial report, contingency plan, personnel training, LDR.');


-- ============================================================================
-- REFERENCE: WASTE STREAM TYPES
-- ============================================================================
-- Categorizes waste streams by regulatory program. Used for routing waste
-- handling actions to the correct compliance pathway in the ontology.
-- Ontology: ehs:WasteStreamType subclasses of ehs:WasteHandlingAction.

CREATE TABLE IF NOT EXISTS waste_stream_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    regulatory_program TEXT NOT NULL,              -- 'rcra', 'cwa', 'rcra_universal', 'rcra_used_oil', 'state'
    regulatory_citation TEXT NOT NULL,             -- Primary CFR or statutory citation

    -- Which module tables handle this type
    requires_manifest INTEGER DEFAULT 0,           -- Uses hazardous waste manifest system
    requires_waste_codes INTEGER DEFAULT 0,        -- Needs EPA waste code assignment
    requires_discharge_monitoring INTEGER DEFAULT 0, -- Needs wastewater monitoring/sampling

    -- Generator status relevance
    counts_toward_generator_status INTEGER DEFAULT 0, -- Counts toward VSQG/SQG/LQG determination

    description TEXT NOT NULL
);

INSERT OR IGNORE INTO waste_stream_types (code, name, regulatory_program, regulatory_citation, requires_manifest, requires_waste_codes, requires_discharge_monitoring, counts_toward_generator_status, description) VALUES
    ('hazardous', 'RCRA Hazardous Waste', 'rcra', '40 CFR 261-265',
        1, 1, 0, 1,
        'Waste that is listed (F, K, P, U lists) or exhibits a characteristic (ignitability, corrosivity, reactivity, toxicity). Full RCRA Subtitle C requirements apply.'),
    ('universal', 'Universal Waste', 'rcra_universal', '40 CFR 273',
        0, 0, 0, 0,
        'Batteries, pesticides, mercury-containing equipment, lamps, aerosol cans. Streamlined management standards. Does not count toward generator status. 1-year accumulation limit.'),
    ('used_oil', 'Used Oil', 'rcra_used_oil', '40 CFR 279',
        0, 0, 0, 0,
        'Used oil managed under presumption of recycling. Not hazardous waste unless mixed with hazwaste or fails specification. Simpler management standards than RCRA hazwaste.'),
    ('non_hazardous', 'Non-Hazardous Industrial Waste', 'state', 'State solid waste regulations',
        0, 0, 0, 0,
        'Industrial waste that does not meet RCRA hazardous waste criteria. Regulated under state solid waste programs. Track for waste minimization and cost management.'),
    ('industrial_wastewater', 'Industrial Wastewater Discharge', 'cwa', '40 CFR 403 / CWA Section 402',
        0, 0, 1, 0,
        'Process wastewater discharged to POTW (pretreatment) or directly to waters of the US (NPDES). Regulated under Clean Water Act. Requires monitoring, sampling, and compliance with discharge limits.');


-- ============================================================================
-- REFERENCE: WASTE CODES
-- ============================================================================
-- EPA hazardous waste codes. There are hundreds — this seeds the common ones
-- for manufacturing operations. Users can add more as needed.
-- Ontology: ehs:EPAWasteCode, linked to ehs:RCRAWasteGeneration.

CREATE TABLE IF NOT EXISTS waste_codes (
    code TEXT PRIMARY KEY,

    -- Code classification
    code_type TEXT NOT NULL,                    -- listed_f, listed_k, listed_p, listed_u, characteristic

    -- Description
    waste_name TEXT NOT NULL,
    description TEXT,

    -- Hazard info
    hazard_codes TEXT,                          -- H, T, R, I, C, E (can have multiple)
    basis_for_listing TEXT,                     -- For listed wastes

    -- LDR info
    ldr_subcategory TEXT,
    treatment_standard TEXT,

    is_acute_hazardous INTEGER DEFAULT 0,       -- P-list and some F-list are acute

    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_waste_codes_type ON waste_codes(code_type);


-- ============================================================================
-- WASTE CODES SEED DATA
-- ============================================================================
-- Focused on manufacturing operations. Full EPA list has 500+ codes.

-- Characteristic Wastes (D-codes)
INSERT OR IGNORE INTO waste_codes (code, code_type, waste_name, hazard_codes, is_acute_hazardous) VALUES
    ('D001', 'characteristic', 'Ignitable waste', 'I', 0),
    ('D002', 'characteristic', 'Corrosive waste', 'C', 0),
    ('D003', 'characteristic', 'Reactive waste', 'R', 0),
    ('D004', 'characteristic', 'Arsenic', 'T', 0),
    ('D005', 'characteristic', 'Barium', 'T', 0),
    ('D006', 'characteristic', 'Cadmium', 'T', 0),
    ('D007', 'characteristic', 'Chromium', 'T', 0),
    ('D008', 'characteristic', 'Lead', 'T', 0),
    ('D009', 'characteristic', 'Mercury', 'T', 0),
    ('D010', 'characteristic', 'Selenium', 'T', 0),
    ('D011', 'characteristic', 'Silver', 'T', 0),
    ('D018', 'characteristic', 'Benzene', 'T', 0),
    ('D019', 'characteristic', 'Carbon tetrachloride', 'T', 0),
    ('D021', 'characteristic', 'Chlorobenzene', 'T', 0),
    ('D022', 'characteristic', 'Chloroform', 'T', 0),
    ('D035', 'characteristic', 'Methyl ethyl ketone (MEK)', 'T', 0),
    ('D039', 'characteristic', 'Tetrachloroethylene (Perc)', 'T', 0),
    ('D040', 'characteristic', 'Trichloroethylene (TCE)', 'T', 0);

-- F-List (Non-specific source wastes) - Common in manufacturing
INSERT OR IGNORE INTO waste_codes (code, code_type, waste_name, hazard_codes, basis_for_listing, is_acute_hazardous) VALUES
    ('F001', 'listed_f', 'Spent halogenated degreasing solvents', 'T',
        'Tetrachloroethylene, trichloroethylene, methylene chloride, 1,1,1-trichloroethane, carbon tetrachloride, chlorinated fluorocarbons', 0),
    ('F002', 'listed_f', 'Spent halogenated solvents', 'T',
        'Tetrachloroethylene, methylene chloride, trichloroethylene, 1,1,1-trichloroethane, chlorobenzene, 1,1,2-trichloro-1,2,2-trifluoroethane, ortho-dichlorobenzene, trichlorofluoromethane, 1,1,2-trichloroethane', 0),
    ('F003', 'listed_f', 'Spent non-halogenated solvents', 'I',
        'Xylene, acetone, ethyl acetate, ethyl benzene, ethyl ether, methyl isobutyl ketone, n-butyl alcohol, cyclohexanone, methanol', 0),
    ('F004', 'listed_f', 'Spent non-halogenated solvents', 'T',
        'Cresols, cresylic acid, nitrobenzene', 0),
    ('F005', 'listed_f', 'Spent non-halogenated solvents', 'I,T',
        'Toluene, methyl ethyl ketone, carbon disulfide, isobutanol, pyridine, benzene, 2-ethoxyethanol, 2-nitropropane', 0),
    ('F006', 'listed_f', 'Wastewater treatment sludge from electroplating', 'T',
        'Cadmium, hexavalent chromium, nickel, cyanide', 0),
    ('F007', 'listed_f', 'Spent cyanide plating bath solutions', 'R,T',
        'Cyanide', 0),
    ('F008', 'listed_f', 'Plating bath residues from cyanide plating', 'R,T',
        'Cyanide', 0),
    ('F009', 'listed_f', 'Spent stripping and cleaning bath solutions from electroplating (cyanide)', 'R,T',
        'Cyanide', 0),
    ('F010', 'listed_f', 'Quenching bath residues from metal heat treating (cyanide)', 'R,T',
        'Cyanide', 0),
    ('F011', 'listed_f', 'Spent cyanide solutions from salt bath pot cleaning', 'R,T',
        'Cyanide', 0),
    ('F012', 'listed_f', 'Quenching wastewater treatment sludge from metal heat treating (cyanide)', 'T',
        'Cyanide', 0),
    ('F019', 'listed_f', 'Wastewater treatment sludge from aluminum conversion coating', 'T',
        'Hexavalent chromium', 0);

-- K-List (Source-specific wastes) - Selected manufacturing codes
INSERT OR IGNORE INTO waste_codes (code, code_type, waste_name, hazard_codes, basis_for_listing, is_acute_hazardous) VALUES
    ('K001', 'listed_k', 'Bottom sediment sludge from wood preserving (creosote)', 'T', 'Creosote', 0),
    ('K062', 'listed_k', 'Spent pickle liquor from steel finishing', 'C,T', 'Hexavalent chromium, lead', 0);


-- ============================================================================
-- WASTE STREAMS
-- ============================================================================
-- Defines the types of waste the facility generates.
-- A waste stream is a recurring type of waste from a specific process.
-- Ontology: ehs:WasteStream, child of ehs:WasteHandlingAction context.

CREATE TABLE IF NOT EXISTS waste_streams (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Identification
    stream_code TEXT,                           -- Internal code (e.g., 'WS-001')
    stream_name TEXT NOT NULL,                 -- Descriptive name
    description TEXT,

    -- Source
    generating_process TEXT,                    -- What process creates this waste
    source_location TEXT,                       -- Where it's generated
    source_chemical_id INTEGER,                -- Cross-module FK → chemicals (Module A)

    -- Waste Classification
    waste_category TEXT NOT NULL,               -- hazardous, universal, used_oil, non_hazardous, special
    waste_stream_type_code TEXT,                -- FK → waste_stream_types

    -- Physical properties
    physical_form TEXT,                         -- solid, liquid, sludge, gas, debris
    typical_quantity_per_month REAL,            -- Expected generation rate
    quantity_unit TEXT DEFAULT 'kg',            -- kg, lbs, gallons, drums

    -- Hazard characteristics (for quick reference - detail in waste_stream_codes)
    is_ignitable INTEGER DEFAULT 0,
    is_corrosive INTEGER DEFAULT 0,
    is_reactive INTEGER DEFAULT 0,
    is_toxic INTEGER DEFAULT 0,
    is_acute_hazardous INTEGER DEFAULT 0,       -- P-list or acute F-list

    -- Handling requirements
    handling_instructions TEXT,
    ppe_required TEXT,
    incompatible_with TEXT,                     -- What it can't be stored with

    -- Profile info (for TSDF approval)
    profile_number TEXT,                        -- Waste profile/approval number
    profile_expiration TEXT,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (source_chemical_id) REFERENCES chemicals(id),
    FOREIGN KEY (waste_stream_type_code) REFERENCES waste_stream_types(code)
);

CREATE INDEX idx_waste_streams_establishment ON waste_streams(establishment_id);
CREATE INDEX idx_waste_streams_category ON waste_streams(waste_category);
CREATE INDEX idx_waste_streams_type ON waste_streams(waste_stream_type_code);


-- ============================================================================
-- WASTE STREAM CODES (Junction Table)
-- ============================================================================
-- Links waste streams to their applicable EPA waste codes.
-- A single waste stream can have multiple codes (mixture rule, etc.)

CREATE TABLE IF NOT EXISTS waste_stream_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    waste_stream_id INTEGER NOT NULL,
    waste_code TEXT NOT NULL,

    -- How this code applies
    is_primary INTEGER DEFAULT 0,               -- Primary code for this stream
    basis TEXT,                                 -- Why this code applies (generator knowledge, testing, etc.)

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (waste_stream_id) REFERENCES waste_streams(id) ON DELETE CASCADE,
    FOREIGN KEY (waste_code) REFERENCES waste_codes(code),
    UNIQUE(waste_stream_id, waste_code)
);

CREATE INDEX idx_waste_stream_codes_stream ON waste_stream_codes(waste_stream_id);
CREATE INDEX idx_waste_stream_codes_code ON waste_stream_codes(waste_code);


-- ============================================================================
-- ACCUMULATION AREAS
-- ============================================================================
-- Tracks designated waste accumulation areas.
-- Critical for RCRA compliance — different rules for SAA vs CAA.
-- Ontology: ehs:AccumulationArea, constrained by ehs:GeneratorStatus.

CREATE TABLE IF NOT EXISTS accumulation_areas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Identification
    area_code TEXT,                             -- Internal code
    area_name TEXT NOT NULL,

    -- Type determines rules
    area_type TEXT NOT NULL,                    -- satellite, central_90day, central_180day, central_270day

    -- Location
    building TEXT,
    room TEXT,
    location_description TEXT,

    -- Capacity
    max_containers INTEGER,
    max_volume_gallons REAL,

    -- Requirements based on area type
    accumulation_limit_days INTEGER,            -- Max days waste can stay
    volume_limit_gallons REAL,                  -- Max volume (55 gal for SAA)

    -- Inspection schedule
    inspection_frequency TEXT,                  -- daily, weekly (SAA=weekly, CAA varies)
    last_inspection_date TEXT,
    next_inspection_date TEXT,

    -- Secondary containment
    has_secondary_containment INTEGER DEFAULT 0,
    containment_capacity_gallons REAL,

    -- Emergency equipment
    has_fire_extinguisher INTEGER DEFAULT 0,
    has_spill_kit INTEGER DEFAULT 0,
    has_eyewash INTEGER DEFAULT 0,
    has_communication_device INTEGER DEFAULT 0,

    -- For SAA - link to generating process location
    generating_process TEXT,
    is_under_operator_control INTEGER DEFAULT 1,  -- SAA requirement

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_accumulation_areas_establishment ON accumulation_areas(establishment_id);
CREATE INDEX idx_accumulation_areas_type ON accumulation_areas(area_type);


-- ============================================================================
-- WASTE CONTAINERS
-- ============================================================================
-- Individual containers of waste. This is the heart of accumulation tracking.
-- Each container tracks its start date for the 90/180/270 day clock.
-- Ontology: ehs:WasteContainer, time-constrained by ehs:AccumulationTimeLimit.

CREATE TABLE IF NOT EXISTS waste_containers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    waste_stream_id INTEGER NOT NULL,
    accumulation_area_id INTEGER,               -- NULL if shipped/disposed

    -- Cross-module FK: corrective action that generated this container
    -- (e.g., spill cleanup generates waste containers)
    corrective_action_id INTEGER,               -- FK → corrective_actions

    -- Container identification
    container_number TEXT,                      -- Internal tracking number
    container_type TEXT,                        -- drum_55, drum_30, tote, pail_5, other

    -- Contents
    quantity REAL,
    quantity_unit TEXT DEFAULT 'gallons',
    is_full INTEGER DEFAULT 0,                  -- Container is full/closed

    -- THE CRITICAL DATES
    accumulation_start_date TEXT,               -- When waste first added (starts the clock)
    must_ship_by_date TEXT,                     -- Calculated: start + limit days

    -- Status tracking
    status TEXT DEFAULT 'open',                 -- open, closed, in_transit, shipped, disposed

    -- Closed container info
    closed_date TEXT,                           -- When container was sealed
    closed_by TEXT,

    -- Labeling compliance
    is_labeled INTEGER DEFAULT 0,
    label_date TEXT,
    label_contents TEXT,                        -- What's written on label
    has_hazard_warning INTEGER DEFAULT 0,
    has_accumulation_date INTEGER DEFAULT 0,

    -- Condition tracking
    condition TEXT DEFAULT 'good',              -- good, minor_damage, leaking, deteriorating
    last_condition_check TEXT,

    -- Movement tracking
    moved_to_caa_date TEXT,                     -- If started in SAA, when moved to CAA

    -- Shipment info (when shipped)
    manifest_id INTEGER,                        -- Link to manifest when shipped
    shipped_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (waste_stream_id) REFERENCES waste_streams(id),
    FOREIGN KEY (accumulation_area_id) REFERENCES accumulation_areas(id),
    FOREIGN KEY (corrective_action_id) REFERENCES corrective_actions(id),
    FOREIGN KEY (manifest_id) REFERENCES waste_manifests(id)
);

CREATE INDEX idx_waste_containers_establishment ON waste_containers(establishment_id);
CREATE INDEX idx_waste_containers_stream ON waste_containers(waste_stream_id);
CREATE INDEX idx_waste_containers_area ON waste_containers(accumulation_area_id);
CREATE INDEX idx_waste_containers_status ON waste_containers(status);
CREATE INDEX idx_waste_containers_ship_date ON waste_containers(must_ship_by_date);
CREATE INDEX idx_waste_containers_corrective_action ON waste_containers(corrective_action_id);


-- ============================================================================
-- WASTE RECEIVING FACILITIES (TSDFs)
-- ============================================================================
-- Treatment, Storage, and Disposal Facilities that receive your waste.
-- Separate from TRI facilities because different info is required.

CREATE TABLE IF NOT EXISTS waste_facilities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Identification
    facility_name TEXT NOT NULL,
    epa_id TEXT,                                -- EPA hazardous waste ID (required for RCRA)
    state_id TEXT,                              -- State-specific ID if applicable

    -- Location
    street_address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    county TEXT,

    -- Contact
    contact_name TEXT,
    contact_phone TEXT,
    contact_email TEXT,
    emergency_phone TEXT,

    -- What they do
    facility_type TEXT,                         -- tsdf, recycler, fuel_blender, transfer_station, used_oil_processor

    -- Capabilities (what waste codes they accept)
    accepted_waste_codes TEXT,                  -- Comma-separated or JSON

    -- Permits
    rcra_permit_number TEXT,
    permit_expiration TEXT,

    -- For used oil
    is_used_oil_marketer INTEGER DEFAULT 0,
    used_oil_registration TEXT,

    -- Distance (affects SQG accumulation time)
    distance_miles REAL,

    -- Link to TRI facility if same facility used for both
    tri_facility_id INTEGER,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (tri_facility_id) REFERENCES tri_offsite_facilities(id)
);

CREATE INDEX idx_waste_facilities_establishment ON waste_facilities(establishment_id);
CREATE INDEX idx_waste_facilities_epa_id ON waste_facilities(epa_id);


-- ============================================================================
-- WASTE MANIFESTS
-- ============================================================================
-- Uniform Hazardous Waste Manifest (EPA Form 8700-22)
-- The manifest tracks waste from cradle to grave.
-- Ontology: ehs:WasteManifest, part of ehs:WasteHandlingAction lifecycle.

CREATE TABLE IF NOT EXISTS waste_manifests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Cross-module FK: incident that generated this waste
    -- (e.g., spill cleanup, remediation generates manifested waste)
    incident_id INTEGER,                        -- FK → incidents

    -- Manifest identification
    manifest_tracking_number TEXT UNIQUE,       -- EPA tracking number (e.g., 012345678JJK)

    -- Generator info (Section 1-5)
    generator_name TEXT NOT NULL,
    generator_site_address TEXT,
    generator_mailing_address TEXT,
    generator_epa_id TEXT NOT NULL,
    generator_phone TEXT,
    emergency_phone TEXT,

    -- Transporter info (Sections 6-7)
    transporter1_company TEXT,
    transporter1_epa_id TEXT,
    transporter2_company TEXT,
    transporter2_epa_id TEXT,

    -- Designated facility (Section 8)
    designated_facility_id INTEGER,
    designated_facility_name TEXT,
    designated_facility_address TEXT,
    designated_facility_epa_id TEXT,

    -- Alternate facility (if rejected)
    alternate_facility_id INTEGER,

    -- Shipment details
    shipment_date TEXT,                         -- Date waste left generator

    -- Special handling (Section 14)
    special_handling TEXT,

    -- Generator certification (Section 15)
    generator_printed_name TEXT,
    generator_signature_date TEXT,
    waste_minimization_code TEXT,               -- A, B, C, D, or N

    -- International shipment (Section 16)
    is_import INTEGER DEFAULT 0,
    is_export INTEGER DEFAULT 0,
    port_of_entry_exit TEXT,

    -- Status tracking
    status TEXT DEFAULT 'draft',                -- draft, signed, in_transit, delivered, exception, complete

    -- Copy tracking (generator keeps copy after each signature)
    transporter1_signed_date TEXT,
    transporter2_signed_date TEXT,
    facility_signed_date TEXT,                  -- When TSDF received

    -- Copy 3 return (TSDF sends back signed copy within 30 days)
    copy3_received_date TEXT,
    copy3_discrepancy INTEGER DEFAULT 0,
    discrepancy_notes TEXT,

    -- Exception report (if copy not received in 35/60 days)
    exception_report_needed INTEGER DEFAULT 0,
    exception_report_filed_date TEXT,

    -- e-Manifest
    is_emanifest INTEGER DEFAULT 0,
    emanifest_confirmation TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (incident_id) REFERENCES incidents(id),
    FOREIGN KEY (designated_facility_id) REFERENCES waste_facilities(id),
    FOREIGN KEY (alternate_facility_id) REFERENCES waste_facilities(id)
);

CREATE INDEX idx_waste_manifests_establishment ON waste_manifests(establishment_id);
CREATE INDEX idx_waste_manifests_tracking ON waste_manifests(manifest_tracking_number);
CREATE INDEX idx_waste_manifests_date ON waste_manifests(shipment_date);
CREATE INDEX idx_waste_manifests_status ON waste_manifests(status);
CREATE INDEX idx_waste_manifests_incident ON waste_manifests(incident_id);


-- ============================================================================
-- MANIFEST LINE ITEMS (Sections 9-12)
-- ============================================================================
-- Each manifest can list multiple waste streams.

CREATE TABLE IF NOT EXISTS manifest_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    manifest_id INTEGER NOT NULL,
    line_number INTEGER NOT NULL,               -- 1, 2, 3, etc. on the manifest

    -- Waste identification (Section 9)
    waste_stream_id INTEGER,                    -- Link to our waste stream
    dot_shipping_name TEXT NOT NULL,            -- DOT proper shipping name
    dot_hazard_class TEXT,                      -- DOT hazard class
    dot_id_number TEXT,                         -- UN or NA number
    packing_group TEXT,                         -- I, II, or III

    -- EPA waste codes (Section 13)
    -- Stored as comma-separated, links to waste_stream_codes
    epa_waste_codes TEXT NOT NULL,

    -- Containers (Section 10)
    container_count INTEGER NOT NULL,
    container_type TEXT,                        -- DM=drum, CY=cylinder, etc.

    -- Quantity (Section 11)
    quantity REAL NOT NULL,
    quantity_unit TEXT NOT NULL,                -- G=gallons, P=pounds, K=kilograms, etc.

    -- Special handling for this waste
    special_handling TEXT,

    -- Link to actual containers shipped
    container_ids TEXT,                         -- Comma-separated container IDs

    -- Receiving facility discrepancy (if any)
    quantity_received REAL,
    discrepancy_type TEXT,                      -- quantity, waste_type, none
    discrepancy_resolution TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (manifest_id) REFERENCES waste_manifests(id) ON DELETE CASCADE,
    FOREIGN KEY (waste_stream_id) REFERENCES waste_streams(id)
);

CREATE INDEX idx_manifest_items_manifest ON manifest_items(manifest_id);
CREATE INDEX idx_manifest_items_stream ON manifest_items(waste_stream_id);


-- ============================================================================
-- LDR NOTIFICATIONS
-- ============================================================================
-- Land Disposal Restriction notifications sent to TSDFs.
-- Required when shipping hazardous waste subject to LDR.

CREATE TABLE IF NOT EXISTS ldr_notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    waste_stream_id INTEGER NOT NULL,
    receiving_facility_id INTEGER NOT NULL,

    -- Notification type
    notification_type TEXT NOT NULL,            -- one_time, first_shipment, annual_update

    -- Waste identification
    waste_description TEXT NOT NULL,
    epa_waste_codes TEXT NOT NULL,

    -- Constituent concentrations (if applicable)
    constituent_data TEXT,                      -- JSON: [{name, concentration, unit}]

    -- Treatment standard
    treatment_standard TEXT,                    -- What standard applies
    underlying_hazardous_constituents TEXT,     -- UHCs if applicable

    -- Generator certification
    certification_statement TEXT,               -- The LDR certification language
    certified_by TEXT,
    certification_date TEXT,

    -- Tracking
    sent_date TEXT,
    sent_method TEXT,                           -- mail, email, with_manifest

    acknowledgment_received INTEGER DEFAULT 0,
    acknowledgment_date TEXT,

    -- Link to manifest if sent with shipment
    manifest_id INTEGER,

    -- Expiration (some need annual renewal)
    expiration_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (waste_stream_id) REFERENCES waste_streams(id),
    FOREIGN KEY (receiving_facility_id) REFERENCES waste_facilities(id),
    FOREIGN KEY (manifest_id) REFERENCES waste_manifests(id)
);

CREATE INDEX idx_ldr_notifications_establishment ON ldr_notifications(establishment_id);
CREATE INDEX idx_ldr_notifications_stream ON ldr_notifications(waste_stream_id);
CREATE INDEX idx_ldr_notifications_facility ON ldr_notifications(receiving_facility_id);


-- ============================================================================
-- GENERATOR STATUS TRACKING (Monthly)
-- ============================================================================
-- Tracks monthly waste generation to determine generator status.
-- Status determines: accumulation time, training, contingency plan, biennial report.
-- References generator_status_levels for threshold lookups.

CREATE TABLE IF NOT EXISTS generator_status_monthly (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    year INTEGER NOT NULL,
    month INTEGER NOT NULL,                     -- 1-12

    -- Quantities generated this month (kg)
    hazardous_waste_kg REAL DEFAULT 0,
    acute_hazardous_kg REAL DEFAULT 0,          -- P-list and acute F-list (much lower threshold)

    -- Calculated status for this month
    generator_status TEXT,                      -- FK → generator_status_levels.code

    -- Running totals for the calendar year (for biennial report)
    ytd_hazardous_kg REAL DEFAULT 0,
    ytd_acute_kg REAL DEFAULT 0,

    -- Maximum accumulation this month
    max_accumulated_kg REAL,
    max_acute_accumulated_kg REAL,

    -- Any status change?
    status_changed INTEGER DEFAULT 0,
    previous_status TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (generator_status) REFERENCES generator_status_levels(code),
    UNIQUE(establishment_id, year, month)
);

CREATE INDEX idx_generator_status_establishment ON generator_status_monthly(establishment_id);
CREATE INDEX idx_generator_status_period ON generator_status_monthly(year, month);


-- ============================================================================
-- UNIVERSAL WASTE
-- ============================================================================
-- Batteries, lamps, pesticides, mercury equipment, aerosols.
-- Simpler rules than hazardous waste but still regulated under 40 CFR 273.

CREATE TABLE IF NOT EXISTS universal_waste (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    accumulation_area_id INTEGER,

    -- Type
    waste_type TEXT NOT NULL,                   -- batteries, lamps, pesticides, mercury_equipment, aerosols, electronics

    -- Description
    description TEXT,

    -- Accumulation tracking (1 year limit for SQHUWs, no limit for LQHUWs)
    accumulation_start_date TEXT NOT NULL,
    must_ship_by_date TEXT,                     -- start + 365 days

    -- Quantity
    quantity REAL,
    quantity_unit TEXT,                         -- each, lbs, kg, drums

    -- Container/storage
    container_description TEXT,
    is_labeled INTEGER DEFAULT 0,
    label_text TEXT,

    -- Status
    status TEXT DEFAULT 'accumulating',         -- accumulating, shipped, disposed

    -- Shipment
    shipped_date TEXT,
    shipped_to TEXT,
    shipping_document TEXT,                     -- Not a manifest, just bill of lading

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (accumulation_area_id) REFERENCES accumulation_areas(id)
);

CREATE INDEX idx_universal_waste_establishment ON universal_waste(establishment_id);
CREATE INDEX idx_universal_waste_type ON universal_waste(waste_type);
CREATE INDEX idx_universal_waste_status ON universal_waste(status);
CREATE INDEX idx_universal_waste_ship_date ON universal_waste(must_ship_by_date);


-- ============================================================================
-- USED OIL CONTAINERS
-- ============================================================================
-- Managed under 40 CFR 279 — simpler than hazardous waste if properly managed.
-- Becomes hazardous waste if mixed with hazwaste or fails specifications.

CREATE TABLE IF NOT EXISTS used_oil_containers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Container identification
    container_number TEXT,
    container_type TEXT,                        -- tank, drum_55, tote
    location TEXT,

    -- Capacity and level
    capacity_gallons REAL,
    current_quantity_gallons REAL DEFAULT 0,

    -- Testing/Specification
    last_tested_date TEXT,
    meets_specification INTEGER,                -- 1=on-spec, 0=off-spec, NULL=untested
    halogen_ppm REAL,                           -- <1000 ppm to presume not mixed
    flash_point_f REAL,                         -- Must be >100 F
    total_halogens_ppm REAL,
    arsenic_ppm REAL,
    cadmium_ppm REAL,
    chromium_ppm REAL,
    lead_ppm REAL,

    -- If off-spec or mixed, becomes hazardous
    is_mixed_with_hazwaste INTEGER DEFAULT 0,
    mixed_waste_description TEXT,

    -- Labeling
    is_labeled INTEGER DEFAULT 0,               -- Must say "Used Oil"

    -- Status
    status TEXT DEFAULT 'in_use',               -- in_use, full, shipped, disposed

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_used_oil_establishment ON used_oil_containers(establishment_id);
CREATE INDEX idx_used_oil_status ON used_oil_containers(status);


-- ============================================================================
-- USED OIL SHIPMENTS
-- ============================================================================
-- Track pickups by used oil haulers/recyclers.

CREATE TABLE IF NOT EXISTS used_oil_shipments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Shipment details
    shipment_date TEXT NOT NULL,
    quantity_gallons REAL NOT NULL,

    -- Hauler/Transporter
    hauler_company TEXT NOT NULL,
    hauler_epa_id TEXT,                         -- If applicable
    hauler_registration TEXT,
    driver_name TEXT,

    -- Receiving facility
    receiving_facility_id INTEGER,
    receiving_facility_name TEXT,

    -- Documentation
    bill_of_lading TEXT,
    manifest_number TEXT,                       -- Only if off-spec/mixed

    -- Certification (generator must sign)
    certified_by TEXT,
    certification_date TEXT,

    -- Which containers were emptied
    container_ids TEXT,                         -- Comma-separated IDs

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (receiving_facility_id) REFERENCES waste_facilities(id)
);

CREATE INDEX idx_used_oil_shipments_establishment ON used_oil_shipments(establishment_id);
CREATE INDEX idx_used_oil_shipments_date ON used_oil_shipments(shipment_date);


-- ============================================================================
-- WASTE AREA INSPECTIONS
-- ============================================================================
-- Required inspections of accumulation areas and containers.
-- SAA: Weekly or at each use (per 262.15)
-- CAA: Weekly for containers, daily for tanks (per 265.174)

CREATE TABLE IF NOT EXISTS waste_inspections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    accumulation_area_id INTEGER,

    -- Inspection details
    inspection_date TEXT NOT NULL,
    inspection_type TEXT,                       -- routine, initial, corrective_followup
    inspector_name TEXT NOT NULL,

    -- What was inspected
    containers_inspected INTEGER DEFAULT 0,

    -- Container checklist
    containers_labeled INTEGER DEFAULT 1,
    containers_dated INTEGER DEFAULT 1,
    containers_closed INTEGER DEFAULT 1,
    containers_good_condition INTEGER DEFAULT 1,

    -- Area checklist
    area_clean INTEGER DEFAULT 1,
    aisle_space_adequate INTEGER DEFAULT 1,
    secondary_containment_ok INTEGER DEFAULT 1,
    emergency_equipment_ok INTEGER DEFAULT 1,
    spill_kit_stocked INTEGER DEFAULT 1,

    -- Findings
    deficiencies_found INTEGER DEFAULT 0,
    deficiency_description TEXT,

    -- Corrective action
    corrective_action_needed INTEGER DEFAULT 0,
    corrective_action_description TEXT,
    corrective_action_due_date TEXT,
    corrective_action_completed INTEGER DEFAULT 0,
    corrective_action_completed_date TEXT,
    corrective_action_completed_by TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (accumulation_area_id) REFERENCES accumulation_areas(id)
);

CREATE INDEX idx_waste_inspections_establishment ON waste_inspections(establishment_id);
CREATE INDEX idx_waste_inspections_area ON waste_inspections(accumulation_area_id);
CREATE INDEX idx_waste_inspections_date ON waste_inspections(inspection_date);


-- ============================================================================
-- PART 2: INDUSTRIAL WASTEWATER MONITORING — RELOCATED 2026-04-21
-- ============================================================================
-- The ww_* tables (monitoring locations, parameters, monitoring requirements,
-- equipment, calibrations, labs, lab submissions, sampling events, sample
-- results, flow measurements) have moved to module_d_clean_water.sql to
-- match the v3.2 ontology's Module D (Clean Water Act) scope. The companion
-- views and the equipment-calibration trigger moved with them.
--
-- CWA-distinctive tables also expanded there: discharge_points (physical
-- outfalls, ehs:DischargePoint), sw_swpps (SWPPP documents), sw_bmps (BMP
-- catalog), sw_outfall_benchmarks (MSGP benchmark values), plus two new
-- reference tables (water_pollutant_types and sw_industrial_sectors) and
-- a pollutant_type_code discriminator on ww_parameters.
--
-- This file now focuses on what it was originally named for: RCRA / hazardous
-- waste / manifest tracking.


-- ============================================================================
-- PART 3: VIEWS — RCRA HAZARDOUS WASTE
-- ============================================================================


-- ----------------------------------------------------------------------------
-- v_generator_status_current
-- ----------------------------------------------------------------------------
-- Determines current generator status based on recent activity.
-- Uses highest status from last 12 months (once LQG, harder to drop back).

CREATE VIEW IF NOT EXISTS v_generator_status_current AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,
    e.naics_code,

    -- Most recent month's data
    gsm.year AS current_year,
    gsm.month AS current_month,
    gsm.hazardous_waste_kg AS current_month_kg,
    gsm.generator_status AS current_month_status,

    -- Determine effective status (highest in last 12 months for most requirements)
    (SELECT MAX(CASE gs2.generator_status
        WHEN 'lqg' THEN 3
        WHEN 'sqg' THEN 2
        WHEN 'vsqg' THEN 1
        ELSE 0 END)
     FROM generator_status_monthly gs2
     WHERE gs2.establishment_id = e.id
       AND (gs2.year * 12 + gs2.month) >= (gsm.year * 12 + gsm.month - 11)
    ) AS status_level,

    CASE (SELECT MAX(CASE gs2.generator_status
        WHEN 'lqg' THEN 3
        WHEN 'sqg' THEN 2
        WHEN 'vsqg' THEN 1
        ELSE 0 END)
     FROM generator_status_monthly gs2
     WHERE gs2.establishment_id = e.id
       AND (gs2.year * 12 + gs2.month) >= (gsm.year * 12 + gsm.month - 11))
        WHEN 3 THEN 'lqg'
        WHEN 2 THEN 'sqg'
        WHEN 1 THEN 'vsqg'
        ELSE 'unknown'
    END AS effective_status,

    -- Accumulation time limits based on status (from generator_status_levels)
    CASE (SELECT MAX(CASE gs2.generator_status
        WHEN 'lqg' THEN 3
        WHEN 'sqg' THEN 2
        WHEN 'vsqg' THEN 1
        ELSE 0 END)
     FROM generator_status_monthly gs2
     WHERE gs2.establishment_id = e.id
       AND (gs2.year * 12 + gs2.month) >= (gsm.year * 12 + gsm.month - 11))
        WHEN 3 THEN 90
        WHEN 2 THEN 180   -- Could be 270 if >200 miles from TSDF
        WHEN 1 THEN NULL  -- VSQG no time limit
        ELSE NULL
    END AS accumulation_limit_days

FROM establishments e
LEFT JOIN generator_status_monthly gsm ON e.id = gsm.establishment_id
WHERE gsm.id = (
    SELECT gsm2.id FROM generator_status_monthly gsm2
    WHERE gsm2.establishment_id = e.id
    ORDER BY gsm2.year DESC, gsm2.month DESC
    LIMIT 1
)
OR gsm.id IS NULL;


-- ----------------------------------------------------------------------------
-- v_containers_approaching_deadline
-- ----------------------------------------------------------------------------
-- Containers that need to be shipped soon or are overdue.
-- This is a primary compliance alert view.

CREATE VIEW IF NOT EXISTS v_containers_approaching_deadline AS
SELECT
    wc.id AS container_id,
    wc.container_number,
    wc.establishment_id,
    e.name AS establishment_name,
    ws.stream_name AS waste_stream,
    aa.area_name AS accumulation_area,
    aa.area_type,
    wc.accumulation_start_date,
    wc.must_ship_by_date,
    wc.quantity,
    wc.quantity_unit,
    wc.status,
    CAST(julianday(wc.must_ship_by_date) - julianday('now') AS INTEGER) AS days_remaining,
    CASE
        WHEN date(wc.must_ship_by_date) < date('now') THEN 'OVERDUE'
        WHEN date(wc.must_ship_by_date) < date('now', '+7 days') THEN 'CRITICAL'
        WHEN date(wc.must_ship_by_date) < date('now', '+14 days') THEN 'URGENT'
        WHEN date(wc.must_ship_by_date) < date('now', '+30 days') THEN 'APPROACHING'
        ELSE 'OK'
    END AS urgency
FROM waste_containers wc
INNER JOIN establishments e ON wc.establishment_id = e.id
INNER JOIN waste_streams ws ON wc.waste_stream_id = ws.id
LEFT JOIN accumulation_areas aa ON wc.accumulation_area_id = aa.id
WHERE wc.status IN ('open', 'closed')
  AND wc.must_ship_by_date IS NOT NULL
  AND date(wc.must_ship_by_date) < date('now', '+30 days')
ORDER BY wc.must_ship_by_date ASC;


-- ----------------------------------------------------------------------------
-- v_saa_volume_status
-- ----------------------------------------------------------------------------
-- Satellite accumulation areas — alerts when approaching 55 gallon limit.

CREATE VIEW IF NOT EXISTS v_saa_volume_status AS
SELECT
    aa.id AS area_id,
    aa.area_code,
    aa.area_name,
    aa.establishment_id,
    aa.generating_process,
    SUM(wc.quantity) AS current_quantity_gallons,
    55.0 AS limit_gallons,
    ROUND(100.0 * SUM(wc.quantity) / 55.0, 1) AS percent_full,
    CASE
        WHEN SUM(wc.quantity) >= 55 THEN 'FULL - MUST MOVE TO CAA'
        WHEN SUM(wc.quantity) >= 50 THEN 'ALMOST FULL'
        WHEN SUM(wc.quantity) >= 40 THEN 'APPROACHING LIMIT'
        ELSE 'OK'
    END AS status,
    COUNT(wc.id) AS container_count
FROM accumulation_areas aa
LEFT JOIN waste_containers wc ON aa.id = wc.accumulation_area_id
    AND wc.status IN ('open', 'closed')
    AND wc.quantity_unit = 'gallons'
WHERE aa.area_type = 'satellite'
  AND aa.is_active = 1
GROUP BY aa.id, aa.area_code, aa.area_name, aa.establishment_id, aa.generating_process;


-- ----------------------------------------------------------------------------
-- v_manifests_pending_return
-- ----------------------------------------------------------------------------
-- Manifests where we haven't received signed copy back from TSDF.
-- Exception report needed if not received in 35 days (LQG) or 60 days (SQG).

CREATE VIEW IF NOT EXISTS v_manifests_pending_return AS
SELECT
    wm.id AS manifest_id,
    wm.manifest_tracking_number,
    wm.establishment_id,
    e.name AS establishment_name,
    wm.shipment_date,
    wm.designated_facility_name,
    wm.status,
    CAST(julianday('now') - julianday(wm.shipment_date) AS INTEGER) AS days_since_shipment,
    CASE
        WHEN gsc.effective_status = 'lqg' THEN 35
        ELSE 60
    END AS exception_report_deadline_days,
    CASE
        WHEN CAST(julianday('now') - julianday(wm.shipment_date) AS INTEGER) >=
             CASE WHEN gsc.effective_status = 'lqg' THEN 35 ELSE 60 END
        THEN 'EXCEPTION REPORT REQUIRED'
        WHEN CAST(julianday('now') - julianday(wm.shipment_date) AS INTEGER) >= 30
        THEN 'CONTACT FACILITY'
        ELSE 'WAITING'
    END AS action_needed
FROM waste_manifests wm
INNER JOIN establishments e ON wm.establishment_id = e.id
LEFT JOIN v_generator_status_current gsc ON wm.establishment_id = gsc.establishment_id
WHERE wm.status IN ('in_transit', 'delivered')
  AND wm.copy3_received_date IS NULL
  AND wm.exception_report_filed_date IS NULL
ORDER BY wm.shipment_date ASC;


-- ----------------------------------------------------------------------------
-- v_inspections_due
-- ----------------------------------------------------------------------------
-- Accumulation areas needing inspection based on schedule.

CREATE VIEW IF NOT EXISTS v_inspections_due AS
SELECT
    aa.id AS area_id,
    aa.area_code,
    aa.area_name,
    aa.area_type,
    aa.establishment_id,
    aa.inspection_frequency,
    aa.last_inspection_date,
    CASE aa.inspection_frequency
        WHEN 'daily' THEN date(aa.last_inspection_date, '+1 day')
        WHEN 'weekly' THEN date(aa.last_inspection_date, '+7 days')
        WHEN 'monthly' THEN date(aa.last_inspection_date, '+1 month')
        ELSE aa.next_inspection_date
    END AS next_due_date,
    CAST(julianday(CASE aa.inspection_frequency
        WHEN 'daily' THEN date(aa.last_inspection_date, '+1 day')
        WHEN 'weekly' THEN date(aa.last_inspection_date, '+7 days')
        WHEN 'monthly' THEN date(aa.last_inspection_date, '+1 month')
        ELSE aa.next_inspection_date
    END) - julianday('now') AS INTEGER) AS days_until_due,
    CASE
        WHEN aa.last_inspection_date IS NULL THEN 'NEVER INSPECTED'
        WHEN date(CASE aa.inspection_frequency
            WHEN 'daily' THEN date(aa.last_inspection_date, '+1 day')
            WHEN 'weekly' THEN date(aa.last_inspection_date, '+7 days')
            WHEN 'monthly' THEN date(aa.last_inspection_date, '+1 month')
            ELSE aa.next_inspection_date
        END) < date('now') THEN 'OVERDUE'
        WHEN date(CASE aa.inspection_frequency
            WHEN 'daily' THEN date(aa.last_inspection_date, '+1 day')
            WHEN 'weekly' THEN date(aa.last_inspection_date, '+7 days')
            WHEN 'monthly' THEN date(aa.last_inspection_date, '+1 month')
            ELSE aa.next_inspection_date
        END) <= date('now', '+1 day') THEN 'DUE TODAY'
        ELSE 'UPCOMING'
    END AS status
FROM accumulation_areas aa
WHERE aa.is_active = 1
ORDER BY next_due_date ASC;


-- ----------------------------------------------------------------------------
-- v_universal_waste_approaching_deadline
-- ----------------------------------------------------------------------------
-- Universal waste approaching 1-year accumulation limit.

CREATE VIEW IF NOT EXISTS v_universal_waste_approaching_deadline AS
SELECT
    uw.id,
    uw.establishment_id,
    uw.waste_type,
    uw.description,
    uw.quantity,
    uw.quantity_unit,
    uw.accumulation_start_date,
    uw.must_ship_by_date,
    CAST(julianday(uw.must_ship_by_date) - julianday('now') AS INTEGER) AS days_remaining,
    CASE
        WHEN date(uw.must_ship_by_date) < date('now') THEN 'OVERDUE'
        WHEN date(uw.must_ship_by_date) < date('now', '+30 days') THEN 'SHIP SOON'
        WHEN date(uw.must_ship_by_date) < date('now', '+90 days') THEN 'APPROACHING'
        ELSE 'OK'
    END AS urgency
FROM universal_waste uw
WHERE uw.status = 'accumulating'
  AND uw.must_ship_by_date IS NOT NULL
ORDER BY uw.must_ship_by_date ASC;


-- ----------------------------------------------------------------------------
-- v_waste_stream_summary
-- ----------------------------------------------------------------------------
-- Summary of waste streams with annual quantities and costs.

CREATE VIEW IF NOT EXISTS v_waste_stream_summary AS
SELECT
    ws.id AS waste_stream_id,
    ws.stream_code,
    ws.stream_name,
    ws.waste_category,
    ws.waste_stream_type_code,
    ws.establishment_id,
    GROUP_CONCAT(DISTINCT wsc.waste_code) AS waste_codes,
    COUNT(DISTINCT wc.id) AS total_containers,
    SUM(CASE WHEN wc.status IN ('open', 'closed') THEN 1 ELSE 0 END) AS active_containers,
    SUM(CASE WHEN wc.status = 'shipped' THEN wc.quantity ELSE 0 END) AS shipped_quantity,
    -- Manifests this year
    (SELECT COUNT(*) FROM manifest_items mi
     INNER JOIN waste_manifests wm ON mi.manifest_id = wm.id
     WHERE mi.waste_stream_id = ws.id
       AND strftime('%Y', wm.shipment_date) = strftime('%Y', 'now')
    ) AS manifests_this_year
FROM waste_streams ws
LEFT JOIN waste_stream_codes wsc ON ws.id = wsc.waste_stream_id
LEFT JOIN waste_containers wc ON ws.id = wc.waste_stream_id
WHERE ws.is_active = 1
GROUP BY ws.id, ws.stream_code, ws.stream_name, ws.waste_category, ws.waste_stream_type_code, ws.establishment_id;


-- ----------------------------------------------------------------------------
-- v_waste_compliance_dashboard
-- ----------------------------------------------------------------------------
-- Overall compliance status for establishment — quick health check.
-- Combines RCRA waste and wastewater compliance into a single view.

CREATE VIEW IF NOT EXISTS v_waste_compliance_dashboard AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    -- Generator status
    COALESCE(gsc.effective_status, 'unknown') AS generator_status,

    -- Container deadlines
    (SELECT COUNT(*) FROM v_containers_approaching_deadline vcd
     WHERE vcd.establishment_id = e.id AND vcd.urgency = 'OVERDUE') AS containers_overdue,
    (SELECT COUNT(*) FROM v_containers_approaching_deadline vcd
     WHERE vcd.establishment_id = e.id AND vcd.urgency = 'CRITICAL') AS containers_critical,

    -- SAA status
    (SELECT COUNT(*) FROM v_saa_volume_status vsv
     WHERE vsv.establishment_id = e.id AND vsv.status LIKE '%FULL%') AS saa_at_limit,

    -- Manifest issues
    (SELECT COUNT(*) FROM v_manifests_pending_return vmpr
     WHERE vmpr.establishment_id = e.id AND vmpr.action_needed = 'EXCEPTION REPORT REQUIRED') AS manifests_need_exception,

    -- Inspections
    (SELECT COUNT(*) FROM v_inspections_due vid
     WHERE vid.establishment_id = e.id AND vid.status = 'OVERDUE') AS inspections_overdue,

    -- Universal waste
    (SELECT COUNT(*) FROM v_universal_waste_approaching_deadline vuw
     WHERE vuw.establishment_id = e.id AND vuw.urgency = 'OVERDUE') AS universal_waste_overdue,

    -- Active counts
    (SELECT COUNT(*) FROM waste_containers wc
     WHERE wc.establishment_id = e.id AND wc.status IN ('open', 'closed')) AS active_containers,
    (SELECT COUNT(*) FROM accumulation_areas aa
     WHERE aa.establishment_id = e.id AND aa.is_active = 1) AS active_accumulation_areas,

    -- Wastewater exceedances (last 12 months)
    (SELECT COUNT(*) FROM v_ww_exceedances ex
     WHERE ex.establishment_id = e.id
       AND ex.sample_date >= date('now', '-12 months')) AS ww_exceedances_last_12_months,

    -- Wastewater equipment needing calibration
    (SELECT COUNT(*) FROM ww_equipment eq
     WHERE eq.establishment_id = e.id
       AND eq.is_active = 1
       AND eq.next_calibration_due <= date('now', '+30 days')) AS ww_calibrations_due_30_days,

    -- Pending wastewater lab results
    (SELECT COUNT(*) FROM ww_lab_submissions ls
     WHERE ls.establishment_id = e.id
       AND ls.status IN ('submitted', 'received_by_lab')) AS ww_pending_lab_results,

    -- Overall status (considers both RCRA and wastewater)
    CASE
        WHEN (SELECT COUNT(*) FROM v_containers_approaching_deadline vcd
              WHERE vcd.establishment_id = e.id AND vcd.urgency = 'OVERDUE') > 0 THEN 'CRITICAL'
        WHEN (SELECT COUNT(*) FROM v_manifests_pending_return vmpr
              WHERE vmpr.establishment_id = e.id AND vmpr.action_needed = 'EXCEPTION REPORT REQUIRED') > 0 THEN 'CRITICAL'
        WHEN (SELECT COUNT(*) FROM v_ww_exceedances ex
              WHERE ex.establishment_id = e.id
                AND ex.sample_date >= date('now', '-30 days')) > 0 THEN 'CRITICAL'
        WHEN (SELECT COUNT(*) FROM v_containers_approaching_deadline vcd
              WHERE vcd.establishment_id = e.id AND vcd.urgency = 'CRITICAL') > 0 THEN 'WARNING'
        WHEN (SELECT COUNT(*) FROM v_inspections_due vid
              WHERE vid.establishment_id = e.id AND vid.status = 'OVERDUE') > 0 THEN 'WARNING'
        WHEN (SELECT COUNT(*) FROM ww_equipment eq
              WHERE eq.establishment_id = e.id
                AND eq.is_active = 1
                AND eq.next_calibration_due < date('now')) > 0 THEN 'WARNING'
        ELSE 'OK'
    END AS overall_status

FROM establishments e
LEFT JOIN v_generator_status_current gsc ON e.id = gsc.establishment_id;


-- ============================================================================
-- PART 4: TRIGGERS
-- ============================================================================


-- ----------------------------------------------------------------------------
-- RCRA: Auto-calculate must_ship_by_date when container accumulation starts
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_container_ship_date
AFTER INSERT ON waste_containers
WHEN NEW.must_ship_by_date IS NULL AND NEW.accumulation_start_date IS NOT NULL
BEGIN
    UPDATE waste_containers
    SET must_ship_by_date = (
        SELECT CASE aa.area_type
            WHEN 'central_90day' THEN date(NEW.accumulation_start_date, '+90 days')
            WHEN 'central_180day' THEN date(NEW.accumulation_start_date, '+180 days')
            WHEN 'central_270day' THEN date(NEW.accumulation_start_date, '+270 days')
            ELSE NULL  -- SAA has no time limit until moved to CAA
        END
        FROM accumulation_areas aa
        WHERE aa.id = NEW.accumulation_area_id
    )
    WHERE id = NEW.id;
END;


-- ----------------------------------------------------------------------------
-- RCRA: Auto-calculate universal waste ship-by date (1 year)
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_universal_waste_ship_date
AFTER INSERT ON universal_waste
WHEN NEW.must_ship_by_date IS NULL
BEGIN
    UPDATE universal_waste
    SET must_ship_by_date = date(NEW.accumulation_start_date, '+365 days')
    WHERE id = NEW.id;
END;


-- ----------------------------------------------------------------------------
-- RCRA: Update container status to shipped when added to manifest
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_container_manifest_status
AFTER UPDATE ON waste_containers
WHEN NEW.manifest_id IS NOT NULL AND OLD.manifest_id IS NULL
BEGIN
    UPDATE waste_containers
    SET status = 'in_transit',
        shipped_date = date('now')
    WHERE id = NEW.id;
END;


-- ----------------------------------------------------------------------------
-- RCRA: Update last_inspection_date on accumulation area when inspection recorded
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_inspection_update_area
AFTER INSERT ON waste_inspections
BEGIN
    UPDATE accumulation_areas
    SET last_inspection_date = NEW.inspection_date,
        updated_at = datetime('now')
    WHERE id = NEW.accumulation_area_id;
END;


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
INDUSTRIAL WASTE STREAMS MODULE (module_industrial_waste_streams.sql)

Derived from ehs-ontology-v3.1.ttl — ehs:WasteHandlingAction (ActionContext)
Covers RCRA hazardous waste generation, accumulation, manifesting, and disposal
tracking. Industrial wastewater (the former PART 2) was relocated to
module_d_clean_water.sql in 2026-04-21 to match the v3.2 ontology's Module D
scope.

ONTOLOGY CONNECTIONS:
    - ehs:WasteHandlingAction — the shared ActionContext
    - ehs:EPA_Framework — routes to RCRA Subtitle C and CWA compliance
    - ehs:ChemicalSubstance (Module A) — source chemicals for waste streams
    - ehs:EmissionUnit (Module B) — wastewater from emission unit processes
    - ehs:CorrectiveAction — waste from corrective actions/cleanups
    - ehs:Incident — spill cleanup generates manifested waste

CROSS-MODULE FOREIGN KEYS:
    - waste_streams.source_chemical_id → chemicals (Module A)
    - waste_containers.corrective_action_id → corrective_actions
    - waste_manifests.incident_id → incidents

NEW REFERENCE TABLES (ontology-derived):
    - generator_status_levels: VSQG/SQG/LQG with thresholds and requirements
    - waste_stream_types: Categorizes by regulatory program (RCRA, CWA, etc.)

PART 1 — RCRA HAZARDOUS WASTE:
  Reference Tables:
    - generator_status_levels: VSQG/SQG/LQG classification with thresholds
    - waste_stream_types: Categories by regulatory program
    - waste_codes: EPA hazardous waste codes (35 seeded: D, F, K lists)

  Core Waste Tracking:
    - waste_streams: Types of waste generated (recurring waste types)
    - waste_stream_codes: Junction linking streams to EPA codes
    - waste_containers: Individual containers with accumulation tracking
    - accumulation_areas: SAA and CAA locations

  Shipping/Disposal:
    - waste_facilities: TSDFs, recyclers, used oil processors
    - waste_manifests: Uniform Hazardous Waste Manifests
    - manifest_items: Line items on each manifest
    - ldr_notifications: Land Disposal Restriction notices

  Generator Compliance:
    - generator_status_monthly: Monthly generation tracking for status determination
    - waste_inspections: Accumulation area inspection records

  Special Wastes:
    - universal_waste: Batteries, lamps, aerosols, etc.
    - used_oil_containers: Used oil tank/drum tracking
    - used_oil_shipments: Used oil pickup records

VIEWS:
  RCRA Compliance Alerts:
    - v_generator_status_current: Current generator status determination
    - v_containers_approaching_deadline: Containers needing shipment
    - v_saa_volume_status: Satellite areas approaching 55-gallon limit
    - v_manifests_pending_return: Manifests awaiting TSDF confirmation
    - v_inspections_due: Areas needing inspection
    - v_universal_waste_approaching_deadline: UW approaching 1-year limit
    - v_waste_stream_summary: Summary by waste stream
    - v_waste_compliance_dashboard: Overall waste status — NEEDS REVIEW: still
      references the relocated ww_* tables/views (v_ww_exceedances, ww_equipment,
      ww_lab_submissions) and will fail to compile until those refs are removed
      or the view is moved/rewritten to sit downstream of module_d_clean_water.sql.

TRIGGERS (4 total):
    - trg_container_ship_date: Auto-calculate must_ship_by_date for containers
    - trg_universal_waste_ship_date: Auto-calculate UW ship-by date
    - trg_container_manifest_status: Update container status when manifested
    - trg_inspection_update_area: Update area last_inspection_date

PRE-SEEDED DATA:
    Waste Codes (35): D001-D040, F001-F019, K001, K062
    Generator Status Levels (3): VSQG, SQG, LQG
    Waste Stream Types (5): hazardous, universal, used_oil, non_hazardous, industrial_wastewater

DOES NOT INCLUDE:
    - Stormwater (separate module — MSGP/CGP have different permit structures)
    - TRI reporting (Module A)
    - Air emissions (Module B)

REGULATORY DRIVERS:
    - 40 CFR 260-265: RCRA Hazardous Waste
    - 40 CFR 273: Universal Waste
    - 40 CFR 279: Used Oil
*/
