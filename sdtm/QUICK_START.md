# Quick Start Guide: SDTM Pipeline with sdtm.oak

## Overview

This guide provides step-by-step instructions for running the SDTM data transformation pipeline using the `sdtm.oak` package (v0.2.0). The pipeline implements pharmaverse best practices for clinical trial data standardization.

## Prerequisites

### Required R Packages

```r
# Install from CRAN
install.packages(c(
  "sdtm.oak",
  "pharmaverseraw",
  "pharmaversesdtm",
  "xportr",
  "dplyr",
  "readr",
  "logger",
  "here",
  "testthat"
))
```

### Environment Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/stiigg/sas-r-hybrid-clinical-pipeline.git
   cd sas-r-hybrid-clinical-pipeline
   ```

2. **Set up configuration:**
   - Ensure `config/paths.R` defines output directories
   - Review `config/controlled_terminology.R` for CT specifications

3. **Create output directories:**
   ```r
   dir.create("sdtm/data/csv", showWarnings = FALSE, recursive = TRUE)
   dir.create("sdtm/data/xpt", showWarnings = FALSE, recursive = TRUE)
   dir.create("sdtm/logs", showWarnings = FALSE, recursive = TRUE)
   ```

## Running the Pipeline

### Option 1: Run Complete Pipeline

Execute all SDTM domains in sequence:

```r
# From R console
source("sdtm/programs/R/oak/run_all_sdtm_oak.R")
```

This will:
- Generate DM (Demographics) domain
- Generate AE (Adverse Events) domain
- Generate VS (Vital Signs) domain
- Create CSV and XPT outputs
- Log execution summary

### Option 2: Run Individual Domains

#### Demographics (DM)
```r
source("sdtm/programs/R/oak/foundation/generate_dm_with_oak.R")
```

#### Adverse Events (AE)
```r
source("sdtm/programs/R/oak/events/generate_ae_with_oak.R")
```

#### Vital Signs (VS)
```r
source("sdtm/programs/R/oak/findings/generate_vs_with_oak.R")
```

## Output Files

### Generated SDTM Datasets

After successful execution, find outputs in:

- **CSV format:** `sdtm/data/csv/`
  - `dm.csv` - Demographics
  - `ae.csv` - Adverse Events
  - `vs.csv` - Vital Signs

- **XPT format (regulatory submission):** `sdtm/data/xpt/`
  - `dm.xpt`
  - `ae.xpt`
  - `vs.xpt`

- **Execution logs:** `sdtm/logs/sdtm_oak_pipeline.log`

## Running Unit Tests

### Test All Domains

```r
library(testthat)

# Test DM domain
test_file("tests/testthat/test-sdtm-dm.R")

# Test VS domain
test_file("tests/testthat/test-sdtm-vs.R")

# Test AE domain
test_file("tests/testthat/test-sdtm-ae.R")
```

### Run All Tests

```r
devtools::test()
```

## Validation Workflow

### 1. Data Quality Checks

```r
# Load generated datasets
dm <- readr::read_csv("sdtm/data/csv/dm.csv")
ae <- readr::read_csv("sdtm/data/csv/ae.csv")
vs <- readr::read_csv("sdtm/data/csv/vs.csv")

# Basic validation
summary(dm)
summary(ae)
summary(vs)
```

### 2. Pinnacle 21 Validator

1. Export XPT files to validation directory:
   ```bash
   # XPT files are already in sdtm/data/xpt/
   ```

2. Open Pinnacle 21 Community

3. Select study validation type:
   - SDTM 3.4 or latest version
   - Select appropriate therapeutic area

4. Load XPT files from `sdtm/data/xpt/`

5. Review validation report for:
   - Variable conformance
   - Controlled terminology compliance
   - Cross-domain consistency

### 3. Custom Validation Checks

```r
# Cross-domain checks
library(dplyr)

# Check all AE subjects exist in DM
ae_subjects <- unique(ae$USUBJID)
dm_subjects <- unique(dm$USUBJID)

missing_dm <- setdiff(ae_subjects, dm_subjects)
if (length(missing_dm) > 0) {
  warning("Subjects in AE not found in DM: ", paste(missing_dm, collapse = ", "))
}

# Check date consistency
ae_dates <- ae %>%
  filter(!is.na(AESTDTC)) %>%
  left_join(dm %>% select(USUBJID, RFSTDTC), by = "USUBJID") %>%
  mutate(
    ae_before_study = as.Date(substr(AESTDTC, 1, 10)) < as.Date(substr(RFSTDTC, 1, 10))
  )

if (any(ae_dates$ae_before_study, na.rm = TRUE)) {
  warning("Some AEs start before study reference start date")
}
```

## Customization

### Using Your Own Raw Data

1. **Replace pharmaverseraw data source:**

   Edit domain scripts (e.g., `generate_dm_with_oak.R`):
   
   ```r
   # Before:
   # dm_raw <- pharmaverseraw::dm_raw
   
   # After:
   dm_raw <- readr::read_csv(file.path(PATH_RAW_DATA, "my_demographics.csv"))
   ```

2. **Map your variable names to expected format:**

   ```r
   dm_raw <- dm_raw %>%
     rename(
       USUBJID = patient_id,
       AGE = patient_age,
       SEX = patient_gender
       # Add other mappings
     )
   ```

### Adding Controlled Terminology

Edit `config/controlled_terminology.R`:

```r
# Add new CT specification
oak_ct_spec$my_custom_ct <- tibble(
  codelist_code = c("CUSTOM01", "CUSTOM01"),
  term_code = c("C001", "C002"),
  term_value = c("VALUE1", "VALUE2"),
  collected_value = c("Value 1", "Value 2"),
  term_preferred_term = c("First Value", "Second Value")
)
```

## Troubleshooting

### Common Issues

#### 1. Missing PATH variables

**Error:** `object 'PATH_SDTM_CSV' not found`

**Solution:** Source the paths configuration:
```r
source(here::here("config", "paths.R"))
```

#### 2. Package not found

**Error:** `there is no package called 'sdtm.oak'`

**Solution:** Install missing packages:
```r
install.packages("sdtm.oak")
```

#### 3. Controlled terminology mismatch

**Error:** `Error in assign_ct(): CT specification not found`

**Solution:** Verify CT specification name and codelist code in `controlled_terminology.R`

#### 4. Date parsing errors

**Error:** `Error in assign_datetime(): Invalid date format`

**Solution:** Ensure dates are in ISO 8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)

## Performance Optimization

### Parallel Execution

For large datasets, run independent domains in parallel:

```r
library(future)
library(furrr)

plan(multisession, workers = 4)

# Run domains in parallel
scripts <- c(
  "sdtm/programs/R/oak/events/generate_ae_with_oak.R",
  "sdtm/programs/R/oak/findings/generate_vs_with_oak.R"
)

future_walk(scripts, source)
```

### Memory Management

For very large studies:

```r
# Clear intermediate objects
rm(dm_raw, ae_raw, vs_raw)
gc()

# Process in chunks if needed
library(chunked)
```

## Next Steps

1. **Expand domain coverage:**
   - Implement CM (Concomitant Medications)
   - Implement LB (Laboratory Results)
   - Add EG (ECG), MH (Medical History)

2. **Enhance validation:**
   - Add define.xml generation
   - Implement aCRF reconciliation
   - Create data lineage documentation

3. **Production deployment:**
   - Set up CI/CD pipeline
   - Integrate with EDC system
   - Automate Pinnacle 21 validation

## Support & Resources

- **sdtm.oak documentation:** https://pharmaverse.github.io/sdtm.oak/
- **pharmaverse community:** https://pharmaverse.org/
- **CDISC SDTM IG:** https://www.cdisc.org/standards/foundational/sdtm
- **Repository issues:** https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/issues

---

**Last Updated:** 2024-12-24  
**Version:** 1.0.0  
**Author:** Christian Baghai
