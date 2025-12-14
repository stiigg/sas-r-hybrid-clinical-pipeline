# Performance Qualification Protocol

**System**: Clinical Trial Data Pipeline - RECIST 1.1 Module  
**Protocol Version**: 1.0  
**Date**: December 2025  
**Prepared By**: Christian Baghai  
**Regulatory Framework**: 21 CFR Part 11, ICH E6(R2), GAMP 5

---

## 1. Executive Summary

### 1.1 Objective
Demonstrate that the complete RECIST 1.1 derivation pipeline produces accurate, reproducible results under production-like conditions. PQ validates end-to-end system performance with realistic datasets.

### 1.2 Scope
- Full pipeline execution: SDTM → ADaM transformation
- Comprehensive test dataset (25 subjects, all RECIST scenarios)
- Reproducibility testing (identical results across multiple runs)
- Performance benchmarking (execution time, resource utilization)
- Stress testing with production-scale datasets

### 1.3 Testing Approach
**Black-box testing**: Tests complete system as users would interact with it  
**Production simulation**: Uses realistic data volumes and complexity

---

## 2. Performance Qualification Test Cases

### PQ-001: Comprehensive Test Dataset Processing

**Requirement ID**: UR-001 through UR-012 (All requirements)  
**Objective**: Validate end-to-end pipeline accuracy with comprehensive test data

**Test Data**:
- **Input**: `demo/data/comprehensive_sdtm_rs.csv` (25 subjects)
- **Expected Output**: `demo/data/expected_bor_comprehensive.csv`
- **Coverage**: All RECIST 1.1 response categories and edge cases

**Subject Coverage**:
- CR with confirmation (n=2)
- PR with confirmation (n=3)
- SD with sufficient duration (n=3)
- PD from various causes (n=5)
- Unconfirmed responses (n=3)
- Missing/incomplete data (n=2)
- Non-target lesion scenarios (n=4)
- New lesion detection (n=3)

**Execution Steps**:
1. Load comprehensive SDTM RS test data
2. Execute complete derivation pipeline:
```sas
/* Full pipeline execution */
%derive_target_lesion_response(inds=sdtm.rs, outds=work.target_response);
%derive_non_target_lesion_response(inds=sdtm.rs, outds=work.nontarget_response);
%derive_overall_timepoint_response(target=work.target_response, 
                                   nontarget=work.nontarget_response,
                                   outds=work.overall_response);
%derive_best_overall_response(inds=work.overall_response, outds=adam.adrs);
```
3. Compare output against expected BOR dataset using QC comparison:
```r
library(diffdf)
actual <- read_sas("outputs/adam/adrs.sas7bdat")
expected <- read.csv("demo/data/expected_bor_comprehensive.csv")

comparison <- diffdf(expected, actual, keys = "USUBJID")
print(comparison)
```
4. Document discrepancies in validation report

**Acceptance Criteria**:
- ✅ **Zero critical discrepancies** in BOR classification for subjects with complete data
- ✅ **100% concordance** between actual and expected responses
- ✅ **Acceptable differences**: Rounding to 1 decimal place for percent change
- ✅ **Performance**: Pipeline completes in <5 minutes on standard hardware (16GB RAM, 4-core CPU)
- ✅ **No SAS errors or warnings** in execution log

**Test Record**:
- Date Tested: ________________
- Execution Time: ________________
- Subjects Processed: _____ / 25
- Concordant BOR: _____ / 25 (_____%)
- Critical Discrepancies: ________________
- Status: ☐ Pass ☐ Fail
- Evidence: 
  - Comparison report: `outputs/qc/pq_001_comparison.html`
  - Execution log: `validation/evidence/pq_001_execution.log`
  - SAS log: `logs/pq_001_sas.log`

**Discrepancy Investigation** (if applicable):

| USUBJID | Expected BOR | Actual BOR | Root Cause | Resolution |
|---------|--------------|------------|------------|------------|
| _______ | _________ | _________ | _________ | _________ |

---

### PQ-002: Reproducibility Testing

**Requirement ID**: UR-012 (21 CFR Part 11 §11.10(c) - Reproducibility)  
**Objective**: Verify pipeline produces identical results across multiple independent executions

**Test Procedure**:
1. Execute pipeline **three times** with identical input data:
   - Run 1: [Timestamp] ________________
   - Run 2: [Timestamp] ________________  
   - Run 3: [Timestamp] ________________

2. Compare outputs using MD5 hash checksums:
```bash
# Generate checksums for each run
md5sum outputs/run1/adam/adrs.sas7bdat > checksums_run1.txt
md5sum outputs/run2/adam/adrs.sas7bdat > checksums_run2.txt
md5sum outputs/run3/adam/adrs.sas7bdat > checksums_run3.txt

# Compare checksums
diff checksums_run1.txt checksums_run2.txt
diff checksums_run2.txt checksums_run3.txt
```

3. Record-level comparison:
```r
run1 <- read_sas("outputs/run1/adam/adrs.sas7bdat")
run2 <- read_sas("outputs/run2/adam/adrs.sas7bdat")
run3 <- read_sas("outputs/run3/adam/adrs.sas7bdat")

all.equal(run1, run2) # Should be TRUE
all.equal(run2, run3) # Should be TRUE
```

**Acceptance Criteria**:
- ✅ **Bit-for-bit identical** outputs across all three runs (MD5 checksums match)
- ✅ **Zero record-level differences** between runs
- ✅ **Deterministic behavior**: Same input always produces same output
- ✅ **No timestamp dependencies** affecting derivations

**Test Record**:
- Date Tested: ________________
- MD5 Checksum Run 1: ________________
- MD5 Checksum Run 2: ________________
- MD5 Checksum Run 3: ________________
- Checksums Match: ☐ Yes ☐ No
- Status: ☐ Pass ☐ Fail
- Evidence: `validation/evidence/pq_002_reproducibility_report.html`

---

### PQ-003: Performance Benchmarking

**Objective**: Validate system performance meets requirements under various data volumes

**Test Scenarios**:

#### Scenario A: Small Study (50 subjects)
- **Subjects**: 50
- **Visits per subject**: 6 (baseline + 5 follow-up)
- **Total RS records**: ~300
- **Target execution time**: <30 seconds

#### Scenario B: Medium Study (200 subjects)  
- **Subjects**: 200
- **Visits per subject**: 8
- **Total RS records**: ~1,600
- **Target execution time**: <2 minutes

#### Scenario C: Large Study (850 subjects)
- **Subjects**: 850
- **Visits per subject**: 12
- **Total RS records**: ~10,200
- **Target execution time**: <10 minutes

**Measurement Procedure**:
```sas
/* SAS execution time measurement */
%let start_time = %sysfunc(datetime());

/* Execute full pipeline */
%derive_target_lesion_response(...);
%derive_non_target_lesion_response(...);
%derive_overall_timepoint_response(...);
%derive_best_overall_response(...);

%let end_time = %sysfunc(datetime());
%let elapsed = %sysevalf(&end_time - &start_time);

%put NOTE: Pipeline execution time: &elapsed seconds;
```

**Performance Metrics**:

| Scenario | Subjects | Records | Target Time | Actual Time | Status |
|----------|----------|---------|-------------|-------------|--------|
| Small | 50 | 300 | <30s | _______ | ☐ P ☐ F |
| Medium | 200 | 1,600 | <2min | _______ | ☐ P ☐ F |
| Large | 850 | 10,200 | <10min | _______ | ☐ P ☐ F |

**Acceptance Criteria**:
- All scenarios complete within target time
- No memory overflow errors
- Linear or sub-linear scaling with data volume

**Test Record**:
- Date Tested: ________________
- Hardware Configuration: ________________
- Status: ☐ Pass ☐ Fail
- Evidence: `validation/evidence/pq_003_performance_benchmark.log`

---

### PQ-004: Data Quality Validation

**Objective**: Verify pipeline handles real-world data quality issues gracefully

**Test Scenarios**:
1. **Missing baseline assessment**: Subject with no ABLFL='Y' record
2. **Out-of-sequence dates**: Follow-up date earlier than baseline
3. **Duplicate assessments**: Multiple records for same visit
4. **Invalid SLD values**: Negative or non-numeric values
5. **Post-progression assessments**: Data after new therapy initiation

**Expected Behavior**:
- Appropriate warnings/notes in log (not errors)
- Subjects with data issues flagged but pipeline continues
- Output dataset includes data quality flags

**Acceptance Criteria**:
- Pipeline completes without fatal errors
- Data quality issues logged with subject IDs
- Invalid records excluded from BOR derivation
- QC flags appropriately set (e.g., `DQFLAG`, `DQREASON`)

**Test Record**:
- Date Tested: ________________
- Scenarios Tested: _____ / 5
- Status: ☐ Pass ☐ Fail
- Evidence: `validation/evidence/pq_004_data_quality.log`

---

### PQ-005: Cross-Platform Validation

**Objective**: Verify results consistent across computing environments

**Test Platforms**:
- **Platform A**: Windows 10, SAS 9.4 M7, R 4.2.3
- **Platform B**: Linux (Ubuntu 22.04), SAS 9.4 M6, R 4.3.2
- **Platform C**: macOS 13, SAS 9.4 M8, R 4.4.0

**Procedure**:
1. Execute identical pipeline on each platform
2. Compare outputs using automated comparison
3. Document any platform-specific differences

**Acceptance Criteria**:
- Identical BOR classifications across all platforms
- Floating-point differences <0.001% (acceptable rounding)
- No platform-specific code dependencies

**Test Record**:
- Date Tested: ________________
- Platforms Tested: _____ / 3
- Cross-platform concordance: _____%
- Status: ☐ Pass ☐ Fail
- Evidence: `validation/evidence/pq_005_cross_platform.html`

---

## 3. Overall PQ Assessment

### 3.1 PQ Test Summary

| Test ID | Test Description | Critical | Status | Tester | Date |
|---------|------------------|----------|--------|--------|------|
| PQ-001 | Comprehensive dataset | Yes | ☐ P ☐ F | ______ | ____ |
| PQ-002 | Reproducibility | Yes | ☐ P ☐ F | ______ | ____ |
| PQ-003 | Performance benchmark | No | ☐ P ☐ F | ______ | ____ |
| PQ-004 | Data quality handling | No | ☐ P ☐ F | ______ | ____ |
| PQ-005 | Cross-platform | No | ☐ P ☐ F | ______ | ____ |

### 3.2 Performance Qualification Status

**Overall PQ Status**: ☐ PASS ☐ FAIL ☐ PASS WITH DEVIATIONS

**Acceptance Criteria**:
- ✅ All critical tests (PQ-001, PQ-002) must pass
- ✅ ≥80% of non-critical tests pass
- ✅ System demonstrates fitness for intended use
- ✅ Performance meets user requirements

**Deviations and Justifications**:
(Document any test failures with impact assessment and mitigation)

---

## 4. Validation Summary Report

### 4.1 System Fitness for Purpose

Based on PQ test results, the RECIST 1.1 Derivation Pipeline:
- ☐ **IS** validated for use in regulatory submissions
- ☐ **IS NOT** validated (specify corrective actions required)

### 4.2 Known Limitations
1. _______________________________________
2. _______________________________________

### 4.3 User Training Requirements
- Understanding of RECIST 1.1 criteria
- SAS programming proficiency
- CDISC SDTM/ADaM standards knowledge

---

## 5. Signature and Approval

**Validation Lead**: ________________________________ Date: ________  
**Quality Assurance Manager**: ________________________________ Date: ________  
**Study Director/Sponsor Representative**: ________________________________ Date: ________  
**Regulatory Affairs (if required)**: ________________________________ Date: ________

---

## 6. References

1. FDA Guidance: Process Validation - General Principles and Practices (2011)
2. GAMP 5: A Risk-Based Approach to Compliant GxP Computerized Systems (2008)
3. Eisenhauer EA, et al. RECIST 1.1. Eur J Cancer. 2009;45(2):228-247
4. 21 CFR Part 11: Electronic Records; Electronic Signatures

---

**End of Performance Qualification Protocol**