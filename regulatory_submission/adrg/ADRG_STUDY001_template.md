# Analysis Data Reviewer's Guide (ADRG)
## STUDY001: Phase III Randomized Trial

**Study Title**: [Insert full study title]
**Protocol Number**: STUDY001
**Sponsor**: [Sponsor Name]
**Data Cut-Off Date**: 2025-06-30
**eCTD Location**: Module 5.3.5.3
**ADRG Version**: 1.0
**Date**: 2025-12-10

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Protocol Description](#2-protocol-description)
3. [Analysis Datasets](#3-analysis-datasets)
4. [ADaM Conformance](#4-adam-conformance)
5. [Data Dependencies](#5-data-dependencies)
6. [Special Variables and Derivations](#6-special-variables-and-derivations)
7. [Program Inventory](#7-program-inventory)

---

## 1. Introduction

### 1.1 Purpose

This Analysis Data Reviewer's Guide (ADRG) provides detailed information about the Analysis Data Model (ADaM) datasets submitted for STUDY001. The ADRG facilitates regulatory review by documenting dataset structures, derivation methods, and traceability to source data.

### 1.2 Scope

This ADRG covers the following ADaM datasets:
- **ADSL**: Subject-Level Analysis Dataset (n=850 subjects)
- **ADRS**: Response Analysis Dataset (tumor assessments per RECIST 1.1)
- **ADTTE**: Time-to-Event Analysis Dataset (PFS, OS endpoints)

All datasets conform to CDISC ADaM Implementation Guide version 1.3.

### 1.3 Related Documents

- **Define.xml**: `define_adam_v2.xml` (located in same eCTD module)
- **Statistical Analysis Plan (SAP)**: Version 2.0, dated 2024-09-15
- **Protocol**: Version 3.0, dated 2023-11-01
- **SDTM Define.xml**: Module 5.3.5.4

### 1.4 Software Environment

**Primary Analysis**:
- R version 4.3.0
- admiral package 0.12.0 (pharmaverse)
- Additional packages: dplyr, lubridate, survival

**Quality Control**:
- Independent R-based QC using admiral
- 100% dataset concordance achieved

---

## 2. Protocol Description

### 2.1 Study Design

**Design**: Multicenter, randomized, double-blind, placebo-controlled Phase III trial

**Population**: Adult patients with advanced solid tumors who progressed after standard therapy

**Randomization**: 2:1 ratio (Treatment:Placebo), stratified by:
- Prior lines of therapy (1 vs 2+)
- ECOG performance status (0 vs 1)

**Sample Size**: 850 patients planned
- Treatment Arm: ~567 patients
- Placebo Arm: ~283 patients

### 2.2 Treatment Arms

- **Treatment Arm**: Investigational drug 200mg PO daily
- **Placebo Arm**: Matched placebo PO daily

Treatment continued until disease progression, unacceptable toxicity, or withdrawal.

### 2.3 Key Endpoints

**Primary Endpoint**:
- Progression-Free Survival (PFS) per RECIST 1.1

**Secondary Endpoints**:
- Overall Response Rate (ORR)
- Duration of Response (DoR)
- Overall Survival (OS)
- Safety and tolerability

### 2.4 Assessments

**Tumor Assessments**:
- CT/MRI scans every 8 weeks (±7 days)
- Assessed per RECIST 1.1 by independent radiology review
- Response confirmation required at ≥28 days

**Safety Assessments**:
- Adverse events (continuous monitoring)
- Laboratory tests (baseline, then every 4 weeks)
- Vital signs (each visit)

---

## 3. Analysis Datasets

### 3.1 ADSL - Subject-Level Analysis Dataset

**Purpose**: One record per subject with demographics, treatment information, and population flags

**Structure**: Basic Data Structure (BDS) - Subject-Level

**Key Variables**:
- **Identifiers**: STUDYID, USUBJID, SUBJID, SITEID
- **Demographics**: AGE, AGEGR1, SEX, RACE, ETHNIC
- **Treatment**: TRT01P, TRT01A, TRTSDTM, TRTEDTM
- **Population Flags**: SAFFL, ITTFL, PPSFL
- **Stratification**: PRIORLNS (prior lines), ECOG0V1
- **Baseline Disease**: BMMTR1 (baseline tumor measurements)

**Record Count**: 850 subjects

**Source**: Derived from SDTM domains DM, EX, DS

**Program**: `etl/adam_r_admiral/programs/ad_adsl.R`

### 3.2 ADRS - Response Analysis Dataset

**Purpose**: Tumor response assessments and derived endpoints (BOR, ORR, DoR)

**Structure**: Basic Data Structure (BDS) - Occurrence Data

**Key Variables**:
- **Analysis Parameter**: PARAMCD, PARAM
  - `OVR`: Overall Response at each visit
  - `BOR`: Best Overall Response
  - `CONF`: Confirmed Response
  - `ORR`: Objective Response Rate (derived flag)
- **Analysis Value**: AVALC (CR, PR, SD, PD, NE)
- **Timing**: ADT, ADTM, ADY, AVISIT
- **Baseline**: BASEC, BASE
- **Confirmation**: CONFDT (confirmation date for CR/PR)

**Record Count**: ~6,800 records (850 subjects × ~8 assessments)

**Source**: Derived from SDTM RS (Response) domain

**Program**: `etl/adam_r_admiral/programs/ad_adrs.R`

### 3.3 ADTTE - Time-to-Event Analysis Dataset

**Purpose**: Time-to-event endpoints with event/censoring indicators

**Structure**: Basic Data Structure (BDS) - Time-to-Event

**Key Variables**:
- **Analysis Parameter**: PARAMCD, PARAM
  - `PFS`: Progression-Free Survival
  - `OS`: Overall Survival
  - `TTPR`: Time to Response
- **Analysis Value**: AVAL (time in days), AVALU ("DAYS")
- **Event Indicator**: CNSR (0=event, 1=censored)
- **Event Detail**: EVNTDESC, CNSDTDSC
- **Start Date**: STARTDT, STARTDTM

**Record Count**: 2,550 records (850 subjects × 3 parameters)

**Source**: Derived from ADRS (for PFS) and DS, AE (for OS)

**Program**: `etl/adam_r_admiral/programs/ad_adtte.R`

---

## 4. ADaM Conformance

### 4.1 Conformance Self-Assessment

All analysis datasets conform to CDISC ADaM Implementation Guide v1.3:

✓ All required variables present (STUDYID, USUBJID, etc.)
✓ Variable names comply with ADaM conventions
✓ Variable labels ≤40 characters
✓ Analysis flags use "Y"/"N"/null pattern
✓ Traceability variables included (--SEQ, --DTC)
✓ One dataset = one analysis purpose
✓ Structure clearly documented (ADSL vs BDS)

### 4.2 Deviations from ADaM IG

None. All datasets fully conform to ADaM IG v1.3.

---

## 5. Data Dependencies

### 5.1 SDTM to ADaM Traceability

#### ADSL Dependencies
```
SDTM Domain → ADSL Variables
DM          → STUDYID, USUBJID, AGE, SEX, RACE, ETHNIC, RFSTDTC, DTHFL
EX          → TRT01P, TRT01A, TRTSDTM, TRTEDTM, TRTEDT
DS          → EOSSTT, DCSREAS (disposition status)
RS          → BMMTR1 (baseline tumor measurement)
```

#### ADRS Dependencies
```
SDTM Domain → ADRS Variables
RS          → PARAMCD, AVALC (response assessments)
ADSL        → All subject-level variables merged
TR          → Tumor measurements (for confirmation logic)
```

#### ADTTE Dependencies
```
Source      → ADTTE Variables
ADRS        → PFS event dates (progression dates)
DS          → PFS censoring (treatment discontinuation)
ADSL        → Subject-level baseline and treatment info
```

### 5.2 External Data Sources

No external data sources used. All analysis data derived from SDTM domains collected in the study.

---

## 6. Special Variables and Derivations

### 6.1 RECIST 1.1 Best Overall Response (BOR)

**Implementation**: Implemented using `admiral::derive_extreme_event()` with RECIST 1.1 rules

**Algorithm**:
1. **CR (Complete Response)**: All target lesions disappeared AND all non-target lesions disappeared AND no new lesions
   - Requires confirmation ≥28 days later
2. **PR (Partial Response)**: ≥30% decrease in sum of target lesion diameters AND no new lesions
   - Requires confirmation ≥28 days later
3. **SD (Stable Disease)**: Neither PR nor PD criteria met, minimum duration 42 days from baseline
4. **PD (Progressive Disease)**: ≥20% increase in sum of diameters (and ≥5mm absolute increase) OR new lesions

**Code Reference**: `etl/adam_program_library/oncology_response/recist_11_macros.R` lines 45-120

**Confirmation Logic**:
```r
# Simplified example
confirmed_response <- rs_data %>%
  filter(AVALC %in% c("CR", "PR")) %>%
  group_by(USUBJID) %>%
  mutate(
    NEXT_ADT = lead(ADT),
    DAYS_TO_CONF = as.numeric(NEXT_ADT - ADT),
    CONFIRMED = if_else(DAYS_TO_CONF >= 28 & lead(AVALC) == AVALC, "Y", "N")
  )
```

### 6.2 Progression-Free Survival (PFS)

**Definition**: Time from randomization to disease progression or death from any cause, whichever occurs first

**Event Definition**:
- **Event (CNSR=0)**: Documented disease progression per RECIST 1.1 OR death
- **Censored (CNSR=1)**: No progression or death observed

**Censoring Rules**:
1. **Last adequate assessment**: Censored at date of last tumor assessment showing no progression
2. **New anti-cancer therapy**: Censored at date of last assessment before new therapy
3. **Withdrew consent**: Censored at date of withdrawal
4. **Lost to follow-up**: Censored at last known alive date

**Code Reference**: `etl/adam_program_library/time_to_event/derive_pfs.R`

### 6.3 Baseline Tumor Measurements (BMMTR1)

**Derivation**: Sum of target lesion diameters at baseline per RECIST 1.1

**Source**: SDTM TR domain where TRLNKID = "TARGET" and VISIT = "BASELINE"

**Code**:
```r
baseline_tumor <- tr %>%
  filter(TRLNKID == "TARGET", VISIT == "BASELINE") %>%
  group_by(USUBJID) %>%
  summarise(BMMTR1 = sum(TRDIAM, na.rm = TRUE))
```

---

## 7. Program Inventory

### 7.1 ADaM Derivation Programs

| Program Name | Purpose | Input Datasets | Output Datasets | QC Program |
|--------------|---------|----------------|-----------------|------------|
| `ad_adsl.R` | Derive subject-level dataset | DM, EX, DS, RS | ADSL | `qc_adam_adsl.R` |
| `ad_adrs.R` | Derive response dataset | RS, TR, ADSL | ADRS | `qc_adam_adrs.R` |
| `ad_adtte.R` | Derive time-to-event dataset | ADRS, DS, ADSL | ADTTE | `qc_adam_adtte.R` |

### 7.2 Derivation Library Programs

| Program Name | Purpose | Called By |
|--------------|---------|----------|
| `recist_11_macros.R` | RECIST 1.1 response derivations | `ad_adrs.R` |
| `derive_pfs.R` | PFS endpoint derivation | `ad_adtte.R` |
| `baseline_functions.R` | Baseline value derivations | All ADaM programs |

### 7.3 QC Programs

| QC Program | Validates | Method | Status |
|------------|-----------|--------|--------|
| `qc_adam_adsl.R` | ADSL | Independent R derivation | 100% match |
| `qc_adam_adrs.R` | ADRS | Independent R derivation | 100% match |
| `qc_adam_adtte.R` | ADTTE | Independent R derivation | 100% match |

### 7.4 Program Execution Order

1. SDTM datasets (input)
2. `ad_adsl.R` → ADSL
3. `ad_adrs.R` → ADRS (requires ADSL)
4. `ad_adtte.R` → ADTTE (requires ADRS, ADSL)
5. QC programs (parallel validation)

**Master Script**: `run_all.R` executes all programs in correct dependency order

---

## Appendices

### Appendix A: Dataset Specifications

See `regulatory_submission/adrg/appendices/A_adam_specification_summary.xlsx` for complete variable-level specifications.

### Appendix B: Detailed Derivation Algorithms

See `regulatory_submission/adrg/appendices/B_derivation_algorithms.md` for step-by-step derivation pseudocode.

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|----------|
| 1.0 | 2025-12-10 | Programming Team | Initial version for submission |

---

**End of ADRG**
