# EHS Ontology — Changelog

All notable changes to `ehs-ontology-*.ttl` are recorded here. Each release
corresponds to a versioned Turtle file; prior versions are archived under
`.archive/` alongside this changelog.

Version numbers track the value in `owl:versionInfo` inside the ontology file.

---

## v3.2 — 2026-04-20 → 2026-04-21

**Theme:** Module D (Clean Water Act) — new regulatory-program module parallel
to Module B (Title V / CAA), plus a cross-program `ehs:Permit` umbrella that
reorganizes air and water permits into a shared hierarchy.

### Added

**New module: Module D — Clean Water Act Discharge & Monitoring.**

Water pollutant taxonomy:
- `ehs:WaterPollutant` with subclasses `ehs:ConventionalPollutant`,
  `ehs:PriorityPollutant`, `ehs:NonConventionalPollutant`, and
  `ehs:WholeEffluentToxicity` (`⊂ NonConventionalPollutant`). Scope per CWA
  §304(a)(4), 40 CFR 423 Appendix A, and 40 CFR 136.

Physical water infrastructure:
- `ehs:DischargePoint` — outfall analog to `ehs:EmissionUnit` on the air side.
- `ehs:StormwaterOutfall` (`⊂ DischargePoint`) — MSGP-regulated outfall.
- `ehs:MonitoringLocation` — compliance sampling point.

Water control equipment:
- `ehs:WaterControlDevice` — water-side analog to `ehs:ControlDevice`.
- `ehs:WastewaterTreatmentUnit` (`⊂ WaterControlDevice`).

Stormwater planning:
- `ehs:SWPPP` — Stormwater Pollution Prevention Plan (40 CFR 122.26).
- `ehs:BestManagementPractice`.

Regulatory-program classes:
- `ehs:NPDESPermit` (`⊂ Permit`) — CWA §402 individual or general permit.
- `ehs:POTWDischargePermit` (`⊂ Permit`) — indirect-discharge industrial
  user permit issued under 40 CFR 403.8.
- `ehs:PretreatmentStandard` — 40 CFR 403 categorical standard.
  **Deliberately not** a subclass of `ehs:Permit`; it is a generally-applicable
  regulatory requirement, not a site-specific authorization document.

Object properties (CWA discharge + monitoring + stormwater chain):
- `ehs:dischargesTo` — `EmissionUnit` → `DischargePoint`.
- `ehs:monitoredAt` — `DischargePoint` → `MonitoringLocation`.
- `ehs:sampledFor` — `MonitoringLocation` → `WaterPollutant`.
- `ehs:subjectToPermit` — `DischargePoint` → `Permit` (range uses the umbrella
  so NPDES, POTW, and future permit types all satisfy it without schema change).
- `ehs:coveredBy` — `StormwaterOutfall` → `SWPPP`.
- `ehs:implements` — `SWPPP` → `BestManagementPractice`.

**Cross-program Permit umbrella.**
- New top-level class `ehs:Permit` covering any regulatory authorization
  document (air, water, waste, radiation, etc.).
- Excludes regulatory standards that apply by operation of law without site-
  specific issuance (NSPS, NESHAP, 40 CFR 403 pretreatment standards).

### Changed

- `ehs:TitleVPermit` — retrofit with `rdfs:subClassOf ehs:Permit`.
- `ehs:FESOP` — retrofit with `rdfs:subClassOf ehs:Permit`.
- `ehs:WaterwayProximity` — definition narrowed to site geography only. CWA
  permitting substance moved to Module D where it belongs; this class
  remains a `LocationContext` modifier used by the
  `ContextualComplianceActivation` routing at incident time (e.g., to decide
  whether a release triggers CWA §311 notification).
- `ehs:EnvironmentalIncident` — added `rdfs:comment` documenting the CWA
  linkage back to the `Permit` / `DischargePoint` / `dischargesTo` chain.
- Header metadata: `owl:versionInfo "3.2"`; `dcterms:date 2026-04-20`;
  v3.2 additions block added to the header `rdfs:comment`.
- Module structure: former "MODULE D: EMPLOYEE INCIDENT MANAGEMENT" section
  renamed to "OPERATIONAL: EMPLOYEE INCIDENT MANAGEMENT" to free the letter
  D for the new regulatory-program module. Content of that section is
  unchanged except for one stale "(Module D)" reference in
  `ehs:alignsWithRecordingCriteria`.
- End-of-file banner bumped from "END OF v3.1" to "END OF v3.2".

### Scenarios

Added two Module D worked scenarios to the routing matrix so the regulatory
vocabulary is exercised end-to-end:

- `ehs:Scenario_NPDESPermitExceedance` — direct-discharge outfall exceeds a
  numeric permit limit; walks the `dischargesTo` / `subjectToPermit` chain;
  fires CWA §309 + 40 CFR 122.41(l)(6) 24-hour noncompliance reporting.
- `ehs:Scenario_StormwaterOutfall_MSGP` — industrial stormwater benchmark
  exceedance; walks the `StormwaterOutfall` / `coveredBy` / `implements`
  chain; fires MSGP Part 6 corrective-action (not direct enforcement).

### Fixed

- `ehs:exposureDuration` — `rdfs:range` changed from `xsd:duration` →
  `xsd:string` (with `skos:definition` pinning ISO 8601 duration format).
  Pre-existing issue surfaced by v3.2 validation: `xsd:duration` is outside
  the OWL 2 datatype map and caused HermiT to refuse to load the ontology.
  Application layer must validate the ISO 8601 grammar at ingress.

### Validation

- `rapper -c` parses cleanly: 1446 triples, zero errors.
- `owlready2` structural scan: all 16 Module D classes, all 6 new object
  properties (with correct `rdfs:domain` and `rdfs:range`), and both new
  scenarios resolve. Zero orphan `ehs:` IRIs (every referenced term is
  declared somewhere in the file).
- HermiT reasoner: **consistent** under OWL-DL semantics (0.5 s). No
  contradictions introduced by v3.2 additions.

### Archived

- `v3.1` moved to `.archive/ehs-ontology-v3.1.ttl`.

---

## Prior versions (pre-changelog)

Archived under `.archive/`. Summaries reconstructed from file headers rather
than from authoritative release notes.

### v3.1

Added `ehs:Establishment` as the facility/site anchor for chemical inventory
and OSHA 300 recordkeeping; expanded Section 313 (TRI Form R / Form A);
cross-module wiring (`InventoryChemical ↔ EmissionUnit`,
`Employee → EmissionUnit`, `IncidentSeverity ↔ RecordingCriteria` alignment,
`EnvironmentalIncident → ContextualComplianceActivation`); range fixes on
`addressedByControl` and `connectsToARECC`; `hasRecordingCriteria` domain
widened to `Outcome`.

### v3.0

First four-module release: Module A (EPCRA Tier II / chemical inventory),
Module B (Title V / CAA air permitting), Module C (OSHA 300 recordkeeping),
and a now-reallocated Module D (Employee Incident Management, renamed to
OPERATIONAL in v3.2). Also introduced the `ContextualComplianceActivation`
three-axis routing (HazardType × ActionContext × ContextualCondition).

### v3 extension and v3 merged

Working files preserved for provenance — `ehs-ontology-v3-extension.ttl`
and `ehs-ontology-v3-merged.ttl` in `.archive/`.
