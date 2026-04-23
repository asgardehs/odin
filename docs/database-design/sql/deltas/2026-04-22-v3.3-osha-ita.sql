-- Delta: v3.3 OSHA ITA support
-- ============================
-- Brings pre-v3.3 databases up to the shape module_c_osha300.sql
-- expresses after Phases 4a.2 + 4a.3.1. Fresh installs run module_c
-- with all this content inline; existing installs that were first
-- created before v3.3 missed the additions and need this delta to
-- catch up.
--
-- All statements here are idempotent on their own or (for ALTER TABLE
-- ADD COLUMN) made idempotent by the delta runner's pragma_table_info
-- guard. Running this delta on a fresh install is a no-op.


-- === ITA lookup tables (5) + seed data ===================================

CREATE TABLE IF NOT EXISTS ita_establishment_sizes (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_reference TEXT NOT NULL,
    min_employees INTEGER,
    max_employees INTEGER
);

INSERT OR IGNORE INTO ita_establishment_sizes (code, name, description, cfr_reference, min_employees, max_employees) VALUES
    ('SMALL',  'Small (≤ 19 employees)',  'Partially exempt from 29 CFR 1904 recordkeeping unless in a non-partially-exempt industry. Not required to submit electronically via ITA.', '29 CFR 1904.1(a)(1); 29 CFR 1904.41', NULL, 19),
    ('MEDIUM', 'Medium (20–249 employees)', 'Must submit 300A summary electronically via ITA if in a designated high-hazard industry (29 CFR 1904.41 Appendix A).', '29 CFR 1904.41(a)(2)', 20, 249),
    ('LARGE',  'Large (≥ 250 employees)',  'Must submit full 300 Log, 300A summary, AND 301 Incident Reports electronically via ITA regardless of industry.', '29 CFR 1904.41(a)(1)', 250, NULL);

CREATE TABLE IF NOT EXISTS ita_establishment_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_reference TEXT NOT NULL
);

INSERT OR IGNORE INTO ita_establishment_types (code, name, description, cfr_reference) VALUES
    ('PRIVATE',   'Private Industry', 'Non-governmental employer. Default federal OSHA jurisdiction unless superseded by an approved State Plan.',                                                              'OSH Act of 1970, Section 3(5); 29 CFR 1975'),
    ('STATE_GOV', 'State Government', 'State-level government employer. Covered ONLY in states with OSHA-approved State Plans — federal OSHA has no jurisdiction over state government employees.',           'OSH Act Section 3(5); 29 CFR 1956'),
    ('LOCAL_GOV', 'Local Government', 'County, city, or other political-subdivision government employer. Same State Plan coverage logic as state government — federal OSHA has no jurisdiction.',            'OSH Act Section 3(5); 29 CFR 1956');

CREATE TABLE IF NOT EXISTS ita_treatment_facility_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL
);

INSERT OR IGNORE INTO ita_treatment_facility_types (code, name, description) VALUES
    ('HOSPITAL_ER',  'Hospital Emergency Room',       'Emergency department of a hospital; acute unscheduled care.'),
    ('HOSPITAL_OP',  'Hospital Outpatient Clinic',    'Scheduled non-emergency care at a hospital-affiliated outpatient clinic.'),
    ('PHYSICIAN',    'Physician''s Office',           'Private physician''s office, non-hospital-affiliated, not specialized for occupational medicine.'),
    ('URGENT_CARE',  'Urgent Care Center',            'Walk-in urgent-care facility providing non-emergency acute care without appointment.'),
    ('OCC_HEALTH',   'Occupational Health Clinic',    'Clinic specializing in work-related injury and illness, typically under employer contract.'),
    ('OTHER',        'Other Facility',                'A medical facility not matching any other category (e.g. on-site first-aid room with a nurse, ambulance-only treatment).'),
    ('UNKNOWN',      'Unknown',                       'Treatment facility not known at time of 301 completion. Acceptable only for backfilled historical records.');

CREATE TABLE IF NOT EXISTS ita_incident_outcomes (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    cfr_reference TEXT NOT NULL,
    ita_csv_column TEXT
);

INSERT OR IGNORE INTO ita_incident_outcomes (code, name, description, cfr_reference, ita_csv_column) VALUES
    ('DEATH',                    'Death',                        'Work-related fatality. Also triggers 8-hour notification under 29 CFR 1904.39.',                                                                    '29 CFR 1904.7(b)(2)',                  'G'),
    ('DAYS_AWAY',                'Days Away From Work',          'Case involves one or more calendar days away from work beyond the day of the event. 180-day cap per 1904.7(b)(3)(v).',                            '29 CFR 1904.7(b)(3)',                  'H'),
    ('JOB_TRANSFER_RESTRICTION', 'Job Transfer or Restriction',  'Restricted work or transfer to another job, no days away beyond event day. 180-day cap per 1904.7(b)(4)(iii).',                                 '29 CFR 1904.7(b)(4)',                  'I'),
    ('OTHER_RECORDABLE',         'Other Recordable',             'Recordable case not meeting death, days-away, or restriction thresholds — typically medical treatment beyond first aid only.',                   '29 CFR 1904.7(b)(5); 1904.7(b)(6)-(10)', 'J');

CREATE TABLE IF NOT EXISTS ita_incident_types (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    osha_300_column TEXT NOT NULL
);

INSERT OR IGNORE INTO ita_incident_types (code, name, description, osha_300_column) VALUES
    ('INJURY',                 'Injury',                  'Physical wound or damage to the body from a workplace event.',                                   'F'),
    ('SKIN_DISORDER',          'Skin Disorder',           'Occupational skin illness.',                                                                     'M1'),
    ('RESPIRATORY_CONDITION',  'Respiratory Condition',   'Occupational respiratory illness.',                                                              'M2'),
    ('POISONING',              'Poisoning',               'Systemic illness from absorbed toxic substances.',                                               'M3'),
    ('HEARING_LOSS',           'Hearing Loss',            'Standard Threshold Shift per 29 CFR 1904.10.',                                                   'M4'),
    ('OTHER_ILLNESS',          'All Other Illnesses',     'Occupational illness not matching skin, respiratory, poisoning, or hearing-loss categories.',   'M5');


-- === ITA mapping tables (2) + seed data ==================================

CREATE TABLE IF NOT EXISTS ita_outcome_mapping (
    severity_code TEXT PRIMARY KEY,
    ita_outcome_code TEXT NOT NULL,
    cfr_reference TEXT NOT NULL,
    notes TEXT,
    FOREIGN KEY (severity_code) REFERENCES incident_severity_levels(code),
    FOREIGN KEY (ita_outcome_code) REFERENCES ita_incident_outcomes(code)
);

INSERT OR IGNORE INTO ita_outcome_mapping (severity_code, ita_outcome_code, cfr_reference, notes) VALUES
    ('FATALITY',   'DEATH',                    '29 CFR 1904.7(b)(2)', 'Also triggers 8-hour OSHA notification per 1904.39 — independent of ITA cycle.'),
    ('LOST_TIME',  'DAYS_AWAY',                '29 CFR 1904.7(b)(3)', 'Day-count cap of 180 days applies.'),
    ('RESTRICTED', 'JOB_TRANSFER_RESTRICTION', '29 CFR 1904.7(b)(4)', 'Day-count cap of 180 days shared with LOST_TIME across the life of one case.'),
    ('MEDICAL_TX', 'OTHER_RECORDABLE',         '29 CFR 1904.7(b)(5)', 'Medical treatment beyond first aid is the most common occupant of the OTHER_RECORDABLE bucket.');

CREATE TABLE IF NOT EXISTS ita_case_type_mapping (
    case_classification_code TEXT PRIMARY KEY,
    ita_case_type_code TEXT NOT NULL,
    FOREIGN KEY (case_classification_code) REFERENCES case_classifications(code),
    FOREIGN KEY (ita_case_type_code) REFERENCES ita_incident_types(code)
);

INSERT OR IGNORE INTO ita_case_type_mapping (case_classification_code, ita_case_type_code) VALUES
    ('INJURY',     'INJURY'),
    ('SKIN',       'SKIN_DISORDER'),
    ('RESP',       'RESPIRATORY_CONDITION'),
    ('POISON',     'POISONING'),
    ('HEARING',    'HEARING_LOSS'),
    ('OTHER_ILL',  'OTHER_ILLNESS');


-- === New columns on establishments (4) ===================================
-- Delta runner guards each ALTER with pragma_table_info; re-running
-- against a fresh install where the column was already created in
-- module_c_osha300.sql is a no-op.

ALTER TABLE establishments ADD COLUMN ein TEXT;
ALTER TABLE establishments ADD COLUMN company_name TEXT;
ALTER TABLE establishments ADD COLUMN size_code TEXT REFERENCES ita_establishment_sizes(code);
ALTER TABLE establishments ADD COLUMN establishment_type_code TEXT REFERENCES ita_establishment_types(code);


-- === New columns on incidents (6) ========================================

ALTER TABLE incidents ADD COLUMN treatment_facility_type_code TEXT REFERENCES ita_treatment_facility_types(code);
ALTER TABLE incidents ADD COLUMN days_away_from_work INTEGER;
ALTER TABLE incidents ADD COLUMN days_restricted_or_transferred INTEGER;
ALTER TABLE incidents ADD COLUMN date_of_death TEXT;
ALTER TABLE incidents ADD COLUMN time_unknown INTEGER DEFAULT 0;
ALTER TABLE incidents ADD COLUMN injury_illness_description TEXT;
