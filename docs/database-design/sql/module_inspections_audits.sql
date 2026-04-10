-- Module: Inspections & Audits
-- Derived from ehs-ontology-v3.1.ttl — ehs:Evaluation (5 E's) + ehs:Confirm (ARECC)
--
-- Ontology alignment:
--   Inspections operationalize ehs:Evaluation — "continuous measurement and improvement
--   using lagging and leading indicators." A completed inspection IS a leading indicator.
--   Audits operationalize ehs:Confirm — "verifying that controls are effective."
--   Together they close the ARECC loop: hazards are Anticipated, Recognized, Evaluated,
--   Controlled, and then CONFIRMED through inspections and audits.
--
-- Design principle: inspections and audits DISCOVER issues. Corrective actions RESOLVE
-- them. This module owns the discovery; corrective_actions (Module C/D) owns the fix.
-- Findings link to corrective_actions via FK rather than duplicating CAR tracking.
--
-- Regulatory/Standard References:
--   EPA SWPPP    — Stormwater Pollution Prevention Plan inspections (NPDES CGP)
--   EPA SPCC     — Spill Prevention, Control & Countermeasure inspections (40 CFR 112)
--   ISO 14001    — Environmental Management System (clause 9.1, 9.2)
--   ISO 45001    — Occupational Health & Safety Management System (clause 9.1, 9.2)
--   ISO 50001    — Energy Management System (clause 9.1, 9.2)
--   OSHA various — Fire extinguishers (1910.157), eyewash (ANSI Z358.1), forklifts (1910.178)
--
-- Cross-module references (these tables are defined elsewhere):
--   establishments       — module_c_osha300.sql (shared foundation)
--   employees            — module_c_osha300.sql (shared foundation)
--   incidents            — module_c_osha300.sql (Module D event records)
--   corrective_actions   — module_c_osha300.sql (Module D corrective action lifecycle)
--   hazard_type_codes    — module_training.sql (ontology hazard type taxonomy)
--   work_areas           — module_training.sql (facility work area definitions)
--   training_regulatory_requirements — module_training.sql (competence requirements)


-- ============================================================================
-- REFERENCE: ISO STANDARDS (management systems audited against)
-- ============================================================================
-- The three ISO management system standards relevant to EHS.
-- Audits evaluate conformity to these standards' requirements.

CREATE TABLE IF NOT EXISTS iso_standards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    standard_code TEXT NOT NULL UNIQUE,         -- '14001', '45001', '50001'
    standard_name TEXT NOT NULL,
    full_title TEXT,
    current_version TEXT,                       -- '2015', '2018', '2018'
    description TEXT,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO iso_standards (id, standard_code, standard_name, full_title, current_version, description) VALUES
    (1, '14001', 'ISO 14001', 'Environmental Management Systems - Requirements with guidance for use', '2015',
        'Specifies requirements for an environmental management system (EMS)'),
    (2, '45001', 'ISO 45001', 'Occupational Health and Safety Management Systems - Requirements with guidance for use', '2018',
        'Specifies requirements for an occupational health and safety (OH&S) management system'),
    (3, '50001', 'ISO 50001', 'Energy Management Systems - Requirements with guidance for use', '2018',
        'Specifies requirements for establishing, implementing, maintaining and improving an energy management system');


-- ============================================================================
-- REFERENCE: ISO CLAUSES (clause structure for each standard)
-- ============================================================================
-- Allows tracking audit findings to specific clauses.
-- Only including main clauses and first-level subclauses for practical use.
-- Ontology note: clause 9 (Performance Evaluation) maps directly to ehs:Evaluation;
-- clause 10.2 (Nonconformity and corrective action) maps to ehs:Confirm.

CREATE TABLE IF NOT EXISTS iso_clauses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    standard_id INTEGER NOT NULL,

    clause_number TEXT NOT NULL,                -- '4.1', '6.1.2', '10.2'
    clause_title TEXT NOT NULL,
    parent_clause TEXT,                         -- '6.1' for '6.1.2'
    clause_level INTEGER DEFAULT 1,            -- 1=main, 2=sub, 3=sub-sub

    description TEXT,

    -- For audit planning — typical audit time/focus
    typical_evidence TEXT,                      -- What auditors typically look for

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (standard_id) REFERENCES iso_standards(id),
    UNIQUE(standard_id, clause_number)
);

CREATE INDEX IF NOT EXISTS idx_iso_clauses_standard ON iso_clauses(standard_id);
CREATE INDEX IF NOT EXISTS idx_iso_clauses_number ON iso_clauses(clause_number);


-- ============================================================================
-- ISO 14001:2015 CLAUSES (Environmental Management)
-- ============================================================================

INSERT OR IGNORE INTO iso_clauses (standard_id, clause_number, clause_title, parent_clause, clause_level, typical_evidence) VALUES
    -- Clause 4: Context of the Organization
    (1, '4', 'Context of the organization', NULL, 1, NULL),
    (1, '4.1', 'Understanding the organization and its context', '4', 2, 'Internal/external issues register, SWOT analysis'),
    (1, '4.2', 'Understanding the needs and expectations of interested parties', '4', 2, 'Interested parties register, compliance obligations'),
    (1, '4.3', 'Determining the scope of the EMS', '4', 2, 'Documented scope statement, site boundaries'),
    (1, '4.4', 'Environmental management system', '4', 2, 'EMS manual or documented information, process interactions'),

    -- Clause 5: Leadership
    (1, '5', 'Leadership', NULL, 1, NULL),
    (1, '5.1', 'Leadership and commitment', '5', 2, 'Management review minutes, resource allocation records'),
    (1, '5.2', 'Environmental policy', '5', 2, 'Signed policy, communication records, employee awareness'),
    (1, '5.3', 'Organizational roles, responsibilities and authorities', '5', 2, 'Org chart, job descriptions, appointment letters'),

    -- Clause 6: Planning
    (1, '6', 'Planning', NULL, 1, NULL),
    (1, '6.1', 'Actions to address risks and opportunities', '6', 2, 'Risk register, opportunities log'),
    (1, '6.1.1', 'General', '6.1', 3, 'Planning documentation showing risk-based thinking'),
    (1, '6.1.2', 'Environmental aspects', '6.1', 3, 'Aspects/impacts register, significance criteria, LCA considerations'),
    (1, '6.1.3', 'Compliance obligations', '6.1', 3, 'Legal register, compliance evaluation records'),
    (1, '6.1.4', 'Planning action', '6.1', 3, 'Action plans for significant aspects and compliance'),
    (1, '6.2', 'Environmental objectives and planning to achieve them', '6', 2, 'Objectives register, action plans, KPIs'),
    (1, '6.2.1', 'Environmental objectives', '6.2', 3, 'SMART objectives aligned with policy'),
    (1, '6.2.2', 'Planning actions to achieve environmental objectives', '6.2', 3, 'Action plans with responsibilities, resources, timelines'),

    -- Clause 7: Support
    (1, '7', 'Support', NULL, 1, NULL),
    (1, '7.1', 'Resources', '7', 2, 'Budget allocation, staffing records, equipment'),
    (1, '7.2', 'Competence', '7', 2, 'Training records, competency assessments, qualifications'),
    (1, '7.3', 'Awareness', '7', 2, 'Training records, toolbox talks, communication records'),
    (1, '7.4', 'Communication', '7', 2, 'Communication procedures, internal/external comms records'),
    (1, '7.4.1', 'General', '7.4', 3, 'Communication matrix, procedures'),
    (1, '7.4.2', 'Internal communication', '7.4', 3, 'Meeting minutes, notice boards, intranet'),
    (1, '7.4.3', 'External communication', '7.4', 3, 'Stakeholder correspondence, regulatory submissions'),
    (1, '7.5', 'Documented information', '7', 2, 'Document control procedure, records retention'),
    (1, '7.5.1', 'General', '7.5', 3, 'Documented information requirements'),
    (1, '7.5.2', 'Creating and updating', '7.5', 3, 'Document templates, approval process'),
    (1, '7.5.3', 'Control of documented information', '7.5', 3, 'Master document list, access controls, backup'),

    -- Clause 8: Operation
    (1, '8', 'Operation', NULL, 1, NULL),
    (1, '8.1', 'Operational planning and control', '8', 2, 'SOPs, work instructions, operational controls'),
    (1, '8.2', 'Emergency preparedness and response', '8', 2, 'Emergency plans, drill records, equipment inspections'),

    -- Clause 9: Performance evaluation — maps to ehs:Evaluation
    (1, '9', 'Performance evaluation', NULL, 1, NULL),
    (1, '9.1', 'Monitoring, measurement, analysis and evaluation', '9', 2, 'Monitoring data, calibration records, analysis reports'),
    (1, '9.1.1', 'General', '9.1', 3, 'Monitoring and measurement plan'),
    (1, '9.1.2', 'Evaluation of compliance', '9.1', 3, 'Compliance evaluation records, audit reports'),
    (1, '9.2', 'Internal audit', '9', 2, 'Audit program, audit reports, auditor competence'),
    (1, '9.2.1', 'General', '9.2', 3, 'Audit program covering all requirements'),
    (1, '9.2.2', 'Internal audit programme', '9.2', 3, 'Audit schedule, scope, criteria, methods'),
    (1, '9.3', 'Management review', '9', 2, 'Management review minutes, inputs/outputs'),

    -- Clause 10: Improvement — maps to ehs:Confirm (corrective action = verifying controls work)
    (1, '10', 'Improvement', NULL, 1, NULL),
    (1, '10.1', 'General', '10', 2, 'Improvement initiatives, trend analysis'),
    (1, '10.2', 'Nonconformity and corrective action', '10', 2, 'NCR/CAR register, root cause analysis, effectiveness reviews'),
    (1, '10.3', 'Continual improvement', '10', 2, 'Improvement projects, KPI trends, benchmarking');


-- ============================================================================
-- ISO 45001:2018 CLAUSES (Occupational Health & Safety)
-- ============================================================================

INSERT OR IGNORE INTO iso_clauses (standard_id, clause_number, clause_title, parent_clause, clause_level, typical_evidence) VALUES
    -- Clause 4: Context
    (2, '4', 'Context of the organization', NULL, 1, NULL),
    (2, '4.1', 'Understanding the organization and its context', '4', 2, 'Internal/external issues affecting OH&S'),
    (2, '4.2', 'Understanding the needs and expectations of workers and other interested parties', '4', 2, 'Interested parties register, worker consultation records'),
    (2, '4.3', 'Determining the scope of the OH&S management system', '4', 2, 'Documented scope, boundaries, applicability'),
    (2, '4.4', 'OH&S management system', '4', 2, 'System documentation, process interactions'),

    -- Clause 5: Leadership and worker participation
    (2, '5', 'Leadership and worker participation', NULL, 1, NULL),
    (2, '5.1', 'Leadership and commitment', '5', 2, 'Management commitment evidence, resource provision'),
    (2, '5.2', 'OH&S policy', '5', 2, 'Signed policy, communication records'),
    (2, '5.3', 'Organizational roles, responsibilities and authorities', '5', 2, 'Role definitions, accountability matrix'),
    (2, '5.4', 'Consultation and participation of workers', '5', 2, 'Safety committee minutes, worker feedback mechanisms'),

    -- Clause 6: Planning
    (2, '6', 'Planning', NULL, 1, NULL),
    (2, '6.1', 'Actions to address risks and opportunities', '6', 2, 'Risk assessment process'),
    (2, '6.1.1', 'General', '6.1', 3, 'Planning for risk-based approach'),
    (2, '6.1.2', 'Hazard identification and assessment of risks and opportunities', '6.1', 3, 'Hazard register, risk assessments, JHAs'),
    (2, '6.1.2.1', 'Hazard identification', '6.1.2', 4, 'Hazard identification methodology, hazard inventory'),
    (2, '6.1.2.2', 'Assessment of OH&S risks and other risks', '6.1.2', 4, 'Risk matrix, risk rankings'),
    (2, '6.1.2.3', 'Assessment of OH&S opportunities and other opportunities', '6.1.2', 4, 'Opportunity register'),
    (2, '6.1.3', 'Determination of legal requirements and other requirements', '6.1', 3, 'Legal register, compliance tracking'),
    (2, '6.1.4', 'Planning action', '6.1', 3, 'Action plans, hierarchy of controls'),
    (2, '6.2', 'OH&S objectives and planning to achieve them', '6', 2, 'Safety objectives, targets, programs'),
    (2, '6.2.1', 'OH&S objectives', '6.2', 3, 'Measurable objectives aligned with policy'),
    (2, '6.2.2', 'Planning to achieve OH&S objectives', '6.2', 3, 'Action plans, responsibilities, KPIs'),

    -- Clause 7: Support
    (2, '7', 'Support', NULL, 1, NULL),
    (2, '7.1', 'Resources', '7', 2, 'Budget, staffing, equipment for OH&S'),
    (2, '7.2', 'Competence', '7', 2, 'Training records, competency requirements'),
    (2, '7.3', 'Awareness', '7', 2, 'Safety inductions, toolbox talks, awareness training'),
    (2, '7.4', 'Communication', '7', 2, 'Communication procedures, safety alerts'),
    (2, '7.4.1', 'General', '7.4', 3, 'Communication planning'),
    (2, '7.4.2', 'Internal communication', '7.4', 3, 'Safety meetings, notice boards'),
    (2, '7.4.3', 'External communication', '7.4', 3, 'Regulatory notifications, contractor comms'),
    (2, '7.5', 'Documented information', '7', 2, 'Document control, records management'),
    (2, '7.5.1', 'General', '7.5', 3, 'Documented information required by the standard'),
    (2, '7.5.2', 'Creating and updating', '7.5', 3, 'Document templates, approval process, version control'),
    (2, '7.5.3', 'Control of documented information', '7.5', 3, 'Master document list, access controls, distribution, retention'),

    -- Clause 8: Operation
    (2, '8', 'Operation', NULL, 1, NULL),
    (2, '8.1', 'Operational planning and control', '8', 2, 'Safe work procedures, permits, controls'),
    (2, '8.1.1', 'General', '8.1', 3, 'Operational control procedures'),
    (2, '8.1.2', 'Eliminating hazards and reducing OH&S risks', '8.1', 3, 'Hierarchy of controls application'),
    (2, '8.1.3', 'Management of change', '8.1', 3, 'MOC procedures, change assessments'),
    (2, '8.1.4', 'Procurement', '8.1', 3, 'Contractor management, purchasing controls'),
    (2, '8.1.4.1', 'General', '8.1.4', 4, 'Procurement procedures'),
    (2, '8.1.4.2', 'Contractors', '8.1.4', 4, 'Contractor prequalification, oversight'),
    (2, '8.1.4.3', 'Outsourcing', '8.1.4', 4, 'Outsourced process controls'),
    (2, '8.2', 'Emergency preparedness and response', '8', 2, 'Emergency plans, drills, first aid'),

    -- Clause 9: Performance evaluation — maps to ehs:Evaluation
    (2, '9', 'Performance evaluation', NULL, 1, NULL),
    (2, '9.1', 'Monitoring, measurement, analysis and evaluation', '9', 2, 'Safety metrics, leading/lagging indicators'),
    (2, '9.1.1', 'General', '9.1', 3, 'Monitoring plan, equipment calibration'),
    (2, '9.1.2', 'Evaluation of compliance', '9.1', 3, 'Compliance audits, regulatory inspections'),
    (2, '9.2', 'Internal audit', '9', 2, 'Audit program, findings, auditor qualifications'),
    (2, '9.2.1', 'General', '9.2', 3, 'Audit requirements'),
    (2, '9.2.2', 'Internal audit programme', '9.2', 3, 'Audit schedule, methods'),
    (2, '9.3', 'Management review', '9', 2, 'Review minutes, inputs, outputs, actions'),

    -- Clause 10: Improvement — maps to ehs:Confirm
    (2, '10', 'Improvement', NULL, 1, NULL),
    (2, '10.1', 'General', '10', 2, 'Improvement tracking'),
    (2, '10.2', 'Incident, nonconformity and corrective action', '10', 2, 'Incident investigations, NCRs, CARs'),
    (2, '10.3', 'Continual improvement', '10', 2, 'Improvement projects, trend analysis');


-- ============================================================================
-- ISO 50001:2018 CLAUSES (Energy Management)
-- ============================================================================

INSERT OR IGNORE INTO iso_clauses (standard_id, clause_number, clause_title, parent_clause, clause_level, typical_evidence) VALUES
    -- Clause 4: Context
    (3, '4', 'Context of the organization', NULL, 1, NULL),
    (3, '4.1', 'Understanding the organization and its context', '4', 2, 'Energy-related internal/external issues'),
    (3, '4.2', 'Understanding the needs and expectations of interested parties', '4', 2, 'Stakeholder expectations re: energy'),
    (3, '4.3', 'Determining the scope of the EnMS', '4', 2, 'EnMS boundaries, energy sources included'),
    (3, '4.4', 'Energy management system', '4', 2, 'EnMS documentation, process interactions'),

    -- Clause 5: Leadership
    (3, '5', 'Leadership', NULL, 1, NULL),
    (3, '5.1', 'Leadership and commitment', '5', 2, 'Top management energy commitment'),
    (3, '5.2', 'Energy policy', '5', 2, 'Energy policy, communication records'),
    (3, '5.3', 'Organizational roles, responsibilities and authorities', '5', 2, 'Energy team, management representative'),

    -- Clause 6: Planning
    (3, '6', 'Planning', NULL, 1, NULL),
    (3, '6.1', 'Actions to address risks and opportunities', '6', 2, 'Energy-related risks and opportunities'),
    (3, '6.2', 'Objectives, energy targets, and planning to achieve them', '6', 2, 'Energy objectives, targets, action plans'),
    (3, '6.3', 'Energy review', '6', 2, 'Energy consumption data, analysis'),
    (3, '6.4', 'Energy performance indicators', '6', 2, 'EnPIs defined, monitored'),
    (3, '6.5', 'Energy baseline', '6', 2, 'Baseline data, normalization factors'),
    (3, '6.6', 'Planning for collection of energy data', '6', 2, 'Metering plan, data collection procedures'),

    -- Clause 7: Support
    (3, '7', 'Support', NULL, 1, NULL),
    (3, '7.1', 'Resources', '7', 2, 'Resources for EnMS, energy projects'),
    (3, '7.2', 'Competence', '7', 2, 'Energy-related competence, training'),
    (3, '7.3', 'Awareness', '7', 2, 'Energy awareness training'),
    (3, '7.4', 'Communication', '7', 2, 'Energy performance communication'),
    (3, '7.5', 'Documented information', '7', 2, 'EnMS documentation, records'),
    (3, '7.5.1', 'General', '7.5', 3, 'Documentation requirements'),
    (3, '7.5.2', 'Creating and updating', '7.5', 3, 'Document creation process'),
    (3, '7.5.3', 'Control of documented information', '7.5', 3, 'Document control'),

    -- Clause 8: Operation
    (3, '8', 'Operation', NULL, 1, NULL),
    (3, '8.1', 'Operational planning and control', '8', 2, 'Operational controls for SEUs'),
    (3, '8.2', 'Design', '8', 2, 'Energy considerations in design'),
    (3, '8.3', 'Procurement', '8', 2, 'Energy-efficient procurement'),

    -- Clause 9: Performance evaluation — maps to ehs:Evaluation
    (3, '9', 'Performance evaluation', NULL, 1, NULL),
    (3, '9.1', 'Monitoring, measurement, analysis and evaluation of energy performance', '9', 2, 'Energy monitoring data, trend analysis'),
    (3, '9.1.1', 'General', '9.1', 3, 'Monitoring plan'),
    (3, '9.1.2', 'Evaluation of compliance with legal and other requirements', '9.1', 3, 'Energy compliance evaluation'),
    (3, '9.2', 'Internal audit', '9', 2, 'EnMS audits'),
    (3, '9.2.1', 'General', '9.2', 3, 'Audit requirements'),
    (3, '9.2.2', 'Internal audit programme', '9.2', 3, 'Audit program'),
    (3, '9.3', 'Management review', '9', 2, 'Energy management review'),

    -- Clause 10: Improvement — maps to ehs:Confirm
    (3, '10', 'Improvement', NULL, 1, NULL),
    (3, '10.1', 'Nonconformity and corrective action', '10', 2, 'Energy NCRs, CARs'),
    (3, '10.2', 'Continual improvement', '10', 2, 'Energy performance improvement');


-- ============================================================================
-- REFERENCE: ROOT CAUSE CATEGORIES (shared across modules)
-- ============================================================================
-- Standalone reference table for root cause trending. The original module had
-- root cause tracking inline in the CAR tables. Since corrective actions now
-- live in Module C/D, this reference table is available for any module to use
-- when categorizing root causes during investigation or CAR analysis.
--
-- Ontology note: root causes map to systemic failures in ehs:ControlMeasure
-- effectiveness. "Why did the control fail?" drives the category.

CREATE TABLE IF NOT EXISTS root_cause_categories (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    ontology_note TEXT                             -- How this maps to ontology concepts
);

INSERT OR IGNORE INTO root_cause_categories (code, name, description, ontology_note) VALUES
    ('TRAINING',       'Training Deficiency',
        'Inadequate training, competence not established, or training not reinforced.',
        'Failure in ehs:Evaluate competence — ISO clause 7.2'),
    ('PROCEDURE',      'Procedure Deficiency',
        'Missing, outdated, unclear, or inadequate procedures or work instructions.',
        'Failure in ehs:Control (administrative) — ISO clause 8.1'),
    ('EQUIPMENT',      'Equipment Deficiency',
        'Equipment failure, inadequate maintenance, missing safeguards or engineering controls.',
        'Failure in ehs:Control (engineering) — ISO clause 8.1'),
    ('COMMUNICATION',  'Communication Breakdown',
        'Information not transmitted, unclear, or not received by relevant parties.',
        'Failure in ISO clause 7.4 — internal/external communication'),
    ('RESOURCE',       'Inadequate Resources',
        'Insufficient staffing, funding, time, or materials to maintain controls.',
        'Failure in ISO clause 7.1 — resource provision'),
    ('MANAGEMENT',     'Management System Failure',
        'Gaps in planning, oversight, management review, or leadership commitment.',
        'Failure in ISO clause 5 — leadership and commitment'),
    ('DESIGN',         'Design Deficiency',
        'Inherent design flaws in process, equipment, or facility layout.',
        'Failure in ehs:Control (elimination/substitution) — highest hierarchy levels'),
    ('HUMAN_FACTORS',  'Human Factors',
        'Ergonomic issues, fatigue, workload, cognitive overload, or attention failures.',
        'Maps to ehs:ErgonomicHazard and ehs:PsychosocialHazard'),
    ('ORGANIZATIONAL_CULTURE', 'Organizational Culture',
        'Normalization of deviance, production pressure overriding safety, lack of reporting culture.',
        'Systemic failure across multiple ontology domains — deepest root cause level');


-- ============================================================================
-- REFERENCE: INSPECTION TYPES
-- ============================================================================
-- Categories of inspections that can be performed.
-- Ontology note: each inspection type operationalizes ehs:Evaluation for
-- specific hazard domains. The ontology_hazard_types comment indicates which
-- ehs:HazardType subclasses are evaluated by each inspection type.

CREATE TABLE IF NOT EXISTS inspection_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    type_code TEXT NOT NULL UNIQUE,            -- 'SWPPP', 'SPCC', 'SAFETY_WALK', etc.
    type_name TEXT NOT NULL,
    description TEXT,

    -- Regulatory driver
    regulatory_citation TEXT,                  -- '40 CFR 112.7', 'CGP Section 4.1'

    -- Frequency requirements
    default_frequency TEXT,                    -- 'weekly', 'monthly', 'quarterly', 'annual'
    frequency_notes TEXT,                      -- 'Within 24 hours of 0.25" rain event'

    -- Retention
    retention_years INTEGER DEFAULT 3,

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

-- Environmental Inspections
-- Ontology: SWPPP/SPCC inspections evaluate ehs:ChemicalHazard controls
-- in the environmental release pathway (stormwater, oil storage).
INSERT OR IGNORE INTO inspection_types (id, type_code, type_name, description, regulatory_citation, default_frequency, frequency_notes, retention_years) VALUES
    (1, 'SWPPP', 'Stormwater (SWPPP) Inspection',
        'Inspection of stormwater controls, BMPs, and outfalls per SWPPP requirements',
        'NPDES CGP Section 4', 'weekly', 'Also required within 24 hours of storm event >= 0.25 inches', 3),
    (2, 'SPCC', 'SPCC Inspection',
        'Inspection of oil storage containers, secondary containment, and spill equipment',
        '40 CFR 112.7(e)', 'monthly', 'Visual inspection of containers and containment areas', 3),
    (3, 'SWPPP_STORM', 'Stormwater Post-Storm Inspection',
        'Inspection within 24 hours of qualifying storm event',
        'NPDES CGP Section 4.1', 'as_needed', 'Required after rain events >= 0.25 inches', 3);

-- Safety Inspections
-- Ontology: Safety walkthroughs evaluate multiple ehs:HazardType subclasses
-- (physical, mechanical, electrical, chemical, ergonomic). Individual safety
-- inspections target specific control measures within ehs:Control.
INSERT OR IGNORE INTO inspection_types (id, type_code, type_name, description, regulatory_citation, default_frequency, frequency_notes, retention_years) VALUES
    (10, 'SAFETY_WALK', 'Safety Walkthrough',
        'General workplace safety inspection',
        'OSHA General Duty Clause', 'weekly', NULL, 3),
    (11, 'FIRE_EXT', 'Fire Extinguisher Inspection',
        'Monthly visual inspection of portable fire extinguishers',
        '29 CFR 1910.157(e)(2)', 'monthly', 'Annual maintenance by certified technician also required', 3),
    (12, 'EYEWASH', 'Eyewash/Safety Shower Inspection',
        'Weekly activation test of emergency eyewash stations and safety showers',
        'ANSI Z358.1', 'weekly', 'Annual inspection/certification also required', 3),
    (13, 'EMERG_LIGHT', 'Emergency Lighting Inspection',
        'Monthly 30-second test, annual 90-minute test of emergency lighting',
        'NFPA 101', 'monthly', 'Annual 90-minute test also required', 3),
    (14, 'EXIT_SIGN', 'Exit Sign Inspection',
        'Monthly inspection of exit signs and emergency lighting',
        'NFPA 101', 'monthly', NULL, 3),
    (15, 'FIRST_AID', 'First Aid Kit Inspection',
        'Inspection and restocking of first aid kits',
        '29 CFR 1910.151', 'monthly', NULL, 3);

-- Equipment Inspections
-- Ontology: Equipment inspections evaluate ehs:MechanicalHazard controls.
-- Forklift pre-shift maps to ehs:Evaluate (operator-level leading indicator).
INSERT OR IGNORE INTO inspection_types (id, type_code, type_name, description, regulatory_citation, default_frequency, frequency_notes, retention_years) VALUES
    (20, 'FORKLIFT_PRE', 'Forklift Pre-Shift Inspection',
        'Operator pre-shift inspection of powered industrial truck',
        '29 CFR 1910.178(q)(7)', 'daily', 'Before each shift the truck is used', 1),
    (21, 'CRANE', 'Crane Inspection',
        'Periodic inspection of cranes and hoists',
        '29 CFR 1910.179(j)', 'monthly', 'Frequent (daily) and periodic (monthly/annual) required', 3),
    (22, 'LADDER', 'Ladder Inspection',
        'Inspection of portable and fixed ladders',
        '29 CFR 1910.23', 'quarterly', NULL, 3);

-- Waste Inspections
-- Ontology: Waste inspections evaluate ehs:ChemicalHazard controls for
-- hazardous waste accumulation areas (RCRA) and used oil (40 CFR 279).
INSERT OR IGNORE INTO inspection_types (id, type_code, type_name, description, regulatory_citation, default_frequency, frequency_notes, retention_years) VALUES
    (30, 'HAZWASTE_WEEKLY', 'Hazardous Waste Weekly Inspection',
        'Weekly inspection of hazardous waste accumulation areas',
        '40 CFR 265.174', 'weekly', 'Required for LQG central accumulation areas', 3),
    (31, 'USED_OIL', 'Used Oil Container Inspection',
        'Inspection of used oil storage containers',
        '40 CFR 279.22', 'monthly', NULL, 3);


-- ============================================================================
-- REFERENCE: INSPECTION CHECKLIST TEMPLATES
-- ============================================================================
-- Pre-seeded checklist items that can be used for each inspection type.
-- Users can add their own site-specific items.

CREATE TABLE IF NOT EXISTS inspection_checklist_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    inspection_type_id INTEGER NOT NULL,

    item_order INTEGER DEFAULT 0,              -- Display order
    checklist_item TEXT NOT NULL,              -- The item to check
    category TEXT,                             -- Grouping within the checklist

    expected_response TEXT,                    -- 'yes_no', 'pass_fail', 'numeric', 'text'
    acceptable_values TEXT,                    -- 'yes', 'pass', '>0', etc.

    guidance_notes TEXT,                       -- Help text for inspector
    regulatory_reference TEXT,                 -- Specific reg citation for this item

    is_critical INTEGER DEFAULT 0,            -- Failure requires immediate action
    is_active INTEGER DEFAULT 1,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (inspection_type_id) REFERENCES inspection_types(id)
);

CREATE INDEX IF NOT EXISTS idx_checklist_templates_type ON inspection_checklist_templates(inspection_type_id);


-- ============================================================================
-- SWPPP INSPECTION CHECKLIST (Pre-seeded)
-- ============================================================================

INSERT OR IGNORE INTO inspection_checklist_templates
    (inspection_type_id, item_order, checklist_item, category, expected_response, guidance_notes, is_critical) VALUES
    -- General Site Conditions
    (1, 1, 'Evidence of spills or leaks on paved areas', 'Site Conditions', 'yes_no',
        'Look for staining, sheens, or discoloration', 1),
    (1, 2, 'Waste and debris properly contained/disposed', 'Site Conditions', 'yes_no',
        'Dumpster lids closed, no overflow, no debris in drainage paths', 0),
    (1, 3, 'Outdoor material storage areas covered or contained', 'Site Conditions', 'yes_no',
        'Raw materials, chemicals, equipment protected from rain', 0),
    (1, 4, 'No illicit discharges observed', 'Site Conditions', 'yes_no',
        'No unauthorized connections, dumping, or non-stormwater discharges', 1),

    -- BMPs - Structural
    (1, 10, 'Catch basin inserts in place and functional', 'Structural BMPs', 'yes_no',
        'Inserts not clogged, properly seated', 0),
    (1, 11, 'Sediment traps/basins have adequate capacity', 'Structural BMPs', 'yes_no',
        'Not more than 50% full of sediment', 0),
    (1, 12, 'Oil/water separators functioning', 'Structural BMPs', 'yes_no',
        'Baffles in place, not full of accumulated oil', 0),
    (1, 13, 'Detention/retention pond condition acceptable', 'Structural BMPs', 'yes_no',
        'Outlet structure clear, no excessive vegetation or erosion', 0),

    -- BMPs - Non-Structural
    (1, 20, 'Good housekeeping practices maintained', 'Non-Structural BMPs', 'yes_no',
        'Paved areas swept, materials stored properly', 0),
    (1, 21, 'Spill kits available and stocked', 'Non-Structural BMPs', 'yes_no',
        'Kits accessible, absorbents available', 0),
    (1, 22, 'Secondary containment intact and empty', 'Non-Structural BMPs', 'yes_no',
        'No standing water/product in containment, drains plugged', 0),
    (1, 23, 'Vehicle/equipment maintenance areas clean', 'Non-Structural BMPs', 'yes_no',
        'No drips, drip pans in use, covered if possible', 0),

    -- Outfall Inspection
    (1, 30, 'Outfall structure condition acceptable', 'Outfalls', 'yes_no',
        'No erosion, damage, or blockage at outfall', 0),
    (1, 31, 'No evidence of illicit discharge at outfall', 'Outfalls', 'yes_no',
        'No sheen, discoloration, foam, or unusual odor', 1),
    (1, 32, 'Receiving water conditions normal', 'Outfalls', 'yes_no',
        'No visible pollution in receiving stream/ditch', 0),

    -- Post-Storm Specific (type_id = 3)
    (3, 1, 'Storm event date and approximate rainfall', 'Storm Event', 'text',
        'Record date and estimated rainfall amount', 0),
    (3, 2, 'BMPs performed adequately during storm', 'Storm Event', 'yes_no',
        'Controls contained runoff, no bypass or overflow', 0),
    (3, 3, 'Any BMP failures or damage observed', 'Storm Event', 'yes_no',
        'Document any erosion, overtopping, or structural damage', 1),
    (3, 4, 'Corrective actions needed', 'Storm Event', 'yes_no',
        'Note any repairs or maintenance required', 0);


-- ============================================================================
-- SPCC INSPECTION CHECKLIST (Pre-seeded)
-- ============================================================================

INSERT OR IGNORE INTO inspection_checklist_templates
    (inspection_type_id, item_order, checklist_item, category, expected_response, guidance_notes, is_critical) VALUES
    -- Container Integrity
    (2, 1, 'Oil containers free of leaks, corrosion, or damage', 'Container Integrity', 'yes_no',
        'Inspect all tanks, drums, totes, IBCs containing oil', 1),
    (2, 2, 'Container supports/foundations in good condition', 'Container Integrity', 'yes_no',
        'Check for rust, settling, cracks in concrete', 0),
    (2, 3, 'Container labels legible and accurate', 'Container Integrity', 'yes_no',
        'Contents clearly marked', 0),
    (2, 4, 'Valves, fittings, and connections secure', 'Container Integrity', 'yes_no',
        'No drips, properly closed when not in use', 0),

    -- Secondary Containment
    (2, 10, 'Secondary containment free of accumulated oil/water', 'Secondary Containment', 'yes_no',
        'Drain or remove accumulated liquids', 0),
    (2, 11, 'Containment integrity intact (no cracks/gaps)', 'Secondary Containment', 'yes_no',
        'Inspect walls, floors, seals', 1),
    (2, 12, 'Containment capacity adequate (110% of largest container)', 'Secondary Containment', 'yes_no',
        'Verify capacity if changes made to stored containers', 0),
    (2, 13, 'Containment drain valves closed/locked', 'Secondary Containment', 'yes_no',
        'Valves should be closed except during authorized drainage', 1),

    -- Spill Prevention
    (2, 20, 'Spill kits available near oil storage', 'Spill Prevention', 'yes_no',
        'Absorbents, PPE, bags accessible', 0),
    (2, 21, 'Overfill protection devices functional', 'Spill Prevention', 'yes_no',
        'High level alarms, automatic shutoffs working', 0),
    (2, 22, 'Transfer procedures being followed', 'Spill Prevention', 'yes_no',
        'Attended transfers, drip pans in use', 0),

    -- Equipment and Training
    (2, 30, 'SPCC Plan available on-site', 'Documentation', 'yes_no',
        'Current plan accessible to personnel', 0),
    (2, 31, 'Personnel trained on spill response', 'Documentation', 'yes_no',
        'Training records current for designated personnel', 0),
    (2, 32, 'Emergency contact information posted', 'Documentation', 'yes_no',
        'Phone numbers for response team, regulators', 0);


-- ============================================================================
-- SAFETY INSPECTION CHECKLISTS (Pre-seeded)
-- ============================================================================

-- Fire Extinguisher Inspection (monthly visual) — 29 CFR 1910.157(e)(2)
INSERT OR IGNORE INTO inspection_checklist_templates
    (inspection_type_id, item_order, checklist_item, category, expected_response, guidance_notes, is_critical) VALUES
    (11, 1, 'Extinguisher in designated location', 'Location', 'yes_no', 'Not blocked, visible, proper mounting height', 0),
    (11, 2, 'Access to extinguisher unobstructed', 'Location', 'yes_no', 'Clear path, no storage blocking access', 0),
    (11, 3, 'Operating instructions visible and legible', 'Condition', 'yes_no', 'Label facing outward', 0),
    (11, 4, 'Safety seal and tamper indicator intact', 'Condition', 'yes_no', 'If broken, extinguisher may have been used', 1),
    (11, 5, 'Pressure gauge in operable range (green)', 'Condition', 'yes_no', 'Needle in green zone', 1),
    (11, 6, 'No visible physical damage or corrosion', 'Condition', 'yes_no', 'Dents, rust, damage to hose/nozzle', 0),
    (11, 7, 'Inspection tag current', 'Documentation', 'yes_no', 'Monthly inspection documented, annual service date', 0);

-- Eyewash/Safety Shower Inspection (weekly) — ANSI Z358.1
INSERT OR IGNORE INTO inspection_checklist_templates
    (inspection_type_id, item_order, checklist_item, category, expected_response, guidance_notes, is_critical) VALUES
    (12, 1, 'Unit location clearly identified/signed', 'Location', 'yes_no', 'Highly visible sign, unobstructed', 0),
    (12, 2, 'Access path clear (10 seconds travel time)', 'Location', 'yes_no', 'No obstructions in path from work area', 1),
    (12, 3, 'Activated and water flows freely', 'Function', 'yes_no', 'Activate for at least 3 seconds weekly', 1),
    (12, 4, 'Water temperature acceptable (tepid 60-100F)', 'Function', 'yes_no', 'Not too hot or cold', 0),
    (12, 5, 'Dust covers in place (if equipped)', 'Condition', 'yes_no', 'Covers protect nozzles but allow quick activation', 0),
    (12, 6, 'No leaks when not activated', 'Condition', 'yes_no', 'Check valves, piping', 0),
    (12, 7, 'Inspection tag/log updated', 'Documentation', 'yes_no', 'Document weekly activation test', 0);

-- General Safety Walkthrough — OSHA General Duty Clause
-- Ontology: covers multiple ehs:HazardType subclasses in a single inspection:
--   housekeeping → physical, egress → physical, electrical → electrical,
--   machine safety → mechanical, PPE → all types, HazCom → chemical
INSERT OR IGNORE INTO inspection_checklist_templates
    (inspection_type_id, item_order, checklist_item, category, expected_response, guidance_notes, is_critical) VALUES
    (10, 1, 'Walking/working surfaces clear and dry', 'Housekeeping', 'yes_no', 'No trip hazards, spills cleaned up', 0),
    (10, 2, 'Aisles and exits unobstructed', 'Egress', 'yes_no', 'Clear path to exits, minimum width maintained', 1),
    (10, 3, 'Exit signs illuminated', 'Egress', 'yes_no', 'All exit signs lit, visible', 0),
    (10, 4, 'Electrical panels accessible (36" clearance)', 'Electrical', 'yes_no', 'No storage in front of panels', 1),
    (10, 5, 'Extension cords not used as permanent wiring', 'Electrical', 'yes_no', 'Temporary use only', 0),
    (10, 6, 'Guards in place on machinery', 'Machine Safety', 'yes_no', 'Point of operation, nip point guards', 1),
    (10, 7, 'PPE being worn as required', 'PPE', 'yes_no', 'Eye, hearing, foot, hand protection as posted', 0),
    (10, 8, 'Chemical containers labeled', 'HazCom', 'yes_no', 'All containers have labels, SDS accessible', 0),
    (10, 9, 'Compressed gas cylinders secured', 'Material Handling', 'yes_no', 'Chained or capped, stored upright', 0),
    (10, 10, 'No obvious hazards observed', 'General', 'yes_no', 'Document any concerns', 0);


-- ============================================================================
-- SWPPP OUTFALLS (facility-specific stormwater outfall points)
-- ============================================================================
-- Ontology: outfalls are the physical points where ehs:ChemicalHazard
-- controls (BMPs) are confirmed effective via discharge monitoring.

CREATE TABLE IF NOT EXISTS swppp_outfalls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    outfall_id TEXT NOT NULL,                  -- 'OF-001', 'OF-002' per SWPPP
    outfall_name TEXT,                         -- Descriptive name
    description TEXT,

    -- Location
    latitude REAL,
    longitude REAL,
    location_description TEXT,                 -- 'Northeast corner of parking lot'

    -- Drainage area info
    drainage_area_acres REAL,
    drainage_area_description TEXT,            -- What drains to this outfall

    -- Receiving water
    receiving_water_name TEXT,                 -- Stream, ditch, municipal system
    receiving_water_type TEXT,                 -- 'stream', 'wetland', 'municipal_storm', 'ditch'

    -- Monitoring requirements
    requires_sampling INTEGER DEFAULT 0,       -- Some permits require sampling
    benchmark_parameters TEXT,                 -- Parameters to sample if required

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, outfall_id)
);

CREATE INDEX IF NOT EXISTS idx_swppp_outfalls_establishment ON swppp_outfalls(establishment_id);


-- ============================================================================
-- SPCC CONTAINERS (oil storage containers under SPCC plan)
-- ============================================================================
-- Ontology: containers are the physical assets where ehs:ChemicalHazard
-- controls (secondary containment, overfill protection) are confirmed.

CREATE TABLE IF NOT EXISTS spcc_containers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    container_id TEXT NOT NULL,                -- Internal tracking ID
    container_name TEXT,
    description TEXT,

    -- Container details
    container_type TEXT,                       -- 'AST', 'drum', 'tote', 'tank_truck', 'transformer'
    capacity_gallons REAL NOT NULL,
    shell_capacity_gallons REAL,               -- For tanks — shell vs working capacity

    -- Contents
    oil_type TEXT,                             -- 'diesel', 'hydraulic', 'lubricating', 'transformer'
    product_name TEXT,

    -- Location
    location_description TEXT,
    building TEXT,
    indoor_outdoor TEXT,                       -- 'indoor', 'outdoor', 'covered_outdoor'

    -- Secondary containment
    containment_type TEXT,                     -- 'dike', 'vault', 'double_wall', 'drip_pan', 'none'
    containment_capacity_gallons REAL,

    -- Spill history
    spill_history TEXT,                        -- Brief description of any past spills

    -- Installation/inspection
    install_date TEXT,
    last_integrity_test TEXT,                  -- For regulated ASTs
    next_integrity_test TEXT,

    -- Regulatory status
    is_regulated_ast INTEGER DEFAULT 0,        -- Subject to additional requirements

    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, container_id)
);

CREATE INDEX IF NOT EXISTS idx_spcc_containers_establishment ON spcc_containers(establishment_id);


-- ============================================================================
-- INSPECTIONS (Master Record)
-- ============================================================================
-- Individual inspection events. Each inspection IS a leading indicator —
-- the act of inspecting operationalizes ehs:Evaluation (5 E's of Safety).
--
-- Cross-module FK: work_area_id links to work_areas (from training module),
-- enabling queries like "show all inspections for the welding shop" and
-- tying inspection frequency to the hazard profile of a work area.

CREATE TABLE IF NOT EXISTS inspections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    inspection_type_id INTEGER NOT NULL,

    -- Identification
    inspection_number TEXT,                    -- Auto-generated or user-defined

    -- Schedule vs actual
    scheduled_date TEXT,
    inspection_date TEXT NOT NULL,

    -- Inspector
    inspector_id INTEGER,                      -- Employee who performed inspection
    inspector_name TEXT,                       -- For external inspectors
    inspector_title TEXT,

    -- Scope
    areas_inspected TEXT,                      -- Description of areas covered
    work_area_id INTEGER,                      -- FK → work_areas (cross-module: links to facility work area)

    -- For SWPPP storm-triggered inspections
    is_storm_triggered INTEGER DEFAULT 0,
    storm_date TEXT,
    rainfall_inches REAL,

    -- For SPCC — which containers inspected
    spcc_container_ids TEXT,                   -- Comma-separated container IDs

    -- For SWPPP — which outfalls inspected
    swppp_outfall_ids TEXT,                    -- Comma-separated outfall IDs

    -- Overall result
    overall_result TEXT DEFAULT 'pass',        -- 'pass', 'pass_with_findings', 'fail'

    -- Summary
    summary_notes TEXT,

    -- Weather conditions (for outdoor inspections)
    weather_conditions TEXT,
    temperature_f INTEGER,

    -- Status
    status TEXT DEFAULT 'draft',               -- 'draft', 'completed', 'reviewed'
    completed_at TEXT,
    reviewed_by INTEGER,
    reviewed_at TEXT,

    -- Attachments
    photo_references TEXT,                     -- File paths or references

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (inspection_type_id) REFERENCES inspection_types(id),
    FOREIGN KEY (inspector_id) REFERENCES employees(id),
    FOREIGN KEY (reviewed_by) REFERENCES employees(id),
    FOREIGN KEY (work_area_id) REFERENCES work_areas(id)
);

CREATE INDEX IF NOT EXISTS idx_inspections_establishment ON inspections(establishment_id);
CREATE INDEX IF NOT EXISTS idx_inspections_type ON inspections(inspection_type_id);
CREATE INDEX IF NOT EXISTS idx_inspections_date ON inspections(inspection_date);
CREATE INDEX IF NOT EXISTS idx_inspections_status ON inspections(status);
CREATE INDEX IF NOT EXISTS idx_inspections_work_area ON inspections(work_area_id);


-- ============================================================================
-- INSPECTION HAZARD TYPES (junction — links inspections to ontology hazards)
-- ============================================================================
-- Ontology bridge: connects individual inspections to the ehs:HazardType
-- taxonomy from the training module. Enables queries like "show me all
-- inspections related to electrical hazards" and supports the ontology's
-- principle that hazard types cross-cut all modules.
--
-- Examples:
--   SWPPP inspection      → CHEMICAL (stormwater pollutants)
--   Safety walkthrough    → PHYSICAL, MECHANICAL, ELECTRICAL, CHEMICAL, ERGONOMIC
--   Forklift pre-shift    → MECHANICAL
--   HAZWASTE_WEEKLY       → CHEMICAL
--   Eyewash inspection    → CHEMICAL (emergency response equipment for chemical exposure)

CREATE TABLE IF NOT EXISTS inspection_hazard_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    inspection_id INTEGER NOT NULL,
    hazard_type_code TEXT NOT NULL,             -- FK → hazard_type_codes (from training module)

    notes TEXT,                                 -- Optional context for this linkage

    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (hazard_type_code) REFERENCES hazard_type_codes(code),
    UNIQUE(inspection_id, hazard_type_code)
);

CREATE INDEX IF NOT EXISTS idx_inspection_hazard_types_inspection ON inspection_hazard_types(inspection_id);
CREATE INDEX IF NOT EXISTS idx_inspection_hazard_types_hazard ON inspection_hazard_types(hazard_type_code);


-- ============================================================================
-- INSPECTION CHECKLIST RESPONSES
-- ============================================================================
-- Actual responses to checklist items during an inspection.
-- Items copied from template at inspection start, can add custom items.

CREATE TABLE IF NOT EXISTS inspection_checklist_responses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    inspection_id INTEGER NOT NULL,

    -- Link to template (NULL if custom item)
    template_item_id INTEGER,

    -- Item details (copied from template or custom)
    item_order INTEGER,
    checklist_item TEXT NOT NULL,
    category TEXT,

    -- Response
    response TEXT,                             -- 'yes', 'no', 'pass', 'fail', 'N/A', or value
    response_notes TEXT,

    -- If finding generated
    is_finding INTEGER DEFAULT 0,
    finding_id INTEGER,                        -- Link to inspection_findings if issue found

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (template_item_id) REFERENCES inspection_checklist_templates(id),
    FOREIGN KEY (finding_id) REFERENCES inspection_findings(id)
);

CREATE INDEX IF NOT EXISTS idx_checklist_responses_inspection ON inspection_checklist_responses(inspection_id);


-- ============================================================================
-- INSPECTION FINDINGS
-- ============================================================================
-- Issues discovered during inspections.
-- Ontology: findings are the output of ehs:Evaluation — they identify where
-- ehs:ControlMeasure effectiveness is degraded or absent.
--
-- Cross-module FKs:
--   corrective_action_id → corrective_actions (Module C/D) for formal corrective action
--   incident_id → incidents (if a finding leads to or was discovered during incident investigation)

CREATE TABLE IF NOT EXISTS inspection_findings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    inspection_id INTEGER NOT NULL,

    -- Finding identification
    finding_number TEXT,                       -- Sequence within inspection

    -- Classification
    finding_type TEXT NOT NULL,                -- 'observation', 'deficiency', 'violation', 'opportunity'
    severity TEXT DEFAULT 'minor',             -- 'minor', 'major', 'critical'

    -- Description
    finding_description TEXT NOT NULL,
    location TEXT,

    -- Regulatory reference (if applicable)
    regulatory_citation TEXT,

    -- Evidence
    photo_reference TEXT,

    -- Immediate action taken
    immediate_action TEXT,
    immediate_action_by TEXT,
    immediate_action_date TEXT,

    -- Cross-module: link to corrective action (Module C/D)
    -- Instead of duplicating CAR tables, findings point to the shared
    -- corrective_actions table from module_c_osha300.sql.
    corrective_action_id INTEGER,              -- FK → corrective_actions (Module C/D)

    -- Cross-module: link to incident (if finding relates to an incident)
    incident_id INTEGER,                       -- FK → incidents (discovered during or led to incident)

    -- Status
    status TEXT DEFAULT 'open',                -- 'open', 'corrective_action_issued', 'closed'
    closed_date TEXT,
    closed_by INTEGER,
    closure_notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (corrective_action_id) REFERENCES corrective_actions(id),
    FOREIGN KEY (incident_id) REFERENCES incidents(id),
    FOREIGN KEY (closed_by) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_inspection_findings_inspection ON inspection_findings(inspection_id);
CREATE INDEX IF NOT EXISTS idx_inspection_findings_status ON inspection_findings(status);
CREATE INDEX IF NOT EXISTS idx_inspection_findings_corrective_action ON inspection_findings(corrective_action_id);
CREATE INDEX IF NOT EXISTS idx_inspection_findings_incident ON inspection_findings(incident_id);


-- ============================================================================
-- INSPECTION SCHEDULE (recurring schedules with auto-calculated due dates)
-- ============================================================================
-- Ontology: the schedule itself is the PLAN for ehs:Evaluation — how often
-- and where we will confirm that controls remain effective.

CREATE TABLE IF NOT EXISTS inspection_schedule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    inspection_type_id INTEGER NOT NULL,

    -- Schedule name
    schedule_name TEXT,

    -- Frequency
    frequency TEXT NOT NULL,                   -- 'daily', 'weekly', 'monthly', 'quarterly', 'annual'
    frequency_details TEXT,                    -- 'Every Monday', 'First week of month'

    -- Day/time preferences
    preferred_day_of_week INTEGER,             -- 0=Sunday, 1=Monday, etc.
    preferred_time TEXT,

    -- Responsible person
    default_inspector_id INTEGER,

    -- Status
    is_active INTEGER DEFAULT 1,

    -- Last/next
    last_inspection_date TEXT,
    last_inspection_id INTEGER,
    next_due_date TEXT,

    -- Reminder settings
    reminder_days_before INTEGER DEFAULT 7,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (inspection_type_id) REFERENCES inspection_types(id),
    FOREIGN KEY (default_inspector_id) REFERENCES employees(id),
    FOREIGN KEY (last_inspection_id) REFERENCES inspections(id)
);

CREATE INDEX IF NOT EXISTS idx_inspection_schedule_establishment ON inspection_schedule(establishment_id);
CREATE INDEX IF NOT EXISTS idx_inspection_schedule_type ON inspection_schedule(inspection_type_id);
CREATE INDEX IF NOT EXISTS idx_inspection_schedule_next_due ON inspection_schedule(next_due_date);


-- ============================================================================
-- AUDITS (Master Record — internal/external, ISO standard tracking)
-- ============================================================================
-- Ontology: audits are the formal mechanism for ehs:Confirm — systematic,
-- evidence-based evaluation of management system conformity. ISO 9.2 requires
-- internal audits at planned intervals; external audits verify certification.

CREATE TABLE IF NOT EXISTS audits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    -- Identification
    audit_number TEXT,                         -- 'AUD-2025-001'
    audit_title TEXT NOT NULL,                 -- 'ISO 14001 Internal Audit - Q1 2025'

    -- Audit type
    audit_type TEXT NOT NULL,                  -- 'internal', 'external_surveillance', 'external_certification', 'external_recertification'

    -- Standard(s) being audited
    standard_id INTEGER,                       -- Primary standard (14001, 45001, 50001)
    is_integrated_audit INTEGER DEFAULT 0,     -- Covers multiple standards
    additional_standard_ids TEXT,              -- Comma-separated if integrated

    -- For external audits — registrar info
    registrar_name TEXT,                       -- 'DNV', 'BSI', 'NSF-ISR', etc.
    certificate_number TEXT,

    -- Dates
    scheduled_start_date TEXT,
    scheduled_end_date TEXT,
    actual_start_date TEXT,
    actual_end_date TEXT,

    -- Lead auditor
    lead_auditor_id INTEGER,                   -- Employee ID if internal
    lead_auditor_name TEXT,                    -- Name for external auditors
    lead_auditor_company TEXT,                 -- For external

    -- Scope summary
    scope_description TEXT,
    exclusions TEXT,                           -- What's not in scope

    -- Previous audit reference
    previous_audit_id INTEGER,                 -- Link to prior audit for comparison

    -- Objectives
    audit_objectives TEXT,
    audit_criteria TEXT,                       -- 'ISO 14001:2015, Site EMS Manual, Legal requirements'

    -- Results summary
    total_findings INTEGER DEFAULT 0,
    major_nonconformities INTEGER DEFAULT 0,
    minor_nonconformities INTEGER DEFAULT 0,
    opportunities_for_improvement INTEGER DEFAULT 0,
    positive_findings INTEGER DEFAULT 0,

    -- Recommendation (for certification audits)
    recommendation TEXT,                       -- 'certification_recommended', 'conditional', 'not_recommended'
    recommendation_conditions TEXT,

    -- Status
    status TEXT DEFAULT 'planned',             -- 'planned', 'in_progress', 'draft_report', 'final', 'closed'

    -- Report
    executive_summary TEXT,
    conclusion TEXT,
    report_date TEXT,
    report_file_reference TEXT,

    -- Follow-up
    followup_audit_needed INTEGER DEFAULT 0,
    followup_audit_date TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (standard_id) REFERENCES iso_standards(id),
    FOREIGN KEY (lead_auditor_id) REFERENCES employees(id),
    FOREIGN KEY (previous_audit_id) REFERENCES audits(id)
);

CREATE INDEX IF NOT EXISTS idx_audits_establishment ON audits(establishment_id);
CREATE INDEX IF NOT EXISTS idx_audits_standard ON audits(standard_id);
CREATE INDEX IF NOT EXISTS idx_audits_type ON audits(audit_type);
CREATE INDEX IF NOT EXISTS idx_audits_status ON audits(status);
CREATE INDEX IF NOT EXISTS idx_audits_date ON audits(actual_start_date);


-- ============================================================================
-- AUDIT TEAM (members of the audit team)
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_team (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    audit_id INTEGER NOT NULL,

    -- Team member
    employee_id INTEGER,                       -- If internal auditor
    auditor_name TEXT NOT NULL,
    auditor_company TEXT,                      -- For external auditors

    -- Role
    role TEXT NOT NULL,                        -- 'lead_auditor', 'auditor', 'technical_expert', 'observer', 'trainee'

    -- Qualifications relevant to this audit
    qualifications TEXT,                       -- Certifications, experience

    -- Assigned areas/clauses
    assigned_scope TEXT,                       -- What they're responsible for auditing

    -- Conflict of interest check
    independence_confirmed INTEGER DEFAULT 0,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_audit_team_audit ON audit_team(audit_id);


-- ============================================================================
-- AUDIT SCOPE DETAIL (breakdown by process/area/clause)
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_scope (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    audit_id INTEGER NOT NULL,

    -- What's being audited
    scope_type TEXT NOT NULL,                  -- 'process', 'department', 'clause', 'location'
    scope_item TEXT NOT NULL,                  -- Process name, dept name, clause number, location

    -- For clause-based scope
    clause_id INTEGER,                         -- Link to iso_clauses

    -- Assignment
    assigned_auditor_id INTEGER,               -- Who will audit this scope item

    -- Timing
    scheduled_date TEXT,
    scheduled_time TEXT,
    estimated_duration_minutes INTEGER,

    -- Contacts/interviewees
    auditee_contact TEXT,

    -- Status
    status TEXT DEFAULT 'planned',             -- 'planned', 'in_progress', 'completed'

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE,
    FOREIGN KEY (clause_id) REFERENCES iso_clauses(id),
    FOREIGN KEY (assigned_auditor_id) REFERENCES audit_team(id)
);

CREATE INDEX IF NOT EXISTS idx_audit_scope_audit ON audit_scope(audit_id);
CREATE INDEX IF NOT EXISTS idx_audit_scope_clause ON audit_scope(clause_id);


-- ============================================================================
-- AUDIT FINDINGS (with clause-level tracking)
-- ============================================================================
-- Ontology: audit findings document where ehs:Confirm identified gaps.
-- Nonconformities mean a control is not implemented or not effective.
--
-- Cross-module FKs:
--   corrective_action_id → corrective_actions (Module C/D) for formal corrective action
--   training_requirement_id → training_regulatory_requirements (for competence findings at clause 7.2)

CREATE TABLE IF NOT EXISTS audit_findings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    audit_id INTEGER NOT NULL,

    -- Finding identification
    finding_number TEXT NOT NULL,              -- 'F1', 'F2' or 'MAJ-001', 'MIN-001'

    -- Classification
    finding_type TEXT NOT NULL,                -- 'major_nc', 'minor_nc', 'ofi', 'positive', 'observation'

    -- Clause reference (THE KEY TRACKING FEATURE)
    clause_id INTEGER,                         -- Link to iso_clauses
    clause_number TEXT,                        -- Stored for quick reference
    clause_title TEXT,

    -- Additional standard references if integrated audit
    secondary_clause_refs TEXT,                -- Other clauses also implicated

    -- Finding details
    requirement_statement TEXT,                -- What the standard requires
    finding_statement TEXT NOT NULL,           -- Objective evidence of the finding

    -- Context
    process_area TEXT,                         -- Where finding was identified
    department TEXT,
    auditee_interviewed TEXT,

    -- Evidence
    evidence_description TEXT,
    document_references TEXT,                  -- Documents reviewed
    photo_references TEXT,

    -- For repeat findings
    is_repeat_finding INTEGER DEFAULT 0,
    previous_finding_id INTEGER,               -- Link to finding from prior audit

    -- Risk assessment (for prioritization)
    risk_level TEXT,                           -- 'high', 'medium', 'low'
    potential_impact TEXT,

    -- Auditee response
    auditee_agreement INTEGER DEFAULT 1,       -- Did auditee agree with finding?
    auditee_comments TEXT,

    -- Cross-module: link to corrective action (Module C/D)
    -- Instead of duplicating CAR tables, audit findings point to the shared
    -- corrective_actions table from module_c_osha300.sql.
    corrective_action_id INTEGER,              -- FK → corrective_actions (Module C/D)

    -- Cross-module: link to training requirement (for competence findings)
    -- When an audit finding at clause 7.2 (Competence) identifies a training
    -- gap, this links to the specific training requirement that was deficient.
    training_requirement_id INTEGER,           -- FK → training_regulatory_requirements

    -- Status
    status TEXT DEFAULT 'open',                -- 'open', 'corrective_action_issued', 'verified', 'closed'
    verified_date TEXT,
    verified_by INTEGER,
    verification_notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE,
    FOREIGN KEY (clause_id) REFERENCES iso_clauses(id),
    FOREIGN KEY (previous_finding_id) REFERENCES audit_findings(id),
    FOREIGN KEY (corrective_action_id) REFERENCES corrective_actions(id),
    FOREIGN KEY (training_requirement_id) REFERENCES training_regulatory_requirements(id),
    FOREIGN KEY (verified_by) REFERENCES employees(id)
);

CREATE INDEX IF NOT EXISTS idx_audit_findings_audit ON audit_findings(audit_id);
CREATE INDEX IF NOT EXISTS idx_audit_findings_clause ON audit_findings(clause_id);
CREATE INDEX IF NOT EXISTS idx_audit_findings_type ON audit_findings(finding_type);
CREATE INDEX IF NOT EXISTS idx_audit_findings_status ON audit_findings(status);
CREATE INDEX IF NOT EXISTS idx_audit_findings_corrective_action ON audit_findings(corrective_action_id);
CREATE INDEX IF NOT EXISTS idx_audit_findings_training_req ON audit_findings(training_requirement_id);


-- ============================================================================
-- VIEWS
-- ============================================================================


-- ----------------------------------------------------------------------------
-- V_INSPECTIONS_DUE
-- ----------------------------------------------------------------------------
-- Upcoming and overdue inspections based on schedule.
-- This is the primary ehs:Evaluation dashboard — are we measuring on time?

CREATE VIEW IF NOT EXISTS v_inspections_due AS
SELECT
    isc.id AS schedule_id,
    isc.establishment_id,
    e.name AS establishment_name,
    it.type_code,
    it.type_name AS inspection_type,
    isc.schedule_name,
    isc.frequency,
    isc.last_inspection_date,
    isc.next_due_date,
    CAST(julianday(isc.next_due_date) - julianday('now') AS INTEGER) AS days_until_due,
    CASE
        WHEN date(isc.next_due_date) < date('now') THEN 'OVERDUE'
        WHEN date(isc.next_due_date) <= date('now', '+7 days') THEN 'DUE_THIS_WEEK'
        WHEN date(isc.next_due_date) <= date('now', '+30 days') THEN 'DUE_THIS_MONTH'
        ELSE 'UPCOMING'
    END AS urgency,
    emp.first_name || ' ' || emp.last_name AS default_inspector
FROM inspection_schedule isc
INNER JOIN establishments e ON isc.establishment_id = e.id
INNER JOIN inspection_types it ON isc.inspection_type_id = it.id
LEFT JOIN employees emp ON isc.default_inspector_id = emp.id
WHERE isc.is_active = 1
ORDER BY isc.next_due_date ASC;


-- ----------------------------------------------------------------------------
-- V_INSPECTION_COMPLIANCE_SUMMARY
-- ----------------------------------------------------------------------------
-- Overall inspection compliance status by establishment.
-- Ontology: this view answers "is ehs:Evaluation happening on schedule?"

CREATE VIEW IF NOT EXISTS v_inspection_compliance_summary AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    -- Scheduled vs completed (last 30 days)
    (SELECT COUNT(*) FROM inspection_schedule WHERE establishment_id = e.id AND is_active = 1) AS active_schedules,

    (SELECT COUNT(*) FROM inspections i
     WHERE i.establishment_id = e.id
       AND date(i.inspection_date) >= date('now', '-30 days')) AS inspections_last_30_days,

    -- Overdue
    (SELECT COUNT(*) FROM inspection_schedule isc
     WHERE isc.establishment_id = e.id
       AND isc.is_active = 1
       AND date(isc.next_due_date) < date('now')) AS overdue_inspections,

    -- Findings
    (SELECT COUNT(*) FROM inspection_findings inf
     INNER JOIN inspections i ON inf.inspection_id = i.id
     WHERE i.establishment_id = e.id
       AND inf.status = 'open') AS open_findings,

    -- Overall status
    CASE
        WHEN (SELECT COUNT(*) FROM inspection_schedule isc
              WHERE isc.establishment_id = e.id AND isc.is_active = 1
              AND date(isc.next_due_date) < date('now')) > 0 THEN 'NON-COMPLIANT'
        WHEN (SELECT COUNT(*) FROM inspection_findings inf
              INNER JOIN inspections i ON inf.inspection_id = i.id
              WHERE i.establishment_id = e.id AND inf.status = 'open' AND inf.severity = 'critical') > 0 THEN 'AT_RISK'
        ELSE 'COMPLIANT'
    END AS compliance_status

FROM establishments e;


-- ----------------------------------------------------------------------------
-- V_OPEN_CORRECTIVE_ACTIONS_FROM_INSPECTIONS
-- ----------------------------------------------------------------------------
-- All open corrective actions that originated from inspection findings.
-- Replaces the old v_open_cars view for inspection-sourced CARs.

CREATE VIEW IF NOT EXISTS v_open_corrective_actions_from_inspections AS
SELECT
    ca.id AS corrective_action_id,
    ca.description AS action_description,
    ca.hierarchy_level,
    ca.status,
    ca.due_date,
    ca.assigned_to,
    CAST(julianday('now') - julianday(ca.created_at) AS INTEGER) AS days_open,
    CAST(julianday(ca.due_date) - julianday('now') AS INTEGER) AS days_until_due,
    CASE
        WHEN ca.due_date IS NOT NULL AND date(ca.due_date) < date('now') THEN 'OVERDUE'
        WHEN ca.due_date IS NOT NULL AND date(ca.due_date) <= date('now', '+7 days') THEN 'DUE_SOON'
        ELSE 'ON_TRACK'
    END AS urgency,
    inf.finding_number,
    inf.finding_description,
    inf.severity AS finding_severity,
    i.inspection_number,
    i.inspection_date,
    it.type_code AS inspection_type,
    i.establishment_id
FROM corrective_actions ca
INNER JOIN inspection_findings inf ON inf.corrective_action_id = ca.id
INNER JOIN inspections i ON inf.inspection_id = i.id
INNER JOIN inspection_types it ON i.inspection_type_id = it.id
WHERE ca.status NOT IN ('completed', 'verified')
ORDER BY
    CASE inf.severity WHEN 'critical' THEN 1 WHEN 'major' THEN 2 ELSE 3 END,
    ca.due_date ASC;


-- ----------------------------------------------------------------------------
-- V_OPEN_CORRECTIVE_ACTIONS_FROM_AUDITS
-- ----------------------------------------------------------------------------
-- All open corrective actions that originated from audit findings.

CREATE VIEW IF NOT EXISTS v_open_corrective_actions_from_audits AS
SELECT
    ca.id AS corrective_action_id,
    ca.description AS action_description,
    ca.hierarchy_level,
    ca.status,
    ca.due_date,
    ca.assigned_to,
    CAST(julianday('now') - julianday(ca.created_at) AS INTEGER) AS days_open,
    CAST(julianday(ca.due_date) - julianday('now') AS INTEGER) AS days_until_due,
    CASE
        WHEN ca.due_date IS NOT NULL AND date(ca.due_date) < date('now') THEN 'OVERDUE'
        WHEN ca.due_date IS NOT NULL AND date(ca.due_date) <= date('now', '+7 days') THEN 'DUE_SOON'
        ELSE 'ON_TRACK'
    END AS urgency,
    af.finding_number,
    af.finding_type,
    af.finding_statement,
    af.clause_number,
    af.clause_title,
    a.audit_number,
    a.audit_title,
    a.audit_type,
    iso.standard_code,
    a.establishment_id
FROM corrective_actions ca
INNER JOIN audit_findings af ON af.corrective_action_id = ca.id
INNER JOIN audits a ON af.audit_id = a.id
LEFT JOIN iso_standards iso ON a.standard_id = iso.id
WHERE ca.status NOT IN ('completed', 'verified')
ORDER BY
    CASE af.finding_type WHEN 'major_nc' THEN 1 WHEN 'minor_nc' THEN 2 ELSE 3 END,
    ca.due_date ASC;


-- ----------------------------------------------------------------------------
-- V_CORRECTIVE_ACTIONS_OVERDUE
-- ----------------------------------------------------------------------------
-- Corrective actions past due from any source (inspection or audit findings).

CREATE VIEW IF NOT EXISTS v_corrective_actions_overdue AS
SELECT
    ca.id AS corrective_action_id,
    ca.description AS action_description,
    ca.hierarchy_level,
    ca.due_date,
    CAST(julianday('now') - julianday(ca.due_date) AS INTEGER) AS days_overdue,
    ca.assigned_to,
    ca.status,
    -- Source: inspection finding
    inf.finding_number AS inspection_finding_number,
    inf.severity AS inspection_finding_severity,
    i.establishment_id AS inspection_establishment_id,
    -- Source: audit finding
    af.finding_number AS audit_finding_number,
    af.finding_type AS audit_finding_type,
    a.establishment_id AS audit_establishment_id
FROM corrective_actions ca
LEFT JOIN inspection_findings inf ON inf.corrective_action_id = ca.id
LEFT JOIN inspections i ON inf.inspection_id = i.id
LEFT JOIN audit_findings af ON af.corrective_action_id = ca.id
LEFT JOIN audits a ON af.audit_id = a.id
WHERE ca.status NOT IN ('completed', 'verified')
  AND ca.due_date IS NOT NULL
  AND date(ca.due_date) < date('now')
ORDER BY ca.due_date ASC;


-- ----------------------------------------------------------------------------
-- V_VERIFICATION_DUE
-- ----------------------------------------------------------------------------
-- Corrective actions that have been completed but not yet verified.
-- Ontology: verification IS ehs:Confirm — the action isn't done until
-- effectiveness is confirmed.

CREATE VIEW IF NOT EXISTS v_verification_due AS
SELECT
    ca.id AS corrective_action_id,
    ca.description AS action_description,
    ca.hierarchy_level,
    ca.completed_date,
    ca.completed_by,
    ca.status,
    ca.verification_notes,
    -- Source: inspection finding
    inf.finding_number AS inspection_finding_number,
    inf.finding_description,
    i.inspection_number,
    i.establishment_id AS inspection_establishment_id,
    -- Source: audit finding
    af.finding_number AS audit_finding_number,
    af.finding_statement,
    af.clause_number,
    a.audit_number,
    a.establishment_id AS audit_establishment_id
FROM corrective_actions ca
LEFT JOIN inspection_findings inf ON inf.corrective_action_id = ca.id
LEFT JOIN inspections i ON inf.inspection_id = i.id
LEFT JOIN audit_findings af ON af.corrective_action_id = ca.id
LEFT JOIN audits a ON af.audit_id = a.id
WHERE ca.status = 'completed'
  AND ca.verified_date IS NULL
ORDER BY ca.completed_date ASC;


-- ----------------------------------------------------------------------------
-- V_ROOT_CAUSE_TRENDING
-- ----------------------------------------------------------------------------
-- Root cause category trending across investigations linked to inspection
-- and audit findings. Identifies systemic issues.
-- Uses root_cause_categories reference table + incident_investigations.

CREATE VIEW IF NOT EXISTS v_root_cause_trending AS
SELECT
    inc.establishment_id,
    ii.rca_method,
    rc.code AS root_cause_category,
    rc.name AS root_cause_name,
    COUNT(*) AS occurrence_count,
    strftime('%Y', ii.completed_date) AS year,
    GROUP_CONCAT(DISTINCT inc.case_number) AS related_case_numbers
FROM incident_investigations ii
INNER JOIN incidents inc ON ii.incident_id = inc.id
INNER JOIN root_cause_categories rc ON ii.root_causes LIKE '%' || rc.code || '%'
WHERE ii.status = 'completed'
  AND ii.root_causes IS NOT NULL
GROUP BY inc.establishment_id, rc.code, rc.name, strftime('%Y', ii.completed_date)
ORDER BY year DESC, occurrence_count DESC;


-- ----------------------------------------------------------------------------
-- V_AUDIT_FINDINGS_BY_CLAUSE
-- ----------------------------------------------------------------------------
-- Trending of audit findings by ISO clause — identifies weak areas.
-- Ontology: this view answers "which ehs:ControlMeasure areas consistently
-- fail ehs:Confirm?" — the most actionable trending for management review.

CREATE VIEW IF NOT EXISTS v_audit_findings_by_clause AS
SELECT
    a.establishment_id,
    a.standard_id,
    iso.standard_code,
    af.clause_number,
    ic.clause_title,
    COUNT(*) AS finding_count,
    SUM(CASE WHEN af.finding_type = 'major_nc' THEN 1 ELSE 0 END) AS major_nc_count,
    SUM(CASE WHEN af.finding_type = 'minor_nc' THEN 1 ELSE 0 END) AS minor_nc_count,
    SUM(CASE WHEN af.finding_type = 'ofi' THEN 1 ELSE 0 END) AS ofi_count,
    SUM(CASE WHEN af.is_repeat_finding = 1 THEN 1 ELSE 0 END) AS repeat_findings,
    GROUP_CONCAT(DISTINCT strftime('%Y', a.actual_start_date)) AS years_with_findings
FROM audit_findings af
INNER JOIN audits a ON af.audit_id = a.id
INNER JOIN iso_standards iso ON a.standard_id = iso.id
LEFT JOIN iso_clauses ic ON af.clause_id = ic.id
WHERE af.clause_number IS NOT NULL
GROUP BY a.establishment_id, a.standard_id, iso.standard_code, af.clause_number, ic.clause_title
ORDER BY finding_count DESC;


-- ----------------------------------------------------------------------------
-- V_AUDIT_STATUS_SUMMARY
-- ----------------------------------------------------------------------------
-- Audit status summary by establishment.

CREATE VIEW IF NOT EXISTS v_audit_status_summary AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,

    -- Last audit dates by standard
    (SELECT MAX(actual_end_date) FROM audits WHERE establishment_id = e.id AND standard_id = 1) AS last_14001_audit,
    (SELECT MAX(actual_end_date) FROM audits WHERE establishment_id = e.id AND standard_id = 2) AS last_45001_audit,
    (SELECT MAX(actual_end_date) FROM audits WHERE establishment_id = e.id AND standard_id = 3) AS last_50001_audit,

    -- Open findings by type
    (SELECT COUNT(*) FROM audit_findings af
     INNER JOIN audits a ON af.audit_id = a.id
     WHERE a.establishment_id = e.id AND af.status = 'open' AND af.finding_type = 'major_nc') AS open_major_nc,
    (SELECT COUNT(*) FROM audit_findings af
     INNER JOIN audits a ON af.audit_id = a.id
     WHERE a.establishment_id = e.id AND af.status = 'open' AND af.finding_type = 'minor_nc') AS open_minor_nc,

    -- Corrective actions from audit findings this year
    (SELECT COUNT(*) FROM corrective_actions ca
     INNER JOIN audit_findings af ON af.corrective_action_id = ca.id
     INNER JOIN audits a ON af.audit_id = a.id
     WHERE a.establishment_id = e.id
       AND strftime('%Y', ca.created_at) = strftime('%Y', 'now')) AS corrective_actions_this_year,

    -- Open corrective actions from audit findings
    (SELECT COUNT(*) FROM corrective_actions ca
     INNER JOIN audit_findings af ON af.corrective_action_id = ca.id
     INNER JOIN audits a ON af.audit_id = a.id
     WHERE a.establishment_id = e.id
       AND ca.status NOT IN ('completed', 'verified')) AS open_corrective_actions,

    -- Overdue corrective actions from audit findings
    (SELECT COUNT(*) FROM corrective_actions ca
     INNER JOIN audit_findings af ON af.corrective_action_id = ca.id
     INNER JOIN audits a ON af.audit_id = a.id
     WHERE a.establishment_id = e.id
       AND ca.status NOT IN ('completed', 'verified')
       AND ca.due_date IS NOT NULL
       AND date(ca.due_date) < date('now')) AS overdue_corrective_actions

FROM establishments e;


-- ----------------------------------------------------------------------------
-- V_INSPECTIONS_BY_HAZARD_TYPE
-- ----------------------------------------------------------------------------
-- Inspection activity grouped by ontology hazard type.
-- Ontology: this view answers "how thoroughly are we evaluating each
-- ehs:HazardType across our inspection program?"

CREATE VIEW IF NOT EXISTS v_inspections_by_hazard_type AS
SELECT
    htc.code AS hazard_type_code,
    htc.name AS hazard_type_name,
    i.establishment_id,
    e.name AS establishment_name,
    COUNT(DISTINCT i.id) AS inspection_count,
    MIN(i.inspection_date) AS earliest_inspection,
    MAX(i.inspection_date) AS latest_inspection,
    SUM(CASE WHEN i.overall_result = 'fail' THEN 1 ELSE 0 END) AS failed_inspections,
    SUM(CASE WHEN i.overall_result = 'pass_with_findings' THEN 1 ELSE 0 END) AS inspections_with_findings
FROM inspection_hazard_types iht
INNER JOIN hazard_type_codes htc ON iht.hazard_type_code = htc.code
INNER JOIN inspections i ON iht.inspection_id = i.id
INNER JOIN establishments e ON i.establishment_id = e.id
GROUP BY htc.code, htc.name, i.establishment_id, e.name
ORDER BY inspection_count DESC;


-- ============================================================================
-- TRIGGERS
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Update inspection schedule when inspection completed
-- ----------------------------------------------------------------------------
-- Automatically advances the next_due_date based on frequency when a
-- completed inspection is inserted.

CREATE TRIGGER IF NOT EXISTS trg_inspection_update_schedule
AFTER INSERT ON inspections
WHEN NEW.status = 'completed'
BEGIN
    UPDATE inspection_schedule
    SET last_inspection_date = NEW.inspection_date,
        last_inspection_id = NEW.id,
        next_due_date = CASE frequency
            WHEN 'daily' THEN date(NEW.inspection_date, '+1 day')
            WHEN 'weekly' THEN date(NEW.inspection_date, '+7 days')
            WHEN 'monthly' THEN date(NEW.inspection_date, '+1 month')
            WHEN 'quarterly' THEN date(NEW.inspection_date, '+3 months')
            WHEN 'annual' THEN date(NEW.inspection_date, '+1 year')
            ELSE next_due_date
        END,
        updated_at = datetime('now')
    WHERE establishment_id = NEW.establishment_id
      AND inspection_type_id = NEW.inspection_type_id;
END;


-- ----------------------------------------------------------------------------
-- Update audit finding counts when findings change
-- ----------------------------------------------------------------------------
-- Keeps the denormalized counts on the audits table in sync.

CREATE TRIGGER IF NOT EXISTS trg_audit_finding_count_insert
AFTER INSERT ON audit_findings
BEGIN
    UPDATE audits
    SET total_findings = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = NEW.audit_id),
        major_nonconformities = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = NEW.audit_id AND finding_type = 'major_nc'),
        minor_nonconformities = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = NEW.audit_id AND finding_type = 'minor_nc'),
        opportunities_for_improvement = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = NEW.audit_id AND finding_type = 'ofi'),
        positive_findings = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = NEW.audit_id AND finding_type = 'positive'),
        updated_at = datetime('now')
    WHERE id = NEW.audit_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_audit_finding_count_delete
AFTER DELETE ON audit_findings
BEGIN
    UPDATE audits
    SET total_findings = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = OLD.audit_id),
        major_nonconformities = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = OLD.audit_id AND finding_type = 'major_nc'),
        minor_nonconformities = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = OLD.audit_id AND finding_type = 'minor_nc'),
        opportunities_for_improvement = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = OLD.audit_id AND finding_type = 'ofi'),
        positive_findings = (SELECT COUNT(*) FROM audit_findings WHERE audit_id = OLD.audit_id AND finding_type = 'positive'),
        updated_at = datetime('now')
    WHERE id = OLD.audit_id;
END;


-- ----------------------------------------------------------------------------
-- Link corrective action to inspection finding when assigned
-- ----------------------------------------------------------------------------
-- When an inspection finding gets a corrective_action_id, update its status.

CREATE TRIGGER IF NOT EXISTS trg_inspection_finding_link_corrective_action
AFTER UPDATE OF corrective_action_id ON inspection_findings
WHEN NEW.corrective_action_id IS NOT NULL AND OLD.corrective_action_id IS NULL
BEGIN
    UPDATE inspection_findings
    SET status = 'corrective_action_issued',
        updated_at = datetime('now')
    WHERE id = NEW.id;
END;


-- ----------------------------------------------------------------------------
-- Link corrective action to audit finding when assigned
-- ----------------------------------------------------------------------------
-- When an audit finding gets a corrective_action_id, update its status.

CREATE TRIGGER IF NOT EXISTS trg_audit_finding_link_corrective_action
AFTER UPDATE OF corrective_action_id ON audit_findings
WHEN NEW.corrective_action_id IS NOT NULL AND OLD.corrective_action_id IS NULL
BEGIN
    UPDATE audit_findings
    SET status = 'corrective_action_issued',
        updated_at = datetime('now')
    WHERE id = NEW.id;
END;


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================
/*
-- 1. Record a SWPPP inspection and link to hazard types
INSERT INTO inspections
    (establishment_id, inspection_type_id, inspection_date, inspector_id,
     areas_inspected, overall_result, status)
VALUES
    (1, 1, date('now'), 5, 'All outdoor areas, outfalls OF-001 through OF-003', 'pass', 'completed');

-- Link to chemical hazard type (stormwater pollutants)
INSERT INTO inspection_hazard_types (inspection_id, hazard_type_code, notes)
VALUES (last_insert_rowid(), 'CHEMICAL', 'Stormwater pollutant controls');

-- 2. Copy checklist template items for new inspection
INSERT INTO inspection_checklist_responses
    (inspection_id, template_item_id, item_order, checklist_item, category)
SELECT
    ?, -- new inspection_id
    ict.id,
    ict.item_order,
    ict.checklist_item,
    ict.category
FROM inspection_checklist_templates ict
WHERE ict.inspection_type_id = 1  -- SWPPP
  AND ict.is_active = 1
ORDER BY ict.item_order;

-- 3. Create corrective action from an inspection finding
-- First, insert the corrective action (in Module C/D's table)
INSERT INTO corrective_actions
    (investigation_id, description, hierarchy_level, assigned_to, due_date)
VALUES
    (NULL, 'Repair cracked secondary containment wall in Tank Farm B',
     'engineering', 'Maintenance Supervisor', date('now', '+14 days'));

-- Then link it to the inspection finding
UPDATE inspection_findings
SET corrective_action_id = last_insert_rowid()
WHERE id = ?;  -- finding_id

-- 4. Find all inspections related to electrical hazards
SELECT i.*, it.type_name
FROM inspections i
INNER JOIN inspection_hazard_types iht ON i.id = iht.inspection_id
INNER JOIN inspection_types it ON i.inspection_type_id = it.id
WHERE iht.hazard_type_code = 'ELECTRICAL'
ORDER BY i.inspection_date DESC;

-- 5. Find inspections that are overdue
SELECT * FROM v_inspections_due WHERE urgency = 'OVERDUE';

-- 6. Get clause-level trending for ISO 14001
SELECT * FROM v_audit_findings_by_clause
WHERE establishment_id = 1 AND standard_code = '14001'
ORDER BY finding_count DESC;

-- 7. Create a corrective action from an audit finding at clause 7.2
INSERT INTO corrective_actions
    (investigation_id, description, hierarchy_level, assigned_to, due_date)
VALUES
    (NULL, 'Establish competence requirements for new EMS coordinator role',
     'administrative', 'EHS Manager', date('now', '+30 days'));

UPDATE audit_findings
SET corrective_action_id = last_insert_rowid(),
    training_requirement_id = 5  -- link to specific training requirement
WHERE id = ?;  -- finding_id

-- 8. Plan an internal audit by clause
INSERT INTO audit_scope (audit_id, scope_type, scope_item, clause_id, scheduled_date)
SELECT
    1,  -- audit_id
    'clause',
    ic.clause_number || ' ' || ic.clause_title,
    ic.id,
    date('now', '+' || (ROW_NUMBER() OVER (ORDER BY ic.clause_number) - 1) || ' days')
FROM iso_clauses ic
WHERE ic.standard_id = 1  -- ISO 14001
  AND ic.clause_level <= 2  -- Main clauses and first-level subclauses
ORDER BY ic.clause_number;

-- 9. Inspection coverage by hazard type
SELECT * FROM v_inspections_by_hazard_type
WHERE establishment_id = 1
ORDER BY hazard_type_name;

-- 10. Get audit findings that are repeat issues
SELECT
    af.finding_number,
    af.clause_number,
    af.finding_statement,
    a.audit_title,
    prev_af.finding_number AS previous_finding,
    prev_a.audit_title AS previous_audit
FROM audit_findings af
INNER JOIN audits a ON af.audit_id = a.id
LEFT JOIN audit_findings prev_af ON af.previous_finding_id = prev_af.id
LEFT JOIN audits prev_a ON prev_af.audit_id = prev_a.id
WHERE af.is_repeat_finding = 1;

-- 11. Root cause trending across investigations
SELECT * FROM v_root_cause_trending
WHERE establishment_id = 1
ORDER BY year DESC, occurrence_count DESC;
*/


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
INSPECTIONS & AUDITS MODULE (module_inspections_audits.sql)
Derived from ehs-ontology-v3.1.ttl — ehs:Evaluation (5 E's) + ehs:Confirm (ARECC)

ONTOLOGY ALIGNMENT:
  - Inspections = ehs:Evaluation (continuous measurement using leading indicators)
  - Audits = ehs:Confirm (verifying that controls are effective)
  - Findings link to corrective_actions (Module C/D) rather than duplicating CAR tables
  - inspection_hazard_types junction bridges to ehs:HazardType taxonomy
  - root_cause_categories provides shared trending reference for all modules

REFERENCE TABLES:
  ISO Standards & Clauses:
    - iso_standards: The three standards (14001, 45001, 50001)
    - iso_clauses: Clause structure for each standard (155 clauses pre-seeded)

  Root Cause Categories:
    - root_cause_categories: 9 categories for trending (shared across modules)

  Inspection Framework:
    - inspection_types: Types of inspections (14 types pre-seeded)
    - inspection_checklist_templates: Pre-seeded checklist items by type (50+ items)

  Facility-Specific:
    - swppp_outfalls: Stormwater outfall definitions
    - spcc_containers: Oil storage containers under SPCC

INSPECTION TABLES:
    - inspections: Master inspection record (+ work_area_id cross-module FK)
    - inspection_hazard_types: Junction to ontology hazard types (NEW)
    - inspection_checklist_responses: Completed checklist items
    - inspection_findings: Issues discovered (+ corrective_action_id, incident_id FKs)
    - inspection_schedule: Recurring inspection schedules

AUDIT TABLES:
    - audits: Master audit record (internal/external, ISO standard)
    - audit_team: Audit team members and assignments
    - audit_scope: Detailed scope by process/clause/area
    - audit_findings: Findings with clause-level tracking (+ corrective_action_id,
      training_requirement_id FKs)

REMOVED (now in Module C/D):
    - car_records → use corrective_actions from module_c_osha300.sql
    - car_root_cause → use incident_investigations.root_causes + root_cause_categories
    - car_actions → corrective_actions handles individual actions
    - car_verification → corrective_actions.verified_date/verified_by

VIEWS:
  Compliance Monitoring:
    - v_inspections_due: Upcoming/overdue inspections
    - v_inspection_compliance_summary: Overall inspection status by establishment

  Corrective Action Management:
    - v_open_corrective_actions_from_inspections: Open CAs from inspection findings
    - v_open_corrective_actions_from_audits: Open CAs from audit findings
    - v_corrective_actions_overdue: Past-due actions from any source
    - v_verification_due: Completed but unverified corrective actions

  Trending & Analysis:
    - v_root_cause_trending: Root cause categories over time
    - v_audit_findings_by_clause: Findings by ISO clause (weak area identification)
    - v_audit_status_summary: Audit and CA status overview
    - v_inspections_by_hazard_type: Inspection activity by ontology hazard type (NEW)

TRIGGERS:
    - trg_inspection_update_schedule: Update schedule after inspection completed
    - trg_audit_finding_count_insert/delete: Keep audit finding counts current
    - trg_inspection_finding_link_corrective_action: Status update on CA linkage
    - trg_audit_finding_link_corrective_action: Status update on CA linkage

CROSS-MODULE FOREIGN KEYS:
    - inspections.work_area_id → work_areas (training module)
    - inspection_hazard_types.hazard_type_code → hazard_type_codes (training module)
    - inspection_findings.corrective_action_id → corrective_actions (Module C/D)
    - inspection_findings.incident_id → incidents (Module C/D)
    - audit_findings.corrective_action_id → corrective_actions (Module C/D)
    - audit_findings.training_requirement_id → training_regulatory_requirements (training module)

PRE-SEEDED DATA:
  ISO Clauses (155 total):
    - ISO 14001:2015 clauses (48 clauses including subclauses)
    - ISO 45001:2018 clauses (63 clauses including subclauses)
    - ISO 50001:2018 clauses (44 clauses including subclauses)

  Root Cause Categories (9):
    - TRAINING, PROCEDURE, EQUIPMENT, COMMUNICATION, RESOURCE,
      MANAGEMENT, DESIGN, HUMAN_FACTORS, ORGANIZATIONAL_CULTURE

  Inspection Types (14 types):
    - Environmental: SWPPP, SPCC, SWPPP_STORM
    - Safety: SAFETY_WALK, FIRE_EXT, EYEWASH, EMERG_LIGHT, EXIT_SIGN, FIRST_AID
    - Equipment: FORKLIFT_PRE, CRANE, LADDER
    - Waste: HAZWASTE_WEEKLY, USED_OIL

  Checklist Templates (50+ items):
    - SWPPP inspection checklist (16 items + 4 post-storm items)
    - SPCC inspection checklist (15 items)
    - Fire extinguisher checklist (7 items)
    - Eyewash/safety shower checklist (7 items)
    - General safety walkthrough checklist (10 items)

REGULATORY DRIVERS:
  - EPA SWPPP (NPDES CGP)
  - EPA SPCC (40 CFR 112)
  - ISO 14001:2015 (Environmental)
  - ISO 45001:2018 (Health & Safety)
  - ISO 50001:2018 (Energy)
  - OSHA various (fire extinguishers, eyewash, forklifts, cranes, ladders)
  - RCRA (40 CFR 265.174 — hazardous waste accumulation area inspections)
  - EPA MSGP / State NPDES stormwater general permits (40 CFR 122.26)
*/


-- ############################################################
-- STORMWATER VISUAL MONITORING EXTENSION
-- ############################################################
-- Extends the inspections module with stormwater-specific tables.
-- Stormwater monitoring is fundamentally an inspection activity:
-- visual observations at outfalls on a schedule, with findings
-- that generate corrective actions.
--
-- The unique pieces are: storm event tracking (qualifying events
-- trigger 72-hour inspection requirements) and annual report rollup.
--
-- Outfall definitions (swppp_outfalls) are already in this module.
-- This extension adds the monitoring workflow on top of them.
--
-- Ontology connection: ehs:Evaluation (5 E's) — stormwater
-- monitoring is continuous measurement of environmental controls.
-- Also connects to EPA_Framework via CWA stormwater provisions.
--
-- Regulatory References:
--   EPA MSGP (Multi-Sector General Permit)
--   State NPDES stormwater general permits
--   40 CFR 122.26 — Stormwater discharge requirements


-- ============================================================================
-- REFERENCE: VISUAL OBSERVATION PARAMETERS
-- ============================================================================
-- Standard EPA MSGP visual observation categories. Consistent across
-- most stormwater general permits in North America.

CREATE TABLE IF NOT EXISTS sw_observation_parameters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    parameter_code TEXT NOT NULL UNIQUE,
    parameter_name TEXT NOT NULL,
    description TEXT,
    observation_type TEXT,                  -- 'yes_no', 'descriptive', 'severity'

    typical_values TEXT,                    -- JSON array of common responses
    display_order INTEGER,

    created_at TEXT DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO sw_observation_parameters
    (id, parameter_code, parameter_name, description, observation_type, typical_values, display_order) VALUES
    (1, 'DISCHARGE_PRESENT', 'Discharge Present',
        'Is there discharge from this outfall?', 'yes_no', '["Yes", "No"]', 1),
    (2, 'COLOR', 'Color',
        'Color of discharge (if present)', 'descriptive',
        '["Clear", "Light Brown", "Brown", "Dark Brown", "Yellow", "Green", "Orange", "Red", "Other"]', 2),
    (3, 'ODOR', 'Odor',
        'Unusual odor present', 'severity', '["None", "Slight", "Moderate", "Strong"]', 3),
    (4, 'SHEEN', 'Sheen',
        'Oil sheen or petroleum products visible on surface', 'severity', '["None", "Slight", "Moderate", "Heavy"]', 4),
    (5, 'FLOATABLES', 'Floatables',
        'Floating materials, debris, or foam', 'severity', '["None", "Minor", "Moderate", "Significant"]', 5),
    (6, 'SUSPENDED_SOLIDS', 'Suspended Solids/Turbidity',
        'Visible suspended solids or cloudiness', 'descriptive',
        '["Clear", "Slightly Cloudy", "Cloudy", "Very Cloudy", "Opaque"]', 6),
    (7, 'FOAM', 'Foam',
        'Suds or foam present', 'severity', '["None", "Slight", "Moderate", "Excessive"]', 7),
    (8, 'EROSION', 'Erosion',
        'Erosion or sediment at outfall', 'severity', '["None", "Minor", "Moderate", "Severe"]', 8),
    (9, 'FLOW_RATE', 'Flow Rate',
        'Visual estimate of discharge flow', 'descriptive',
        '["No Flow", "Trickle", "Moderate", "Heavy"]', 9),
    (10, 'OUTFALL_CONDITION', 'Outfall Condition',
        'Physical condition of outfall structure', 'descriptive',
        '["Good", "Fair", "Poor", "Needs Repair"]', 10);


-- ============================================================================
-- STORM EVENTS
-- ============================================================================
-- Track qualifying storm events. Most permits define "qualifying event" as
-- rainfall above a threshold (e.g., 0.1 inches) that generates runoff.

CREATE TABLE IF NOT EXISTS sw_storm_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,

    event_number TEXT,

    -- Storm timing
    storm_start_datetime TEXT NOT NULL,
    storm_end_datetime TEXT,
    duration_hours REAL,

    -- Rainfall
    rainfall_amount REAL,
    rainfall_units TEXT DEFAULT 'inches',
    rainfall_estimated INTEGER DEFAULT 1,
    rainfall_source TEXT,                   -- 'on-site gauge', 'weather service', 'estimated'
    weather_station_id TEXT,

    -- Qualifying determination
    is_qualifying_event INTEGER DEFAULT 0,
    qualifying_criteria TEXT,

    hours_since_last_storm REAL,
    weather_conditions TEXT,
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id)
);

CREATE INDEX idx_sw_events_establishment ON sw_storm_events(establishment_id);
CREATE INDEX idx_sw_events_start ON sw_storm_events(storm_start_datetime);
CREATE INDEX idx_sw_events_qualifying ON sw_storm_events(is_qualifying_event);


-- ============================================================================
-- OUTFALL INSPECTIONS (Stormwater Visual Monitoring)
-- ============================================================================
-- Each inspection is one visit to one outfall to make visual observations.
-- Links to swppp_outfalls already defined earlier in this module.

CREATE TABLE IF NOT EXISTS sw_outfall_inspections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    outfall_id INTEGER NOT NULL,

    inspection_number TEXT,

    -- When and who
    inspection_date TEXT NOT NULL,
    inspection_time TEXT,
    inspected_by_employee_id INTEGER,

    -- Inspection type
    inspection_type TEXT NOT NULL,          -- 'monthly', 'quarterly', 'storm_event', 'follow_up'

    -- Storm event relationship
    storm_event_id INTEGER,
    hours_after_storm REAL,
    within_72_hours INTEGER DEFAULT 0,

    -- Weather at time of inspection
    weather_at_inspection TEXT,
    temperature_f REAL,

    -- Overall assessment
    discharge_observed INTEGER DEFAULT 0,
    overall_condition TEXT,                 -- 'satisfactory', 'concerning', 'unsatisfactory'

    -- Corrective actions
    corrective_action_needed INTEGER DEFAULT 0,
    corrective_action_description TEXT,
    corrective_action_taken TEXT,
    corrective_action_id INTEGER,          -- FK to corrective_actions (Module C/D)

    -- Follow-up
    requires_follow_up INTEGER DEFAULT 0,
    follow_up_date TEXT,

    photo_paths TEXT,
    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (outfall_id) REFERENCES swppp_outfalls(id),
    FOREIGN KEY (inspected_by_employee_id) REFERENCES employees(id),
    FOREIGN KEY (storm_event_id) REFERENCES sw_storm_events(id),
    FOREIGN KEY (corrective_action_id) REFERENCES corrective_actions(id)
);

CREATE INDEX idx_sw_inspections_establishment ON sw_outfall_inspections(establishment_id);
CREATE INDEX idx_sw_inspections_outfall ON sw_outfall_inspections(outfall_id);
CREATE INDEX idx_sw_inspections_date ON sw_outfall_inspections(inspection_date);
CREATE INDEX idx_sw_inspections_storm ON sw_outfall_inspections(storm_event_id);
CREATE INDEX idx_sw_inspections_type ON sw_outfall_inspections(inspection_type);


-- ============================================================================
-- VISUAL OBSERVATIONS
-- ============================================================================
-- Individual observations made during each outfall inspection.
-- Qualitative data (descriptions, yes/no) not quantitative (numeric values).

CREATE TABLE IF NOT EXISTS sw_visual_observations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    inspection_id INTEGER NOT NULL,
    parameter_id INTEGER NOT NULL,

    observation_value TEXT,
    observation_notes TEXT,
    is_concerning INTEGER DEFAULT 0,

    created_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (inspection_id) REFERENCES sw_outfall_inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (parameter_id) REFERENCES sw_observation_parameters(id)
);

CREATE INDEX idx_sw_observations_inspection ON sw_visual_observations(inspection_id);
CREATE INDEX idx_sw_observations_parameter ON sw_visual_observations(parameter_id);


-- ============================================================================
-- STORMWATER INSPECTION SCHEDULE
-- ============================================================================

CREATE TABLE IF NOT EXISTS sw_inspection_schedule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    outfall_id INTEGER NOT NULL,

    frequency_type TEXT NOT NULL,           -- 'monthly', 'quarterly', 'storm_event'
    is_active INTEGER DEFAULT 1,

    within_hours_of_storm INTEGER,          -- Must inspect within X hours (typically 72)
    next_scheduled_date TEXT,

    permit_id INTEGER,
    permit_condition_id INTEGER,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (outfall_id) REFERENCES swppp_outfalls(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    UNIQUE(establishment_id, outfall_id, frequency_type)
);

CREATE INDEX idx_sw_schedule_establishment ON sw_inspection_schedule(establishment_id);
CREATE INDEX idx_sw_schedule_outfall ON sw_inspection_schedule(outfall_id);
CREATE INDEX idx_sw_schedule_next_date ON sw_inspection_schedule(next_scheduled_date);


-- ============================================================================
-- STORMWATER ANNUAL REPORTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS sw_annual_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    permit_id INTEGER NOT NULL,

    report_year INTEGER NOT NULL,
    period_start_date TEXT NOT NULL,
    period_end_date TEXT NOT NULL,

    -- Summary statistics
    total_storm_events INTEGER,
    qualifying_storm_events INTEGER,
    total_inspections_conducted INTEGER,
    inspections_with_discharge INTEGER,
    inspections_with_concerns INTEGER,
    corrective_actions_implemented INTEGER,

    -- Submission tracking
    report_due_date TEXT,
    report_submitted_date TEXT,
    submission_confirmation_number TEXT,
    submission_method TEXT,

    report_document_path TEXT,
    status TEXT DEFAULT 'draft',

    -- Certification
    certified_by TEXT,
    certified_title TEXT,
    certified_date TEXT,

    notes TEXT,

    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),

    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (permit_id) REFERENCES permits(id),
    UNIQUE(establishment_id, permit_id, report_year)
);

CREATE INDEX idx_sw_reports_establishment ON sw_annual_reports(establishment_id);
CREATE INDEX idx_sw_reports_year ON sw_annual_reports(report_year);


-- ============================================================================
-- STORMWATER VIEWS
-- ============================================================================

-- Upcoming and overdue stormwater inspections
CREATE VIEW IF NOT EXISTS v_sw_inspections_due AS
SELECT
    e.id AS establishment_id,
    e.name AS establishment_name,
    o.id AS outfall_id,
    o.outfall_name,
    o.discharge_point_id,
    sch.frequency_type,
    sch.next_scheduled_date,
    (SELECT MAX(i.inspection_date)
     FROM sw_outfall_inspections i
     WHERE i.outfall_id = o.id
       AND i.inspection_type = sch.frequency_type) AS last_inspection_date,
    julianday(sch.next_scheduled_date) - julianday('now') AS days_until_due,
    CASE
        WHEN sch.next_scheduled_date < date('now') THEN 'OVERDUE'
        WHEN sch.next_scheduled_date <= date('now', '+7 days') THEN 'DUE_THIS_WEEK'
        WHEN sch.next_scheduled_date <= date('now', '+30 days') THEN 'DUE_THIS_MONTH'
        ELSE 'UPCOMING'
    END AS urgency,
    sch.permit_id
FROM sw_inspection_schedule sch
INNER JOIN establishments e ON sch.establishment_id = e.id
INNER JOIN swppp_outfalls o ON sch.outfall_id = o.id
WHERE sch.is_active = 1
  AND sch.next_scheduled_date IS NOT NULL
ORDER BY sch.next_scheduled_date;


-- Storm event 72-hour compliance
CREATE VIEW IF NOT EXISTS v_sw_storm_event_compliance AS
SELECT
    se.id AS storm_event_id,
    se.storm_start_datetime,
    se.rainfall_amount,
    se.rainfall_units,
    se.is_qualifying_event,
    e.id AS establishment_id,
    e.name AS establishment_name,
    (SELECT COUNT(*) FROM swppp_outfalls o
     WHERE o.establishment_id = e.id AND o.is_active = 1) AS total_outfalls,
    (SELECT COUNT(DISTINCT i.outfall_id)
     FROM sw_outfall_inspections i
     WHERE i.storm_event_id = se.id
       AND i.within_72_hours = 1) AS outfalls_inspected_on_time,
    CASE
        WHEN se.is_qualifying_event = 0 THEN 'N/A'
        WHEN (SELECT COUNT(DISTINCT i.outfall_id)
              FROM sw_outfall_inspections i
              WHERE i.storm_event_id = se.id
                AND i.within_72_hours = 1) >=
             (SELECT COUNT(*) FROM swppp_outfalls o
              WHERE o.establishment_id = e.id AND o.is_active = 1)
            THEN 'COMPLIANT'
        ELSE 'NON-COMPLIANT'
    END AS compliance_status
FROM sw_storm_events se
INNER JOIN establishments e ON se.establishment_id = e.id
WHERE se.is_qualifying_event = 1
ORDER BY se.storm_start_datetime DESC;


-- Concerning observations needing attention
CREATE VIEW IF NOT EXISTS v_sw_concerning_observations AS
SELECT
    i.id AS inspection_id,
    i.inspection_date,
    i.inspection_time,
    e.name AS establishment_name,
    o.outfall_name,
    p.parameter_name,
    vo.observation_value,
    vo.observation_notes,
    i.corrective_action_needed,
    i.corrective_action_description,
    i.corrective_action_taken
FROM sw_visual_observations vo
INNER JOIN sw_outfall_inspections i ON vo.inspection_id = i.id
INNER JOIN establishments e ON i.establishment_id = e.id
INNER JOIN swppp_outfalls o ON i.outfall_id = o.id
INNER JOIN sw_observation_parameters p ON vo.parameter_id = p.id
WHERE vo.is_concerning = 1
ORDER BY i.inspection_date DESC;


-- ============================================================================
-- STORMWATER TRIGGERS
-- ============================================================================

-- Auto-calculate hours after storm and 72-hour compliance
CREATE TRIGGER IF NOT EXISTS trg_sw_calculate_hours_after_storm
AFTER INSERT ON sw_outfall_inspections
FOR EACH ROW
WHEN NEW.storm_event_id IS NOT NULL
BEGIN
    UPDATE sw_outfall_inspections
    SET
        hours_after_storm =
            ROUND((julianday(NEW.inspection_date || ' ' || COALESCE(NEW.inspection_time, '12:00')) -
                   julianday((SELECT storm_start_datetime FROM sw_storm_events WHERE id = NEW.storm_event_id))) * 24, 1),
        within_72_hours =
            CASE WHEN (julianday(NEW.inspection_date || ' ' || COALESCE(NEW.inspection_time, '12:00')) -
                       julianday((SELECT storm_start_datetime FROM sw_storm_events WHERE id = NEW.storm_event_id))) * 24 <= 72
                 THEN 1 ELSE 0 END,
        updated_at = datetime('now')
    WHERE id = NEW.id;
END;

-- Update next scheduled date after stormwater inspection
CREATE TRIGGER IF NOT EXISTS trg_sw_update_schedule_after_inspection
AFTER INSERT ON sw_outfall_inspections
FOR EACH ROW
BEGIN
    UPDATE sw_inspection_schedule
    SET
        next_scheduled_date = date(NEW.inspection_date, '+1 month', 'start of month'),
        updated_at = datetime('now')
    WHERE establishment_id = NEW.establishment_id
      AND outfall_id = NEW.outfall_id
      AND frequency_type = 'monthly'
      AND NEW.inspection_type = 'monthly';

    UPDATE sw_inspection_schedule
    SET
        next_scheduled_date = date(NEW.inspection_date, '+3 months', 'start of month'),
        updated_at = datetime('now')
    WHERE establishment_id = NEW.establishment_id
      AND outfall_id = NEW.outfall_id
      AND frequency_type = 'quarterly'
      AND NEW.inspection_type = 'quarterly';
END;

-- Auto-calculate storm duration
CREATE TRIGGER IF NOT EXISTS trg_sw_calculate_storm_duration
AFTER INSERT ON sw_storm_events
FOR EACH ROW
WHEN NEW.storm_end_datetime IS NOT NULL
BEGIN
    UPDATE sw_storm_events
    SET
        duration_hours = ROUND((julianday(NEW.storm_end_datetime) - julianday(NEW.storm_start_datetime)) * 24, 1),
        updated_at = datetime('now')
    WHERE id = NEW.id;
END;
