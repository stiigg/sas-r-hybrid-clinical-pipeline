# Program-Level ADaM Standardization Library

This library contains reusable algorithms and derivations standardized across
all Compound-X NSCLC studies. Ensures consistency for future pooled analyses
(ISS/ISE) and demonstrates technical leadership in creating scalable solutions.

## Modules

- **oncology_response/**: RECIST 1.1 response derivations (ORR, DCR, BOR)
- **time_to_event/**: Survival analysis derivations (OS, PFS, TTR)
- **safety_standards/**: Standardized AE grading and coding
- **common_derivations/**: Shared demographic and baseline calculations

## Usage

```
source("etl/adam_program_library/oncology_response/recist_11_macros.R")

# Derive best overall response
adrs <- derive_bor(
  dataset = rs,
  reference_date = adsl$RANDDT,
  criteria = "RECIST 1.1"
)
```

## Governance

- **Owner**: Portfolio Lead Statistical Programmer
- **Review**: All changes require peer review before merge
- **Versioning**: Semantic versioning (v1.2.3)
- **Testing**: Unit tests required for all functions
