# NEXICART-2 AL Amyloidosis Implementation Guide

## Overview

This document tracks the complete implementation of NEXICART-2 AL amyloidosis CAR-T cell therapy trial updates to the sas-r-hybrid-clinical-pipeline repository.

**Study**: NEXICART-2 - Single-arm, multi-center trial evaluating autologous anti-BCMA CAR-T cells in relapsed/refractory AL amyloidosis

**Branch**: `feature/nexicart-2-complete-implementation`

**Implementation Status**: Phase 2 Complete (Week 1 of 7)

**Key Endpoints**:
- Primary: Overall hematologic response rate per IMWG criteria (dFLC reduction)
- Key Secondary: MRD negativity at 10^-6 sensitivity, Cardiac response (NT-proBNP reduction)
- Safety: CRS/ICANS grading, infections, manufacturing failures

---

## Implementation Phases

### **Phase 1: Critical Missing Domains** ✅ COMPLETE

**Status**: ✅ Complete (from previous branch)
**Files**: 
- `sdtm/programs/sas/48_sdtm_pr.sas` - Procedures (MRD, echo, cytogenetics)
- `sdtm/programs/sas/50_sdtm_dd.sas` - Death details

---

### **Phase 2: Laboratory Domain with dFLC Calculation** ✅ COMPLETE

**Status**: ✅ Complete (2025-12-28)
**Implementation Time**: 3 hours

#### Files Created/Updated:

1. **Raw Data Template**: `sdtm/data/raw/lab_results_nexicart2.csv` ✅
   - 3 patients with realistic disease burden
   - Lambda-involved: NEXICART2-001, NEXICART2-003
   - Kappa-involved: NEXICART2-002
   - Baseline + 2 follow-up timepoints
   - 14 biomarkers per timepoint

2. **Enhanced LB Program**: `sdtm/programs/sas/42_sdtm_lb_nexicart2.sas` ✅
   - Complete dFLC calculation from paired FLC values
   - Light chain type (κ/λ) handling
   - FLC ratio derivation for sCR assessment
   - Clinical significance flags (HIGH, CS for critical values)
   - 7 new LBCAT categories:
     * SERUM FREE LIGHT CHAINS (KAPPA, LAMBDA, DFLC, FLCRATIO)
     * CARDIAC BIOMARKERS (NT-proBNP, troponin)
     * RENAL FUNCTION (proteinuria, eGFR, creatinine)
     * IMMUNOFIXATION (serum, urine)
     * CYTOKINE PANEL (IL-6, IL-10, IFN-γ)
     * B-CELL RECOVERY (CD19+ counts)
     * CAR-T PHARMACOKINETICS (CAR-T copies)

3. **QC Validation**: `qc/validate_dflc_calculation.sas` ✅
   - Independent dFLC recalculation
   - Production comparison with 0.1 mg/L tolerance
   - Automated PASS/FAIL flagging

#### Key Implementation Features:

**dFLC Calculation Algorithm**:
```sas
/* Determine involved vs uninvolved light chain */
if LCLCTYPE = 'λ' then do;
    involved_flc = lambda_val;
    uninvolved_flc = kappa_val;
end;
else if LCLCTYPE = 'κ' then do;
    involved_flc = kappa_val;
    uninvolved_flc = lambda_val;
end;

/* Calculate dFLC per ISA 2012 consensus */
dflc_value = involved_flc - uninvolved_flc;
```

**Clinical Thresholds Applied**:
- dFLC <40 mg/L → Complete Response threshold (LBNRIND = NORMAL)
- dFLC ≥180 mg/L → High-risk per Mayo 2012 (LBNRIND = HIGH, CS)
- NT-proBNP >8500 ng/L → Mayo Stage IIIB cutoff (LBNRIND = HIGH, CS)
- IL-6 >100 pg/mL → Grade 2+ CRS risk (LBNRIND = HIGH, CS)

**Quality Control Reports**:
1. ✅ dFLC manual verification for 3 patients
2. ✅ Baseline biomarker distribution
3. ✅ Biomarker completeness by visit
4. ✅ High-risk cardiac patient identification
5. ✅ Method consistency check (Freelite assay)

---

### **Phase 3: Demographics Enhancement** 📋 IN PROGRESS

**Status**: 🚧 Raw data created, program pending
**Target Completion**: Week 2 (2025-12-29)

#### Files Created:
- `sdtm/data/raw/demographics_nexicart2.csv` ✅

#### File to Update:
- `sdtm/programs/sas/20_sdtm_dm.sas` ⏳

#### Variables to Add:

**Prior Treatment History**:
- `NPRTLIN`: Number of prior lines (median 4)
- `PRBORT`: Prior bortezomib (100%)
- `PRDARATU`: Prior daratumumab (100%)
- `PRASCT`: Prior auto-SCT (50%)
- `PRLMWCLS`: Triple-class exposed

**Cytogenetics**:
- `CYTT1114`: t(11;14) status
- `CYTG1Q`: Gain 1q status
- `CYTD17P`: del(17p) status

**Organ Involvement**:
- `CRDBASEF`: Cardiac involvement (60%)
- `RENBASF`: Renal involvement
- `HEPBASF`: Hepatic involvement
- `NORGINV`: Number of organs (derived)

**Disease Severity**:
- `MAYOSTGB`: Mayo cardiac stage (I/II/IIIA/IIIB)
- `NYHACALB`: NYHA heart failure class

**Baseline Burden**:
- `DFCLCBL`: Baseline dFLC
- `NTPROBNPB`: Baseline NT-proBNP
- `TROPBL`: Baseline troponin
- `PROTBL`: Baseline proteinuria

---

### **Phase 4: CAR-T Specific AE Enhancements** 📋 PENDING

**Target Completion**: Week 5

**File to Update**: `sdtm/programs/sas/30_sdtm_ae.sas`

**Enhancements**:
- AECAT2 = 'CYTOKINE RELEASE SYNDROME'
- AECAT2 = 'ICANS'
- AECAT2 = 'INFECTION'
- AECAT2 = 'CYTOPENIA'
- AECAT2 = 'TUMOR LYSIS SYNDROME'

---

### **Phase 5: EX Domain CAR-T Manufacturing** 📋 PENDING

**Target Completion**: Week 6

**File to Update**: `sdtm/programs/sas/38_sdtm_ex_v2.sas`

**Enhancements**:
- Leukapheresis tracking
- CAR-T infusion with dose
- Vein-to-vein time calculation
- Manufacturing failure flags
- Bridging therapy documentation

---

### **Phase 6: IMWG Response Criteria (ADaM ADRS)** 📋 PENDING

**Target Completion**: Week 3-4
**Priority**: CRITICAL - Primary efficacy endpoint

**Files to Create**:
- `adam/programs/sas/60_adam_adlb_nexicart2.sas` ⏳
- `adam/programs/sas/70_adam_adrs_imwg.sas` ⏳

**IMWG Response Hierarchy** (7-tier):
1. **sCR** (Stringent CR): Negative IF + Normal FLC ratio + BM <5% plasma cells
2. **CR** (Complete Response): Negative IF + dFLC <40 mg/L
3. **VGPR** (Very Good PR): dFLC <40 mg/L OR ≥90% reduction
4. **PR** (Partial Response): ≥50% reduction AND absolute decrease ≥50 mg/L
5. **MR** (Minimal Response): 25-49% reduction (NOT in ORR)
6. **SD** (Stable Disease): Neither response nor progression
7. **PD** (Progressive Disease): ≥25% increase from nadir + absolute increase ≥50 mg/L

**Additional Responses**:
- Cardiac response: NT-proBNP ≥30% decrease + >300 ng/L absolute decrease
- Renal response: Proteinuria ≥30% decrease OR eGFR improvement

---

## 7-Week Implementation Roadmap

| Week | Phase | Deliverables | Status |
|------|-------|--------------|--------|
| **1** | Phase 2 | dFLC calculation, LB enhancements, QC validation | ✅ Complete |
| **2** | Phase 3 | Demographics baseline characteristics | 🚧 In Progress |
| **3-4** | Phase 6 | ADLB + ADRS IMWG response derivation | ⏳ Pending |
| **5** | Phase 4 | CAR-T AE categorization | ⏳ Pending |
| **6** | Phase 5 | Manufacturing tracking | ⏳ Pending |
| **7** | Integration | Master pipeline, validation reports, documentation | ⏳ Pending |

---

## Key Study Design Features

**Patient Population**:
- Relapsed/refractory AL amyloidosis
- Median 4 prior lines (range 1-12)
- 100% bortezomib and daratumumab exposed
- 60% with cardiac involvement
- Mayo stage: II (33%), IIIA (67%)

**Current Sample Data** (3 patients):
- NEXICART2-001: Lambda, Mayo IIIA, NYHA III, baseline dFLC 1555 mg/L
- NEXICART2-002: Kappa, Mayo II, NYHA II, baseline dFLC 1213 mg/L  
- NEXICART2-003: Lambda, Mayo IIIA, NYHA II, baseline dFLC 670 mg/L

**Manufacturing**:
- Median manufacturing time: 16 days
- Manufacturing success: 100% (7/7)

---

## Validation Status

### Phase 2 Validation ✅
- [x] dFLC calculation manually verified (3 patients)
- [x] Light chain type consistency check passed
- [x] Baseline biomarker distribution reasonable
- [x] Clinical significance thresholds applied correctly
- [x] Independent QC script created

### Pending Validation
- [ ] Demographics baseline characteristics summaries
- [ ] IMWG response criteria algorithm
- [ ] Cardiac response derivation
- [ ] Response kinetics (time to response)
- [ ] Manufacturing metrics (vein-to-vein time)

---

## Repository Structure

```
sas-r-hybrid-clinical-pipeline/
├── sdtm/
│   ├── data/
│   │   ├── raw/
│   │   │   ├── lab_results_nexicart2.csv ✅
│   │   │   └── demographics_nexicart2.csv ✅
│   │   ├── csv/
│   │   └── xpt/
│   └── programs/
│       └── sas/
│           ├── 42_sdtm_lb_nexicart2.sas ✅
│           └── 48_sdtm_pr.sas ✅
├── adam/
│   ├── data/
│   └── programs/
│       └── sas/
│           ├── 60_adam_adlb_nexicart2.sas ⏳
│           └── 70_adam_adrs_imwg.sas ⏳
├── qc/
│   └── validate_dflc_calculation.sas ✅
└── NEXICART2_IMPLEMENTATION.md ✅ (this file)
```

---

## Next Actions

**Immediate (Week 2)**:
1. Update `20_sdtm_dm.sas` with baseline characteristics
2. Create QC report for demographics completeness
3. Begin ADLB program for response derivations

**Short-term (Weeks 3-4)**:
1. Implement IMWG response algorithm in ADRS
2. Add nadir detection for PD assessment
3. Cardiac response derivation
4. Create Best Overall Response (BOR) dataset

**Medium-term (Weeks 5-6)**:
1. CAR-T toxicity enhancements
2. Manufacturing tracking
3. Integration testing

---

## References

**Clinical Guidelines**:
- Palladini et al. Blood 2012 - IMWG consensus criteria for AL amyloidosis
- Dispenzieri et al. Blood 2004 - Mayo staging system
- Lee et al. Blood 2019 - ASTCT consensus grading for CRS/ICANS

**CDISC Standards**:
- SDTMIG v3.4 - Study Data Tabulation Model Implementation Guide
- ADaMIG v1.3 - Analysis Data Model Implementation Guide

---

## Contact

**Implementation Lead**: Christian Baghai
**Last Updated**: 2025-12-28
**Branch**: feature/nexicart-2-complete-implementation