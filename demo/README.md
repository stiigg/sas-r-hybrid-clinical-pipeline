# RECIST 1.1 Core Derivation Demo

## Purpose

This demo showcases the RECIST 1.1 core derivation macros using minimal synthetic test data. It demonstrates:

1. **Target lesion response derivation**: SLD calculation and threshold-based categorization
2. **Overall timepoint response integration**: RECIST 1.1 Table 4 logic (simplified)
3. **Best Overall Response derivation**: Confirmation logic and subject-level summarization

## Test Subjects

The demo includes 3 synthetic subjects with distinct response patterns:

| Subject | Baseline SLD | Week 8 SLD | Week 16 SLD | % Change | Expected BOR |
|---------|--------------|------------|-------------|----------|-------------|
| 001-001 | 55mm | 33mm (-40%) | 22mm (-60%) | -60% | **PR** (confirmed) |
| 001-002 | 75mm | 0mm (-100%) | 0mm (-100%) | -100% | **CR** (confirmed) |
| 001-003 | 95mm | 126mm (+33%) | -- | +33% | **PD** (early progression) |

### Response Pattern Details

**Subject 001-001 (Partial Response)**:
- Target lesions: 2 lesions at baseline (25mm + 30mm = 55mm)
- Week 8: Shrinkage to 33mm (-40% from baseline)
- Week 16: Further shrinkage to 22mm (-60% from baseline, meets PR threshold)
- Confirmation: 56-day interval between assessments meets 28-84 day window
- **Result**: PR confirmed

**Subject 001-002 (Complete Response)**:
- Target lesions: 2 lesions at baseline (40mm + 35mm = 75mm)
- Week 8: Complete disappearance (SLD = 0mm)
- Week 16: Remains at 0mm (confirmation of CR)
- Confirmation: 56-day interval confirms sustained response
- **Result**: CR confirmed

**Subject 001-003 (Progressive Disease)**:
- Target lesions: 2 lesions at baseline (50mm + 45mm = 95mm)
- Week 8: Progression to 126mm (+33% from nadir, +31mm absolute increase)
- Meets PD criteria: ≥20% increase AND ≥5mm absolute increase
- **Result**: PD (unconfirmed, early progression)

## Running the Demo

### Prerequisites

- SAS 9.4 or later
- Write access to WORK library and demo/data directory
- Repository cloned to local system

### Execution

```bash
# From repository root
cd demo
sas simple_recist_demo.sas -log demo_run.log
```

### Expected Console Output

```
NOTE: ========================================
NOTE: RECIST 1.1 Core Derivation Demo
NOTE: ========================================

[Target Lesion Response Distribution]
TL_RESP    Frequency
------------------------
CR         2
PD         1  
PR         2
SD         1

[Best Overall Response Distribution]
BOR        Frequency
------------------------
CR         1
PD         1
PR         1

NOTE: Demo completed successfully!
NOTE: Output dataset: demo.adrs_bor
```

## Output Dataset

The demo produces `demo.adrs_bor` (and `work.adrs_bor`) with these key variables:

| Variable | Label | Type | Example Values |
|----------|-------|------|----------------|
| USUBJID | Subject Identifier | Char | 001-001, 001-002, 001-003 |
| BOR | Best Overall Response | Char | CR, PR, PD |
| BORN | BOR Numeric Code | Num | 1=CR, 2=PR, 3=SD, 4=PD |
| BORDT | Date of BOR | Date | 2024-04-23 |
| BORCONF | BOR Confirmed (Y/N) | Char | Y, N |
| BOR_SRC | Basis for BOR | Char | Explanatory text |

## Validation

### Manual Validation

Compare the demo output to expected results:

```sas
proc import datafile="demo/data/expected_bor.csv"
    out=work.expected
    dbms=csv
    replace;
run;

proc compare base=work.expected 
             compare=work.adrs_bor
             out=work.differences
             outnoequal;
    id USUBJID;
    var BOR BORDT BORCONF BORN;
run;
```

**Expected result**: No differences (PROC COMPARE should report 0 observations with differences).

### Expected Values Summary

```
USUBJID   BOR   BORDT       BORCONF  BORN
------------------------------------------
001-001   PR    2024-04-23  Y        2
001-002   CR    2024-04-26  Y        1  
001-003   PD    2024-03-07  N        4
```

## Interpreting Results

### Target Lesion Responses (Intermediate Output)

The `work.adrs_tl` dataset shows visit-level target lesion assessments:

- Each row represents one visit assessment
- `TL_SLD`: Sum of longest diameters at that visit
- `TL_PCHG_BASE`: Percent change from baseline
- `TL_PCHG_NAD`: Percent change from nadir (running minimum)
- `TL_RESP`: Visit-level response category

### Best Overall Response Logic

The BOR macro applies these RECIST 1.1 rules:

1. **CR**: Target SLD = 0, confirmed ≥28 days later
2. **PR**: ≥30% decrease from baseline, confirmed ≥28 days later
3. **SD**: Neither PR nor PD criteria met, ≥42 days from baseline
4. **PD**: ≥20% increase from nadir AND ≥5mm absolute increase

Confirmation window: 28-84 days between initial response and confirmation assessment.

## Extending the Demo

To test additional scenarios:

### 1. Add More Test Subjects

Edit `demo/data/test_sdtm_rs.csv` to add subjects:
- Use USUBJID format: 001-004, 001-005, etc.
- Include baseline (ABLFL='Y') and follow-up assessments
- Ensure RSDY and RSDTC values are consistent

### 2. Test Edge Cases

Create test subjects demonstrating:
- Confirmation window boundaries (day 27 vs 28, day 84 vs 85)
- Unconfirmed responses (progression before confirmation)
- SD with insufficient duration (<42 days)
- Missing assessments

### 3. Add Non-Target Lesions

Create `demo/data/test_sdtm_rs_nontarget.csv` with:
- RSCAT = 'NON-TARGET'
- Qualitative assessments in RSSTRESC (PRESENT, ABSENT, PROGRESSION)
- Update demo script to call `%derive_non_target_lesion_response()`

### 4. Add New Lesions

Create `demo/data/test_sdtm_rs_newlesion.csv` with:
- RSCAT = 'NEW'
- Document new lesion detection dates
- Test automatic PD assignment

## Troubleshooting

### Common Issues

**Issue**: `ERROR: File not found`
- **Solution**: Ensure you're running from the `demo/` directory, or adjust `%let repo_root` path in the script

**Issue**: `ERROR: Numeric values have been converted to character`
- **Solution**: Check that RSSTRESC variable in CSV is properly formatted (no quotes around numbers)

**Issue**: Unexpected BOR values
- **Solution**: Review intermediate datasets:
  ```sas
  proc print data=work.adrs_tl;
  proc print data=work.adrs_timepoint;
  ```

**Issue**: No confirmation (BORCONF='N' when expected 'Y')
- **Solution**: Check visit timing - confirmation requires 28-84 day interval between assessments

## Limitations

This minimal demo:

✅ **Tests**:
- Target lesion derivations
- Confirmation logic
- Basic RECIST 1.1 response categories
- SLD calculation accuracy

❌ **Does NOT test**:
- Non-target lesions
- New lesion detection
- Post-new-therapy assessment exclusion
- Missing data handling
- Multiple same-day assessments
- Tie-breaking logic at nadir

## Next Steps

For comprehensive testing:

1. Review `../STATUS.md` for full test scenario list
2. Expand test data to 20-25 subjects covering edge cases
3. Add automated validation against expected outputs
4. Create testthat unit tests (R) or %assert macros (SAS)
5. Document discrepancy investigation procedures

## Questions?

For issues or questions about the demo:

1. **Check the log file**: `demo_run.log` contains detailed execution information
2. **Review inline comments**: `simple_recist_demo.sas` has step-by-step documentation
3. **Consult macro documentation**: `../etl/adam_program_library/oncology_response/README_ONCOLOGY.md`
4. **Check repository issues**: GitHub issues may document known limitations

## References

- Eisenhauer EA, et al. *Eur J Cancer.* 2009;45(2):228-247. [PMID: 19097774](https://pubmed.ncbi.nlm.nih.gov/19097774/)
- CDISC ADaM Implementation Guide v1.3: https://www.cdisc.org/standards/foundational/adam
- RECIST Working Group: https://recist.eortc.org/

---

**Last Updated**: December 11, 2025  
**Demo Version**: 1.0  
**Status**: Functional - Basic scenarios only
