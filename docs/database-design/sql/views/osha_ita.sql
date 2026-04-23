-- OSHA ITA export views
-- =====================
-- Re-executed on every odin startup by database.LoadViews. Views live
-- here instead of inside module_c_osha300.sql because the migration
-- runner applies module migrations exactly once (tracked in _migrations),
-- and view definitions evolve more often than the underlying tables.
-- Putting views in this re-run path means a pulled change to a view
-- body takes effect on next server restart without requiring a
-- nuke-and-resplat of the dev DB.
--
-- All view files under sql/views/ follow the same pattern: DROP VIEW
-- IF EXISTS + CREATE VIEW. Statements are idempotent.


-- ============================================================================
-- VIEW: v_osha_ita_detail
-- ============================================================================
-- Source for the ITA detail CSV export (one row per recordable incident,
-- combining old 300 Log and 301 Incident Report fields).
--
-- Exporter reads this view directly; business logic (severity → ITA outcome,
-- case classification → ITA type) is resolved here via the mapping tables,
-- not in Go. If OSHA reclassifies an ITA code, update the mapping table and
-- every downstream consumer picks up the change without a rebuild.
--
-- Filters to OSHA-recordable incidents only (inner-joined to
-- ita_outcome_mapping). Non-recordable severities are excluded by design —
-- their absence from the mapping table is the normative statement.

DROP VIEW IF EXISTS v_osha_ita_detail;
CREATE VIEW v_osha_ita_detail AS
SELECT
    -- 24 ITA CSV columns in spec order. Go exporter SELECTs these by
    -- name to guarantee CSV column order regardless of view layout.
    est.name                                  AS establishment_name,     -- 1
    strftime('%Y', i.incident_date)           AS year_of_filing,         -- 2
    i.case_number                             AS case_number,             -- 3
    emp.job_title                             AS job_title,               -- 4
    i.incident_date                           AS date_of_incident,        -- 5
    i.location_description                    AS incident_location,       -- 6
    i.incident_description                    AS incident_description,    -- 7
    iio.name                                  AS incident_outcome,        -- 8
    i.days_away_from_work                     AS dafw_num_away,           -- 9
    i.days_restricted_or_transferred          AS djtr_num_tr,             -- 10
    iit.name                                  AS type_of_incident,        -- 11
    emp.date_of_birth                         AS date_of_birth,           -- 12
    emp.date_hired                            AS date_of_hire,            -- 13
    emp.gender                                AS sex,                     -- 14
    tft.name                                  AS treatment_facility_type, -- 15
    CASE WHEN i.was_hospitalized = 1 THEN 'Y' ELSE 'N' END
                                              AS treatment_in_patient,    -- 16
    i.time_employee_began_work                AS time_started_work,       -- 17
    i.incident_time                           AS time_of_incident,        -- 18
    CASE WHEN i.time_unknown = 1 THEN 'Y' ELSE 'N' END
                                              AS time_unknown,            -- 19
    i.activity_description                    AS nar_before_incident,     -- 20
    i.incident_description                    AS nar_what_happened,       -- 21
    i.injury_illness_description              AS nar_injury_illness,      -- 22
    i.object_or_substance                     AS nar_object_substance,    -- 23
    i.date_of_death                           AS date_of_death,           -- 24

    -- Auxiliary filter columns (NOT emitted in CSV; used by Go
    -- exporter's WHERE clause). Keeping them inside the view lets the
    -- filter live next to the shape.
    i.establishment_id                        AS establishment_id,
    i.id                                      AS incident_id
FROM incidents i
-- INNER JOIN: only OSHA-recordable severities flow to ITA.
-- Non-recordable severities (FirstAid / NearMiss / PropertyDamage /
-- Environmental) have no row in ita_outcome_mapping and are filtered
-- out here by design. This matches the ontology's "absence-is-
-- normative" SKOS modeling from v3.3.
INNER JOIN ita_outcome_mapping iom
    ON iom.severity_code = i.severity_code
INNER JOIN ita_incident_outcomes iio
    ON iio.code = iom.ita_outcome_code
LEFT JOIN ita_case_type_mapping itm
    ON itm.case_classification_code = i.case_classification_code
LEFT JOIN ita_incident_types iit
    ON iit.code = itm.ita_case_type_code
INNER JOIN establishments est
    ON est.id = i.establishment_id
LEFT JOIN employees emp
    ON emp.id = i.employee_id
LEFT JOIN ita_treatment_facility_types tft
    ON tft.code = i.treatment_facility_type_code;


-- ============================================================================
-- VIEW: v_osha_ita_summary
-- ============================================================================
-- Source for the ITA summary CSV export (one row per establishment + year,
-- equivalent to the OSHA 300A annual summary).
--
-- Aggregates recordable incidents by outcome. Establishments with zero
-- recordables in a given year do NOT appear in this view — the Go exporter
-- handles that fallback by synthesizing a zero-row with
-- no_injuries_illnesses='Y'.

DROP VIEW IF EXISTS v_osha_ita_summary;
CREATE VIEW v_osha_ita_summary AS
SELECT
    -- 28 ITA summary CSV columns in spec order. Go exporter SELECTs
    -- these by name to guarantee CSV column order.
    est.name                                                                    AS establishment_name,         -- 1
    est.ein                                                                     AS ein,                         -- 2
    est.company_name                                                            AS company_name,                -- 3
    est.street_address                                                          AS street_address,              -- 4
    est.city                                                                    AS city,                        -- 5
    est.state                                                                   AS state,                       -- 6
    est.zip                                                                     AS zip,                         -- 7
    est.naics_code                                                              AS naics_code,                  -- 8
    est.industry_description                                                    AS industry_description,        -- 9
    ies.name                                                                    AS size,                        -- 10
    iet.name                                                                    AS establishment_type,          -- 11
    strftime('%Y', i.incident_date)                                             AS year_filing_for,             -- 12
    est.annual_avg_employees                                                    AS annual_average_employees,    -- 13
    est.total_hours_worked                                                      AS total_hours_worked,          -- 14

    -- no_injuries_illnesses: 'Y' when zero recordable incidents for this
    -- (establishment, year) combo. Establishments with zero incidents in a
    -- year do not appear in this view at all — the Go exporter handles
    -- that fallback by synthesizing a zero-row with no_injuries_illnesses='Y'
    -- when the query returns no rows.
    CASE WHEN COUNT(*) = 0 THEN 'Y' ELSE 'N' END                                AS no_injuries_illnesses,       -- 15

    -- Case counts by ITA outcome
    SUM(CASE WHEN iom.ita_outcome_code = 'DEATH'                    THEN 1 ELSE 0 END) AS total_deaths,          -- 16
    SUM(CASE WHEN iom.ita_outcome_code = 'DAYS_AWAY'                THEN 1 ELSE 0 END) AS total_dafw_cases,      -- 17
    SUM(CASE WHEN iom.ita_outcome_code = 'JOB_TRANSFER_RESTRICTION' THEN 1 ELSE 0 END) AS total_djtr_cases,      -- 18
    SUM(CASE WHEN iom.ita_outcome_code = 'OTHER_RECORDABLE'         THEN 1 ELSE 0 END) AS total_other_cases,     -- 19

    -- Day-sum totals (nulls treated as 0)
    SUM(COALESCE(i.days_away_from_work, 0))                                     AS total_dafw_days,             -- 20
    SUM(COALESCE(i.days_restricted_or_transferred, 0))                          AS total_djtr_days,             -- 21

    -- Case counts by ITA type (1:1 with case_classification)
    SUM(CASE WHEN itm.ita_case_type_code = 'INJURY'                 THEN 1 ELSE 0 END) AS total_injuries,                -- 22
    SUM(CASE WHEN itm.ita_case_type_code = 'SKIN_DISORDER'          THEN 1 ELSE 0 END) AS total_skin_disorders,          -- 23
    SUM(CASE WHEN itm.ita_case_type_code = 'RESPIRATORY_CONDITION'  THEN 1 ELSE 0 END) AS total_respiratory_conditions,  -- 24
    SUM(CASE WHEN itm.ita_case_type_code = 'POISONING'              THEN 1 ELSE 0 END) AS total_poisonings,              -- 25
    SUM(CASE WHEN itm.ita_case_type_code = 'HEARING_LOSS'           THEN 1 ELSE 0 END) AS total_hearing_loss,            -- 26
    SUM(CASE WHEN itm.ita_case_type_code = 'OTHER_ILLNESS'          THEN 1 ELSE 0 END) AS total_other_illnesses,         -- 27

    -- change_reason: free-text explanation when submission is an amendment.
    -- odin has no amendment tracking yet; always NULL. Add when amendment
    -- flow is built.
    NULL                                                                        AS change_reason,               -- 28

    -- Auxiliary filter column (NOT emitted in CSV). Go exporter uses
    -- establishment_id + year_filing_for in WHERE clauses.
    est.id                                                                      AS establishment_id
FROM establishments est
-- INNER JOIN: only (establishment, year) combos with at least one
-- recordable incident appear in this view. Exporter emits a synthesized
-- "no injuries or illnesses" row when a specific (establishment_id,
-- year_filing_for) combo returns no rows.
INNER JOIN incidents i
    ON i.establishment_id = est.id
INNER JOIN ita_outcome_mapping iom
    ON iom.severity_code = i.severity_code
LEFT JOIN ita_case_type_mapping itm
    ON itm.case_classification_code = i.case_classification_code
LEFT JOIN ita_establishment_sizes ies
    ON ies.code = est.size_code
LEFT JOIN ita_establishment_types iet
    ON iet.code = est.establishment_type_code
GROUP BY est.id, strftime('%Y', i.incident_date);
