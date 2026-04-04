# Air Emissions - Schema Sketch

## Emission Units

The physical things that emit. A piece of equipment, a process area, a stack.

| Field | Description |
|-------|-------------|
| id | Primary key |
| establishment_id | FK to establishment |
| unit_name | "Weld Cell 1", "Paint Booth A", "Boiler #2" |
| unit_description | Longer description if needed |
| source_category | What type of source: welding, coating, combustion, solvent, material_handling, etc. |
| permit_id | FK to permits (nullable) — if this unit is specifically permitted |
| stack_id | FK to stacks (nullable) — where does it vent? |
| date_installed | When it went into service |
| date_removed | Null if still active |
| is_active | Boolean |

**Notes:** This is the anchor point. Everything else ties back to "which emission unit generated this?"

---

## Material Usage (Universal)

The core tracking table. Works for any source type.

| Field | Description |
|-------|-------------|
| id | Primary key |
| emission_unit_id | FK to emission_units — what used this material |
| material_id | FK to emission_materials — what was used |
| usage_period_start | Start of tracking period (first of month typically) |
| usage_period_end | End of tracking period |
| quantity_used | How much |
| unit_of_measure | lbs, gallons, therms, tons, etc. |
| data_source | Where'd this number come from: purchase_records, inventory_count, meter_reading, estimate |
| notes | Optional context |

**Notes:** This is intentionally simple. It answers: "What material, how much, when, where." The *how* (welding process, spray vs dip, etc.) goes in detail tables.

---

## Welding Details (Source-Specific Extension)

Only needed when emission_unit.source_category = 'welding'

| Field | Description |
|-------|-------------|
| id | Primary key |
| material_usage_id | FK to material_usage — extends that record |
| welding_process | MIG, TIG, Stick, Flux-core, Submerged Arc, etc. |
| electrode_type | E70S-6, E7018, E71T-1, etc. |
| electrode_diameter | Wire/rod diameter (affects factors sometimes) |
| shielding_gas | Argon, CO2, 75/25, etc. (nullable for stick) |
| base_metal | Carbon steel, stainless, aluminum (affects factor selection) |

**Notes:** This is the pattern. If paint booths need transfer efficiency, that goes in a `coating_details` table. If combustion needs heat content, that goes in a `combustion_details` table. Only build these when you need them.

---

## Emission Materials (Reference)

What materials can be tracked for emissions purposes.

| Field | Description |
|-------|-------------|
| id | Primary key |
| material_name | "E70S-6 MIG Wire", "Rustoleum Industrial Enamel", "Natural Gas" |
| material_category | welding_consumable, coating, fuel, solvent, raw_material |
| default_unit | Default UOM for this material |
| properties | JSON or separate table? VOC content, heat content, density — varies by category |

**Open question:** Do material properties go here as nullable columns, as JSON, or as a separate `material_properties` table with key-value pairs? Each has trade-offs.

---

## Emission Factors (Reference)

The published factors that convert usage to emissions.

| Field | Description |
|-------|-------------|
| id | Primary key |
| source_category | welding, coating, combustion, etc. |
| process_type | MIG, TIG, Spray Coating, Natural Gas Boiler, etc. |
| material_match | What this factor applies to — electrode type, fuel type, etc. |
| pollutant_code | PM, PM10, PM25, VOC, NOx, CO, specific HAPs like manganese |
| factor_value | The numeric factor |
| factor_unit | lb/ton, lb/MMBtu, lb/gallon, etc. |
| factor_source | AP-42, state guidance, manufacturer data, stack test |
| source_section | "Table 12.19-1" for AP-42 references |
| effective_date | When this factor became valid |
| superseded_date | If replaced by newer factor |
| notes | Applicability notes, limitations |

**Notes:** This should be comprehensive. Pre-seed with AP-42 factors for common sources. Users can add facility-specific factors from stack tests.

---

## Calculated Emissions (Output)

The actual emission numbers, calculated from usage × factors.

| Field | Description |
|-------|-------------|
| id | Primary key |
| emission_unit_id | FK to emission_units |
| material_usage_id | FK to material_usage (nullable — some calcs are at unit level) |
| emission_factor_id | FK to emission_factors — which factor was used |
| calculation_period_start | Period these emissions cover |
| calculation_period_end | |
| pollutant_code | PM, VOC, NOx, etc. |
| emissions_value | The calculated number |
| emissions_unit | lbs, tons |
| calculation_method | factor, mass_balance, cems, stack_test |
| calculated_at | Timestamp of calculation |
| calculated_by | User or "system" |
| is_reported | Has this been submitted to MAERS/state? |
| reported_date | When submitted |

**Notes:** This is where the math lives. Could be calculated on-the-fly via views, or stored for audit trail. Probably stored, since you need to know *exactly* what you reported.

---

## Relationships Diagram (Text Version)

```
emission_units
     │
     ├──→ material_usage (what was used, when, how much)
     │         │
     │         └──→ welding_details (only if welding)
     │         └──→ coating_details (only if coating) 
     │         └──→ [other detail tables as needed]
     │
     └──→ calculated_emissions (the output numbers)
                  │
                  └──→ emission_factors (reference data)
```


## Additions to Schema Sketch

### Material Properties (Key-Value)

| Field | Description |
|-------|-------------|
| id | Primary key |
| material_id | FK to emission_materials |
| property_key | voc_content, heat_content, density, vapor_pressure, etc. |
| property_value | The value (stored as text, parsed as needed) |
| property_unit | %, BTU/scf, lb/gal, etc. |
| source | SDS, lab_analysis, manufacturer, default |
| effective_date | When this property value became valid |

**Notes:** Same material can have different properties over time (reformulated coating, different fuel supplier). The effective_date lets you use the right value for historical calculations.

---

### Material Usage History (Audit Trail)

| Field | Description |
|-------|-------------|
| id | Primary key |
| material_usage_id | FK to the record that changed |
| change_type | insert, update, delete |
| changed_at | Timestamp |
| changed_by | User who made the change |
| change_reason | **Required** — why was this changed? |
| field_changed | Which field (for updates) |
| old_value | Previous value |
| new_value | New value |

**Notes:** Every change to a usage record gets logged here with a reason. "Corrected scale reading error", "Received actual purchase qty from accounting", "December inventory recount". Auditors love this.

---

### Annual Emissions Inventory (Reporting Rollup)

| Field | Description |
|-------|-------------|
| id | Primary key |
| establishment_id | FK to establishment |
| reporting_year | 2024, 2025, etc. |
| emission_unit_id | FK to emission_units |
| pollutant_code | PM, PM10, VOC, NOx, etc. |
| annual_emissions | Total for the year |
| emissions_unit | tons (MAERS wants tons) |
| calculation_method | factor, mass_balance, cems, stack_test |
| data_quality | measured, calculated, estimated |
| finalized | Boolean — locked for reporting? |
| finalized_at | When it was locked |
| finalized_by | Who approved it |
| maers_submitted | Has it been submitted? |
| maers_confirmation | Confirmation number from MAERS |

**Notes:** This is what actually gets reported. Once finalized = true, the numbers are locked. Any corrections after that would be a formal amendment.

---

### Emissions Calculation View (v_calculated_emissions)

This is where the math happens. Not a stored table — a view that pulls current numbers on demand.

**Joins:**
- material_usage
- emission_materials
- material_properties (for VOC%, heat content, etc.)
- emission_factors (matched by source_category, process_type, pollutant)
- welding_details / coating_details (for process-specific factor matching)

**Calculates:**
- quantity_used × conversion_factor × emission_factor = emissions_value
- Grouped by emission_unit, pollutant, period

**Usage pattern:**
1. Query the view to see current calculated emissions
2. Review for reasonableness
3. When ready to report, INSERT from view into annual_emissions_inventory
4. Finalize and submit to MAERS

---

## Updated Relationships

```
emission_materials
     │
     └──→ material_properties (key-value, multiple per material)

material_usage
     │
     ├──→ material_usage_history (audit log with reason)
     │
     └──→ [detail tables: welding_details, coating_details, etc.]

v_calculated_emissions (VIEW)
     │
     └──→ [user reviews, then INSERTs into...]
     
annual_emissions_inventory
     │
     └──→ finalize → submit to MAERS
```

---

## Factor Matching Logic (for v_calculated_emissions)

**Default matching:**
```
emission_factors.source_category = emission_units.source_category
AND emission_factors.process_type = [from detail table: welding_details.welding_process, etc.]
```

**What's stored but not matched by default:**
- electrode_type
- electrode_diameter
- base_metal
- shielding_gas

These columns exist in both the detail tables and the factors table. A user who needs electrode-specific factors can write a query that joins on those fields. The data supports it — the default view just doesn't require it.

---

## Stacks (Minimum for Reporting)

Permit applications and emission inventories often require stack parameters. Dispersion modeling definitely does.

| Field | Description |
|-------|-------------|
| id | Primary key |
| establishment_id | FK to establishment |
| stack_name | "Stack 1", "Paint Booth Exhaust", "Boiler Stack" |
| stack_number | Permit-assigned ID if applicable |
| permit_id | FK to permits (nullable) |
| height_ft | Stack height above ground |
| diameter_in | Internal diameter at exit |
| exit_velocity_fps | Feet per second (nullable — not always known) |
| exit_temperature_f | Exhaust temperature (nullable) |
| latitude | For dispersion modeling (nullable) |
| longitude | For dispersion modeling (nullable) |
| is_active | Boolean |
| notes | |

**Notes:** This covers what MAERS and permit applications typically ask for. Facilities without stacks (fugitive emissions only) just don't create records here. The emission_units table already has stack_id as nullable FK.

---

## Control Devices (Minimum for Reporting)

Permits require knowing what controls are in place and their efficiency. Some require monitoring data.

| Field | Description |
|-------|-------------|
| id | Primary key |
| establishment_id | FK to establishment |
| device_name | "Paint Booth Filters", "Weld Fume Collector", "Wet Scrubber" |
| device_type | baghouse, scrubber_wet, scrubber_dry, filter_panel, cyclone, thermal_oxidizer, carbon_adsorber, etc. |
| emission_unit_id | FK to emission_units — what does this control? |
| permit_id | FK to permits (nullable) |
| install_date | |
| manufacturer | (nullable) |
| model_number | (nullable) |
| is_active | Boolean |
| notes | |

---

## Control Device Efficiency (Per Pollutant)

Control efficiency varies by pollutant. A baghouse might be 99% for PM but 0% for VOC.

| Field | Description |
|-------|-------------|
| id | Primary key |
| control_device_id | FK to control_devices |
| pollutant_code | PM, PM10, VOC, etc. |
| control_efficiency_pct | 0-100 |
| efficiency_source | permit, manufacturer, stack_test, default |
| effective_date | When this efficiency was established |

**Notes:** This lets the calculation view apply control efficiency: `uncontrolled_emissions × (1 - control_efficiency)`. Only needed if the facility claims credit for controls in their inventory.

---

## Control Device Monitoring (Optional — For Facilities Like Yours)

Only populated if permit or good practice requires monitoring.

| Field | Description |
|-------|-------------|
| id | Primary key |
| control_device_id | FK to control_devices |
| monitoring_date | When the reading was taken |
| parameter | pressure_drop, temperature, opacity, flow_rate, etc. |
| value | The reading |
| unit | in_wc, degrees_f, percent, cfm |
| within_range | Boolean — was it within acceptable limits? |
| recorded_by | Who took the reading |
| notes | |

**Notes:** This is where your scrubber pressure drops would go. Facilities that don't monitor anything just don't use this table. But it's there for those who need the audit trail.

---

## Updated Relationships

```
emission_units
     │
     ├──→ stacks (where does it vent?)
     │
     └──→ control_devices (what controls it?)
               │
               ├──→ control_device_efficiency (by pollutant)
               │
               └──→ control_device_monitoring (optional readings)
```

---

## How This Affects Calculations

The v_calculated_emissions view can now account for controls:

```
gross_emissions = usage × emission_factor
controlled_emissions = gross_emissions × (1 - control_efficiency)
```

Facilities report controlled emissions. The view can show both for transparency.

---

## Coating Details

Only needed when emission_unit.source_category = 'coating'

| Field | Description |
|-------|-------------|
| id | Primary key |
| material_usage_id | FK to material_usage |
| application_method | spray_hvlp, spray_conventional, spray_airless, brush, roller, dip, electrostatic, powder |
| transfer_efficiency_pct | What % actually hits the part (affects emissions calc) |
| is_inside_booth | Boolean — contained vs open application |
| reducer_added_gal | Thinner/reducer added to coating (nullable) |
| reducer_material_id | FK to emission_materials (nullable) |

**Notes:** The big variable here is transfer efficiency. HVLP spray might be 65%, conventional spray 30%, brush/roll 90%+. The calc becomes: `gallons × VOC_content × (1 - transfer_efficiency) = VOC emissions`. Reducer is tracked separately because it's often 100% VOC.

---

## Combustion Details

Only needed when emission_unit.source_category = 'combustion'

| Field | Description |
|-------|-------------|
| id | Primary key |
| material_usage_id | FK to material_usage |
| equipment_type | boiler, furnace, heater, generator, turbine, engine_ic |
| heat_input_rating_mmbtu | Max rated capacity |
| operating_hours | Hours operated during usage period (nullable) |
| burner_type | Low-NOx, standard, etc. (nullable — affects factors) |

**Notes:** Most combustion calcs are just `fuel_usage × emission_factor`. The equipment details help match to the right factor (boiler vs engine vs turbine have different factors) and support permit applicability checks (is this unit above the threshold?).

---

## Pattern Validation

All three detail tables follow the same structure:

| Aspect | Welding | Coating | Combustion |
|--------|---------|---------|------------|
| Links to | material_usage_id | material_usage_id | material_usage_id |
| Process identifier | welding_process | application_method | equipment_type |
| Key calc variable | base_metal | transfer_efficiency | heat_input_rating |
| Secondary details | electrode, shielding gas | reducer, booth | burner_type, hours |

**The pattern holds.** Each detail table:
1. Extends a material_usage record (1:1 relationship)
2. Captures the process-specific field needed for factor matching
3. Stores additional details that affect calculations or permit applicability
4. Stays small — only fields that actually matter

add `electrocoat` option to coating. 
