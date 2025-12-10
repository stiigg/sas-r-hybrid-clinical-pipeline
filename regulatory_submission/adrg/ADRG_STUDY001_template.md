# Analysis Data Reviewer's Guide (ADRG)

**Study**: STUDY001 - A Phase III Randomized Trial Comparing Treatment vs Placebo in Patients with Advanced Solid Tumors

**Sponsor**: [Company Name]

**Protocol Number**: STUDY001

**ADRG Version**: 1.0

**Date**: 2025-12-10

**ADaM Version**: ADaM Implementation Guide v1.3

**SDTM Version**: SDTM Implementation Guide v3.4

---

## Document Control

| Version | Date | Author | Description of Changes |
|---------|------|--------|------------------------|
| 1.0 | 2025-12-10 | Clinical Programming Team | Initial version for demonstration portfolio |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Protocol Description](#2-protocol-description)
3. [Analysis Datasets](#3-analysis-datasets)
4. [ADaM Conformance](#4-adam-conformance)
5. [Data Dependencies and Flow](#5-data-dependencies-and-flow)
6. [Special Variables and Algorithms](#6-special-variables-and-algorithms)
7. [Program Inventory](#7-program-inventory)

**Appendices**
- Appendix A: ADaM Specification Summary
- Appendix B: Derivation Algorithms

---

# 1. Introduction

## 1.1 Purpose of This Document

This Analysis Data Reviewer's Guide (ADRG) provides comprehensive documentation of the analysis datasets created for STUDY001. It is intended to:

- Assist regulatory reviewers in understanding the structure, content, and derivation of analysis datasets
- Provide traceability between analysis datasets (ADaM) and source data (SDTM)
- Document complex derivation algorithms and special processing logic
- Serve as a reference for dataset specifications and programming details

This ADRG follows the PHUSE template structure and incorporates recommendations from the FDA Study Data Technical Conformance Guide.

## 1.2 Study Overview

STUDY001 is a Phase III, randomized, double-blind, placebo-controlled trial evaluating the efficacy and safety of an investigational oncology treatment in patients with advanced solid tumors.

**Key Study Characteristics**:
- **Design**: Randomized (1:1), double-blind, placebo-controlled
- **Population**: Adults with advanced solid tumors, ECOG 0-1
- **Sample Size**: 850 subjects randomized
- **Treatment Arms**:
  - Arm A: Investigational Treatment (n=425)
  - Arm B: Placebo (n=425)
- **Primary Endpoint**: Progression-Free Survival (PFS) per RECIST 1.1
- **Key Secondary Endpoints**:
  - Overall Survival (OS)
  - Objective Response Rate (ORR)
  - Duration of Response (DoR)
  - Safety and tolerability

## 1.3 Document Organization

This ADRG is organized into seven main sections:

- **Section 2** describes the clinical trial protocol and key design elements
- **Section 3** provides detailed descriptions of each ADaM dataset
- **Section 4** documents conformance to CDISC ADaM standards
- **Section 5** maps data flow from SDTM to ADaM datasets
- **Section 6** explains special variables and complex derivation algorithms
- **Section 7** inventories all programs used to create analysis datasets

Appendices provide supplementary information including detailed specifications and algorithm pseudocode.

## 1.4 Software Environment

Analysis datasets for STUDY001 were created using R with the **admiral** package from the pharmaverse ecosystem.

**Primary Software**:
- **R Version**: 4.3.0 (2023-04-21)
- **Operating System**: Linux Ubuntu 22.04.1 LTS
- **Key Packages**:
  - admiral 0.12.0 (ADaM derivations)
  - metacore 0.1.0 (metadata management)
  - metatools 0.1.0 (metadata-driven programming)
  - xportr 0.3.0 (XPT transport file generation)
  - dplyr 1.1.2 (data manipulation)
  - lubridate 1.9.2 (date/time handling)

**Reproducibility**: Complete package versions are captured in `renv.lock` file in the repository root.

**Validation**: R packages used in production have been qualified according to company SOPs. Validation evidence is maintained in `validation/package_validation/`.

## 1.5 Submission Package Contents

The ADaM analysis datasets for STUDY001 are submitted in **eCTD Module 5.3.5.3** and include:

- **Analysis Datasets** (SAS XPT v5 format):
  - adsl.xpt - Subject-Level Analysis Dataset
  - adrs.xpt - Response Analysis Dataset
  - adtte.xpt - Time-to-Event Analysis Dataset

- **Metadata Documentation**:
  - define.xml (Define-XML v2.1)
  - This ADRG (PDF)

- **Supplementary Materials**:
  - Dataset specifications (referenced in define.xml)
  - Controlled terminology (CDISC CT 2023-09-29)

All datasets conform to CDISC ADaM Implementation Guide v1.3 and have been validated using Pinnacle 21 Community (results in validation reports).

---

# 2. Protocol Description

*[See sections/02_protocol_description.md for detailed content]*

Key protocol elements affecting analysis dataset creation:

- **Randomization stratification**: Prior lines of therapy (1 vs 2+), ECOG (0 vs 1)
- **Response assessments**: Every 8 weeks per RECIST 1.1
- **Primary analysis**: PFS at 350 events using Kaplan-Meier and Cox regression
- **Safety population**: All subjects receiving ≥1 dose of study treatment
- **ITT population**: All randomized subjects

---

# 3. Analysis Datasets

*[See sections/03_analysis_datasets.md for detailed content]*

## 3.1 Dataset Summary

| Dataset | Structure | Records | Variables | Description |
|---------|-----------|---------|-----------|-------------|
| ADSL | Subject-Level | 850 | 45 | Demographics, baseline, treatment, populations |
| ADRS | BDS (Occurrence) | 7,650 | 38 | Tumor response per RECIST 1.1 |
| ADTTE | BDS (TTE) | 2,550 | 35 | Time-to-event endpoints (PFS, OS) |

## 3.2 Dataset Relationships

All analysis datasets link via:
- **STUDYID** = "STUDY001" (constant)
- **USUBJID** = Unique subject identifier (STUDYID-SITEID-SUBJID format)

ADRS and ADTTE reference ADSL for baseline characteristics and population flags.

---

# 4. ADaM Conformance

*[See sections/04_adam_conformance.md for detailed content]*

## 4.1 ADaM Principles Compliance

STUDY001 analysis datasets adhere to ADaM fundamental principles:

✅ **Principle 1**: One dataset per analysis subject (ADSL)
✅ **Principle 2**: Traceability to SDTM (documented in Section 5)
✅ **Principle 3**: Analysis-ready values (AVAL, AVALC derived)
✅ **Principle 4**: Clear variable naming and labeling
✅ **Principle 5**: Standard variables where applicable
✅ **Principle 6**: Metadata in define.xml

## 4.2 CDISC Standards Used

- **ADaM IG Version**: 1.3 (June 2021)
- **SDTM IG Version**: 3.4 (November 2022)
- **Controlled Terminology**: CDISC CT 2023-09-29
- **Define-XML Version**: 2.1

---

# 5. Data Dependencies and Flow

*[See sections/05_data_dependencies.md for detailed content]*

## 5.1 SDTM to ADaM Traceability

```
SDTM Datasets           ADaM Datasets

DM (Demographics)   ─┐
EX (Exposure)       ─┼─→  ADSL (Subject-Level)
DS (Disposition)    ─┘

RS (Response)       ─┐
TR (Tumor Results)  ─┼─→  ADRS (Response Analysis)
ADSL               ─┘

ADRS (Progression)  ─┐
DS (Disposition)    ─┼─→  ADTTE (Time-to-Event)
AE (Death dates)    ─┤
ADSL               ─┘
```

---

# 6. Special Variables and Algorithms

*[See sections/06_special_variables.md for detailed content]*

Key complex derivations documented:

- **RECIST 1.1 Best Overall Response (BOR)** - Algorithm from Eisenhauer et al. 2009
- **Response confirmation** - CR/PR confirmed at ≥28 days
- **Progression-Free Survival (PFS)** - Time to progression or death with censoring rules
- **Overall Survival (OS)** - Time to death from any cause
- **Population flags** - SAFFL, ITTFL, PPSFL derivation logic

---

# 7. Program Inventory

*[See sections/07_program_inventory.md for detailed content]*

All programs are maintained in Git version control. Key programs:

- `etl/adam_r_admiral/programs/ad_adsl.R` - ADSL derivation
- `etl/adam_r_admiral/programs/ad_adrs.R` - ADRS derivation
- `etl/adam_r_admiral/programs/ad_adtte.R` - ADTTE derivation
- `qc/r/adam/qc_adam_*.R` - Independent QC programs

Complete program listings with inputs, outputs, and dependencies provided in Section 7.

---

# Appendices

## Appendix A: ADaM Specification Summary

*[See appendices/A_adam_specification_summary.xlsx]*

Excel workbook containing:
- Variable-level specifications for all datasets
- Value-level metadata for coded variables
- Derivation formulas and origins

## Appendix B: Derivation Algorithms

*[See appendices/B_derivation_algorithms.md]*

Detailed pseudocode for:
- RECIST 1.1 BOR algorithm
- PFS censoring rules
- Response confirmation logic
- Population flag derivations

---

**End of ADRG**

---

## Document Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Lead Programmer | | | |
| QC Programmer | | | |
| Biostatistician | | | |
| Data Manager | | | |

---

**Note**: This ADRG is part of a demonstration portfolio for clinical programming job applications. While it follows industry standards and best practices, it represents a mock study (STUDY001) and should be adapted for actual submission work.
