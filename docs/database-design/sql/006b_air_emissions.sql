-- Waypoint-EHS - Air Emissions Tracking Schema
-- Tracks material usage, emission calculations, and reporting for air permits.
-- Designed for small manufacturing: welding, coating, combustion sources.
--
-- Regulatory References:
--   Clean Air Act - Title V, NSR/PSD permits
--   40 CFR Part 51/52 - State Implementation Plans
--   EPA AP-42 - Compilation of Air Pollutant Emission Factors
--   State air quality programs (MAERS in Michigan, etc.)
--
-- Design Philosophy:
--   - Material usage as anchor table (what was used, when, where)
--   - Source-specific detail tables extend usage only where needed
--   - Configuration-driven: facilities define their own sources and factors
--   - Calculated emissions stored for audit trail (not just views)
--   - Annual inventory rollup for regulatory reporting
--
-- Connects to:
--   - establishments (001_incidents.sql)
--   - employees (001_incidents.sql) - who recorded usage
--   - permits (006_permits.sql) - links to air permits
--   - permit_conditions (006_permits.sql) - emission limits

-- ============================================================================
-- STACKS
-- ============================================================================
-- Exhaust points where emissions are released. Not all sources have stacks
-- (fugitive emissions), but permits and dispersion modeling require stack data.

CREATE TABLE IF NOT EXISTS air_stacks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    stack_name TEXT NOT NULL,               -- 'Paint Booth Exhaust', 'Boiler Stack'
    stack_number TEXT,                      -- Permit-assigned ID if applicable

    -- Physical parameters (for permits and dispersion modeling)
    height_ft REAL,                         -- Stack height above ground
    diameter_in REAL,                       -- Internal diameter at exit
    exit_velocity_fps REAL,                 -- Feet per second (nullable)
    exit_temperature_f REAL,                -- Exhaust temperature (nullable)

    -- Location (for dispersion modeling)
    latitude REAL,
    longitude REAL,

    -- Permit reference
    permit_id INTEGER,                      -- FK to permits (nullable)

    -- Status
    is_active INTEGER DEFAULT 1,
    install_date TEXT,
    decommission_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    UNIQUE(establishment_id, stack_name)
);

CREATE INDEX idx_air_stacks_establishment ON air_stacks(establishment_id);
CREATE INDEX idx_air_stacks_permit ON air_stacks(permit_id);


-- ============================================================================
-- EMISSION UNITS
-- ============================================================================
-- Physical sources that emit pollutants: equipment, process areas, operations.
-- This is the anchor point - everything ties back to "which unit generated this?"

CREATE TABLE IF NOT EXISTS air_emission_units (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    unit_name TEXT NOT NULL,                -- 'Weld Cell 1', 'Paint Booth A', 'Boiler #2'
    unit_description TEXT,

    -- Source classification
    source_category TEXT NOT NULL,          -- 'welding', 'coating', 'combustion', 'solvent', 'material_handling'
    scc_code TEXT,                          -- EPA Source Classification Code (optional)

    -- Physical location within facility
    building TEXT,
    area TEXT,

    -- Stack relationship (nullable for fugitive sources)
    stack_id INTEGER,

    -- Permit reference
    permit_id INTEGER,                      -- If this unit is specifically permitted

    -- Operating parameters
    max_throughput REAL,                    -- Maximum rated capacity
    max_throughput_unit TEXT,               -- 'tons/hr', 'gallons/day', 'MMBtu/hr'
    typical_operating_hours_year REAL,      -- Typical annual operating hours

    -- Status
    is_active INTEGER DEFAULT 1,
    install_date TEXT,
    decommission_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (stack_id) REFERENCES air_stacks(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    UNIQUE(establishment_id, unit_name)
);

CREATE INDEX idx_air_units_establishment ON air_emission_units(establishment_id);
CREATE INDEX idx_air_units_category ON air_emission_units(source_category);
CREATE INDEX idx_air_units_stack ON air_emission_units(stack_id);
CREATE INDEX idx_air_units_permit ON air_emission_units(permit_id);


-- ============================================================================
-- EMISSION MATERIALS
-- ============================================================================
-- Materials tracked for emissions: coatings, fuels, welding consumables, solvents.
-- Properties stored separately to support reformulations and time-based lookups.

CREATE TABLE IF NOT EXISTS air_emission_materials (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    material_name TEXT NOT NULL,            -- 'E70S-6 MIG Wire', 'Rustoleum Industrial Enamel'
    material_category TEXT NOT NULL,        -- 'welding_consumable', 'coating', 'fuel', 'solvent', 'raw_material'

    -- Identification
    manufacturer TEXT,
    product_code TEXT,                      -- Manufacturer's product code

    -- Default unit of measure
    default_unit TEXT,                      -- 'lbs', 'gallons', 'therms', 'cubic_feet'

    -- SDS reference (if applicable)
    chemical_id INTEGER,                    -- FK to chemicals table (nullable)

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
-- MATERIAL PROPERTIES (Key-Value)
-- ============================================================================
-- Properties that affect emission calculations. Key-value approach supports
-- varying property types across material categories and reformulations over time.

CREATE TABLE IF NOT EXISTS air_material_properties (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_id INTEGER NOT NULL,

    property_key TEXT NOT NULL,             -- 'voc_content', 'heat_content', 'density', 'vapor_pressure'
    property_value TEXT NOT NULL,           -- Stored as text, parsed as needed
    property_unit TEXT,                     -- '%', 'BTU/scf', 'lb/gal', 'mmHg'

    -- Source of this property value
    source TEXT,                            -- 'sds', 'lab_analysis', 'manufacturer', 'default', 'epa'
    source_document TEXT,                   -- Reference to specific document

    -- Time validity (same material can have different properties over time)
    effective_date TEXT NOT NULL,           -- When this value became valid
    superseded_date TEXT,                   -- When replaced (NULL if current)

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (material_id) REFERENCES air_emission_materials(id),
    UNIQUE(material_id, property_key, effective_date)
);

CREATE INDEX idx_air_props_material ON air_material_properties(material_id);
CREATE INDEX idx_air_props_key ON air_material_properties(property_key);
CREATE INDEX idx_air_props_effective ON air_material_properties(effective_date);


-- ============================================================================
-- EMISSION FACTORS
-- ============================================================================
-- Published factors that convert usage to emissions. Pre-seed with AP-42 factors,
-- users can add facility-specific factors from stack tests.

CREATE TABLE IF NOT EXISTS air_emission_factors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Classification for matching
    source_category TEXT NOT NULL,          -- 'welding', 'coating', 'combustion'
    process_type TEXT,                      -- 'MIG', 'spray_hvlp', 'natural_gas_boiler'

    -- Granular matching fields (optional - for power users)
    material_match TEXT,                    -- Electrode type, fuel type, coating type
    equipment_match TEXT,                   -- Specific equipment applicability

    -- The factor itself
    pollutant_code TEXT NOT NULL,           -- 'PM', 'PM10', 'PM25', 'VOC', 'NOx', 'CO', 'Mn', 'Cr'
    factor_value REAL NOT NULL,
    factor_unit TEXT NOT NULL,              -- 'lb/ton', 'lb/MMBtu', 'lb/gallon', 'lb/lb'

    -- Factor source and documentation
    factor_source TEXT NOT NULL,            -- 'AP-42', 'state_guidance', 'manufacturer', 'stack_test'
    source_section TEXT,                    -- 'Table 12.19-1' for AP-42 references
    source_date TEXT,                       -- Publication/test date

    -- Applicability
    applicability_notes TEXT,               -- Conditions, limitations
    rating TEXT,                            -- AP-42 rating: 'A', 'B', 'C', 'D', 'E'

    -- Time validity
    effective_date TEXT,
    superseded_date TEXT,                   -- When replaced by newer factor

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX idx_air_factors_category ON air_emission_factors(source_category);
CREATE INDEX idx_air_factors_process ON air_emission_factors(process_type);
CREATE INDEX idx_air_factors_pollutant ON air_emission_factors(pollutant_code);
CREATE INDEX idx_air_factors_source ON air_emission_factors(factor_source);


-- ============================================================================
-- CONTROL DEVICES
-- ============================================================================
-- Pollution control equipment: baghouses, scrubbers, filters, oxidizers.

CREATE TABLE IF NOT EXISTS air_control_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    device_name TEXT NOT NULL,              -- 'Paint Booth Filters', 'Weld Fume Collector'
    device_type TEXT NOT NULL,              -- 'baghouse', 'scrubber_wet', 'filter_panel', 'thermal_oxidizer'

    -- What does this control?
    emission_unit_id INTEGER,               -- FK to emission_units (nullable if controls multiple)

    -- Equipment details
    manufacturer TEXT,
    model_number TEXT,
    serial_number TEXT,

    -- Permit reference
    permit_id INTEGER,

    -- Status
    is_active INTEGER DEFAULT 1,
    install_date TEXT,
    decommission_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (emission_unit_id) REFERENCES air_emission_units(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    UNIQUE(establishment_id, device_name)
);

CREATE INDEX idx_air_controls_establishment ON air_control_devices(establishment_id);
CREATE INDEX idx_air_controls_unit ON air_control_devices(emission_unit_id);
CREATE INDEX idx_air_controls_type ON air_control_devices(device_type);


-- ============================================================================
-- CONTROL DEVICE EFFICIENCY (Per Pollutant)
-- ============================================================================
-- Control efficiency varies by pollutant. A baghouse might be 99% for PM but 0% for VOC.

CREATE TABLE IF NOT EXISTS air_control_efficiency (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    control_device_id INTEGER NOT NULL,

    pollutant_code TEXT NOT NULL,           -- 'PM', 'PM10', 'VOC', etc.
    control_efficiency_pct REAL NOT NULL,   -- 0-100

    -- Source of efficiency value
    efficiency_source TEXT,                 -- 'permit', 'manufacturer', 'stack_test', 'default'
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
-- CONTROL DEVICE MONITORING
-- ============================================================================
-- Operating parameter monitoring: pressure drops, temperatures, etc.
-- Optional - only for facilities with monitoring requirements.

CREATE TABLE IF NOT EXISTS air_control_monitoring (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    control_device_id INTEGER NOT NULL,

    monitoring_date TEXT NOT NULL,          -- Format: YYYY-MM-DD
    monitoring_time TEXT,                   -- Format: HH:MM

    -- Reading
    parameter TEXT NOT NULL,                -- 'pressure_drop', 'temperature', 'opacity', 'flow_rate'
    value REAL NOT NULL,
    unit TEXT NOT NULL,                     -- 'in_wc', 'degrees_f', 'percent', 'cfm'

    -- Compliance
    min_limit REAL,
    max_limit REAL,
    within_range INTEGER,                   -- 0=out of range, 1=within range

    -- Who recorded
    recorded_by_employee_id INTEGER,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (control_device_id) REFERENCES air_control_devices(id),
    FOREIGN KEY (recorded_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_air_monitoring_device ON air_control_monitoring(control_device_id);
CREATE INDEX idx_air_monitoring_date ON air_control_monitoring(monitoring_date);
CREATE INDEX idx_air_monitoring_param ON air_control_monitoring(parameter);


-- ============================================================================
-- MATERIAL USAGE (Anchor Table)
-- ============================================================================
-- Core tracking table. Works for any source type.
-- "What material, how much, when, where."

CREATE TABLE IF NOT EXISTS air_material_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    emission_unit_id INTEGER NOT NULL,
    material_id INTEGER NOT NULL,

    -- Time period
    usage_period_start TEXT NOT NULL,       -- Format: YYYY-MM-DD (typically first of month)
    usage_period_end TEXT NOT NULL,         -- Format: YYYY-MM-DD

    -- Quantity
    quantity_used REAL NOT NULL,
    unit_of_measure TEXT NOT NULL,          -- 'lbs', 'gallons', 'therms', 'tons', 'cubic_feet'

    -- Data quality
    data_source TEXT,                       -- 'purchase_records', 'inventory_count', 'meter_reading', 'estimate'
    data_quality TEXT,                      -- 'measured', 'calculated', 'estimated'

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
-- MATERIAL USAGE HISTORY (Audit Trail)
-- ============================================================================
-- Every change to usage records logged with reason. Auditors love this.

CREATE TABLE IF NOT EXISTS air_material_usage_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_usage_id INTEGER NOT NULL,

    change_type TEXT NOT NULL,              -- 'insert', 'update', 'delete'
    changed_at TEXT DEFAULT (datetime('now')),
    changed_by_employee_id INTEGER,

    -- What changed
    field_changed TEXT,                     -- Which field (for updates)
    old_value TEXT,
    new_value TEXT,

    -- WHY it changed (required for defensible records)
    change_reason TEXT NOT NULL,            -- 'Corrected scale error', 'Received actual from accounting'

    FOREIGN KEY (material_usage_id) REFERENCES air_material_usage(id),
    FOREIGN KEY (changed_by_employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_air_usage_history_usage ON air_material_usage_history(material_usage_id);
CREATE INDEX idx_air_usage_history_date ON air_material_usage_history(changed_at);


-- ============================================================================
-- WELDING DETAILS (Source-Specific Extension)
-- ============================================================================
-- Only used when emission_unit.source_category = 'welding'
-- Extends material_usage with process variables that affect factor selection.

CREATE TABLE IF NOT EXISTS air_welding_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_usage_id INTEGER NOT NULL UNIQUE,  -- 1:1 with material_usage

    -- Process identification (for factor matching)
    welding_process TEXT NOT NULL,          -- 'GMAW', 'GTAW', 'SMAW', 'FCAW', 'SAW'
    electrode_type TEXT,                    -- 'E70S-6', 'E7018', 'E71T-1', etc.
    electrode_diameter TEXT,                -- '0.035', '0.045', '3/32', etc.

    -- Additional process variables
    shielding_gas TEXT,                     -- 'Ar', 'CO2', '75/25', 'None' (for SMAW)
    base_metal TEXT,                        -- 'carbon_steel', 'stainless', 'aluminum', 'galvanized'

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (material_usage_id) REFERENCES air_material_usage(id) ON DELETE CASCADE
);

CREATE INDEX idx_air_welding_usage ON air_welding_details(material_usage_id);
CREATE INDEX idx_air_welding_process ON air_welding_details(welding_process);
CREATE INDEX idx_air_welding_base ON air_welding_details(base_metal);


-- ============================================================================
-- COATING DETAILS (Source-Specific Extension)
-- ============================================================================
-- Only used when emission_unit.source_category = 'coating'
-- Transfer efficiency is the key variable for spray operations.

CREATE TABLE IF NOT EXISTS air_coating_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_usage_id INTEGER NOT NULL UNIQUE,  -- 1:1 with material_usage

    -- Application method (for factor matching and efficiency)
    application_method TEXT NOT NULL,       -- 'spray_hvlp', 'spray_conventional', 'spray_airless',
                                            -- 'brush', 'roller', 'dip', 'electrostatic', 
                                            -- 'powder', 'electrocoat'

    -- Transfer efficiency (what % hits the part)
    transfer_efficiency_pct REAL,           -- NULL for electrocoat (calc is different)

    -- Application environment
    is_inside_booth INTEGER DEFAULT 1,      -- Contained vs open application

    -- Reducer/thinner tracking (often 100% VOC)
    reducer_added_gal REAL,                 -- Amount of thinner added (nullable)
    reducer_material_id INTEGER,            -- FK to materials (nullable)

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (material_usage_id) REFERENCES air_material_usage(id) ON DELETE CASCADE,
    FOREIGN KEY (reducer_material_id) REFERENCES air_emission_materials(id)
);

CREATE INDEX idx_air_coating_usage ON air_coating_details(material_usage_id);
CREATE INDEX idx_air_coating_method ON air_coating_details(application_method);


-- ============================================================================
-- COMBUSTION DETAILS (Source-Specific Extension)
-- ============================================================================
-- Only used when emission_unit.source_category = 'combustion'
-- Equipment type drives factor selection.

CREATE TABLE IF NOT EXISTS air_combustion_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_usage_id INTEGER NOT NULL UNIQUE,  -- 1:1 with material_usage

    -- Equipment identification (for factor matching)
    equipment_type TEXT NOT NULL,           -- 'boiler', 'furnace', 'heater', 'generator', 
                                            -- 'turbine', 'engine_ic'

    -- Capacity
    heat_input_rating_mmbtu REAL,           -- Max rated capacity (MMBtu/hr)

    -- Operating data
    operating_hours REAL,                   -- Hours operated during usage period

    -- Burner details (affects NOx factors)
    burner_type TEXT,                       -- 'low_nox', 'standard', 'ultra_low_nox'

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (material_usage_id) REFERENCES air_material_usage(id) ON DELETE CASCADE
);

CREATE INDEX idx_air_combustion_usage ON air_combustion_details(material_usage_id);
CREATE INDEX idx_air_combustion_type ON air_combustion_details(equipment_type);


-- ============================================================================
-- CALCULATED EMISSIONS
-- ============================================================================
-- Stored emission calculations for audit trail. What was reported must be reproducible.

CREATE TABLE IF NOT EXISTS air_calculated_emissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    emission_unit_id INTEGER NOT NULL,

    -- Link to source data
    material_usage_id INTEGER,              -- FK to material_usage (nullable for unit-level calcs)
    emission_factor_id INTEGER NOT NULL,    -- Which factor was used

    -- Calculation period
    calculation_period_start TEXT NOT NULL,
    calculation_period_end TEXT NOT NULL,

    -- Result
    pollutant_code TEXT NOT NULL,           -- 'PM', 'PM10', 'VOC', 'NOx', etc.
    gross_emissions REAL NOT NULL,          -- Before control efficiency
    gross_emissions_unit TEXT NOT NULL,     -- 'lbs', 'tons'

    -- Control device (if applicable)
    control_device_id INTEGER,
    control_efficiency_pct REAL,            -- Efficiency applied (snapshot)
    controlled_emissions REAL,              -- After control (what's actually emitted)

    -- Calculation metadata
    calculation_method TEXT,                -- 'factor', 'mass_balance', 'cems', 'stack_test'
    calculated_at TEXT DEFAULT (datetime('now')),
    calculated_by_employee_id INTEGER,

    -- Input values snapshot (for audit reproducibility)
    input_quantity REAL,                    -- Usage quantity at time of calc
    input_unit TEXT,
    factor_value_used REAL,                 -- Factor at time of calc
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
-- ANNUAL EMISSIONS INVENTORY
-- ============================================================================
-- Rollup for regulatory reporting (MAERS, state inventories).
-- Once finalized, numbers are locked for the official record.

CREATE TABLE IF NOT EXISTS air_annual_inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Reporting period
    reporting_year INTEGER NOT NULL,

    -- Source identification
    emission_unit_id INTEGER NOT NULL,
    stack_id INTEGER,                       -- For stack-level reporting

    -- Emissions by pollutant
    pollutant_code TEXT NOT NULL,
    annual_emissions REAL NOT NULL,         -- Controlled emissions
    emissions_unit TEXT NOT NULL,           -- 'tons' (MAERS wants tons)

    -- Calculation basis
    calculation_method TEXT,                -- 'factor', 'mass_balance', 'cems', 'stack_test'
    data_quality TEXT,                      -- 'measured', 'calculated', 'estimated'

    -- Finalization (locks the record)
    is_finalized INTEGER DEFAULT 0,
    finalized_at TEXT,
    finalized_by_employee_id INTEGER,

    -- Submission tracking
    is_submitted INTEGER DEFAULT 0,
    submitted_at TEXT,
    submission_method TEXT,                 -- 'MAERS', 'state_portal', 'paper'
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
-- SEED DATA: COMMON EMISSION FACTORS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Welding Emission Factors (AP-42, Section 12.19)
-- ----------------------------------------------------------------------------
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


-- ----------------------------------------------------------------------------
-- Combustion Emission Factors (AP-42, Section 1.4 - Natural Gas)
-- ----------------------------------------------------------------------------
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


-- ----------------------------------------------------------------------------
-- Coating Emission Factors (General - VOC from coating solids)
-- Note: Actual coating calcs typically use mass balance from VOC content
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO air_emission_factors
    (id, source_category, process_type, material_match, pollutant_code,
     factor_value, factor_unit, factor_source, applicability_notes) VALUES
    -- VOC factor = 1.0 (mass balance: all VOC in coating is emitted)
    (200, 'coating', 'spray_hvlp', NULL, 'VOC', 1.0, 'lb/lb_voc', 'mass_balance', 
     'Applied to VOC content × quantity used'),
    (201, 'coating', 'spray_conventional', NULL, 'VOC', 1.0, 'lb/lb_voc', 'mass_balance',
     'Applied to VOC content × quantity used'),
    (202, 'coating', 'electrocoat', NULL, 'VOC', 1.0, 'lb/lb_voc', 'mass_balance',
     'Applied to VOC content × replenishment quantity'),

    -- PM from spray (overspray particulate)
    (210, 'coating', 'spray_hvlp', NULL, 'PM', 0.35, 'lb/lb_solids', 'EPA guidance',
     'Based on 65% transfer efficiency'),
    (211, 'coating', 'spray_conventional', NULL, 'PM', 0.70, 'lb/lb_solids', 'EPA guidance',
     'Based on 30% transfer efficiency');


-- ============================================================================
-- VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- v_air_material_properties_current
-- Get current (non-superseded) properties for each material
-- ----------------------------------------------------------------------------
CREATE VIEW v_air_material_properties_current AS
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


-- ----------------------------------------------------------------------------
-- v_air_usage_with_details
-- Material usage joined with source-specific details
-- ----------------------------------------------------------------------------
CREATE VIEW v_air_usage_with_details AS
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


-- ----------------------------------------------------------------------------
-- v_air_control_efficiency_current
-- Current control efficiency by device and pollutant
-- ----------------------------------------------------------------------------
CREATE VIEW v_air_control_efficiency_current AS
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


-- ----------------------------------------------------------------------------
-- v_air_emissions_by_unit
-- Calculated emissions summary by emission unit
-- ----------------------------------------------------------------------------
CREATE VIEW v_air_emissions_by_unit AS
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


-- ----------------------------------------------------------------------------
-- v_air_emissions_by_pollutant
-- Facility-wide emissions summary by pollutant
-- ----------------------------------------------------------------------------
CREATE VIEW v_air_emissions_by_pollutant AS
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


-- ----------------------------------------------------------------------------
-- v_air_inventory_status
-- Annual inventory completion status
-- ----------------------------------------------------------------------------
CREATE VIEW v_air_inventory_status AS
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


-- ----------------------------------------------------------------------------
-- v_air_control_monitoring_recent
-- Recent control device monitoring with compliance status
-- ----------------------------------------------------------------------------
CREATE VIEW v_air_control_monitoring_recent AS
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
    
    CASE
        WHEN cm.within_range = 0 THEN 'OUT_OF_RANGE'
        ELSE 'OK'
    END AS status

FROM air_control_monitoring cm
INNER JOIN air_control_devices cd ON cm.control_device_id = cd.id
LEFT JOIN air_emission_units eu ON cd.emission_unit_id = eu.id
WHERE cm.monitoring_date >= date('now', '-90 days')
ORDER BY cm.monitoring_date DESC, cd.device_name;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-log material usage changes to history table
-- ----------------------------------------------------------------------------
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


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================
/*

-- 1. Add an emission unit (welding cell)
INSERT INTO air_emission_units
    (establishment_id, unit_name, source_category, building, area, is_active)
VALUES
    (1, 'Weld Cell 1', 'welding', 'Main Shop', 'Fabrication', 1);

-- 2. Add a material (MIG wire)
INSERT INTO air_emission_materials
    (material_name, material_category, manufacturer, default_unit)
VALUES
    ('E70S-6 MIG Wire 0.035"', 'welding_consumable', 'Lincoln Electric', 'lbs');

-- 3. Record material usage for January
INSERT INTO air_material_usage
    (establishment_id, emission_unit_id, material_id, 
     usage_period_start, usage_period_end, quantity_used, unit_of_measure,
     data_source, recorded_by_employee_id)
VALUES
    (1, 1, 1, '2025-01-01', '2025-01-31', 450, 'lbs', 'inventory_count', 1);

-- 4. Add welding details for that usage record
INSERT INTO air_welding_details
    (material_usage_id, welding_process, electrode_type, electrode_diameter,
     shielding_gas, base_metal)
VALUES
    (last_insert_rowid(), 'GMAW', 'E70S-6', '0.035', '75/25', 'carbon_steel');

-- 5. View usage with all details
SELECT * FROM v_air_usage_with_details
WHERE establishment_id = 1
  AND usage_period_start >= '2025-01-01';

-- 6. Find matching emission factors for welding
SELECT * FROM air_emission_factors
WHERE source_category = 'welding'
  AND process_type = 'GMAW'
  AND (material_match = 'carbon_steel' OR material_match IS NULL);

-- 7. Calculate emissions (manual example - would typically be done via application)
-- PM emissions = 450 lbs wire × (1 ton / 2000 lbs) × 6.6 lb/ton = 1.485 lbs PM
INSERT INTO air_calculated_emissions
    (establishment_id, emission_unit_id, material_usage_id, emission_factor_id,
     calculation_period_start, calculation_period_end,
     pollutant_code, gross_emissions, gross_emissions_unit,
     calculation_method, input_quantity, input_unit, factor_value_used, factor_unit_used)
VALUES
    (1, 1, 1, 1,
     '2025-01-01', '2025-01-31',
     'PM', 1.485, 'lbs',
     'factor', 450, 'lbs', 6.6, 'lb/ton');

-- 8. Get emissions summary by pollutant
SELECT * FROM v_air_emissions_by_pollutant
WHERE establishment_id = 1
  AND year = '2025';

-- 9. Populate annual inventory from calculated emissions
INSERT INTO air_annual_inventory
    (establishment_id, reporting_year, emission_unit_id, pollutant_code,
     annual_emissions, emissions_unit, calculation_method, data_quality)
SELECT
    establishment_id,
    2025,
    emission_unit_id,
    pollutant_code,
    SUM(controlled_emissions) / 2000.0,  -- Convert lbs to tons
    'tons',
    'factor',
    'calculated'
FROM air_calculated_emissions
WHERE establishment_id = 1
  AND calculation_period_start >= '2025-01-01'
  AND calculation_period_end <= '2025-12-31'
GROUP BY establishment_id, emission_unit_id, pollutant_code;

-- 10. Finalize inventory for submission
UPDATE air_annual_inventory
SET 
    is_finalized = 1,
    finalized_at = datetime('now'),
    finalized_by_employee_id = 1
WHERE establishment_id = 1
  AND reporting_year = 2025;

-- 11. Track coating usage with VOC content
-- First, add material and VOC property
INSERT INTO air_emission_materials
    (material_name, material_category, manufacturer, default_unit)
VALUES
    ('Industrial Enamel - Blue', 'coating', 'Rustoleum', 'gallons');

INSERT INTO air_material_properties
    (material_id, property_key, property_value, property_unit, source, effective_date)
VALUES
    (last_insert_rowid(), 'voc_content', '3.5', 'lb/gal', 'sds', '2025-01-01');

-- 12. Record coating usage
INSERT INTO air_material_usage
    (establishment_id, emission_unit_id, material_id,
     usage_period_start, usage_period_end, quantity_used, unit_of_measure,
     data_source)
VALUES
    (1, 2, 2, '2025-01-01', '2025-01-31', 25, 'gallons', 'purchase_records');

INSERT INTO air_coating_details
    (material_usage_id, application_method, transfer_efficiency_pct, is_inside_booth)
VALUES
    (last_insert_rowid(), 'spray_hvlp', 65, 1);

-- 13. Monitor control device
INSERT INTO air_control_monitoring
    (control_device_id, monitoring_date, monitoring_time,
     parameter, value, unit, min_limit, max_limit, within_range,
     recorded_by_employee_id)
VALUES
    (1, '2025-01-15', '08:00', 'pressure_drop', 2.5, 'in_wc', 1.0, 4.0, 1, 1);

-- 14. View recent monitoring
SELECT * FROM v_air_control_monitoring_recent;

*/


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
AIR EMISSIONS MODULE (006b_air_emissions.sql)

PURPOSE:
Track material usage, calculate air emissions, and manage annual inventory
reporting for air permits (MAERS, state programs).

INFRASTRUCTURE TABLES:
    - air_stacks: Exhaust points with physical parameters
    - air_emission_units: Emission sources (the things that emit)
    - air_emission_materials: Materials tracked for emissions
    - air_material_properties: Key-value properties (VOC%, heat content)
    - air_emission_factors: Published factors (AP-42, stack tests)
    - air_control_devices: Pollution control equipment
    - air_control_efficiency: Per-pollutant control efficiency
    - air_control_monitoring: Operating parameter monitoring

OPERATIONAL TABLES:
    - air_material_usage: Anchor table - what was used, when, where
    - air_welding_details: Process variables for welding
    - air_coating_details: Application method, transfer efficiency
    - air_combustion_details: Equipment type, heat input
    - air_material_usage_history: Audit trail with change reasons

OUTPUT TABLES:
    - air_calculated_emissions: Stored calculations with audit trail
    - air_annual_inventory: Rolled up data for regulatory reporting

VIEWS:
    - v_air_material_properties_current: Current (non-superseded) properties
    - v_air_usage_with_details: Usage joined with source-specific details
    - v_air_control_efficiency_current: Current control efficiency
    - v_air_emissions_by_unit: Summary by emission unit
    - v_air_emissions_by_pollutant: Facility-wide by pollutant
    - v_air_inventory_status: Annual inventory completion status
    - v_air_control_monitoring_recent: Recent monitoring with status

PRE-SEEDED EMISSION FACTORS:
    Welding (AP-42 12.19):
        - GMAW (MIG): carbon steel, stainless, galvanized
        - SMAW (Stick): carbon steel
        - FCAW (Flux-core): carbon steel
        - GTAW (TIG): all metals
        - Pollutants: PM, PM10, PM25, Mn, Cr, Cr6, Ni, Zn
    
    Combustion (AP-42 1.4, 1.5):
        - Natural gas boilers (standard and low-NOx)
        - Propane boilers
        - Pollutants: NOx, CO, PM, PM10, PM25, SO2, VOC
    
    Coating:
        - Mass balance factors for VOC
        - PM from spray overspray

KEY DESIGN DECISIONS:
    1. Material usage as anchor table - works for any source type
    2. Source-specific detail tables (welding, coating, combustion) only where needed
    3. Key-value material properties with effective_date for reformulations
    4. Calculated emissions stored (not just views) for audit trail
    5. Annual inventory separate table for finalization/submission tracking
    6. Control efficiency per-pollutant (baghouse ≠ VOC control)
    7. Electrocoat in coating_details with no transfer efficiency adjustment

CALCULATION PATTERNS:
    Welding:    wire_lbs × (1 ton / 2000 lbs) × factor_lb_per_ton
    Coating:    gallons × voc_lb_per_gal × (1 - transfer_efficiency for overspray)
    Electrocoat: replenishment_gal × voc_lb_per_gal (no TE adjustment)
    Combustion: fuel_quantity × factor × unit_conversion

INTEGRATION POINTS:
    - establishments (001): Multi-site support
    - employees (001): Who recorded usage, who calculated
    - permits (006): Link units and stacks to permits
    - permit_conditions (006): Emission limits
    - chemicals (002): SDS reference for materials

REGULATORY DRIVERS:
    - Clean Air Act (Title V, NSR/PSD)
    - EPA AP-42 emission factors
    - State air quality programs (MAERS in Michigan)
    - Annual emission inventories

FUTURE ENHANCEMENTS:
    - Emission calculation engine (automate factor matching)
    - MAERS export format
    - Permit limit compliance checking
    - Stack test data management
    - CEMS integration
*/
