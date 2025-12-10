# Section 1: Introduction

## 1.1 Purpose

This Analysis Data Reviewer's Guide (ADRG) provides detailed information about the Analysis Data Model (ADaM) datasets submitted for **STUDY001** in support of [regulatory application type, e.g., New Drug Application (NDA), Biologics License Application (BLA)]. 

The ADRG is designed to:
- Facilitate regulatory review of analysis datasets
- Document the derivation of analysis variables and endpoints
- Demonstrate traceability from source SDTM data to analysis results
- Provide sufficient detail for reviewers to understand and verify analyses

## 1.2 Scope of Analysis Datasets

This ADRG covers the following ADaM datasets for STUDY001:

### Subject-Level Dataset
- **ADSL**: Subject-Level Analysis Dataset
  - One record per subject (n=850)
  - Demographics, treatment assignments, population flags

### Efficacy Datasets (BDS Structure)
- **ADRS**: Response Analysis Dataset
  - Tumor response assessments per RECIST 1.1
  - Best Overall Response (BOR), Objective Response Rate (ORR)
  - Confirmation logic for CR/PR responses
  
- **ADTTE**: Time-to-Event Analysis Dataset
  - Progression-Free Survival (PFS)
  - Overall Survival (OS)
  - Time to Response
  - Event and censoring indicators

### Safety Datasets (if applicable)
- **ADAE**: Adverse Event Analysis Dataset (if submitted)
- **ADLB**: Laboratory Analysis Dataset (if submitted)

All datasets conform to **CDISC ADaM Implementation Guide version 1.3**.

## 1.3 Related Documentation

This ADRG should be reviewed in conjunction with the following documents:

### Define.xml
- **File**: `define_adam_v2.xml` (located in same eCTD module)
- **Purpose**: Provides variable-level metadata, controlled terminology, and dataset structure
- **Version**: Define-XML v2.1

### Statistical Analysis Plan (SAP)
- **Version**: 2.0
- **Date**: 2024-09-15
- **Location**: eCTD Module 5.3.5.1
- **Purpose**: Describes planned statistical analyses and endpoints

### Clinical Study Protocol
- **Version**: 3.0 (with Amendments 1-2)
- **Date**: 2023-11-01
- **Location**: eCTD Module 5.3.5.1
- **Purpose**: Defines study design, endpoints, and assessments

### SDTM Documentation
- **SDTM Define.xml**: Located in eCTD Module 5.3.5.4
- **CSDRG**: Clinical Study Data Reviewer's Guide for SDTM datasets
- **Purpose**: Source data from which ADaM datasets are derived

## 1.4 Analysis Software Environment

All ADaM datasets were generated using the following validated software:

### Primary Derivation Environment
- **Software**: R version 4.3.0 (2023-04-21)
- **Platform**: x86_64-pc-linux-gnu (64-bit)
- **Operating System**: Linux Ubuntu 22.04.1 LTS

### Key R Packages (Pharmaverse)
- **admiral**: Version 0.12.0 - ADaM derivations and validations
- **metacore**: Version 0.1.0 - Metadata management
- **metatools**: Version 0.1.0 - Metadata-driven programming
- **pharmaversesdtm**: Version 0.2.0 - SDTM domain operations

### Supporting Packages
- **dplyr**: Version 1.1.2 - Data manipulation
- **lubridate**: Version 1.9.2 - Date/time handling
- **survival**: Version 3.5-5 - Time-to-event analyses
- **xportr**: Version 0.3.0 - XPT file generation and define.xml support

### Quality Control Environment
- **QC Method**: Independent R-based double programming using admiral
- **QC Software**: Same R version and packages as production
- **Validation Status**: 100% dataset concordance achieved between production and QC

### Version Control
- **System**: Git version 2.40.1
- **Repository**: Internal company GitLab instance
- **Submission Tag**: `submission-v1.0-2025-12-10`

## 1.5 Repository Structure

For reference, the analysis programs and datasets are organized as follows:

```
project/
├── etl/
│   ├── adam_r_admiral/
│   │   ├── programs/
│   │   │   ├── ad_adsl.R              # ADSL derivation
│   │   │   ├── ad_adrs.R              # ADRS derivation
│   │   │   └── ad_adtte.R             # ADTTE derivation
│   │   └── README_ADMIRAL.md       # Admiral workflow documentation
│   └── adam_program_library/
│       ├── oncology_response/     # RECIST 1.1 macros
│       ├── time_to_event/         # TTE endpoint derivations
│       └── safety_standards/      # Safety parameter derivations
├── qc/
│   └── r/adam/
│       ├── qc_adam_adsl.R         # ADSL QC program
│       ├── qc_adam_adrs.R         # ADRS QC program
│       └── qc_adam_adtte.R        # ADTTE QC program
├── outputs/adam/                   # Generated ADaM RDS files
└── regulatory_submission/
    ├── define_xml/outputs/         # XPT files for submission
    └── adrg/                       # This ADRG
```

See Section 7 (Program Inventory) for complete program listings and dependencies.

## 1.6 Data Standards Compliance

All analysis datasets comply with the following CDISC standards:

- **ADaM Implementation Guide**: Version 1.3 (June 2021)
- **ADaM Basic Data Structure (BDS)**: Used for ADRS and ADTTE
- **ADaM Subject-Level Analysis Dataset (ADSL)**: Used for subject-level data
- **CDISC Controlled Terminology**: Version 2023-12-15
- **Define-XML**: Version 2.1

Conformance to these standards is documented in Section 4 (ADaM Conformance).

## 1.7 Document Navigation

This ADRG is organized into seven main sections:

1. **Introduction** (this section) - Overview and scope
2. **Protocol Description** - Study design and endpoints
3. **Analysis Datasets** - Detailed dataset descriptions
4. **ADaM Conformance** - Compliance self-assessment
5. **Data Dependencies** - SDTM-to-ADaM traceability
6. **Special Variables** - Complex derivation documentation
7. **Program Inventory** - Complete program listings

Appendices provide supplementary specifications and algorithms.

---

**Note to Reviewers**: This ADRG is intended to be used alongside the define.xml file. For variable-level details (labels, types, formats), please refer to define_adam_v2.xml. This document focuses on dataset structures, derivation logic, and analysis considerations.
