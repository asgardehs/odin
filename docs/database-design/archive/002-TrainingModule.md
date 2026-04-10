# Waypoint-EHS Development Session Summary

**Date:** December 1, 2025  
**Session:** 002 - Training Module  
**Status:** In Progress

---

## Project Overview

**Waypoint-EHS** is an EHS (Environmental, Health & Safety) compliance database and TUI application designed for small manufacturing companies that cannot afford enterprise ERP modules.

### Technical Stack
- **Database:** SQLite (portable for small companies; migration path to SQL Server planned)
- **Language:** Go
- **TUI Framework:** Bubbles, BubbleTea, HUH, Lipgloss
- **Documentation:** Glow (with planned custom markdown creation capability)

### Target Users
- Small manufacturing facilities
- Job shops (e-coat, plating, machining)
- Companies with same regulatory burden as large enterprises but limited IT budget

---

## Modules Status

| Order | Module | Status | File(s) |
|-------|--------|--------|---------|
| 001 | Incidents | ✅ Complete | `001_incidents.sql` |
| 002 | Chemicals / SDS | ✅ Complete | `002_chemicals.sql` |
| 002a | SARA 313 / TRI | ✅ Complete | `002a_sara313.sql` |
| 002a | Regulatory Requirements | ✅ Complete | `002a_sara313.sql` |
| 003 | Training Records | ✅ Complete | `003_training.sql` |
| 004 | Waste Management | ✅ Complete | `004_waste.sql` |
| 005 | Inspections & Audits | 🔲 Next | - |
| 006 | Permits & Licenses | 🔲 Planned | - |
| 007 | PPE Tracking | 🔲 Planned | - |

---

## Session 002: Training Module

### Design Decisions

**1. Course-Requirement Relationship (Many-to-Many)**
- One course can satisfy multiple regulatory requirements
- Example: "Annual Safety Refresher" might cover HazCom, PPE, and Fire Extinguisher training
- Implemented via `course_requirements` junction table

**2. Training Requirement Determination (Three Paths)**
Requirements flow to employees through multiple triggers:
1. **All-employee triggers** - Emergency procedures apply to everyone
2. **Activity/Role-based triggers** - Forklift operators need forklift training, LOTO authorized employees need LOTO training
3. **Work area hazard exposure** - Employees in areas with flammable chemicals need HazCom and fire safety training

Plus **direct assignment** for exceptions (new hires, remedial training, special circumstances).

**3. Track Completions with Scores (Not Attempts)**
- Only successful completions are recorded
- Scores captured where applicable
- Expiration dates auto-calculated from course validity period

### Tables Created

| Table | Purpose |
|-------|---------|
| `training_courses` | Course definitions with validity periods, delivery methods, passing scores |
| `course_requirements` | Many-to-many link between courses and regulatory requirements |
| `training_completions` | Employee completion records with dates, scores, instructors |
| `training_assignments` | Direct/manual training assignments with due dates and status |
| `employee_activities` | Activity codes assigned to employees (FORKLIFT_OP, LOTO_AUTH, etc.) |
| `work_areas` | Hazard profiles for work areas/departments |
| `employee_work_areas` | Links employees to their assigned work areas |
| `activity_codes` | Reference table of activity codes with descriptions |

### Views Created

| View | Purpose |
|------|---------|
| `v_employee_required_requirements` | What regulatory requirements apply to each employee (foundation view) |
| `v_employee_required_courses` | What courses satisfy those requirements |
| `v_employee_current_training` | Most recent completion status per employee/course |
| `v_employee_training_status` | Full status combining required vs completed |
| `v_training_gap_analysis` | Missing/expired training only - action items for compliance |
| `v_training_summary_by_employee` | Compliance counts and percentages per employee |
| `v_training_summary_by_course` | Compliance counts per course |
| `v_training_compliance_summary` | Overall establishment compliance metrics |
| `v_training_expiring` | Training expiring in next 90 days |
| `v_pending_training_assignments` | Active direct assignments awaiting completion |

### Pre-seeded Data

**Activity Codes (16 common activities):**
- FORKLIFT_OP, LOTO_AUTH, LOTO_AFF, HAZMAT_HANDLER
- FIRST_AID, CONFINED_ENTRY, CONFINED_RESCUE, HOT_WORK
- CRANE_OP, AERIAL_LIFT, ELECTRICAL_QUAL, RESPIRATOR_USER
- FALL_PROTECT, SPILL_RESPONSE, HAZWOPER_OP, FIRE_BRIGADE

**Sample Courses (13 courses mapped to regulatory requirements):**
- SAF-100: New Employee Safety Orientation
- SAF-101: Hazard Communication (HazCom)
- SAF-102: Respiratory Protection
- SAF-103: Personal Protective Equipment (PPE)
- SAF-104: Lockout/Tagout - Authorized Employee
- SAF-105: Lockout/Tagout - Affected Employee
- SAF-106: Emergency Action Plan
- SAF-107: Portable Fire Extinguisher Use
- SAF-108: First Aid and CPR
- OPS-101: Powered Industrial Truck (Forklift) Operator
- DOT-101: HazMat General Awareness
- DOT-102: HazMat Function-Specific
- DOT-103: HazMat Security Awareness

### Triggers

| Trigger | Purpose |
|---------|---------|
| `trg_training_completion_expiration` | Auto-calculates expiration_date based on course validity_months |
| `trg_training_completion_assignment` | Auto-updates assignment status to 'completed' when completion recorded |

---

## How Training Requirements Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        REQUIREMENT TRIGGERS                                  │
│  (From 002a_sara313.sql regulatory_requirements & requirement_triggers)     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                          │
         ▼                          ▼                          ▼
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│  ALL_EMPLOYEES  │      │    ACTIVITY     │      │ CHEMICAL_HAZARD │
│                 │      │                 │      │                 │
│ EAP Training    │      │ Forklift Ops    │      │ is_flammable    │
│ (everyone)      │      │ LOTO Auth       │      │ is_acute_toxic  │
│                 │      │ HazMat Handler  │      │ signal_word     │
└────────┬────────┘      └────────┬────────┘      └────────┬────────┘
         │                        │                        │
         │               ┌────────┴────────┐               │
         │               │                 │               │
         │               ▼                 ▼               ▼
         │      ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
         │      │  EMPLOYEE   │   │  JOB_TITLE  │   │ WORK_AREAS  │
         │      │ ACTIVITIES  │   │  (employees │   │  (hazard    │
         │      │  (explicit) │   │   table)    │   │   flags)    │
         │      └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
         │             │                 │                 │
         │             │                 │                 ▼
         │             │                 │         ┌─────────────┐
         │             │                 │         │ EMPLOYEE    │
         │             │                 │         │ WORK_AREAS  │
         │             │                 │         │ (junction)  │
         │             │                 │         └──────┬──────┘
         │             │                 │                │
         └─────────────┴─────────────────┴────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │ v_employee_required_requirements │
                    │   (aggregates all triggers)     │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │   v_employee_required_courses   │
                    │   (maps to actual courses)      │
                    └───────────────┬───────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
         ┌─────────────────┐            ┌─────────────────┐
         │    TRAINING     │            │   v_employee_   │
         │   COMPLETIONS   │───────────▶│ training_status │
         │ (what's done)   │            │ (required vs    │
         │                 │            │  completed)     │
         └─────────────────┘            └────────┬────────┘
                                                 │
                                                 ▼
                                    ┌─────────────────────┐
                                    │ v_training_gap_     │
                                    │ analysis            │
                                    │ (what's missing)    │
                                    └─────────────────────┘
```

---

## Session 002 Part 2: Waste Management Module

### Design Decisions

**1. Container-Centric Tracking**
The heart of RCRA compliance is knowing when each container's accumulation clock started. The schema tracks individual containers with their start dates and auto-calculates must_ship_by dates based on accumulation area type.

**2. Generator Status Determination**
Generator status (VSQG/SQG/LQG) drives most other requirements. The system tracks monthly generation quantities and determines effective status based on the highest status in the last 12 months (per EPA episodic generation rules).

**3. Satellite vs Central Accumulation**
Different rules apply:
- **SAA**: 55-gallon limit, no time limit, at point of generation
- **CAA**: No volume limit, but 90/180/270 day time limit based on generator status

**4. Manifest Lifecycle Tracking**
Manifests track from draft → signed → in_transit → delivered → complete, with specific alerts for exception reports if signed copies aren't returned within 35 days (LQG) or 60 days (SQG).

### Tables Created

| Table | Purpose |
|-------|---------|
| `waste_codes` | EPA hazardous waste codes (D, F, K, P, U lists) with 35 common codes pre-seeded |
| `waste_streams` | Recurring waste types with characterization and handling info |
| `waste_stream_codes` | Junction linking waste streams to applicable EPA codes |
| `waste_containers` | Individual containers with accumulation start dates and deadlines |
| `accumulation_areas` | SAA and CAA definitions with inspection schedules |
| `waste_facilities` | TSDFs, recyclers, used oil processors |
| `waste_manifests` | Uniform Hazardous Waste Manifest tracking |
| `manifest_items` | Line items on each manifest |
| `ldr_notifications` | Land Disposal Restriction notices to TSDFs |
| `generator_status_monthly` | Monthly generation tracking for status determination |
| `waste_inspections` | Accumulation area inspection records |
| `universal_waste` | Batteries, lamps, aerosols with 1-year limit tracking |
| `used_oil_containers` | Used oil tank/drum tracking with specification testing |
| `used_oil_shipments` | Used oil pickup records |

### Views Created

| View | Purpose |
|------|---------|
| `v_generator_status_current` | Determines effective generator status (VSQG/SQG/LQG) |
| `v_containers_approaching_deadline` | Containers needing shipment soon (90/180/270 day limits) |
| `v_saa_volume_status` | Satellite areas approaching 55-gallon limit |
| `v_manifests_pending_return` | Manifests awaiting TSDF confirmation (exception report tracking) |
| `v_inspections_due` | Accumulation areas needing inspection |
| `v_universal_waste_approaching_deadline` | Universal waste approaching 1-year limit |
| `v_waste_stream_summary` | Summary by waste stream with annual quantities |
| `v_waste_compliance_dashboard` | Overall compliance health check for establishment |

### Triggers

| Trigger | Purpose |
|---------|---------|
| `trg_container_ship_date` | Auto-calculate must_ship_by_date based on area type |
| `trg_universal_waste_ship_date` | Auto-calculate 1-year deadline for universal waste |
| `trg_container_manifest_status` | Update container status when added to manifest |
| `trg_inspection_update_area` | Update area's last_inspection_date when inspection recorded |

### Pre-seeded Waste Codes (35 Common Manufacturing Codes)

**Characteristic Wastes (D-codes):**
D001-D003 (ignitable, corrosive, reactive), D004-D011 (metals), D018-D040 (organics)

**Listed Wastes (F-codes - Non-Specific Sources):**
- F001-F005: Spent solvents (halogenated and non-halogenated)
- F006-F012: Electroplating and metal heat treating wastes
- F019: Aluminum conversion coating sludge

**Listed Wastes (K-codes - Source-Specific):**
- K001: Wood preserving (creosote)
- K062: Steel finishing pickle liquor

---

## How Waste Compliance Flows

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WASTE STREAM DEFINITION                              │
│   (Define recurring waste types, assign EPA codes, set handling procedures) │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ACCUMULATION AREAS                                    │
│          SAA (55 gal limit)          │        CAA (time limit)              │
│     ┌────────────────────┐           │     ┌────────────────────┐          │
│     │ Point of generation│           │     │ Central storage    │          │
│     │ No time limit      │──────────▶│     │ 90/180/270 days    │          │
│     │ Weekly inspection  │  When full│     │ Weekly inspection  │          │
│     └────────────────────┘           │     └────────────────────┘          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WASTE CONTAINERS                                     │
│                                                                              │
│   ┌────────────────────────────────────────────────────────────────────┐   │
│   │ Container #: WC-001        │ Status: OPEN                          │   │
│   │ Stream: Spent Solvent      │ Codes: F001, D001                     │   │
│   │ Accum Start: 2025-10-01    │ Must Ship By: 2025-12-30 (90 days)   │   │
│   │ Location: CAA-1            │ Quantity: 45 gallons                  │   │
│   └────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   v_containers_approaching_deadline: Alerts at 30/14/7 days and OVERDUE    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            MANIFEST                                          │
│                                                                              │
│   Generator ──▶ Transporter ──▶ TSDF                                        │
│                                                                              │
│   ┌──────────────────────────────────────────────────────┐                  │
│   │ Tracking #: 012345678JJK                             │                  │
│   │ Ship Date: 2025-12-28                                │                  │
│   │ TSDF: Clean Harbors                                  │                  │
│   │ Status: IN_TRANSIT                                   │                  │
│   │ Copy 3 Due: 2026-02-01 (35 days for LQG)            │                  │
│   └──────────────────────────────────────────────────────┘                  │
│                                                                              │
│   v_manifests_pending_return: Tracks copy returns, exception report needs   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      GENERATOR STATUS TRACKING                               │
│                                                                              │
│   Monthly totals ──▶ Determine Status ──▶ Set Requirements                  │
│                                                                              │
│   VSQG (<100 kg/mo)  │  SQG (100-1000 kg/mo)  │  LQG (>1000 kg/mo)         │
│   - No time limit    │  - 180/270 day limit   │  - 90 day limit            │
│   - Limited training │  - Basic training      │  - Full training           │
│   - No contingency   │  - Basic contingency   │  - Full contingency plan   │
│   - No biennial rpt  │  - No biennial rpt     │  - Biennial report         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Files Created This Session

```
waypoint/
├── 001_incidents.sql        # OSHA incident tracking
├── 002_chemicals.sql        # Chemical/SDS management
├── 002a_sara313.sql         # TRI + Regulatory requirements bridge
├── 003_training.sql         # Training module (NEW - 1116 lines)
├── docs/
│   └── session_summary_002.md  # This file
└── identifier.sqlite        # SQLite database file
```

---

## Next Steps

### Immediate (Session 003)
1. **004 - Waste Management** - RCRA tracking, manifests, waste codes
   - Generator status determination
   - Waste accumulation time tracking
   - Manifest records
   - LDR notifications

### Upcoming
2. **005 - Inspections & Audits** - Scheduled inspections, findings, follow-up
3. **006 - Permits & Licenses** - Permit tracking with renewal alerts
4. **007 - PPE Tracking** - Assignment, inspection, replacement

### v2 Training Enhancements
Future investigation needed for:
- **Custom training courses** - Allow end users to create their own courses beyond the pre-seeded regulatory ones
- **Trainer tracking** - Track who is qualified to deliver each course
- **Train-the-trainer management** - Track trainer certifications and when refreshers are due (trainers often need to recertify more frequently than the training they deliver)

### TUI Development
Once schemas are complete, begin Go/BubbleTea implementation:
- Main menu navigation
- Chemical inventory entry
- Training record management
- Gap analysis dashboards
- Report generation

---

*End of Session 002 Summary*
