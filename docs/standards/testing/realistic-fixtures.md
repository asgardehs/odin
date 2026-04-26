# Realistic Test Data

Fixture data uses plausible names, codes, and shapes — never
"Test1" / "TestData2" / "foo" / "bar".

```go
// good
"Acme Test Plant", "100 Test Way", "Detroit", "MI", "48201"
"12-3456789"          // EIN, plausible format
"FATALITY"            // real severity_code
"INJURY"              // real case_classification_code
"2025-03-10"          // realistic incident date
"Crushed by forklift during drum loading."  // plausible incident description

// bad
"Test1", "test name 1", "TestStreet", "TS", "00000"
"X-12345"             // invalid EIN format
"SEV1"                // not a real severity_code
"foo description"
```

## Rules

- **Names match the domain.** Establishments are facility names
  ("Acme Plant", "Asgard Metal Works"). Employees are realistic
  human names. Incidents are short plausible descriptions. The
  test reads like a real EHS scenario.
- **Codes match the seed data.** Severity = `FATALITY`, `LOST_TIME`,
  etc. Case classifications = `INJURY`, `SKIN`, `RESP`, `POISON`,
  `HEARING`, `OTHER_ILL`. ITA codes = `DEATH`, `DAYS_AWAY`, etc.
  Use what the SQL actually defines; making up codes hides bugs
  where the FK target doesn't exist.
- **Dates use realistic recent years.** `2025-03-10`, `2026-04-22`.
  Avoid `1900-01-01` placeholders; date logic (180-day caps,
  year-of-filing computation) misbehaves on junk dates and the
  tests should catch that.
- **Format-validated fields use valid formats.** EIN is `XX-XXXXXXX`
  or `XXXXXXXXX`. ZIP is 5 or 9 digits. Phone is 10 digits. State
  is 2-letter USPS code. Lazy values pass some tests by accident
  but break format-validation tests for the wrong reason.

## Why this matters

- **Failures read as scenarios.** When a test fails with
  `severity_code = FATALITY, case_classification = INJURY,
  expected outcome = Death but got DaysAway`, the failure tells
  you what went wrong in EHS terms. With `severity_code = SEV1
  expected = X1 but got X2`, you have to mentally translate to
  understand.
- **Future test maintenance.** A new contributor reading
  realistic fixtures learns the domain at the same time as the
  codebase. Generic placeholders teach nothing.
- **Catches FK / enum bugs early.** Using a real OSHA severity
  code means the FK to `incident_severity_levels` is actually
  exercised. A made-up `'SEV1'` would either fail loudly (good)
  or silently (bad if FKs were off).

## Reference

- Strong examples: `internal/osha_ita/exporter_test.go`,
  `internal/server/api_osha_ita_test.go`,
  `internal/importer/osha_ita_detail_test.go`.
