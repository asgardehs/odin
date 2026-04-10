# Air Permits Module — Design Decisions

**Date:** 2025-12-01  
**Status:** Ready for schema implementation

---

## Core Architecture

The air emissions module follows the established pattern from other Waypoint modules: `material_usage` serves as the anchor table, with source-specific detail tables extending it only where process variables affect calculations.

---

## Detail Table Strategy

**Tables needed:**

| Source Category | Detail Table | Reason |
|-----------------|--------------|--------|
| welding | `welding_details` | Process, electrode, base metal affect factor selection |
| coating | `coating_details` | Transfer efficiency directly changes emission calculation |
| combustion | `combustion_details` | Equipment type drives factor selection |

**No detail table needed:**

| Source Category | Reason |
|-----------------|--------|
| electrocoat | Calculation is `replenishment_gallons × VOC_content` — no process variables affect the math |

---

## Electrocoat Handling

Electrocoat emissions come from the cure oven, not application. The emission pathway:

```
bath_replenishment → deposited_on_parts → volatilized_at_cure
```

Bath replenishment rate is the proxy for deposited coating. All replenishment is treated as deposited-then-cured (dragout not tracked separately).

**Implementation:**
- `emission_unit.source_category = 'electrocoat'`
- `coating_details.application_method` includes `electrocoat` as an option
- View calculates: `quantity_used × VOC_content = emissions`
- No transfer efficiency adjustment (unlike spray coating)

Per-bath tracking for multiple e-coat lines is an edge case not currently in scope.

---

## Material Properties

Using key-value approach with `material_properties` table:
- Flexible for varying property types across material categories
- `effective_date` supports reformulated products and supplier changes
- Trade-off: requires JOINs/pivots for multi-property queries — acceptable for reporting flexibility

---

## Factor Matching

Detail tables store granular fields (electrode_type, electrode_diameter, base_metal, shielding_gas) even though the default view won't match on all of them.

**Rationale:** Data is captured for power users who need electrode-specific factors. Default matching uses `source_category` + `process_type`. More granular matching can be added later without schema changes.

---

## Implementation Order

1. `emission_units` and `stacks`
2. `emission_materials` and `material_properties`
3. `emission_factors`
4. `material_usage` and detail tables
5. `control_devices` and related tables
6. `calculated_emissions` and reporting tables
7. Views

---

## Open Items

None currently — ready to proceed with schema.
