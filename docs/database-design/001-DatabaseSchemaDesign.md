# Waypoint-EHS Development Session Summary

**Date:** November 30, 2025  
**Session:** 001 - Database Schema Design  
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

## Modules Planned (v1)

| Order | Module | Status | File(s) |
|-------|--------|--------|---------|
| 001 | Incidents | ✅ Complete | `001_incidents.sql` |
| 002 | Chemicals / SDS | ✅ Complete | `002_chemicals.sql` |
| 002a | SARA 313 / TRI | ✅ Complete | `002a_sara313.sql` |
| 002a | Regulatory Requirements | ✅ Complete | `002a_sara313.sql` |
| 003 | Training Records | 🔲 Next | - |
| 004 | Waste Management | 🔲 Planned | - |
| 005 | Inspections & Audits | 🔲 Planned | - |
| 006 | Permits & Licenses | 🔲 Planned | - |
| 007 | PPE Tracking | 🔲 Planned | - |

**Deferred to v2:** Equipment/Maintenance

---

## Completed Schema Details


### 001 - Incidents (`001_incidents.sql`)

**Regulatory Drivers:** OSHA 300, 300A, 301

**Tables:**
| Table | Purpose |
|-------|---------|
| `establishments` | Company/site information (OSHA tracks by physical location) |
| `employees` | Employee records with OSHA-required fields |
| `incidents` | Core incident record - captures OSHA requirements plus safety management data |
| `corrective_actions` | Actions taken to prevent recurrence |
| `injury_illness_types` | OSHA standard codes for injury/illness classification |
| `body_parts` | OSHA BLS body part codes |
| `osha_300a_summaries` | Stored annual summary calculations |
| `audit_log` | Change tracking for compliance |
| `settings` | Application configuration |

**Key Design Decisions:**
- `is_recordable` flag separates OSHA-reportable from internal-only incidents
- `is_privacy_case` supports OSHA name-hiding for sensitive injuries
- Corrective actions include verification loop (assigned → completed → verified)
- Audit log captures all changes for regulatory defense

---

### 002 - Chemicals / SDS (`002_chemicals.sql`)

**Regulatory Drivers:** OSHA HazCom, EPA Tier II (EPCRA 311/312), SARA 313

**Tables:**
| Table | Purpose |
|-------|---------|
| `storage_locations` | Physical locations with Tier II storage conditions |
| `chemicals` | Master chemical record with GHS flags and regulatory markers |
| `chemical_components` | Mixture ingredients (SDS Section 3) |
| `sds_documents` | SDS tracking with revision history and review scheduling |
| `chemical_inventory` | Point-in-time snapshots (primary tracking method) |
| `chemical_transactions` | Optional detailed transaction log |
| `ghs_hazard_statements` | Reference: H and P statements |
| `ghs_pictograms` | Reference: 9 GHS symbols |
| `chemical_hazard_statements` | Links chemicals to H/P statements |
| `chemical_pictograms` | Links chemicals to pictograms |
| `tier2_reports` | Annual Tier II submission records |
| `tier2_report_chemicals` | Chemical details for each Tier II report |
| `unit_conversions` | Reference for converting to pounds |

**Key Design Decisions:**
- GHS hazard classes stored as boolean flags (not junction table) for easy Tier II checkbox queries
- Dual inventory approach: snapshots (required) + transactions (optional)
- SDS revision tracking with `superseded_by_id` linking old → new versions
- `quantity_lbs` stored alongside native units for Tier II calculations

**Views:**
| View | Purpose |
|------|---------|
| `v_current_inventory` | Most recent snapshot per chemical/location |
| `v_tier2_reportable` | Chemicals above Tier II threshold |
| `v_sds_review_status` | SDS review due dates and overdue items |

---


### 002a - SARA 313 / TRI (`002a_sara313.sql`)

**Regulatory Drivers:** EPCRA Section 313, Form R, Form A

**Tables:**
| Table | Purpose |
|-------|---------|
| `sara313_chemicals` | Reference: TRI-listed chemicals with thresholds |
| `tri_annual_activity` | Tracks manufactured/processed/otherwise-used quantities |
| `tri_releases_transfers` | Release destinations (air, water, land, off-site) |
| `tri_offsite_facilities` | Receiving facilities (recyclers, TSDFs, POTWs) |
| `tri_transfer_details` | Links transfers to specific facilities |
| `tri_reports` | Submitted Form R/Form A records |
| `tri_source_reduction` | Pollution prevention activities |
| `tri_source_reduction_codes` | Reference: EPA W-codes |

**Key Design Decisions:**
- Three activity types tracked separately (manufacture, process, otherwise use) because different thresholds apply
- Form A eligibility calculated (`qualifies_form_a`) for simplified reporting
- Source reduction codes included to support Form R Section 8.10
- Pre-seeded with common manufacturing chemicals (metals, solvents, acids)

**Views:**
| View | Purpose |
|------|---------|
| `v_tri_reportable_chemicals` | Chemicals above TRI thresholds |
| `v_tri_annual_summary` | Yearly TRI summary by establishment |
| `v_tri_pending_reports` | Form Rs needed but not yet submitted |

---

### 002a - Regulatory Requirements Bridge (`002a_sara313.sql`)

**Purpose:** Links chemicals to their regulatory requirements, enabling automatic determination of training needs, inspection schedules, and reporting obligations.

**Tables:**
| Table | Purpose |
|-------|---------|
| `regulatory_sources` | Regulations (OSHA, EPA, DOT) |
| `regulatory_requirements` | Specific requirements with frequency and retention |
| `requirement_triggers` | Conditions that activate requirements |

**Trigger Types:**
- `chemical_hazard` - Triggered by hazard flag (e.g., `is_flammable`)
- `chemical_specific` - Triggered by specific chemical or CAS number
- `threshold` - Triggered when quantity exceeds threshold
- `activity` - Triggered by job activity (e.g., forklift operation)
- `all_employees` - Applies to everyone

**Pre-seeded Regulations:**
- OSHA: HazCom, Respiratory Protection, PPE, LOTO, Forklifts, EAP, Fire Extinguishers, First Aid
- EPA: Tier II, TRI, SPCC, RCRA, RMP
- DOT: HazMat Training

**Views:**
| View | Purpose |
|------|---------|
| `v_chemical_training_requirements` | Training required based on chemical hazards |
| `v_chemical_all_requirements` | All requirements by chemical |
| `v_establishment_regulatory_profile` | Regulatory summary for a facility |

---


## Database Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ESTABLISHMENTS                                  │
│                         (Company/Site - OSHA unit)                          │
└─────────────────────────────────────────────────────────────────────────────┘
          │                    │                    │
          ▼                    ▼                    ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│    EMPLOYEES     │  │    CHEMICALS     │  │ STORAGE_LOCATIONS│
│                  │  │                  │  │                  │
│ - Identity       │  │ - GHS hazards    │  │ - Building/room  │
│ - Job info       │  │ - Regulatory     │  │ - Tier II info   │
│ - OSHA 301 data  │  │ - Physical props │  │ - Coordinates    │
└──────────────────┘  └──────────────────┘  └──────────────────┘
          │                    │                    │
          │                    ▼                    │
          │           ┌──────────────────┐         │
          │           │  SDS_DOCUMENTS   │         │
          │           │                  │         │
          │           │ - Revisions      │         │
          │           │ - Review dates   │         │
          │           └──────────────────┘         │
          │                    │                    │
          │                    ▼                    │
          │           ┌──────────────────┐         │
          │           │CHEMICAL_INVENTORY│◄────────┘
          │           │                  │
          │           │ - Snapshots      │
          │           │ - Transactions   │
          │           └──────────────────┘
          │                    │
          ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│    INCIDENTS     │  │ REGULATORY_      │
│                  │  │ REQUIREMENTS     │
│ - OSHA 300/301   │  │                  │
│ - Classification │  │ - Triggers       │
│ - Investigation  │  │ - Frequencies    │
└──────────────────┘  └──────────────────┘
          │                    │
          ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│CORRECTIVE_ACTIONS│  │  (TRAINING -     │
│                  │  │   Module 003)    │
│ - Assigned       │  │                  │
│ - Verified       │  │ - Courses        │
└──────────────────┘  │ - Completions    │
                      │ - Gaps           │
                      └──────────────────┘

REPORTING OUTPUTS:
├── OSHA 300 Log
├── OSHA 300A Summary  
├── OSHA 301 Forms
├── Tier II Reports
├── TRI Form R/Form A
└── Training Matrix
```

---

## Key Relationships

| From | To | Relationship |
|------|----|--------------|
| Establishment | Employees | 1:many |
| Establishment | Chemicals | 1:many |
| Establishment | Storage Locations | 1:many |
| Establishment | Incidents | 1:many |
| Employee | Incidents | 1:many |
| Chemical | SDS Documents | 1:many (revisions) |
| Chemical | Chemical Components | 1:many (mixtures) |
| Chemical | Chemical Inventory | 1:many (snapshots) |
| Chemical | Chemical Transactions | 1:many |
| Storage Location | Chemical Inventory | 1:many |
| Incident | Corrective Actions | 1:many |
| Regulatory Source | Regulatory Requirements | 1:many |
| Regulatory Requirement | Requirement Triggers | 1:many |

---

## Next Steps

### Immediate (Session 002)
1. **003 - Training Records**
   - Training courses/curricula table
   - Completion records linked to employees
   - Gap analysis views (required by chemicals but not completed)
   - Custom table support for user-defined requirements

### Upcoming
2. **004 - Waste Management** - RCRA tracking, manifests, waste codes
3. **005 - Inspections & Audits** - Scheduled inspections, findings, follow-up
4. **006 - Permits & Licenses** - Permit tracking with renewal alerts
5. **007 - PPE Tracking** - Assignment, inspection, replacement

### Future Enhancements
- SQL Server migration scripts
- Data import utilities (bulk chemical loading)
- Report generation queries

---

## Files Created This Session

```
waypoint/
├── 001_incidents.sql        # OSHA incident tracking (pre-existing)
├── 002_chemicals.sql        # Chemical/SDS management
├── 002a_sara313.sql         # TRI + Regulatory requirements bridge
├── docs/
│   └── session_summary_001.md  # This file
└── identifier.sqlite        # SQLite database file
```

---

## Design Principles Applied

1. **Regulatory-first** - Schema fields map directly to form requirements
2. **Audit-ready** - Change tracking and record retention built in
3. **Flexible thresholds** - User can override defaults per chemical
4. **Optional complexity** - Simple path (snapshots) with optional detail (transactions)
5. **Pre-seeded references** - Common chemicals, regulations, codes ready to use
6. **View-based reporting** - Complex queries encapsulated in views

---

*End of Session 001 Summary*
