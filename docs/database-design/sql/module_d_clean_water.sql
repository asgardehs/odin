-- Module D: Clean Water Act Discharge & Monitoring
-- Derived from ehs-ontology-v3.2.ttl — Module D (Clean Water Act)
-- Plan: docs/plans/2026-04-20-module-d-csv-import-pdf-forms.md (Phase 1)
--
-- This module consolidates CWA-distinctive SQL under one file to match the
-- ontology's Module D scope. It is a combination of:
--   1. RELOCATION from module_industrial_waste_streams.sql — the ww_* cluster
--      (10 tables + 6 views + 1 trigger) was originally placed in the RCRA
--      hazardous-waste file but belongs to CWA / Module D in v3.2.
--   2. GAP FILL — four new tables that give physical outfalls, SWPPP
--      documents, BMP catalogs, and MSGP benchmarks their own entities. The
--      ww_parameters reference table gains a pollutant_type_code discriminator
--      aligned with the v3.2 ehs:WaterPollutant taxonomy.
--
-- Design principles (from the plan):
--   - NPDES / POTW / stormwater permits live in the generic permits table
--     (module_permits_licenses.sql) with permit_type_id = 10..14. Module D
--     does NOT create an npdes_permits table. ehs:NPDESPermit ⊂ ehs:Permit
--     in the ontology maps cleanly to shared-table polymorphism.
--   - Module D distinctive tables own what air permits don't have: outfalls
--     as physical objects, a water-pollutant reference table, discharge
--     monitoring events / results / flow, SWPPPs as living documents, and
--     MSGP benchmarks as regulatory reference data.
--   - Ontology-to-SQL map:
--       ehs:WaterPollutant / taxonomy → water_pollutant_types + ww_parameters
--       ehs:DischargePoint → discharge_points
--       ehs:StormwaterOutfall → discharge_points where discharge_type includes
--                               'stormwater'
--       ehs:MonitoringLocation → ww_monitoring_locations
--       ehs:WastewaterTreatmentUnit → air_emission_units (reused; the existing
--                                     emission-unit modeling covers process
--                                     units whose outputs are waterborne)
--       ehs:SWPPP → sw_swpps
--       ehs:BestManagementPractice → sw_bmps
--       ehs:NPDESPermit / POTWDischargePermit → permits (generic)
--       ehs:dischargesTo → discharge_points.emission_unit_id
--       ehs:monitoredAt → ww_monitoring_locations.discharge_point_id
--       ehs:sampledFor → ww_monitoring_requirements(location_id,parameter_id)
--       ehs:subjectToPermit → discharge_points.permit_id
--       ehs:coveredBy → discharge_points.swppp_id
--       ehs:implements → sw_bmps.swppp_id
--
-- Load order: after module_b_title_v_caa.sql (air_emission_units FK),
-- module_c_osha300.sql (establishments, employees), and
-- module_permits_licenses.sql (permits, permit_conditions).
-- Migration is idempotent — every CREATE uses IF NOT EXISTS, and the
-- _migrations tracking table in internal/database/migrate.go prevents
-- re-application on existing DBs where the relocated tables already live.


-- ============================================================================
-- REFERENCE: WATER POLLUTANT TYPES (ontology WaterPollutant subclasses)
-- ============================================================================
-- Four categories from the v3.2 ontology. A pollutant belongs to exactly
-- one category (unlike air, where toluene can be both HAP and VOC).

CREATE TABLE IF NOT EXISTS water_pollutant_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_reference TEXT
);

INSERT OR IGNORE INTO water_pollutant_types (code, name, description, cfr_reference) VALUES
    ('CONVENTIONAL', 'Conventional Pollutant',
     'One of five pollutants identified by EPA under CWA Section 304(a)(4) as conventional: biochemical oxygen demand (BOD), total suspended solids (TSS), pH, oil and grease, and fecal coliform. Technology-based limits set by Best Conventional Pollutant Control Technology (BCT).',
     '40 CFR 401.16; 40 CFR 125.3'),
    ('PRIORITY', 'Priority Pollutant',
     'One of 126 toxic pollutants listed by EPA under CWA Section 307(a) and codified at 40 CFR 423 Appendix A. Includes metals, volatile organics, acid extractables, base/neutral extractables, and pesticides. Technology-based limits set by Best Available Technology Economically Achievable (BAT).',
     '40 CFR 423 App A; CWA 307(a)'),
    ('NONCONVENTIONAL', 'Non-Conventional Pollutant',
     'Any water pollutant that is neither conventional nor on the priority pollutant list but is still regulated under an NPDES permit. Includes nutrients (ammonia, nitrate, total N, total P), chloride, sulfate, fluoride, TDS. Limits are set case-by-case driven by receiving-water quality standards.',
     'CWA 402 (case-by-case)'),
    ('WET', 'Whole Effluent Toxicity',
     'Aggregate toxic effect measured directly via bioassay rather than chemical analysis. Limits expressed as acute or chronic toxic units (TUa, TUc). Required in NPDES permits where receiving-water quality cannot be assured by individual chemical-specific limits.',
     '40 CFR 136');


-- ============================================================================
-- REFERENCE: MSGP INDUSTRIAL SECTORS
-- ============================================================================
-- Stormwater general permit sector mapping. Each industrial sector has its
-- own set of benchmark monitoring values. Used by discharge_points and
-- sw_outfall_benchmarks to determine which benchmarks apply.

CREATE TABLE IF NOT EXISTS sw_industrial_sectors (
    code TEXT PRIMARY KEY,                      -- 'AA', 'AB', 'C', 'N', etc.
    sic_prefix TEXT,                            -- 'SIC 2812', '3471', etc. (may be list)
    name TEXT NOT NULL,
    description TEXT,
    msgp_part TEXT,                             -- MSGP Part 8 subsection reference
    notes TEXT
);

INSERT OR IGNORE INTO sw_industrial_sectors (code, sic_prefix, name, description, msgp_part) VALUES
    ('A',  '24',      'Timber Products',                  'Wood preserving, sawmills, plywood.',                          'MSGP Part 8.A'),
    ('B',  '26',      'Paper and Allied Products',        'Pulp mills, paper mills, paperboard mills.',                   'MSGP Part 8.B'),
    ('C',  '28',      'Chemical and Allied Products',     'Industrial inorganics, plastics, pharma, paints, fertilizers.','MSGP Part 8.C'),
    ('D',  '29',      'Asphalt Paving and Roofing',       'Asphalt paving mixtures, asphalt roofing materials.',          'MSGP Part 8.D'),
    ('E',  '32',      'Glass, Clay, Cement, Concrete',    'Flat glass, cement, concrete products, cut stone.',            'MSGP Part 8.E'),
    ('F',  '33',      'Primary Metals',                   'Steel, iron foundries, nonferrous smelting/refining.',         'MSGP Part 8.F'),
    ('G',  '10',      'Metal Mining',                     'Metal mining and associated activities.',                      'MSGP Part 8.G'),
    ('H',  '12',      'Coal Mines and Prep',              'Coal mining, coal preparation plants.',                        'MSGP Part 8.H'),
    ('I',  '13',      'Oil and Gas Extraction',           'Oil and gas extraction, well services.',                       'MSGP Part 8.I'),
    ('J',  '14',      'Mineral Mining',                   'Nonmetallic minerals (sand, gravel, stone).',                  'MSGP Part 8.J'),
    ('K',  '4953',    'Hazardous Waste TSDFs',            'Hazardous waste treatment, storage, disposal facilities.',     'MSGP Part 8.K'),
    ('L',  '4953',    'Landfills',                        'Landfills, land application sites, open dumps.',               'MSGP Part 8.L'),
    ('M',  '5015',    'Automobile Salvage',               'Automotive dismantling and recycling.',                        'MSGP Part 8.M'),
    ('N',  '5093',    'Scrap Recycling',                  'Scrap and waste materials, recycling facilities.',             'MSGP Part 8.N'),
    ('O',  '4911',    'Steam Electric',                   'Steam electric power generation.',                             'MSGP Part 8.O'),
    ('P',  '4221',    'Land Transportation',              'Trucking terminals, maintenance facilities.',                  'MSGP Part 8.P'),
    ('Q',  '44',      'Water Transportation',             'Ship and boat building, shipyards, marinas.',                  'MSGP Part 8.Q'),
    ('R',  '37',      'Transportation Equipment',         'Motor vehicles, aircraft, ship building.',                     'MSGP Part 8.R'),
    ('S',  '45',      'Air Transportation',               'Airports, flying fields, airport terminals.',                  'MSGP Part 8.S'),
    ('T',  '4952',    'Treatment Works',                  'POTWs with design flow >= 1 MGD.',                             'MSGP Part 8.T'),
    ('U',  '20',      'Food and Kindred Products',        'Meat packing, dairy, canning, bakeries, beverages.',           'MSGP Part 8.U'),
    ('V',  '22,23',   'Textile Mills and Apparel',        'Broadwoven fabric, dyeing, apparel and related.',              'MSGP Part 8.V'),
    ('W',  '25',      'Furniture and Fixtures',           'Wood and metal household/office furniture.',                   'MSGP Part 8.W'),
    ('X',  '27',      'Printing and Publishing',          'Commercial printing, periodicals, books.',                     'MSGP Part 8.X'),
    ('Y',  '30',      'Rubber, Misc Plastics',            'Tires, rubber footwear, plastics products.',                   'MSGP Part 8.Y'),
    ('Z',  '31',      'Leather and Leather Products',     'Leather tanning, footwear, luggage.',                          'MSGP Part 8.Z'),
    ('AA', '34',      'Fabricated Metal Products',        'Cutlery, hand tools, hardware, heating/plumbing.',             'MSGP Part 8.AA'),
    ('AB', '35',      'Machinery',                        'Engines, farm machinery, metalworking machinery.',             'MSGP Part 8.AB'),
    ('AC', '36',      'Electronics and Electrical',       'Electronic components, communications equipment.',             'MSGP Part 8.AC'),
    ('AD', '1711',    'Construction Stormwater',          'Covers by CGP not MSGP; captured here for completeness.',      'CGP (separate)');


-- ============================================================================
-- PHYSICAL WATER INFRASTRUCTURE
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DISCHARGE POINTS (outfalls)
-- ----------------------------------------------------------------------------
-- Physical location where regulated wastewater, stormwater, or other
-- discharges leave the facility. Maps to ehs:DischargePoint. Each NPDES
-- permit may cover multiple discharge points; each discharge point is
-- subject to its own effluent limits, monitoring frequency, and reporting.
--
-- StormwaterOutfall (ontology subclass of DischargePoint) is represented
-- by discharge_type containing 'stormwater' — no separate table needed.

CREATE TABLE IF NOT EXISTS discharge_points (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    outfall_code TEXT NOT NULL,                 -- 'OUTFALL-001', 'SW-OUT-002'
    outfall_name TEXT,
    description TEXT,

    -- Discharge type: what flows through this outfall
    discharge_type TEXT NOT NULL,               -- 'process_wastewater', 'stormwater', 'combined', 'non_contact_cooling', 'sanitary', 'boiler_blowdown'

    -- Receiving waterbody
    receiving_waterbody TEXT,                   -- Name of stream/lake/POTW
    receiving_waterbody_type TEXT,              -- 'surface_water', 'potw', 'groundwater'
    receiving_waterbody_classification TEXT,    -- State water-quality classification
    is_impaired_water INTEGER DEFAULT 0,        -- On the CWA §303(d) impaired waters list?
    tmdl_applies INTEGER DEFAULT 0,             -- Is there a TMDL that applies?
    tmdl_parameters TEXT,                       -- JSON array of TMDL parameter codes if tmdl_applies

    -- Geography
    latitude REAL,
    longitude REAL,

    -- Regulatory coverage
    permit_id INTEGER,                          -- The permit that governs this outfall (NPDES, MSGP, POTW discharge)
    stormwater_sector_code TEXT,                -- MSGP sector (FK to sw_industrial_sectors.code); NULL for non-stormwater
    swppp_id INTEGER,                           -- Governing SWPPP (for stormwater outfalls); ehs:coveredBy

    -- Cross-module wiring: which process unit feeds this outfall (ehs:dischargesTo)
    emission_unit_id INTEGER,                   -- Primary upstream unit; secondary units via ww_monitoring_locations chain

    -- Physical characteristics
    pipe_diameter_inches REAL,
    typical_flow_mgd REAL,                      -- Typical daily flow in million gallons per day

    -- Status lifecycle
    status TEXT DEFAULT 'active',               -- 'active', 'decommissioned', 'pending', 'reactivated'
    installation_date TEXT,
    decommission_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    FOREIGN KEY (stormwater_sector_code) REFERENCES sw_industrial_sectors(code),
    FOREIGN KEY (swppp_id) REFERENCES sw_swpps(id) DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    UNIQUE(establishment_id, outfall_code)
);

CREATE INDEX IF NOT EXISTS idx_discharge_points_establishment ON discharge_points(establishment_id);
CREATE INDEX IF NOT EXISTS idx_discharge_points_permit ON discharge_points(permit_id);
CREATE INDEX IF NOT EXISTS idx_discharge_points_status ON discharge_points(status);
CREATE INDEX IF NOT EXISTS idx_discharge_points_type ON discharge_points(discharge_type);


-- ----------------------------------------------------------------------------
-- WASTEWATER MONITORING LOCATIONS
-- ----------------------------------------------------------------------------
-- Sample points within the facility. A monitoring location may (a) be at a
-- discharge point (the outfall itself is sampled), (b) be upstream of the
-- discharge point (post-treatment pre-mixing), or (c) be an internal process
-- monitoring point with no discharge connection. Maps to ehs:MonitoringLocation.

CREATE TABLE IF NOT EXISTS ww_monitoring_locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Cross-module FK: wastewater can originate from emission unit processes
    -- (e.g., scrubber blowdown, cooling tower discharge from air emission sources)
    emission_unit_id INTEGER,                   -- FK → air_emission_units (Module B)

    -- Link to the discharge point this location monitors (ehs:monitoredAt).
    -- NULL for internal-process-only sample points.
    discharge_point_id INTEGER,

    location_code TEXT NOT NULL,                -- 'COMP-TANK', 'CLARIFIER', 'OUTFALL-001'
    location_name TEXT,
    location_type TEXT,                         -- 'outfall', 'internal_sample_point', 'equipment', 'pre_discharge'
    description TEXT,

    -- Geographic info (optional)
    latitude REAL,
    longitude REAL,

    -- Permit reference (if this location is in a permit)
    permit_id INTEGER,                          -- NULL for voluntary monitoring points

    -- Status
    is_active INTEGER DEFAULT 1,
    installation_date TEXT,                     -- When this location was established
    decommission_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    FOREIGN KEY (discharge_point_id) REFERENCES discharge_points(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    UNIQUE(establishment_id, location_code)
);

CREATE INDEX IF NOT EXISTS idx_ww_locations_establishment ON ww_monitoring_locations(establishment_id);
CREATE INDEX IF NOT EXISTS idx_ww_locations_permit ON ww_monitoring_locations(permit_id);
CREATE INDEX IF NOT EXISTS idx_ww_locations_emission_unit ON ww_monitoring_locations(emission_unit_id);
CREATE INDEX IF NOT EXISTS idx_ww_locations_discharge_point ON ww_monitoring_locations(discharge_point_id);


-- ============================================================================
-- REFERENCE: WASTEWATER PARAMETERS
-- ============================================================================
-- Pollutants and parameters that can be tested (metals, conventional
-- pollutants, physical properties, etc.). In v3.2 each row is tagged with
-- a pollutant_type_code linking to water_pollutant_types, aligning the
-- table with the ehs:WaterPollutant ontology taxonomy. parameter_category
-- is retained for UI grouping ('metal' vs 'nutrient' vs 'physical') —
-- pollutant_type_code is the regulatory classification.

CREATE TABLE IF NOT EXISTS ww_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    parameter_code TEXT NOT NULL UNIQUE,        -- 'CR-T', 'NI-T', 'BOD5', 'TSS', 'PH'
    parameter_name TEXT NOT NULL,               -- 'Chromium (Total)', 'Nickel (Total)'
    parameter_category TEXT,                    -- 'metal', 'conventional', 'physical', 'nutrient', 'organic', 'other'

    -- v3.2 ontology taxonomy tag (NULL for non-pollutant parameters like flow, temperature)
    pollutant_type_code TEXT,                   -- FK → water_pollutant_types.code

    cas_number TEXT,                            -- Chemical Abstracts Service number

    -- Typical measurement info
    typical_units TEXT,                         -- 'mg/L', 'ug/L', 'pH units', 'SU'
    typical_method TEXT,                        -- EPA method number (e.g., '200.7', '405.1')

    -- Lab requirements
    requires_certified_lab INTEGER DEFAULT 0,   -- 0=can be field measured, 1=needs certified lab

    -- Legacy regulatory flags (kept for query compatibility; redundant with pollutant_type_code)
    priority_pollutant INTEGER DEFAULT 0,       -- Duplicates pollutant_type_code = 'PRIORITY'
    toxic_pollutant INTEGER DEFAULT 0,          -- Broader toxic classification (includes some non-priority)

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (pollutant_type_code) REFERENCES water_pollutant_types(code)
);

CREATE INDEX IF NOT EXISTS idx_ww_parameters_category ON ww_parameters(parameter_category);
CREATE INDEX IF NOT EXISTS idx_ww_parameters_type ON ww_parameters(pollutant_type_code);


-- ============================================================================
-- WASTEWATER PARAMETERS SEED DATA
-- ============================================================================
-- Baseline parameters for industrial wastewater monitoring with v3.2
-- pollutant_type_code discriminator applied. Note: the 126 priority
-- pollutants listed at 40 CFR 423 Appendix A are NOT all seeded here —
-- only those a small-shop Odin user is realistically going to test are.
-- Additional priority pollutants are added via the schema builder or by
-- user INSERT when needed.

INSERT OR IGNORE INTO ww_parameters
    (id, parameter_code, parameter_name, parameter_category, pollutant_type_code,
     cas_number, typical_units, typical_method,
     requires_certified_lab, priority_pollutant, toxic_pollutant) VALUES
    -- Metals (Total) — all priority pollutants per 40 CFR 423 App A
    (1, 'CD-T',  'Cadmium (Total)',              'metal',        'PRIORITY',       '7440-43-9',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (2, 'CR-T',  'Chromium (Total)',             'metal',        'PRIORITY',       '7440-47-3',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (3, 'CR-HEX','Chromium (Hexavalent)',        'metal',        'PRIORITY',       '18540-29-9', 'mg/L',    'EPA 218.6',  1, 1, 1),
    (4, 'CU-T',  'Copper (Total)',               'metal',        'PRIORITY',       '7440-50-8',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (5, 'CN-T',  'Cyanide (Total)',              'metal',        'PRIORITY',       '57-12-5',    'mg/L',    'EPA 335.4',  1, 1, 1),
    (6, 'PB-T',  'Lead (Total)',                 'metal',        'PRIORITY',       '7439-92-1',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (7, 'NI-T',  'Nickel (Total)',               'metal',        'PRIORITY',       '7440-02-0',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (8, 'AG-T',  'Silver (Total)',               'metal',        'PRIORITY',       '7440-22-4',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (9, 'ZN-T',  'Zinc (Total)',                 'metal',        'PRIORITY',       '7440-66-6',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (50,'AS-T',  'Arsenic (Total)',              'metal',        'PRIORITY',       '7440-38-2',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (51,'HG-T',  'Mercury (Total)',              'metal',        'PRIORITY',       '7439-97-6',  'mg/L',    'EPA 245.1',  1, 1, 1),
    (52,'SE-T',  'Selenium (Total)',             'metal',        'PRIORITY',       '7782-49-2',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (53,'BE-T',  'Beryllium (Total)',            'metal',        'PRIORITY',       '7440-41-7',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (54,'SB-T',  'Antimony (Total)',             'metal',        'PRIORITY',       '7440-36-0',  'mg/L',    'EPA 200.7',  1, 1, 1),
    (55,'TL-T',  'Thallium (Total)',             'metal',        'PRIORITY',       '7440-28-0',  'mg/L',    'EPA 200.7',  1, 1, 1),

    -- Volatile Organics (priority — sample of common ones)
    (60,'BENZENE',     'Benzene',                'organic',      'PRIORITY',       '71-43-2',    'ug/L',    'EPA 624',    1, 1, 1),
    (61,'TOLUENE',     'Toluene',                'organic',      'PRIORITY',       '108-88-3',   'ug/L',    'EPA 624',    1, 1, 1),
    (62,'TCE',         'Trichloroethylene',      'organic',      'PRIORITY',       '79-01-6',    'ug/L',    'EPA 624',    1, 1, 1),
    (63,'PCE',         'Tetrachloroethylene',    'organic',      'PRIORITY',       '127-18-4',   'ug/L',    'EPA 624',    1, 1, 1),
    (64,'CHCL3',       'Chloroform',             'organic',      'PRIORITY',       '67-66-3',    'ug/L',    'EPA 624',    1, 1, 1),

    -- Nutrients — non-conventional
    (10,'NH3-N',       'Ammonia Nitrogen (as N)','nutrient',     'NONCONVENTIONAL','7664-41-7',  'mg/L',    'EPA 350.1',  1, 0, 0),
    (11,'P-T',         'Phosphorus (Total)',     'nutrient',     'NONCONVENTIONAL','7723-14-0',  'mg/L',    'EPA 365.1',  1, 0, 0),
    (12,'N-T',         'Nitrogen (Total)',       'nutrient',     'NONCONVENTIONAL',NULL,         'mg/L',    'EPA 351.2',  1, 0, 0),
    (70,'NO3-N',       'Nitrate Nitrogen',       'nutrient',     'NONCONVENTIONAL','14797-55-8', 'mg/L',    'EPA 353.2',  1, 0, 0),
    (71,'NO2-N',       'Nitrite Nitrogen',       'nutrient',     'NONCONVENTIONAL','14797-65-0', 'mg/L',    'EPA 353.2',  1, 0, 0),

    -- Conventional Pollutants — 40 CFR 401.16
    (20,'BOD5',        'Biochemical Oxygen Demand (5-day)', 'conventional', 'CONVENTIONAL', NULL, 'mg/L',   'EPA 405.1',  1, 0, 0),
    (21,'TSS',         'Total Suspended Solids', 'conventional', 'CONVENTIONAL',   NULL,         'mg/L',    'EPA 160.2',  1, 0, 0),
    (22,'OG',          'Oil and Grease',         'conventional', 'CONVENTIONAL',   NULL,         'mg/L',    'EPA 1664A',  1, 0, 0),
    (23,'FECAL_COL',   'Fecal Coliform',         'conventional', 'CONVENTIONAL',   NULL,         'CFU/100mL','SM 9222D',  1, 0, 0),
    (30,'PH',          'pH',                     'conventional', 'CONVENTIONAL',   NULL,         'SU',      'EPA 150.1',  0, 0, 0),

    -- Non-conventional: other common parameters
    (80,'TDS',         'Total Dissolved Solids', 'physical',     'NONCONVENTIONAL',NULL,         'mg/L',    'EPA 160.1',  1, 0, 0),
    (81,'CL',          'Chloride',               'physical',     'NONCONVENTIONAL','16887-00-6', 'mg/L',    'EPA 325.3',  1, 0, 0),
    (82,'SO4',         'Sulfate',                'physical',     'NONCONVENTIONAL','14808-79-8', 'mg/L',    'EPA 375.4',  1, 0, 0),
    (83,'F',           'Fluoride',               'physical',     'NONCONVENTIONAL','16984-48-8', 'mg/L',    'EPA 340.2',  1, 0, 0),
    (84,'COD',         'Chemical Oxygen Demand', 'conventional', 'NONCONVENTIONAL',NULL,         'mg/L',    'EPA 410.4',  1, 0, 0),

    -- Whole Effluent Toxicity
    (90,'WET-ACUTE',   'Acute Whole Effluent Toxicity (LC50)','organic','WET',NULL, 'TUa',      'EPA 821-R-02-012', 1, 0, 1),
    (91,'WET-CHRONIC', 'Chronic Whole Effluent Toxicity (NOEC)','organic','WET',NULL,'TUc',     'EPA 821-R-02-013', 1, 0, 1),

    -- Physical measurements (NOT pollutants — pollutant_type_code = NULL)
    (31,'TEMP',        'Temperature',            'physical',     NULL,             NULL,         'deg_C',   'EPA 170.1',  0, 0, 0),
    (32,'FLOW',        'Flow Rate',              'physical',     NULL,             NULL,         'MGD',     'Measured',   0, 0, 0),
    (33,'CONDUCT',     'Specific Conductance',   'physical',     NULL,             NULL,         'uS/cm',   'EPA 120.1',  0, 0, 0),
    (34,'DO',          'Dissolved Oxygen',       'physical',     NULL,             NULL,         'mg/L',    'EPA 360.1',  0, 0, 0);


-- ============================================================================
-- WASTEWATER MONITORING REQUIREMENTS
-- ============================================================================
-- Configuration table: defines what must be tested, where, how often, and
-- what the limits are. Each facility configures this based on their permit
-- or voluntary monitoring program.

CREATE TABLE IF NOT EXISTS ww_monitoring_requirements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,
    parameter_id INTEGER NOT NULL,

    -- Monitoring schedule
    frequency_type TEXT,                        -- 'daily', 'weekly', 'monthly', 'quarterly', 'annual'
    frequency_count INTEGER DEFAULT 1,          -- e.g., 2 for "2x weekly"

    -- Sample type
    sample_type TEXT,                           -- 'grab', 'composite', 'flow_proportional'

    -- Limits (all nullable — not all parameters have limits)
    limit_daily_max REAL,
    limit_monthly_avg REAL,
    limit_annual_avg REAL,
    limit_units TEXT,                           -- Should match parameter typical_units

    -- Benchmark (for MSGP stormwater — trigger-for-corrective-action, NOT a limit)
    msgp_benchmark REAL,
    msgp_benchmark_units TEXT,

    -- Regulatory basis
    is_permit_required INTEGER DEFAULT 0,       -- 0=voluntary, 1=permit requirement
    permit_id INTEGER,                          -- Which permit requires this
    permit_condition_id INTEGER,                -- Specific permit condition

    -- Dates
    effective_date TEXT,                        -- When this requirement starts
    end_date TEXT,                              -- NULL if ongoing

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (location_id) REFERENCES ww_monitoring_locations(id),
    FOREIGN KEY (parameter_id) REFERENCES ww_parameters(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    FOREIGN KEY (permit_condition_id) REFERENCES permit_conditions(id)
);

CREATE INDEX IF NOT EXISTS idx_ww_requirements_establishment ON ww_monitoring_requirements(establishment_id);
CREATE INDEX IF NOT EXISTS idx_ww_requirements_location ON ww_monitoring_requirements(location_id);
CREATE INDEX IF NOT EXISTS idx_ww_requirements_parameter ON ww_monitoring_requirements(parameter_id);
CREATE INDEX IF NOT EXISTS idx_ww_requirements_permit ON ww_monitoring_requirements(permit_id);


-- ============================================================================
-- WASTEWATER SAMPLING EQUIPMENT
-- ============================================================================
-- Field instruments and lab equipment that need calibration tracking.

CREATE TABLE IF NOT EXISTS ww_equipment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    equipment_code TEXT NOT NULL,               -- 'PH-METER-01', 'COMPOSITE-SAMPLER-01'
    equipment_name TEXT,
    equipment_type TEXT,                        -- 'ph_meter', 'composite_sampler', 'flow_meter'

    manufacturer TEXT,
    model_number TEXT,
    serial_number TEXT,

    -- Calibration schedule
    calibration_frequency_days INTEGER,         -- How often to calibrate
    last_calibration_date TEXT,
    next_calibration_due TEXT,

    -- Status
    is_active INTEGER DEFAULT 1,
    purchase_date TEXT,
    retire_date TEXT,

    location TEXT,                              -- Where is this equipment normally stored/used

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, equipment_code)
);

CREATE INDEX IF NOT EXISTS idx_ww_equipment_establishment ON ww_equipment(establishment_id);
CREATE INDEX IF NOT EXISTS idx_ww_equipment_calibration_due ON ww_equipment(next_calibration_due);


-- ============================================================================
-- WASTEWATER EQUIPMENT CALIBRATIONS
-- ============================================================================
-- Record of each calibration performed.

CREATE TABLE IF NOT EXISTS ww_equipment_calibrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    equipment_id INTEGER NOT NULL,

    calibration_date TEXT NOT NULL,             -- Format: YYYY-MM-DD
    calibration_time TEXT,                      -- Format: HH:MM

    calibrated_by_employee_id INTEGER,

    -- Calibration details
    calibration_standard_used TEXT,             -- e.g., "pH 7.0 buffer", "4.0 mg/L Ni standard"
    standard_lot_number TEXT,
    standard_expiration_date TEXT,

    -- Results
    passed INTEGER DEFAULT 1,                   -- 0=failed, 1=passed
    pre_calibration_reading REAL,               -- What it read before calibration
    post_calibration_reading REAL,              -- What it reads after calibration
    expected_reading REAL,                      -- What standard should read

    -- Next calibration
    next_calibration_due TEXT,                  -- Format: YYYY-MM-DD

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (equipment_id) REFERENCES ww_equipment(id),
    FOREIGN KEY (calibrated_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_ww_calibrations_equipment ON ww_equipment_calibrations(equipment_id);
CREATE INDEX IF NOT EXISTS idx_ww_calibrations_date ON ww_equipment_calibrations(calibration_date);


-- ============================================================================
-- WASTEWATER LAB CERTIFICATIONS
-- ============================================================================
-- External labs and their certifications. Tracks which labs can perform
-- which analyses and ensures they are properly certified.

CREATE TABLE IF NOT EXISTS ww_labs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    lab_name TEXT NOT NULL,
    lab_code TEXT UNIQUE,                       -- Short code for easy reference

    -- Contact info
    street_address TEXT,
    city TEXT,
    state TEXT,
    zip TEXT,
    phone TEXT,
    website TEXT,
    primary_contact_name TEXT,
    primary_contact_email TEXT,

    -- Certifications
    state_certification_number TEXT,
    nelac_certification TEXT,                   -- National Environmental Laboratory Accreditation
    certification_expiration_date TEXT,

    -- Lab capabilities
    certified_parameters TEXT,                  -- JSON array of parameter_codes they're certified for

    -- Status
    is_active INTEGER DEFAULT 1,
    is_preferred INTEGER DEFAULT 0,             -- Preferred vendor?

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_ww_labs_active ON ww_labs(is_active);


-- ============================================================================
-- WASTEWATER LAB SUBMISSIONS
-- ============================================================================
-- Tracking samples sent to external labs. Multiple sampling events can be
-- included in one lab submission.

CREATE TABLE IF NOT EXISTS ww_lab_submissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    lab_id INTEGER NOT NULL,

    -- Identification
    submission_number TEXT,                     -- Internal tracking number
    chain_of_custody_number TEXT,               -- COC form number

    -- Dates
    submitted_date TEXT NOT NULL,               -- When samples were sent/dropped off
    received_by_lab_date TEXT,                  -- When lab received them
    report_due_date TEXT,                       -- Expected turnaround
    report_received_date TEXT,                  -- When we got results back

    -- Lab info
    lab_project_number TEXT,                    -- Lab's internal job number
    lab_contact_name TEXT,

    -- Documents
    coc_document_path TEXT,                     -- Scanned COC form
    lab_report_path TEXT,                       -- Lab report PDF

    -- Status
    status TEXT DEFAULT 'submitted',            -- 'submitted', 'received_by_lab', 'results_received', 'cancelled'

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (lab_id) REFERENCES ww_labs(id)
);

CREATE INDEX IF NOT EXISTS idx_ww_lab_submissions_establishment ON ww_lab_submissions(establishment_id);
CREATE INDEX IF NOT EXISTS idx_ww_lab_submissions_lab ON ww_lab_submissions(lab_id);
CREATE INDEX IF NOT EXISTS idx_ww_lab_submissions_status ON ww_lab_submissions(status);


-- ============================================================================
-- WASTEWATER SAMPLING EVENTS (Anchor Table)
-- ============================================================================
-- Each sampling event represents one trip to collect samples. Multiple
-- parameters are tested from each event.

CREATE TABLE IF NOT EXISTS ww_sampling_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,

    -- Event identification
    event_number TEXT,                          -- Optional internal tracking number

    -- When and who
    sample_date TEXT NOT NULL,                  -- Format: YYYY-MM-DD
    sample_time TEXT,                           -- Format: HH:MM (24-hour)
    sampled_by_employee_id INTEGER,

    -- Sample details
    sample_type TEXT,                           -- 'grab', 'composite'
    composite_period_hours REAL,                -- If composite, how many hours

    -- Weather (relevant for some permits)
    weather_conditions TEXT,                    -- 'dry', 'rain', 'snow'

    -- Equipment used
    equipment_id INTEGER,                       -- Sampler or meter used (if field measurement)

    -- Lab submission (if samples sent to external lab)
    lab_submission_id INTEGER,

    -- Finalization (DMR readiness)
    status TEXT DEFAULT 'in_progress',          -- 'in_progress', 'finalized'
    finalized_date TEXT,
    finalized_by_employee_id INTEGER,

    -- Photo/documentation
    photo_paths TEXT,                           -- JSON array of photo file paths

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (location_id) REFERENCES ww_monitoring_locations(id),
    FOREIGN KEY (sampled_by_employee_id) REFERENCES employees(id),
    FOREIGN KEY (finalized_by_employee_id) REFERENCES employees(id),
    FOREIGN KEY (equipment_id) REFERENCES ww_equipment(id),
    FOREIGN KEY (lab_submission_id) REFERENCES ww_lab_submissions(id)
);

CREATE INDEX IF NOT EXISTS idx_ww_events_establishment ON ww_sampling_events(establishment_id);
CREATE INDEX IF NOT EXISTS idx_ww_events_location ON ww_sampling_events(location_id);
CREATE INDEX IF NOT EXISTS idx_ww_events_date ON ww_sampling_events(sample_date);
CREATE INDEX IF NOT EXISTS idx_ww_events_lab_submission ON ww_sampling_events(lab_submission_id);
CREATE INDEX IF NOT EXISTS idx_ww_events_status ON ww_sampling_events(status);


-- ============================================================================
-- WASTEWATER SAMPLE RESULTS
-- ============================================================================
-- Individual test results. Each result is one parameter from one sampling
-- event. This is where actual data lives.

CREATE TABLE IF NOT EXISTS ww_sample_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id INTEGER NOT NULL,
    parameter_id INTEGER NOT NULL,

    -- Result
    result_value REAL,                          -- Numeric value (NULL if non-detect)
    result_units TEXT NOT NULL,                 -- Should match parameter's typical_units

    -- Lab qualifiers (if from certified lab)
    result_qualifier TEXT,                      -- 'ND', 'J', 'U', '<', '>', etc.
    detection_limit REAL,                       -- Method detection limit
    reporting_limit REAL,                       -- Practical quantitation limit

    -- Analysis details
    analyzed_date TEXT,                         -- When was this sample analyzed (may differ from sample_date)
    analyzed_by TEXT,                           -- 'field' or lab name
    analysis_method TEXT,                       -- EPA method number

    -- QA/QC
    is_duplicate INTEGER DEFAULT 0,             -- Is this a duplicate sample?
    duplicate_of_result_id INTEGER,             -- If duplicate, which result is it duplicating?
    is_blank INTEGER DEFAULT 0,                 -- Is this a blank sample?

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (event_id) REFERENCES ww_sampling_events(id) ON DELETE CASCADE,
    FOREIGN KEY (parameter_id) REFERENCES ww_parameters(id),
    FOREIGN KEY (duplicate_of_result_id) REFERENCES ww_sample_results(id)
);

CREATE INDEX IF NOT EXISTS idx_ww_results_event ON ww_sample_results(event_id);
CREATE INDEX IF NOT EXISTS idx_ww_results_parameter ON ww_sample_results(parameter_id);
CREATE INDEX IF NOT EXISTS idx_ww_results_date ON ww_sample_results(analyzed_date);


-- ============================================================================
-- WASTEWATER FLOW MEASUREMENTS
-- ============================================================================
-- Optional table for facilities that track discharge flow/volume. Some
-- permits require flow monitoring, others don't.

CREATE TABLE IF NOT EXISTS ww_flow_measurements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,

    measurement_date TEXT NOT NULL,             -- Format: YYYY-MM-DD
    measurement_time TEXT,                      -- Format: HH:MM

    -- Flow data
    flow_rate REAL,
    flow_units TEXT,                            -- 'MGD', 'GPM', 'GPD', 'liters/min'

    -- Measurement method
    measurement_method TEXT,                    -- 'meter', 'calculated', 'estimated', 'totalizer'
    meter_reading REAL,                         -- If using totalizer/meter

    -- Equipment
    equipment_id INTEGER,                       -- Flow meter used

    -- Daily total (if calculating)
    daily_total_volume REAL,
    daily_total_units TEXT,                     -- 'gallons', 'cubic_meters'

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (location_id) REFERENCES ww_monitoring_locations(id),
    FOREIGN KEY (equipment_id) REFERENCES ww_equipment(id)
);

CREATE INDEX IF NOT EXISTS idx_ww_flow_establishment ON ww_flow_measurements(establishment_id);
CREATE INDEX IF NOT EXISTS idx_ww_flow_location ON ww_flow_measurements(location_id);
CREATE INDEX IF NOT EXISTS idx_ww_flow_date ON ww_flow_measurements(measurement_date);


-- ============================================================================
-- STORMWATER POLLUTION PREVENTION PLANS (SWPPP documents)
-- ============================================================================
-- Maps to ehs:SWPPP. A living document per establishment — revisions must
-- be tracked, as Tier 1 corrective action (MSGP Part 6) frequently triggers
-- a SWPPP update + BMP modification.

CREATE TABLE IF NOT EXISTS sw_swpps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Version/revision tracking
    revision_number TEXT NOT NULL,              -- 'v1.0', 'v2.1', etc.
    effective_date TEXT NOT NULL,
    supersedes_swppp_id INTEGER,                -- Previous SWPPP this revises; NULL for first version

    -- Review cadence
    last_annual_review_date TEXT,
    next_annual_review_due TEXT,

    -- Responsible personnel
    pollution_prevention_team_lead_employee_id INTEGER,
    pollution_prevention_team TEXT,             -- JSON array of employee_id values

    -- Document reference
    document_path TEXT,                         -- Path to the full SWPPP PDF/Word

    -- Permit linkage
    permit_id INTEGER,                          -- Typically the MSGP or an individual stormwater permit

    -- Status
    status TEXT DEFAULT 'active',               -- 'active', 'superseded', 'retired'

    -- Site characterization narrative (stored in document_path; these are index fields)
    site_description_summary TEXT,
    industrial_activities_summary TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (supersedes_swppp_id) REFERENCES sw_swpps(id),
    FOREIGN KEY (pollution_prevention_team_lead_employee_id) REFERENCES employees(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id)
);

CREATE INDEX IF NOT EXISTS idx_sw_swpps_establishment ON sw_swpps(establishment_id);
CREATE INDEX IF NOT EXISTS idx_sw_swpps_status ON sw_swpps(status);
CREATE INDEX IF NOT EXISTS idx_sw_swpps_next_review ON sw_swpps(next_annual_review_due);


-- ============================================================================
-- BEST MANAGEMENT PRACTICES (BMPs)
-- ============================================================================
-- Maps to ehs:BestManagementPractice. BMPs are what a SWPPP "implements"
-- per ehs:implements. Each BMP has inspection cadence + responsible role.

CREATE TABLE IF NOT EXISTS sw_bmps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    swppp_id INTEGER NOT NULL,
    establishment_id INTEGER NOT NULL,          -- Denormalized for simpler queries

    bmp_code TEXT NOT NULL,                     -- 'BMP-001', 'BMP-COVER-001'
    bmp_name TEXT NOT NULL,                     -- 'Cover outside storage area'

    -- Classification
    bmp_type TEXT NOT NULL,                     -- 'structural', 'non_structural'
    bmp_subtype TEXT,                           -- 'secondary_containment', 'good_housekeeping', 'employee_training', 'inspection_schedule', etc.

    -- Description
    description TEXT NOT NULL,
    implementation_date TEXT,
    implementation_details TEXT,                -- Longer narrative / specs / vendor info

    -- Inspection cadence
    inspection_frequency TEXT,                  -- 'weekly', 'monthly', 'quarterly', 'annual', 'storm_event', 'continuous'
    inspection_frequency_days INTEGER,          -- Numeric form for scheduling
    responsible_role TEXT,                      -- 'EHS Manager', 'Facility Operator', etc.
    responsible_employee_id INTEGER,

    -- Lifecycle
    last_inspection_date TEXT,
    next_inspection_due TEXT,
    last_effectiveness_review_date TEXT,
    status TEXT DEFAULT 'active',               -- 'active', 'retired', 'pending_implementation'
    retirement_date TEXT,
    retirement_reason TEXT,                     -- 'replaced', 'ineffective', 'no_longer_applicable'
    replaced_by_bmp_id INTEGER,                 -- Self-FK if replaced

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (swppp_id) REFERENCES sw_swpps(id),
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (responsible_employee_id) REFERENCES employees(id),
    FOREIGN KEY (replaced_by_bmp_id) REFERENCES sw_bmps(id),
    UNIQUE(swppp_id, bmp_code)
);

CREATE INDEX IF NOT EXISTS idx_sw_bmps_swppp ON sw_bmps(swppp_id);
CREATE INDEX IF NOT EXISTS idx_sw_bmps_establishment ON sw_bmps(establishment_id);
CREATE INDEX IF NOT EXISTS idx_sw_bmps_status ON sw_bmps(status);
CREATE INDEX IF NOT EXISTS idx_sw_bmps_next_inspection ON sw_bmps(next_inspection_due);


-- ============================================================================
-- STORMWATER OUTFALL BENCHMARKS (MSGP Part 2 sector-specific values)
-- ============================================================================
-- MSGP benchmark monitoring values. Benchmarks are NOT numeric effluent
-- limits — exceedance triggers MSGP Part 6 corrective action (SWPPP review,
-- BMP modification), not a CWA §309 violation. Each row ties a sector +
-- parameter to a benchmark value. Outfalls pick up applicable benchmarks
-- via their discharge_points.stormwater_sector_code.

CREATE TABLE IF NOT EXISTS sw_outfall_benchmarks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    sector_code TEXT NOT NULL,                  -- FK → sw_industrial_sectors.code
    parameter_id INTEGER NOT NULL,              -- FK → ww_parameters.id

    benchmark_value REAL NOT NULL,
    benchmark_units TEXT NOT NULL,

    -- Statistical basis (MSGP typically uses rolling-4-quarter average)
    statistical_basis TEXT,                     -- 'quarterly_average', 'rolling_4_quarter_average'

    -- Regulatory basis
    msgp_version TEXT,                          -- '2021', '2026', etc.
    msgp_part TEXT,                             -- 'Part 2.2.1.1', 'Part 8.AA', etc.
    citation TEXT,

    effective_date TEXT,
    end_date TEXT,                              -- NULL if still in effect

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (sector_code) REFERENCES sw_industrial_sectors(code),
    FOREIGN KEY (parameter_id) REFERENCES ww_parameters(id),
    UNIQUE(sector_code, parameter_id, msgp_version)
);

CREATE INDEX IF NOT EXISTS idx_sw_benchmarks_sector ON sw_outfall_benchmarks(sector_code);
CREATE INDEX IF NOT EXISTS idx_sw_benchmarks_parameter ON sw_outfall_benchmarks(parameter_id);


-- ============================================================================
-- VIEWS (relocated from module_industrial_waste_streams.sql PART 4)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- v_ww_results_with_limits
-- ----------------------------------------------------------------------------
-- Show all results alongside their applicable limits for easy compliance checking.

CREATE VIEW IF NOT EXISTS v_ww_results_with_limits AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    se.id AS event_id,
    se.event_number,
    se.sample_date,
    se.sample_time,

    ml.location_code,
    ml.location_name,

    p.parameter_code,
    p.parameter_name,
    p.pollutant_type_code,

    sr.result_value,
    sr.result_units,
    sr.result_qualifier,
    sr.detection_limit,
    sr.reporting_limit,

    mr.limit_daily_max,
    mr.limit_monthly_avg,
    mr.limit_units,

    -- Compliance check
    CASE
        WHEN mr.limit_daily_max IS NOT NULL AND sr.result_value > mr.limit_daily_max
            THEN 1
        ELSE 0
    END AS exceeds_daily_max,

    -- Percent of limit
    CASE
        WHEN mr.limit_daily_max IS NOT NULL AND mr.limit_daily_max > 0
            THEN ROUND((sr.result_value / mr.limit_daily_max) * 100, 1)
        ELSE NULL
    END AS percent_of_limit,

    sr.analyzed_by,
    sr.notes

FROM ww_sample_results sr
INNER JOIN ww_sampling_events se ON sr.event_id = se.id
INNER JOIN establishments e ON se.establishment_id = e.id
INNER JOIN ww_monitoring_locations ml ON se.location_id = ml.id
INNER JOIN ww_parameters p ON sr.parameter_id = p.id
LEFT JOIN ww_monitoring_requirements mr ON
    se.establishment_id = mr.establishment_id AND
    se.location_id = mr.location_id AND
    sr.parameter_id = mr.parameter_id AND
    (mr.end_date IS NULL OR se.sample_date <= mr.end_date) AND
    se.sample_date >= mr.effective_date;


-- ----------------------------------------------------------------------------
-- v_ww_exceedances
-- ----------------------------------------------------------------------------
-- Only show results that exceeded limits.

CREATE VIEW IF NOT EXISTS v_ww_exceedances AS
SELECT * FROM v_ww_results_with_limits
WHERE exceeds_daily_max = 1
ORDER BY sample_date DESC;


-- ----------------------------------------------------------------------------
-- v_ww_calibrations_due
-- ----------------------------------------------------------------------------
-- Equipment needing calibration soon.

CREATE VIEW IF NOT EXISTS v_ww_calibrations_due AS
SELECT
    e.id AS establishment_id,
    eq.id AS equipment_id,
    eq.equipment_code,
    eq.equipment_name,
    eq.equipment_type,
    eq.last_calibration_date,
    eq.next_calibration_due,

    julianday(eq.next_calibration_due) - julianday('now') AS days_until_due,

    CASE
        WHEN eq.next_calibration_due < date('now') THEN 'OVERDUE'
        WHEN eq.next_calibration_due <= date('now', '+7 days') THEN 'DUE_THIS_WEEK'
        WHEN eq.next_calibration_due <= date('now', '+30 days') THEN 'DUE_THIS_MONTH'
        ELSE 'UPCOMING'
    END AS urgency

FROM ww_equipment eq
INNER JOIN establishments e ON eq.establishment_id = e.id
WHERE eq.is_active = 1
  AND eq.next_calibration_due IS NOT NULL
ORDER BY eq.next_calibration_due;


-- ----------------------------------------------------------------------------
-- v_ww_sampling_schedule
-- ----------------------------------------------------------------------------
-- What monitoring is required, when, and at which locations.

CREATE VIEW IF NOT EXISTS v_ww_sampling_schedule AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    ml.location_code,
    ml.location_name,

    p.parameter_code,
    p.parameter_name,

    mr.frequency_type,
    mr.frequency_count,
    mr.sample_type,

    mr.limit_daily_max,
    mr.limit_monthly_avg,
    mr.limit_units,

    CASE WHEN mr.is_permit_required = 1 THEN 'Required' ELSE 'Voluntary' END AS requirement_type,

    perm.permit_number,

    mr.notes

FROM ww_monitoring_requirements mr
INNER JOIN establishments e ON mr.establishment_id = e.id
INNER JOIN ww_monitoring_locations ml ON mr.location_id = ml.id
INNER JOIN ww_parameters p ON mr.parameter_id = p.id
LEFT JOIN permits perm ON mr.permit_id = perm.id
WHERE mr.end_date IS NULL OR mr.end_date >= date('now')
ORDER BY e.name, ml.location_code, p.parameter_name;


-- ----------------------------------------------------------------------------
-- v_ww_lab_submissions_summary
-- ----------------------------------------------------------------------------
-- Track status of lab submissions.

CREATE VIEW IF NOT EXISTS v_ww_lab_submissions_summary AS
SELECT
    ls.id AS submission_id,
    ls.submission_number,
    ls.chain_of_custody_number,

    e.name AS establishment_name,
    lab.lab_name,

    ls.submitted_date,
    ls.received_by_lab_date,
    ls.report_due_date,
    ls.report_received_date,

    ls.status,

    (SELECT COUNT(DISTINCT se.id)
     FROM ww_sampling_events se
     WHERE se.lab_submission_id = ls.id) AS sample_count,

    julianday('now') - julianday(ls.submitted_date) AS days_since_submission,
    julianday(ls.report_due_date) - julianday('now') AS days_until_due,

    CASE
        WHEN ls.status = 'results_received' THEN 'COMPLETE'
        WHEN ls.report_due_date < date('now') THEN 'OVERDUE'
        WHEN ls.report_due_date <= date('now', '+3 days') THEN 'DUE_SOON'
        ELSE 'ON_TRACK'
    END AS urgency

FROM ww_lab_submissions ls
INNER JOIN establishments e ON ls.establishment_id = e.id
INNER JOIN ww_labs lab ON ls.lab_id = lab.id
ORDER BY ls.submitted_date DESC;


-- ----------------------------------------------------------------------------
-- v_ww_compliance_summary
-- ----------------------------------------------------------------------------
-- High-level wastewater compliance summary by establishment.

CREATE VIEW IF NOT EXISTS v_ww_compliance_summary AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    (SELECT COUNT(*) FROM ww_sampling_events se
     WHERE se.establishment_id = e.id
       AND se.sample_date >= date('now', '-12 months')) AS samples_last_12_months,

    (SELECT COUNT(*) FROM ww_sample_results sr
     INNER JOIN ww_sampling_events se ON sr.event_id = se.id
     WHERE se.establishment_id = e.id
       AND se.sample_date >= date('now', '-12 months')) AS results_last_12_months,

    (SELECT COUNT(*) FROM v_ww_exceedances ex
     WHERE ex.establishment_id = e.id
       AND ex.sample_date >= date('now', '-12 months')) AS exceedances_last_12_months,

    (SELECT COUNT(*) FROM ww_equipment eq
     WHERE eq.establishment_id = e.id
       AND eq.is_active = 1
       AND eq.next_calibration_due <= date('now', '+30 days')) AS calibrations_due_30_days,

    (SELECT COUNT(*) FROM ww_lab_submissions ls
     WHERE ls.establishment_id = e.id
       AND ls.status IN ('submitted', 'received_by_lab')) AS pending_lab_results,

    -- New in v3.2: active SWPPPs and upcoming annual reviews
    (SELECT COUNT(*) FROM sw_swpps sw
     WHERE sw.establishment_id = e.id
       AND sw.status = 'active') AS active_swpps,
    (SELECT COUNT(*) FROM sw_swpps sw
     WHERE sw.establishment_id = e.id
       AND sw.status = 'active'
       AND sw.next_annual_review_due <= date('now', '+30 days')) AS swppps_review_due_30_days,

    -- BMPs needing inspection
    (SELECT COUNT(*) FROM sw_bmps b
     WHERE b.establishment_id = e.id
       AND b.status = 'active'
       AND b.next_inspection_due <= date('now', '+30 days')) AS bmps_inspection_due_30_days

FROM establishments e;


-- ----------------------------------------------------------------------------
-- v_discharge_points_with_permit (new in v3.2)
-- ----------------------------------------------------------------------------
-- Outfalls joined to their governing permit and establishment for the
-- Clean Water page's list view.

CREATE VIEW IF NOT EXISTS v_discharge_points_with_permit AS
SELECT
    dp.id AS discharge_point_id,
    dp.establishment_id,
    e.name AS establishment_name,

    dp.outfall_code,
    dp.outfall_name,
    dp.discharge_type,
    dp.receiving_waterbody,
    dp.receiving_waterbody_type,
    dp.is_impaired_water,
    dp.tmdl_applies,
    dp.status,

    dp.permit_id,
    perm.permit_number,
    pt.type_code AS permit_type_code,
    pt.type_name AS permit_type_name,

    dp.stormwater_sector_code,
    sec.name AS stormwater_sector_name,

    dp.swppp_id,
    sw.revision_number AS swppp_revision

FROM discharge_points dp
INNER JOIN establishments e ON dp.establishment_id = e.id
LEFT JOIN permits perm ON dp.permit_id = perm.id
LEFT JOIN permit_types pt ON perm.permit_type_id = pt.id
LEFT JOIN sw_industrial_sectors sec ON dp.stormwater_sector_code = sec.code
LEFT JOIN sw_swpps sw ON dp.swppp_id = sw.id
WHERE dp.status != 'decommissioned';


-- ============================================================================
-- TRIGGERS (relocated from module_industrial_waste_streams.sql PART 5)
-- ============================================================================

-- Auto-update next calibration due date when calibration is performed.
CREATE TRIGGER IF NOT EXISTS trg_ww_update_equipment_calibration
AFTER INSERT ON ww_equipment_calibrations
FOR EACH ROW
WHEN NEW.passed = 1
BEGIN
    UPDATE ww_equipment
    SET
        last_calibration_date = NEW.calibration_date,
        next_calibration_due = NEW.next_calibration_due,
        updated_at = datetime('now')
    WHERE id = NEW.equipment_id;
END;


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
MODULE D — CLEAN WATER ACT DISCHARGE & MONITORING

Derived from third_party/ehs-ontology/ehs-ontology-v3.2.ttl. Consolidates CWA-distinctive
SQL under one file matching the ontology's Module D scope.

ONTOLOGY-TO-SQL MAP:
  ehs:WaterPollutant + subclasses  → water_pollutant_types (4 rows) +
                                     ww_parameters (~40 rows,
                                     pollutant_type_code discriminator)
  ehs:DischargePoint               → discharge_points
  ehs:StormwaterOutfall            → discharge_points WHERE discharge_type
                                     LIKE '%stormwater%'
  ehs:MonitoringLocation           → ww_monitoring_locations
                                     (linked to outfalls via discharge_point_id)
  ehs:WastewaterTreatmentUnit      → air_emission_units (reused cross-module;
                                     the existing unit modeling covers both
                                     air emission sources and water process
                                     units whose outputs are waterborne)
  ehs:SWPPP                        → sw_swpps (with revision tracking and
                                     supersedes chain)
  ehs:BestManagementPractice       → sw_bmps
  ehs:NPDESPermit                  → permits WHERE permit_type_id IN
                                     (10 NPDES_INDIVIDUAL, 11 NPDES_GENERAL,
                                      12 NPDES_STORMWATER)
  ehs:POTWDischargePermit          → permits WHERE permit_type_id = 13
                                     (PRETREATMENT)
  ehs:dischargesTo                 → discharge_points.emission_unit_id
                                     (primary upstream unit; additional units
                                     tracked via the monitoring-location chain)
  ehs:monitoredAt                  → ww_monitoring_locations.discharge_point_id
  ehs:sampledFor                   → ww_monitoring_requirements
                                     (location_id + parameter_id)
  ehs:subjectToPermit              → discharge_points.permit_id
  ehs:coveredBy                    → discharge_points.swppp_id
  ehs:implements                   → sw_bmps.swppp_id

CROSS-MODULE FOREIGN KEYS:
    - discharge_points.emission_unit_id       → air_emission_units (Module B)
    - ww_monitoring_locations.emission_unit_id→ air_emission_units (Module B)
    - discharge_points.permit_id              → permits (Permits/Licenses)
    - ww_monitoring_locations.permit_id       → permits (Permits/Licenses)
    - ww_monitoring_requirements.permit_id    → permits (Permits/Licenses)
    - ww_monitoring_requirements.permit_condition_id → permit_conditions
    - sw_swpps.permit_id                      → permits (Permits/Licenses)

REFERENCE TABLES (ontology-derived):
    - water_pollutant_types: CWA pollutant taxonomy (4 rows — conventional,
      priority, nonconventional, WET)
    - sw_industrial_sectors: MSGP sector code mapping (~30 rows from EPA
      2021 Multi-Sector General Permit)

PRIMARY TABLES:

  Physical infrastructure (new in v3.2):
    - discharge_points: Physical outfalls (ehs:DischargePoint)

  Monitoring program (relocated from module_industrial_waste_streams.sql):
    - ww_monitoring_locations: Sample points (now with discharge_point_id FK)
    - ww_parameters: Pollutant/parameter reference (now with
      pollutant_type_code discriminator)
    - ww_monitoring_requirements: What to test, where, how often, limits
      (now also supports MSGP benchmark values)
    - ww_equipment + ww_equipment_calibrations: Field instruments
    - ww_labs + ww_lab_submissions: External certified labs
    - ww_sampling_events: Anchor table (now with finalize lifecycle)
    - ww_sample_results: Individual test results
    - ww_flow_measurements: Optional flow tracking

  Stormwater planning (new in v3.2):
    - sw_swpps: SWPPP documents with revision tracking
    - sw_bmps: BMP catalog per SWPPP with inspection cadence
    - sw_outfall_benchmarks: MSGP sector + parameter benchmark values

VIEWS (relocated + extended):
    - v_ww_results_with_limits: Results + applicable limits for compliance
      checking (now includes pollutant_type_code)
    - v_ww_exceedances: Limit exceedances only
    - v_ww_calibrations_due: Equipment needing calibration
    - v_ww_sampling_schedule: Monitoring schedule with permit linkage
    - v_ww_lab_submissions_summary: Lab submission tracking
    - v_ww_compliance_summary: High-level compliance metrics (extended to
      count active SWPPPs, upcoming SWPPP reviews, and BMP inspections due)
    - v_discharge_points_with_permit: Outfall list view for the UI (new)

TRIGGERS:
    - trg_ww_update_equipment_calibration: Auto-update equipment calibration
      dates when a calibration row is inserted with passed = 1

PRE-SEEDED DATA:
    - Water Pollutant Types (4): Conventional, Priority, Nonconventional, WET
    - MSGP Industrial Sectors (~30)
    - Water Parameters (~40): 15 metals, 5 volatile organics, 5 nutrients,
      5 conventional, 5 non-conventional, 2 WET, 4 physical (non-pollutant)

DOES NOT INCLUDE:
    - Stormwater construction general permit (CGP) — separate permit program
    - Underground Injection Control (UIC) — separate Title of the SDWA
    - Section 404 dredge-and-fill — separate permit program
    - Drinking water / SDWA monitoring — separate regulatory program

REGULATORY DRIVERS:
    - Clean Water Act Sections 301, 304, 307, 308, 309, 311, 402
    - 40 CFR 122 (EPA NPDES regulations)
    - 40 CFR 136 (analytical test methods, WET)
    - 40 CFR 401.16 (conventional pollutants)
    - 40 CFR 403 (pretreatment standards)
    - 40 CFR 423 Appendix A (126 priority pollutants)
    - EPA 2021 Multi-Sector General Permit (MSGP)
*/
