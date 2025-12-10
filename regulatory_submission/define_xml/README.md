# Define.xml Generation for Regulatory Submissions

## Overview

This directory contains tools and workflows for generating CDISC-compliant define.xml files using the pharmaverse `xportr` package. Define.xml is a mandatory component of regulatory submissions that provides detailed metadata about submitted datasets.

## Purpose

Define.xml files serve as:
- **Dataset Dictionary**: Complete variable-level metadata for all SDTM and ADaM datasets
- **Reviewer Guide**: Enables regulatory reviewers to understand dataset structure without SAS access
- **Compliance Documentation**: Demonstrates adherence to CDISC standards (SDTM IG v3.4, ADaM IG v1.3)
- **Traceability**: Links datasets to analysis specifications and results

## Regulatory Requirements

### FDA Requirements
- Define.xml v2.0 or v2.1 format (FDA prefers v2.1)
- Must accompany all datasets in Module 5.3.5.3 (ADaM) and 5.3.5.4 (SDTM)
- Must validate using FDA Validator or Pinnacle 21 Community
- Required elements: Variable attributes, Value-level metadata, Code lists, Analysis derivations

### EMA/PMDA Requirements
- Similar define.xml requirements
- Additional country-specific validations may apply

## Workflow

### 1. Prepare Dataset Specifications

Create Excel specifications with required columns:
- **Variable-level metadata** (`dataset_specifications/adam_spec.xlsx`):
  - `dataset`: Dataset name (e.g., ADSL, ADRS)
  - `variable`: Variable name
  - `label`: Variable label (≤40 characters)
  - `type`: Data type (text, integer, float, datetime)
  - `length`: Character length or numeric precision
  - `format`: Display format (e.g., DATE9., 8.2)
  - `order`: Column position in dataset
  - `origin`: Derivation source (Assigned, Derived, Protocol, etc.)
  - `role`: Variable role (Identifier, Topic, Qualifier, etc.)

### 2. Apply xportr Validations

```r
library(xportr)
library(admiral)

# Load dataset and specifications
adsl <- readRDS("outputs/adam/adsl.rds")
var_spec <- readxl::read_excel("regulatory_submission/define_xml/dataset_specifications/adam_spec.xlsx")

# Apply xportr pipeline
adsl_validated <- adsl |>
  xportr_type(var_spec) |>      # Validate variable types
  xportr_length(var_spec) |>    # Check character lengths
  xportr_label(var_spec) |>     # Apply variable labels
  xportr_order(var_spec) |>     # Order variables per spec
  xportr_format(var_spec) |>    # Apply display formats
  xportr_df_label(dataset_spec) # Apply dataset label
```

### 3. Generate XPT Files

```r
# Write SAS XPT v5 transport file for submission
xportr_write(
  adsl_validated,
  path = "regulatory_submission/define_xml/outputs/adsl.xpt",
  domain = "ADSL",
  label = "Subject-Level Analysis Dataset"
)
```

### 4. Create Define.xml

```r
# Run define.xml generation script
source("regulatory_submission/define_xml/generate_define_adam.R")

# Output: define_adam_v2.xml in outputs/ directory
```

### 5. Validate Define.xml

**Using Pinnacle 21 Community (Free)**:
```bash
# Download from: https://www.pinnacle21.com/products/community
pinnacle21 validate \
  --standard=cdisc-ct \
  --define=regulatory_submission/define_xml/outputs/define_adam_v2.xml \
  --data=regulatory_submission/define_xml/outputs/
```

## Directory Structure

```
regulatory_submission/define_xml/
├── README.md                          # This file
├── generate_define_adam.R             # ADaM define.xml generator
├── generate_define_sdtm.R             # SDTM define.xml generator
├── dataset_specifications/
│   ├── adam_spec.xlsx                 # ADaM variable metadata
│   └── sdtm_spec.xlsx                 # SDTM variable metadata
├── value_level_metadata/
│   ├── adam_vl_spec.xlsx              # ADaM value-level metadata
│   └── sdtm_vl_spec.xlsx              # SDTM value-level metadata
└── outputs/
    ├── adsl.xpt                       # XPT files for submission
    ├── adrs.xpt
    ├── adtte.xpt
    ├── define_adam_v2.xml             # ADaM define.xml
    └── define_sdtm_v2.xml             # SDTM define.xml
```

## Resources

- [xportr Package](https://atorus-research.github.io/xportr/)
- [FDA Define.xml v2.1 Specification](https://www.fda.gov/media/88173/download)
- [CDISC Define-XML User Guide](https://www.cdisc.org/standards/foundational/define-xml)
- [Pinnacle 21 Community](https://www.pinnacle21.com/products/community)
