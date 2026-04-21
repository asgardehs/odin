The ontology files in this directory (ehs-ontology-v3.2.ttl and related
documents) are licensed under Creative Commons Attribution-ShareAlike 4.0
International (CC BY-SA 4.0), not the GPL-3.0 that covers the rest of this
repository. See LICENSE-CC-BY-SA-4.0.txt in this directory for the full
license text.

# EHS Ontology Documentation

## Files

- **ehs-ontology-v3.2.ttl** — The EHS Ontology (OWL/Turtle). Four
  regulatory-program modules plus one operational module:
  - Module A: EPCRA Tier II / TRI (chemical inventory reporting)
  - Module B: Title V / CAA (air permitting)
  - Module C: OSHA 300 (injury and illness recordkeeping)
  - Module D: Clean Water Act (NPDES discharge + monitoring, stormwater
    SWPPPs + BMPs, added in v3.2)
  - OPERATIONAL: Employee Incident Management (investigation workflow,
    root cause analysis, corrective actions — cross-cutting, non-regulatory)
  Cross-program `ehs:Permit` umbrella introduced in v3.2 covers Title V,
  FESOP, NPDES, and POTW discharge permits. Validated in Protégé;
  consistent under OWL-DL semantics via HermiT.
- **CHANGELOG.md** — Version history. v3.2 entry covers the Module D
  additions, Permit umbrella, and reconciliation changes with validation
  results.
- **.archive/** — Prior ontology versions retained for provenance
  (v3.1, v3-merged, v3-extension, and the original ehs-ontology.ttl).
- **EHS Geo-Compliance Extension.md** — Design document for the fourth
  routing axis (FacilityJurisdiction). Adds state/county/city regulatory
  overlays on top of the federal baseline.

## Paper

"The Compliance Routing Problem — A Practitioner-Built Ontology for Multi-Agency
EHS Navigation" Adam J. Bick, 2026-04-09. Submitted to EngrXiv.

The paper presents the ontology's formal architecture, validates the three-axis
routing model (HazardType × ActionContext × ContextualCondition) through
nine worked scenarios, and describes the Geo-Compliance Extension design.
The v3.2 revision adds Module D (Clean Water Act) and two additional worked
scenarios (`Scenario_NPDESPermitExceedance`, `Scenario_StormwaterOutfall_MSGP`)
exercising the new regulatory-program chain; the paper's published claims
are on v3.1 and remain unchanged.
