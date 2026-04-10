---
title: 'EHS Ontology: Geo-Compliance Extension'
date: 2026-04-10
status: Design Draft
version: 1
written_by: Adam J. Bick
---

# EHS Ontology: Geo-Compliance Extension

Extends: EHS Ontology v3.1 Namespace: ehs-geo:
(http://example.org/ehs-geo-compliance#)

## 1. Executive Summary

The EHS Ontology v3.1 excels at routing compliance activation along three axes —
HazardType, ActionContext, and ContextualConditions — to produce a precise
federal regulatory framework set. However, the federal layer is only one tier of
a facility's actual compliance obligation. Real-world EHS programs operate under
a minimum three-tier regulatory stack:

```text
FEDERAL → STATE → COUNTY / LOCAL
```

**A manufacturing facility in Oakland, CA faces:**

- Federal OSHA (29 CFR 1910) + Cal/OSHA Title 8 CCR + City of Oakland industrial
  hygiene ordinance
- Federal EPA + California Air Resources Board (CARB) + Bay Area AQMD permit
  conditions
- Federal EPCRA Tier II + Cal OES HazMat reporting + Alameda County CUPA program

The current ontology has no mechanism to capture this geographic layering. The
Geo-Compliance Extension adds a fourth routing axis — FacilityJurisdiction —
that activates state, county, and city regulatory overlays on top of the
existing federal compliance activation logic.

## 2. Problem Statement & Design Goals

### 2.1 Gap Analysis in v3.1

**Capability v3.1 Status Gap**

| Capability                                    | v3.1 Status    | Gap                                                               |
| --------------------------------------------- | -------------- | ----------------------------------------------------------------- |
| Federal regulatory framework routing          | [YES] Complete | —                                                                 |
| OSHA State Plan differentiation               | [NO] Absent    | 22 states have their own plans with additional requirements       |
| State environmental agency programs           | [NO] Absent    | 50 state EPA equivalents with unique permit structures            |
| Local air quality management districts        | [NO] Absent    | 130+ AQMDs/AQCDs with facility-specific permit conditions         |
| CUPA / Unified Program jurisdiction           | [NO] Absent    | California Certified Unified Program Agency local authority       |
| County health department EHS authority        | [NO] Absent    | Varies widely — critical for food, bio, and hazmat facilities     |
| City-level ordinances (e.g., Safer Chemicals) | [NO] Absent    | Some cities exceed state and federal requirements                 |
| Multi-jurisdiction conflict resolution        | [NO] Absent    | When state, county, and city rules differ, most-stringent applies |

### 2.2 Design Goals

1. Additive, not disruptive — The extension must not break or redefine any v3.1
   class or property. All new terms live in ehs-geo:.
2. Location-parameterized activation — Given `ehs:Establishment` + geographic
   coordinates / jurisdiction identifiers, compute the complete multi-tier
   compliance obligation set.
3. Hierarchy-aware — Model the "most-stringent prevails" principle and state
   preemption vs. supplementation rules.
4. Incrementally populatable — A facility can start by specifying only state,
   then refine to county and city as data becomes available.
5. Interoperable with existing routing — ehs-geo: produces
   `ehs:RegulatoryFramework` instances that plug directly into the existing
   ehs:ComplianceActivation routing machinery.

## 3. Ontology Architecture

### 3.1 The Four-Axis Routing Model

**The extended routing model processes compliance activation in four ordered
steps:**

```text
Step 1: HazardType(s) → Federal framework baseline
Step 2: ActionContext → Operational modifier
Step 3: ContextualConditions → Scope refinement
Step 4: FacilityJurisdiction → Geographic overlay (NEW)
```

_Step 4 does not replace Steps 1–3. It accepts the output of
ehs:ContextualComplianceActivation and augments it with sub-federal regulatory
obligations._

### 3.2 Class Hierarchy Overview

```text
ehs-geo:JurisdictionalLayer (abstract root)
├── ehs-geo:StateJurisdiction
│ ├── ehs-geo:OSHAStatePlan
│ ├── ehs-geo:StateEnvironmentalProgram
│ └── ehs-geo:StateFireMarshalProgram
├── ehs-geo:CountyJurisdiction
│ ├── ehs-geo:CountyAirDistrict
│ ├── ehs-geo:CertifiedUnifiedProgramAgency (CA-specific, but models a pattern)
│ └── ehs-geo:CountyHealthDepartment
└── ehs-geo:CityJurisdiction
├── ehs-geo:CityFireDepartment
├── ehs-geo:CityBuildingDepartment
└── ehs-geo:CityEnvironmentalOffice
```

```text
ehs-geo:FacilityJurisdiction
— links an ehs:Establishment to its full set of JurisdictionalLayers
```

```text
ehs-geo:GeoComplianceRequirement
— a sub-federal compliance item activated by JurisdictionalLayer + HazardType
├── ehs-geo:StateRequirement
├── ehs-geo:CountyRequirement
└── ehs-geo:CityRequirement
```

```text
ehs-geo:JurisdictionalRelationship (abstract)
├── ehs-geo:StatePreempts (state law overrides local)
├── ehs-geo:LocalSupplements (local adds to state floor)
└── ehs-geo:MostStringentApplies (when layers conflict)
```

## 4. Detailed Class Definitions

### 4.1 FacilityJurisdiction

```text
ehs-geo:FacilityJurisdiction rdf:type owl:Class ;
rdfs:label "Facility Jurisdiction"@en ;
skos:definition """The complete set of governmental jurisdictions (federal, state, county,
city/municipal) whose regulatory authority applies to a specific Establishment. This is
the geographic anchor of the Geo-Compliance Extension — it binds an ehs:Establishment
to all layers of regulatory authority that govern its operations.
```

```text
A FacilityJurisdiction is resolved from the physical address of the Establishment and
may include: one state, one or more county-level authorities, one or more municipal
authorities, and any special districts (air quality management districts, fire protection
districts, groundwater management districts).
```

```text
Once resolved, FacilityJurisdiction triggers GeoComplianceRequirements that stack on
top of the federal ComplianceActivation output."""@en ;
rdfs:comment """Design note: FacilityJurisdiction is attached to ehs:Establishment
(the v3.1 facility anchor) via the ehs-geo:hasJurisdiction property. The Establishment
already carries address-level data (implicitly via its real-world identity); this class
makes the regulatory consequence of that address explicit."""@en.
```

### 4.2 JurisdictionalLayer (Abstract)

```text
ehs-geo:JurisdictionalLayer rdf:type owl:Class ;
rdfs:label "Jurisdictional Layer"@en ;
skos:definition """An abstract superclass representing a single level of governmental
regulatory authority below the federal level. Concrete subclasses are StateJurisdiction,
CountyJurisdiction, and CityJurisdiction. A FacilityJurisdiction is composed of one
or more JurisdictionalLayers."""@en.
```

### 4.3 StateJurisdiction

```text
ehs-geo:StateJurisdiction rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:JurisdictionalLayer ;
rdfs:label "State Jurisdiction"@en ;
skos:definition """Represents the regulatory authority of a U.S. state over facilities
within its borders. A state may exercise authority through:
(a) An OSHA-approved State Plan — covering occupational safety and health for both
private and public sector workers (22 states + Puerto Rico) or public sector only
(7 states + Virgin Islands). State Plans must be 'at least as effective' (ALAE)
as federal OSHA but may exceed federal requirements.
(b) A State Environmental Program — state EPA equivalent that may implement delegated
federal programs (CAA, CWA, RCRA) with additional state-specific requirements.
(c) A State Fire Marshal Program — adoption of fire codes (NFPA 1, IFC, or state-
specific) with state-level enforcement authority.
(d) State Right-to-Know Laws — some states (CA, NJ, MA) have chemical inventory
reporting requirements that exceed or differ from EPCRA 311/312."""@en.
```

```text
ehs-geo:OSHAStatePlan rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:StateJurisdiction ;
rdfs:label "OSHA State Plan"@en ;
skos:definition """An OSHA-approved state occupational safety and health program
operating under Section 18 of the OSH Act. State Plans replace federal OSHA
enforcement for workers covered by the plan. A State Plan must promulgate standards
at least as effective as the corresponding federal standards within 6 months of
federal adoption, but may adopt stricter standards without federal approval.
```

```text
Coverage types:
FULL_COVERAGE: covers both private sector and state/local government workers
(22 states: AK, AZ, CA, HI, IN, IA, KY, MD, MI, MN, NV, NM, NC, OR, SC, TN, UT,
VT, VA, WA, WY + PR)
PUBLIC_SECTOR_ONLY: covers only state and local government workers
(7 states: CT, IL, ME, MA, NJ, NY + VI)
NO_STATE_PLAN: federal OSHA has direct jurisdiction
(remaining states: AL, AR, CO, DE, FL, GA, ID, IL*, KS, LA, MO, MT, NE, NH, ND,
OH, OK, PA, RI, SD, TX, WI + DC — *IL is public sector only)"""@en.
```

```text
ehs-geo:StateEnvironmentalProgram rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:StateJurisdiction ;
rdfs:label "State Environmental Agency Program"@en ;
skos:definition """The state environmental agency's regulatory authority over
facilities within the state. State environmental programs may:
(1) Administer delegated federal programs (CAA, CWA, RCRA, TSCA) under EPA
authorization, with authority to impose additional requirements.
(2) Operate independent state programs (e.g., California's Cap-and-Trade program
under AB 32, New Jersey's Environmental Cleanup Responsibility Act (ECRA)).
(3) Issue state-level operating permits that incorporate both federal and
state-specific requirements.
```

```text
Key state environmental agencies include:

- CARB / CalEPA (California)
- NJDEP (New Jersey)
- NYSDEC (New York)
- WDOE (Washington)
- TCEQ (Texas)
- IDEM (Indiana)"""@en.
```

### 4.4 CountyJurisdiction

```text
ehs-geo:CountyJurisdiction rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:JurisdictionalLayer ;
rdfs:label "County Jurisdiction"@en ;
skos:definition """Represents the regulatory authority of a county (or county-equivalent
parish, borough, or consolidated city-county) over facilities within its borders.
County-level EHS authority is most significant in three areas:
(1) Air quality management districts — often operate below the state level with
direct permitting authority for stationary sources.
(2) Hazardous materials / Unified Programs — particularly in California, where
Certified Unified Program Agencies (CUPAs) administer hazardous waste,
underground storage tanks, and hazardous materials business plans.
(3) County health department authority — environmental health programs for food,
water, and communicable disease that affect facility operations."""@en.
```

```text
ehs-geo:CountyAirDistrict rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:CountyJurisdiction ;
rdfs:label "Air Quality Management District / Air Pollution Control District"@en ;
skos:definition """A regional or county-level air quality regulatory agency with
authority to issue air permits and regulate stationary source emissions. In
California, AQMDs/APCDs are the primary permitting authority for all stationary
sources (not delegated to state level). Examples:
- South Coast AQMD (Los Angeles Basin) — strictest air rules in the country
- Bay Area AQMD
- San Joaquin Valley APCD
- Sacramento Metropolitan AQMD
Outside California, similar regional authorities exist (e.g., Puget Sound Clean
Air Agency, Houston-Galveston APCA). District rules may impose lower emission
thresholds, additional VOC/NOx controls, and facility-specific BACT requirements
beyond federal NSPS/NESHAP standards."""@en.


ehs-geo:CertifiedUnifiedProgramAgency rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:CountyJurisdiction ;
rdfs:label "Certified Unified Program Agency (CUPA)"@en ;
skos:definition """A California-specific jurisdictional entity that administers
six environmental and safety programs under a single unified permit (California
Health & Safety Code §25404). The six unified programs are:
(1) Hazardous Materials Business Plan (HMBP) — equivalent to but stricter than
EPCRA Tier II for California facilities.
(2) California Accidental Release Prevention (CalARP) — state-level RMP program.
(3) Underground Storage Tank (UST) program.
(4) Hazardous Waste Generator program.
(5) Hazardous Waste On-Site Treatment (Tiered Permitting).
(6) Aboveground Petroleum Storage Act (APSA).
Most CUPAs are operated at the county or city level. HMBP reporting thresholds
often differ significantly from federal EPCRA thresholds.
```

```text
NOTE: The CUPA model exemplifies the general pattern of 'unified local program
agency' that may exist in other states under different names."""@en.
```

```text
ehs-geo:CountyHealthDepartment rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:CountyJurisdiction ;
rdfs:label "County Health Department / Environmental Health"@en ;
```

```text
skos:definition """The county public health authority with regulatory jurisdiction
over environmental health programs including: food service establishments, water
systems, solid waste facilities, vector control, and in some counties, industrial
hygiene programs. County health departments may issue operating permits, conduct
inspections, and enforce local health codes that are not covered by OSHA or EPA."""@en.
```

### 4.5 CityJurisdiction

```text
ehs-geo:CityJurisdiction rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:JurisdictionalLayer ;
rdfs:label "City / Municipal Jurisdiction"@en ;
skos:definition """Represents the regulatory authority of a municipality (city, town,
village, or township) over facilities within its borders. Municipal EHS authority is
most commonly exercised through:
(1) Fire Department / Fire Prevention Bureau — local fire code adoption and
enforcement (IFC, NFPA 1, or local amendments). Hazardous materials permits
for quantities above city thresholds. Pre-incident planning surveys.
(2) Building Department — occupancy classification, fire suppression systems,
sprinkler requirements, and certificates of occupancy.
(3) Environmental Office / Sustainability Department — some cities (San Francisco,
Chicago, Seattle) have adopted local chemical use ordinances or sustainability
requirements that exceed state and federal minimums.
(4) Stormwater / Pretreatment Authority — local industrial pretreatment programs
under CWA with city-specific discharge limits."""@en.
```

```text
ehs-geo:CityFireDepartment rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:CityJurisdiction ;
rdfs:label "City Fire Department (AHJ)"@en ;
skos:definition """The Authority Having Jurisdiction (AHJ) for fire code enforcement
at the municipal level. The city fire department adopts and enforces a version of
the International Fire Code (IFC) or NFPA 1 with local amendments. Hazardous
materials inventory permits are commonly required at lower thresholds than EPCRA.
Fire department pre-incident planning surveys may require submission of chemical
inventories, site plans, and emergency response procedures.
Key requirements that vary by city:
- Hazardous materials permit thresholds (often lower than EPCRA 10,000 lb)
- Sprinkler system requirements by occupancy and chemical type
- Hot work permit requirements
- Annual inspection frequencies"""@en.
```

### 4.6 GeoComplianceRequirement

```text
ehs-geo:GeoComplianceRequirement rdf:type owl:Class ;
rdfs:label "Geo-Compliance Requirement"@en ;
skos:definition """A specific regulatory obligation that arises from the combination
of a JurisdictionalLayer and a HazardType or ActionContext. GeoComplianceRequirements
are the sub-federal counterpart to ehs:ComplianceActivation — they represent the
same routing concept (type → obligation) applied at the state, county, and city
levels.
```

A GeoComplianceRequirement specifies:

- The activating jurisdiction (which layer imposed this requirement)
- The triggering condition (hazard type, action context, chemical, or threshold)
- The specific citation within that jurisdiction's code
- The relationship to the federal baseline (supplements, exceeds, or replaces)
- Relevant deadlines, thresholds, and permit contacts"""@en.

```text
ehs-geo:StateRequirement rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:GeoComplianceRequirement ;
rdfs:label "State Compliance Requirement"@en ;
skos:definition "A GeoComplianceRequirement imposed by a state authority (OSHA State Plan, state environmental agenc

ehs-geo:CountyRequirement rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:GeoComplianceRequirement ;
rdfs:label "County Compliance Requirement"@en ;
skos:definition "A GeoComplianceRequirement imposed by a county-level authority (air district, CUPA, county health d

ehs-geo:CityRequirement rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:GeoComplianceRequirement ;
rdfs:label "City / Municipal Compliance Requirement"@en ;
skos:definition "A GeoComplianceRequirement imposed by a city or municipal authority (fire department, building depa
```

### 4.7 JurisdictionalConflict Resolution

```text
ehs-geo:JurisdictionalRelationship rdf:type owl:Class ;
rdfs:label "Jurisdictional Relationship"@en ;
skos:definition """Describes the legal relationship between two JurisdictionalLayers
when both impose requirements on the same regulated subject. This is necessary because
federal, state, county, and city requirements do not always point in the same direction.
Three relationship types exist: StatePreempts, LocalSupplements, MostStringentApplies."""@en.

ehs-geo:StatePreempts rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:JurisdictionalRelationship ;
rdfs:label "State Preempts Local"@en ;
skos:definition """State law expressly prohibits local governments from enacting
regulations in this subject area. Compliance is determined solely by the state
standard. Example: Some states preempt local regulation of pesticide use or
agricultural chemical storage. When StatePreempts applies, CountyRequirements and
CityRequirements in the preempted subject area are set aside."""@en.

ehs-geo:LocalSupplements rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:JurisdictionalRelationship ;
rdfs:label "Local Supplements State / Federal Floor"@en ;
skos:definition """Local ordinances ADD requirements on top of the state and federal
baseline. The federal/state requirements are the minimum floor; local requirements
are additive. Example: A city requires hazardous materials permits at 500 lbs,
while EPCRA threshold is 10,000 lbs. Both thresholds apply — the city permit
obligation fires at 500 lbs; the EPCRA obligation fires at 10,000 lbs. The facility
must comply with BOTH."""@en.

ehs-geo:MostStringentApplies rdf:type owl:Class ;
rdfs:subClassOf ehs-geo:JurisdictionalRelationship ;
rdfs:label "Most Stringent Requirement Applies"@en ;
skos:definition """When multiple tiers impose requirements on the same subject and
the requirements are not additive but instead set different numerical standards
(e.g., different OEL values, different emission limits), the most protective /
most stringent requirement governs. This is the default principle in environmental
and occupational health law when preemption is absent and supplementation is
ambiguous. Example: Federal OSHA PEL for silica is 50 μg/m³ TWA; Cal/OSHA
PEL is also 50 μg/m³ but with stricter action level triggers. The Cal/OSHA
requirement applies at the California facility."""@en.
```

## 5. Object Properties

### 5.1 Linking Establishment to Jurisdiction

```text
ehs-geo:hasJurisdiction rdf:type owl:ObjectProperty ;
rdfs:label "has jurisdiction"@en ;
rdfs:domain ehs:Establishment ;
rdfs:range ehs-geo:FacilityJurisdiction ;
skos:definition """Links an Establishment to its resolved FacilityJurisdiction.
This is the entry point of the Geo-Compliance Extension — once this link exists,
all downstream GeoComplianceRequirements can be inferred or queried."""@en.

ehs-geo:composedOf rdf:type owl:ObjectProperty ;
rdfs:label "composed of"@en ;
rdfs:domain ehs-geo:FacilityJurisdiction ;
rdfs:range ehs-geo:JurisdictionalLayer ;
skos:definition "Links a FacilityJurisdiction to each of its constituent JurisdictionalLayers (state, county, city,

ehs-geo:inState rdf:type owl:DatatypeProperty ;
rdfs:label "in state"@en ;
rdfs:domain ehs-geo:FacilityJurisdiction ;
rdfs:range xsd:string ;
skos:definition "The two-letter U.S. state code (ISO 3166-2:US) for the facility's location."@en.

ehs-geo:inCounty rdf:type owl:DatatypeProperty ;
rdfs:label "in county"@en ;
rdfs:domain ehs-geo:FacilityJurisdiction ;
rdfs:range xsd:string ;
skos:definition "The name of the county (or parish, borough) in which the facility is located."@en.

ehs-geo:inCity rdf:type owl:DatatypeProperty ;
rdfs:label "in city"@en ;
rdfs:domain ehs-geo:FacilityJurisdiction ;
rdfs:range xsd:string ;
skos:definition "The name of the city or municipality in which the facility is located."@en.

ehs-geo:geoCoordinates rdf:type owl:DatatypeProperty ;
rdfs:label "geo coordinates"@en ;
rdfs:domain ehs-geo:FacilityJurisdiction ;
rdfs:range xsd:string ;
skos:definition "WGS84 decimal latitude/longitude string (e.g., '37.7749,-122.4194') enabling automated jurisdiction

ehs-geo:facilityAddress rdf:type owl:DatatypeProperty ;
rdfs:label "facility address"@en ;
rdfs:domain ehs-geo:FacilityJurisdiction ;
rdfs:range xsd:string ;
skos:definition "Full street address of the facility. Used for geocoding to resolve JurisdictionalLayers when coordi
```

### 5.2 Linking Requirements to Activation

```text
ehs-geo:activatesGeoRequirement rdf:type owl:ObjectProperty ;
rdfs:label "activates geo requirement"@en ;
rdfs:domain ehs-geo:JurisdictionalLayer ;
rdfs:range ehs-geo:GeoComplianceRequirement ;
skos:definition """A JurisdictionalLayer activates specific GeoComplianceRequirements
when the relevant HazardType, ActionContext, or threshold condition is present.
This property is the sub-federal analog to ehs:activatesFramework."""@en.

ehs-geo:requirementTriggeredBy rdf:type owl:ObjectProperty ;
rdfs:label "requirement triggered by"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range ehs:HazardType ;
skos:definition "Links a GeoComplianceRequirement to the HazardType that triggers it."@en.

ehs-geo:requirementTriggeredByAction rdf:type owl:ObjectProperty ;
rdfs:label "requirement triggered by action"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range ehs:ActionContext ;
skos:definition "Links a GeoComplianceRequirement to the ActionContext that triggers it (e.g., StorageAction trigger

ehs-geo:supplementsFederalFramework rdf:type owl:ObjectProperty ;
rdfs:label "supplements federal framework"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range ehs:RegulatoryFramework ;
skos:definition "Indicates that this GeoComplianceRequirement supplements (adds to) the specified federal framework

ehs-geo:exceedsFederalFramework rdf:type owl:ObjectProperty ;
rdfs:label "exceeds federal framework"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range ehs:RegulatoryFramework ;
skos:definition "Indicates that this GeoComplianceRequirement sets a STRICTER standard than the federal framework on

ehs-geo:hasJurisdictionalRelationship rdf:type owl:ObjectProperty ;
rdfs:label "has jurisdictional relationship"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range ehs-geo:JurisdictionalRelationship ;
skos:definition "Describes how this requirement relates to requirements from other jurisdictional tiers."@en.
```

### 5.3 Geo-Activation Integration with v3.1

```text
ehs-geo:hasGeoActivation rdf:type owl:ObjectProperty ;
rdfs:label "has geo activation"@en ;
rdfs:domain ehs:ContextualComplianceActivation ;
rdfs:range ehs-geo:GeoComplianceRequirement ;
skos:definition """Links a v3.1 ContextualComplianceActivation (the federal routing
result) to the sub-federal GeoComplianceRequirements that also apply. This is the
bridge between the existing v3.1 compliance routing and the Geo-Compliance Extension.
A single ContextualComplianceActivation may have zero or many GeoComplianceRequirements
depending on the facility's jurisdiction."""@en.

ehs-geo:resolvedForEstablishment rdf:type owl:ObjectProperty ;
rdfs:label "resolved for establishment"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range ehs:Establishment ;
skos:definition "Links a GeoComplianceRequirement to the specific Establishment for which it has been determined to
```

## 6. Datatype Properties on GeoComplianceRequirement

```text
ehs-geo:jurisdictionalCitation rdf:type owl:DatatypeProperty ;
rdfs:label "jurisdictional citation"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range xsd:string ;
skos:definition """The specific code, statute, or regulation citation within the
sub-federal jurisdiction. Examples:

- California: 'Cal/OSHA Title 8 CCR §5155 (PEL for air contaminants)'
- Bay Area AQMD: 'Regulation 8, Rule 8 (Solvent Coating Operations)'
- Michigan: 'Michigan Occupational Safety and Health Act (MIOSHA) R 325.51101'"""@en.

ehs-geo:localThreshold rdf:type owl:DatatypeProperty ;
rdfs:label "local threshold"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range xsd:decimal ;
skos:definition "The quantity or concentration threshold at which this requirement activates, expressed in the unit

ehs-geo:localThresholdUnit rdf:type owl:DatatypeProperty ;
rdfs:label "local threshold unit"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range xsd:string ;
skos:definition "The unit for ehs-geo:localThreshold (e.g., 'lbs', 'gallons', 'ppm', 'μg/m³', 'tpy')."@en.

ehs-geo:reportingDeadline rdf:type owl:DatatypeProperty ;
rdfs:label "reporting deadline"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range xsd:string ;
skos:definition "The submission deadline for any periodic reporting obligation (e.g., 'February 15 annually', 'Withi

ehs-geo:contactAgency rdf:type owl:DatatypeProperty ;
rdfs:label "contact agency"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range xsd:string ;
skos:definition "The specific agency to which submissions are made or from which permits are obtained (e.g., 'Bay Ar

ehs-geo:agencyWebsite rdf:type owl:DatatypeProperty ;
rdfs:label "agency website"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range xsd:anyURI ;
skos:definition "The URL for the regulatory agency responsible for this requirement."@en.

ehs-geo:permitRequired rdf:type owl:DatatypeProperty ;
rdfs:label "permit required"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range xsd:boolean ;
skos:definition "True if this requirement triggers a permit obligation (not just reporting). A permit usually requir

ehs-geo:applicabilityNote rdf:type owl:DatatypeProperty ;
rdfs:label "applicability note"@en ;
rdfs:domain ehs-geo:GeoComplianceRequirement ;
rdfs:range xsd:string ;
skos:definition "A plain-language explanation of when and why this requirement applies, including any industry-speci
```

## 7. Jurisdiction Resolution Algorithm

The process for resolving a FacilityJurisdiction from an `ehs:Establishment`
follows these steps:

### Step 1 — Address Geocoding

```text
INPUT: Establishment physical address (street, city, state, ZIP)
PROCESS: Geocode to WGS84 lat/long using Census Geocoder, Google Maps API,
or equivalent. Store as ehs-geo:geoCoordinates.
OUTPUT: Lat/Long coordinate pair
```

### Step 2 — State Layer Resolution

```text
INPUT: State code from address (e.g., "CA", "MI", "TX")
LOOKUP RULES:
a. Is state in OSHA Full State Plan list?
→ If yes: instantiate ehs-geo:OSHAStatePlan with state-specific attributes
→ If no: record federal OSHA jurisdiction (no OSHAStatePlan instance needed)
b. Does state have a delegated EPA environmental program?
→ Always yes for CAA, CWA, RCRA in most states
→ Instantiate ehs-geo:StateEnvironmentalProgram with state agency
c. Does state have unique chemical inventory / right-to-know laws?
→ Check against state-specific inventory (CA, NJ, MA, IL, PA have significant programs)
OUTPUT: One or more ehs-geo:StateJurisdiction instances
```

### Step 3 — County Layer Resolution

```text
INPUT: County FIPS code (derived from geocoordinate via Census TIGER)
LOOKUP RULES:
a. Does an Air Quality Management / Pollution Control District cover this county?
→ Look up EPA AirNow / state air agency database
→ If yes: instantiate ehs-geo:CountyAirDistrict
b. Is this county in California?
→ Instantiate ehs-geo:CertifiedUnifiedProgramAgency (CUPA lookup from Cal OES)
c. Does the county health department have industrial EHS authority?
→ County-specific lookup
OUTPUT: Zero or more ehs-geo:CountyJurisdiction instances
```

### Step 4 — City Layer Resolution

```text
INPUT: City/municipality from address
LOOKUP RULES:
a. Does the city fire department issue hazardous materials permits?
→ Check IFC adoption status and local amendments
→ If yes: instantiate ehs-geo:CityFireDepartment
b. Does the city have a building department with occupancy classification authority?
→ Nearly always yes for incorporated cities
→ Instantiate ehs-geo:CityBuildingDepartment
c. Does the city have a local chemical use ordinance or sustainability requirement
that exceeds state/federal minimums?
→ Known cities: San Francisco (SF Environment), Chicago (Green Permit), Seattle
→ Instantiate ehs-geo:CityEnvironmentalOffice if applicable
OUTPUT: One or more ehs-geo:CityJurisdiction instances
```

### Step 5 — Compose FacilityJurisdiction

```text
Combine all resolved layers into a single ehs-geo:FacilityJurisdiction instance
linked to the ehs:Establishment via ehs-geo:hasJurisdiction.
```

## 8. GeoComplianceRequirement Activation Logic

Once FacilityJurisdiction is resolved, requirements are activated by crossing
jurisdiction with hazard type and action context:

```text
FOR EACH JurisdictionalLayer in FacilityJurisdiction:
FOR EACH HazardType in the active HazardousExposureSituation:
QUERY: Does this layer have an ehs-geo:activatesGeoRequirement
for this HazardType?
→ If yes: add GeoComplianceRequirement to the obligation set

FOR EACH ActionContext in the active HazardousExposureSituation:
QUERY: Does this layer have an ehs-geo:activatesGeoRequirement
for this ActionContext?
→ If yes: add GeoComplianceRequirement to the obligation set

THEN APPLY conflict resolution:
→ For each pair of requirements covering the same regulatory subject:
If ehs-geo:StatePreempts: drop the local requirement
If ehs-geo:LocalSupplements: keep both (additive)
If ehs-geo:MostStringentApplies: keep only the stricter one
```

## 9. Illustrative Jurisdiction Instances

### 9.1 Michigan (Full OSHA State Plan, Delegated EPA)

```text
ehs-geo:Michigan_MIOSHA rdf:type ehs-geo:OSHAStatePlan ;
rdfs:label "Michigan OSHA (MIOSHA)"@en ;
ehs-geo:stateName "Michigan"@en ;
ehs-geo:stateCode "MI" ;
ehs-geo:coverageType "FULL_COVERAGE" ;
ehs-geo:statePlanAuthority "Michigan Occupational Safety and Health Act (MIOSH Act), PA 154 of 1974" ;
ehs-geo:agencyWebsite <https://www.michigan.gov/leo/bureaus-agencies/ors/miosha> ;
ehs-geo:applicabilityNote """MIOSHA is an OSHA-approved State Plan covering all
private sector and public sector workers in Michigan. Standards are found in
Michigan Administrative Code Part 1-99 (General Industry) and Part 100-
(Construction). MIOSHA General Industry standards closely parallel federal 29 CFR
1910 but have several unique provisions including stricter noise standards and
Michigan-specific right-to-know requirements (MIOSHA Part 92)."""@en.

ehs-geo:Michigan_EGLE rdf:type ehs-geo:StateEnvironmentalProgram ;
rdfs:label "Michigan EGLE (Environment, Great Lakes, and Energy)"@en ;
ehs-geo:stateCode "MI" ;
ehs-geo:agencyWebsite <https://www.michigan.gov/egle> ;
ehs-geo:applicabilityNote """EGLE administers Michigan's air quality program under
Part 55 of the Natural Resources and Environmental Protection Act (NREPA, PA 451
of 1994) as a SIP-approved state program under the CAA. Air permits are issued
by EGLE's Air Quality Division with Michigan-specific emission limits that may
differ from federal NSPS/NESHAP."""@en.
```

### 9.2 California (OSHA State Plan, CARB, County AQMD, CUPA)

```text
ehs-geo:California_CalOSHA rdf:type ehs-geo:OSHAStatePlan ;
rdfs:label "Cal/OSHA (California Division of Occupational Safety & Health)"@en ;
ehs-geo:stateCode "CA" ;
ehs-geo:coverageType "FULL_COVERAGE" ;
ehs-geo:agencyWebsite <https://www.dir.ca.gov/dosh/> ;
ehs-geo:applicabilityNote """Cal/OSHA standards (California Code of Regulations,
Title 8) frequently exceed federal OSHA. Notable differences: California Permissible
Exposure Limits (PELs) are often lower than federal OSHA PELs; California has
unique Aerosol Transmissible Diseases (ATD) standard; California Heat Illness
Prevention standard is more detailed than federal OSHA guidance."""@en.

ehs-geo:BayArea_AQMD rdf:type ehs-geo:CountyAirDistrict ;
rdfs:label "Bay Area Air Quality Management District (BAAQMD)"@en ;
ehs-geo:districtName "Bay Area AQMD" ;
ehs-geo:stateCode "CA" ;
ehs-geo:countiesServed "Alameda, Contra Costa, Marin, Napa, San Francisco, San Mateo, Santa Clara, Solano (part), So
ehs-geo:agencyWebsite <https://www.baaqmd.gov> ;
ehs-geo:applicabilityNote """BAAQMD is the primary air permitting authority for
all stationary sources in the nine-county Bay Area. Regulation 8 governs organic
compounds. New Source Review (NSR) thresholds are lower than federal major source
thresholds. Facilities must obtain an Authority to Construct (ATC) and Permit to
Operate (PTO) from BAAQMD, not from EPA or CalEPA."""@en.

ehs-geo:Alameda_CUPA rdf:type ehs-geo:CertifiedUnifiedProgramAgency ;
rdfs:label "Alameda County CUPA (Environmental Health Services)"@en ;
ehs-geo:stateCode "CA" ;
ehs-geo:countyName "Alameda County" ;
ehs-geo:agencyWebsite <https://ehsd.org/> ;
ehs-geo:applicabilityNote """Alameda County CUPA administers all six unified programs
including the Hazardous Materials Business Plan (HMBP). California HMBP reporting
threshold for most hazardous materials is 55 gallons or 500 lbs — significantly
lower than the federal EPCRA Tier II threshold of 10,000 lbs. HMBP is submitted
electronically to the California Environmental Reporting System (CERS)."""@en.
```

### 9.3 Texas (No State OSHA Plan — Federal OSHA Jurisdiction)

```text
ehs-geo:Texas_TCEQ rdf:type ehs-geo:StateEnvironmentalProgram ;
rdfs:label "Texas Commission on Environmental Quality (TCEQ)"@en ;
ehs-geo:stateCode "TX" ;
ehs-geo:agencyWebsite <https://www.tceq.texas.gov> ;
ehs-geo:applicabilityNote """TCEQ administers Texas air quality program under
Texas Health & Safety Code Chapter 382 (Texas Clean Air Act). Texas is a
NON-State-Plan state for OSHA — federal OSHA has direct jurisdiction.
TCEQ issues state air permits (Standard Permits, Flexible Permits, New Source
Review Permits) that serve as the federally enforceable operating authority.
Tier II reporting in Texas is submitted to TCEQ via the Texas Tier Two Reporting
System (T2RS)."""@en.
```

## 10. Worked Scenarios with Geo-Compliance Overlay

### 10.1 Scenario: Solvent Coating Line in Wayne County, Michigan

**Facility:** Automotive paint shop, 150 employees, Wayne County (Detroit area),
Michigan **Hazard:** ChemicalHazard (xylene, toluene), ErgonomicHazard
(repetitive spray application) **Action:** ProcessingAction (paint spray booth
operation)

#### Federal activation (from v3.1):

- OSHA 29 CFR 1910.1200 (HCS)
- EPA 40 CFR Part 70 (Title V if major source)
- ACGIH TLVs

#### Geo-Compliance overlay (new):

```text
ehs-geo:Scenario_WayneCounty_PaintLine rdf:type ehs-geo:GeoComplianceRequirement ;
rdfs:label "Wayne County, MI — Paint Line Geo-Compliance"@en ;
ehs-geo:resolvedForEstablishment :WayneCounty_PaintShop ;

# State layer — MIOSHA
ehs-geo:jurisdictionalCitation
"MIOSHA Part 301 (Air Contaminants for General Industry) — Michigan-specific PELs; MIOSHA Part 92 (Employee Righ
ehs-geo:exceedsFederalFramework ehs:OSHA_Framework ;

# State layer — EGLE Air Quality
ehs-geo:jurisdictionalCitation
"Michigan Air Pollution Control Rule Part 6 (Emission Limitations) — state RACT requirements for VOC coating ope
ehs-geo:supplementsFederalFramework ehs:EPA_Framework ;
ehs-geo:permitRequired true ;
ehs-geo:contactAgency "EGLE Air Quality Division, SE Michigan District Office" ;
ehs-geo:agencyWebsite <https://www.michigan.gov/egle/about/organization/air-quality> ;

# County layer — no separate AQMD in Michigan (EGLE handles county air)

# City layer (if in Detroit)
ehs-geo:jurisdictionalCitation
"Detroit Fire Prevention Code §3301 — hazardous materials storage and use permit required above local thresholds
ehs-geo:permitRequired true ;
ehs-geo:localThreshold 55 ;
ehs-geo:localThresholdUnit "gallons (flammable liquids)" ;
ehs-geo:hasJurisdictionalRelationship ehs-geo:LocalSupplements.
```

### 10.2 Scenario: Same Facility — Oakland, California

Same paint shop profile, relocated to Alameda County, Oakland, CA

Additional geo-compliance obligations (above federal baseline):

| Layer           | Requirement                                              | Citation                      | Notes                                                     |
| --------------- | -------------------------------------------------------- | ----------------------------- | --------------------------------------------------------- |
| Cal/OSHA        | Stricter VOC PELs                                        | Title 8 CCR §5155             | Xylene Cal PEL (100 ppm) may match or differ from federal |
| Cal/OSHA        | Heat Illness Prevention (spray booth operators)          | Title 8 CCR §3395             | No federal equivalent                                     |
| CalARP          | Accidental Release Prevention (if RMP-covered chemicals) | Health & Safety Code §25531   | State-level RMP analog                                    |
| BAAQMD          | Authority to Construct + Permit to Operate (spray booth) | BAAQMD Regulation 2           | BAAQMD is the permitting authority, not EPA               |
| BAAQMD          | Regulation 8, Rule 16 (Spray Coating Operations)         | BAAQMD R8-16                  | Stricter VOC limits than federal NESHAP                   |
| Alameda CUPA    | Hazardous Materials Business Plan (HMBP)                 | CA H&S Code §25500-25520      | Trigger: 55 gal flammable liquids (vs. 10,000 lb EPCRA)   |
| City of Oakland | Fire Prevention Code hazmat permit                       | Oakland Municipal Code §15.04 | AHJ is Oakland Fire Prevention Bureau                     |

## 11. Implementation Framework

### 11.1 Namespace Declaration for the Extension File

```text
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>.
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
@prefix owl: <http://www.w3.org/2002/07/owl#>.
@prefix xsd: <http://www.w3.org/2001/XMLSchema#>.
@prefix skos: <http://www.w3.org/2004/02/skos/core#>.
@prefix dcterms: <http://purl.org/dc/terms/>.
@prefix ehs: <http://example.org/ehs-ontology#>.
@prefix ehs-geo: <http://example.org/ehs-geo-compliance#>.

<http://example.org/ehs-geo-compliance> rdf:type owl:Ontology ;
owl:imports <http://example.org/ehs-ontology> ;
dcterms:title "EHS Ontology: Geo-Compliance Extension"@en ;
dcterms:description "Extension to EHS Ontology v3.1 adding sub-federal jurisdictional layers for state, county, and
owl:versionInfo "1.0".
```

### 11.2 Phased Rollout Plan

| Phase   | Scope                                            | Effort | Outcome                                                                                   |
| ------- | ------------------------------------------------ | ------ | ----------------------------------------------------------------------------------------- |
| Phase 1 | State OSHA Plan / No-Plan flag                   | Low    | Determines whether state or federal OSHA citations apply to each facility                 |
| Phase 2 | State environmental program (50 state agencies)  | Medium | Enables state air permit, state chemical reporting, and state water permit identification |
| Phase 3 | Major county air districts (top 25 AQMDs/APCDs)  | Medium | Covers ~80% of industrial facilities in air nonattainment areas                           |
| Phase 4 | California CUPA program (58 California counties) | Medium | Critical for CA facilities — HMBP replaces/supplements EPCRA for CA                       |
| Phase 5 | City fire department hazmat permit thresholds    | High   | Wide variation; populate for top 50 industrial cities first                               |
| Phase 6 | City-level chemical use ordinances               | High   | Limited to progressive cities (SF, Chicago, Seattle, etc.)                                |

### 11.3 Data Population Strategy

The extension is designed to be populated from three source types:

1. Static Lookup Tables (State-Level)

Populate once; update as regulations change. Cover:

- OSHA State Plan status for all 50 states + territories
- State environmental agency name, URL, and primary program
- State-specific right-to-know thresholds

2. API-Driven Resolution (County/City)

Use geocoding + boundary APIs to dynamically assign jurisdictions:

- U.S. Census Geocoding API -> FIPS code -> state + county
- EPA Facility Registry System (FRS) -> existing regulatory IDs
- ECHO (EPA Enforcement and Compliance History Online) -> permit linkages

3. Expert-Curated Requirement Instances

For specific high-impact requirements (Bay Area AQMD R8-16, Cal/OSHA ATD
standard, NJ TCPA), hand-curate GeoComplianceRequirement instances with precise
citations, thresholds, and deadlines.

## 12. SPARQL Query Patterns

### 12.1 Get All Compliance Requirements for a Facility

```text
PREFIX ehs: <http://example.org/ehs-ontology#>
PREFIX ehs-geo: <http://example.org/ehs-geo-compliance#>

SELECT ?layer ?requirement ?citation ?contactAgency ?permitRequired
WHERE {
?establishment a ehs:Establishment ;
ehs-geo:hasJurisdiction ?jurisdiction.
?jurisdiction ehs-geo:composedOf ?layer.
?layer ehs-geo:activatesGeoRequirement ?requirement.
OPTIONAL { ?requirement ehs-geo:jurisdictionalCitation ?citation }
OPTIONAL { ?requirement ehs-geo:contactAgency ?contactAgency }
OPTIONAL { ?requirement ehs-geo:permitRequired ?permitRequired }
}
ORDER BY ?layer
```

### 12.2 Find State Plans That Exceed Federal OSHA for a Given Hazard

### Type

```text
SELECT ?stateReq ?citation ?exceedsFramework
WHERE {
?stateReq a ehs-geo:StateRequirement ;
ehs-geo:requirementTriggeredBy ehs:ChemicalHazard ;
ehs-geo:exceedsFederalFramework ?exceedsFramework ;
ehs-geo:jurisdictionalCitation ?citation.
}
```

### 12.3 Check Whether a Facility Needs a Local Hazmat Permit

```text
SELECT ?facility ?city ?threshold ?unit
WHERE {
?facility a ehs:Establishment ;
ehs-geo:hasJurisdiction ?j.
?j ehs-geo:composedOf ?layer.
?layer a ehs-geo:CityFireDepartment.
?layer ehs-geo:activatesGeoRequirement ?req.
?req ehs-geo:permitRequired true ;
ehs-geo:localThreshold ?threshold ;
ehs-geo:localThresholdUnit ?unit.
OPTIONAL { ?j ehs-geo:inCity ?city }
}
```

## 13. Integration with Existing Ontology Hooks

### 13.1 Wiring into ehs:Establishment (v3.1)

The v3.1 ehs:Establishment class is already the facility anchor. The extension
adds one new outgoing

**property:**

```text
ehs:Establishment
├── [existing] ehs:hasNAICSCode
├── [existing] ehs:hasEstablishmentSize
├── [existing] ehs:hasChemicalInventory
├── [existing] ehs:hasTRIObligation
└── [NEW] ehs-geo:hasJurisdiction → ehs-geo:FacilityJurisdiction
```

### 13.2 Wiring into ehs:ContextualComplianceActivation (v3.1)

The federal routing class gains one new outgoing property:

```text
ehs:ContextualComplianceActivation
├── [existing] ehs:triggeredByType
├── [existing] ehs:hasActionContext
├── [existing] ehs:hasContextCondition
├── [existing] ehs:activatesFramework
├── [existing] ehs:specificCitation
└── [NEW] ehs-geo:hasGeoActivation → ehs-geo:GeoComplianceRequirement
```

### 13.3 Wiring into WorkplaceLocation (v3.1)

The existing `ehs:WorkplaceLocation` class notes that location is a context. The
extension promotes location from a qualitative descriptor to a full
jurisdictional anchor:

```text
ehs:WorkplaceLocation (existing subclass of WorkProcess)
→ serves as the semantic precursor to ehs-geo:FacilityJurisdiction
→ The geo extension operationalizes WorkplaceLocation into regulatory triggers
```

## 14. Design Decisions & Rationale

| Decision                                                       | Rationale                                                                                                                                                                                                                                                                                 |
| -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Separate ehs-geo: namespace                                    | Preserves backwards compatibility. v3.1 ontology is unmodified; the extension is imported on top.                                                                                                                                                                                         |
| FacilityJurisdiction as a bridge class                         | Allows a single property (ehs-geo:hasJurisdiction) to link Establishment to all layers without polluting the Establishment class with dozens of new properties.                                                                                                                           |
| Three-tier layer model (State, County, City)                   | Matches U.S. governmental structure. Special districts (AQMDs, fire districts) are modeled as subtypes of the nearest tier.                                                                                                                                                               |
| Conflict resolution as a typed relationship                    | StatePreempts, LocalSupplements, and MostStringentApplies are first-class classes, not free-text notes. This enables SPARQL queries to automatically filter requirements based on conflict rules.                                                                                         |
| GeoComplianceRequirement distinct from ehs:RegulatoryFramework | Federal frameworks are law-body level (OSHA_Framework, PA_Framework). Geo requirements are instance-specific — they represent the precise obligation at a particular place. This distinction mirrors the v3.1 distinction between RegulatoryFramework and ContextualComplianceActivation. |
| Geocoordinate support                                          | Enables future API automation for jurisdiction lookup. Regulators' digital boundaries (TIGER shapefiles, AQMD district boundaries) can be used to auto-populate FacilityJurisdiction from an address.                                                                                     |

## 15. Future Extensions

| Extension                      | Description                                                                                                                                                   |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Non-attainment area classifier | Mark CountyAirDistrict instances with NAAQS non-attainment status (O3, PM2.5, SO2) to trigger NSR and offset requirements.                                    |
| Tribal jurisdiction            | Add ehs-geo:TribalJurisdiction for facilities on or adjacent to tribal lands (EPA retains direct authority on most reservations).                             |
| Coastal/Port zone              | Add ehs-geo:CoastalZoneJurisdiction to trigger USCG and state coastal commission requirements for waterfront facilities.                                      |
| Environmental Justice overlay  | Link facility jurisdiction to EPA EJScreen census tract scores to flag heightened scrutiny and community notification obligations.                            |
| Temporal validity              | Add ehs-geo:effectiveDate and ehs-geo:expirationDate to GeoComplianceRequirement instances to model regulatory change over time.                              |
| Permit linkage                 | Add a ehs-geo:existingPermit class to track the actual permit numbers issued by each jurisdictional authority, linking requirements to real permit documents. |

## Appendix A: OSHA State Plan Reference Table

**State OSHA Coverage**

| State          | Coverage    | Agency              | Key Unique Standard(s)                                       |
| -------------- | ----------- | ------------------- | ------------------------------------------------------------ |
| California     | Full        | Cal/OSHA (DIR/DOSH) | Heat Illness Prevention (§3395), ATD Standard, stricter PELs |
| Michigan       | Full        | MIOSHA (LEO)        | Part 92 Right-to-Know, noise standards                       |
| Washington     | Full        | L&I/WISHA           | Stricter field sanitation, WAC 296 series                    |
| Oregon         | Full        | OR-OSHA             | Ergonomics standard (still in effect)                        |
| Virginia       | Full        | VA DOLI             | Heat Illness standard                                        |
| North Carolina | Full        | NCDOL OSH           | Trench safety                                                |
| New York       | Public only | PESH (NYS DOL)      | State/local government workers only                          |
| New Jersey     | Public only | NJDOL PEOSH         | State/local government workers only                          |
| Texas          | None        | Federal OSHA direct | No State Plan                                                |
| Florida        | None        | Federal OSHA direct | No State Plan                                                |
| Ohio           | None        | Federal OSHA direct | No State Plan                                                |

**Appendix B: State Chemical Inventory / Right-to-Know Programs (Beyond EPCRA)**

| State         | Program                            | Threshold Difference                                 | Submission System         |
| ------------- | ---------------------------------- | ---------------------------------------------------- | ------------------------- |
| California    | HMBP (Health & Safety Code §25500) | 55 gal or 500 lbs (vs. 10,000 lbs EPCRA)             | CERS (cers.calepa.ca.gov) |
| New Jersey    | NJRTK Survey (NJRTK Act)           | Worker right-to-know reporting distinct from EPCRA   | NJDEP online              |
| Massachusetts | TURA Toxic Use Reduction Act       | Chemical use reduction planning for listed chemicals | TURA Online               |
| Illinois      | Emergency Management Act (IEMA)    | Mirrors EPCRA but with IEMA as recipient             | IEMA TIER2 Submit         |
| Pennsylvania  | PAEPCRA Right-to-Know              | SDS and annual survey to PA DEP                      | PA DEP eFACTS             |
