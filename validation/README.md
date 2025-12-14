# Validation Documentation

**Purpose**: Regulatory-grade validation framework for RECIST 1.1 clinical data derivation pipeline  
**Compliance**: FDA 21 CFR Part 11, EU Annex 11, ICH E6(R2), GAMP 5  
**Last Updated**: December 2025

---

## Overview

This directory contains comprehensive validation documentation for the RECIST 1.1 derivation pipeline, designed to meet regulatory requirements for FDA and EMA submissions.

### Validation Framework Structure

```
validation/
├── iq_protocol.md                  # Installation Qualification
├── oq_protocol.md                  # Operational Qualification
├── pq_protocol.md                  # Performance Qualification
├── requirements_traceability_matrix.csv  # Bidirectional traceability
├── scripts/                        # Automated validation scripts
│   ├── check_r_env.R              # R environment verification (IQ-002)
│   ├── check_file_structure.R     # File integrity check (IQ-004)
│   └── check_sas_env.sas          # SAS environment verification (IQ-003)
├── pinnacle21/                     # CDISC compliance validation
│   ├── prepare_xpt_export.sas     # XPT export for P21 validation
│   └── validation_checklist.md    # P21 execution guide
└── evidence/                       # Test execution evidence (created during validation)
    ├── iq_002_r_env_check.txt
    ├── iq_003_sas_env_check.txt
    ├── iq_004_file_structure_check.txt
    └── [...additional test evidence...]
```

---

## Validation Stages: IQ → OQ → PQ

### Installation Qualification (IQ)

**Purpose**: Verify computational environment is correctly installed and configured

**Scope**:
- R version ≥ 4.2.0
- Required R packages (admiral, dplyr, haven, testthat, diffdf, yaml, lubridate)
- SAS version ≥ 9.4 M6
- SAS/STAT license (for PROC COMPARE)
- Repository file structure integrity
- Git version control configuration

**Document**: [`iq_protocol.md`](iq_protocol.md)

**Execution**:
```bash
# Automated checks
Rscript validation/scripts/check_r_env.R
Rscript validation/scripts/check_file_structure.R
sas validation/scripts/check_sas_env.sas
```

**Acceptance Criteria**: All IQ test cases must pass before proceeding to OQ

---

### Operational Qualification (OQ)

**Purpose**: Verify individual RECIST functions operate correctly per specifications

**Scope**:
- Target lesion response classification (PR threshold at -30%)
- Progressive disease dual criteria (+20% AND +5mm)
- Complete response requirement (SLD = 0)
- Nadir tracking for PD assessment
- Confirmation window boundaries (28-84 days)
- SD minimum duration (≥42 days)
- RECIST Table 4 integration logic
- New lesion detection

**Document**: [`oq_protocol.md`](oq_protocol.md)

**Automated Tests**: 
- R: `tests/testthat/test-recist-boundaries.R`
- R: `tests/testthat/test-recist-confirmation.R`
- Execution: `Rscript tests/run_all_tests.R`

**Test Coverage**: 20+ test cases covering all critical RECIST 1.1 logic

**Acceptance Criteria**:
- All critical priority OQ tests pass
- ≥90% of all OQ tests pass
- All failures documented with corrective actions

---

### Performance Qualification (PQ)

**Purpose**: Demonstrate end-to-end pipeline produces accurate results with production-like data

**Scope**:
- Comprehensive 25-subject test dataset processing
- Reproducibility testing (identical results across runs)
- Performance benchmarking (small/medium/large datasets)
- Data quality handling (missing data, out-of-sequence dates)
- Cross-platform validation (Windows/Linux/macOS)

**Document**: [`pq_protocol.md`](pq_protocol.md)

**Test Data**: 
- Input: `demo/data/comprehensive_sdtm_rs.csv` (25 subjects)
- Expected: `demo/data/expected_bor_comprehensive.csv`

**Execution**:
```bash
# Full pipeline with comprehensive dataset
sas demo/run_comprehensive_test.sas

# Automated comparison
Rscript qc/r/automated_comparison.R
```

**Acceptance Criteria**:
- 100% BOR concordance for subjects with complete data
- Zero critical discrepancies
- Pipeline completes in <5 minutes on standard hardware

---

## Requirements Traceability Matrix (RTM)

**Purpose**: Establish bidirectional traceability from requirements → code → tests → evidence

**File**: [`requirements_traceability_matrix.csv`](requirements_traceability_matrix.csv)

**Structure**:
- **REQ_ID**: Unique requirement identifier (e.g., UR-002)
- **Requirement_Description**: What must be implemented
- **RECIST_Reference**: Citation to RECIST 1.1 specification (Eisenhauer et al. 2009)
- **Priority**: Critical / High / Medium / Low
- **Implementing_Code**: Specific SAS macro or R function with line numbers
- **Test_Case_ID**: Links to automated tests (OQ/PQ test IDs)
- **IQ_OQ_PQ**: Qualification stage where validated
- **Status**: Passed / In Progress / Pending
- **Evidence_Location**: Path to test execution evidence

**Example Entry**:
```csv
UR-002,"Apply -30% decrease threshold for PR classification",
"RECIST 1.1 Table 3",Critical,
"derive_target_lesion_response.sas lines 145-160",
"OQ-RECIST-001 OQ-RECIST-002",OQ,Passed,
"tests/testthat/test-recist-boundaries.R lines 38-60"
```

**Traceability Coverage**: 15+ requirements covering all RECIST 1.1 logic

---

## Quality Control Framework

### Dual Validation Approach

The pipeline implements **dual programming** for critical derivations:

1. **Production Programmer**: Develops RECIST macros
2. **QC Programmer**: Independently programs same logic
3. **Automated Comparison**: Flags discrepancies between outputs

### R-Based QC (diffdf)

**File**: `qc/r/automated_comparison.R`

**Execution**:
```r
source("qc/r/automated_comparison.R")

# Compare datasets
result <- compare_datasets(
  prod_path = "outputs/adam/adrs.sas7bdat",
  qc_path = "outputs/qc/adrs.sas7bdat",
  keys = c("USUBJID", "PARAMCD", "AVISIT")
)

print(result$summary)  # PASS/FAIL status
```

**Features**:
- Pharmaceutical-grade comparison using `diffdf` package
- Configurable numeric tolerance for floating-point precision
- Automated HTML report generation
- Pass/fail determination with detailed metrics

### SAS-Based QC (PROC COMPARE)

**Files**:
- `qc/sas/compare_adsl.sas` - Subject-level dataset comparison
- `qc/sas/compare_adrs.sas` - Response dataset comparison (BOR focus)
- `qc/sas/compare_adtte.sas` - Time-to-event dataset comparison

**Execution**:
```bash
# Run all SAS QC comparisons
./qc/run_sas_qc.sh

# Or individually
sas qc/sas/compare_adsl.sas
sas qc/sas/compare_adrs.sas
sas qc/sas/compare_adtte.sas
```

**Output**:
- HTML reports: `outputs/qc_reports/adsl_compare_YYYYMMDD.html`
- SAS logs: `logs/qc_adsl_YYYYMMDD.log`
- Pass/fail status in console and log

**Key Features**:
- PROC COMPARE with absolute tolerance (0.001 for numeric)
- Focus on response-specific variables (AVALC, CONFFL, PCHG)
- Discrepancy frequency analysis by parameter
- BOR-specific validation (most critical endpoint)

---

## CDISC Compliance Validation (Pinnacle 21)

**Purpose**: Validate datasets conform to CDISC ADaM Implementation Guide and controlled terminology

**Directory**: `validation/pinnacle21/`

### Preparation

1. **Export datasets to XPT format** (required by Pinnacle 21):
```bash
sas validation/pinnacle21/prepare_xpt_export.sas
```

Outputs:
- `validation/pinnacle21/xpt_files/adsl.xpt`
- `validation/pinnacle21/xpt_files/adrs.xpt`
- `validation/pinnacle21/xpt_files/adtte.xpt`

2. **Prepare define.xml metadata** (use Pinnacle 21 Define-XML Generator or manual creation)

### Execution

Follow step-by-step guide: [`pinnacle21/validation_checklist.md`](pinnacle21/validation_checklist.md)

**Key Steps**:
1. Open Pinnacle 21 Community application
2. Select ADaM validation configuration
3. Load XPT files and define.xml
4. Execute validation
5. Review errors/warnings
6. Iterate until clean validation achieved

**Acceptance Criteria**:
- **Zero critical errors** (red flags)
- All warnings documented with justification
- Define.xml passes structural validation
- XPT files comply with SAS V5 transport specification

**Typical Iteration**: 3-4 validation cycles to achieve clean validation

---

## Validation Execution Workflow

### Phase 1: Installation Qualification (2-3 hours)

```bash
# Step 1: Verify R environment
Rscript validation/scripts/check_r_env.R
# Expected: PASS status, all packages present

# Step 2: Verify file structure
Rscript validation/scripts/check_file_structure.R
# Expected: All critical files present

# Step 3: Verify SAS environment
sas validation/scripts/check_sas_env.sas
# Expected: SAS 9.4 M6+, PROC COMPARE functional

# Step 4: Document results in validation/iq_protocol.md
# - Fill in test record sections
# - Attach evidence files
# - Obtain sign-offs
```

**Deliverable**: Completed IQ protocol with evidence and sign-offs

---

### Phase 2: Operational Qualification (4-6 hours)

```bash
# Step 1: Run automated unit tests
Rscript tests/run_all_tests.R
# Expected: All testthat tests pass

# Step 2: Document test results in validation/oq_protocol.md
# For each OQ test case:
# - Record execution date and tester
# - Document actual results vs expected
# - Mark PASS/FAIL status
# - Link to test evidence files

# Step 3: Investigate any test failures
# - Document root cause
# - Implement fix
# - Re-run tests
# - Update traceability matrix

# Step 4: Obtain sign-offs
```

**Deliverable**: Completed OQ protocol with 90%+ test pass rate

---

### Phase 3: Performance Qualification (6-8 hours)

```bash
# Step 1: Run comprehensive dataset through pipeline
sas demo/run_comprehensive_test.sas

# Step 2: Compare actual vs expected BOR
Rscript qc/r/automated_comparison.R

# Step 3: Execute reproducibility test (3 independent runs)
# Run 1
sas demo/run_comprehensive_test.sas -log logs/pq_run1.log
# Run 2
sas demo/run_comprehensive_test.sas -log logs/pq_run2.log
# Run 3
sas demo/run_comprehensive_test.sas -log logs/pq_run3.log

# Compare MD5 checksums
md5sum outputs/run1/adam/adrs.sas7bdat
md5sum outputs/run2/adam/adrs.sas7bdat
md5sum outputs/run3/adam/adrs.sas7bdat
# Expected: Identical checksums

# Step 4: Document results in validation/pq_protocol.md
# - PQ-001: Comprehensive dataset results
# - PQ-002: Reproducibility evidence
# - PQ-003: Performance benchmarks

# Step 5: Obtain management sign-offs
```

**Deliverable**: Completed PQ protocol with 100% BOR concordance

---

### Phase 4: CDISC Compliance (4-6 hours)

```bash
# Step 1: Export to XPT format
sas validation/pinnacle21/prepare_xpt_export.sas

# Step 2: Execute Pinnacle 21 validation
# (Manual process in Pinnacle 21 GUI)
# Follow: validation/pinnacle21/validation_checklist.md

# Step 3: Review and resolve errors
# - Document each error in issue_resolution_log.csv
# - Implement fixes
# - Re-validate
# - Iterate until clean validation

# Step 4: Archive validation report
cp validation_report.html validation/pinnacle21/reports/p21_validation_$(date +%Y%m%d).html
```

**Deliverable**: Pinnacle 21 validation report with zero critical errors

---

## Evidence Collection

All validation evidence must be collected and archived:

### Automated Test Evidence
- `validation/evidence/iq_002_r_env_check.txt`
- `validation/evidence/iq_003_sas_env_check.txt`
- `validation/evidence/iq_004_file_structure_check.txt`
- `validation/evidence/oq_*.log` (OQ test execution logs)
- `validation/evidence/pq_*.log` (PQ test execution logs)

### QC Comparison Reports
- `outputs/qc_reports/adsl_compare_YYYYMMDD.html`
- `outputs/qc_reports/adrs_compare_YYYYMMDD.html`
- `outputs/qc_reports/adtte_compare_YYYYMMDD.html`

### Pinnacle 21 Validation
- `validation/pinnacle21/reports/p21_validation_YYYYMMDD.html`
- `validation/pinnacle21/issue_resolution_log.csv`

### Test Coverage Report
- `validation/test_coverage_report.html` (generated by covr package)

---

## Regulatory Compliance Checklist

### FDA 21 CFR Part 11 Requirements

- [x] **§11.10(a)**: Validation of systems to ensure accuracy, reliability, and consistent intended performance
  - Evidence: IQ/OQ/PQ protocols
  
- [x] **§11.10(c)**: Ability to generate accurate and complete copies of records
  - Evidence: PQ-002 reproducibility testing
  
- [x] **§11.10(e)**: Use of secure, computer-generated, time-stamped audit trails
  - Evidence: Git version control with commit history
  
- [ ] **§11.10(g)**: Use of authority checks (if required by sponsor)
  - Status: Not implemented (single-user system)

### ICH E6(R2) Good Clinical Practice

- [x] **Section 5.5.3**: Quality control should be applied to each stage of data handling
  - Evidence: Dual programming with SAS/R QC framework
  
- [x] **Section 5.18.4(e)**: The sponsor should ensure accuracy, completeness, and reliability
  - Evidence: Requirements traceability matrix, OQ/PQ validation

### GAMP 5 Risk-Based Validation

- [x] **System Classification**: Category 4 (Configured Products)
- [x] **Risk Assessment**: Medium risk (impacts analysis, not patient care)
- [x] **Validation Rigor**: Proportionate to risk (IQ/OQ/PQ approach)

---

## Sign-Off and Approval

### Validation Lead
**Name**: ________________________________  
**Date**: ________________________________  
**Signature**: ________________________________

### Quality Assurance Manager
**Name**: ________________________________  
**Date**: ________________________________  
**Signature**: ________________________________

### Study Director / Sponsor Representative
**Name**: ________________________________  
**Date**: ________________________________  
**Signature**: ________________________________

---

## References

1. FDA 21 CFR Part 11: Electronic Records; Electronic Signatures (1997)
2. EU Annex 11: Computerised Systems (2011)
3. ICH E6(R2): Good Clinical Practice (2016)
4. GAMP 5: A Risk-Based Approach to Compliant GxP Computerized Systems (2008)
5. Eisenhauer EA, et al. New response evaluation criteria in solid tumours: Revised RECIST guideline (version 1.1). *Eur J Cancer*. 2009;45(2):228-247.
6. CDISC ADaM Implementation Guide v1.1 (2016)
7. FDA Guidance: Process Validation - General Principles and Practices (2011)

---

**Document Version**: 1.0  
**Last Updated**: December 14, 2025  
**Maintained By**: Christian Baghai  
**Next Review**: Upon completion of validation or significant system changes
