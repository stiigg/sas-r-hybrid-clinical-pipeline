# NEXICART-2: AL Amyloidosis CAR-T Clinical Trial Implementation

## Executive Summary

This repository branch implements a **production-grade SDTM and ADaM pipeline** for the **NEXICART-2 clinical trial**, investigating **NXC-201 BCMA-targeted CAR-T cell therapy** for relapsed/refractory light chain (AL) amyloidosis. The implementation demonstrates **expert-level therapeutic area knowledge** in AL amyloidosis, **advanced ADaM programming techniques** (nadir tracking), and **regulatory-grade quality control** validation.

### Trial Background

**NEXICART-2** is a Phase 1/2 clinical trial evaluating NXC-201, an autologous BCMA-directed CAR-T therapy, in patients with relapsed/refractory AL amyloidosis who have failed at least one prior line of therapy. Recent results (December 2025) showed:

- **95% overall hematologic response rate** (ORR)
- **75% complete response rate** (CR)
- **Rapid response kinetics**: 14-day median time to response
- **Manageable safety profile**: 83% CRS incidence (mostly Grade 1-2), 0% ICANS
- **100% manufacturing success** with 14-day vein-to-vein time

### Clinical Significance

AL amyloidosis is a rare, life-threatening plasma cell disorder where misfolded immunoglobulin light chains deposit as amyloid fibrils in organs (heart, kidneys, liver), causing progressive organ failure. **Median survival is 6 months** for advanced Mayo Stage IIIB/IV patients. Standard chemotherapy produces CR rates of 20-40%, making NXC-201's 75% CR rate a potential breakthrough.

---

## Implementation Highlights

### ✅ Phase 2: SDTM Laboratory Domain (COMPLETE)

**Program**: `sdtm/programs/sas/42_sdtm_lb_nexicart2.sas` (14.5 KB)

**Key Features**:
- **Derived dFLC calculation** (involved FLC - uninvolved FLC) with light chain type tracking
- **Comprehensive biomarker panel**:
  - Serum free light chains (kappa, lambda, dFLC, FLC ratio)
  - Cardiac biomarkers (NT-proBNP, high-sensitivity troponin) for Mayo staging
  - Renal function (eGFR, 24h urine protein, creatinine)
  - Immunofixation (serum and urine) for CR determination
  - Cytokine panel (IL-6, IL-10, IFN-gamma) for CRS monitoring
  - B-cell recovery (CD19 count) for immune reconstitution
  - CAR-T pharmacokinetics (qPCR-based CAR-T cell quantification)
- **Clinical significance flagging**: High-risk cardiac patients (NT-proBNP >8,500 ng/L)
- **QC validation reports**: dFLC calculation verification for first 3 subjects

**Input**: `sdtm/data/raw/lab_results_nexicart2.csv` (6.8 KB, 3 patients, longitudinal)

**Output**: `sdtm/data/csv/lb.csv`, `sdtm/data/xpt/lb.xpt`

---

### ✅ Phase 6: ADaM ADLB with Nadir Tracking (COMPLETE)

**Program**: `adam/programs/sas/60_adam_adlb_nexicart2.sas` (11.6 KB)

**Key Innovation**: **Cumulative nadir calculation** (running minimum post-baseline)

**Technical Implementation**:
```sas
/* Cumulative minimum using RETAIN statement */
data adlb_nadir;
    set adlb_postbl;
    by USUBJID PARAMCD ADY;
    
    retain NADIR NADIRDY;
    
    if first.PARAMCD then do;
        NADIR = AVAL;
        NADIRDY = ADY;
    end;
    else do;
        if AVAL < NADIR then do;
            NADIR = AVAL;
            NADIRDY = ADY;
        end;
    end;
    
    if AVAL = NADIR then NADIRF = 'Y';
run;
```

**Why Nadir Matters**: IMWG progressive disease (PD) criteria define relapse as **≥25% increase from nadir** (not baseline), making nadir tracking **mandatory** for accurate response classification in AL amyloidosis trials.

**Derived Variables**:
- `BASE`: Baseline value (pre-treatment)
- `CHG`, `PCHG`: Change and percent change from baseline
- `NADIR`: Lowest post-baseline value (cumulative minimum)
- `NADIRDY`: Study day when nadir occurred
- `NADIRF`: Flag identifying nadir record (Y/blank)
- `CHGNADIR`, `PCHGNADIR`: Change and percent change from nadir
- `ANL01FL`, `ANL02FL`, `ANL03FL`: Analysis flags

**QC Validation**: Independent comparison of `NADIR` to `min(post-baseline AVAL)` with automated pass/fail reporting.

---

### ✅ Phase 6: ADaM ADRS with IMWG Response (COMPLETE)

**Program**: `adam/programs/sas/70_adam_adrs_imwg.sas` (14.4 KB)

**IMWG 7-Tier Hematologic Response Hierarchy** (Palladini et al. *Blood* 2012):

| Rank | Response | IMWG Criteria | ORR Inclusion |
|------|----------|---------------|---------------|
| 7 | **sCR** (stringent CR) | Negative IF + Normal FLC ratio (0.26-1.65) + BM <5% | ✅ Yes |
| 6 | **CR** (complete) | Negative IF + dFLC <40 mg/L | ✅ Yes |
| 5 | **VGPR** (very good PR) | dFLC <40 mg/L OR ≥90% reduction | ✅ Yes |
| 4 | **PR** (partial) | ≥50% reduction AND ≥-50 mg/L absolute decrease | ✅ Yes |
| 3 | **MR** (minimal) | 25-49% reduction | ❌ **NO** |
| 2 | **SD** (stable) | Neither response nor progression | ❌ No |
| 1 | **PD** (progressive) | ≥25% increase from **nadir** + ≥50 mg/L absolute | ❌ No |

**Critical Distinction**: MR (minimal response) is **excluded from ORR** in AL amyloidosis, unlike multiple myeloma where any response ≥50% contributes to ORR.

**Hierarchical Logic Implementation**:
```sas
/* Must apply in strict priority order */
if pd_criteria then RESPONSE = 'PD';              /* Check first */
else if scr_criteria then RESPONSE = 'sCR';
else if cr_criteria then RESPONSE = 'CR';
else if vgpr_criteria then RESPONSE = 'VGPR';
else if pr_criteria then RESPONSE = 'PR';
else if mr_criteria then RESPONSE = 'MR';
else RESPONSE = 'SD';                             /* Default */
```

**Confirmed Response**: Same response category maintained on ≥2 consecutive assessments ≥28 days apart.

**Best Overall Response (BOR)**: Highest **confirmed** response during study period.

**Derived Efficacy Endpoints**:
- `ORR`: Overall Response Rate = sCR + CR + VGPR + PR (excludes MR)
- `CR Rate`: Complete Response Rate = sCR + CR
- `Deep Response Rate`: Same as CR rate
- `VGPR or Better`: sCR + CR + VGPR

**Integration**:
- **dFLC values**: From ADLB (baseline, change, nadir, percent changes)
- **FLC ratio**: From ADLB (for sCR determination)
- **Immunofixation**: From SDTM LB (both serum and urine must be negative)
- **Bone marrow plasma cells**: Optional from SDTM PR domain (if collected)

---

### ✅ QC Validation (COMPLETE)

**Program**: `qc/validate_dflc_calculation.sas` (8.9 KB)

**Methodology**: **Double programming** (independent QC programmer)

**Process**:
1. **Independent re-derivation**: QC programmer calculates dFLC from raw kappa/lambda **without** reviewing production code
2. **Comparison**: Production `LB.DFLC` vs. QC `QC_DFLC`
3. **Tolerance**: ±0.1 mg/L (Freelite assay instrument precision)
4. **Automated reporting**: PASS/FAIL determination with ERROR logging

**QC Logic Verification**:
```sas
/* Lambda-involved patients */
if LC_TYPE = 'λ' then QC_DFLC = lambda_val - kappa_val;

/* Kappa-involved patients */
if LC_TYPE = 'κ' then QC_DFLC = kappa_val - lambda_val;
```

**Regulatory Compliance**: Supports **21 CFR Part 11** (electronic records) and **ICH E6(R2)** (Good Clinical Practice) requirements for data validation.

---

## Data Structure

### Raw Data (3 Patients, Longitudinal)

**File**: `sdtm/data/raw/lab_results_nexicart2.csv` (6.8 KB)

**Patient Profiles**:

| USUBJID | LC Type | Baseline dFLC | Mayo Stage | Response Pattern |
|---------|---------|---------------|------------|------------------|
| NEXICART2-001 | Lambda (λ) | 1,555 mg/L | IIIB (high-risk) | Rapid CR (dFLC →40 mg/L by Cycle 2) |
| NEXICART2-002 | Kappa (κ) | 1,213 mg/L | II (intermediate) | PR (66% reduction) |
| NEXICART2-003 | Lambda (λ) | 670 mg/L | IIIA (cardiac) | Data through screening only |

**Timepoints**:
- Visit 0: Screening (baseline)
- Visit 1: Cycle 1 Day 1 (post-infusion assessment)
- Visit 2: Cycle 2 Day 1 (response evaluation)

**Biomarker Highlights**:
- **NEXICART2-001**: Baseline NT-proBNP 8,542 ng/L (Stage IIIB threshold >8,500) → Normalized to 2,150 ng/L
- **NEXICART2-002**: IL-6 surge to 95.5 pg/mL at Cycle 1 (Grade 2 CRS)
- **All patients**: CD19 B-cell depletion at Cycle 1 (8-12 cells/μL), demonstrating CAR-T activity

---

## Clinical Context: AL Amyloidosis Essentials

### Disease Pathophysiology

**AL (light chain) amyloidosis** is caused by a clonal plasma cell disorder producing **misfolded immunoglobulin light chains** (kappa or lambda) that aggregate into insoluble **amyloid fibrils**, depositing in organs and causing progressive dysfunction.

**Key Concepts**:
- **Involved FLC**: The monoclonal light chain (kappa or lambda) producing amyloid deposits
- **Uninvolved FLC**: The non-clonal light chain from healthy plasma cells
- **dFLC (difference)**: Involved FLC - Uninvolved FLC = **primary biomarker** for disease burden
- **Organ involvement**: Heart (50%), kidney (70%), liver (15%), peripheral nerves (20%)

### Mayo 2012 Staging System

**Three biomarkers** stratify prognosis:

| Stage | NT-proBNP | Troponin T | dFLC | Median OS |
|-------|-----------|------------|------|----------|
| **I** | <1,800 ng/L | <0.025 ng/mL | <180 mg/L | 94 months |
| **II** | 1 elevated | - | - | 40 months |
| **IIIA** | Both elevated | - | <180 mg/L | 14 months |
| **IIIB** | Both elevated | - | ≥180 mg/L | **6 months** |
| **IV** | Stage IIIB + eGFR <50 mL/min | - | - | <6 months |

**Clinical Significance**: NEXICART2-001 with Mayo Stage IIIB (6-month median survival) achieving CR demonstrates potential **life-saving benefit**.

### Treatment Landscape

**Standard of Care** (chemotherapy-based):
- **First-line**: Daratumumab + cyclophosphamide/bortezomib/dexamethasone (ANDROMEDA trial: 53% hematologic CR)
- **Second-line**: Melphalan + autologous stem cell transplant (eligible patients only)
- **Problem**: Many patients **ineligible** for transplant due to advanced cardiac dysfunction

**NXC-201 CAR-T Advantage**:
- **One-time infusion** (vs. continuous chemotherapy)
- **75% CR rate** (vs. 20-40% with chemotherapy)
- **Rapid response**: Median 14 days (vs. 2-3 months)
- **Potential organ recovery**: Cardiac biomarker normalization observed

---

## Technical Specifications

### CDISC Standards Compliance

- **SDTM**: Study Data Tabulation Model v3.4
- **ADaM**: Analysis Data Model v1.1
- **Controlled Terminology**: CDISC CT 2023-12-15

### Variable Naming Conventions

**SDTM LB Domain**:
- `LBTESTCD`: Laboratory test code (e.g., 'DFLC', 'KAPPA', 'LAMBDA')
- `LBTEST`: Full test name (e.g., 'Difference in Free Light Chains')
- `LBCAT`: Category (e.g., 'SERUM FREE LIGHT CHAINS', 'CARDIAC BIOMARKERS')
- `LBMETHOD`: Analytical method (e.g., 'FREELITE', 'ELISA')
- `LBBLFL`: Baseline flag ('Y' if pre-treatment assessment)
- `LBNRIND`: Normal range indicator ('LOW', 'NORMAL', 'HIGH', 'HIGH, CS' for clinical significance)

**ADaM ADLB**:
- `PARAMCD`: Parameter code (same as LBTESTCD)
- `AVAL`: Analysis value (numeric)
- `BASE`: Baseline value
- `CHG`: Change from baseline (AVAL - BASE)
- `PCHG`: Percent change from baseline ((CHG/BASE)*100)
- `NADIR`: Cumulative minimum post-baseline
- `NADIRDY`: Study day of nadir
- `NADIRF`: Nadir flag ('Y' if current record is nadir)
- `CHGNADIR`: Change from nadir (AVAL - NADIR)
- `PCHGNADIR`: Percent change from nadir

**ADaM ADRS**:
- `PARAMCD`: 'IMWGRESP' (IMWG hematologic response)
- `PARAM`: 'IMWG Hematologic Response'
- `AVALC`: Response category ('sCR', 'CR', 'VGPR', 'PR', 'MR', 'SD', 'PD')
- `AVAL`: Numeric rank (1=PD, 2=SD, 3=MR, 4=PR, 5=VGPR, 6=CR, 7=sCR)
- `CONFIRMEDFL`: Confirmed response flag ('Y' if ≥2 consecutive assessments ≥28 days)
- `BOR`: Best overall response (highest confirmed response)
- `ORRFL`: Overall response rate flag ('Y' if sCR/CR/VGPR/PR, 'N' if MR/SD/PD)
- `CRFL`: Complete response flag ('Y' if sCR or CR)

---

## File Inventory

### SDTM Programs
```
sdtm/programs/sas/
├── 42_sdtm_lb_nexicart2.sas    (14,483 bytes) - Laboratory domain with dFLC derivation
└── 20_sdtm_dm.sas              (existing) - Demographics domain
```

### ADaM Programs
```
adam/programs/sas/
├── 60_adam_adlb_nexicart2.sas  (11,614 bytes) - Laboratory analysis with nadir tracking
├── 70_adam_adrs_imwg.sas       (14,357 bytes) - IMWG response classification
└── 30_adam_adsl.sas            (existing) - Subject-level analysis
```

### QC Programs
```
qc/
└── validate_dflc_calculation.sas  (8,868 bytes) - Independent dFLC validation
```

### Raw Data
```
sdtm/data/raw/
├── lab_results_nexicart2.csv      (6,772 bytes) - 3 patients, longitudinal biomarkers
└── demographics_nexicart2.csv     (658 bytes) - Patient demographics with LC type
```

---

## Implementation Status

### ✅ Completed (Core Pipeline)

| Phase | Deliverable | Status | Lines of Code | Key Features |
|-------|-------------|--------|---------------|-------------|
| **Phase 2** | SDTM LB Domain | ✅ Complete | 420 | dFLC derivation, comprehensive biomarkers |
| **Phase 6A** | ADaM ADLB | ✅ Complete | 380 | Nadir tracking, change from baseline/nadir |
| **Phase 6B** | ADaM ADRS | ✅ Complete | 450 | IMWG 7-tier response, BOR, ORR endpoints |
| **Phase 7** | QC Validation | ✅ Complete | 290 | Independent dFLC verification, automated PASS/FAIL |

**Total**: ~1,540 lines of production SAS code + comprehensive documentation

### ⏳ Future Enhancements (Optional)

| Phase | Enhancement | Priority | Est. Hours | Purpose |
|-------|-------------|----------|------------|----------|
| **Phase 4** | AE CAR-T Toxicity | Medium | 10-12 | ASTCT CRS grading, ICANS tracking |
| **Phase 5** | DM Mayo Staging | Medium | 6-8 | Baseline risk stratification |
| **Phase 5** | DM Organ Involvement | Medium | 4-6 | Multi-organ involvement flags |
| **Phase 5** | MB Manufacturing | Low | 6-8 | Vein-to-vein time, CAR-T dose tracking |
| **Phase 7** | Master Pipeline | Low | 4-5 | One-click execution script |
| **Phase 7** | Validation Report | Low | 3-4 | Traceability matrix for regulatory submission |

---

## Portfolio Value

### Demonstrates Expertise In:

1. **Therapeutic Area Knowledge**: AL amyloidosis, CAR-T cell therapy, hematologic malignancies
2. **Advanced ADaM Techniques**: Nadir calculation (cumulative minimum), hierarchical response classification
3. **Regulatory Standards**: CDISC SDTM/ADaM compliance, QC validation methodology
4. **Clinical Trial Endpoints**: Primary efficacy (ORR), secondary endpoints (CR rate, BOR)
5. **Data Quality**: Independent validation, automated QC reporting, tolerance-based acceptance criteria
6. **Real-World Data**: Based on actual NEXICART-2 trial design and published results

### Distinguishing Features:

- **Therapeutic area depth**: Not generic oncology - specific to **AL amyloidosis** subtype
- **Nadir tracking**: Advanced ADaM programming beyond basic change-from-baseline
- **IMWG criteria implementation**: Industry-standard response assessment for AL amyloidosis
- **QC validation**: Demonstrates regulatory-grade quality control processes
- **Clinical context**: Clear documentation of why dFLC, nadir, and IMWG criteria matter clinically

---

## References

### IMWG Consensus Criteria
1. Palladini G, et al. **New criteria for response to treatment in immunoglobulin light chain amyloidosis based on free light chain measurement and cardiac biomarkers.** *Blood.* 2012;119(23):5397-5404.
2. Kumar S, et al. **Revised prognostic staging system for light chain amyloidosis incorporating cardiac biomarkers and serum free light chain measurements.** *J Clin Oncol.* 2012;30(9):989-995.

### NEXICART-2 Trial Results
3. Landau H, et al. **First US Trial of CAR T-Cell Therapy for Relapsed/Refractory AL Amyloidosis.** Memorial Sloan Kettering Cancer Center. December 2025.
4. Immix Biopharma. **NEXICART-2 Clinical Trial Progress in Relapsed/Refractory AL Amyloidosis.** Press Release. July 2025.

### CDISC Standards
5. CDISC. **Study Data Tabulation Model Implementation Guide (SDTMIG) v3.4.** 2023.
6. CDISC. **Analysis Data Model Implementation Guide (ADaMIG) v1.1.** 2016.

### CAR-T Toxicity Grading
7. Lee DW, et al. **ASTCT Consensus Grading for Cytokine Release Syndrome and Neurologic Toxicity Associated with Immune Effector Cells.** *Biol Blood Marrow Transplant.* 2019;25(4):625-638.

---

## Author & Contact

**Christian Baghai**
- Clinical Statistical Programmer | Digital Analytics Consultant
- Specialization: SDTM/ADaM programming, CAR-T clinical trials, hematologic malignancies
- GitHub: [@stiigg](https://github.com/stiigg)
- Location: Paris, France

**Repository**: [sas-r-hybrid-clinical-pipeline](https://github.com/stiigg/sas-r-hybrid-clinical-pipeline)

**Branch**: `feature/nexicart-2-complete-implementation`

**Last Updated**: December 28, 2025

---

## License

MIT License - See repository root for details.

---

*This implementation is for portfolio demonstration purposes and uses synthetic patient data. Any resemblance to actual clinical trial data is coincidental.*
