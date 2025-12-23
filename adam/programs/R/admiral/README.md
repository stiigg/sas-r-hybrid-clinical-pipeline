# ADaM Dataset Derivation with admiral

## Overview

This directory contains **ADaM (Analysis Data Model) dataset derivation programs** using the [`admiral`](https://pharmaverse.github.io/admiral/) package and its extensions from the pharmaverse ecosystem.

**Framework:** admiral (ADaM in R Asset Library)  
**Standards:** CDISC ADaM Implementation Guide v1.3  
**Status:** Core datasets implemented, oncology extensions in progress

## What is admiral?

`admiral` is the pharmaverse flagship package for ADaM derivations:

- **Modular functions**: Reusable derivation functions (e.g., `derive_var_age()`, `derive_vars_merged()`)
- **Template-based**: Standard programming templates for common ADaM structures
- **CDISC-compliant**: Follows ADaM IG v1.3 requirements
- **Production-proven**: Used in successful regulatory submissions
- **Extension ecosystem**: Specialty packages for oncology, vaccines, ophthalmology

**Key References:**
- [admiral CRAN Package](https://cran.r-project.org/package=admiral)
- [admiral GitHub](https://github.com/pharmaverse/admiral)
- [admiralonco for Oncology](https://pharmaverse.github.io/admiralonco/)

## Directory Structure

ADaM datasets organized by **structure type** following ADaM IG:

```
adam/programs/R/admiral/
├── adsl/                    # Subject-Level Analysis Dataset (ADSL)
│   └── generate_adsl_with_admiral.R
│
├── bds/                     # Basic Data Structure (BDS)
│   ├── generate_adlb_with_admiral.R   # Laboratory Analysis Dataset
│   ├── generate_advs_with_admiral.R   # Vital Signs Analysis Dataset
│   └── generate_adeg_with_admiral.R   # ECG Analysis Dataset
│
├── occds/                   # Occurrence Data Structure (OCCDS)
│   └── generate_adae_with_admiral.R   # Adverse Events Analysis Dataset
│
├── oncology/                # Oncology-Specific Datasets
│   ├── generate_adrs_with_admiralonco.R  # Response Analysis (RECIST)
│   └── generate_adtte_with_admiralonco.R # Time-to-Event Analysis
│
├── run_all_adam_admiral.R   # Master orchestration script
└── README.md                # This file
```

## ADaM Structure Types

### ADSL: Subject-Level Analysis Dataset

**Purpose:** Foundation dataset containing one record per subject with baseline characteristics and treatment information.

**Key Variables:**
- Demographics: AGE, AGEGR1, SEX, RACE, ETHNIC
- Treatment: TRT01P, TRT01A, TRT01PN, TRT01AN
- Dates: TRTSDT, TRTEDT, RFSTDTC, RFENDTC
- Study participation: SAFFL, FASFL, ITTFL
- Baseline characteristics: All variables ending in "BL"

**Dependencies:** DM, EX, DS, SV SDTM domains

**admiral Functions Used:**
```r
derive_vars_merged()        # Merge SDTM variables
derive_var_age_years()      # Calculate age
derive_vars_dt()            # Derive dates
derive_var_trtsdtm()        # Treatment start date/time
derive_vars_duration()      # Treatment duration
derive_var_merged_exist_flag() # Analysis flags (SAFFL, FASFL)
```

**Status:** ✅ Complete

### BDS: Basic Data Structure

**Purpose:** One record per subject per parameter per analysis visit.

**Typical Pattern:**
- PARAMCD: Parameter code (e.g., "ALT", "SYSBP")
- PARAM: Parameter description
- AVAL: Analysis value (numeric)
- AVALC: Analysis value (character)
- CHG: Change from baseline
- PCHG: Percent change from baseline
- BASE: Baseline value
- DTYPE: Derivation type

**BDS Datasets in This Repository:**

| **Dataset** | **Parameters** | **SDTM Source** | **Status** |
|-------------|----------------|-----------------|------------|
| **ADLB** | Laboratory tests (ALT, AST, WBC, etc.) | LB | ✅ Complete |
| **ADVS** | Vital signs (SYSBP, DIABP, PULSE, TEMP) | VS | ✅ Complete |
| **ADEG** | ECG parameters (HR, QTcF, PR, QRS) | EG | ✅ Complete |

**admiral Functions Used:**
```r
derive_vars_merged()        # Merge ADSL variables
derive_param_computed()     # Computed parameters (e.g., change from baseline)
derive_var_base()           # Baseline values
derive_var_chg()            # Change from baseline
derive_var_pchg()           # Percent change
derive_var_anrind()         # Normal range indicator
derive_var_ontrtfl()        # On-treatment flag
```

**Status:** Core datasets complete

### OCCDS: Occurrence Data Structure

**Purpose:** One record per subject per event occurrence.

**Typical Pattern:**
- Event identification: AEDECOD, AEBODSYS
- Severity: ASEV, AESEV
- Causality: AREL
- Outcome: AEOUT
- Flags: AOCC01FL, AOCC02FL, etc.

**OCCDS Datasets:**

| **Dataset** | **Events** | **SDTM Source** | **Status** |
|-------------|------------|-----------------|------------|
| **ADAE** | Adverse Events | AE | ✅ Complete |

**admiral Functions Used:**
```r
derive_vars_merged()        # Merge ADSL
derive_var_merged_exist_flag() # Occurrence flags
derive_vars_dt()            # Event dates
derive_var_ontrtfl()        # On-treatment flag
derive_vars_duration()      # Event duration
```

**Status:** ✅ Complete

### Oncology Extensions (admiralonco)

**Purpose:** RECIST 1.1 response and time-to-event endpoints.

**Oncology-Specific Datasets:**

| **Dataset** | **Purpose** | **SDTM Source** | **admiralonco Functions** | **Status** |
|-------------|-------------|-----------------|---------------------------|------------|
| **ADRS** | Response Assessment | RS, TU, TR | `derive_param_response()`, `derive_param_bor()` | 🚧 In Progress |
| **ADTTE** | Time-to-Event | ADRS, DS | `derive_param_tte()`, `derive_var_cnsr()` | 🚧 In Progress |

**Key RECIST 1.1 Parameters:**
- **OVR**: Overall Response (CR, PR, SD, PD, NE)
- **BOR**: Best Overall Response
- **CBOR**: Confirmed Best Overall Response
- **PFS**: Progression-Free Survival
- **OS**: Overall Survival
- **DOR**: Duration of Response
- **TTR**: Time to Response

**admiralonco Reference:** [admiralonco.admiral.pharmaverse.org](https://pharmaverse.github.io/admiralonco/)

**Status:** Code complete, testing in progress

## Derivation Workflow

### Standard ADaM Pipeline

```
  SDTM Domains
       ↓
  1. ADSL (foundation) ← DM + EX + DS + SV
       ↓
  2. BDS Datasets
     - ADLB ← ADSL + LB
     - ADVS ← ADSL + VS  
     - ADEG ← ADSL + EG
       ↓
  3. OCCDS Datasets
     - ADAE ← ADSL + AE
       ↓
  4. Oncology Datasets
     - ADRS ← ADSL + RS + TU + TR
     - ADTTE ← ADSL + ADRS + DS
```

**Critical Rule:** ADSL must be derived first (all other datasets merge ADSL variables)

## Quick Start

### Run Complete Pipeline

```r
# From repository root
source("config/paths.R")  # Load paths
source("adam/programs/R/admiral/run_all_adam_admiral.R")  # Generate all ADaM
```

### Run Individual Dataset

```r
# Example: Generate ADSL
source("config/paths.R")
source("adam/programs/R/admiral/adsl/generate_adsl_with_admiral.R")

# Example: Generate ADLB (requires ADSL first)
source("adam/programs/R/admiral/bds/generate_adlb_with_admiral.R")
```

### Run Dataset Type

```r
# Example: Generate all BDS datasets
source("config/paths.R")
for (script in list.files("adam/programs/R/admiral/bds", full.names = TRUE)) {
  source(script)
}
```

## Output Locations

All ADaM scripts generate outputs in standardized locations:

```
adam/
├── data/
│   ├── xpt/          # SAS v5 transport files (FDA submission)
│   │   ├── adsl.xpt
│   │   ├── adlb.xpt
│   │   ├── advs.xpt
│   │   └── ...
│   └── csv/          # Human-readable CSV
│       ├── adsl.csv
│       ├── adlb.csv
│       └── ...
└── logs/             # Execution logs
    ├── adsl_log.txt
    └── ...
```

## Standard Script Pattern

All admiral derivation scripts follow consistent structure:

```r
# 1. Setup
library(admiral)
library(dplyr)
library(lubridate)
source(here::here("config", "paths.R"))

# 2. Load SDTM datasets
sdtm_dm <- readr::read_csv(file.path(PATH_SDTM_DATA_CSV, "dm.csv"))
sdtm_ex <- readr::read_csv(file.path(PATH_SDTM_DATA_CSV, "ex.csv"))

# 3. Derive ADaM dataset using admiral functions
adsl <- sdtm_dm %>%
  derive_vars_merged(
    dataset_add = sdtm_ex,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(TRTSDT = EXSTDTC, TRTEDT = EXENDTC)
  ) %>%
  derive_var_age_years(
    age = AGE,
    age_unit = AGEU
  ) %>%
  derive_vars_dt(
    new_vars_prefix = "TRTS",
    dtc = TRTSDT
  )

# 4. Write outputs
xportr::xportr_write(adsl, file.path(PATH_ADAM_DATA_XPT, "adsl.xpt"))
readr::write_csv(adsl, file.path(PATH_ADAM_DATA_CSV, "adsl.csv"))

# 5. Log completion
log_info("ADSL generation complete: {nrow(adsl)} subjects")
```

## Dependencies

### Required R Packages

```r
# Pharmaverse ecosystem
install.packages(c(
  "admiral",         # Core ADaM derivations
  "admiralonco",     # Oncology extensions
  "xportr",          # XPT file creation
  "metacore",        # Metadata management
  "metatools"        # Metadata operations
))

# Supporting packages
install.packages(c(
  "dplyr",           # Data manipulation
  "tidyr",           # Data tidying
  "lubridate",       # Date/time handling
  "stringr",         # String operations
  "purrr",           # Functional programming
  "readr",           # Data import/export
  "logger",          # Logging
  "here"             # Path management
))
```

### Package Versions

See `renv.lock` for exact versions.

**Pharmaverse compatibility:**
- admiral v1.1.1 (CRAN 2024-12-01)
- admiralonco v1.1.0 (CRAN 2024-09-20)

## Validation Strategy

### Three-Tier Validation

**Tier 1: Automated Checks**
- All required variables present
- Data types correct (numeric vs character)
- Key variables populated (no missing USUBJID, PARAM)
- Proper sort order (USUBJID, PARAMCD, AVISITN)

**Tier 2: Cross-Dataset Consistency**
- ADSL subject count matches all other datasets
- Baseline flags consistent
- Treatment variables consistent across datasets
- Date variables logically consistent

**Tier 3: Regulatory Compliance**
- ADaM IG v1.3 compliance (Pinnacle21)
- Define.xml metadata complete
- Controlled terminology validated

**Validation reports:** `adam/validation/reports/`

## Integration with TLFs

ADaM datasets feed directly into Tables/Listings/Figures:

```
ADaM Datasets → TLF Programs → Clinical Study Report
     ↓               ↓                  ↓
  adsl.xpt      tlf/table_14.2.01.R   Table 14.2.1 Demographics
  adae.xpt      tlf/table_14.3.01.R   Table 14.3.1 Adverse Events
  adlb.xpt      tlf/table_14.3.05.R   Table 14.3.5 Laboratory
```

**Next step:** See `tlf/programs/R/README.md`

## Troubleshooting

### Common Issues

**Issue 1: "ADSL dataset not found"**
```r
# Solution: Generate ADSL first
source("adam/programs/R/admiral/adsl/generate_adsl_with_admiral.R")
```

**Issue 2: Merge failures**
```r
# Check for USUBJID mismatches between SDTM and ADSL
anti_join(sdtm_lb, adsl, by = c("STUDYID", "USUBJID"))
```

**Issue 3: Missing baseline values**
```r
# Verify baseline flag derivation logic
adlb %>% filter(ABLFL == "Y") %>% count(USUBJID, PARAMCD)
```

## Performance Considerations

### Large Studies (>1000 subjects)

- Use `data.table` for large BDS datasets
- Process parameters in parallel
- Consider database backend for very large studies

### Optimization Tips

```r
# Efficient baseline merge
adlb <- adlb %>%
  derive_var_base(
    by_vars = exprs(STUDYID, USUBJID, PARAMCD),
    source_var = AVAL,
    new_var = BASE,
    filter = ABLFL == "Y"
  )

# Parallel parameter processing
library(furrr)
plan(multisession, workers = 4)

params <- c("ALT", "AST", "WBC", "HGB")
results <- future_map_dfr(params, ~process_param(.x))
```

## References

### Pharmaverse Resources
- [admiral Documentation](https://pharmaverse.github.io/admiral/)
- [admiralonco Documentation](https://pharmaverse.github.io/admiralonco/)
- [admiral GitHub Examples](https://github.com/pharmaverse/admiral/tree/main/inst/templates)

### CDISC Standards
- [ADaM Implementation Guide v1.3](https://www.cdisc.org/standards/foundational/adam)
- [ADaM Basic Data Structure v1.1](https://www.cdisc.org/standards/foundational/adam/adamig-v1-3-web)

### Regulatory Guidance
- [FDA Study Data Technical Conformance Guide](https://www.fda.gov/industry/fda-data-standards-advisory-board/study-data-standards-resources)

## Support

For questions:
- **Repository Issues:** [github.com/stiigg/sas-r-hybrid-clinical-pipeline/issues](https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/issues)
- **Pharmaverse Slack:** [pharmaverse.slack.com](https://pharmaverse.slack.com) (#admiral channel)

---

**Last Updated:** December 23, 2024  
**admiral Version:** 1.1.1  
**ADaM IG:** v1.3
