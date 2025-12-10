# Analysis Data Reviewer's Guide (ADRG)

## Overview

The **Analysis Data Reviewer's Guide (ADRG)** is a mandatory document for regulatory submissions that provides detailed information about analysis datasets (ADaM) to facilitate regulatory review. It accompanies the define.xml and analysis datasets in eCTD Module 5.3.5.3.

## Purpose

The ADRG serves to:
- **Describe Analysis Datasets**: Provide detailed descriptions of each ADaM dataset's structure and purpose
- **Document Derivations**: Explain complex derivation algorithms and data processing steps
- **Ensure Traceability**: Link analysis datasets back to source SDTM data
- **Facilitate Review**: Enable reviewers to understand and verify analysis datasets without running code
- **Demonstrate Compliance**: Show adherence to CDISC ADaM Implementation Guide

## Regulatory Requirements

### FDA Requirements

- **Mandatory for NDA/BLA submissions** with electronic datasets
- Must be placed in **eCTD Module 5.3.5.3** alongside ADaM datasets and define.xml
- Should follow PHUSE ADaRG template structure
- Must include all 7 required sections (see below)

### EMA/PMDA Requirements

- Similar requirements as FDA
- May have additional country-specific expectations
- Must demonstrate ADaM conformance with clear traceability

## ADRG Structure (7 Required Sections)

### Section 1: Introduction
- Study overview and objectives
- Scope of analysis datasets included
- Reference to define.xml location

### Section 2: Protocol Description
- Study design and population
- Treatment arms and randomization
- Key endpoints and assessments

### Section 3: Analysis Datasets (CRITICAL)
- Detailed description of each ADaM dataset
- Dataset structure (ADSL vs BDS vs OCCDS)
- Key variables and their purpose
- Relationship between datasets

### Section 4: ADaM Conformance
- Self-assessment against ADaM IG requirements
- Checklist of conformance items
- Justification for any deviations

### Section 5: Data Dependencies
- Mapping of ADaM datasets to source SDTM domains
- Explanation of data flow and transformations
- External data sources (if any)

### Section 6: Special Variables and Derivations
- Complex derivation algorithms
- RECIST 1.1 response criteria implementation
- Time-to-event censoring rules
- Imputation methods

### Section 7: Program Inventory
- Complete list of all derivation programs
- Program names, descriptions, and purposes
- Input/output datasets for each program
- QC program listing

## Directory Structure

```
regulatory_submission/adrg/
├── README_ADRG.md                    # This file
├── ADRG_STUDY001_template.md        # Main ADRG document
├── sections/
│   ├── 01_introduction.md
│   ├── 02_protocol_description.md
│   ├── 03_analysis_datasets.md       # Dataset descriptions
│   ├── 04_adam_conformance.md
│   ├── 05_data_dependencies.md
│   ├── 06_special_variables.md       # Derivation algorithms
│   └── 07_program_inventory.md       # Program listing
└── appendices/
    ├── A_adam_specification_summary.xlsx
    └── B_derivation_algorithms.md
```

## Connection to Repository

This ADRG template is directly linked to the repository structure:

### Program Inventory (Section 7)
References actual programs in:
- `etl/adam/` - ADaM derivation programs
- `etl/adam_r_admiral/` - R/admiral implementations
- `qc/r/adam/` - QC programs
- `sas/adam/` - SAS derivation programs (if applicable)

### Dataset Descriptions (Section 3)
Describes datasets generated in:
- `outputs/adam/` - ADSL, ADRS, ADTTE, etc.

### Derivation Algorithms (Section 6)
Documents code from:
- `etl/adam_program_library/oncology_response/` - RECIST 1.1 derivations
- `etl/adam_program_library/time_to_event/` - TTE endpoints
- `etl/adam_program_library/safety_standards/` - Safety parameters

## Creating the ADRG

### Step 1: Review Template
Start with `ADRG_STUDY001_template.md` and customize for your study

### Step 2: Populate Each Section
Use the individual section files in `sections/` as starting points

### Step 3: Document Derivations
For Section 6, reference actual code and algorithms:
```markdown
## RECIST 1.1 Best Overall Response

Best Overall Response (BOR) is derived using the algorithm implemented in:
`etl/adam_program_library/oncology_response/derive_bor.R`

Key rules:
- CR requires confirmation at ≥28 days
- PR requires confirmation at ≥28 days
- SD requires minimum duration of 42 days from baseline
```

### Step 4: Create Program Inventory
Generate automatically using:
```r
# List all programs with descriptions
source("automation/generate_program_inventory.R")
```

### Step 5: Convert to PDF
For submission, convert markdown to PDF:
```bash
pandoc ADRG_STUDY001_template.md -o ADRG_STUDY001.pdf
```

## Validation Checklist

- [ ] All 7 sections complete
- [ ] Dataset descriptions match actual ADaM datasets in `outputs/adam/`
- [ ] Program inventory matches actual files in repository
- [ ] Derivation algorithms documented with code references
- [ ] SDTM-to-ADaM traceability documented
- [ ] ADaM conformance self-assessment completed
- [ ] Cross-references to define.xml included
- [ ] Version control information included

## Resources

### Templates and Guidance
- [PHUSE ADaRG Template v1.2](https://advance.hub.phuse.global/wiki/spaces/WEL/pages/26804660/Analysis+Data+Reviewer+s+Guide+ADRG+Package)
- [FDA Guidance on Providing Electronic Submissions](https://www.fda.gov/media/88173/download)
- [ADaM Implementation Guide v1.3](https://www.cdisc.org/standards/foundational/adam)

### Examples
- See `ADRG_STUDY001_template.md` for a complete working example
- Real submission examples available on FDA website (search for "ADRG" in study data technical documents)

## Tips for Lead Programmers

1. **Start Early**: Begin ADRG development during SAP finalization, not at submission time
2. **Maintain Throughout**: Update ADRG as derivation logic evolves during development
3. **Link to Code**: Use explicit references to program names and line numbers
4. **Version Control**: Keep ADRG in Git alongside code for synchronized updates
5. **Peer Review**: Have biostatisticians review for accuracy and completeness
6. **Regulatory Perspective**: Write for reviewers who may not have SAS/R access

## Common Pitfalls to Avoid

- **Generic Descriptions**: Avoid boilerplate text; be specific to your study
- **Missing Derivations**: Document ALL complex algorithms, not just "interesting" ones
- **Outdated Inventory**: Ensure program listing exactly matches final code repository
- **Incomplete Traceability**: Every ADaM variable should trace back to SDTM or protocol
- **Format Inconsistency**: Use consistent terminology with define.xml and SAP

## Support

For questions about ADRG creation:
1. Review PHUSE ADaRG template and examples
2. Consult FDA guidance documents
3. Review example ADRGs from public submissions
4. Seek input from regulatory affairs and biostatistics teams
