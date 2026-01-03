# Level 4: BDS Structure Macros

## Overview

Level 4 macros finalize the ADTR dataset by adding CDISC ADaM BDS (Basic Data Structure) compliance variables:

- **PARCAT1/2/3**: Parameter categorization for data organization
- **CRIT1-4 + flags**: RECIST 1.1 algorithm criterion documentation
- **ANL01FL-04FL**: Analysis subset flags (Safety, Efficacy, PP, Best Response)
- **SRCDOM/SRCVAR/SRCSEQ**: SDTM source traceability

## Files

### 1. add_parcat_vars.sas
**Purpose**: Add CDISC parameter categorization (PARCAT1/2/3)

**Logic**:
- **PARCAT1**: Data structure level
  - "INDIVIDUAL LESION" (LDIAM)
  - "SUM OF DIAMETERS" (SDIAM, SNTLDIAM)
- **PARCAT2**: Lesion type or organ system
  - LDIAM: Organ system from TU.TULOCCAT
  - SDIAM: "TARGET LESIONS"
  - SNTLDIAM: "NON-TARGET LESIONS"
- **PARCAT3**: Detailed classification
  - LDIAM: Specific location + TARGET/NON-TARGET

**Inputs**:
- ADTR with PARAMCD, PARAM
- TU domain with TULOCCAT (organ), TULOC (location), TUTESTCD/TUSTRESC (classification)

**Research**: CDISC ADaM Guide 2026

---

### 2. add_crit_flags.sas
**Purpose**: Add RECIST 1.1 criterion flags (CRIT1-4 + CRIT1FL-4FL)

**Algorithm**:
- **CRIT1**: Standard RECIST 1.1 PD
  - TARGET lesions: ≥20% increase from nadir AND ≥5mm absolute increase
- **CRIT2**: New lesions
  - Unequivocal new lesion(s) detected post-baseline (automatic PD)
- **CRIT3**: Enaworu 25mm nadir rule (optional)
  - Nadir ≥25mm: Only 20% increase required
  - Nadir <25mm: Only 5mm absolute increase required
- **CRIT4**: Non-target progression
  - Unequivocal progression of existing non-target lesion(s)

**Inputs**:
- ADTR with BASE, NADIR, AVAL, AVALC
- New lesion detection dataset (NEW_LESION_FL)

**Parameters**:
- `enaworu_rule=Y`: Enable Enaworu 25mm rule (default=Y)

**Validation**: All CRIT=Y must have AVALC containing "PD" or "PROGRESS"

**Research**: CDISC KB 2024, Enaworu et al. Cureus 2025 (PMC12094296)

---

### 3. add_anl_flags.sas
**Purpose**: Add analysis subset flags (ANL01FL-ANL04FL)

**Flags**:
- **ANL01FL**: Safety analysis set
  - SAFFL='Y' AND ADY ≥ 1 (post-baseline)
- **ANL02FL**: Efficacy evaluable set
  - ITTFL='Y' AND has baseline measurement
- **ANL03FL**: Per-protocol set
  - PPROTFL='Y' AND baseline AND post-baseline
- **ANL04FL**: Best confirmed response
  - Minimum AVAL per subject-parameter (best response)
  - Must be in efficacy set (ANL02FL='Y')

**Inputs**:
- ADTR with BASE, AVAL, ADY
- ADSL with SAFFL, ITTFL, PPROTFL

**Validation**: ANL04FL should be unique per subject-parameter

---

### 4. add_source_trace.sas
**Purpose**: Add SDTM source traceability (SRCDOM, SRCVAR, SRCSEQ)

**Traceability Rules**:
| PARAMCD | SRCDOM | SRCVAR | SRCSEQ | Notes |
|---------|--------|--------|--------|-------|
| LDIAM | TR | TRSTRESN | TRSEQ | 1:1 link to TR record |
| SDIAM | TR | TRSTRESN | . | Multiple TR records (max 5) |
| SNTLDIAM | TR | TRSTRESN | . | Multiple TR records |
| BASE | ADTR | AVAL | . | Derived from ADTR.AVAL |
| NADIR | ADTR | AVAL | . | Minimum AVAL (ADY≥1) |
| CHG | ADTR | AVAL - BASE | . | Change formula |
| PCHG | ADTR | (AVAL-BASE)/BASE*100 | . | Percent change formula |

**Outputs**:
- ADTR with SRCDOM, SRCVAR, SRCSEQ
- _trace_documentation: ADRG (Analysis Data Reviewer Guide) table

**Validation**: LDIAM must have SRCSEQ=TRSEQ

**Research**: PharmaSUG 2025-DS-065

---

## Integration Wrapper

**File**: `finalize_adtr_bds.sas`

**Purpose**: Execute all 4 Level 4 macros in sequence with QC checkpoints

**Usage**:
```sas
/* After Level 1-3 macros complete */
%include "macros/level4_bds_structure/finalize_adtr_bds.sas";

%finalize_adtr_bds(
    input_ds=work.adtr,
    output_ds=work.adtr_final,
    adsl_ds=work.adsl,
    tu_ds=work.tu,
    new_lesion_ds=work.new_lesions,
    enaworu_rule=Y
);
```

**Execution Order**:
1. add_parcat_vars → PARCAT1/2/3
2. add_crit_flags → CRIT1-4 (uses PARCAT2 for non-target)
3. add_anl_flags → ANL01FL-04FL
4. add_source_trace → SRCDOM/SRCVAR/SRCSEQ

---

## Dependencies

**Level 1-3 Macros** (must run first):
- Level 1: Utility macros (data prep)
- Level 2: Baseline/nadir derivations (BASE, NADIR)
- Level 3: Parameter creation (LDIAM, SDIAM, SNTLDIAM with PARAMCD, AVAL, AVALC)

**SDTM Domains**:
- TR: Tumor Results (TRSTRESN, TRSEQ)
- TU: Tumor Identification (TULOCCAT, TULOC, TUTESTCD, TUSTRESC)

**ADaM Datasets**:
- ADSL: Subject-Level (SAFFL, ITTFL, PPROTFL)

---

## QC Validation

Each macro includes:
- **PROC FREQ**: Distribution reports
- **PROC SQL**: Validation checks
- **PUT statements**: Execution logging
- **Automatic warnings**: Flag inconsistencies

**Example QC Outputs**:
```
QC: PARCAT Variable Distribution
QC: CRIT Flag Distribution (Post-Baseline)
QC: Subject Counts by Analysis Set and Parameter
QC: Source Traceability by Parameter
```

---

## Research Citations

1. **CDISC ADaM Implementation Guide 2026**
   - Parameter categorization (PARCAT) structure
   - https://intuitionlabs.ai/articles/cdisc-sdtm-adam-guide

2. **CDISC Knowledge Base 2024**
   - ADaM BDS using CRIT variables
   - https://www.cdisc.org/kb/examples/adam-basic-data-structure-bds-using-crit

3. **Enaworu et al., Cureus 2025**
   - 25mm nadir rule for simplified PD criteria
   - PMC12094296: https://pmc.ncbi.nlm.nih.gov/articles/PMC12094296/

4. **PharmaSUG 2025-DS-065**
   - "Which ADaM Data Structure Is Most Appropriate?"
   - Source traceability best practices
   - https://pharmasug.org/proceedings/2025/DS/PharmaSUG-2025-DS-065.pdf

---

## Expected Output

**Final ADTR Variables** (after Level 4):

**Core BDS**:
- STUDYID, USUBJID, PARAMCD, PARAM, AVAL, AVALC
- BASE, CHG, PCHG, NADIR
- ADT, ADY, VISIT, VISITNUM

**Level 4 Additions**:
- PARCAT1, PARCAT2, PARCAT3
- CRIT1, CRIT1FL, CRIT2, CRIT2FL, CRIT3, CRIT3FL, CRIT4, CRIT4FL
- ANL01FL, ANL02FL, ANL03FL, ANL04FL
- SRCDOM, SRCVAR, SRCSEQ

**Traceability**:
- TRLNKID (link to TR), TRSEQ (source sequence)

---

## Troubleshooting

### Missing PARCAT values
**Issue**: LDIAM records missing PARCAT2/3
**Solution**: Check TU domain for TULOCCAT (organ) and TULOC (location)

### CRIT validation failures
**Issue**: CRIT=Y without AVALC=PD
**Solution**: Review response derivation logic in Level 3 macros

### Multiple ANL04FL per subject
**Issue**: Best response flag appears multiple times
**Solution**: Check for tied AVAL values (same minimum)

### Missing SRCSEQ for LDIAM
**Issue**: LDIAM missing SRCSEQ linkage
**Solution**: Verify TRSEQ merge from TR domain in Level 3

---

## Testing

See `tests/test_level4_bds.sas` for unit tests covering:
- PARCAT assignment edge cases
- CRIT flag logic validation
- ANL flag population counts
- Source traceability completeness

---

## Compliance

These macros ensure:
- ✅ CDISC ADaM BDS compliance
- ✅ FDA traceability requirements (21 CFR Part 11)
- ✅ RECIST 1.1 algorithm documentation
- ✅ Analysis population reproducibility

---

**Last Updated**: 2026-01-03
**Author**: Clinical Programming Team
**Version**: 1.0.0
