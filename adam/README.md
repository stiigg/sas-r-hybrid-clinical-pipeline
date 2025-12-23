# ADaM Directory - Dedicated ADaM Analysis Dataset Implementation

This directory contains all ADaM (Analysis Data Model) logic, transforming SDTM datasets into analysis-ready datasets for statistical analysis and TLF generation.

## Directory Structure

```
adam/
├── programs/          # ADaM dataset programs
│   ├── sas/          # SAS-based ADaM programs
│   └── R/            # R/pharmaverse ADaM programs
├── metadata/         # ADaM specifications
├── data/            # ADaM data inputs and outputs
│   ├── input/       # SDTM datasets (from sdtm/data/output/)
│   └── output/      # Generated ADaM datasets
├── outputs/         # Logs, validation reports
└── utilities/       # ADaM-specific helper functions
```

## Data Flow

```
data/input/          →  programs/sas/     →  data/output/
(SDTM datasets)         programs/R/           (ADaM datasets)
                        (analysis logic)
```

## ADaM Programs

### SAS Programs
- `30_adam_adsl.sas` - Subject-Level Analysis Dataset (ADSL)
- `adam_adbm.sas` - Biomarker Analysis Dataset (ADBM)
- `adam_adrs.sas` - Response Analysis Dataset (ADRS)
- `adam_adtr.sas` - Tumor Results Analysis (ADTR)
- `adam_adtte.sas` - Time-to-Event Analysis (ADTTE)
- `adam_adeffsum.sas` - Efficacy Summary Analysis

### R Programs
- `02_build_adam_pharmaverse.R` - Pharmaverse-based ADaM construction

## Running ADaM Pipeline

From project root:
```r
source("adam/run_adam_all.R")
```

## Dependencies

ADaM programs require SDTM datasets to be generated first. Run the SDTM pipeline before running ADaM.
