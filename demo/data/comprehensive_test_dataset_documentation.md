# Comprehensive RECIST 1.1 Test Dataset Documentation

## Overview

This 25-subject synthetic test dataset provides comprehensive coverage of RECIST 1.1 response criteria including:
- Basic response categories (CR, PR, SD, PD)
- Edge case threshold testing (borderline 30%, 20%+5mm)
- Non-target lesion integration (RECIST Table 4 logic)
- Confirmation window validation (28-84 day requirements)
- Special clinical scenarios (pseudoprogression, early death)

## Test Categories

### BASIC_RESPONSE (8 subjects)

Core response identification scenarios.

#### Subject 001-001: Partial Response (Confirmed)
**Baseline:** 100mm  
**Week 8 (Day 56):** 65mm (35% decrease)  
**Week 12 (Day 84):** 65mm (maintained)  
**Expected BOR:** PR (CONFIRMED at Day 84)

**Validation Point:** Standard PR scenario with proper confirmation window.

#### Subject 001-002: Complete Response (Confirmed)
**Baseline:** 80mm  
**Week 10 (Day 70):** 0mm (complete disappearance)  
**Week 22 (Day 154):** 0mm (maintained)  
**Expected BOR:** CR (CONFIRMED at Day 154)

**Validation Point:** Complete response with extended confirmation interval.

#### Subject 001-003: Progressive Disease
**Baseline:** 120mm  
**Week 8 (Day 56):** 120mm (stable)  
**Nadir:** 90mm (Week 4, Day 28)  
**Week 16 (Day 112):** 150mm  
**Change from nadir:** +67% (60mm absolute)  
**Expected BOR:** PD

**Validation Point:** Clear PD meeting both percentage (>20%) and absolute (>5mm) criteria.

#### Subject 001-004: Stable Disease (Maintained)
**Baseline:** 80mm  
**Week 6 (Day 42):** 78mm  
**Week 8 (Day 56):** 76mm  
**Week 12 (Day 84):** 75mm  
**Expected BOR:** SD (maintained >42 days)

**Validation Point:** SD duration requirement met (≥42 days from baseline).

#### Subject 001-005: Very Good Partial Response
**Baseline:** 120mm  
**Week 8 (Day 56):** 18mm (85% decrease)  
**Week 12 (Day 84):** 15mm (87.5% decrease)  
**Expected BOR:** PR (CONFIRMED)

**Validation Point:** Exceptional response magnitude still classified as PR (not a separate VGPR category in RECIST 1.1).

#### Subject 001-006: Mixed Response Pattern
**Baseline:** 110mm (Lesion A=50mm, B=40mm, C=20mm)  
**Week 4 (Day 28):** 90mm (Lesion A=25mm↓, B=50mm↑, C=15mm↓)  
**Net change:** -18% (insufficient for PR threshold)  
**Expected BOR:** SD

**Validation Point:** Some lesions shrink, others grow; net change determines response.

#### Subject 001-007: Unconfirmed Response Before Progression
**Baseline:** 100mm  
**Week 4 (Day 28):** 60mm (40% decrease, unconfirmed)  
**Week 8 (Day 56):** 150mm (progression before confirmation)  
**Expected BOR:** PD

**Validation Point:** Unconfirmed PR does not count as BOR if progression occurs before confirmation window closes.

#### Subject 001-008: Response Evolution Over Time
**Baseline:** 90mm  
**Week 8 (Day 56):** 85mm (SD)  
**Week 16 (Day 112):** 50mm (44% decrease = PR)  
**Week 20 (Day 140):** 45mm (PR confirmed)  
**Week 32 (Day 224):** 0mm (CR)  
**Week 40 (Day 280):** 0mm (CR confirmed)  
**Expected BOR:** CR (CONFIRMED)

**Validation Point:** Best response selected from evolving responses (CR > PR > SD).

---

### EDGE_CASE_THRESHOLD (6 subjects)

Borderline scenarios testing inclusive/exclusive threshold interpretation.

#### Subject 001-009: Borderline PR - Exactly 30% Decrease
**Baseline:** 100mm  
**Week 8 (Day 56):** 70mm (exactly 30% decrease)  
**Week 12 (Day 84):** 70mm (confirmed)  
**Expected BOR:** PR (CONFIRMED)

**Critical Validation:** RECIST 1.1 specifies "at least a 30% decrease" which is **INCLUSIVE** of exactly 30%. Implementation must use `>= 30%` not `> 30%`.

#### Subject 001-010: Borderline PD - Percentage Met, Absolute NOT Met
**Baseline:** 40mm  
**Nadir:** 30mm (Week 8)  
**Week 16:** 36mm  
**Change from nadir:** +20% (6mm absolute, but only 4mm if measured as 36-32=4 rounding)  
**Expected BOR:** SD

**Critical Validation:** PD requires **BOTH** ≥20% increase **AND** ≥5mm absolute. This is **AND logic**, not OR. If only 4mm absolute, criteria not met despite 20% relative increase.

#### Subject 001-011: Borderline PD - Both Criteria at Threshold
**Baseline:** 150mm  
**Nadir:** 100mm (Week 8)  
**Week 16:** 120mm  
**Change from nadir:** Exactly +20% (20mm absolute)  
**Expected BOR:** PD

**Critical Validation:** When both criteria exactly at threshold (20% AND ≥5mm), PD criteria ARE met. Tests inclusive threshold interpretation.

#### Subject 001-012: Minimum Lesion Size Handling
**Baseline:** Single lesion = 10mm (minimum measurable)  
**Week 8:** 6mm (40% decrease but now <10mm = non-measurable)  
**Week 12:** 0mm (disappeared)  
**Week 18:** 0mm (confirmed)  
**Expected BOR:** CR (CONFIRMED)

**Critical Validation:** Lesions <10mm are non-measurable and contribute 0mm to SLD (not 5mm by convention). If single lesion shrinks <10mm, SLD=0 = CR.

#### Subject 001-013: Target Lesion Selection (Max 5, Max 2/Organ)
**Baseline:** 8 lesions present  
- Liver A: 45mm, Liver B: 40mm, Liver C: 28mm  
- Lung A: 38mm, Lung B: 35mm  
- Lymph A: 32mm, Lymph B: 25mm, Lymph C: 20mm  
**Correct selection:** 5 largest = 45+40+38+35+32 = 190mm (max 2 per organ)  
**Incorrect selection:** 45+40+38+35+28 = 186mm (3 liver lesions violates rule)  
**Expected Baseline SLD:** 190mm  
**Expected BOR:** SD (maintained)

**Critical Validation:** Correct lesion selection logic (max 5 total, max 2 per organ).

#### Subject 001-014: Confirmation Window - Exactly 28 Days
**Baseline:** 100mm  
**Day 28:** 65mm (35% decrease)  
**Day 56:** 65mm (confirmed exactly 28 days after initial response)  
**Expected BOR:** PR (CONFIRMED)

**Critical Validation:** RECIST specifies "not less than 4 weeks" = ≥28 days. Confirmation at exactly 28 days IS valid. Implementation must use `>= 28` not `> 28`.

#### Subject 001-015: Confirmation Window - Only 27 Days
**Baseline:** 100mm  
**Day 27:** 60mm (40% decrease)  
**Day 60:** 150mm (progression)  
**Expected BOR:** PD

**Critical Validation:** Response at Day 27 cannot be confirmed (needs ≥28 days). If progression occurs before valid confirmation, BOR = PD.

---

### NONTARGET_INTEGRATION (4 subjects)

RECIST 1.1 Table 4 logic: Overall response determination.

#### Subject 001-016: Target CR + Non-target CR = Overall CR
**Target lesions:** Baseline 80mm → Week 12: 0mm (CR)  
**Non-target lesions:** Baseline PRESENT → Week 12: ABSENT (CR)  
**New lesions:** NONE  
**Expected Overall Response:** CR (CONFIRMED at Week 18)  
**RECIST Table 4:** Row 1

#### Subject 001-017: Target CR + Non-target Stable = Overall PR
**Target lesions:** Baseline 70mm → Week 12: 0mm (CR)  
**Non-target lesions:** Baseline PRESENT → Week 12: PRESENT (non-CR/non-PD)  
**New lesions:** NONE  
**Expected Overall Response:** PR (CONFIRMED)  
**RECIST Table 4:** Row 2  
**Rationale:** Non-target persistence downgrades overall response from CR to PR

#### Subject 001-018: Target PR + Non-target PD = Overall PD
**Target lesions:** Baseline 100mm → Week 8: 60mm (40% decrease = PR)  
**Non-target lesions:** Baseline STABLE → Week 8: UNEQUIVOCAL PROGRESSION  
**Expected Overall Response:** PD  
**RECIST Table 4:** Any PD component = Overall PD

#### Subject 001-019: New Lesion = Automatic PD
**Target lesions:** Baseline 90mm → Week 8: 50mm (44% decrease = PR)  
**Non-target lesions:** STABLE  
**New lesions:** Week 8 - new liver metastasis detected  
**Expected Overall Response:** PD  
**RECIST Table 4:** New lesion overrides all favorable responses

---

### DURATION_TESTING (4 subjects)

Confirmation window and duration requirement boundary testing.

#### Subject 001-020: SD - Exactly 42 Days (Minimum)
**Baseline:** 80mm (Day 0)  
**Day 42:** 78mm (SD maintained exactly 42 days)  
**Day 56:** 76mm  
**Expected BOR:** SD  
**Validation:** SD requires ≥42 days from baseline. Exactly 42 days IS sufficient.

#### Subject 001-021: SD - Only 41 Days (Insufficient)
**Baseline:** 85mm (Day 0)  
**Day 41:** 82mm (SD only 41 days)  
**Day 50:** 110mm (PD)  
**Expected BOR:** PD  
**Validation:** SD <42 days does not qualify as BOR. If progression occurs, BOR = PD.

#### Subject 001-022: CR Confirmation at 84 Days (Maximum)
**Baseline:** 100mm  
**Week 12 (Day 84):** 0mm (CR)  
**Week 24 (Day 168):** 0mm (confirmed exactly 84 days after initial CR)  
**Expected BOR:** CR (CONFIRMED)  
**Validation:** Maximum confirmation interval is 84 days per protocol. Confirmation at exactly 84 days IS valid.

#### Subject 001-023: Pseudoprogression Pattern
**Baseline:** 110mm  
**Week 8 (Day 56):** 145mm (32% increase = PD by RECIST)  
**Week 16 (Day 112):** 70mm (36% decrease from baseline = PR)  
**Expected BOR (RECIST 1.1):** PD  
**Expected BOR (iRECIST):** iUPD → iPR (confirmed progression requires next timepoint)  
**Validation:** RECIST 1.1 calls this PD. iRECIST would require confirmation.

---

### SPECIAL_SCENARIOS (3 subjects)

Complex real-world clinical situations.

#### Subject 001-024: Best Response Before Non-PD Death
**Baseline:** 120mm  
**Week 8:** 75mm (38% decrease = PR)  
**Week 16:** 70mm (PR confirmed)  
**Week 20:** Death (non-PD cause: infection)  
**Expected BOR:** PR (CONFIRMED)  
**Validation:** Death does not change prior best response. BOR = best confirmed response before death.

#### Subject 001-025: Non-Evaluable (Inadequate Follow-up)
**Baseline:** 95mm  
**Week 4:** Lost to follow-up (no further scans)  
**Expected BOR:** NE (Non-Evaluable)  
**Validation:** Insufficient data for response determination.

---

## Implementation Notes

### Key Testing Objectives

1. **Threshold Interpretation:** Verify inclusive (≥) vs exclusive (>) operators
2. **AND Logic:** Confirm PD requires both percentage AND absolute criteria
3. **Confirmation Windows:** Validate 28-84 day boundaries (inclusive)
4. **Duration Requirements:** Verify SD ≥42 days from baseline
5. **Table 4 Logic:** Confirm correct prioritization (PD > CR > PR > SD)
6. **Lesion Selection:** Validate max 5 target, max 2 per organ
7. **Non-Measurable Handling:** Verify <10mm lesions contribute 0mm to SLD

### Expected Validation Workflow

```sas
/* Run RECIST derivations on comprehensive test data */
%derive_target_lesion_response(inds=testdata.comprehensive_rs, ...);
%derive_best_overall_response(inds=work.adrs_target, ...);

/* Compare actual vs expected BOR */
proc compare base=testdata.expected_bor 
             compare=work.actual_bor
             out=work.discrepancies;
    id USUBJID;
    var BOR CONFIRMATION;
run;

/* Generate validation report */
/* Expected: 0 discrepancies = 100% pass rate */
```

### Industry Context

This test suite addresses RECIST 1.1 variability challenges documented in:
- **Iannessi A et al. (EJNMMI 2024):** "RECIST assessment variability requires rigorous validation"
- **Dahm IC et al. (Radiology 2024):** "Edge case interpretation differences between radiologists"

Comprehensive test coverage demonstrates specification-level expertise critical for senior statistical programmer roles in oncology.

---

**Test Suite Version:** 1.0  
**Last Updated:** December 29, 2025  
**Created By:** Christian Baghai  
**Purpose:** Production-ready RECIST 1.1 validation demonstrating pharmaceutical programming standards