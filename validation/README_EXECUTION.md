# Validation Execution Quick Start

**Purpose**: Step-by-step guide to execute complete validation  
**Time Required**: 4-6 hours (first time), 2-3 hours (subsequent runs)  
**Prerequisites**: R, SAS (optional), Git

---

## Quick Execution (Automated)

For automated validation execution:

```bash
# Make script executable
chmod +x validation/run_all_validation.sh

# Run complete validation suite
./validation/run_all_validation.sh
```

This script executes all IQ/OQ/PQ tests automatically and generates a summary report.

**Output**: `validation/evidence/validation_run_YYYYMMDD_HHMMSS_summary.txt`

---

## Manual Execution (Step-by-Step)

### Phase 1: Installation Qualification (30 minutes)

#### Step 1.1: R Environment Check

```bash
Rscript validation/scripts/check_r_env.R
```

**Expected Output**: `PASS` with all packages installed  
**Evidence**: `validation/evidence/iq_002_r_env_check.txt`

**If FAIL**:
- Install missing R packages: `install.packages(c("admiral", "dplyr", "haven", "testthat", "diffdf", "yaml", "lubridate"))`
- Re-run check

#### Step 1.2: File Structure Check

```bash
Rscript validation/scripts/check_file_structure.R
```

**Expected Output**: `PASS` with all critical files present  
**Evidence**: `validation/evidence/iq_004_file_structure_check.txt`

**If FAIL**:
- Ensure all required files are committed to Git
- Check that you're in the repository root directory

#### Step 1.3: SAS Environment Check (Optional)

```bash
sas validation/scripts/check_sas_env.sas
```

**Expected Output**: `PASS` with SAS 9.4 M6+ and PROC COMPARE available  
**Evidence**: `validation/evidence/iq_003_sas_env_check.txt`

**If FAIL**:
- Verify SAS/STAT license is active
- Check SAS version meets minimum requirements

#### Step 1.4: Document IQ Results

1. Open `validation/iq_protocol.md`
2. Fill in actual test results in test record sections
3. Attach evidence files
4. Obtain tester and reviewer sign-offs

---

### Phase 2: Operational Qualification (1-2 hours)

#### Step 2.1: Run Unit Tests

```bash
Rscript tests/run_all_tests.R
```

**Expected Output**: All tests pass  
**Evidence**: Console output + testthat results

**If FAIL**:
- Review test failures in console output
- Document discrepancies in `validation/evidence/issue_resolution_log.csv`
- Fix code or adjust test expectations
- Re-run tests

#### Step 2.2: Document OQ Results

1. Open `validation/oq_protocol.md`
2. For each test case:
   - Record execution date and tester
   - Mark PASS/FAIL status
   - Link to test evidence
3. Calculate pass rate (must be ≥90% overall, 100% for critical tests)
4. Obtain sign-offs

---

### Phase 3: Performance Qualification (2-3 hours)

#### Step 3.1: Run Integration Test

```bash
Rscript tests/integration/test_end_to_end_pipeline.R
```

**Note**: This test requires actual pipeline implementation. Update the script with your pipeline execution code.

**Expected Output**: 100% BOR concordance with expected results  
**Evidence**: `validation/evidence/pq_001_integration_test.txt`

#### Step 3.2: Reproducibility Test (PQ-002)

Run pipeline 3 times and verify identical outputs:

```bash
# Run 1
sas demo/run_comprehensive_test.sas -log logs/pq_run1.log
cp outputs/adam/adrs.sas7bdat outputs/pq_run1_adrs.sas7bdat

# Run 2
sas demo/run_comprehensive_test.sas -log logs/pq_run2.log
cp outputs/adam/adrs.sas7bdat outputs/pq_run2_adrs.sas7bdat

# Run 3
sas demo/run_comprehensive_test.sas -log logs/pq_run3.log
cp outputs/adam/adrs.sas7bdat outputs/pq_run3_adrs.sas7bdat

# Verify identical outputs
md5sum outputs/pq_run*_adrs.sas7bdat
```

**Expected**: All MD5 checksums identical

#### Step 3.3: Document PQ Results

1. Open `validation/pq_protocol.md`
2. Document PQ-001 through PQ-005 test results
3. Record BOR concordance rate
4. Attach evidence files
5. Obtain sign-offs

---

### Phase 4: QC Validation (1 hour)

#### Step 4.1: Run R-Based QC

```r
source("qc/r/automated_comparison.R")

# Compare ADSL
compare_datasets(
  prod_path = "outputs/adam/adsl.sas7bdat",
  qc_path = "outputs/qc/adsl.sas7bdat",
  keys = "USUBJID"
)

# Compare ADRS
compare_datasets(
  prod_path = "outputs/adam/adrs.sas7bdat",
  qc_path = "outputs/qc/adrs.sas7bdat",
  keys = c("USUBJID", "PARAMCD", "AVISIT")
)

# Compare ADTTE
compare_datasets(
  prod_path = "outputs/adam/adtte.sas7bdat",
  qc_path = "outputs/qc/adtte.sas7bdat",
  keys = c("USUBJID", "PARAMCD")
)
```

**Expected**: Zero discrepancies  
**Evidence**: HTML reports in `outputs/qc_reports/`

#### Step 4.2: Run SAS-Based QC

```bash
# Run all SAS QC comparisons
./qc/run_sas_qc.sh

# Or run individually
sas qc/sas/compare_adsl.sas
sas qc/sas/compare_adrs.sas
sas qc/sas/compare_adtte.sas
```

**Expected**: All comparisons PASS  
**Evidence**: HTML reports in `outputs/qc_reports/`

---

### Phase 5: CDISC Compliance (2-3 hours)

#### Step 5.1: Export to XPT Format

```bash
sas validation/pinnacle21/prepare_xpt_export.sas
```

**Expected**: XPT files created in `validation/pinnacle21/xpt_files/`

#### Step 5.2: Execute Pinnacle 21 Validation

Follow detailed guide: `validation/pinnacle21/validation_checklist.md`

**Key Steps**:
1. Open Pinnacle 21 Community
2. Load XPT files and define.xml
3. Execute ADaM validation
4. Review errors/warnings
5. Iterate until clean validation (0 critical errors)

**Expected**: Zero critical errors (red flags)  
**Evidence**: `validation/pinnacle21/reports/p21_validation_YYYYMMDD.html`

---

### Phase 6: Generate Validation Summary (1 hour)

#### Step 6.1: Generate Test Coverage Report

```bash
Rscript validation/scripts/generate_coverage_report.R
```

**Expected**: Coverage ≥80%  
**Evidence**: `validation/test_coverage_report.html`

#### Step 6.2: Complete Validation Summary Report

1. Open `validation/validation_summary_report.md`
2. Fill in all test results:
   - IQ: 6 test cases
   - OQ: 10 test cases
   - PQ: 5 test cases
3. Document QC results (R and SAS)
4. Document Pinnacle 21 results
5. Summarize issues from `issue_resolution_log.csv`
6. Fill in coverage metrics
7. Obtain all sign-offs:
   - Validation Lead
   - QA Manager
   - Study Director
   - Regulatory Affairs (if required)

---

## Validation Checklist

Use this checklist to track validation progress:

### Installation Qualification
- [ ] IQ-001: R Version Verification
- [ ] IQ-002: R Package Installation
- [ ] IQ-003: SAS Installation
- [ ] IQ-004: File Structure Integrity
- [ ] IQ-005: SAS Autocall Configuration
- [ ] IQ-006: Git Version Control
- [ ] IQ Protocol signed off

### Operational Qualification
- [ ] OQ-RECIST-001: PR at -30%
- [ ] OQ-RECIST-002: SD boundary
- [ ] OQ-RECIST-003: PD dual criteria
- [ ] OQ-RECIST-004: CR = SLD 0
- [ ] OQ-RECIST-005: Nadir tracking
- [ ] OQ-CONF-001: 28-day minimum
- [ ] OQ-CONF-002: 84-day maximum
- [ ] OQ-CONF-003: SD 42-day duration
- [ ] OQ-TABLE4-001: Table 4 integration
- [ ] OQ-NEWLES-001: New lesion = PD
- [ ] OQ Protocol signed off

### Performance Qualification
- [ ] PQ-001: Comprehensive dataset (25 subjects)
- [ ] PQ-002: Reproducibility (3 runs)
- [ ] PQ-003: Performance benchmarks
- [ ] PQ-004: Data quality handling
- [ ] PQ-005: Cross-platform validation
- [ ] PQ Protocol signed off

### QC Validation
- [ ] R QC: ADSL comparison
- [ ] R QC: ADRS comparison
- [ ] R QC: ADTTE comparison
- [ ] SAS QC: ADSL comparison
- [ ] SAS QC: ADRS comparison
- [ ] SAS QC: ADTTE comparison
- [ ] All QC comparisons PASS

### CDISC Compliance
- [ ] XPT files exported
- [ ] Define.xml prepared
- [ ] Pinnacle 21 validation executed
- [ ] Zero critical errors achieved
- [ ] Warnings documented and justified
- [ ] Validation report archived

### Documentation
- [ ] Test coverage report generated (≥80%)
- [ ] Issue resolution log complete
- [ ] Validation summary report complete
- [ ] All evidence files archived
- [ ] All protocols signed off
- [ ] Final approval obtained

---

## Troubleshooting

### Common Issues

#### "R package not found"
**Solution**: Install missing package:
```r
install.packages("package_name")
```

#### "SAS not found in PATH"
**Solution**: Add SAS to your PATH or run from SAS directory

#### "File structure check fails"
**Solution**: Ensure you're in repository root: `cd /path/to/sas-r-hybrid-clinical-pipeline`

#### "Unit tests fail"
**Solution**:
1. Review test output to identify failing test
2. Document in `validation/evidence/issue_resolution_log.csv`
3. Fix code or adjust test expectations
4. Re-run tests
5. Document resolution

#### "Pinnacle 21 shows critical errors"
**Solution**: Follow `validation/pinnacle21/validation_checklist.md` error resolution guide

---

## Time Estimates

| Phase | First Time | Subsequent Runs |
|-------|------------|----------------|
| IQ | 30 min | 10 min |
| OQ | 2 hours | 30 min |
| PQ | 3 hours | 1 hour |
| QC | 1 hour | 30 min |
| Pinnacle 21 | 3 hours | 1 hour |
| Documentation | 2 hours | 30 min |
| **Total** | **~12 hours** | **~4 hours** |

---

## Support

For validation questions:
- Review `validation/README.md` for detailed guidance
- Check `validation/evidence/issue_resolution_log.csv` for known issues
- Consult protocol documents (IQ/OQ/PQ)

---

**Last Updated**: December 14, 2025
