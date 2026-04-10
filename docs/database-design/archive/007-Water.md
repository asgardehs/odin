# 006c Industrial Wastewater Module

## Configuration Layer (Set once per facility)

**`monitoring_locations`**
```
location_id (PK)
location_code (e.g., "COMP-TANK", "CLARIFIER")
location_name
location_type (outfall, internal_sample_point, equipment)
description
active (boolean)
```
**`water_parameters`**
```
parameter_id (PK)
parameter_code (e.g., "CR-T", "NI-T", "BOD5")
parameter_name (e.g., "Chromium (Total)")
cas_number (optional)
typical_units (mg/L, μg/L, pH units)
requires_lab (boolean) - some need certified lab, others can be field measured
```

**`monitoring_requirements`**
```
requirement_id (PK)
facility_id (FK)
location_id (FK)
parameter_id (FK)
frequency_type (daily, weekly, monthly, quarterly, annual)
frequency_count (e.g., 1 for "1x weekly")
sample_type (grab, composite, flow_proportional) - nullable
limit_daily_max (nullable)
limit_monthly_avg (nullable) - for others who have this
limit_units
mandatory (boolean) - permit required vs voluntary monitoring
permit_reference (text) - which permit requires this
effective_date
end_date (nullable)
notes
```

---

## Operational Layer (Daily work)

**`sampling_events`** (anchor table)
```
event_id (PK)
facility_id (FK)
location_id (FK)
sample_date
sample_time
sample_type (grab, composite)
sampled_by_employee_id (FK to employees)
weather_conditions (for stormwater relevance)
equipment_id (FK - nullable, for calibration tracking)
lab_submission_id (FK - nullable)
notes
```

**`sample_results`**
```
result_id (PK)
event_id (FK)
parameter_id (FK)
result_value (decimal)
result_units
detection_limit (nullable)
reporting_limit (nullable)
result_qualifier (ND, J, U, etc.) - lab qualifiers
analyzed_date (nullable - if different from sample date)
analyzed_by (field vs lab name)
notes
```

**`lab_submissions`** (optional but recommended)
```
submission_id (PK)
facility_id (FK)
lab_name
lab_certification_number
chain_of_custody_number
submitted_date
received_date (by lab)
report_received_date
report_file_reference (link to document management)
notes
```

**`equipment_calibrations`** (optional)
```
calibration_id (PK)
equipment_id (FK - references equipment table)
calibration_date
calibrated_by_employee_id (FK)
calibration_standard_used
next_calibration_due
passed (boolean)
notes
```

**`flow_measurements`** (optional - for others who track discharge)
```
measurement_id (PK)
facility_id (FK)
location_id (FK)
measurement_date
flow_rate
flow_units (MGD, GPM, etc.)
measurement_method (meter, calculated, estimated)
notes
```

---

### Key Design Decisions

1. **`monitoring_requirements` is your configuration** - user define "test Chromium weekly at composite tank, limit 1.00 mg/L"
2. **`sampling_events` is the anchor** - "on 2025-12-01, I sampled the composite tank"
3. **`sample_results` stores measurements** - "Chromium was 0.45 mg/L"
4. **Lab tracking is separate** - multiple samples can go in one lab submission

---
