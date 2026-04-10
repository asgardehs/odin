-- Module B: Title V / Clean Air Act Air Permitting (40 CFR Part 70)
-- Derived from ehs-ontology-v3.1.ttl — Module B + cross-module wiring properties
--
-- Design principle: layer the ontology's REGULATORY STRUCTURE (pollutant taxonomy,
-- PTE calculations, major source thresholds, permit types, technology standards,
-- CAM monitoring) on top of the production-grade OPERATIONAL TABLES from the
-- original 006b_air_emissions.sql (material usage, emission factors, calculated
-- emissions, source-specific details for welding/coating/combustion).
--
-- The ontology models air permitting as a gateway decision:
--   1. Identify emission units and the pollutants they emit
--   2. Calculate PTE per emission unit per pollutant (pre-control and post-control)
--   3. Sum facility PTE and compare against major source thresholds
--   4. Threshold comparison determines permit type (Title V vs FESOP)
--   5. Applicable technology standards (MACT, NSPS) become permit conditions
--   6. Control devices with PTE above thresholds trigger CAM requirements
--
-- Shared tables (establishments, employees) defined in module_c_osha300.sql.
-- Audit log handled by git-backed store, settings by Heimdall.


-- ============================================================================
-- REFERENCE: AIR POLLUTANT TYPES (from ontology AirPollutant subclasses)
-- ============================================================================
-- The ontology defines four pollutant type categories with distinct regulatory
-- significance. A single pollutant (e.g., toluene) can belong to multiple
-- categories (HAP and VOC). The type determines which threshold applies.

CREATE TABLE IF NOT EXISTS air_pollutant_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_reference TEXT                          -- Primary regulatory citation
);

INSERT OR IGNORE INTO air_pollutant_types (code, name, description, cfr_reference) VALUES
    ('CRITERIA', 'Criteria Pollutant',
     'One of six pollutants with NAAQS under CAA Section 109: SO2, NOx, CO, PM10, PM2.5, Pb, and ozone (regulated via VOC/NOx as precursors). Major source threshold generally 100 tpy, reduced in nonattainment areas.',
     'CAA Section 109'),
    ('HAP', 'Hazardous Air Pollutant',
     'One of 187 toxic air pollutants listed in CAA Section 112(b). Known or suspected to cause cancer, birth defects, or other serious health effects. Major source thresholds: 10 tpy single HAP, 25 tpy combined HAPs.',
     'CAA Section 112(b)'),
    ('VOC', 'Volatile Organic Compound',
     'Any compound of carbon (excluding CO, CO2, carbonic acid, metallic carbides/carbonates, ammonium carbonate, and exempt compounds per 40 CFR 51.100) that participates in atmospheric photochemical reactions. Regulated as ozone precursor. Major source threshold 100 tpy, lower in ozone nonattainment areas.',
     '40 CFR 51.100'),
    ('GHG', 'Greenhouse Gas',
     'CO2, CH4, N2O, HFCs, PFCs, SF6, and NF3 per the Mandatory Reporting Rule. Title V applicability threshold: 100,000 tpy CO2 equivalent. GHG reporting threshold: 25,000 tpy CO2e.',
     '40 CFR Part 98');


-- ============================================================================
-- REFERENCE: AIR POLLUTANTS (specific regulated substances)
-- ============================================================================
-- Individual pollutants with their type classification. A pollutant can appear
-- in multiple types (e.g., toluene is both HAP and VOC). The pollutant_code
-- here is the same code used in the operational tables (emission factors,
-- calculated emissions, control efficiency).

CREATE TABLE IF NOT EXISTS air_pollutants (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    cas_number TEXT,                            -- CAS registry number where applicable
    formula TEXT,                               -- Chemical formula
    description TEXT
);

INSERT OR IGNORE INTO air_pollutants (code, name, cas_number, formula, description) VALUES
    -- Criteria pollutants
    ('SO2',    'Sulfur Dioxide',            '7446-09-5',  'SO2',   'Criteria pollutant. Combustion of sulfur-containing fuels.'),
    ('NOx',    'Nitrogen Oxides',           NULL,         'NOx',   'Criteria pollutant. NO + NO2, primarily from combustion. Also ozone precursor.'),
    ('CO',     'Carbon Monoxide',           '630-08-0',   'CO',    'Criteria pollutant. Incomplete combustion product.'),
    ('PM',     'Total Particulate Matter',  NULL,         NULL,    'Criteria pollutant. All filterable particulate, any size.'),
    ('PM10',   'Particulate Matter <=10um', NULL,         NULL,    'Criteria pollutant. Inhalable coarse particles.'),
    ('PM25',   'Particulate Matter <=2.5um',NULL,         NULL,    'Criteria pollutant. Fine particles, deepest lung penetration.'),
    ('Pb',     'Lead',                      '7439-92-1',  'Pb',    'Criteria pollutant and HAP. Smelting, battery manufacturing, leaded fuel combustion.'),
    ('VOC',    'Volatile Organic Compounds',NULL,         NULL,    'Ozone precursor category. Reported as aggregate unless speciated.'),

    -- Common HAPs (subset of 187 — seed the most frequently encountered)
    ('Benzene',      'Benzene',             '71-43-2',    'C6H6',        'HAP. Known human carcinogen. Fuels, solvents, chemical manufacturing.'),
    ('Toluene',      'Toluene',             '108-88-3',   'C7H8',        'HAP and VOC. Paints, coatings, adhesives, fuels.'),
    ('Xylene',       'Xylenes (mixed)',     '1330-20-7',  'C8H10',       'HAP and VOC. Paints, coatings, solvents.'),
    ('MeCl2',        'Methylene Chloride',  '75-09-2',    'CH2Cl2',      'HAP. Solvent degreasing, paint stripping. Probable carcinogen.'),
    ('Formaldehyde', 'Formaldehyde',        '50-00-0',    'CH2O',        'HAP. Combustion byproduct, resins, composite wood products.'),
    ('Cr6',          'Hexavalent Chromium', '18540-29-9', NULL,          'HAP. Welding stainless steel, chrome plating. Known carcinogen.'),
    ('Ni',           'Nickel Compounds',    '7440-02-0',  'Ni',          'HAP. Welding, combustion, metal processing.'),
    ('Mn',           'Manganese Compounds', '7439-96-5',  'Mn',          'HAP. Welding fume, steel manufacturing.'),
    ('Cr',           'Chromium (total)',     '7440-47-3',  'Cr',          'HAP. All chromium species combined.'),
    ('Zn',           'Zinc Compounds',      '7440-66-6',  'Zn',          'Welding galvanized steel. PM contributor.'),
    ('Cd',           'Cadmium Compounds',   '7440-43-9',  'Cd',          'HAP. Smelting, battery manufacturing. Known carcinogen.'),

    -- Greenhouse gases
    ('CO2',    'Carbon Dioxide',            '124-38-9',   'CO2',   'GHG. Primary greenhouse gas from fossil fuel combustion.'),
    ('CH4',    'Methane',                   '74-82-8',    'CH4',   'GHG. Natural gas leaks, landfills, wastewater. GWP = 28.'),
    ('N2O',    'Nitrous Oxide',             '10024-97-2', 'N2O',   'GHG. Combustion, agricultural operations. GWP = 265.'),
    ('CO2e',   'CO2 Equivalent',            NULL,         NULL,    'GHG. Aggregate metric: sum of (each GHG mass x GWP).');


-- ============================================================================
-- REFERENCE: POLLUTANT TYPE MAPPING (junction — pollutant to type)
-- ============================================================================
-- Many-to-many: toluene is both HAP and VOC, lead is both criteria and HAP.

CREATE TABLE IF NOT EXISTS air_pollutant_type_map (
    pollutant_code TEXT NOT NULL,
    type_code TEXT NOT NULL,

    PRIMARY KEY (pollutant_code, type_code),
    FOREIGN KEY (pollutant_code) REFERENCES air_pollutants(code),
    FOREIGN KEY (type_code) REFERENCES air_pollutant_types(code)
);

INSERT OR IGNORE INTO air_pollutant_type_map (pollutant_code, type_code) VALUES
    -- Criteria pollutants
    ('SO2',    'CRITERIA'),
    ('NOx',    'CRITERIA'),
    ('CO',     'CRITERIA'),
    ('PM',     'CRITERIA'),
    ('PM10',   'CRITERIA'),
    ('PM25',   'CRITERIA'),
    ('Pb',     'CRITERIA'),
    ('Pb',     'HAP'),
    ('VOC',    'VOC'),

    -- HAPs (many are also VOCs)
    ('Benzene',      'HAP'),
    ('Benzene',      'VOC'),
    ('Toluene',      'HAP'),
    ('Toluene',      'VOC'),
    ('Xylene',       'HAP'),
    ('Xylene',       'VOC'),
    ('MeCl2',        'HAP'),
    ('Formaldehyde', 'HAP'),
    ('Cr6',          'HAP'),
    ('Ni',           'HAP'),
    ('Mn',           'HAP'),
    ('Cr',           'HAP'),
    ('Cd',           'HAP'),

    -- GHGs
    ('CO2',    'GHG'),
    ('CH4',    'GHG'),
    ('N2O',    'GHG'),
    ('CO2e',   'GHG');


-- ============================================================================
-- REFERENCE: MAJOR SOURCE THRESHOLDS (from ontology MajorSourceThreshold)
-- ============================================================================
-- PTE levels that trigger Title V permitting. The standard thresholds apply in
-- attainment areas. Nonattainment areas have lower thresholds for the
-- nonattainment pollutant(s), coded as separate rows.

CREATE TABLE IF NOT EXISTS air_major_source_thresholds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pollutant_type_code TEXT NOT NULL,          -- FK to air_pollutant_types
    threshold_tpy REAL NOT NULL,               -- Tons per year
    threshold_applies_to TEXT NOT NULL,         -- 'single_pollutant', 'combined_haps', 'co2e'
    attainment_status TEXT NOT NULL DEFAULT 'attainment',  -- 'attainment', 'marginal', 'moderate', 'serious', 'severe', 'extreme'
    description TEXT NOT NULL,
    cfr_reference TEXT,

    FOREIGN KEY (pollutant_type_code) REFERENCES air_pollutant_types(code)
);

INSERT OR IGNORE INTO air_major_source_thresholds
    (id, pollutant_type_code, threshold_tpy, threshold_applies_to, attainment_status, description, cfr_reference) VALUES
    -- Standard attainment area thresholds
    (1, 'CRITERIA', 100.0,    'single_pollutant', 'attainment',
     '100 tpy of any single criteria pollutant in attainment areas.',
     '40 CFR 70.2'),
    (2, 'HAP',      10.0,     'single_pollutant', 'attainment',
     '10 tpy of any single hazardous air pollutant.',
     'CAA Section 112'),
    (3, 'HAP',      25.0,     'combined_haps',    'attainment',
     '25 tpy of any combination of hazardous air pollutants.',
     'CAA Section 112'),
    (4, 'VOC',      100.0,    'single_pollutant', 'attainment',
     '100 tpy VOC in ozone attainment areas.',
     '40 CFR 70.2'),
    (5, 'GHG',      100000.0, 'co2e',             'attainment',
     '100,000 tpy CO2 equivalent for greenhouse gases.',
     'Tailoring Rule'),

    -- Ozone nonattainment area thresholds (VOC/NOx as ozone precursors)
    (10, 'VOC', 100.0, 'single_pollutant', 'marginal',
     '100 tpy VOC in marginal ozone nonattainment areas.',
     'CAA Section 182(a)'),
    (11, 'VOC', 100.0, 'single_pollutant', 'moderate',
     '100 tpy VOC in moderate ozone nonattainment areas.',
     'CAA Section 182(b)'),
    (12, 'VOC', 50.0,  'single_pollutant', 'serious',
     '50 tpy VOC in serious ozone nonattainment areas.',
     'CAA Section 182(c)'),
    (13, 'VOC', 25.0,  'single_pollutant', 'severe',
     '25 tpy VOC in severe ozone nonattainment areas.',
     'CAA Section 182(d)'),
    (14, 'VOC', 10.0,  'single_pollutant', 'extreme',
     '10 tpy VOC in extreme ozone nonattainment areas.',
     'CAA Section 182(e)'),

    -- PM nonattainment
    (20, 'CRITERIA', 100.0, 'single_pollutant', 'moderate',
     '100 tpy PM10 in moderate PM10 nonattainment areas.',
     'CAA Section 189(a)'),
    (21, 'CRITERIA', 70.0,  'single_pollutant', 'serious',
     '70 tpy PM10 in serious PM10 nonattainment areas.',
     'CAA Section 189(b)'),

    -- CO nonattainment
    (30, 'CRITERIA', 100.0, 'single_pollutant', 'moderate',
     '100 tpy CO in moderate CO nonattainment areas.',
     'CAA Section 187');


-- ============================================================================
-- REFERENCE: NONATTAINMENT AREAS (from ontology NonattainmentArea)
-- ============================================================================
-- Geographic areas that do not meet NAAQS for one or more criteria pollutants.
-- Classification severity determines which threshold row applies. Updated as
-- EPA redesignates areas. An establishment's county/state determines lookup.

CREATE TABLE IF NOT EXISTS air_nonattainment_areas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    area_name TEXT NOT NULL,                    -- 'South Coast Air Basin', 'Houston-Galveston-Brazoria'
    state TEXT NOT NULL,                        -- 2-letter code
    counties TEXT,                              -- Comma-separated county names (or 'partial' for split counties)
    pollutant_code TEXT NOT NULL,               -- The NAAQS pollutant: 'O3', 'PM25', 'PM10', 'CO', 'SO2', 'Pb', 'NO2'
    classification TEXT NOT NULL,              -- 'marginal', 'moderate', 'serious', 'severe', 'extreme'
    designation_date TEXT,                      -- YYYY-MM-DD of EPA final designation
    attainment_deadline TEXT,                   -- YYYY-MM-DD

    description TEXT,

    is_current INTEGER DEFAULT 1,              -- 0 if redesignated to attainment

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_air_naa_state ON air_nonattainment_areas(state);
CREATE INDEX idx_air_naa_pollutant ON air_nonattainment_areas(pollutant_code);
CREATE INDEX idx_air_naa_classification ON air_nonattainment_areas(classification);


-- ============================================================================
-- REFERENCE: PERMIT TYPES (from ontology TitleVPermit, FESOP)
-- ============================================================================
-- The two permit tracks in the ontology. The PTE-vs-threshold comparison
-- determines which track a facility falls into.

CREATE TABLE IF NOT EXISTS air_permit_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_reference TEXT
);

INSERT OR IGNORE INTO air_permit_types (code, name, description, cfr_reference) VALUES
    ('TITLE_V', 'Title V Operating Permit',
     'Comprehensive operating permit required for major sources under 40 CFR Part 70. Consolidates all applicable federal and state air requirements into one federally enforceable document. Valid for 5 years with renewal required. Contains emission limits, monitoring requirements, recordkeeping obligations, reporting schedules, and compliance certification requirements for each emission unit.',
     '40 CFR Part 70'),
    ('FESOP', 'Federally Enforceable State Operating Permit',
     'State-issued permit allowing a facility to accept federally enforceable emission limitations that restrict PTE below major source thresholds, thereby avoiding Title V permitting. Also called a synthetic minor permit or permit-by-rule in some states. The restrictions must be practically enforceable and include monitoring, recordkeeping, and reporting conditions.',
     'State programs'),
    ('GP', 'General Permit',
     'Permit covering multiple similar sources under a single permit document. Facilities register under the general permit rather than obtaining an individual permit. Common for dry cleaners, gas stations, small boilers.',
     'State programs'),
    ('PBR', 'Permit by Rule',
     'Sources that meet specified criteria are deemed permitted without individual application. The rule itself functions as the permit. Typically for very small or low-emission sources.',
     'State programs'),
    ('PTI', 'Permit to Install',
     'Pre-construction permit required before installing or modifying an emission unit. Distinct from the operating permit — PTI authorizes construction, Title V/FESOP authorizes operation.',
     'State programs');


-- ============================================================================
-- REFERENCE: TECHNOLOGY STANDARD TYPES (from ontology MACT, NSPS)
-- ============================================================================
-- Categories of technology-based standards that become applicable requirements
-- in the Title V permit.

CREATE TABLE IF NOT EXISTS air_technology_standard_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_part TEXT NOT NULL                      -- 40 CFR Part number
);

INSERT OR IGNORE INTO air_technology_standard_types (code, name, description, cfr_part) VALUES
    ('MACT', 'Maximum Achievable Control Technology',
     'Emission standards for major sources of HAPs under CAA Section 112. Based on emission levels achieved by best-performing 12% of existing sources in a source category. Codified as National Emission Standards for Hazardous Air Pollutants (NESHAP). Subject to periodic residual risk review under Section 112(f).',
     '40 CFR Part 63'),
    ('NSPS', 'New Source Performance Standards',
     'Emission standards for new and modified stationary sources in specific industrial categories under CAA Section 111. Apply based on date of construction, modification, or reconstruction of the emission unit. NSPS requirements become applicable requirements in the Title V permit.',
     '40 CFR Part 60'),
    ('SIP', 'State Implementation Plan Rule',
     'State-adopted emission rules approved by EPA as part of the State Implementation Plan. Implements NAAQS attainment strategy. Becomes federally enforceable upon SIP approval.',
     '40 CFR Parts 51/52'),
    ('GACT', 'Generally Available Control Technology',
     'Less stringent alternative to MACT for area sources (below major source thresholds) of HAPs under CAA Section 112(d)(5). EPA may issue GACT standards instead of MACT for area source categories.',
     '40 CFR Part 63');


-- ============================================================================
-- STACKS (from 006b — retained as-is)
-- ============================================================================
-- Exhaust points where emissions are released. Not all sources have stacks
-- (fugitive emissions), but permits and dispersion modeling require stack data.

CREATE TABLE IF NOT EXISTS air_stacks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    stack_name TEXT NOT NULL,                   -- 'Paint Booth Exhaust', 'Boiler Stack'
    stack_number TEXT,                          -- Permit-assigned ID if applicable

    -- Physical parameters (for permits and dispersion modeling)
    height_ft REAL,                            -- Stack height above ground
    diameter_in REAL,                           -- Internal diameter at exit
    exit_velocity_fps REAL,                    -- Feet per second
    exit_temperature_f REAL,                   -- Exhaust temperature

    -- Location (for dispersion modeling)
    latitude REAL,
    longitude REAL,

    -- Status
    is_active INTEGER DEFAULT 1,
    install_date TEXT,
    decommission_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, stack_name)
);

CREATE INDEX idx_air_stacks_establishment ON air_stacks(establishment_id);


-- ============================================================================
-- EMISSION UNITS (from 006b — enhanced with ontology fields)
-- ============================================================================
-- The fundamental building block of air permitting. A discrete piece of equipment,
-- process, or activity that emits or has the potential to emit air pollutants.
-- Each emission unit has its own PTE calculation and may have specific emission
-- limits, control devices, and monitoring requirements in the permit.
--
-- Adding, removing, or modifying emission units may trigger permit modification.

CREATE TABLE IF NOT EXISTS air_emission_units (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    unit_name TEXT NOT NULL,                    -- 'Weld Cell 1', 'Paint Booth A', 'Boiler #2'
    unit_description TEXT,

    -- Source classification
    source_category TEXT NOT NULL,              -- 'welding', 'coating', 'combustion', 'solvent', 'material_handling'
    scc_code TEXT,                              -- EPA Source Classification Code
    is_fugitive INTEGER DEFAULT 0,             -- 1 = FugitiveEmissionSource (no stack, LDAR applies)

    -- Physical location within facility
    building TEXT,
    area TEXT,

    -- Stack relationship (NULL for fugitive sources)
    stack_id INTEGER,

    -- Permit reference
    permit_type_code TEXT,                     -- FK to air_permit_types (which permit covers this unit)
    permit_number TEXT,                        -- State-assigned permit number

    -- Operating parameters (used for PTE calculation)
    max_throughput REAL,                       -- Maximum rated capacity
    max_throughput_unit TEXT,                   -- 'tons/hr', 'gallons/day', 'MMBtu/hr'
    max_operating_hours_year REAL DEFAULT 8760, -- For PTE: default 24/365 unless restricted
    typical_operating_hours_year REAL,          -- Actual typical hours (for actual emissions)

    -- Federally enforceable restrictions (FESOP/synthetic minor limits)
    restricted_throughput REAL,                 -- Federally enforceable throughput limit
    restricted_throughput_unit TEXT,
    restricted_hours_year REAL,                -- Federally enforceable hours limit

    -- Status
    is_active INTEGER DEFAULT 1,
    install_date TEXT,
    decommission_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (stack_id) REFERENCES air_stacks(id),
    FOREIGN KEY (permit_type_code) REFERENCES air_permit_types(code),
    UNIQUE(establishment_id, unit_name)
);

CREATE INDEX idx_air_units_establishment ON air_emission_units(establishment_id);
CREATE INDEX idx_air_units_category ON air_emission_units(source_category);
CREATE INDEX idx_air_units_stack ON air_emission_units(stack_id);
CREATE INDEX idx_air_units_permit_type ON air_emission_units(permit_type_code);
CREATE INDEX idx_air_units_fugitive ON air_emission_units(is_fugitive);


-- ============================================================================
-- CONTROL DEVICES (from 006b — retained as-is)
-- ============================================================================
-- Air pollution control equipment: thermal oxidizers (RTO/RCO), catalytic
-- oxidizers, scrubbers (wet/dry), baghouses, ESPs, carbon adsorbers, condensers,
-- cyclones, HEPA filters. Control efficiency determines the difference between
-- pre-control and post-control PTE.

CREATE TABLE IF NOT EXISTS air_control_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    device_name TEXT NOT NULL,                  -- 'Paint Booth Filters', 'Weld Fume Collector'
    device_type TEXT NOT NULL,                  -- 'baghouse', 'scrubber_wet', 'thermal_oxidizer', etc.

    -- What does this control?
    emission_unit_id INTEGER,                  -- FK (NULL if controls multiple units)

    -- Equipment details
    manufacturer TEXT,
    model_number TEXT,
    serial_number TEXT,

    -- Status
    is_active INTEGER DEFAULT 1,
    install_date TEXT,
    decommission_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    UNIQUE(establishment_id, device_name)
);

CREATE INDEX idx_air_controls_establishment ON air_control_devices(establishment_id);
CREATE INDEX idx_air_controls_unit ON air_control_devices(emission_unit_id);
CREATE INDEX idx_air_controls_type ON air_control_devices(device_type);


-- ============================================================================
-- CONTROL DEVICE EFFICIENCY (from 006b — per pollutant)
-- ============================================================================
-- Control efficiency varies by pollutant. A baghouse might be 99% for PM but
-- 0% for VOC. This is critical for PTE: post-control PTE = pre-control PTE
-- x (1 - efficiency/100).

CREATE TABLE IF NOT EXISTS air_control_efficiency (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    control_device_id INTEGER NOT NULL,

    pollutant_code TEXT NOT NULL,               -- FK to air_pollutants.code
    control_efficiency_pct REAL NOT NULL,       -- 0-100

    -- Source of efficiency value
    efficiency_source TEXT,                     -- 'permit', 'manufacturer', 'stack_test', 'default'
    source_document TEXT,

    -- Time validity
    effective_date TEXT NOT NULL,
    superseded_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (control_device_id) REFERENCES air_control_devices(id),
    UNIQUE(control_device_id, pollutant_code, effective_date)
);

CREATE INDEX idx_air_eff_device ON air_control_efficiency(control_device_id);
CREATE INDEX idx_air_eff_pollutant ON air_control_efficiency(pollutant_code);


-- ============================================================================
-- TECHNOLOGY STANDARDS (applicable MACT/NSPS/SIP rules per emission unit)
-- ============================================================================
-- From ontology: subjectToStandard links emission units to applicable technology
-- standards. These become conditions in the Title V permit. An emission unit
-- may be subject to multiple standards simultaneously (e.g., an NSPS and a MACT).

CREATE TABLE IF NOT EXISTS air_technology_standards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    standard_type_code TEXT NOT NULL,           -- FK to air_technology_standard_types
    subpart TEXT NOT NULL,                      -- 'Subpart MMMM', 'Subpart JJJJJJ', 'Subpart Dc'
    title TEXT NOT NULL,                        -- 'NESHAP for Surface Coating of Miscellaneous Metal Parts'
    cfr_citation TEXT,                          -- '40 CFR 63 Subpart MMMM'

    -- Applicability
    source_categories TEXT,                    -- Comma-separated: 'coating', 'combustion'
    applicability_criteria TEXT,                -- When does this standard apply?

    -- Key requirements summary
    emission_limits TEXT,                       -- Brief summary of limits
    monitoring_requirements TEXT,               -- Brief summary of monitoring
    recordkeeping_requirements TEXT,            -- Brief summary of recordkeeping
    reporting_requirements TEXT,                -- Brief summary of reporting

    description TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (standard_type_code) REFERENCES air_technology_standard_types(code)
);

CREATE INDEX idx_air_tech_std_type ON air_technology_standards(standard_type_code);
CREATE INDEX idx_air_tech_std_subpart ON air_technology_standards(subpart);


-- ============================================================================
-- EMISSION UNIT STANDARDS (junction — which standards apply to which units)
-- ============================================================================

CREATE TABLE IF NOT EXISTS air_emission_unit_standards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    emission_unit_id INTEGER NOT NULL,
    technology_standard_id INTEGER NOT NULL,

    -- Applicability determination
    applicability_date TEXT,                    -- When applicability was determined
    applicability_basis TEXT,                   -- 'construction_date', 'modification', 'source_category'
    is_applicable INTEGER DEFAULT 1,           -- 0 if determined not applicable (document why)
    applicability_notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    FOREIGN KEY (technology_standard_id) REFERENCES air_technology_standards(id),
    UNIQUE(emission_unit_id, technology_standard_id)
);

CREATE INDEX idx_air_eu_std_unit ON air_emission_unit_standards(emission_unit_id);
CREATE INDEX idx_air_eu_std_standard ON air_emission_unit_standards(technology_standard_id);


-- ============================================================================
-- EMISSION MATERIALS (from 006b — retained as-is)
-- ============================================================================
-- Materials tracked for emissions: coatings, fuels, welding consumables, solvents.

CREATE TABLE IF NOT EXISTS air_emission_materials (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    material_name TEXT NOT NULL,                -- 'E70S-6 MIG Wire', 'Rustoleum Industrial Enamel'
    material_category TEXT NOT NULL,            -- 'welding_consumable', 'coating', 'fuel', 'solvent', 'raw_material'

    -- Identification
    manufacturer TEXT,
    product_code TEXT,

    -- Default unit of measure
    default_unit TEXT,                          -- 'lbs', 'gallons', 'therms', 'cubic_feet'

    -- Cross-module: link to Module A chemical inventory (usesChemical property)
    chemical_id INTEGER,                       -- FK to chemicals table

    -- Status
    is_active INTEGER DEFAULT 1,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (chemical_id) REFERENCES chemicals(id)
);

CREATE INDEX idx_air_materials_category ON air_emission_materials(material_category);
CREATE INDEX idx_air_materials_chemical ON air_emission_materials(chemical_id);


-- ============================================================================
-- MATERIAL PROPERTIES (from 006b — key-value with time validity)
-- ============================================================================
-- Properties that affect emission calculations. Key-value approach supports
-- varying property types across material categories and reformulations over time.

CREATE TABLE IF NOT EXISTS air_material_properties (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_id INTEGER NOT NULL,

    property_key TEXT NOT NULL,                 -- 'voc_content', 'heat_content', 'density', 'vapor_pressure'
    property_value TEXT NOT NULL,               -- Stored as text, parsed as needed
    property_unit TEXT,                         -- '%', 'BTU/scf', 'lb/gal', 'mmHg'

    -- Source of this property value
    source TEXT,                                -- 'sds', 'lab_analysis', 'manufacturer', 'default', 'epa'
    source_document TEXT,

    -- Time validity (same material can have different properties over time)
    effective_date TEXT NOT NULL,
    superseded_date TEXT,                       -- NULL if current

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (material_id) REFERENCES air_emission_materials(id),
    UNIQUE(material_id, property_key, effective_date)
);

CREATE INDEX idx_air_props_material ON air_material_properties(material_id);
CREATE INDEX idx_air_props_key ON air_material_properties(property_key);
CREATE INDEX idx_air_props_effective ON air_material_properties(effective_date);


-- ============================================================================
-- EMISSION FACTORS (from 006b — retained as-is)
-- ============================================================================
-- Published factors that convert usage to emissions. Pre-seed with AP-42 factors,
-- users can add facility-specific factors from stack tests.

CREATE TABLE IF NOT EXISTS air_emission_factors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Classification for matching
    source_category TEXT NOT NULL,              -- 'welding', 'coating', 'combustion'
    process_type TEXT,                          -- 'MIG', 'spray_hvlp', 'natural_gas_boiler'

    -- Granular matching fields
    material_match TEXT,                        -- Electrode type, fuel type, coating type
    equipment_match TEXT,                       -- Specific equipment applicability

    -- The factor itself
    pollutant_code TEXT NOT NULL,               -- FK to air_pollutants.code
    factor_value REAL NOT NULL,
    factor_unit TEXT NOT NULL,                  -- 'lb/ton', 'lb/MMBtu', 'lb/gallon', 'lb/lb'

    -- Factor source and documentation
    factor_source TEXT NOT NULL,                -- 'AP-42', 'state_guidance', 'manufacturer', 'stack_test'
    source_section TEXT,                        -- 'Table 12.19-1' for AP-42 references
    source_date TEXT,

    -- Applicability
    applicability_notes TEXT,
    rating TEXT,                                -- AP-42 rating: 'A', 'B', 'C', 'D', 'E'

    -- Time validity
    effective_date TEXT,
    superseded_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_air_factors_category ON air_emission_factors(source_category);
CREATE INDEX idx_air_factors_process ON air_emission_factors(process_type);
CREATE INDEX idx_air_factors_pollutant ON air_emission_factors(pollutant_code);
CREATE INDEX idx_air_factors_source ON air_emission_factors(factor_source);


-- ============================================================================
-- MATERIAL USAGE (from 006b — anchor operational table)
-- ============================================================================
-- Core tracking table. "What material, how much, when, where."

CREATE TABLE IF NOT EXISTS air_material_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    emission_unit_id INTEGER NOT NULL,
    material_id INTEGER NOT NULL,

    -- Time period
    usage_period_start TEXT NOT NULL,           -- YYYY-MM-DD (typically first of month)
    usage_period_end TEXT NOT NULL,

    -- Quantity
    quantity_used REAL NOT NULL,
    unit_of_measure TEXT NOT NULL,              -- 'lbs', 'gallons', 'therms', 'tons', 'cubic_feet'

    -- Data quality
    data_source TEXT,                          -- 'purchase_records', 'inventory_count', 'meter_reading', 'estimate'
    data_quality TEXT,                          -- 'measured', 'calculated', 'estimated'

    -- Who recorded
    recorded_by_employee_id INTEGER,
    recorded_at TEXT DEFAULT (datetime('now')),

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    FOREIGN KEY (material_id) REFERENCES air_emission_materials(id),
    FOREIGN KEY (recorded_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_air_usage_establishment ON air_material_usage(establishment_id);
CREATE INDEX idx_air_usage_unit ON air_material_usage(emission_unit_id);
CREATE INDEX idx_air_usage_material ON air_material_usage(material_id);
CREATE INDEX idx_air_usage_period ON air_material_usage(usage_period_start, usage_period_end);


-- ============================================================================
-- MATERIAL USAGE HISTORY (from 006b — audit trail)
-- ============================================================================

CREATE TABLE IF NOT EXISTS air_material_usage_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_usage_id INTEGER NOT NULL,

    change_type TEXT NOT NULL,                  -- 'insert', 'update', 'delete'
    changed_at TEXT DEFAULT (datetime('now')),
    changed_by_employee_id INTEGER,

    field_changed TEXT,
    old_value TEXT,
    new_value TEXT,

    change_reason TEXT NOT NULL,                -- Required for defensible records

    FOREIGN KEY (material_usage_id) REFERENCES air_material_usage(id),
    FOREIGN KEY (changed_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_air_usage_history_usage ON air_material_usage_history(material_usage_id);
CREATE INDEX idx_air_usage_history_date ON air_material_usage_history(changed_at);


-- ============================================================================
-- WELDING DETAILS (from 006b — source-specific extension)
-- ============================================================================
-- Only used when emission_unit.source_category = 'welding'

CREATE TABLE IF NOT EXISTS air_welding_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_usage_id INTEGER NOT NULL UNIQUE,  -- 1:1 with material_usage

    welding_process TEXT NOT NULL,              -- 'GMAW', 'GTAW', 'SMAW', 'FCAW', 'SAW'
    electrode_type TEXT,                        -- 'E70S-6', 'E7018', 'E71T-1'
    electrode_diameter TEXT,                    -- '0.035', '0.045', '3/32'

    shielding_gas TEXT,                         -- 'Ar', 'CO2', '75/25', 'None'
    base_metal TEXT,                            -- 'carbon_steel', 'stainless', 'aluminum', 'galvanized'

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (material_usage_id) REFERENCES air_material_usage(id) ON DELETE CASCADE
);

CREATE INDEX idx_air_welding_usage ON air_welding_details(material_usage_id);
CREATE INDEX idx_air_welding_process ON air_welding_details(welding_process);
CREATE INDEX idx_air_welding_base ON air_welding_details(base_metal);


-- ============================================================================
-- COATING DETAILS (from 006b — source-specific extension)
-- ============================================================================
-- Only used when emission_unit.source_category = 'coating'

CREATE TABLE IF NOT EXISTS air_coating_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_usage_id INTEGER NOT NULL UNIQUE,  -- 1:1 with material_usage

    application_method TEXT NOT NULL,           -- 'spray_hvlp', 'spray_conventional', 'spray_airless',
                                                -- 'brush', 'roller', 'dip', 'electrostatic',
                                                -- 'powder', 'electrocoat'
    transfer_efficiency_pct REAL,               -- NULL for electrocoat
    is_inside_booth INTEGER DEFAULT 1,

    reducer_added_gal REAL,
    reducer_material_id INTEGER,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (material_usage_id) REFERENCES air_material_usage(id) ON DELETE CASCADE,
    FOREIGN KEY (reducer_material_id) REFERENCES air_emission_materials(id)
);

CREATE INDEX idx_air_coating_usage ON air_coating_details(material_usage_id);
CREATE INDEX idx_air_coating_method ON air_coating_details(application_method);


-- ============================================================================
-- COMBUSTION DETAILS (from 006b — source-specific extension)
-- ============================================================================
-- Only used when emission_unit.source_category = 'combustion'

CREATE TABLE IF NOT EXISTS air_combustion_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_usage_id INTEGER NOT NULL UNIQUE,  -- 1:1 with material_usage

    equipment_type TEXT NOT NULL,               -- 'boiler', 'furnace', 'heater', 'generator',
                                                -- 'turbine', 'engine_ic'
    heat_input_rating_mmbtu REAL,              -- Max rated capacity (MMBtu/hr)
    operating_hours REAL,                       -- Hours operated during usage period
    burner_type TEXT,                           -- 'low_nox', 'standard', 'ultra_low_nox'

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (material_usage_id) REFERENCES air_material_usage(id) ON DELETE CASCADE
);

CREATE INDEX idx_air_combustion_usage ON air_combustion_details(material_usage_id);
CREATE INDEX idx_air_combustion_type ON air_combustion_details(equipment_type);


-- ============================================================================
-- CALCULATED EMISSIONS (from 006b — retained as-is)
-- ============================================================================
-- Stored emission calculations for audit trail.

CREATE TABLE IF NOT EXISTS air_calculated_emissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    emission_unit_id INTEGER NOT NULL,

    -- Link to source data
    material_usage_id INTEGER,                 -- FK (NULL for unit-level calcs)
    emission_factor_id INTEGER NOT NULL,

    -- Calculation period
    calculation_period_start TEXT NOT NULL,
    calculation_period_end TEXT NOT NULL,

    -- Result
    pollutant_code TEXT NOT NULL,               -- FK to air_pollutants.code
    gross_emissions REAL NOT NULL,              -- Before control efficiency
    gross_emissions_unit TEXT NOT NULL,         -- 'lbs', 'tons'

    -- Control device (if applicable)
    control_device_id INTEGER,
    control_efficiency_pct REAL,               -- Efficiency applied (snapshot)
    controlled_emissions REAL,                  -- After control (what's actually emitted)

    -- Calculation metadata
    calculation_method TEXT,                    -- 'factor', 'mass_balance', 'cems', 'stack_test'
    calculated_at TEXT DEFAULT (datetime('now')),
    calculated_by_employee_id INTEGER,

    -- Input values snapshot (for audit reproducibility)
    input_quantity REAL,
    input_unit TEXT,
    factor_value_used REAL,
    factor_unit_used TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    FOREIGN KEY (material_usage_id) REFERENCES air_material_usage(id),
    FOREIGN KEY (emission_factor_id) REFERENCES air_emission_factors(id),
    FOREIGN KEY (control_device_id) REFERENCES air_control_devices(id),
    FOREIGN KEY (calculated_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_air_calc_establishment ON air_calculated_emissions(establishment_id);
CREATE INDEX idx_air_calc_unit ON air_calculated_emissions(emission_unit_id);
CREATE INDEX idx_air_calc_usage ON air_calculated_emissions(material_usage_id);
CREATE INDEX idx_air_calc_pollutant ON air_calculated_emissions(pollutant_code);
CREATE INDEX idx_air_calc_period ON air_calculated_emissions(calculation_period_start, calculation_period_end);


-- ============================================================================
-- POTENTIAL TO EMIT (PTE) — the gateway calculation (from ontology)
-- ============================================================================
-- PTE is the maximum capacity of a source to emit a pollutant under its physical
-- and operational design. Calculated per emission unit per pollutant.
--
-- Pre-control PTE uses uncontrolled emission factors at max-rated capacity,
-- 24/365 unless federally enforceable restrictions apply. Post-control PTE
-- applies the guaranteed control device efficiency.
--
-- Facility PTE is the sum of all emission unit PTEs. A facility can accept
-- federally enforceable restrictions (via FESOP) to keep PTE below major
-- source thresholds — this is called taking a "synthetic minor" limitation.

CREATE TABLE IF NOT EXISTS air_potential_to_emit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    emission_unit_id INTEGER NOT NULL,
    pollutant_code TEXT NOT NULL,               -- FK to air_pollutants.code

    -- Calculation basis
    calculation_year INTEGER NOT NULL,          -- Year this PTE applies to
    calculation_basis TEXT NOT NULL,            -- 'unrestricted', 'restricted' (FESOP limits applied)

    -- PTE values (tons per year)
    pre_control_pte_tpy REAL NOT NULL,         -- Max capacity x max hours x emission factor
    control_device_id INTEGER,                 -- Which control device efficiency was applied
    control_efficiency_pct REAL,               -- Snapshot of efficiency used
    post_control_pte_tpy REAL NOT NULL,        -- Pre-control x (1 - efficiency/100)

    -- Calculation inputs snapshot (for reproducibility)
    max_throughput_used REAL,                   -- May be restricted throughput if FESOP
    max_throughput_unit TEXT,
    operating_hours_used REAL,                  -- May be restricted hours if FESOP (default 8760)
    emission_factor_id INTEGER,                -- Which factor was used
    emission_factor_value REAL,
    emission_factor_unit TEXT,

    -- Comparison to threshold
    applicable_threshold_id INTEGER,           -- FK to air_major_source_thresholds
    exceeds_threshold INTEGER,                 -- 0 = below, 1 = above major source threshold

    -- Documentation
    calculated_at TEXT DEFAULT (datetime('now')),
    calculated_by TEXT,
    methodology_notes TEXT,                     -- How PTE was determined (factor, stack test, etc.)

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    FOREIGN KEY (control_device_id) REFERENCES air_control_devices(id),
    FOREIGN KEY (emission_factor_id) REFERENCES air_emission_factors(id),
    FOREIGN KEY (applicable_threshold_id) REFERENCES air_major_source_thresholds(id),
    UNIQUE(emission_unit_id, pollutant_code, calculation_year, calculation_basis)
);

CREATE INDEX idx_air_pte_unit ON air_potential_to_emit(emission_unit_id);
CREATE INDEX idx_air_pte_pollutant ON air_potential_to_emit(pollutant_code);
CREATE INDEX idx_air_pte_year ON air_potential_to_emit(calculation_year);
CREATE INDEX idx_air_pte_exceeds ON air_potential_to_emit(exceeds_threshold);


-- ============================================================================
-- FACILITY PTE SUMMARY (rollup — determines major source status)
-- ============================================================================
-- Facility-wide PTE by pollutant type, compared against major source thresholds.
-- This is the decision point: does the facility need Title V or can it stay FESOP?

CREATE TABLE IF NOT EXISTS air_facility_pte_summary (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    calculation_year INTEGER NOT NULL,

    -- Pollutant aggregate
    pollutant_type_code TEXT NOT NULL,          -- FK to air_pollutant_types
    pollutant_code TEXT,                        -- Specific pollutant (NULL for combined HAP total)
    aggregation TEXT NOT NULL,                  -- 'single_pollutant', 'combined_haps', 'co2e'

    -- Facility-wide PTE (sum of all emission unit PTEs)
    total_pte_tpy REAL NOT NULL,               -- Sum of post_control_pte_tpy across all units

    -- Threshold comparison
    applicable_threshold_id INTEGER,           -- FK to air_major_source_thresholds
    threshold_tpy REAL,                        -- Snapshot of threshold value
    is_major_source INTEGER NOT NULL,          -- 0 = below threshold, 1 = major source

    -- Nonattainment adjustment (if applicable)
    nonattainment_area_id INTEGER,             -- FK to air_nonattainment_areas (NULL if attainment)

    -- Permit determination
    permit_type_required TEXT,                 -- 'TITLE_V' if major, 'FESOP' if synthetic minor

    -- Documentation
    determined_at TEXT DEFAULT (datetime('now')),
    determined_by TEXT,
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (pollutant_type_code) REFERENCES air_pollutant_types(code),
    FOREIGN KEY (applicable_threshold_id) REFERENCES air_major_source_thresholds(id),
    FOREIGN KEY (nonattainment_area_id) REFERENCES air_nonattainment_areas(id),
    FOREIGN KEY (permit_type_required) REFERENCES air_permit_types(code),
    UNIQUE(establishment_id, calculation_year, pollutant_type_code, aggregation, pollutant_code)
);

CREATE INDEX idx_air_fac_pte_establishment ON air_facility_pte_summary(establishment_id);
CREATE INDEX idx_air_fac_pte_year ON air_facility_pte_summary(calculation_year);
CREATE INDEX idx_air_fac_pte_major ON air_facility_pte_summary(is_major_source);


-- ============================================================================
-- COMPLIANCE ASSURANCE MONITORING (CAM) — from ontology
-- ============================================================================
-- 40 CFR Part 64. Required for emission units at major sources that use control
-- devices and have pre-control PTE above major source thresholds. Monitors
-- operational parameters that indicate control device performance.
--
-- CAM applicability per emission unit: (1) subject to emission limitation,
-- (2) uses a control device to achieve compliance, and (3) pre-control or
-- post-control PTE exceeds major source thresholds.

CREATE TABLE IF NOT EXISTS air_cam_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    emission_unit_id INTEGER NOT NULL,
    control_device_id INTEGER NOT NULL,

    -- Applicability determination
    is_cam_applicable INTEGER NOT NULL,        -- Result of the 3-prong test
    applicability_basis TEXT,                   -- Which emission limitation triggers CAM
    pre_control_pte_exceeds INTEGER,           -- Does pre-control PTE exceed threshold?

    -- Monitoring parameters (what to measure)
    -- Stored as structured data, not free text
    plan_status TEXT DEFAULT 'draft',          -- 'draft', 'submitted', 'approved', 'active'
    approved_date TEXT,
    approved_by TEXT,                           -- Permitting authority

    description TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    FOREIGN KEY (control_device_id) REFERENCES air_control_devices(id),
    UNIQUE(emission_unit_id, control_device_id)
);

CREATE INDEX idx_air_cam_unit ON air_cam_plans(emission_unit_id);
CREATE INDEX idx_air_cam_device ON air_cam_plans(control_device_id);
CREATE INDEX idx_air_cam_status ON air_cam_plans(plan_status);


-- ============================================================================
-- CAM MONITORING INDICATORS (parameters tracked per CAM plan)
-- ============================================================================
-- Each CAM plan specifies one or more indicator parameters with acceptable
-- ranges. Excursions from these ranges trigger corrective action and reporting.

CREATE TABLE IF NOT EXISTS air_cam_indicators (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cam_plan_id INTEGER NOT NULL,

    parameter TEXT NOT NULL,                    -- 'pressure_drop', 'temperature', 'opacity', 'flow_rate', 'voltage'
    unit TEXT NOT NULL,                         -- 'in_wc', 'degrees_f', 'percent', 'cfm', 'kV'

    -- Acceptable range (excursion = outside this range)
    indicator_range_low REAL,
    indicator_range_high REAL,

    -- Monitoring frequency
    monitoring_frequency TEXT,                  -- 'continuous', 'daily', 'weekly', 'monthly'
    data_collection_method TEXT,                -- 'cems', 'manual_reading', 'datalogger'

    description TEXT,

    FOREIGN KEY (cam_plan_id) REFERENCES air_cam_plans(id) ON DELETE CASCADE
);

CREATE INDEX idx_air_cam_ind_plan ON air_cam_indicators(cam_plan_id);


-- ============================================================================
-- CONTROL DEVICE MONITORING (from 006b — enhanced for CAM)
-- ============================================================================
-- Operating parameter monitoring: pressure drops, temperatures, etc.
-- Now links to CAM indicator for compliance tracking when CAM applies.

CREATE TABLE IF NOT EXISTS air_control_monitoring (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    control_device_id INTEGER NOT NULL,

    monitoring_date TEXT NOT NULL,              -- YYYY-MM-DD
    monitoring_time TEXT,                       -- HH:MM

    -- Reading
    parameter TEXT NOT NULL,                    -- 'pressure_drop', 'temperature', 'opacity', 'flow_rate'
    value REAL NOT NULL,
    unit TEXT NOT NULL,                         -- 'in_wc', 'degrees_f', 'percent', 'cfm'

    -- Compliance range
    min_limit REAL,
    max_limit REAL,
    within_range INTEGER,                      -- 0 = out of range, 1 = within range

    -- CAM linkage (NULL if not under CAM)
    cam_indicator_id INTEGER,                  -- FK to air_cam_indicators
    is_cam_excursion INTEGER DEFAULT 0,        -- 1 if this reading is a CAM excursion

    -- Who recorded
    recorded_by_employee_id INTEGER,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (control_device_id) REFERENCES air_control_devices(id),
    FOREIGN KEY (cam_indicator_id) REFERENCES air_cam_indicators(id),
    FOREIGN KEY (recorded_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_air_monitoring_device ON air_control_monitoring(control_device_id);
CREATE INDEX idx_air_monitoring_date ON air_control_monitoring(monitoring_date);
CREATE INDEX idx_air_monitoring_param ON air_control_monitoring(parameter);
CREATE INDEX idx_air_monitoring_cam ON air_control_monitoring(cam_indicator_id);
CREATE INDEX idx_air_monitoring_excursion ON air_control_monitoring(is_cam_excursion);


-- ============================================================================
-- ANNUAL EMISSIONS INVENTORY (from 006b — retained as-is)
-- ============================================================================
-- Rollup for regulatory reporting (MAERS, state inventories).

CREATE TABLE IF NOT EXISTS air_annual_inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    reporting_year INTEGER NOT NULL,

    emission_unit_id INTEGER NOT NULL,
    stack_id INTEGER,

    pollutant_code TEXT NOT NULL,
    annual_emissions REAL NOT NULL,             -- Controlled emissions in tons
    emissions_unit TEXT NOT NULL,               -- 'tons'

    calculation_method TEXT,                    -- 'factor', 'mass_balance', 'cems', 'stack_test'
    data_quality TEXT,                          -- 'measured', 'calculated', 'estimated'

    -- Finalization
    is_finalized INTEGER DEFAULT 0,
    finalized_at TEXT,
    finalized_by_employee_id INTEGER,

    -- Submission tracking
    is_submitted INTEGER DEFAULT 0,
    submitted_at TEXT,
    submission_method TEXT,                     -- 'MAERS', 'state_portal', 'paper'
    confirmation_number TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    FOREIGN KEY (stack_id) REFERENCES air_stacks(id),
    FOREIGN KEY (finalized_by_employee_id) REFERENCES employees(id),
    UNIQUE(establishment_id, reporting_year, emission_unit_id, pollutant_code)
);

CREATE INDEX idx_air_inventory_establishment ON air_annual_inventory(establishment_id);
CREATE INDEX idx_air_inventory_year ON air_annual_inventory(reporting_year);
CREATE INDEX idx_air_inventory_unit ON air_annual_inventory(emission_unit_id);
CREATE INDEX idx_air_inventory_pollutant ON air_annual_inventory(pollutant_code);
CREATE INDEX idx_air_inventory_finalized ON air_annual_inventory(is_finalized);


-- ============================================================================
-- CROSS-MODULE: EMISSION UNIT CHEMICALS (usesChemical / emittedFromUnit)
-- ============================================================================
-- From ontology v3.1 cross-module wiring. Links emission units to Module A
-- chemical inventory. A single chemical (e.g., toluene) appears in both the
-- facility's chemical inventory (Tier II tracking) and as a pollutant emitted
-- from an emission unit (PTE and permit limits). Enables the three-way
-- linkage: inventory tracking -> emission unit -> TRI release quantity.

CREATE TABLE IF NOT EXISTS air_emission_unit_chemicals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    emission_unit_id INTEGER NOT NULL,
    chemical_id INTEGER NOT NULL,              -- FK to chemicals table (Module A)

    -- How this chemical relates to the emission unit
    relationship TEXT NOT NULL,                -- 'consumed' (input), 'emitted' (output), 'both'

    -- Pollutant mapping (which air pollutant does this chemical map to?)
    pollutant_code TEXT,                        -- FK to air_pollutants.code (e.g., toluene -> 'Toluene' HAP)

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    FOREIGN KEY (chemical_id) REFERENCES chemicals(id),
    UNIQUE(emission_unit_id, chemical_id)
);

CREATE INDEX idx_air_eu_chem_unit ON air_emission_unit_chemicals(emission_unit_id);
CREATE INDEX idx_air_eu_chem_chemical ON air_emission_unit_chemicals(chemical_id);


-- ============================================================================
-- CROSS-MODULE: EMPLOYEE EMISSION UNIT ASSIGNMENTS (worksAtEmissionUnit)
-- ============================================================================
-- From ontology v3.1 cross-module wiring. Links employees to the emission
-- units where they work. Bridges occupational health and environmental
-- compliance: workers at emission units face chemical exposure from the same
-- pollutants regulated under the Title V permit. Enables querying: "which
-- employees work at emission units that emit HAPs above the OEL?"

CREATE TABLE IF NOT EXISTS air_employee_assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_id INTEGER NOT NULL,
    emission_unit_id INTEGER NOT NULL,

    -- Assignment period
    assignment_start_date TEXT NOT NULL,        -- YYYY-MM-DD
    assignment_end_date TEXT,                   -- NULL if current

    -- Role at this unit
    role TEXT,                                  -- 'operator', 'maintenance', 'supervisor', 'helper'
    is_primary_assignment INTEGER DEFAULT 1,   -- 1 if this is their primary work location

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (employee_id) REFERENCES employees(id),
    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id)
);

CREATE INDEX idx_air_emp_assign_employee ON air_employee_assignments(employee_id);
CREATE INDEX idx_air_emp_assign_unit ON air_employee_assignments(emission_unit_id);
CREATE INDEX idx_air_emp_assign_active ON air_employee_assignments(assignment_end_date);


-- ============================================================================
-- SEED DATA: COMMON EMISSION FACTORS (from 006b)
-- ============================================================================

-- Welding Emission Factors (AP-42, Section 12.19)
INSERT OR IGNORE INTO air_emission_factors
    (id, source_category, process_type, material_match, pollutant_code,
     factor_value, factor_unit, factor_source, source_section, rating) VALUES
    -- GMAW (MIG) - Carbon Steel
    (1, 'welding', 'GMAW', 'carbon_steel', 'PM', 6.6, 'lb/ton', 'AP-42', '12.19', 'D'),
    (2, 'welding', 'GMAW', 'carbon_steel', 'PM10', 5.6, 'lb/ton', 'AP-42', '12.19', 'D'),
    (3, 'welding', 'GMAW', 'carbon_steel', 'PM25', 5.4, 'lb/ton', 'AP-42', '12.19', 'D'),
    (4, 'welding', 'GMAW', 'carbon_steel', 'Mn', 0.43, 'lb/ton', 'AP-42', '12.19', 'E'),

    -- SMAW (Stick) - Carbon Steel
    (10, 'welding', 'SMAW', 'carbon_steel', 'PM', 11.0, 'lb/ton', 'AP-42', '12.19', 'D'),
    (11, 'welding', 'SMAW', 'carbon_steel', 'PM10', 9.9, 'lb/ton', 'AP-42', '12.19', 'D'),
    (12, 'welding', 'SMAW', 'carbon_steel', 'PM25', 9.5, 'lb/ton', 'AP-42', '12.19', 'D'),

    -- FCAW (Flux-core) - Carbon Steel
    (20, 'welding', 'FCAW', 'carbon_steel', 'PM', 16.0, 'lb/ton', 'AP-42', '12.19', 'D'),
    (21, 'welding', 'FCAW', 'carbon_steel', 'PM10', 14.0, 'lb/ton', 'AP-42', '12.19', 'D'),
    (22, 'welding', 'FCAW', 'carbon_steel', 'PM25', 13.0, 'lb/ton', 'AP-42', '12.19', 'D'),

    -- GTAW (TIG) - All metals (very low emissions)
    (30, 'welding', 'GTAW', NULL, 'PM', 0.04, 'lb/ton', 'AP-42', '12.19', 'E'),
    (31, 'welding', 'GTAW', NULL, 'PM10', 0.03, 'lb/ton', 'AP-42', '12.19', 'E'),

    -- GMAW - Stainless Steel (includes hexavalent chromium)
    (40, 'welding', 'GMAW', 'stainless', 'PM', 8.0, 'lb/ton', 'AP-42', '12.19', 'D'),
    (41, 'welding', 'GMAW', 'stainless', 'Cr', 0.6, 'lb/ton', 'AP-42', '12.19', 'E'),
    (42, 'welding', 'GMAW', 'stainless', 'Cr6', 0.06, 'lb/ton', 'AP-42', '12.19', 'E'),
    (43, 'welding', 'GMAW', 'stainless', 'Ni', 0.3, 'lb/ton', 'AP-42', '12.19', 'E'),

    -- GMAW - Galvanized (zinc emissions)
    (50, 'welding', 'GMAW', 'galvanized', 'PM', 15.0, 'lb/ton', 'AP-42', '12.19', 'E'),
    (51, 'welding', 'GMAW', 'galvanized', 'Zn', 4.0, 'lb/ton', 'AP-42', '12.19', 'E');

-- Combustion Emission Factors (AP-42, Section 1.4 - Natural Gas)
INSERT OR IGNORE INTO air_emission_factors
    (id, source_category, process_type, material_match, pollutant_code,
     factor_value, factor_unit, factor_source, source_section, rating) VALUES
    -- Natural Gas - Small Boilers (<100 MMBtu/hr)
    (100, 'combustion', 'boiler', 'natural_gas', 'NOx', 100.0, 'lb/MMscf', 'AP-42', '1.4', 'A'),
    (101, 'combustion', 'boiler', 'natural_gas', 'CO', 84.0, 'lb/MMscf', 'AP-42', '1.4', 'A'),
    (102, 'combustion', 'boiler', 'natural_gas', 'PM', 7.6, 'lb/MMscf', 'AP-42', '1.4', 'A'),
    (103, 'combustion', 'boiler', 'natural_gas', 'PM10', 7.6, 'lb/MMscf', 'AP-42', '1.4', 'A'),
    (104, 'combustion', 'boiler', 'natural_gas', 'PM25', 7.6, 'lb/MMscf', 'AP-42', '1.4', 'A'),
    (105, 'combustion', 'boiler', 'natural_gas', 'SO2', 0.6, 'lb/MMscf', 'AP-42', '1.4', 'A'),
    (106, 'combustion', 'boiler', 'natural_gas', 'VOC', 5.5, 'lb/MMscf', 'AP-42', '1.4', 'B'),

    -- Natural Gas - Low-NOx Burner
    (110, 'combustion', 'boiler_low_nox', 'natural_gas', 'NOx', 50.0, 'lb/MMscf', 'AP-42', '1.4', 'B'),

    -- Propane (LPG) - Industrial
    (120, 'combustion', 'boiler', 'propane', 'NOx', 130.0, 'lb/1000gal', 'AP-42', '1.5', 'B'),
    (121, 'combustion', 'boiler', 'propane', 'CO', 51.0, 'lb/1000gal', 'AP-42', '1.5', 'B'),
    (122, 'combustion', 'boiler', 'propane', 'PM', 3.4, 'lb/1000gal', 'AP-42', '1.5', 'B');

-- Coating Emission Factors (mass balance approach)
INSERT OR IGNORE INTO air_emission_factors
    (id, source_category, process_type, material_match, pollutant_code,
     factor_value, factor_unit, factor_source, applicability_notes) VALUES
    (200, 'coating', 'spray_hvlp', NULL, 'VOC', 1.0, 'lb/lb_voc', 'mass_balance',
     'Applied to VOC content x quantity used'),
    (201, 'coating', 'spray_conventional', NULL, 'VOC', 1.0, 'lb/lb_voc', 'mass_balance',
     'Applied to VOC content x quantity used'),
    (202, 'coating', 'electrocoat', NULL, 'VOC', 1.0, 'lb/lb_voc', 'mass_balance',
     'Applied to VOC content x replenishment quantity'),

    -- PM from spray (overspray particulate)
    (210, 'coating', 'spray_hvlp', NULL, 'PM', 0.35, 'lb/lb_solids', 'EPA guidance',
     'Based on 65% transfer efficiency'),
    (211, 'coating', 'spray_conventional', NULL, 'PM', 0.70, 'lb/lb_solids', 'EPA guidance',
     'Based on 30% transfer efficiency');


-- ============================================================================
-- SEED DATA: COMMON TECHNOLOGY STANDARDS
-- ============================================================================
-- A sampling of frequently applicable MACT and NSPS subparts for small
-- manufacturing. Users add their own as applicability is determined.

INSERT OR IGNORE INTO air_technology_standards
    (id, standard_type_code, subpart, title, cfr_citation, source_categories, applicability_criteria) VALUES
    -- MACT standards (40 CFR Part 63)
    (1, 'MACT', 'Subpart MMMM', 'Surface Coating of Miscellaneous Metal Parts and Products',
     '40 CFR 63 Subpart MMMM', 'coating',
     'Facilities that coat metal parts and use 264+ gallons/year of coating. Major source of HAPs.'),
    (2, 'MACT', 'Subpart XXXXXX', 'Nine Metal Fabrication and Finishing Source Categories (Area Source)',
     '40 CFR 63 Subpart XXXXXX', 'welding',
     'Area sources performing welding, cutting, brazing on metals with HAP-containing filler or base metal.'),
    (3, 'MACT', 'Subpart ZZZZZZ', 'Area Source Standards for Aluminum, Copper, and Other Nonferrous Foundries',
     '40 CFR 63 Subpart ZZZZZZ', 'combustion,material_handling',
     'Area source nonferrous foundries.'),
    (4, 'MACT', 'Subpart DDDDD', 'Industrial, Commercial, and Institutional Boilers and Process Heaters (Major)',
     '40 CFR 63 Subpart DDDDD', 'combustion',
     'Major source boilers and process heaters.'),
    (5, 'MACT', 'Subpart JJJJJJ', 'Industrial, Commercial, and Institutional Boilers (Area Source)',
     '40 CFR 63 Subpart JJJJJJ', 'combustion',
     'Area source boilers at commercial, industrial, and institutional facilities.'),

    -- NSPS standards (40 CFR Part 60)
    (10, 'NSPS', 'Subpart Dc', 'Small Industrial-Commercial-Institutional Steam Generating Units',
     '40 CFR 60 Subpart Dc', 'combustion',
     'Steam generating units with heat input capacity 10-100 MMBtu/hr constructed/modified/reconstructed after June 9, 1989.'),
    (11, 'NSPS', 'Subpart IIII', 'Stationary Compression Ignition Internal Combustion Engines',
     '40 CFR 60 Subpart IIII', 'combustion',
     'Stationary CI ICE (diesel generators, fire pumps) manufactured after April 1, 2006.'),
    (12, 'NSPS', 'Subpart JJJJ', 'Stationary Spark Ignition Internal Combustion Engines',
     '40 CFR 60 Subpart JJJJ', 'combustion',
     'Stationary SI ICE (natural gas engines) manufactured after July 1, 2007.');


-- ============================================================================
-- VIEWS
-- ============================================================================

-- Current material properties (non-superseded)
CREATE VIEW IF NOT EXISTS v_air_material_properties_current AS
SELECT
    m.id AS material_id,
    m.material_name,
    m.material_category,
    p.property_key,
    p.property_value,
    p.property_unit,
    p.source,
    p.effective_date
FROM air_emission_materials m
LEFT JOIN air_material_properties p ON m.id = p.material_id
WHERE p.superseded_date IS NULL
   OR p.id IS NULL;


-- Material usage joined with source-specific details
CREATE VIEW IF NOT EXISTS v_air_usage_with_details AS
SELECT
    u.id AS usage_id,
    u.establishment_id,
    u.emission_unit_id,
    eu.unit_name,
    eu.source_category,

    u.material_id,
    m.material_name,
    m.material_category,

    u.usage_period_start,
    u.usage_period_end,
    u.quantity_used,
    u.unit_of_measure,
    u.data_source,

    -- Welding details (NULL if not welding)
    wd.welding_process,
    wd.electrode_type,
    wd.base_metal,
    wd.shielding_gas,

    -- Coating details (NULL if not coating)
    cd.application_method,
    cd.transfer_efficiency_pct,
    cd.reducer_added_gal,

    -- Combustion details (NULL if not combustion)
    cbd.equipment_type,
    cbd.heat_input_rating_mmbtu,
    cbd.operating_hours,
    cbd.burner_type

FROM air_material_usage u
INNER JOIN air_emission_units eu ON u.emission_unit_id = eu.id
INNER JOIN air_emission_materials m ON u.material_id = m.id
LEFT JOIN air_welding_details wd ON u.id = wd.material_usage_id
LEFT JOIN air_coating_details cd ON u.id = cd.material_usage_id
LEFT JOIN air_combustion_details cbd ON u.id = cbd.material_usage_id;


-- Current control efficiency by device and pollutant
CREATE VIEW IF NOT EXISTS v_air_control_efficiency_current AS
SELECT
    cd.id AS control_device_id,
    cd.device_name,
    cd.device_type,
    cd.emission_unit_id,
    ce.pollutant_code,
    ce.control_efficiency_pct,
    ce.efficiency_source,
    ce.effective_date
FROM air_control_devices cd
INNER JOIN air_control_efficiency ce ON cd.id = ce.control_device_id
WHERE cd.is_active = 1
  AND ce.superseded_date IS NULL;


-- Calculated emissions summary by emission unit and month
CREATE VIEW IF NOT EXISTS v_air_emissions_by_unit AS
SELECT
    ce.establishment_id,
    e.name AS establishment_name,
    ce.emission_unit_id,
    eu.unit_name,
    eu.source_category,
    ce.pollutant_code,

    strftime('%Y', ce.calculation_period_start) AS year,
    strftime('%m', ce.calculation_period_start) AS month,

    SUM(ce.gross_emissions) AS total_gross_lbs,
    SUM(ce.controlled_emissions) AS total_controlled_lbs,
    SUM(ce.controlled_emissions) / 2000.0 AS total_controlled_tons

FROM air_calculated_emissions ce
INNER JOIN establishments e ON ce.establishment_id = e.id
INNER JOIN air_emission_units eu ON ce.emission_unit_id = eu.id
GROUP BY
    ce.establishment_id, e.name,
    ce.emission_unit_id, eu.unit_name, eu.source_category,
    ce.pollutant_code,
    strftime('%Y', ce.calculation_period_start),
    strftime('%m', ce.calculation_period_start)
ORDER BY year DESC, month DESC, eu.unit_name, ce.pollutant_code;


-- Facility-wide emissions summary by pollutant
CREATE VIEW IF NOT EXISTS v_air_emissions_by_pollutant AS
SELECT
    ce.establishment_id,
    e.name AS establishment_name,
    ce.pollutant_code,

    strftime('%Y', ce.calculation_period_start) AS year,

    SUM(ce.gross_emissions) AS annual_gross_lbs,
    SUM(ce.controlled_emissions) AS annual_controlled_lbs,
    SUM(ce.controlled_emissions) / 2000.0 AS annual_controlled_tons

FROM air_calculated_emissions ce
INNER JOIN establishments e ON ce.establishment_id = e.id
GROUP BY
    ce.establishment_id, e.name,
    ce.pollutant_code,
    strftime('%Y', ce.calculation_period_start)
ORDER BY year DESC, ce.pollutant_code;


-- PTE vs threshold comparison (the gateway decision)
CREATE VIEW IF NOT EXISTS v_air_pte_vs_threshold AS
SELECT
    eu.establishment_id,
    e.name AS establishment_name,
    pte.emission_unit_id,
    eu.unit_name,
    eu.source_category,
    pte.pollutant_code,
    p.name AS pollutant_name,
    pte.calculation_year,
    pte.calculation_basis,
    pte.pre_control_pte_tpy,
    pte.post_control_pte_tpy,
    t.threshold_tpy,
    t.threshold_applies_to,
    t.attainment_status,
    pte.exceeds_threshold,
    CASE
        WHEN pte.exceeds_threshold = 1 THEN 'MAJOR SOURCE'
        ELSE 'BELOW THRESHOLD'
    END AS status
FROM air_potential_to_emit pte
INNER JOIN air_emission_units eu ON pte.emission_unit_id = eu.id
INNER JOIN establishments e ON eu.establishment_id = e.id
LEFT JOIN air_pollutants p ON pte.pollutant_code = p.code
LEFT JOIN air_major_source_thresholds t ON pte.applicable_threshold_id = t.id
ORDER BY pte.calculation_year DESC, eu.unit_name, pte.pollutant_code;


-- Facility major source determination summary
CREATE VIEW IF NOT EXISTS v_air_facility_major_source_status AS
SELECT
    fps.establishment_id,
    e.name AS establishment_name,
    fps.calculation_year,
    fps.pollutant_type_code,
    pt.name AS pollutant_type_name,
    fps.aggregation,
    fps.total_pte_tpy,
    fps.threshold_tpy,
    fps.is_major_source,
    fps.permit_type_required,
    naa.area_name AS nonattainment_area,
    naa.classification AS nonattainment_classification
FROM air_facility_pte_summary fps
INNER JOIN establishments e ON fps.establishment_id = e.id
INNER JOIN air_pollutant_types pt ON fps.pollutant_type_code = pt.code
LEFT JOIN air_nonattainment_areas naa ON fps.nonattainment_area_id = naa.id
ORDER BY fps.calculation_year DESC, fps.pollutant_type_code;


-- Annual inventory completion status
CREATE VIEW IF NOT EXISTS v_air_inventory_status AS
SELECT
    ai.establishment_id,
    e.name AS establishment_name,
    ai.reporting_year,

    COUNT(*) AS total_records,
    SUM(CASE WHEN ai.is_finalized = 1 THEN 1 ELSE 0 END) AS finalized_records,
    SUM(CASE WHEN ai.is_submitted = 1 THEN 1 ELSE 0 END) AS submitted_records,

    CASE
        WHEN SUM(CASE WHEN ai.is_submitted = 0 THEN 1 ELSE 0 END) = 0 THEN 'SUBMITTED'
        WHEN SUM(CASE WHEN ai.is_finalized = 0 THEN 1 ELSE 0 END) = 0 THEN 'FINALIZED'
        ELSE 'IN_PROGRESS'
    END AS status,

    GROUP_CONCAT(DISTINCT ai.pollutant_code) AS pollutants_reported

FROM air_annual_inventory ai
INNER JOIN establishments e ON ai.establishment_id = e.id
GROUP BY ai.establishment_id, e.name, ai.reporting_year
ORDER BY ai.reporting_year DESC, e.name;


-- Recent control device monitoring with compliance status
CREATE VIEW IF NOT EXISTS v_air_control_monitoring_recent AS
SELECT
    cm.id,
    cd.device_name,
    cd.device_type,
    eu.unit_name,
    cm.monitoring_date,
    cm.parameter,
    cm.value,
    cm.unit,
    cm.min_limit,
    cm.max_limit,
    cm.within_range,
    cm.is_cam_excursion,

    CASE
        WHEN cm.is_cam_excursion = 1 THEN 'CAM_EXCURSION'
        WHEN cm.within_range = 0 THEN 'OUT_OF_RANGE'
        ELSE 'OK'
    END AS status

FROM air_control_monitoring cm
INNER JOIN air_control_devices cd ON cm.control_device_id = cd.id
LEFT JOIN air_emission_units eu ON cd.emission_unit_id = eu.id
WHERE cm.monitoring_date >= date('now', '-90 days')
ORDER BY cm.monitoring_date DESC, cd.device_name;


-- Employees at emission units with HAP exposure (cross-module bridge query)
CREATE VIEW IF NOT EXISTS v_air_employee_hap_exposure AS
SELECT
    emp.id AS employee_id,
    emp.first_name || ' ' || emp.last_name AS employee_name,
    emp.job_title,
    ea.role,
    eu.id AS emission_unit_id,
    eu.unit_name,
    eu.source_category,
    p.code AS pollutant_code,
    p.name AS pollutant_name,
    ptm.type_code AS pollutant_type,
    pte.post_control_pte_tpy
FROM air_employee_assignments ea
INNER JOIN employees emp ON ea.employee_id = emp.id
INNER JOIN air_emission_units eu ON ea.emission_unit_id = eu.id
INNER JOIN air_potential_to_emit pte ON eu.id = pte.emission_unit_id
INNER JOIN air_pollutants p ON pte.pollutant_code = p.code
INNER JOIN air_pollutant_type_map ptm ON p.code = ptm.pollutant_code
WHERE ea.assignment_end_date IS NULL            -- Currently assigned
  AND ptm.type_code = 'HAP'                    -- HAP pollutants only
  AND pte.post_control_pte_tpy > 0             -- Non-zero emissions
ORDER BY emp.last_name, eu.unit_name, p.name;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-log material usage changes to history table
CREATE TRIGGER IF NOT EXISTS trg_air_usage_insert
AFTER INSERT ON air_material_usage
FOR EACH ROW
BEGIN
    INSERT INTO air_material_usage_history
        (material_usage_id, change_type, changed_by_employee_id, change_reason)
    VALUES
        (NEW.id, 'insert', NEW.recorded_by_employee_id, 'Initial entry');
END;

CREATE TRIGGER IF NOT EXISTS trg_air_usage_update
AFTER UPDATE ON air_material_usage
FOR EACH ROW
WHEN OLD.quantity_used != NEW.quantity_used
BEGIN
    INSERT INTO air_material_usage_history
        (material_usage_id, change_type, changed_by_employee_id,
         field_changed, old_value, new_value, change_reason)
    VALUES
        (NEW.id, 'update', NEW.recorded_by_employee_id,
         'quantity_used', CAST(OLD.quantity_used AS TEXT), CAST(NEW.quantity_used AS TEXT),
         COALESCE(NEW.notes, 'Quantity updated'));
END;
