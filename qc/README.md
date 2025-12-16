# QC Framework (Code Exists, Untested)

⚠️ **Status: Code complete but NOT TESTED with real data**

This directory contains R and SAS scripts for double-programming QC workflows. The code is syntactically correct but has **not been executed** with actual datasets.

## What's Here

**R-Based QC Scripts:**
- `compare_datasets.R` - diffdf-based dataset comparison (10.3KB, untested)
- `run_qc.R` - QC orchestration script (9.6KB, untested)
- `qc/r/adam/` - ADaM-specific QC functions (untested)
- `qc/r/tlf/` - TLF QC validation (untested)

**SAS-Based QC Scripts:**
- `qc/sas/compare_adsl.sas` - PROC COMPARE for ADSL (untested)
- `qc/sas/compare_adrs.sas` - PROC COMPARE for ADRS (untested)
- `qc/sas/compare_adtte.sas` - PROC COMPARE for ADTTE (untested)
- `run_sas_qc.sh` - Shell wrapper for SAS QC execution (3KB, untested)

**Supporting Infrastructure:**
- `qc/tests/` - Test directory (placeholder, no tests implemented)
- `qc/reports/` - Empty directory for QC reports (.gitkeep only)

## What This Code Would Do (If It Worked)

### Dual Programming Workflow

1. **Production programmer** creates RECIST derivations in `etl/`
2. **QC programmer** independently programs same logic
3. **Automated comparison** flags discrepancies between outputs

### R-Based Comparison (diffdf)

```r
# Theoretical usage (untested)
source("qc/compare_datasets.R")

result <- compare_datasets(
  prod_path = "outputs/adam/adrs.sas7bdat",
  qc_path = "outputs/qc/adrs.sas7bdat",
  keys = c("USUBJID", "PARAMCD", "AVISIT")
)

print(result$summary)  # Would show PASS/FAIL
```

### SAS-Based Comparison (PROC COMPARE)

```bash
# Theoretical usage (untested)
./qc/run_sas_qc.sh

# Would generate:
# - HTML comparison reports
# - Discrepancy frequency tables
# - Pass/fail status
```

## Current Limitation

**No QC datasets available.** To test this framework would require:

1. Create production ADRS output from demo data
2. Independently program same derivations
3. Run comparison scripts
4. Validate output reports are generated
5. Verify discrepancies are correctly flagged

**Estimated effort:** 10-15 hours to create test datasets and validate comparison outputs.

## For Working QC Validation

See: [demo/simple_recist_demo.sas](../demo/simple_recist_demo.sas)

This includes **embedded QC validation** with 3 test subjects:

```sas
/* QC Validation: Verify BOR distribution */
PROC FREQ DATA=work.bor_results;
  TABLES BOR / NOCUM;
  TITLE "QC Check: Best Overall Response Distribution";
RUN;

/* Expected output:
   BOR    Frequency   Percent
   CR     1           33.33
   PD     1           33.33
   PR     1           33.33
*/
```

This is the **only QC validation** currently working in this repository.

## What This Demonstrates

Despite being untested, this code demonstrates understanding of:
- Pharmaceutical double-programming standards
- R `diffdf` package for dataset comparison
- SAS PROC COMPARE for numeric/character validation
- Automated QC report generation
- Discrepancy investigation workflows

## To Make Production-Ready

1. **Create test datasets** (3-4 hours)
   - Generate production ADRS from demo/data/test_sdtm_rs.csv
   - Independently program QC ADRS
   - Introduce intentional discrepancies for testing

2. **Execute comparison scripts** (2-3 hours)
   - Run compare_datasets.R
   - Run PROC COMPARE scripts
   - Verify reports are generated correctly

3. **Validate output format** (2-3 hours)
   - HTML reports render properly
   - Discrepancies are clearly flagged
   - Pass/fail logic works correctly

4. **Document QC procedures** (2-3 hours)
   - Create QC execution guide
   - Document discrepancy resolution workflow
   - Add QC sign-off templates

**Total estimated effort:** 10-15 hours

---

**Document Purpose:** Portfolio demonstration of QC framework knowledge  
**Implementation Status:** Code exists, untested  
**Last Updated:** December 16, 2025
