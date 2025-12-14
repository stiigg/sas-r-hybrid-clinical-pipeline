# Operational Qualification Protocol

**System**: Clinical Trial Data Pipeline - RECIST 1.1 Module  
**Protocol Version**: 1.0  
**Date**: December 2025  
**Prepared By**: Christian Baghai  
**Regulatory Framework**: 21 CFR Part 11, ICH E6(R2)

---

## 1. Executive Summary

### 1.1 Objective
Verify that individual RECIST 1.1 derivation functions operate correctly according to specifications under defined test conditions. OQ validates that each software component performs its intended function accurately.

### 1.2 Scope
This Operational Qualification validates:
- Target lesion response classification functions
- Non-target lesion response integration
- Overall response derivation (RECIST Table 4 logic)
- Best Overall Response (BOR) calculation with confirmation
- Response threshold boundary conditions
- Confirmation window temporal logic

### 1.3 Testing Approach
**White-box testing**: Tests specific functions with known inputs and expected outputs  
**Traceability**: Each test links to user requirements and RECIST 1.1 specification

---

## 2. Test Cases

### OQ-RECIST-001: PR Classification at -30% Threshold

**Requirement ID**: UR-002  
**RECIST Reference**: Eisenhauer et al. 2009, Table 3  
**Implementation**: `derive_target_lesion_response.sas` lines 145-160  

**Objective**: Verify that target lesion reduction of exactly -30% from baseline is classified as Partial Response (PR)

**Test Data**:
```
USUBJID: TEST-PR-30
Baseline SLD: 100mm (ABLFL='Y')
Follow-up SLD: 70mm (Day 57)
Expected % change: -30.0%
Expected classification: PR
```

**Procedure**:
1. Create test SDTM RS dataset with values above
2. Execute `%derive_target_lesion_response(inds=test_data, outds=result)`
3. Verify output variables:
   - `TL_RESP = 'PR'`
   - `TL_PCHG_BASE = -30.0` (within tolerance ±0.1%)
   - `TL_SLD = 70`

**Acceptance Criteria**:
- Response correctly classified as PR
- Percent change calculation accurate to ±0.1%
- No SAS errors or warnings in log

**Test Record**:
- Date Tested: ________________
- Tested By: ________________
- Actual TL_RESP: ________________
- Actual TL_PCHG_BASE: ________________
- Status: ☐ Pass ☐ Fail ☐ N/A
- Evidence: `validation/evidence/OQ-RECIST-001.log`
- Comments: ________________________________________________

---

### OQ-RECIST-002: Below PR Threshold (-29.9%) → SD

**Requirement ID**: UR-002  
**RECIST Reference**: Eisenhauer et al. 2009, Table 3

**Objective**: Verify that -29.9% reduction does NOT meet PR criteria and is classified as SD

**Test Data**:
```
USUBJID: TEST-SD-29.9
Baseline SLD: 100mm
Follow-up SLD: 70.1mm (Day 57)
Expected % change: -29.9%
Expected classification: SD
```

**Acceptance Criteria**:
- Response classified as SD (not PR)
- Demonstrates correct threshold boundary handling

**Test Record**:
- Date Tested: ________________
- Tested By: ________________
- Status: ☐ Pass ☐ Fail
- Evidence: Linked to `tests/testthat/test-recist-boundaries.R` line 62

---

### OQ-RECIST-003: PD Requires Both +20% AND +5mm

**Requirement ID**: UR-003  
**RECIST Reference**: Eisenhauer et al. 2009, Section 4.2.1

**Objective**: Verify that Progressive Disease requires BOTH criteria:
1. ≥20% increase from nadir, AND
2. ≥5mm absolute increase

**Test Case 1**: +20% but only +4mm → Should NOT be PD
```
Nadir SLD: 20mm
Current SLD: 24mm
Percent change: +20.0%
Absolute change: +4mm
Expected: SD (fails 5mm criterion)
```

**Test Case 2**: +20% and exactly +5mm → Should be PD
```
Nadir SLD: 25mm
Current SLD: 30mm
Percent change: +20.0%
Absolute change: +5mm
Expected: PD (meets both criteria)
```

**Acceptance Criteria**:
- Test Case 1: Not classified as PD
- Test Case 2: Correctly classified as PD
- Logic correctly implements AND condition (not OR)

**Test Record**:
- Date Tested: ________________
- Test Case 1 Status: ☐ Pass ☐ Fail
- Test Case 2 Status: ☐ Pass ☐ Fail
- Evidence: `tests/testthat/test-recist-boundaries.R` lines 96-134

---

### OQ-RECIST-004: CR Requires SLD = 0

**Requirement ID**: UR-004  
**RECIST Reference**: Eisenhauer et al. 2009, Table 3

**Objective**: Complete Response requires disappearance of all target lesions (SLD = 0)

**Test Data**:
```
Baseline SLD: 50mm
Follow-up SLD: 0mm
Expected: CR
```

**Negative Test** (1mm residual):
```
Baseline SLD: 50mm
Follow-up SLD: 1mm
Expected: PR (not CR), -98%
```

**Acceptance Criteria**:
- SLD = 0 → CR
- SLD > 0 → Not CR (even if 1mm)

**Test Record**:
- Date Tested: ________________
- Status: ☐ Pass ☐ Fail
- Evidence: `tests/testthat/test-recist-boundaries.R` lines 160-184

---

### OQ-RECIST-005: Nadir Tracking for PD Assessment

**Requirement ID**: UR-006  
**RECIST Reference**: Eisenhauer et al. 2009, Section 4.2.1

**Objective**: PD is assessed from nadir (lowest previous SLD), not baseline

**Test Data**:
```
Day 1 (Baseline): SLD = 100mm
Day 57: SLD = 50mm (nadir, PR)
Day 113: SLD = 65mm
```

**Expected Calculation**:
- From nadir: (65 - 50) / 50 = +30% and +15mm absolute
- Meets PD criteria from nadir
- Even though from baseline = -35% (would be PR)

**Acceptance Criteria**:
- Nadir correctly identified as 50mm (not baseline)
- PD assessment uses nadir as reference
- Classification: PD (not PR)

**Test Record**:
- Date Tested: ________________
- Identified Nadir: ________________
- Status: ☐ Pass ☐ Fail
- Evidence: `tests/testthat/test-recist-boundaries.R` lines 208-232

---

### OQ-CONF-001: Confirmation Window - 28 Day Minimum

**Requirement ID**: UR-007  
**RECIST Reference**: Eisenhauer et al. 2009, Section 5.2

**Objective**: Response confirmation requires follow-up assessment ≥28 days after initial response

**Test Cases**:

| Initial Response | Confirmation | Interval | Expected Result |
|-----------------|--------------|----------|----------------|
| Day 57 | Day 84 | 27 days | Unconfirmed (<28) |
| Day 57 | Day 85 | 28 days | **Confirmed** (minimum) |
| Day 57 | Day 113 | 56 days | **Confirmed** (within range) |

**Acceptance Criteria**:
- 27-day interval: Response NOT confirmed
- 28-day interval: Response confirmed
- Logic enforces minimum boundary correctly

**Test Record**:
- Date Tested: ________________
- 27-day test: ☐ Pass ☐ Fail
- 28-day test: ☐ Pass ☐ Fail
- Evidence: `tests/testthat/test-recist-confirmation.R` lines 38-93

---

### OQ-CONF-002: Confirmation Window - 84 Day Maximum

**Requirement ID**: UR-007  
**RECIST Reference**: Eisenhauer et al. 2009, Section 5.2

**Test Cases**:

| Initial Response | Confirmation | Interval | Expected Result |
|-----------------|--------------|----------|----------------|
| Day 57 | Day 141 | 84 days | **Confirmed** (maximum) |
| Day 57 | Day 142 | 85 days | Unconfirmed (>84) |

**Acceptance Criteria**:
- 84-day interval: Response confirmed
- 85-day interval: Response NOT confirmed
- Logic enforces maximum boundary correctly

**Test Record**:
- Date Tested: ________________
- Status: ☐ Pass ☐ Fail
- Evidence: `tests/testthat/test-recist-confirmation.R` lines 95-153

---

### OQ-CONF-003: SD Minimum Duration (42 Days)

**Requirement ID**: UR-008  
**RECIST Reference**: Eisenhauer et al. 2009, Section 5.2

**Objective**: Stable Disease requires measurement ≥42 days from baseline to be considered confirmed

**Test Data**:
```
Day 1 (Baseline): SLD = 100mm
Day 43: SLD = 85mm (-15%, SD range)
Duration from baseline: 42 days
Expected: Confirmed SD
```

**Negative Test** (41 days):
```
Day 42: SLD = 85mm
Duration: 41 days
Expected: Unconfirmed (below 42-day threshold)
```

**Acceptance Criteria**:
- ≥42 days: SD confirmed
- <42 days: SD not confirmed

**Test Record**:
- Date Tested: ________________
- Status: ☐ Pass ☐ Fail
- Evidence: `tests/testthat/test-recist-confirmation.R` lines 155-190

---

### OQ-TABLE4-001: Overall Response Integration

**Requirement ID**: UR-009  
**RECIST Reference**: Eisenhauer et al. 2009, Table 4

**Objective**: Verify correct integration of target + non-target + new lesions per RECIST Table 4

**Test Scenarios** (subset of 12 combinations):

| Target | Non-Target | New Lesion | Expected Overall |
|--------|-----------|------------|------------------|
| CR | CR | No | CR |
| CR | Non-CR/Non-PD | No | PR |
| PR | Non-CR/Non-PD | No | PR |
| SD | Non-CR/Non-PD | No | SD |
| PD | Any | Any | PD |
| Any | PD | Any | PD |
| Any | Any | Yes | PD |

**Acceptance Criteria**:
- All Table 4 combinations correctly implemented
- PD takes precedence over other responses
- CR requires ALL components = CR

**Test Record**:
- Date Tested: ________________
- Scenarios Tested: _____ / 12
- Status: ☐ Pass ☐ Fail
- Evidence: `demo/data/comprehensive_sdtm_rs.csv` subjects 013-025

---

### OQ-NEWLES-001: New Lesion Detection

**Requirement ID**: UR-010  
**RECIST Reference**: Eisenhauer et al. 2009, Section 4.4

**Objective**: Appearance of new lesion(s) automatically results in PD classification

**Test Data**:
```
Day 57: Target = PR (-40%), New lesion detected
Expected: Overall response = PD (new lesion overrides target PR)
```

**Acceptance Criteria**:
- New lesion flag correctly detected
- Overall response = PD regardless of target/non-target status
- Date of PD = date of new lesion detection

**Test Record**:
- Date Tested: ________________
- Status: ☐ Pass ☐ Fail
- Evidence: Subjects 017-019 in comprehensive test data

---

## 3. Test Execution Summary

### 3.1 OQ Test Results

| Test ID | Test Description | Priority | Status | Tester | Date |
|---------|------------------|----------|--------|--------|------|
| OQ-RECIST-001 | PR at -30% threshold | Critical | ☐ P ☐ F | ______ | ____ |
| OQ-RECIST-002 | SD at -29.9% | High | ☐ P ☐ F | ______ | ____ |
| OQ-RECIST-003 | PD dual criteria | Critical | ☐ P ☐ F | ______ | ____ |
| OQ-RECIST-004 | CR requires SLD=0 | Critical | ☐ P ☐ F | ______ | ____ |
| OQ-RECIST-005 | Nadir tracking | High | ☐ P ☐ F | ______ | ____ |
| OQ-CONF-001 | 28-day minimum | Critical | ☐ P ☐ F | ______ | ____ |
| OQ-CONF-002 | 84-day maximum | Critical | ☐ P ☐ F | ______ | ____ |
| OQ-CONF-003 | SD 42-day duration | High | ☐ P ☐ F | ______ | ____ |
| OQ-TABLE4-001 | Table 4 integration | Critical | ☐ P ☐ F | ______ | ____ |
| OQ-NEWLES-001 | New lesion = PD | Critical | ☐ P ☐ F | ______ | ____ |

### 3.2 Overall OQ Status

**Operational Qualification Status**: ☐ PASS ☐ FAIL ☐ PASS WITH DEVIATIONS

**Acceptance Criteria**:
- All Critical priority tests must pass
- ≥90% of all tests must pass
- All failures documented with corrective action

---

## 4. Traceability

### 4.1 Requirements Coverage

OQ tests provide **forward traceability**:
- User Requirements → Functional Specifications → OQ Test Cases

### 4.2 Test Evidence

All test evidence stored in:
- Automated test results: `tests/testthat/` (R) and `tests/sas/` (SAS)
- Manual test logs: `validation/evidence/OQ-*.log`
- Test data: `demo/data/comprehensive_sdtm_rs.csv`

---

## 5. Signature and Approval

**Tester**: ________________________________ Date: ________  
**Developer**: ________________________________ Date: ________  
**QA Reviewer**: ________________________________ Date: ________

---

**End of Operational Qualification Protocol**