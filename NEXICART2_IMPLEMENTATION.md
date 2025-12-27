# NEXICART-2 AL Amyloidosis Implementation Guide

## Overview

This document provides complete implementation instructions for NEXICART-2 AL amyloidosis CAR-T cell therapy trial updates to the sas-r-hybrid-clinical-pipeline repository.

**Study**: NEXICART-2 - Single-arm, multi-center trial evaluating autologous anti-BCMA CAR-T cells in relapsed/refractory AL amyloidosis

**Branch**: `feature/nexicart-2-al-amyloidosis-domains`

**Key Endpoints**:
- Primary: Overall hematologic response rate (dFLC reduction)
- Key Secondary: MRD negativity at 10^-6 sensitivity, Cardiac response (60% patients with cardiac involvement)
- Safety: CRS/ICANS, infections, manufacturing failures

---

## Phase 1: Critical Missing Domains ✅ COMPLETE

**Estimated Time**: 12-18 hours

### 1.1 PR (Procedures) Domain

**File Created**: `sdtm/programs/sas/48_sdtm_pr.sas`

**Purpose**: Tracks critical procedures for efficacy and safety assessment

**Key Features**:
- MRD assessment by flow cytometry (10^-5 and 10^-6 sensitivity levels)
- Echocardiography parameters (LVEF, wall thickness, strain)
- CAR-T manufacturing flow (apheresis → CAR-T infusion)
- Cytogenetic abnormalities [t(11;14), gain 1q, del(17p)]

**Procedures Tracked**:
| Category | PRTESTCD | PRTEST | Method |
|----------|----------|--------|--------|
| Bone Marrow | BMBIOPSY | Bone Marrow Biopsy | - |
| Bone Marrow | MRDFLOW5 | MRD (10^-5) | Multicolor Flow Cytometry |
| Bone Marrow | MRDFLOW6 | MRD (10^-6) | Multicolor Flow Cytometry |
| Cardiac | LVEF | LV Ejection Fraction | Biplane Simpson |
| Cardiac | WALLTHK | LV Wall Thickness | - |
| Cardiac | STRAIN | Global Longitudinal Strain | Speckle Tracking Echo |
| CAR-T Therapy | APHERESIS | Leukapheresis | - |
| CAR-T Therapy | CARTINF | CAR-T Infusion | - |
| Cytogenetics | T1114 | t(11;14) Status | FISH |
| Cytogenetics | GAIN1Q | Gain 1q Status | FISH |
| Cytogenetics | DEL17P | del(17p) Status | FISH |

**Input Template**: `sdtm/data/raw/procedures_raw.csv`

**Outputs**: 
- `sdtm/data/csv/pr.csv`
- `sdtm/data/xpt/pr.xpt`
- `logs/48_sdtm_pr.log`

**QC Checks**:
- MRD negativity rates by sensitivity level
- LVEF distribution at baseline vs follow-up
- CAR-T manufacturing completion rate (apheresis → infusion)
- Cytogenetic abnormality prevalence

---

### 1.2 DD (Death Details) Domain

**File Created**: `sdtm/programs/sas/50_sdtm_dd.sas`

**Purpose**: Regulatory-compliant death reporting with causality assessment

**Key Features**:
- Death cause (verbatim and MedDRA coded)
- Relationship to CAR-T therapy (NOT RELATED → RELATED)
- Autopsy performed flag and findings
- Disease category standardization

**Death Categories Standardized**:
- PROGRESSIVE AL AMYLOIDOSIS
- CARDIAC FAILURE
- RENAL FAILURE
- INFECTION
- CYTOKINE RELEASE SYNDROME
- OTHER

**Input Template**: `sdtm/data/raw/death_details_raw.csv` (empty by default)

**Outputs**: 
- `sdtm/data/csv/dd.csv`
- `sdtm/data/xpt/dd.xpt`
- `logs/50_sdtm_dd.log`

**Special Handling**: Creates empty domain structure if no deaths occur

---

## Phase 2: Laboratory Domain Expansion 🚧 IN PROGRESS

**Estimated Time**: 12-18 hours

### 2.1 Enhanced LB Domain

**File to Update**: `sdtm/programs/sas/42_sdtm_lb.sas`

**New Biomarker Categories**:
| LBCAT | Test Codes | Clinical Significance |
|-------|------------|----------------------|
| SERUM FREE LIGHT CHAINS | KAPPA, LAMBDA, DFLC | Primary efficacy endpoint |
| CARDIAC BIOMARKERS | NTPROBNP, TROPHS, TROPNI | Cardiac response assessment |
| RENAL FUNCTION | PROT24H, UPROT, EGFR, CREAT | Organ involvement tracking |
| CAR-T PHARMACOKINETICS | CARTPK, CARTCMAX, CARTTMAX | CAR-T expansion monitoring |
| CYTOKINE PANEL | IL6, IL10, IFNG, TNF | CRS prediction/monitoring |
| IMMUNOFIXATION | SIF, UIF | Hematologic response |
| B-CELL RECOVERY | CD19POS | B-cell aplasia tracking |

### 2.2 Derived dFLC Calculation

**Critical Formula**: 
```
dFLC = involved FLC - uninvolved FLC

If lambda light chain type:
  dFLC = LAMBDA - KAPPA
  
If kappa light chain type:
  dFLC = KAPPA - LAMBDA
```

**Complete Response Threshold**: dFLC < 4 mg/dL

**Implementation Location**: After main LB dataset creation, before baseline flag derivation

**Input Template**: `sdtm/data/raw/lab_results_raw.csv` ✅ Created

**Required Metadata**: Light chain type must be stored in DM or MH domain (LIGHT_CHAIN_TYPE variable)

**QC Validations**:
- Manual verification of dFLC calculation for first 10 subjects
- Baseline dFLC distribution summary
- NT-proBNP baseline vs follow-up for cardiac response
- Biomarker completeness by category

---

## Phase 3: Demographics Enhancement 📋 PENDING

**Estimated Time**: 8-12 hours

**File to Update**: `sdtm/programs/sas/20_sdtm_dm.sas`

**New Baseline Characteristics to Add**:

### Prior Treatment History
- `NPRTLIN`: Number of prior lines of therapy (median 4, range 1-12)
- `PRBORT`: Prior bortezomib exposure (Y/N) - 100% in NEXICART-2
- `PRDARATU`: Prior daratumumab exposure (Y/N) - 100%
- `PRASCT`: Prior autologous stem cell transplant (Y/N) - 50%
- `PRLMWCLS`: Triple-class exposed (PI/IMiD/anti-CD38) (Y/N)

### Light Chain Type and Cytogenetics
- `LCHTYPEC`: Light chain type (LAMBDA/KAPPA)
- `CYTT1114`: t(11;14) present (Y/N)
- `CYTG1Q`: Gain 1q present (Y/N)
- `CYTD17P`: del(17p) present (Y/N)

### Baseline Organ Involvement
- `CRDBASEF`: Cardiac involvement (Y/N) - 60% expected
- `RENBASF`: Renal involvement (Y/N)
- `HEPBASF`: Hepatic involvement (Y/N)
- `NEUROBASF`: Peripheral neuropathy (Y/N)
- `NORGINV`: Number of organs involved (derived)

### Disease Severity Staging
- `MAYOSTGB`: Mayo cardiac stage (I/II/IIIA/IIIB)
- `NYHACALB`: NYHA heart failure class (I/II/III/IV)

### Baseline Disease Burden
- `DFCLCBL`: Baseline dFLC (mg/dL)
- `NTPROBNPB`: Baseline NT-proBNP (ng/L)
- `TROPBL`: Baseline troponin (ng/mL)
- `PROTBL`: Baseline 24h proteinuria (g/24h)

---

## Phase 4: Adverse Events Enhancement 📋 PENDING

**File to Update**: `sdtm/programs/sas/30_sdtm_ae.sas`

**CAR-T Specific Toxicity Tracking**:
- CRS grading (Lee 2019 criteria)
- ICANS grading (ASTCT consensus)
- Infection categorization
- Cytopenias

---

## Phase 5: Exposure Domain Enhancement 📋 PENDING

**File to Update**: `sdtm/programs/sas/38_sdtm_ex.sas`

**CAR-T Dosing Details**:
- CAR+ T cell dose (actual cells infused)
- Manufacturing success/failure
- Bridging therapy during manufacturing

---

## Phase 6: Response Assessment Domain 📋 PENDING

**File to Update**: `sdtm/programs/sas/54_sdtm_rs.sas`

**AL Amyloidosis Response Criteria**:
- Hematologic response (CR/VGPR/PR/NR)
- Cardiac response
- Renal response
- Hepatic response

---

## Integration Instructions

### Prerequisites
1. Ensure `sdtm/data/csv/dm.csv` exists with RFSTDTC for all subjects
2. Create directory structure:
   ```
   sdtm/data/raw/     (for input CSVs)
   sdtm/data/csv/     (for SDTM outputs)
   sdtm/data/xpt/     (for transport files)
   logs/              (for SAS logs)
   ```

### Running the Programs

**Phase 1 Programs**:
```sas
/* Run in this order */
%include 'sdtm/programs/sas/48_sdtm_pr.sas';
%include 'sdtm/programs/sas/50_sdtm_dd.sas';
```

**Phase 2 Updates**: 
1. Backup existing `42_sdtm_lb.sas`
2. Apply code insertions as documented
3. Run updated LB program

### Validation Checkpoints

After each phase:
1. Review SAS log for ERRORs and WARNINGs
2. Verify record counts match expectations
3. Run QC frequency tables
4. Check data completeness reports

### Expected Record Counts (7 Subjects)

| Domain | Records | Subjects |
|--------|---------|----------|
| PR     | ~70-100 | 7 |
| DD     | 0-10    | 0-2 |
| LB     | ~500-700 | 7 |

---

## Key Study Design Features

**Patient Population**:
- Relapsed/refractory AL amyloidosis
- Median 4 prior lines (range 1-12)
- 100% bortezomib and daratumumab exposed
- 60% with cardiac involvement
- Mayo stage: I (0%), II (29%), IIIA (57%), IIIB (14%)

**Primary Endpoint**: Overall hematologic response rate
- CR: dFLC <4 mg/dL + negative immunofixation
- VGPR: dFLC <4 mg/dL or >90% reduction
- PR: >50% dFLC reduction

**Key Secondary Endpoints**:
- MRD negativity (10^-6): 2/7 patients (29%)
- Cardiac response: Defined by NT-proBNP >30% reduction + NYHA class improvement
- Safety: CRS, ICANS, infections

**Manufacturing**:
- Median manufacturing time: 16 days
- Manufacturing success: 100% (7/7)

---

## Next Steps

1. ✅ Phase 1 complete - PR and DD domains created
2. 🔄 Complete Phase 2 - Update 42_sdtm_lb.sas with dFLC calculation
3. ⏳ Phase 3 - Enhance 20_sdtm_dm.sas with baseline characteristics
4. ⏳ Phases 4-6 - Update AE, EX, RS domains

---

## Questions or Issues?

Contact: Christian Baghai
Date: 2025-12-27
