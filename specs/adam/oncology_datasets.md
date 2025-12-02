# Oncology ADaM Structures

This repository supports five core oncology ADaM datasets. These specifications summarize the expected content for reference during implementation and QC.

## ADTR (Tumor Assessments)
- **Key identifiers**: `SUBJID`, `TULNKID`, `VISITNUM`, `ADT`
- **Measurements**: `AVAL` (longest diameter in mm), `CHG`, `PCHG`
- **Flags**: `DTYPE` (TARGET/NON-TARGET/NEW)

## ADRS (Timepoint Response)
- Derived per RECIST 1.1 from ADTR rollups.
- **Endpoints**: `AVALC` (CR/PR/SD/PD), `CNFRM` (confirmation flag), `ADT`.

## ADEFFSUM (Best Overall Response)
- **BOR** computed with hierarchical logic and confirmation.
- Aligns with RECIST 1.1 guidance for SD definition (≥6 weeks of stable disease).

## ADTTE (Time-to-Event)
- Parameters: `PFS`, `OS`, with `AVAL` storing days from `STARTDT` to event/censor.
- **Censoring**: `CNSR` (0=event, 1=censored) following CDISC TTE conventions.

## ADBM (Biomarkers)
- Biomarker results such as `PDL1TPS`, `TMB`, and `MSI` with categorical buckets in `AVALC`.
- Supports stratification variables for survival analysis and dashboards.
