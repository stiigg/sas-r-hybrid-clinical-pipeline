# SDTM Domain Generation with sdtm.oak

## Overview

This directory contains **automated SDTM domain generation programs** using the [`sdtm.oak`](https://pharmaverse.github.io/sdtm.oak/) package from the pharmaverse ecosystem.

**Current Status:** 16/16 core domains implemented (100% coverage for oncology trial use case)

## What is sdtm.oak?

`sdtm.oak` is a pharmaverse package that enables **algorithm-based SDTM dataset creation**:

- **System-agnostic**: Works with any EDC platform (Medidata Rave, Oracle InForm, etc.)
- **Reusable algorithms**: Modular code that can be applied across studies
- **CDISC-compliant**: Follows SDTM Implementation Guide v3.4
- **Production-proven**: Used in real FDA/EMA submissions

**Key Reference:** [sdtm.oak CRAN Package](https://cran.r-project.org/package=sdtm.oak)

## Directory Structure

Domains are organized by **CDISC domain class** following SDTM Implementation Guide structure:

```
sdtm/programs/R/oak/
├── foundation/          # Foundation domains (subject-level)
│   └── generate_dm_with_oak.R
│
├── events/              # Events domains (time-stamped occurrences)
│   ├── generate_ae_with_oak.R   # Adverse Events
│   ├── generate_cm_with_oak.R   # Concomitant Medications
│   ├── generate_mh_with_oak.R   # Medical History
│   ├── generate_ds_with_oak.R   # Disposition
│   └── generate_ex_with_oak.R   # Exposure
│
├── findings/            # Findings domains (measurements)
│   ├── generate_lb_with_oak.R   # Laboratory Results
│   ├── generate_vs_with_oak.R   # Vital Signs
│   ├── generate_eg_with_oak.R   # ECG
│   └── generate_pe_with_oak.R   # Physical Examination
│
├── findings_about/      # Findings About domains (questionnaires)
│   └── generate_qs_with_oak.R   # Questionnaires
│
├── interventions/       # Interventions domains
│   └── generate_sv_with_oak.R   # Subject Visits
│
├── oncology/            # Oncology-specific domains
│   ├── generate_tu_with_oak.R   # Tumor Identification
│   ├── generate_tr_with_oak.R   # Tumor Results
│   └── generate_rs_with_oak.R   # Response Assessment (RECIST 1.1)
│
├── run_all_sdtm_oak.R   # Master orchestration script
└── README.md            # This file
```

## Domain Class Rationale

Organization follows **SDTM IG Section 2.3 - Domain Models**:

| **Class** | **Purpose** | **Examples** | **Relationship** |
|-----------|-------------|--------------|------------------|
| **Foundation** | Subject-level data | DM | One record per subject |
| **Events** | Time-stamped occurrences | AE, CM, MH, DS, EX | Multiple records per subject |
| **Findings** | Measurements/observations | LB, VS, EG, PE | Multiple records per subject/timepoint |
| **Findings About** | Questionnaire responses | QS | Multiple records per subject/questionnaire |
| **Interventions** | Protocol-specified activities | SV | Multiple records per subject/visit |
| **Oncology** | Tumor assessments | TU, TR, RS | RECIST-specific for solid tumors |

This organization:
- ✅ Mirrors CDISC standards documentation
- ✅ Groups domains by similar structure
- ✅ Enables parallel programming (classes are independent)
- ✅ Improves code maintainability

## Quick Start

### Run Complete Pipeline

```r
# From repository root
source("config/paths.R")  # Load path configuration
source("sdtm/programs/R/oak/run_all_sdtm_oak.R")  # Generate all domains
```

### Run Individual Domain

```r
# Example: Generate Adverse Events (AE) domain
source("config/paths.R")
source("sdtm/programs/R/oak/events/generate_ae_with_oak.R")
```

### Run Domain Class

```r
# Example: Generate all Events domains
source("config/paths.R")
for (script in list.files("sdtm/programs/R/oak/events", full.names = TRUE)) {
  source(script)
}
```

## Output Locations

All domain scripts generate outputs in standardized locations (defined in `config/paths.R`):

```
sdtm/
├── data/
│   ├── xpt/          # SAS v5 transport files (FDA submission format)
│   │   ├── dm.xpt
│   │   ├── ae.xpt
│   │   └── ...
│   └── csv/          # Human-readable CSV files
│       ├── dm.csv
│       ├── ae.csv
│       └── ...
└── logs/             # Execution logs
    ├── dm_log.txt
    └── ...
```

## Domain Implementation Details

### Foundation Domains

**DM (Demographics)**
- **CDISC Class:** Special Purpose
- **Key Variables:** USUBJID, AGE, SEX, RACE, ETHNIC, COUNTRY, ARM, ACTARM
- **Complexity:** Moderate (requires multiple data sources)
- **Status:** ✅ Complete

### Events Domains

| **Domain** | **Description** | **Key Logic** | **Status** |
|------------|-----------------|---------------|------------|
| **AE** | Adverse Events | MedDRA coding, causality assessment, severity grading | ✅ Complete |
| **CM** | Concomitant Medications | WHODrug coding, start/stop dates | ✅ Complete |
| **MH** | Medical History | Pre-study conditions, MedDRA coding | ✅ Complete |
| **DS** | Disposition | Study discontinuation reasons, protocol deviations | ✅ Complete |
| **EX** | Exposure | Treatment administration, dose calculations | ✅ Complete |

### Findings Domains

| **Domain** | **Description** | **Key Logic** | **Status** |
|------------|-----------------|---------------|------------|
| **LB** | Laboratory Results | Normal range comparisons, grade toxicity (CTCAE) | ✅ Complete |
| **VS** | Vital Signs | Temperature, BP, HR, weight baseline calculations | ✅ Complete |
| **EG** | Electrocardiogram | QTc calculations, ECG interpretations | ✅ Complete |
| **PE** | Physical Examination | Body system findings, abnormality flags | ✅ Complete |

### Findings About Domains

**QS (Questionnaires)**
- Supports multiple instruments (ECOG, PRO-CTCAE, quality of life)
- Score calculations and category derivations
- **Status:** ✅ Complete

### Interventions Domains

**SV (Subject Visits)**
- Visit dates, visit windows, visit compliance
- Protocol-defined vs unscheduled visits
- **Status:** ✅ Complete

### Oncology Domains (RECIST 1.1)

| **Domain** | **Description** | **RECIST Logic** | **Status** |
|------------|-----------------|------------------|------------|
| **TU** | Tumor Identification | Target vs non-target lesion classification | ✅ Complete |
| **TR** | Tumor Results | Lesion measurements, sum of diameters | ✅ Complete |
| **RS** | Response Assessment | CR/PR/SD/PD determination per RECIST 1.1 | ✅ Complete |

**Reference:** [RECIST 1.1 Guidelines (2009)](https://www.eortc.org/recist/)

## Standard Script Structure

All domain scripts follow consistent pattern:

```r
# 1. Setup
library(sdtm.oak)
library(dplyr)
source(here::here("config", "paths.R"))

# 2. Load raw data
raw_data <- readr::read_csv(file.path(PATH_RAW_DATA, "domain_input.csv"))

# 3. Apply sdtm.oak algorithms
sdtm_domain <- raw_data %>%
  oak::assign_datetime() %>%
  oak::assign_no_date_imputation() %>%
  oak::derive_study_day() %>%
  oak::assign_ct()

# 4. Write outputs
xportr::xportr_write(sdtm_domain, file.path(PATH_SDTM_DATA_XPT, "domain.xpt"))
readr::write_csv(sdtm_domain, file.path(PATH_SDTM_DATA_CSV, "domain.csv"))

# 5. Log completion
log_info("Domain generation complete: {nrow(sdtm_domain)} records")
```

## Validation Strategy

Each domain undergoes three-tier validation:

### Tier 1: Automated Checks (within script)
- Required variables present
- Data types correct
- Key variables populated
- Sort order verified

### Tier 2: CDISC Conformance (Pinnacle21)
- Controlled terminology validation
- Variable attributes compliance
- Define.xml metadata checks

### Tier 3: Cross-Domain Relationships
- USUBJID consistency across domains
- Study day calculations
- Date/time logical consistency

**Validation reports location:** `sdtm/validation/reports/`

## Dependencies

### Required R Packages

```r
# Pharmaverse ecosystem
install.packages(c(
  "sdtm.oak",      # SDTM automation
  "xportr",        # XPT file creation
  "metacore",      # Metadata management
  "metatools"      # Metadata operations
))

# Supporting packages
install.packages(c(
  "dplyr",         # Data manipulation
  "readr",         # Data import/export  
  "lubridate",     # Date/time handling
  "stringr",       # String operations
  "logger",        # Logging
  "here"           # Path management
))
```

### Package Versions (Locked via renv)

See `renv.lock` for exact versions used in this repository.

**Pharmaverse compatibility:** Tested with sdtm.oak v0.1.0 (CRAN 2024-10-15)

## Troubleshooting

### Common Issues

**Issue 1: "object 'PATH_SDTM_DATA_XPT' not found"**
```r
# Solution: Source path configuration first
source("config/paths.R")
```

**Issue 2: Missing raw data files**
```r
# Check data-raw/ directory exists and contains input files
list.files("data-raw/sdtm_input/", recursive = TRUE)
```

**Issue 3: Controlled terminology errors**
```r
# Update CDISC CT version in config/controlled_terminology/
# Download latest from: https://www.cdisc.org/standards/terminology
```

## Performance Optimization

### Parallel Execution

Domain classes are independent and can be parallelized:

```r
library(future)
plan(multisession, workers = 4)

future_lapply(list(
  "sdtm/programs/R/oak/foundation/generate_dm_with_oak.R",
  "sdtm/programs/R/oak/events/generate_ae_with_oak.R",
  "sdtm/programs/R/oak/findings/generate_lb_with_oak.R"
), source)
```

**Expected speedup:** 3-4x on multi-core machines

### Memory Management

For large studies (>1000 subjects):
- Process domains sequentially
- Use `rm()` to clear objects between domains
- Consider data.table for large findings domains

## Integration with ADaM

SDTM outputs feed directly into ADaM pipeline:

```
SDTM Domains → ADaM Programs → Analysis Datasets
     ↓               ↓                  ↓
  dm.xpt       admiral/adsl.R       adsl.xpt
  ae.xpt       admiral/adae.R       adae.xpt
  lb.xpt       admiral/adlb.R       adlb.xpt
```

**Next step:** See `adam/programs/R/admiral/README.md`

## References

### Pharmaverse Resources
- [sdtm.oak Package Documentation](https://pharmaverse.github.io/sdtm.oak/)
- [Pharmaverse Blog](https://pharmaverse.github.io/blog/)
- [CDISC Open Source Alliance (COSA)](https://www.cdisc.org/cosa)

### CDISC Standards
- [SDTM Implementation Guide v3.4](https://www.cdisc.org/standards/foundational/sdtmig)
- [SDTM v2.1](https://www.cdisc.org/standards/foundational/sdtm)
- [Controlled Terminology](https://www.cdisc.org/standards/terminology)

### Regulatory Guidance
- [FDA Study Data Technical Conformance Guide](https://www.fda.gov/industry/fda-data-standards-advisory-board/study-data-standards-resources)
- [EMA SEND/SDTM Specifications](https://www.ema.europa.eu/en/human-regulatory/research-development/data-medicines-iso-idmp-standards/substance-registration)

## Support

For questions about this implementation:
- **Repository Issues:** [github.com/stiigg/sas-r-hybrid-clinical-pipeline/issues](https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/issues)
- **Pharmaverse Slack:** [pharmaverse.slack.com](https://pharmaverse.slack.com)
- **CDISC Forum:** [community.cdisc.org](https://community.cdisc.org)

---

**Last Updated:** December 23, 2024  
**Pharmaverse Structure:** Version 2025.1  
**CDISC Standards:** SDTM IG v3.4, CT 2024-12-21
