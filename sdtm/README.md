# SDTM Directory - Dedicated SDTM Mapping Implementation

This directory contains all SDTM (Study Data Tabulation Model) mapping logic, transforming raw clinical trial data into standardized CDISC SDTM domains.

## Directory Structure

```
sdtm/
├── programs/          # SDTM mapping programs
│   ├── sas/          # SAS-based SDTM mappings
│   └── R/            # R/pharmaverse SDTM mappings
├── metadata/         # SDTM specifications and documentation
├── data/            # SDTM data inputs and outputs
│   ├── input/       # Raw source data
│   └── output/      # Generated SDTM datasets
├── outputs/         # Logs, validation reports
└── utilities/       # SDTM-specific helper functions
```

## Data Flow

```
data/input/          →  programs/sas/     →  data/output/
(raw CSVs)              programs/R/           (SDTM domains)
                        (mapping logic)
```

## SDTM Programs

### SAS Programs
- `20_sdtm_dm.sas` - Demographics domain (DM)
- `sdtm_tu_tr.sas` - Tumor/Target Response domains (TU/TR)

### R Programs  
- `01_build_sdtm_pharmaverse.R` - Pharmaverse-based SDTM construction

## Running SDTM Pipeline

From project root:
```r
source("sdtm/run_sdtm_all.R")
```

## Output

SDTM datasets are written to `sdtm/data/output/` and serve as input for the ADaM pipeline.
