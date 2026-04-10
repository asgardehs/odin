# Waypoint-EHS Development Session Summary

**Date:** December 1, 2025  
**Session:** 004 - Permits & Licenses  
**Status:** Complete (Base Structure)

---

## Project Overview

**Waypoint-EHS** is an EHS (Environmental, Health & Safety) compliance database and TUI application designed for small manufacturing companies that cannot afford enterprise ERP modules.

### Technical Stack
- **Database:** SQLite (portable for small companies; migration path to SQL Server planned)
- **Language:** Go
- **TUI Framework:** Bubbles, BubbleTea, HUH, Lipgloss
- **Documentation:** Glow (with planned custom markdown creation capability)

---

## Modules Status

| Order | Module | Status | File(s) |
|-------|--------|--------|---------|
| 001 | Incidents | ✅ Complete | `001_incidents.sql` |
| 002 | Chemicals / SDS | ✅ Complete | `002_chemicals.sql` |
| 002a | SARA 313 / TRI | ✅ Complete | `002a_sara313.sql` |
| 003 | Training Records | ✅ Complete | `003_training.sql` |
| 004 | Waste Management | ✅ Complete | `004_waste.sql` |
| 005 | Inspections & Audits | ✅ Complete | `005_inspections_audits.sql` |
| 006 | Permits | ✅ Complete | `006_permits.sql` |
| 006a | Licenses | ✅ Complete | `006a_licenses.sql` |
| 006b | Air Reporting | 🔲 Next | - |
| 006c | Water Reporting | 🔲 Planned | - |
| 007 | PPE Tracking | 🔲 Planned | - |

---

## Session 004: Permits & Licenses

### Design Decisions

**1. Separation of Permits and Licenses**

Permits and licenses serve different purposes and have different compliance characteristics:

| Aspect | Permits | Licenses |
|--------|---------|----------|
| **Purpose** | Authorize specific operations | Authorize entity/person to operate |
| **Holder** | Facility/operation | Establishment, employee, or equipment |
| **Ongoing Compliance** | Monitoring, reporting, limits | Primarily renewal and CE |
| **Examples** | Title V, NPDES, RCRA | Business license, PE, Wastewater Operator |

**2. Generic Permit Structure First**

Built a flexible base structure that works for all permit types (air, water, waste) before adding media-specific reporting tables. This allows:
- Common views for expiration/renewal tracking
- Unified compliance calendar
- Consistent deviation tracking
- Future extensibility for new permit types

**3. Condition and Limit Separation**

Permit conditions (text-based requirements) are stored separately from permit limits (numeric values):
- Conditions: "Maintain records of all maintenance activities"
- Limits: "NOx ≤ 2.5 lb/hr, 12-month rolling average"

This enables proper compliance tracking and exceedance calculations for limits.

**4. Three License Holder Types**

Licenses can be held by:
- **Establishment**: Business licenses, zoning permits
- **Employee**: Professional certifications (PE, CIH), operator licenses
- **Equipment**: Boiler registrations, elevator permits

Single `licenses` table with holder type indicators rather than separate tables.

**5. Continuing Education Auto-Tracking**

For licenses requiring CE (PE, CIH, CSP, operator licenses):
- Triggers automatically sum CE hours when records added/deleted
- Views show CE progress and identify who's behind
- Tracks CE by period to handle renewal cycles


---

## 006_permits.sql - Permits Module

### Tables Created

#### Reference Tables

| Table | Purpose |
|-------|---------|
| `regulatory_agencies` | Agencies that issue permits (EPA regions, state DEQs, local authorities) |
| `permit_types` | Categories of permits with typical characteristics |

#### Core Permit Tables

| Table | Purpose |
|-------|---------|
| `permits` | Master permit record with dates, status, renewal tracking, fees |
| `permit_conditions` | Individual conditions within permits (text-based requirements) |
| `permit_limits` | Numeric limits with units, averaging periods, monitoring methods |
| `permit_modifications` | Amendment and modification history |

#### Monitoring & Reporting Tables

| Table | Purpose |
|-------|---------|
| `permit_monitoring_requirements` | What monitoring must be performed (methods, frequency, QA/QC) |
| `permit_reporting_requirements` | Reports that must be submitted (DMRs, certifications, inventories) |
| `permit_report_submissions` | Tracking of actual report submissions with confirmation |

#### Compliance Tracking Tables

| Table | Purpose |
|-------|---------|
| `permit_deviations` | Exceedances and deviations with root cause and reporting status |
| `compliance_calendar` | Master calendar of all permit-related obligations |

### Views Created

| View | Purpose |
|------|---------|
| `v_permits_expiring` | Permits approaching expiration with renewal deadline tracking |
| `v_reports_due` | Upcoming report submissions with urgency indicators |
| `v_compliance_calendar_upcoming` | All upcoming compliance obligations |
| `v_open_deviations` | Deviations needing attention (especially unreported ones) |
| `v_permit_summary` | Summary counts by establishment and category |

### Pre-Seeded Permit Types (17 Types)

**Air Permits (6):**
| Code | Name | Term | Reporting |
|------|------|------|-----------|
| TITLE_V | Title V Operating Permit | 5 years | Semi-annual |
| NSR_MAJOR | New Source Review - Major | N/A | Annual |
| PSD | Prevention of Significant Deterioration | N/A | Annual |
| MINOR_SOURCE | Minor Source Air Permit | 5 years | Annual |
| PTI | Permit to Install | N/A | None |
| GP_AIR | General Permit - Air | 5 years | Annual |

**Water Permits (5):**
| Code | Name | Term | Reporting |
|------|------|------|-----------|
| NPDES_INDIVIDUAL | NPDES Individual Permit | 5 years | Monthly |
| NPDES_GENERAL | NPDES General Permit (Industrial) | 5 years | Quarterly |
| NPDES_STORMWATER | NPDES Stormwater (MSGP/CGP) | 5 years | Annual |
| PRETREATMENT | Industrial Pretreatment Permit | 5 years | Monthly |
| GWDP | Groundwater Discharge Permit | 5 years | Quarterly |

**Waste Permits (3):**
| Code | Name | Term |
|------|------|------|
| RCRA_TSDF | RCRA Part B (TSDF) | 10 years |
| RCRA_GENERATOR | RCRA Generator Notification | N/A |
| USED_OIL | Used Oil Handler Registration | N/A |

**Other (3):**
| Code | Name | Term |
|------|------|------|
| SPCC | SPCC Plan (Self-Certified) | 5 years |
| RMP | Risk Management Plan | 5 years |
| TIER2 | Tier II Notification | 1 year |


---

## 006a_licenses.sql - Licenses Module

### Tables Created

#### Reference Tables

| Table | Purpose |
|-------|---------|
| `license_types` | Categories of licenses with CE requirements and renewal characteristics |
| `license_issuing_authorities` | Bodies that issue licenses (state boards, professional orgs) |

#### Core License Tables

| Table | Purpose |
|-------|---------|
| `licenses` | Master license record (can be held by establishment, employee, or equipment) |
| `license_continuing_education` | CE credit records with hours, provider, verification |
| `license_renewal_history` | Historical record of renewal cycles |

### Views Created

| View | Purpose |
|------|---------|
| `v_licenses_expiring` | Licenses approaching expiration with holder info |
| `v_license_ce_status` | CE progress showing hours completed vs required |
| `v_employee_licenses` | All licenses held by employees |
| `v_license_summary` | Summary counts by establishment and category |

### Triggers Created

| Trigger | Purpose |
|---------|---------|
| `trg_license_ce_add` | Auto-update CE hours completed when CE record inserted |
| `trg_license_ce_delete` | Auto-update CE hours completed when CE record deleted |

### Pre-Seeded License Types (24 Types)

**Business Licenses (5):**
| Code | Name | Term | CE Required |
|------|------|------|-------------|
| BUSINESS | Business License | 1 year | No |
| FIRE_PERMIT | Fire Department Permit | 1 year | No |
| OCCUPANCY | Certificate of Occupancy | N/A | No |
| ZONING | Zoning Permit/Variance | N/A | No |
| SALES_TAX | Sales Tax License | 1 year | No |

**Professional Certifications (7):**
| Code | Name | Term | CE Hours |
|------|------|------|----------|
| PE | Professional Engineer | 2 years | 30 |
| CIH | Certified Industrial Hygienist | 5 years | 50 |
| CSP | Certified Safety Professional | 5 years | 25 |
| ASP | Associate Safety Professional | 5 years | None |
| CHMM | Certified Hazardous Materials Manager | 5 years | 20 |
| QEP | Qualified Environmental Professional | 5 years | 30 |
| REM | Registered Environmental Manager | 5 years | 30 |

**Operator Licenses (7):**
| Code | Name | Term | CE Hours |
|------|------|------|----------|
| WASTEWATER_OP | Wastewater Treatment Operator | 3 years | 30 |
| WATER_OP | Water Treatment Operator | 3 years | 30 |
| BOILER_OP | Boiler Operator | 1 year | None |
| CRANE_OP | Crane Operator (NCCCO) | 5 years | None |
| FORKLIFT_TRAINER | Forklift Train-the-Trainer | 3 years | None |
| CDL | Commercial Drivers License | 5 years | None |
| HAZMAT_CDL | CDL Hazmat Endorsement | 5 years | None |

**Equipment Registrations (6):**
| Code | Name | Term |
|------|------|------|
| BOILER_REG | Boiler Registration | 1 year |
| PRESSURE_VESSEL | Pressure Vessel Registration | 1 year |
| ELEVATOR | Elevator Permit | 1 year |
| UST | Underground Storage Tank Registration | 1 year |
| AST | Aboveground Storage Tank Registration | 1 year |
| SCALE | Commercial Scale License | 1 year |


---

## How Permit Compliance Tracking Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PERMIT STRUCTURE                                   │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  NPDES Individual Permit #MI0012345                                 │   │
│   │  Issued: 2023-01-01  │  Expires: 2028-01-01  │  Status: ACTIVE      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│         ┌──────────────────────────┼──────────────────────────┐             │
│         │                          │                          │             │
│         ▼                          ▼                          ▼             │
│   ┌───────────────┐      ┌───────────────┐      ┌───────────────┐          │
│   │  CONDITIONS   │      │    LIMITS     │      │  MONITORING   │          │
│   │               │      │               │      │  REQUIREMENTS │          │
│   │ I.A.1 - DMR   │      │ TSS Daily Max │      │               │          │
│   │   submission  │      │   30 mg/L     │      │ Grab sample   │          │
│   │ I.A.2 - Record│      │ TSS Monthly   │      │ 3x per week   │          │
│   │   retention   │      │   Avg 20 mg/L │      │ EPA 160.2     │          │
│   │ II.B - BMP    │      │ pH Range      │      │               │          │
│   │   requirements│      │   6.0 - 9.0   │      │ Continuous    │          │
│   └───────────────┘      └───────────────┘      └───────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      REPORTING REQUIREMENTS                                  │
│                                                                              │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │
│   │   Monthly DMR    │  │  Annual Report   │  │ Deviation Report │         │
│   │                  │  │                  │  │                  │         │
│   │ Due: 28th of     │  │ Due: March 1     │  │ Due: Within 24   │         │
│   │ following month  │  │                  │  │ hours of event   │         │
│   │                  │  │                  │  │                  │         │
│   │ Submit: NetDMR   │  │ Submit: Mail     │  │ Submit: Email    │         │
│   └────────┬─────────┘  └──────────────────┘  └──────────────────┘         │
│            │                                                                 │
│            ▼                                                                 │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │  REPORT SUBMISSION TRACKING                                          │  │
│   │                                                                      │  │
│   │  Period: November 2025  │  Due: Dec 28, 2025  │  Status: PENDING    │  │
│   │  Submitted: [Not yet]   │  Confirmation: [N/A]                      │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      DEVIATION TRACKING                                      │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │  EXCEEDANCE RECORDED                                                 │  │
│   │                                                                      │  │
│   │  Date: 2025-12-01 14:30        │  Limit: TSS Daily Max 30 mg/L      │  │
│   │  Duration: 1.5 hours           │  Actual: 45 mg/L (50% over)        │  │
│   │  Severity: Minor               │  Root Cause: Storm infiltration    │  │
│   │                                                                      │  │
│   │  Reporting Required: YES       │  Report Due: 2025-12-02            │  │
│   │  Agency Notified: YES          │  CAR Issued: CAR-2025-047          │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```


---

## How License & CE Tracking Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        LICENSE TYPES BY HOLDER                               │
│                                                                              │
│   ESTABLISHMENT              EMPLOYEE                  EQUIPMENT             │
│   ─────────────              ────────                  ─────────             │
│   Business License           PE License                Boiler Registration   │
│   Fire Permit                CIH Certification         Elevator Permit       │
│   Occupancy Certificate      Wastewater Operator       Pressure Vessel Reg   │
│   Zoning Variance            CDL + HazMat              UST/AST Registration  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EMPLOYEE LICENSE WITH CE TRACKING                         │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  John Smith - Wastewater Operator Class B                           │   │
│   │  License #: WW-12345-B                                              │   │
│   │  Issued: 2023-03-15  │  Expires: 2026-03-15  │  Status: ACTIVE      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  CE TRACKING (Period: 2023-03-15 to 2026-03-15)                     │   │
│   │                                                                     │   │
│   │  Required: 30 hours  │  Completed: 18 hours  │  Remaining: 12 hours│   │
│   │                                                                     │   │
│   │  Progress: ████████████░░░░░░░░  60%                               │   │
│   │  Status: ON TRACK (18 months remaining)                             │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  CE RECORDS                                                         │   │
│   │                                                                     │   │
│   │  Date       │ Activity                        │ Provider   │ Hours │   │
│   │  ──────────────────────────────────────────────────────────────────│   │
│   │  2023-06-15 │ Biosolids Management Update     │ State DEQ  │  4.0  │   │
│   │  2023-09-20 │ Lab Safety & QA/QC              │ WEF        │  6.0  │   │
│   │  2024-03-10 │ Nutrient Removal Technologies   │ State DEQ  │  4.0  │   │
│   │  2024-08-05 │ Annual Operator Conference      │ MWEA       │  4.0  │   │
│   │  ──────────────────────────────────────────────────────────────────│   │
│   │                                                  TOTAL:     18.0  │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Trigger: When CE record added → Auto-update ce_hours_completed on license │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Compliance Calendar Integration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      DECEMBER 2025 COMPLIANCE CALENDAR                       │
│                                                                              │
│   Date  │ Type          │ Description                      │ Status         │
│   ──────┼───────────────┼──────────────────────────────────┼─────────────── │
│   12/01 │ Inspection    │ SWPPP Weekly Inspection          │ ✓ Completed    │
│   12/05 │ Report        │ Tier II Annual Report            │ ⏳ In Progress │
│   12/15 │ Fee           │ Title V Annual Fee ($2,500)      │ ○ Pending      │
│   12/20 │ License       │ Boiler Registration Renewal      │ ○ Pending      │
│   12/28 │ Report        │ November DMR Submission          │ ○ Pending      │
│   12/31 │ Certification │ Annual Compliance Certification  │ ○ Pending      │
│                                                                              │
│   Sources feeding into calendar:                                            │
│   ├── Permit reporting requirements → Report due dates                      │
│   ├── Permit expiration dates → Renewal deadlines                          │
│   ├── License expiration dates → Renewal deadlines                         │
│   ├── Inspection schedules → Inspection due dates                          │
│   └── Manual entries → Ad-hoc obligations                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```


---

## Planned Extensions (Next Sessions)

### 006b_air_permits.sql - Air-Specific Reporting
Tables to support air permit compliance:

| Table | Purpose |
|-------|---------|
| `emission_units` | Equipment/processes that emit (boilers, paint booths, etc.) |
| `stacks` | Discharge points with parameters (height, diameter, temp) |
| `control_devices` | Pollution control equipment (scrubbers, baghouses, etc.) |
| `cems_data` | Continuous Emissions Monitoring System data |
| `stack_tests` | Stack test records and results |
| `emissions_inventory` | Annual emissions by pollutant |
| `excess_emissions` | Air deviation/excess emissions reports |

### 006c_water_permits.sql - Water-Specific Reporting  
Tables to support water permit compliance:

| Table | Purpose |
|-------|---------|
| `discharge_outfalls` | Discharge monitoring points |
| `dmr_data` | Discharge Monitoring Report data entry |
| `dmr_submissions` | DMR submission tracking (NetDMR integration) |
| `benchmark_monitoring` | Stormwater benchmark parameter tracking |
| `pretreatment_monitoring` | Industrial pretreatment sampling data |

---

## Regulatory Drivers

### Permits Module

| Regulation | Coverage |
|------------|----------|
| Clean Air Act Title V | Operating permit structure, compliance certification |
| Clean Air Act NSR/PSD | Construction permits, emission limits |
| Clean Water Act 402 | NPDES permits, DMR reporting |
| Clean Water Act 307 | Pretreatment permits |
| RCRA 3005 | Hazardous waste facility permits |
| EPCRA 312 | Tier II notifications |
| CAA 112(r) | Risk Management Plans |
| 40 CFR 112 | SPCC Plans |

### Licenses Module

| Authority | License Types |
|-----------|---------------|
| State Professional Boards | PE, operator licenses |
| Professional Organizations | CIH, CSP, CHMM certifications |
| Local Government | Business licenses, fire permits, occupancy |
| State Agencies | Boiler/pressure vessel, UST/AST registrations |
| Federal (TSA/DOT) | HazMat CDL endorsements |

---

## Files Created This Session

```
waypoint/
├── 001_incidents.sql           # OSHA incident tracking
├── 002_chemicals.sql           # Chemical/SDS management  
├── 002a_sara313.sql            # TRI + Regulatory requirements bridge
├── 003_training.sql            # Training module
├── 004_waste.sql               # Waste management (RCRA, universal, used oil)
├── 005_inspections_audits.sql  # Inspections, Audits & CARs
├── 006_permits.sql             # NEW - Permits (1,078 lines)
├── 006a_licenses.sql           # NEW - Licenses (661 lines)
├── docs/
│   ├── session_summary_001.md  # Initial session
│   ├── session_summary_002.md  # Training & Waste
│   ├── session_summary_003.md  # Inspections & Audits
│   └── session_summary_004.md  # This file - Permits & Licenses
└── identifier.sqlite           # SQLite database file
```

---

## Integration Points

| Module | Integration with Permits/Licenses |
|--------|-----------------------------------|
| **Chemicals (002)** | Permitted chemicals link to inventory; TRI chemicals have permit thresholds |
| **Training (003)** | Operator licenses may link to training requirements; CE activities may be training |
| **Waste (004)** | RCRA permits link to waste streams; generator status affects permit requirements |
| **Inspections (005)** | Permit inspections tracked; deviations can generate CARs |
| **Compliance Calendar** | All permit reports, license renewals feed into unified calendar |

---

## Next Steps

### Immediate (Session 005)
1. **006b - Air Reporting** - Air-specific tables
   - Emission units and control devices
   - Stack test tracking
   - Emissions inventory
   - Excess emissions reporting

2. **006c - Water Reporting** - Water-specific tables
   - Outfall definitions
   - DMR data entry
   - Benchmark monitoring

### Upcoming
3. **007 - PPE Tracking** - Assignment, inspection, replacement

### TUI Development
Once schemas complete:
- Permit dashboard with expiration alerts
- License renewal calendar
- DMR data entry screens
- Compliance calendar view
- Report generation

---

## Design Principles Applied

1. **Generic first, specific later** - Base permit structure works for all types before adding media-specific tables
2. **Separation of concerns** - Conditions (text) vs Limits (numeric) vs Monitoring (methods)
3. **Flexible holder types** - Single license table supports establishment, employee, and equipment
4. **Auto-calculation** - Triggers maintain CE totals automatically
5. **Calendar integration** - All obligations flow to unified compliance calendar
6. **Deviation tracking** - Root cause and reporting status for all permit exceedances
7. **Renewal alerting** - Views calculate days until expiration and renewal deadlines

---

*End of Session 004 Summary*
