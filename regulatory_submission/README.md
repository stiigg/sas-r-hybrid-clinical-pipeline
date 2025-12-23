# Regulatory Submission Structure

## Overview

This directory contains the **eCTD Module 5 submission package** and associated regulatory documentation following FDA/EMA requirements.

**Standards:**
- FDA Study Data Technical Conformance Guide v5.0
- EMA eCTD Specifications v3.2.2
- ICH M4E(R2) Common Technical Document

## Directory Structure

```
regulatory_submission/
├── ectd/
│   └── m5/                      # Module 5: Clinical Study Reports
│       └── datasets/
│           └── study-001/
│               ├── tabulations/     # SDTM datasets
│               │   ├── dm.xpt       # (symlink → sdtm/data/xpt/dm.xpt)
│               │   ├── ae.xpt
│               │   ├── ... (all SDTM .xpt files)
│               │   ├── define.xml
│               │   └── define.xsl
│               │
│               ├── analysis/        # ADaM datasets
│               │   ├── adsl.xpt     # (symlink → adam/data/xpt/adsl.xpt)
│               │   ├── adlb.xpt
│               │   ├── ... (all ADaM .xpt files)
│               │   ├── define.xml
│               │   └── define.xsl
│               │
│               └── datasets.pdf     # Dataset overview document
│
├── adrg/                        # Analysis Data Reviewer's Guide
│   ├── adrg_template.Rmd
│   └── adrg_v1.0.pdf
│
├── sdrg/                        # Study Data Reviewer's Guide  
│   ├── sdrg_template.Rmd
│   └── sdrg_v1.0.pdf
│
├── validation_reports/
│   ├── pinnacle21_sdtm_report.pdf
│   ├── pinnacle21_adam_report.pdf
│   └── validation_summary.pdf
│
└── README.md                    # This file
```

## Key Components

### eCTD Module 5

**FDA Requirement:** Electronic Common Technical Document Module 5 contains study reports and datasets.

**Critical Structure:**
- `m5/datasets/{study-id}/tabulations/` → SDTM datasets
- `m5/datasets/{study-id}/analysis/` → ADaM datasets
- Each folder requires:
  - Dataset files (*.xpt in SAS v5 transport format)
  - define.xml (CDISC Define-XML metadata)
  - define.xsl (stylesheet for define.xml viewing)

**Symbolic Links Strategy:**

Instead of copying files (risk of version mismatch), use symbolic links:

```bash
# Create symlinks for SDTM datasets
cd regulatory_submission/ectd/m5/datasets/study-001/tabulations/
for file in ../../../../../../sdtm/data/xpt/*.xpt; do
  ln -s "$file" .
done

# Create symlinks for ADaM datasets
cd ../analysis/
for file in ../../../../../../adam/data/xpt/*.xpt; do
  ln -s "$file" .
done
```

**Benefit:** Single source of truth - changes to source datasets automatically reflected in submission structure.

### ADRG: Analysis Data Reviewer's Guide

**Purpose:** Document explaining how ADaM datasets were created from SDTM.

**Required Content (FDA expectation):**
1. **Introduction** - Study overview
2. **Data Sources** - SDTM domains used
3. **Programming Methods** - Software, packages, algorithms
4. **Analysis Datasets** - Description of each ADaM dataset
5. **Traceability Matrix** - SDTM → ADaM variable mapping

**Template:** `adrg/adrg_template.Rmd` (R Markdown for automated generation)

### SDRG: Study Data Reviewer's Guide

**Purpose:** Document explaining SDTM dataset creation from raw EDC data.

**Required Content:**
1. Study design and data collection methods
2. EDC system and version
3. Data processing methodology
4. Quality control procedures
5. Known data issues and resolutions

**Template:** `sdrg/sdrg_template.Rmd`

### Validation Reports

**Pinnacle21 Validation:**
- Industry-standard CDISC conformance checker
- Validates controlled terminology
- Checks define.xml consistency
- Reports issues by severity (Error/Warning/Info)

**Required Reports:**
- `pinnacle21_sdtm_report.pdf` - SDTM validation
- `pinnacle21_adam_report.pdf` - ADaM validation
- `validation_summary.pdf` - Overall validation results

## Creating Submission Package

### Step 1: Generate All Datasets

```r
# Complete pipeline execution
source("config/paths.R")
source("sdtm/programs/R/oak/run_all_sdtm_oak.R")      # SDTM
source("adam/programs/R/admiral/run_all_adam_admiral.R") # ADaM
```

### Step 2: Create Symbolic Links

```bash
# From repository root
./regulatory_submission/scripts/create_submission_structure.sh
```

### Step 3: Generate define.xml

```r
# Using metacore and xportr
source("regulatory_submission/scripts/generate_define_xml.R")
```

### Step 4: Run Pinnacle21 Validation

```bash
# Requires Pinnacle21 Community installed
# Download from: https://www.pinnacle21.com/

p21 validate \
  --type SDTM \
  --data regulatory_submission/ectd/m5/datasets/study-001/tabulations/ \
  --output regulatory_submission/validation_reports/pinnacle21_sdtm_report.pdf

p21 validate \
  --type ADaM \
  --data regulatory_submission/ectd/m5/datasets/study-001/analysis/ \
  --output regulatory_submission/validation_reports/pinnacle21_adam_report.pdf
```

### Step 5: Generate ADRG/SDRG

```r
# Render R Markdown templates
rmarkdown::render("regulatory_submission/adrg/adrg_template.Rmd")
rmarkdown::render("regulatory_submission/sdrg/sdrg_template.Rmd")
```

### Step 6: Package Submission

```bash
# Create zip archive for submission
zip -r study-001-submission.zip regulatory_submission/ectd/m5/
```

## FDA/EMA Submission Checklist

### Critical Requirements

- ☐ All datasets in SAS v5 transport format (*.xpt)
- ☐ define.xml present in both tabulations/ and analysis/
- ☐ Variable names ≤ 8 characters
- ☐ Dataset names ≤ 8 characters
- ☐ Label lengths ≤ 40 characters (SDTM) or ≤ 200 characters (ADaM)
- ☐ No special characters in variable names
- ☐ All controlled terminology validated
- ☐ ADRG and SDRG included
- ☐ Pinnacle21 validation passed (no critical errors)
- ☐ Sort order correct for all datasets
- ☐ Define-XML matches actual dataset contents

### Common Submission Errors (Avoid These!)

1. **Version Mismatch:** Datasets in submission folder don't match source
   - ✅ **Solution:** Use symbolic links

2. **Missing Define-XML:** Submission rejected if define.xml absent
   - ✅ **Solution:** Automated generation from metadata

3. **XPT Format Issues:** Some SAS transport files corrupt or version 8
   - ✅ **Solution:** Use xportr package with validation

4. **Controlled Terminology Errors:** Invalid CDISC CT codes
   - ✅ **Solution:** Validate with latest CT version

5. **Character Encoding:** Non-ASCII characters in datasets
   - ✅ **Solution:** UTF-8 encoding, validate before XPT creation

## Regulatory References

### FDA Guidance
- [Study Data Technical Conformance Guide](https://www.fda.gov/industry/fda-data-standards-advisory-board/study-data-standards-resources)
- [Electronic Common Technical Document (eCTD) v4.0](https://www.fda.gov/drugs/electronic-regulatory-submission-and-review/ectd-submission-requirements)

### EMA Guidance
- [Data Package Guidance for eCTD Submissions](https://www.ema.europa.eu/en/human-regulatory/research-development/data-medicines-iso-idmp-standards)

### CDISC Standards
- [Define-XML v2.1](https://www.cdisc.org/standards/data-exchange/define-xml)
- [SDTM IG v3.4](https://www.cdisc.org/standards/foundational/sdtmig)
- [ADaM IG v1.3](https://www.cdisc.org/standards/foundational/adam)

## Support

For submission-related questions:
- **FDA eSub Support:** esub@fda.hhs.gov
- **Pinnacle21 Support:** https://www.pinnacle21.com/support
- **CDISC Forum:** https://community.cdisc.org

---

**Last Updated:** December 23, 2024  
**Submission Standards:** FDA Study Data Technical Conformance Guide v5.0  
**eCTD Version:** 4.0
