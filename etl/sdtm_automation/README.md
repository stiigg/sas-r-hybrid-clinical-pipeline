# SDTM Automation Pipeline with sdtm.oak

Complete SDTM (Study Data Tabulation Model) domain generation using the `sdtm.oak` R package from pharmaverse. This pipeline automates the transformation of raw clinical trial data into CDISC-compliant SDTM datasets ready for FDA submission.

## Overview

This directory contains **12 automated R scripts** that generate standardized SDTM domains using algorithm-based transformations. The approach replaces manual SAS programming with reproducible, validated R code.

## Implemented Domains

### ✅ Foundation Domain (1)
- **DM** - Demographics: Subject-level information, treatment arms, study dates

### ✅ Oncology Package (3)
- **TU** - Tumor Identification: Baseline tumor inventory
- **TR** - Tumor Results: Longitudinal tumor measurements
- **RS** - Disease Response: Overall response assessments (CR, PR, SD, PD)

### ✅ Safety & Exposure (3)
- **AE** - Adverse Events: Side effects and safety events
- **EX** - Exposure: Study drug administration records
- **SV** - Subject Visits: Visit attendance tracking

### ✅ Subject Status (2)
- **DS** - Disposition: Study completion status and discontinuation
- **CM** - Concomitant Medications: Non-study medications
- **MH** - Medical History: Pre-existing conditions

### ✅ Clinical Measurements (2)
- **LB** - Laboratory Tests: Hematology, chemistry, urinalysis
- **VS** - Vital Signs: Blood pressure, temperature, pulse, weight, height

## Domain Coverage

**Current Status: 12/15 domains (80% complete)**

This represents a **robust submission-ready package** covering:
- All mandatory domains (DM, DS)
- Complete oncology tumor assessment package (TU, TR, RS)
- Comprehensive safety monitoring (AE, CM, MH, LB, VS)
- Treatment exposure tracking (EX, SV)

## File Structure

```
etl/sdtm_automation/
├── README.md                          # This file
├── run_all_sdtm_domains.R            # Master script to execute all domains
├── generate_dm_with_oak.R            # Demographics
├── generate_tu_with_oak.R            # Tumor Identification
├── generate_tr_with_oak.R            # Tumor Results
├── generate_rs_with_oak.R            # Disease Response
├── generate_ae_with_oak.R            # Adverse Events
├── generate_ex_with_oak.R            # Exposure
├── generate_sv_with_oak.R            # Subject Visits
├── generate_ds_with_oak.R            # Disposition
├── generate_cm_with_oak.R            # Concomitant Medications
├── generate_mh_with_oak.R            # Medical History
├── generate_lb_with_oak.R            # Laboratory Tests
└── generate_vs_with_oak.R            # Vital Signs
```

## Prerequisites

### Required R Packages

```r
install.packages(c("dplyr", "haven", "readr", "here", "logger"))
install.packages("sdtm.oak")  # From CRAN
install.packages("xportr")     # Optional but recommended for FDA-compliant XPT files
```

### Demo Data

Each script can run with or without demo data:
- **With demo data**: Place CSV files in `demo/data/` directory
- **Without demo data**: Scripts automatically generate synthetic test data

Expected demo data files:
- `demo/data/test_sdtm_dm.csv`
- `demo/data/test_sdtm_tu.csv`
- `demo/data/test_sdtm_tr.csv`
- `demo/data/test_sdtm_rs.csv`
- `demo/data/test_sdtm_ae.csv`
- `demo/data/test_sdtm_ex.csv`
- `demo/data/test_sdtm_sv.csv`
- `demo/data/test_sdtm_ds.csv`
- `demo/data/test_sdtm_cm.csv`
- `demo/data/test_sdtm_mh.csv`
- `demo/data/test_sdtm_lb.csv`
- `demo/data/test_sdtm_vs.csv`

## Usage

### Run All Domains at Once

```bash
Rscript etl/sdtm_automation/run_all_sdtm_domains.R
```

### Run Individual Domains

```bash
# Foundation
Rscript etl/sdtm_automation/generate_dm_with_oak.R

# Oncology package
Rscript etl/sdtm_automation/generate_tu_with_oak.R
Rscript etl/sdtm_automation/generate_tr_with_oak.R
Rscript etl/sdtm_automation/generate_rs_with_oak.R

# Safety and exposure
Rscript etl/sdtm_automation/generate_ae_with_oak.R
Rscript etl/sdtm_automation/generate_ex_with_oak.R
Rscript etl/sdtm_automation/generate_sv_with_oak.R

# Subject status
Rscript etl/sdtm_automation/generate_ds_with_oak.R
Rscript etl/sdtm_automation/generate_cm_with_oak.R
Rscript etl/sdtm_automation/generate_mh_with_oak.R

# Clinical measurements
Rscript etl/sdtm_automation/generate_lb_with_oak.R
Rscript etl/sdtm_automation/generate_vs_with_oak.R
```

## Output

Each script generates two files in `outputs/sdtm/`:

1. **XPT file**: SAS transport format for FDA submission
   - Example: `outputs/sdtm/dm_oak.xpt`

2. **CSV file**: Human-readable format for review
   - Example: `outputs/sdtm/dm_oak.csv`

### Complete Output Package

```
outputs/sdtm/
├── dm_oak.xpt / dm_oak.csv       # Demographics
├── tu_oak.xpt / tu_oak.csv       # Tumor Identification
├── tr_oak.xpt / tr_oak.csv       # Tumor Results
├── rs_oak.xpt / rs_oak.csv       # Disease Response
├── ae_oak.xpt / ae_oak.csv       # Adverse Events
├── ex_oak.xpt / ex_oak.csv       # Exposure
├── sv_oak.xpt / sv_oak.csv       # Subject Visits
├── ds_oak.xpt / ds_oak.csv       # Disposition
├── cm_oak.xpt / cm_oak.csv       # Concomitant Medications
├── mh_oak.xpt / mh_oak.csv       # Medical History
├── lb_oak.xpt / lb_oak.csv       # Laboratory Tests
└── vs_oak.xpt / vs_oak.csv       # Vital Signs
```

## Algorithm-Based Approach

All scripts use `sdtm.oak` functions for standardized transformations:

- **`assign_no_ct()`**: Direct variable assignments without controlled terminology
- **`assign_datetime()`**: ISO 8601 date/time conversions
- **Standard pipelines**: Consistent workflow across all domains

### Example Workflow Pattern

```r
raw_data %>%
  assign_no_ct(tgt_var = "STUDYID", tgt_val = "STUDY-001") %>%
  assign_no_ct(tgt_var = "USUBJID", tgt_val = paste("STUDY-001", SUBJID, sep = "-")) %>%
  assign_datetime(dtc_var = "VSDTC", dtm = VISIT_DATE, date_fmt = "%Y-%m-%d") %>%
  select(STUDYID, DOMAIN, USUBJID, ...)
```

## Key Features

- ✅ **Automated**: No manual data mapping required
- ✅ **Reproducible**: Same input always produces same output
- ✅ **Validated**: Uses pharmaverse `sdtm.oak` package
- ✅ **FDA-compliant**: Generates XPT files in SAS transport format
- ✅ **Self-documenting**: Comprehensive logging throughout
- ✅ **Flexible**: Works with or without demo data

## Domain Linking

Domains are connected through key variables:

- **USUBJID**: Unique subject identifier (links all domains)
- **VISITNUM/VISIT**: Visit identifiers (links time-based domains)
- **TULNKID/TRLNKID**: Tumor linking (connects TU ↔ TR ↔ RS)
- **RFSTDTC/RFENDTC**: Reference dates from DM domain

## Validation

Each script includes:
- Record count validation
- Subject count verification
- Domain-specific quality checks (e.g., completers vs. discontinued in DS)
- Comprehensive logging with `logger` package

## Future Enhancements

Optional domains that could be added:
- **EG** - ECG Tests (for cardiotoxicity monitoring)
- **PE** - Physical Examination
- **QS** - Questionnaires (patient-reported outcomes)
- **TA/TE/TV** - Trial design domains

## References

- [CDISC SDTM Implementation Guide](https://www.cdisc.org/standards/foundational/sdtm)
- [sdtm.oak Package Documentation](https://pharmaverse.github.io/sdtm.oak/)
- [Pharmaverse](https://pharmaverse.org/)
- [FDA Study Data Technical Conformance Guide](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/study-data-technical-conformance-guide)

## License

This code is part of the sas-r-hybrid-clinical-pipeline project.

## Contact

For questions or issues, please open a GitHub issue in the parent repository.
