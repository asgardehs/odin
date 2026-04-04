# Waypoint-EHS Development Session Summary

**Date:** December 1, 2025  
**Session:** 003 - Inspections, Audits & Corrective Actions  
**Status:** Complete

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
| 003 | Training Records | ✅ Complete | `003_training.sql` |
| 004 | Waste Management | ✅ Complete | `004_waste.sql` |
| 005 | Inspections & Audits | ✅ Complete | `005_inspections_audits.sql` |
| 006 | Permits & Licenses | 🔲 Next | - |
| 007 | PPE Tracking | 🔲 Planned | - |

---

## Session 003: Inspections, Audits & Corrective Actions

### Design Decisions

**1. Clause-Level Tracking for ISO Audits**
Audit findings are linked to specific ISO clause numbers (e.g., "ISO 14001:2015 clause 6.1.2 - Environmental aspects"). This enables:
- Trending which clauses generate the most findings
- Identifying weak areas in the management system
- Preparing for surveillance audits by reviewing past findings by clause
- Internal auditor assignment by competency area

**2. Pre-Seeded Checklists with Customization (Option C)**
Inspection checklists come pre-populated with common items but allow site-specific additions:
- SWPPP: 20 items covering BMPs, outfalls, site conditions
- SPCC: 15 items covering containers, containment, spill prevention
- Safety inspections: Fire extinguishers, eyewash stations, general walkthroughs
- Users can add items specific to their facility's SWPPP, SPCC plan, or operations

**3. Year-Based CAR Numbering**
CARs use the format `CAR-2025-001`, `CAR-2025-002`:
- Easy to see age at a glance
- Simple to timeline recurring issues
- Auto-generated via trigger
- Sequence resets each year per establishment

**4. Root Cause Category Tracking**
Root cause analysis includes standardized categories for trending:
- Training, Procedure, Equipment, Communication
- Resource, Management, Design, Human Error
- Enables identification of systemic issues across multiple CARs

**5. Effectiveness Verification**
Every CAR includes a verification step to confirm corrective actions actually worked:
- Verification criteria defined at CAR creation
- Scheduled verification date (typically 30-90 days after closure)
- If ineffective, links to follow-up CAR


### Tables Created

#### Reference Tables

| Table | Purpose |
|-------|---------|
| `iso_standards` | The three management system standards (14001, 45001, 50001) |
| `iso_clauses` | Clause structure for each standard with 150+ clauses pre-seeded |
| `inspection_types` | Types of inspections (SWPPP, SPCC, safety, equipment, waste) |
| `inspection_checklist_templates` | Pre-seeded checklist items by inspection type |

#### Facility-Specific Tables

| Table | Purpose |
|-------|---------|
| `swppp_outfalls` | Stormwater discharge outfall definitions per SWPPP |
| `spcc_containers` | Oil storage containers covered under SPCC plan |

#### Inspection Tables

| Table | Purpose |
|-------|---------|
| `inspections` | Master inspection record with date, inspector, scope, results |
| `inspection_checklist_responses` | Completed checklist items for each inspection |
| `inspection_findings` | Issues discovered during inspections |
| `inspection_schedule` | Recurring inspection schedules with auto-calculated next due dates |

#### Audit Tables

| Table | Purpose |
|-------|---------|
| `audits` | Master audit record (internal/external, ISO standard, registrar info) |
| `audit_team` | Audit team members, roles, assigned scope |
| `audit_scope` | Detailed scope breakdown by process, department, or clause |
| `audit_findings` | Findings with clause-level tracking, repeat finding identification |

#### Corrective Action Tables

| Table | Purpose |
|-------|---------|
| `corrective_actions` | Main CAR record with year-based numbering, source linking |
| `car_root_cause` | Root cause analysis (5-Why structure, category tracking) |
| `car_actions` | Individual action items within a CAR |
| `car_verification` | Effectiveness verification tracking |

### Views Created

#### Compliance Monitoring

| View | Purpose |
|------|---------|
| `v_inspections_due` | Upcoming and overdue inspections based on schedule |
| `v_inspection_compliance_summary` | Overall inspection status by establishment |

#### CAR Management

| View | Purpose |
|------|---------|
| `v_open_cars` | All open CARs with aging, urgency indicators |
| `v_car_summary_by_year` | Annual CAR statistics and trends |
| `v_car_actions_overdue` | Past-due action items |
| `v_verification_due` | Effectiveness verifications coming due |

#### Trending & Analysis

| View | Purpose |
|------|---------|
| `v_car_root_cause_trending` | Root cause categories over time (systemic issues) |
| `v_audit_findings_by_clause` | Findings by ISO clause (weak area identification) |
| `v_audit_status_summary` | Audit and CAR status overview by establishment |

### Triggers Created

| Trigger | Purpose |
|---------|---------|
| `trg_car_number_generate` | Auto-format CAR number as CAR-YYYY-NNN |
| `trg_inspection_update_schedule` | Update schedule's last/next dates after inspection |
| `trg_audit_finding_count_insert` | Keep audit finding counts current on insert |
| `trg_audit_finding_count_delete` | Keep audit finding counts current on delete |
| `trg_car_link_audit_finding` | Link CAR to source audit finding, update finding status |
| `trg_car_link_inspection_finding` | Link CAR to source inspection finding, update finding status |
| `trg_car_action_complete_check` | Move CAR to pending_verification when all actions complete |


### Pre-Seeded Data

#### ISO Clauses (155 clauses total)

**ISO 14001:2015 - Environmental Management (50 clauses)**
- Clause 4: Context of the organization
- Clause 5: Leadership
- Clause 6: Planning (including 6.1.2 Environmental aspects, 6.1.3 Compliance obligations)
- Clause 7: Support (competence, awareness, communication, documented information)
- Clause 8: Operation (operational control, emergency preparedness)
- Clause 9: Performance evaluation (monitoring, compliance evaluation, internal audit, management review)
- Clause 10: Improvement (nonconformity, corrective action, continual improvement)

**ISO 45001:2018 - Occupational Health & Safety (60 clauses)**
- Clause 4: Context (including worker consultation)
- Clause 5: Leadership and worker participation
- Clause 6: Planning (hazard identification, risk assessment, legal requirements)
- Clause 7: Support
- Clause 8: Operation (hierarchy of controls, MOC, contractor management, emergency)
- Clause 9: Performance evaluation
- Clause 10: Improvement (incident investigation, corrective action)

**ISO 50001:2018 - Energy Management (45 clauses)**
- Clause 4: Context
- Clause 5: Leadership
- Clause 6: Planning (energy review, EnPIs, baseline, data collection)
- Clause 7: Support
- Clause 8: Operation (design, procurement)
- Clause 9: Performance evaluation
- Clause 10: Improvement

#### Inspection Types (14 types)

**Environmental Inspections:**
- SWPPP - Weekly stormwater inspections
- SPCC - Monthly oil storage inspections
- SWPPP_STORM - Post-storm event inspections (within 24 hours of ≥0.25" rain)

**Safety Inspections:**
- SAFETY_WALK - General workplace safety walkthrough
- FIRE_EXT - Monthly fire extinguisher visual inspection
- EYEWASH - Weekly eyewash/safety shower activation test
- EMERG_LIGHT - Monthly emergency lighting test
- EXIT_SIGN - Monthly exit sign inspection
- FIRST_AID - Monthly first aid kit inspection

**Equipment Inspections:**
- FORKLIFT_PRE - Daily pre-shift forklift inspection
- CRANE - Monthly crane/hoist inspection
- LADDER - Quarterly ladder inspection

**Waste Inspections:**
- HAZWASTE_WEEKLY - Weekly hazardous waste area inspection
- USED_OIL - Monthly used oil container inspection

#### Checklist Templates (50+ items)

**SWPPP Checklist (20 items):**
- Site conditions: spills, debris, material storage, illicit discharges
- Structural BMPs: catch basins, sediment traps, oil/water separators, detention ponds
- Non-structural BMPs: housekeeping, spill kits, secondary containment, maintenance areas
- Outfall inspection: structure condition, discharge quality, receiving water

**SPCC Checklist (15 items):**
- Container integrity: leaks, corrosion, supports, valves
- Secondary containment: integrity, capacity, drain valves
- Spill prevention: kits, overfill protection, transfer procedures
- Documentation: plan availability, training, emergency contacts

**Fire Extinguisher Checklist (7 items):**
- Location, access, instructions, seal, pressure, condition, tag

**Eyewash/Safety Shower Checklist (7 items):**
- Signage, access, water flow, temperature, covers, leaks, documentation

**General Safety Walkthrough (10 items):**
- Walking surfaces, exits, electrical, machine guards, PPE, HazCom, compressed gas


---

## How CAR Tracking Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CAR SOURCES                                        │
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │    AUDIT     │  │  INSPECTION  │  │   INCIDENT   │  │    OTHER     │    │
│  │   FINDING    │  │   FINDING    │  │              │  │  (complaint, │    │
│  │              │  │              │  │              │  │   mgmt rev)  │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
│         │                 │                 │                 │             │
│         └─────────────────┴─────────────────┴─────────────────┘             │
│                                    │                                         │
│                                    ▼                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CAR CREATION                                          │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  CAR-2025-001                                                       │   │
│   │  Source: ISO 14001 Audit Finding                                    │   │
│   │  Clause: 6.1.2 - Environmental aspects                              │   │
│   │  Severity: Major                                                    │   │
│   │  Description: Aspect register not updated for new plating line      │   │
│   │  Due Date: 2025-02-01                                               │   │
│   │  Responsible: EHS Manager                                           │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      ROOT CAUSE ANALYSIS                                     │
│                                                                              │
│   Why 1: Aspect register not updated                                        │
│   Why 2: No trigger to review when new equipment added                      │
│   Why 3: MOC procedure doesn't include EMS review step                      │
│   Why 4: Procedure written before EMS implemented                           │
│   Why 5: (root) No systematic review of legacy procedures for EMS alignment │
│                                                                              │
│   Category: PROCEDURE                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CAR ACTIONS                                           │
│                                                                              │
│   Action 1: Update aspect register for plating line (CONTAINMENT)           │
│             Due: 2025-01-10  │  Responsible: Env Coordinator                │
│                                                                              │
│   Action 2: Revise MOC procedure to include EMS review (CORRECTIVE)         │
│             Due: 2025-01-20  │  Responsible: EHS Manager                    │
│                                                                              │
│   Action 3: Review all MOC-related procedures for EMS gaps (PREVENTIVE)     │
│             Due: 2025-01-31  │  Responsible: Quality Manager                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EFFECTIVENESS VERIFICATION                                │
│                                                                              │
│   Verification Due: 2025-04-01 (90 days after closure)                      │
│   Method: Review next 3 MOC requests to confirm EMS step completed          │
│   Criteria: 100% of MOC requests include documented EMS review              │
│                                                                              │
│   ┌─────────────────────┐              ┌─────────────────────┐              │
│   │     EFFECTIVE       │              │   NOT EFFECTIVE     │              │
│   │                     │              │                     │              │
│   │  CAR Closed         │              │  New CAR Issued     │              │
│   │  Status: closed     │              │  Links to original  │              │
│   └─────────────────────┘              └─────────────────────┘              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```


---

## How Inspection Tracking Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      INSPECTION SCHEDULE                                     │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  Schedule: SWPPP Weekly Inspection                                  │   │
│   │  Frequency: Weekly (every Monday)                                   │   │
│   │  Default Inspector: Environmental Coordinator                       │   │
│   │  Last Inspection: 2025-11-25                                        │   │
│   │  Next Due: 2025-12-02                                               │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CREATE INSPECTION                                       │
│                                                                              │
│   1. New inspection record created                                          │
│   2. Checklist items copied from template                                   │
│   3. Inspector records responses for each item                              │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  SWPPP Inspection - December 2, 2025                                │   │
│   │                                                                     │   │
│   │  Site Conditions:                                                   │   │
│   │  [✓] Evidence of spills or leaks on paved areas............... NO  │   │
│   │  [✓] Waste and debris properly contained...................... YES │   │
│   │  [✗] Outdoor material storage covered ← FINDING............... NO  │   │
│   │                                                                     │   │
│   │  Structural BMPs:                                                   │   │
│   │  [✓] Catch basin inserts functional........................... YES │   │
│   │  [✓] Oil/water separator functioning.......................... YES │   │
│   │                                                                     │   │
│   │  Overall Result: PASS WITH FINDINGS                                 │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
              ┌──────────────────────┴──────────────────────┐
              │                                             │
              ▼                                             ▼
┌─────────────────────────────┐              ┌─────────────────────────────┐
│     FINDING CREATED         │              │   SCHEDULE UPDATED          │
│                             │              │                             │
│  Finding: Materials stored  │              │   Last Inspection: 12/02    │
│  outside without cover      │              │   Next Due: 12/09           │
│  Severity: Minor            │              │   (auto-calculated)         │
│  Immediate Action: Tarps    │              │                             │
│  placed over materials      │              │                             │
│                             │              │                             │
│  Requires CAR? [YES]        │              │                             │
│         │                   │              │                             │
│         ▼                   │              │                             │
│  CAR-2025-042 Issued        │              │                             │
└─────────────────────────────┘              └─────────────────────────────┘
```

---

## Clause-Level Trending for Management System Improvement

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    v_audit_findings_by_clause                                │
│                                                                              │
│  ISO 14001 Findings by Clause (2023-2025)                                   │
│  ────────────────────────────────────────────────────────────────────────── │
│                                                                              │
│  Clause        │ Title                      │ Major │ Minor │ OFI │ Total  │
│  ──────────────┼────────────────────────────┼───────┼───────┼─────┼─────── │
│  6.1.2         │ Environmental aspects      │   2   │   3   │  1  │   6    │ ◄─ WEAK
│  7.2           │ Competence                 │   1   │   2   │  2  │   5    │ ◄─ WEAK
│  8.1           │ Operational control        │   0   │   3   │  1  │   4    │
│  9.1.2         │ Compliance evaluation      │   1   │   1   │  1  │   3    │
│  10.2          │ Corrective action          │   0   │   2   │  0  │   2    │
│  7.5           │ Documented information     │   0   │   1   │  1  │   2    │
│  ──────────────┴────────────────────────────┴───────┴───────┴─────┴─────── │
│                                                                              │
│  INSIGHT: Clauses 6.1.2 and 7.2 consistently generate findings.            │
│  RECOMMENDATION: Focus internal audits and improvement efforts here.        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    v_car_root_cause_trending                                 │
│                                                                              │
│  Root Cause Categories (2025)                                               │
│  ────────────────────────────────────────────────────────────────────────── │
│                                                                              │
│  Category       │ Count │ CARs                                              │
│  ───────────────┼───────┼────────────────────────────────────────────────── │
│  PROCEDURE      │   8   │ CAR-2025-003, 007, 012, 018, 022, 028, 031, 039  │ ◄─ SYSTEMIC
│  TRAINING       │   5   │ CAR-2025-005, 011, 019, 025, 037                  │
│  COMMUNICATION  │   4   │ CAR-2025-008, 015, 029, 041                       │
│  EQUIPMENT      │   2   │ CAR-2025-021, 034                                 │
│  ───────────────┴───────┴────────────────────────────────────────────────── │
│                                                                              │
│  INSIGHT: Procedure-related issues are the dominant root cause.             │
│  RECOMMENDATION: Launch procedure review/improvement initiative.            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```


---

## Regulatory Drivers

| Regulation/Standard | Coverage in Module |
|--------------------|--------------------|
| **EPA SWPPP (NPDES CGP)** | Inspection type, checklist, outfall tracking, storm event inspections |
| **EPA SPCC (40 CFR 112)** | Inspection type, checklist, container tracking, secondary containment |
| **ISO 14001:2015** | Full clause structure, audit tracking, finding categorization |
| **ISO 45001:2018** | Full clause structure, audit tracking, incident linkage |
| **ISO 50001:2018** | Full clause structure, energy-specific clauses |
| **OSHA 29 CFR 1910.157** | Fire extinguisher inspection checklist |
| **ANSI Z358.1** | Eyewash/safety shower inspection checklist |
| **OSHA 29 CFR 1910.178** | Forklift pre-shift inspection type |
| **40 CFR 265.174** | Hazardous waste weekly inspection linkage |

---

## Files Created/Modified This Session

```
waypoint/
├── 001_incidents.sql           # OSHA incident tracking
├── 002_chemicals.sql           # Chemical/SDS management  
├── 002a_sara313.sql            # TRI + Regulatory requirements bridge
├── 003_training.sql            # Training module
├── 004_waste.sql               # Waste management (RCRA, universal, used oil)
├── 005_inspections_audits.sql  # NEW - Inspections, Audits & CARs (1,929 lines)
├── docs/
│   ├── session_summary_001.md  # Initial session documentation
│   ├── session_summary_002.md  # Training & Waste sessions
│   └── session_summary_003.md  # This file - Inspections & Audits
└── identifier.sqlite           # SQLite database file
```

---

## Key Integration Points

The Inspections & Audits module connects to all other modules:

| Module | Integration |
|--------|-------------|
| **Incidents (001)** | CARs can be sourced from incidents; incident investigations may trigger CARs |
| **Chemicals (002)** | SPCC containers link to chemical inventory; inspections verify HazCom compliance |
| **Training (003)** | Audit findings on competence (7.2) link to training gaps; CAR root cause "training" |
| **Waste (004)** | Hazardous waste inspection types; waste area inspections feed into this module |

---

## Next Steps

### Immediate (Session 004)
1. **006 - Permits & Licenses** - Permit tracking with renewal alerts
   - Air permits, water permits, waste permits
   - Operating licenses
   - Renewal tracking and notifications
   - Compliance calendar

### Upcoming
2. **007 - PPE Tracking** - Assignment, inspection, replacement
   - PPE types and requirements
   - Employee assignments
   - Inspection records
   - Replacement tracking

### TUI Development
Once schemas are complete, begin Go/BubbleTea implementation:
- Main menu navigation
- Chemical inventory entry
- Training record management
- Inspection checklists (mobile-friendly)
- CAR workflow screens
- Dashboard views for compliance status
- Report generation

---

## v2 Enhancements

### Cross-Standard Audit Mapping (Integrated Management Systems)
Many companies operate integrated management systems (IMS) combining ISO 14001, 45001, and 50001. A future enhancement would add cross-standard clause mapping to support:

- **Common clause identification** - Map equivalent clauses across standards (e.g., 7.5 Documented Information exists in all three)
- **Single audit, multiple standards** - One finding could reference clauses from multiple standards simultaneously
- **Gap analysis** - Identify where one standard's requirements differ from another
- **Efficiency reporting** - Show auditors which areas can be covered once for all standards vs. standard-specific requirements

Example mapping:
| Topic | ISO 14001 | ISO 45001 | ISO 50001 |
|-------|-----------|-----------|-----------|
| Context | 4.1 | 4.1 | 4.1 |
| Interested Parties | 4.2 | 4.2 | 4.2 |
| Competence | 7.2 | 7.2 | 7.2 |
| Documented Information | 7.5 | 7.5 | 7.5 |
| Internal Audit | 9.2 | 9.2 | 9.2 |
| Management Review | 9.3 | 9.3 | 9.3 |
| Nonconformity & CA | 10.2 | 10.2 | 10.1 |

This would require a new `iso_clause_mapping` table linking equivalent clauses across standards.

---

## Design Principles Applied

1. **Year-based CAR numbering** - Immediate age visibility, easy pattern identification
2. **Clause-level audit tracking** - Pinpoint management system weaknesses
3. **Pre-seeded with customization** - Useful out of box, adaptable to site specifics
4. **Root cause categories** - Enable systemic issue identification
5. **Effectiveness verification** - Close the loop on corrective actions
6. **View-based reporting** - Complex queries encapsulated for easy consumption
7. **Trigger-automated housekeeping** - Reduce manual data maintenance

---

*End of Session 003 Summary*
