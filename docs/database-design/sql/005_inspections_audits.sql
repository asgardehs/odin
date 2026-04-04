-- Waypoint-EHS - Inspections, Audits & Corrective Actions Schema
-- Comprehensive tracking for regulatory inspections, ISO management system audits,
-- and corrective action management.
--
-- Regulatory/Standard References:
--   EPA SWPPP    - Stormwater Pollution Prevention Plan inspections
--   EPA SPCC     - Spill Prevention, Control & Countermeasure inspections
--   ISO 14001    - Environmental Management System
--   ISO 45001    - Occupational Health & Safety Management System
--   ISO 50001    - Energy Management System
--
-- Key Features:
--   - Clause-level tracking for ISO audit findings
--   - Pre-seeded inspection checklists with customization
--   - Year-based CAR numbering (CAR-2025-001)
--   - Root cause analysis and effectiveness verification
--   - Links to other modules (chemicals, training, waste, incidents)
--
-- Connects to:
--   - establishments (001_incidents.sql)
--   - employees (001_incidents.sql)
--   - All other modules via CAR source references

-- ============================================================================
-- ISO STANDARDS REFERENCE
-- ============================================================================
-- The management system standards we track audits against.

CREATE TABLE IF NOT EXISTS iso_standards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    standard_code TEXT NOT NULL UNIQUE,     -- '14001', '45001', '50001'
    standard_name TEXT NOT NULL,
    full_title TEXT,
    current_version TEXT,                   -- '2015', '2018', '2018'
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
-- ISO CLAUSES REFERENCE
-- ============================================================================
-- Clause structure for each standard. Allows tracking findings to specific clauses.
-- Only including main clauses and first-level subclauses for practical use.

CREATE TABLE IF NOT EXISTS iso_clauses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    standard_id INTEGER NOT NULL,
    
    clause_number TEXT NOT NULL,            -- '4.1', '6.1.2', '10.2'
    clause_title TEXT NOT NULL,
    parent_clause TEXT,                     -- '6.1' for '6.1.2'
    clause_level INTEGER DEFAULT 1,         -- 1=main, 2=sub, 3=sub-sub
    
    description TEXT,
    
    -- For audit planning - typical audit time/focus
    typical_evidence TEXT,                  -- What auditors typically look for
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (standard_id) REFERENCES iso_standards(id),
    UNIQUE(standard_id, clause_number)
);

CREATE INDEX idx_iso_clauses_standard ON iso_clauses(standard_id);
CREATE INDEX idx_iso_clauses_number ON iso_clauses(clause_number);


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
    
    -- Clause 9: Performance evaluation
    (1, '9', 'Performance evaluation', NULL, 1, NULL),
    (1, '9.1', 'Monitoring, measurement, analysis and evaluation', '9', 2, 'Monitoring data, calibration records, analysis reports'),
    (1, '9.1.1', 'General', '9.1', 3, 'Monitoring and measurement plan'),
    (1, '9.1.2', 'Evaluation of compliance', '9.1', 3, 'Compliance evaluation records, audit reports'),
    (1, '9.2', 'Internal audit', '9', 2, 'Audit program, audit reports, auditor competence'),
    (1, '9.2.1', 'General', '9.2', 3, 'Audit program covering all requirements'),
    (1, '9.2.2', 'Internal audit programme', '9.2', 3, 'Audit schedule, scope, criteria, methods'),
    (1, '9.3', 'Management review', '9', 2, 'Management review minutes, inputs/outputs'),
    
    -- Clause 10: Improvement
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
    
    -- Clause 9: Performance evaluation
    (2, '9', 'Performance evaluation', NULL, 1, NULL),
    (2, '9.1', 'Monitoring, measurement, analysis and evaluation', '9', 2, 'Safety metrics, leading/lagging indicators'),
    (2, '9.1.1', 'General', '9.1', 3, 'Monitoring plan, equipment calibration'),
    (2, '9.1.2', 'Evaluation of compliance', '9.1', 3, 'Compliance audits, regulatory inspections'),
    (2, '9.2', 'Internal audit', '9', 2, 'Audit program, findings, auditor qualifications'),
    (2, '9.2.1', 'General', '9.2', 3, 'Audit requirements'),
    (2, '9.2.2', 'Internal audit programme', '9.2', 3, 'Audit schedule, methods'),
    (2, '9.3', 'Management review', '9', 2, 'Review minutes, inputs, outputs, actions'),
    
    -- Clause 10: Improvement
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
    
    -- Clause 9: Performance evaluation
    (3, '9', 'Performance evaluation', NULL, 1, NULL),
    (3, '9.1', 'Monitoring, measurement, analysis and evaluation of energy performance', '9', 2, 'Energy monitoring data, trend analysis'),
    (3, '9.1.1', 'General', '9.1', 3, 'Monitoring plan'),
    (3, '9.1.2', 'Evaluation of compliance with legal and other requirements', '9.1', 3, 'Energy compliance evaluation'),
    (3, '9.2', 'Internal audit', '9', 2, 'EnMS audits'),
    (3, '9.2.1', 'General', '9.2', 3, 'Audit requirements'),
    (3, '9.2.2', 'Internal audit programme', '9.2', 3, 'Audit program'),
    (3, '9.3', 'Management review', '9', 2, 'Energy management review'),
    
    -- Clause 10: Improvement
    (3, '10', 'Improvement', NULL, 1, NULL),
    (3, '10.1', 'Nonconformity and corrective action', '10', 2, 'Energy NCRs, CARs'),
    (3, '10.2', 'Continual improvement', '10', 2, 'Energy performance improvement');


-- ============================================================================
-- INSPECTION TYPES
-- ============================================================================
-- Categories of inspections that can be performed.

CREATE TABLE IF NOT EXISTS inspection_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    type_code TEXT NOT NULL UNIQUE,         -- 'SWPPP', 'SPCC', 'SAFETY_WALK', etc.
    type_name TEXT NOT NULL,
    description TEXT,
    
    -- Regulatory driver
    regulatory_citation TEXT,               -- '40 CFR 112.7', 'CGP Section 4.1'
    
    -- Frequency requirements
    default_frequency TEXT,                 -- 'weekly', 'monthly', 'quarterly', 'annual'
    frequency_notes TEXT,                   -- 'Within 24 hours of 0.25" rain event'
    
    -- Retention
    retention_years INTEGER DEFAULT 3,
    
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);


INSERT OR IGNORE INTO inspection_types (id, type_code, type_name, description, regulatory_citation, default_frequency, frequency_notes, retention_years) VALUES
    -- Environmental Inspections
    (1, 'SWPPP', 'Stormwater (SWPPP) Inspection', 
        'Inspection of stormwater controls, BMPs, and outfalls per SWPPP requirements',
        'NPDES CGP Section 4', 'weekly', 'Also required within 24 hours of storm event >= 0.25 inches', 3),
    (2, 'SPCC', 'SPCC Inspection',
        'Inspection of oil storage containers, secondary containment, and spill equipment',
        '40 CFR 112.7(e)', 'monthly', 'Visual inspection of containers and containment areas', 3),
    (3, 'SWPPP_STORM', 'Stormwater Post-Storm Inspection',
        'Inspection within 24 hours of qualifying storm event',
        'NPDES CGP Section 4.1', 'as_needed', 'Required after rain events >= 0.25 inches', 3),
    
    -- Safety Inspections
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
        '29 CFR 1910.151', 'monthly', NULL, 3),
    
    -- Equipment Inspections
    (20, 'FORKLIFT_PRE', 'Forklift Pre-Shift Inspection',
        'Operator pre-shift inspection of powered industrial truck',
        '29 CFR 1910.178(q)(7)', 'daily', 'Before each shift the truck is used', 1),
    (21, 'CRANE', 'Crane Inspection',
        'Periodic inspection of cranes and hoists',
        '29 CFR 1910.179(j)', 'monthly', 'Frequent (daily) and periodic (monthly/annual) required', 3),
    (22, 'LADDER', 'Ladder Inspection',
        'Inspection of portable and fixed ladders',
        '29 CFR 1910.23', 'quarterly', NULL, 3),
    
    -- Waste Inspections (in addition to 004_waste.sql accumulation area inspections)
    (30, 'HAZWASTE_WEEKLY', 'Hazardous Waste Weekly Inspection',
        'Weekly inspection of hazardous waste accumulation areas',
        '40 CFR 265.174', 'weekly', 'Required for LQG central accumulation areas', 3),
    (31, 'USED_OIL', 'Used Oil Container Inspection',
        'Inspection of used oil storage containers',
        '40 CFR 279.22', 'monthly', NULL, 3);


-- ============================================================================
-- INSPECTION CHECKLIST TEMPLATES
-- ============================================================================
-- Pre-seeded checklist items that can be used for each inspection type.
-- Users can add their own site-specific items.

CREATE TABLE IF NOT EXISTS inspection_checklist_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    inspection_type_id INTEGER NOT NULL,
    
    item_order INTEGER DEFAULT 0,           -- Display order
    checklist_item TEXT NOT NULL,           -- The item to check
    category TEXT,                          -- Grouping within the checklist
    
    expected_response TEXT,                 -- 'yes_no', 'pass_fail', 'numeric', 'text'
    acceptable_values TEXT,                 -- 'yes', 'pass', '>0', etc.
    
    guidance_notes TEXT,                    -- Help text for inspector
    regulatory_reference TEXT,              -- Specific reg citation for this item
    
    is_critical INTEGER DEFAULT 0,          -- Failure requires immediate action
    is_active INTEGER DEFAULT 1,
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (inspection_type_id) REFERENCES inspection_types(id)
);

CREATE INDEX idx_checklist_templates_type ON inspection_checklist_templates(inspection_type_id);


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

-- Fire Extinguisher Inspection (monthly visual)
INSERT OR IGNORE INTO inspection_checklist_templates 
    (inspection_type_id, item_order, checklist_item, category, expected_response, guidance_notes, is_critical) VALUES
    (11, 1, 'Extinguisher in designated location', 'Location', 'yes_no', 'Not blocked, visible, proper mounting height', 0),
    (11, 2, 'Access to extinguisher unobstructed', 'Location', 'yes_no', 'Clear path, no storage blocking access', 0),
    (11, 3, 'Operating instructions visible and legible', 'Condition', 'yes_no', 'Label facing outward', 0),
    (11, 4, 'Safety seal and tamper indicator intact', 'Condition', 'yes_no', 'If broken, extinguisher may have been used', 1),
    (11, 5, 'Pressure gauge in operable range (green)', 'Condition', 'yes_no', 'Needle in green zone', 1),
    (11, 6, 'No visible physical damage or corrosion', 'Condition', 'yes_no', 'Dents, rust, damage to hose/nozzle', 0),
    (11, 7, 'Inspection tag current', 'Documentation', 'yes_no', 'Monthly inspection documented, annual service date', 0);

-- Eyewash/Safety Shower Inspection (weekly)
INSERT OR IGNORE INTO inspection_checklist_templates 
    (inspection_type_id, item_order, checklist_item, category, expected_response, guidance_notes, is_critical) VALUES
    (12, 1, 'Unit location clearly identified/signed', 'Location', 'yes_no', 'Highly visible sign, unobstructed', 0),
    (12, 2, 'Access path clear (10 seconds travel time)', 'Location', 'yes_no', 'No obstructions in path from work area', 1),
    (12, 3, 'Activated and water flows freely', 'Function', 'yes_no', 'Activate for at least 3 seconds weekly', 1),
    (12, 4, 'Water temperature acceptable (tepid 60-100°F)', 'Function', 'yes_no', 'Not too hot or cold', 0),
    (12, 5, 'Dust covers in place (if equipped)', 'Condition', 'yes_no', 'Covers protect nozzles but allow quick activation', 0),
    (12, 6, 'No leaks when not activated', 'Condition', 'yes_no', 'Check valves, piping', 0),
    (12, 7, 'Inspection tag/log updated', 'Documentation', 'yes_no', 'Document weekly activation test', 0);

-- General Safety Walkthrough
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
-- SWPPP OUTFALLS
-- ============================================================================
-- Facility-specific stormwater outfall points for inspection tracking.

CREATE TABLE IF NOT EXISTS swppp_outfalls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    
    outfall_id TEXT NOT NULL,               -- 'OF-001', 'OF-002' per SWPPP
    outfall_name TEXT,                      -- Descriptive name
    description TEXT,
    
    -- Location
    latitude REAL,
    longitude REAL,
    location_description TEXT,              -- 'Northeast corner of parking lot'
    
    -- Drainage area info
    drainage_area_acres REAL,
    drainage_area_description TEXT,         -- What drains to this outfall
    
    -- Receiving water
    receiving_water_name TEXT,              -- Stream, ditch, municipal system
    receiving_water_type TEXT,              -- 'stream', 'wetland', 'municipal_storm', 'ditch'
    
    -- Monitoring requirements
    requires_sampling INTEGER DEFAULT 0,    -- Some permits require sampling
    benchmark_parameters TEXT,              -- Parameters to sample if required
    
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, outfall_id)
);

CREATE INDEX idx_swppp_outfalls_establishment ON swppp_outfalls(establishment_id);


-- ============================================================================
-- SPCC CONTAINERS
-- ============================================================================
-- Oil storage containers covered under SPCC plan.

CREATE TABLE IF NOT EXISTS spcc_containers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    
    container_id TEXT NOT NULL,             -- Internal tracking ID
    container_name TEXT,
    description TEXT,
    
    -- Container details
    container_type TEXT,                    -- 'AST', 'drum', 'tote', 'tank_truck', 'transformer'
    capacity_gallons REAL NOT NULL,
    shell_capacity_gallons REAL,            -- For tanks - shell vs working capacity
    
    -- Contents
    oil_type TEXT,                          -- 'diesel', 'hydraulic', 'lubricating', 'transformer'
    product_name TEXT,
    
    -- Location
    location_description TEXT,
    building TEXT,
    indoor_outdoor TEXT,                    -- 'indoor', 'outdoor', 'covered_outdoor'
    
    -- Secondary containment
    containment_type TEXT,                  -- 'dike', 'vault', 'double_wall', 'drip_pan', 'none'
    containment_capacity_gallons REAL,
    
    -- Spill history
    spill_history TEXT,                     -- Brief description of any past spills
    
    -- Installation/inspection
    install_date TEXT,
    last_integrity_test TEXT,               -- For regulated ASTs
    next_integrity_test TEXT,
    
    -- Regulatory status
    is_regulated_ast INTEGER DEFAULT 0,     -- Subject to additional requirements
    
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    UNIQUE(establishment_id, container_id)
);

CREATE INDEX idx_spcc_containers_establishment ON spcc_containers(establishment_id);


-- ============================================================================
-- INSPECTIONS (Master Record)
-- ============================================================================
-- Individual inspection events.

CREATE TABLE IF NOT EXISTS inspections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    inspection_type_id INTEGER NOT NULL,
    
    -- Identification
    inspection_number TEXT,                 -- Auto-generated or user-defined
    
    -- Schedule vs actual
    scheduled_date TEXT,
    inspection_date TEXT NOT NULL,
    
    -- Inspector
    inspector_id INTEGER,                   -- Employee who performed inspection
    inspector_name TEXT,                    -- For external inspectors
    inspector_title TEXT,
    
    -- Scope
    areas_inspected TEXT,                   -- Description of areas covered
    
    -- For SWPPP storm-triggered inspections
    is_storm_triggered INTEGER DEFAULT 0,
    storm_date TEXT,
    rainfall_inches REAL,
    
    -- For SPCC - which containers inspected
    spcc_container_ids TEXT,                -- Comma-separated container IDs
    
    -- For SWPPP - which outfalls inspected
    swppp_outfall_ids TEXT,                 -- Comma-separated outfall IDs
    
    -- Overall result
    overall_result TEXT DEFAULT 'pass',     -- 'pass', 'pass_with_findings', 'fail'
    
    -- Summary
    summary_notes TEXT,
    
    -- Weather conditions (for outdoor inspections)
    weather_conditions TEXT,
    temperature_f INTEGER,
    
    -- Status
    status TEXT DEFAULT 'draft',            -- 'draft', 'completed', 'reviewed'
    completed_at TEXT,
    reviewed_by INTEGER,
    reviewed_at TEXT,
    
    -- Attachments
    photo_references TEXT,                  -- File paths or references
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (inspection_type_id) REFERENCES inspection_types(id),
    FOREIGN KEY (inspector_id) REFERENCES employees(id),
    FOREIGN KEY (reviewed_by) REFERENCES employees(id)
);

CREATE INDEX idx_inspections_establishment ON inspections(establishment_id);
CREATE INDEX idx_inspections_type ON inspections(inspection_type_id);
CREATE INDEX idx_inspections_date ON inspections(inspection_date);
CREATE INDEX idx_inspections_status ON inspections(status);


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
    response TEXT,                          -- 'yes', 'no', 'pass', 'fail', 'N/A', or value
    response_notes TEXT,
    
    -- If finding generated
    is_finding INTEGER DEFAULT 0,
    finding_id INTEGER,                     -- Link to inspection_findings if issue found
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (template_item_id) REFERENCES inspection_checklist_templates(id),
    FOREIGN KEY (finding_id) REFERENCES inspection_findings(id)
);

CREATE INDEX idx_checklist_responses_inspection ON inspection_checklist_responses(inspection_id);


-- ============================================================================
-- INSPECTION FINDINGS
-- ============================================================================
-- Issues discovered during inspections.

CREATE TABLE IF NOT EXISTS inspection_findings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    inspection_id INTEGER NOT NULL,
    
    -- Finding identification
    finding_number TEXT,                    -- Sequence within inspection
    
    -- Classification
    finding_type TEXT NOT NULL,             -- 'observation', 'deficiency', 'violation', 'opportunity'
    severity TEXT DEFAULT 'minor',          -- 'minor', 'major', 'critical'
    
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
    
    -- CAR linkage
    requires_car INTEGER DEFAULT 0,
    car_id INTEGER,                         -- Link to car_records if CAR issued
    
    -- Status
    status TEXT DEFAULT 'open',             -- 'open', 'car_issued', 'closed'
    closed_date TEXT,
    closed_by INTEGER,
    closure_notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (car_id) REFERENCES car_records(id),
    FOREIGN KEY (closed_by) REFERENCES employees(id)
);

CREATE INDEX idx_inspection_findings_inspection ON inspection_findings(inspection_id);
CREATE INDEX idx_inspection_findings_status ON inspection_findings(status);
CREATE INDEX idx_inspection_findings_car ON inspection_findings(car_id);


-- ============================================================================
-- AUDITS (Master Record)
-- ============================================================================
-- ISO management system audits and other formal audits.

CREATE TABLE IF NOT EXISTS audits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    
    -- Identification
    audit_number TEXT,                      -- 'AUD-2025-001'
    audit_title TEXT NOT NULL,              -- 'ISO 14001 Internal Audit - Q1 2025'
    
    -- Audit type
    audit_type TEXT NOT NULL,               -- 'internal', 'external_surveillance', 'external_certification', 'external_recertification'
    
    -- Standard(s) being audited
    standard_id INTEGER,                    -- Primary standard (14001, 45001, 50001)
    is_integrated_audit INTEGER DEFAULT 0,  -- Covers multiple standards
    additional_standard_ids TEXT,           -- Comma-separated if integrated
    
    -- For external audits - registrar info
    registrar_name TEXT,                    -- 'DNV', 'BSI', 'NSF-ISR', etc.
    certificate_number TEXT,
    
    -- Dates
    scheduled_start_date TEXT,
    scheduled_end_date TEXT,
    actual_start_date TEXT,
    actual_end_date TEXT,
    
    -- Lead auditor
    lead_auditor_id INTEGER,                -- Employee ID if internal
    lead_auditor_name TEXT,                 -- Name for external auditors
    lead_auditor_company TEXT,              -- For external
    
    -- Scope summary
    scope_description TEXT,
    exclusions TEXT,                        -- What's not in scope
    
    -- Previous audit reference
    previous_audit_id INTEGER,              -- Link to prior audit for comparison
    
    -- Objectives
    audit_objectives TEXT,
    audit_criteria TEXT,                    -- 'ISO 14001:2015, Site EMS Manual, Legal requirements'
    
    -- Results summary
    total_findings INTEGER DEFAULT 0,
    major_nonconformities INTEGER DEFAULT 0,
    minor_nonconformities INTEGER DEFAULT 0,
    opportunities_for_improvement INTEGER DEFAULT 0,
    positive_findings INTEGER DEFAULT 0,
    
    -- Recommendation (for certification audits)
    recommendation TEXT,                    -- 'certification_recommended', 'conditional', 'not_recommended'
    recommendation_conditions TEXT,
    
    -- Status
    status TEXT DEFAULT 'planned',          -- 'planned', 'in_progress', 'draft_report', 'final', 'closed'
    
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

CREATE INDEX idx_audits_establishment ON audits(establishment_id);
CREATE INDEX idx_audits_standard ON audits(standard_id);
CREATE INDEX idx_audits_type ON audits(audit_type);
CREATE INDEX idx_audits_status ON audits(status);
CREATE INDEX idx_audits_date ON audits(actual_start_date);


-- ============================================================================
-- AUDIT TEAM
-- ============================================================================
-- Members of the audit team.

CREATE TABLE IF NOT EXISTS audit_team (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    audit_id INTEGER NOT NULL,
    
    -- Team member
    employee_id INTEGER,                    -- If internal auditor
    auditor_name TEXT NOT NULL,
    auditor_company TEXT,                   -- For external auditors
    
    -- Role
    role TEXT NOT NULL,                     -- 'lead_auditor', 'auditor', 'technical_expert', 'observer', 'trainee'
    
    -- Qualifications relevant to this audit
    qualifications TEXT,                    -- Certifications, experience
    
    -- Assigned areas/clauses
    assigned_scope TEXT,                    -- What they're responsible for auditing
    
    -- Conflict of interest check
    independence_confirmed INTEGER DEFAULT 0,
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE INDEX idx_audit_team_audit ON audit_team(audit_id);


-- ============================================================================
-- AUDIT SCOPE DETAIL
-- ============================================================================
-- Detailed breakdown of audit scope by process/area/clause.

CREATE TABLE IF NOT EXISTS audit_scope (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    audit_id INTEGER NOT NULL,
    
    -- What's being audited
    scope_type TEXT NOT NULL,               -- 'process', 'department', 'clause', 'location'
    scope_item TEXT NOT NULL,               -- Process name, dept name, clause number, location
    
    -- For clause-based scope
    clause_id INTEGER,                      -- Link to iso_clauses
    
    -- Assignment
    assigned_auditor_id INTEGER,            -- Who will audit this scope item
    
    -- Timing
    scheduled_date TEXT,
    scheduled_time TEXT,
    estimated_duration_minutes INTEGER,
    
    -- Contacts/interviewees
    auditee_contact TEXT,
    
    -- Status
    status TEXT DEFAULT 'planned',          -- 'planned', 'in_progress', 'completed'
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE,
    FOREIGN KEY (clause_id) REFERENCES iso_clauses(id),
    FOREIGN KEY (assigned_auditor_id) REFERENCES audit_team(id)
);

CREATE INDEX idx_audit_scope_audit ON audit_scope(audit_id);
CREATE INDEX idx_audit_scope_clause ON audit_scope(clause_id);


-- ============================================================================
-- AUDIT FINDINGS
-- ============================================================================
-- Findings from ISO audits with clause-level tracking.

CREATE TABLE IF NOT EXISTS audit_findings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    audit_id INTEGER NOT NULL,
    
    -- Finding identification
    finding_number TEXT NOT NULL,           -- 'F1', 'F2' or 'MAJ-001', 'MIN-001'
    
    -- Classification
    finding_type TEXT NOT NULL,             -- 'major_nc', 'minor_nc', 'ofi', 'positive', 'observation'
    
    -- Clause reference (THE KEY TRACKING FEATURE)
    clause_id INTEGER,                      -- Link to iso_clauses
    clause_number TEXT,                     -- Stored for quick reference
    clause_title TEXT,
    
    -- Additional standard references if integrated audit
    secondary_clause_refs TEXT,             -- Other clauses also implicated
    
    -- Finding details
    requirement_statement TEXT,             -- What the standard requires
    finding_statement TEXT NOT NULL,        -- Objective evidence of the finding
    
    -- Context
    process_area TEXT,                      -- Where finding was identified
    department TEXT,
    auditee_interviewed TEXT,
    
    -- Evidence
    evidence_description TEXT,
    document_references TEXT,               -- Documents reviewed
    photo_references TEXT,
    
    -- For repeat findings
    is_repeat_finding INTEGER DEFAULT 0,
    previous_finding_id INTEGER,            -- Link to finding from prior audit
    
    -- Risk assessment (for prioritization)
    risk_level TEXT,                        -- 'high', 'medium', 'low'
    potential_impact TEXT,
    
    -- Auditee response
    auditee_agreement INTEGER DEFAULT 1,    -- Did auditee agree with finding?
    auditee_comments TEXT,
    
    -- CAR linkage
    requires_car INTEGER DEFAULT 1,         -- Most NC findings require CAR
    car_id INTEGER,
    
    -- Status
    status TEXT DEFAULT 'open',             -- 'open', 'car_issued', 'verified', 'closed'
    verified_date TEXT,
    verified_by INTEGER,
    verification_notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (audit_id) REFERENCES audits(id) ON DELETE CASCADE,
    FOREIGN KEY (clause_id) REFERENCES iso_clauses(id),
    FOREIGN KEY (previous_finding_id) REFERENCES audit_findings(id),
    FOREIGN KEY (car_id) REFERENCES car_records(id),
    FOREIGN KEY (verified_by) REFERENCES employees(id)
);

CREATE INDEX idx_audit_findings_audit ON audit_findings(audit_id);
CREATE INDEX idx_audit_findings_clause ON audit_findings(clause_id);
CREATE INDEX idx_audit_findings_type ON audit_findings(finding_type);
CREATE INDEX idx_audit_findings_status ON audit_findings(status);
CREATE INDEX idx_audit_findings_car ON audit_findings(car_id);


-- ============================================================================
-- CAR RECORDS (Corrective Action Requests)
-- ============================================================================
-- Year-based numbering: CAR-2025-001, CAR-2025-002, etc.
-- Central tracking for all corrective actions from any source.
-- Named car_records to avoid conflict with corrective_actions in 001_incidents.sql

CREATE TABLE IF NOT EXISTS car_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    
    -- CAR Number (Year-based)
    car_year INTEGER NOT NULL,              -- 2025
    car_sequence INTEGER NOT NULL,          -- 1, 2, 3... within year
    car_number TEXT NOT NULL UNIQUE,        -- 'CAR-2025-001' (auto-generated)
    
    -- Source of the CAR
    source_type TEXT NOT NULL,              -- 'audit', 'inspection', 'incident', 'complaint', 'management_review', 'other'
    
    -- Source references (only one will be populated based on source_type)
    source_audit_id INTEGER,
    source_audit_finding_id INTEGER,
    source_inspection_id INTEGER,
    source_inspection_finding_id INTEGER,
    source_incident_id INTEGER,
    source_description TEXT,                -- For 'other' sources
    
    -- Classification
    car_type TEXT DEFAULT 'corrective',     -- 'corrective', 'preventive'
    severity TEXT DEFAULT 'minor',          -- 'minor', 'major', 'critical'
    
    -- Problem statement
    nonconformity_description TEXT NOT NULL,
    date_identified TEXT NOT NULL,
    identified_by INTEGER,
    identified_by_name TEXT,
    
    -- Affected area
    department TEXT,
    process_area TEXT,
    
    -- Regulatory/standard reference
    requirement_reference TEXT,             -- Clause, regulation, procedure violated
    
    -- Immediate containment
    containment_action TEXT,
    containment_date TEXT,
    containment_responsible TEXT,
    containment_verified INTEGER DEFAULT 0,
    
    -- Dates
    due_date TEXT,                          -- When CAR must be closed
    extension_date TEXT,                    -- If extended
    extension_reason TEXT,
    
    -- Assignment
    responsible_person_id INTEGER,
    responsible_person_name TEXT,
    
    -- Status tracking
    status TEXT DEFAULT 'open',             -- 'open', 'in_progress', 'pending_verification', 'closed', 'closed_ineffective'
    
    -- Closure
    closed_date TEXT,
    closed_by INTEGER,
    
    -- Management review
    reviewed_in_management_review INTEGER DEFAULT 0,
    management_review_date TEXT,
    
    -- Notes
    notes TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (establishment_id) REFERENCES establishments(id),
    FOREIGN KEY (source_audit_id) REFERENCES audits(id),
    FOREIGN KEY (source_audit_finding_id) REFERENCES audit_findings(id),
    FOREIGN KEY (source_inspection_id) REFERENCES inspections(id),
    FOREIGN KEY (source_inspection_finding_id) REFERENCES inspection_findings(id),
    FOREIGN KEY (source_incident_id) REFERENCES incidents(id),
    FOREIGN KEY (identified_by) REFERENCES employees(id),
    FOREIGN KEY (responsible_person_id) REFERENCES employees(id),
    FOREIGN KEY (closed_by) REFERENCES employees(id),
    UNIQUE(car_year, car_sequence, establishment_id)
);

CREATE INDEX idx_car_establishment ON car_records(establishment_id);
CREATE INDEX idx_car_number ON car_records(car_number);
CREATE INDEX idx_car_year ON car_records(car_year);
CREATE INDEX idx_car_status ON car_records(status);
CREATE INDEX idx_car_source_type ON car_records(source_type);
CREATE INDEX idx_car_due_date ON car_records(due_date);
CREATE INDEX idx_car_responsible ON car_records(responsible_person_id);


-- ============================================================================
-- CAR ROOT CAUSE ANALYSIS
-- ============================================================================
-- Structured root cause analysis for each CAR.

CREATE TABLE IF NOT EXISTS car_root_cause (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    car_id INTEGER NOT NULL,
    
    -- Analysis method used
    analysis_method TEXT,                   -- '5_why', 'fishbone', 'fault_tree', 'pareto', 'other'
    
    -- 5-Why structure (common method)
    why_1 TEXT,
    why_2 TEXT,
    why_3 TEXT,
    why_4 TEXT,
    why_5 TEXT,
    
    -- Root cause statement
    root_cause_statement TEXT NOT NULL,
    
    -- Root cause category (for trending)
    root_cause_category TEXT,               -- 'training', 'procedure', 'equipment', 'communication', 
                                            -- 'resource', 'management', 'design', 'human_error', 'other'
    
    -- Contributing factors
    contributing_factors TEXT,
    
    -- Analysis performed by
    analyzed_by INTEGER,
    analyzed_by_name TEXT,
    analysis_date TEXT,
    
    -- Team involved in analysis
    analysis_team TEXT,
    
    -- Supporting documentation
    supporting_docs TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (car_id) REFERENCES car_records(id) ON DELETE CASCADE,
    FOREIGN KEY (analyzed_by) REFERENCES employees(id)
);

CREATE INDEX idx_car_root_cause_car ON car_root_cause(car_id);
CREATE INDEX idx_car_root_cause_category ON car_root_cause(root_cause_category);


-- ============================================================================
-- CAR ACTIONS
-- ============================================================================
-- Individual action items to address the CAR.
-- A single CAR may have multiple actions.

CREATE TABLE IF NOT EXISTS car_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    car_id INTEGER NOT NULL,
    
    -- Action identification
    action_number INTEGER NOT NULL,         -- 1, 2, 3 within the CAR
    
    -- Action details
    action_type TEXT NOT NULL,              -- 'corrective', 'preventive', 'containment'
    action_description TEXT NOT NULL,
    
    -- Target
    target_outcome TEXT,                    -- What success looks like
    
    -- Assignment
    responsible_person_id INTEGER,
    responsible_person_name TEXT,
    
    -- Dates
    due_date TEXT,
    completed_date TEXT,
    
    -- Status
    status TEXT DEFAULT 'open',             -- 'open', 'in_progress', 'completed', 'cancelled'
    
    -- Completion details
    completion_notes TEXT,
    completion_evidence TEXT,               -- What evidence exists of completion
    
    -- Verified
    verified INTEGER DEFAULT 0,
    verified_by INTEGER,
    verified_date TEXT,
    
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (car_id) REFERENCES car_records(id) ON DELETE CASCADE,
    FOREIGN KEY (responsible_person_id) REFERENCES employees(id),
    FOREIGN KEY (verified_by) REFERENCES employees(id)
);

CREATE INDEX idx_car_actions_car ON car_actions(car_id);
CREATE INDEX idx_car_actions_status ON car_actions(status);
CREATE INDEX idx_car_actions_due_date ON car_actions(due_date);
CREATE INDEX idx_car_actions_responsible ON car_actions(responsible_person_id);


-- ============================================================================
-- CAR EFFECTIVENESS VERIFICATION
-- ============================================================================
-- Verification that the corrective actions actually worked.

CREATE TABLE IF NOT EXISTS car_verification (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    car_id INTEGER NOT NULL,
    
    -- Verification planning
    verification_method TEXT,               -- How effectiveness will be verified
    verification_criteria TEXT,             -- What indicates success
    verification_due_date TEXT,             -- When to verify (often 30-90 days after closure)
    
    -- Verification execution
    verification_date TEXT,
    verified_by INTEGER,
    verified_by_name TEXT,
    
    -- Results
    is_effective INTEGER,                   -- 1=effective, 0=not effective
    verification_notes TEXT,
    evidence_reviewed TEXT,
    
    -- If not effective
    followup_required INTEGER DEFAULT 0,
    followup_car_id INTEGER,                -- New CAR if needed
    
    created_at TEXT DEFAULT (datetime('now')),
    
    FOREIGN KEY (car_id) REFERENCES car_records(id) ON DELETE CASCADE,
    FOREIGN KEY (verified_by) REFERENCES employees(id),
    FOREIGN KEY (followup_car_id) REFERENCES car_records(id)
);

CREATE INDEX idx_car_verification_car ON car_verification(car_id);
CREATE INDEX idx_car_verification_due ON car_verification(verification_due_date);


-- ============================================================================
-- INSPECTION SCHEDULE
-- ============================================================================
-- Recurring inspection schedule for planning.

CREATE TABLE IF NOT EXISTS inspection_schedule (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    establishment_id INTEGER NOT NULL,
    inspection_type_id INTEGER NOT NULL,
    
    -- Schedule name
    schedule_name TEXT,
    
    -- Frequency
    frequency TEXT NOT NULL,                -- 'daily', 'weekly', 'monthly', 'quarterly', 'annual'
    frequency_details TEXT,                 -- 'Every Monday', 'First week of month'
    
    -- Day/time preferences
    preferred_day_of_week INTEGER,          -- 0=Sunday, 1=Monday, etc.
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

CREATE INDEX idx_inspection_schedule_establishment ON inspection_schedule(establishment_id);
CREATE INDEX idx_inspection_schedule_type ON inspection_schedule(inspection_type_id);
CREATE INDEX idx_inspection_schedule_next_due ON inspection_schedule(next_due_date);


-- ============================================================================
-- VIEWS: Inspections & Audits
-- ============================================================================

-- ----------------------------------------------------------------------------
-- V_INSPECTIONS_DUE
-- ----------------------------------------------------------------------------
-- Upcoming and overdue inspections based on schedule.

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
-- V_OPEN_CARS
-- ----------------------------------------------------------------------------
-- All open CARs with aging information.

CREATE VIEW IF NOT EXISTS v_open_cars AS
SELECT 
    ca.id AS car_id,
    ca.car_number,
    ca.establishment_id,
    e.name AS establishment_name,
    ca.source_type,
    ca.severity,
    ca.nonconformity_description,
    ca.date_identified,
    ca.due_date,
    COALESCE(ca.extension_date, ca.due_date) AS effective_due_date,
    ca.status,
    emp.first_name || ' ' || emp.last_name AS responsible_person,
    ca.department,
    
    -- Aging
    CAST(julianday('now') - julianday(ca.date_identified) AS INTEGER) AS days_open,
    CAST(julianday(COALESCE(ca.extension_date, ca.due_date)) - julianday('now') AS INTEGER) AS days_until_due,
    
    -- Status indicator
    CASE 
        WHEN date(COALESCE(ca.extension_date, ca.due_date)) < date('now') THEN 'OVERDUE'
        WHEN date(COALESCE(ca.extension_date, ca.due_date)) <= date('now', '+7 days') THEN 'DUE_SOON'
        ELSE 'ON_TRACK'
    END AS urgency,
    
    -- Progress
    (SELECT COUNT(*) FROM car_actions WHERE car_id = ca.id) AS total_actions,
    (SELECT COUNT(*) FROM car_actions WHERE car_id = ca.id AND status = 'completed') AS completed_actions

FROM car_records ca
INNER JOIN establishments e ON ca.establishment_id = e.id
LEFT JOIN employees emp ON ca.responsible_person_id = emp.id
WHERE ca.status NOT IN ('closed', 'closed_ineffective')
ORDER BY
    CASE ca.severity WHEN 'critical' THEN 1 WHEN 'major' THEN 2 ELSE 3 END,
    ca.due_date ASC;


-- ----------------------------------------------------------------------------
-- V_CAR_SUMMARY_BY_YEAR
-- ----------------------------------------------------------------------------
-- CAR statistics by year for trending.

CREATE VIEW IF NOT EXISTS v_car_summary_by_year AS
SELECT 
    ca.establishment_id,
    ca.car_year,
    COUNT(*) AS total_cars,
    SUM(CASE WHEN ca.status IN ('closed', 'closed_ineffective') THEN 1 ELSE 0 END) AS closed_cars,
    SUM(CASE WHEN ca.status NOT IN ('closed', 'closed_ineffective') THEN 1 ELSE 0 END) AS open_cars,
    SUM(CASE WHEN ca.severity = 'critical' THEN 1 ELSE 0 END) AS critical_count,
    SUM(CASE WHEN ca.severity = 'major' THEN 1 ELSE 0 END) AS major_count,
    SUM(CASE WHEN ca.severity = 'minor' THEN 1 ELSE 0 END) AS minor_count,
    SUM(CASE WHEN ca.source_type = 'audit' THEN 1 ELSE 0 END) AS from_audits,
    SUM(CASE WHEN ca.source_type = 'inspection' THEN 1 ELSE 0 END) AS from_inspections,
    SUM(CASE WHEN ca.source_type = 'incident' THEN 1 ELSE 0 END) AS from_incidents,
    ROUND(AVG(CASE WHEN ca.closed_date IS NOT NULL 
        THEN julianday(ca.closed_date) - julianday(ca.date_identified) END), 1) AS avg_days_to_close
FROM car_records ca
GROUP BY ca.establishment_id, ca.car_year
ORDER BY ca.car_year DESC;


-- ----------------------------------------------------------------------------
-- V_CAR_ROOT_CAUSE_TRENDING
-- ----------------------------------------------------------------------------
-- Root cause category trending to identify systemic issues.

CREATE VIEW IF NOT EXISTS v_car_root_cause_trending AS
SELECT 
    ca.establishment_id,
    crc.root_cause_category,
    COUNT(*) AS occurrence_count,
    ca.car_year,
    GROUP_CONCAT(ca.car_number) AS car_numbers
FROM car_records ca
INNER JOIN car_root_cause crc ON ca.id = crc.car_id
WHERE crc.root_cause_category IS NOT NULL
GROUP BY ca.establishment_id, crc.root_cause_category, ca.car_year
ORDER BY ca.car_year DESC, occurrence_count DESC;


-- ----------------------------------------------------------------------------
-- V_AUDIT_FINDINGS_BY_CLAUSE
-- ----------------------------------------------------------------------------
-- Trending of audit findings by ISO clause - identifies weak areas.

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
-- V_CAR_ACTIONS_OVERDUE
-- ----------------------------------------------------------------------------
-- Action items that are past due.

CREATE VIEW IF NOT EXISTS v_car_actions_overdue AS
SELECT 
    ca.id AS car_id,
    ca.car_number,
    caa.action_number,
    caa.action_description,
    caa.due_date,
    CAST(julianday('now') - julianday(caa.due_date) AS INTEGER) AS days_overdue,
    caa.responsible_person_name,
    ca.severity AS car_severity,
    ca.establishment_id
FROM car_actions caa
INNER JOIN car_records ca ON caa.car_id = ca.id
WHERE caa.status NOT IN ('completed', 'cancelled')
  AND date(caa.due_date) < date('now')
ORDER BY caa.due_date ASC;


-- ----------------------------------------------------------------------------
-- V_VERIFICATION_DUE
-- ----------------------------------------------------------------------------
-- CAR effectiveness verifications that are due.

CREATE VIEW IF NOT EXISTS v_verification_due AS
SELECT 
    cv.id AS verification_id,
    ca.id AS car_id,
    ca.car_number,
    ca.nonconformity_description,
    cv.verification_due_date,
    CAST(julianday(cv.verification_due_date) - julianday('now') AS INTEGER) AS days_until_due,
    cv.verification_method,
    cv.verification_criteria,
    CASE 
        WHEN date(cv.verification_due_date) < date('now') THEN 'OVERDUE'
        WHEN date(cv.verification_due_date) <= date('now', '+14 days') THEN 'DUE_SOON'
        ELSE 'UPCOMING'
    END AS urgency,
    ca.establishment_id
FROM car_verification cv
INNER JOIN car_records ca ON cv.car_id = ca.id
WHERE cv.verification_date IS NULL
ORDER BY cv.verification_due_date ASC;


-- ----------------------------------------------------------------------------
-- V_INSPECTION_COMPLIANCE_SUMMARY
-- ----------------------------------------------------------------------------
-- Overall inspection compliance status by establishment.

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
-- V_AUDIT_STATUS_SUMMARY
-- ----------------------------------------------------------------------------
-- Audit and CAR status summary by establishment.

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
    
    -- CARs this year
    (SELECT COUNT(*) FROM car_records
     WHERE establishment_id = e.id AND car_year = CAST(strftime('%Y', 'now') AS INTEGER)) AS cars_this_year,

    -- Open CARs
    (SELECT COUNT(*) FROM car_records
     WHERE establishment_id = e.id AND status NOT IN ('closed', 'closed_ineffective')) AS open_cars,

    -- Overdue CARs
    (SELECT COUNT(*) FROM car_records
     WHERE establishment_id = e.id
       AND status NOT IN ('closed', 'closed_ineffective')
       AND date(COALESCE(extension_date, due_date)) < date('now')) AS overdue_cars

FROM establishments e;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-generate CAR number (Year-based)
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_car_number_generate
AFTER INSERT ON car_records
WHEN NEW.car_number IS NULL OR NEW.car_number = ''
BEGIN
    UPDATE car_records
    SET car_number = 'CAR-' || NEW.car_year || '-' ||
        SUBSTR('000' || NEW.car_sequence, -3, 3)
    WHERE id = NEW.id;
END;

-- ----------------------------------------------------------------------------
-- Get next CAR sequence for the year
-- ----------------------------------------------------------------------------
-- Note: In application code, you'll want to:
-- 1. SELECT COALESCE(MAX(car_sequence), 0) + 1 FROM car_records WHERE car_year = ? AND establishment_id = ?
-- 2. INSERT with that sequence number
-- This trigger just formats the number if it wasn't provided.

-- ----------------------------------------------------------------------------
-- Update inspection schedule when inspection completed
-- ----------------------------------------------------------------------------
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
-- Link CAR to source finding when created
-- ----------------------------------------------------------------------------
CREATE TRIGGER IF NOT EXISTS trg_car_link_audit_finding
AFTER INSERT ON car_records
WHEN NEW.source_audit_finding_id IS NOT NULL
BEGIN
    UPDATE audit_findings
    SET car_id = NEW.id,
        status = 'car_issued',
        updated_at = datetime('now')
    WHERE id = NEW.source_audit_finding_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_car_link_inspection_finding
AFTER INSERT ON car_records
WHEN NEW.source_inspection_finding_id IS NOT NULL
BEGIN
    UPDATE inspection_findings
    SET car_id = NEW.id,
        status = 'car_issued',
        updated_at = datetime('now')
    WHERE id = NEW.source_inspection_finding_id;
END;

-- ----------------------------------------------------------------------------
-- Auto-close CAR when all actions completed and verified
-- ----------------------------------------------------------------------------
-- Note: This is a helper - actual closure should be explicit in application
-- But we can auto-set to 'pending_verification' when actions complete
CREATE TRIGGER IF NOT EXISTS trg_car_action_complete_check
AFTER UPDATE ON car_actions
WHEN NEW.status = 'completed'
BEGIN
    UPDATE car_records
    SET status = 'pending_verification',
        updated_at = datetime('now')
    WHERE id = NEW.car_id
      AND status = 'in_progress'
      AND NOT EXISTS (
          SELECT 1 FROM car_actions
          WHERE car_id = NEW.car_id
            AND status NOT IN ('completed', 'cancelled')
      );
END;


-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================
/*
-- 1. Get next CAR number for a new CAR
SELECT 'CAR-' || strftime('%Y', 'now') || '-' || 
       SUBSTR('000' || (COALESCE(MAX(car_sequence), 0) + 1), -3, 3) AS next_car_number,
       COALESCE(MAX(car_sequence), 0) + 1 AS next_sequence
FROM car_records
WHERE car_year = CAST(strftime('%Y', 'now') AS INTEGER)
  AND establishment_id = 1;

-- 2. Create a new CAR from an audit finding
INSERT INTO car_records
    (establishment_id, car_year, car_sequence, source_type, source_audit_id,
     source_audit_finding_id, severity, nonconformity_description, date_identified,
     requirement_reference, due_date, responsible_person_id)
SELECT
    a.establishment_id,
    CAST(strftime('%Y', 'now') AS INTEGER),
    COALESCE((SELECT MAX(car_sequence) + 1 FROM car_records
              WHERE car_year = CAST(strftime('%Y', 'now') AS INTEGER)
              AND establishment_id = a.establishment_id), 1),
    'audit',
    af.audit_id,
    af.id,
    CASE af.finding_type WHEN 'major_nc' THEN 'major' ELSE 'minor' END,
    af.finding_statement,
    date('now'),
    af.clause_number || ' - ' || af.clause_title,
    date('now', '+30 days'),
    1  -- responsible person id
FROM audit_findings af
INNER JOIN audits a ON af.audit_id = a.id
WHERE af.id = ?;  -- finding_id

-- 3. View all open CARs with aging
SELECT * FROM v_open_cars WHERE establishment_id = 1;

-- 4. Get clause-level trending for ISO 14001
SELECT * FROM v_audit_findings_by_clause 
WHERE establishment_id = 1 AND standard_code = '14001'
ORDER BY finding_count DESC;

-- 5. Record a SWPPP inspection
INSERT INTO inspections 
    (establishment_id, inspection_type_id, inspection_date, inspector_id,
     areas_inspected, overall_result, status)
VALUES 
    (1, 1, date('now'), 5, 'All outdoor areas, outfalls OF-001 through OF-003', 'pass', 'completed');

-- 6. Copy checklist template items for new inspection
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

-- 7. Find inspections that are overdue
SELECT * FROM v_inspections_due WHERE urgency = 'OVERDUE';

-- 8. Root cause category analysis
SELECT * FROM v_car_root_cause_trending 
WHERE establishment_id = 1
ORDER BY car_year DESC, occurrence_count DESC;

-- 9. Check verification effectiveness rate
SELECT 
    car_year,
    COUNT(*) AS total_verifications,
    SUM(CASE WHEN is_effective = 1 THEN 1 ELSE 0 END) AS effective,
    SUM(CASE WHEN is_effective = 0 THEN 1 ELSE 0 END) AS ineffective,
    ROUND(100.0 * SUM(CASE WHEN is_effective = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS effectiveness_rate
FROM car_verification cv
INNER JOIN car_records ca ON cv.car_id = ca.id
WHERE cv.is_effective IS NOT NULL
GROUP BY car_year;

-- 10. Plan an internal audit by clause
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

-- 11. Get audit findings that are repeat issues
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
*/


-- ============================================================================
-- SCHEMA SUMMARY
-- ============================================================================
/*
INSPECTIONS, AUDITS & CORRECTIVE ACTIONS MODULE (005_inspections_audits.sql)

REFERENCE TABLES:
  ISO Standards & Clauses:
    - iso_standards: The three standards (14001, 45001, 50001)
    - iso_clauses: Clause structure for each standard (150+ clauses pre-seeded)
    
  Inspection Framework:
    - inspection_types: Types of inspections (SWPPP, SPCC, safety, etc.)
    - inspection_checklist_templates: Pre-seeded checklist items by type

  Facility-Specific:
    - swppp_outfalls: Stormwater outfall definitions
    - spcc_containers: Oil storage containers under SPCC

INSPECTION TABLES:
    - inspections: Master inspection record
    - inspection_checklist_responses: Completed checklist items
    - inspection_findings: Issues discovered during inspections
    - inspection_schedule: Recurring inspection schedules

AUDIT TABLES:
    - audits: Master audit record (internal/external, ISO standard)
    - audit_team: Audit team members and assignments
    - audit_scope: Detailed scope by process/clause/area
    - audit_findings: Findings with clause-level tracking

CORRECTIVE ACTION TABLES:
    - car_records: Main CAR record (year-based numbering)
    - car_root_cause: Root cause analysis (5-why, categories)
    - car_actions: Individual action items within a CAR
    - car_verification: Effectiveness verification tracking

VIEWS:
  Compliance Monitoring:
    - v_inspections_due: Upcoming/overdue inspections
    - v_inspection_compliance_summary: Overall inspection status
    
  CAR Management:
    - v_open_cars: All open CARs with aging
    - v_car_summary_by_year: Annual CAR statistics
    - v_car_actions_overdue: Past-due action items
    - v_verification_due: Effectiveness verifications due
    
  Trending & Analysis:
    - v_car_root_cause_trending: Root cause categories over time
    - v_audit_findings_by_clause: Findings by ISO clause (weak area identification)
    - v_audit_status_summary: Audit and CAR status overview

TRIGGERS:
    - trg_car_number_generate: Auto-format CAR number (CAR-YYYY-NNN)
    - trg_inspection_update_schedule: Update schedule after inspection
    - trg_audit_finding_count_*: Keep audit finding counts current
    - trg_car_link_*_finding: Link CAR to source finding
    - trg_car_action_complete_check: Move to pending_verification when actions done

PRE-SEEDED DATA:
  ISO Clauses:
    - ISO 14001:2015 clauses (50 clauses including subclauses)
    - ISO 45001:2018 clauses (60 clauses including subclauses)
    - ISO 50001:2018 clauses (45 clauses including subclauses)
    
  Inspection Types (14 types):
    - Environmental: SWPPP, SPCC, SWPPP_STORM
    - Safety: SAFETY_WALK, FIRE_EXT, EYEWASH, EMERG_LIGHT, EXIT_SIGN, FIRST_AID
    - Equipment: FORKLIFT_PRE, CRANE, LADDER
    - Waste: HAZWASTE_WEEKLY, USED_OIL
    
  Checklist Templates (50+ items):
    - SWPPP inspection checklist
    - SPCC inspection checklist
    - Fire extinguisher checklist
    - Eyewash/safety shower checklist
    - General safety walkthrough checklist

KEY FEATURES:
  1. Clause-level tracking for ISO audit findings
  2. Year-based CAR numbering (CAR-2025-001)
  3. Pre-seeded checklists with customization capability
  4. Root cause category trending
  5. Effectiveness verification tracking
  6. Links to incidents, chemicals, training, waste modules via CAR sources
  7. Repeat finding identification
  8. Integrated audit support (multiple standards)

REGULATORY DRIVERS:
  - EPA SWPPP (NPDES CGP)
  - EPA SPCC (40 CFR 112)
  - ISO 14001:2015 (Environmental)
  - ISO 45001:2018 (Health & Safety)
  - ISO 50001:2018 (Energy)
  - OSHA various (fire extinguishers, eyewash, etc.)
*/


-- ============================================================================
-- ISO 45001:2018 MISSING SUBCLAUSES (Documented Information)
-- ============================================================================

INSERT OR IGNORE INTO iso_clauses (standard_id, clause_number, clause_title, parent_clause, clause_level, typical_evidence) VALUES
    (2, '7.5.1', 'General', '7.5', 3, 'Documented information required by the standard'),
    (2, '7.5.2', 'Creating and updating', '7.5', 3, 'Document templates, approval process, version control'),
    (2, '7.5.3', 'Control of documented information', '7.5', 3, 'Master document list, access controls, distribution, retention');

