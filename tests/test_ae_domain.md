# AE Domain Testing Checklist

## Pre-Test Setup

### Required Files
- [ ] DM domain exists: `data/csv/dm.csv`
- [ ] Raw AE data exists: `data/raw/adverse_events_raw.csv`
- [ ] SAS program exists: `sdtm/programs/sas/30_sdtm_ae.sas`

### Directory Structure
- [ ] `data/csv/` directory exists
- [ ] `data/xpt/` directory exists
- [ ] `logs/` directory exists
- [ ] `docs/` directory exists

## Execution Test

### Run Program
- [ ] Execute: `%include "sdtm/programs/sas/30_sdtm_ae.sas";`
- [ ] Program completes without SAS errors
- [ ] Log file created: `logs/30_sdtm_ae.log`
- [ ] Check for "Program completed successfully" message in log

### Execution Time
- [ ] Program runtime < 30 seconds (for test data)
- [ ] No infinite loops or hangs

## Output Validation

### File Creation
- [ ] `data/csv/ae.csv` created
- [ ] `data/csv/suppae.csv` created
- [ ] `data/xpt/ae.xpt` created
- [ ] `data/xpt/suppae.xpt` created
- [ ] All files have non-zero size

### Record Counts
- [ ] AE records: Expected = 15 (actual: _____ )
- [ ] SUPPAE records: Expected = 15 (actual: _____ )
- [ ] Subjects with AEs: Expected = 8 (actual: _____ )
- [ ] Counts match between CSV and XPT files

### Variable Counts
- [ ] AE domain: 30 variables (not 13)
- [ ] SUPPAE domain: 10 variables
- [ ] No unexpected variables present
- [ ] All expected variables present

## Data Quality Checks

### Required Variables
- [ ] All records have STUDYID populated
- [ ] All records have DOMAIN = "AE"
- [ ] All records have USUBJID populated
- [ ] All records have AESEQ > 0
- [ ] All records have AETERM populated

### MedDRA Coding
- [ ] All AEs have AEDECOD (Preferred Term)
- [ ] All AEs have AEPTCD (PT Code)
- [ ] All AEs have AEBODSYS (Body System)
- [ ] All AEs have AESOC (System Organ Class)
- [ ] AESOC = AEBODSYS for all records
- [ ] No records with missing MedDRA codes

### Seriousness Criteria
- [ ] AESER present for all records
- [ ] 3 records with AESER='Y' (serious events)
- [ ] 12 records with AESER='N' (non-serious events)
- [ ] Serious events have at least one criterion flagged:
  - [ ] AESDTH, AESLIFE, AESHOSP, AESDISAB, AESCONG, AESMIE, or AESOD = 'Y'

### Severity Distribution
- [ ] MILD: ~7 records
- [ ] MODERATE: ~5 records
- [ ] SEVERE: ~3 records
- [ ] No invalid severity values
- [ ] No missing severity values

### Date Logic
- [ ] All AESTDTC in ISO 8601 format (YYYY-MM-DD)
- [ ] All AEENDTC in ISO 8601 format (YYYY-MM-DD)
- [ ] No end dates before start dates
- [ ] AEDUR = (end date - start date + 1) for complete events
- [ ] AEDUR > 0 for all records with end dates

### Study Day Logic
- [ ] AESTDY calculated correctly (no Day 0)
- [ ] AEENDY calculated correctly (no Day 0)
- [ ] AEENDY >= AESTDY for all records
- [ ] Negative study days for pre-treatment events
- [ ] Positive study days for on-treatment events

### Controlled Terminology
- [ ] AESEV only contains: MILD, MODERATE, SEVERE
- [ ] AESER only contains: Y, N, (blank)
- [ ] AEREL contains standard values or extensions
- [ ] AEACN contains standard values or extensions
- [ ] AEOUT contains standard values or extensions

### Unique Identifiers
- [ ] No duplicate AESEQ within same USUBJID
- [ ] AESEQ sequential within subject
- [ ] All AESEQ values are positive integers

### SUPPAE Domain
- [ ] All SUPPAE records link to AE domain
- [ ] RDOMAIN = "AE" for all records
- [ ] IDVAR = "AESEQ" for all records
- [ ] QNAM = "AETRTEM" for all records
- [ ] QLABEL = "Treatment Emergent Flag" for all records
- [ ] QVAL = "Y" for treatment-emergent events
- [ ] QORIG = "DERIVED" for all records

## QC Check Results

### QC Check 1: Frequency Distributions
```
Run proc freq and verify:
- AESEV distribution looks reasonable
- AESER distribution: 3 Y, 12 N
- AEREL distribution shows variety of relationships
- AEACN distribution shows appropriate actions
- AEOUT distribution shows appropriate outcomes
- Seriousness criteria flags present for serious events
```
- [ ] Frequencies reviewed and acceptable

### QC Check 2: Descriptive Statistics
```
Run proc means and verify:
- AEDUR: Mean ~5 days, Range 1-9 days
- AESTDY: Mean ~30 days, Range varies
- AEENDY: Mean ~35 days, Range varies
```
- [ ] Statistics reviewed and acceptable

### QC Check 3: MedDRA Coding Completeness
```
Check:
- 100% of AEs have AEDECOD
- 100% of AEs have AEPTCD
- 100% of AEs have AEBODSYS
- 0% uncoded events
```
- [ ] Coding completeness = 100%

### QC Check 4: Duplicate Detection
```
Verify:
- 0 duplicate AESEQ within subject
- Program flags if duplicates found
```
- [ ] No duplicates found

### QC Check 5: Missing Required Variables
```
Verify:
- 0 records with missing STUDYID
- 0 records with missing DOMAIN
- 0 records with missing USUBJID
- 0 records with missing AESEQ
- 0 records with missing AETERM
```
- [ ] No missing required variables

### QC Check 6: Date Logic Errors
```
Verify:
- 0 records with end date < start date
- 0 records with AEENDY < AESTDY
- 0 records with study day = 0
```
- [ ] No date logic errors

### QC Check 7: Treatment-Emergent Distribution
```
Verify:
- 100% of events are treatment-emergent (AETRTEM='Y')
- 0% pre-treatment events
```
- [ ] Treatment-emergent distribution correct

## Log File Review

### Check Log for:
- [ ] No SAS ERROR messages
- [ ] No FATAL messages
- [ ] Review all WARNING messages (if any)
- [ ] "Validation checks passed" message present
- [ ] Summary statistics printed at end
- [ ] Next steps guidance provided

### Validation Status
- [ ] validation_errors = NO
- [ ] validation_warnings = NO (or reviewed and acceptable)

## Variable Order Verification

### AE Domain Variable Sequence:
1. [ ] Identifiers: STUDYID, DOMAIN, USUBJID, AESEQ
2. [ ] Topic: AETERM
3. [ ] Synonyms: AEDECOD, AEPTCD, AEBODSYS, AESOC, AEHLT, AEHLGT, AELLT
4. [ ] Grouping: AECAT, AESCAT
5. [ ] Location: AELOC
6. [ ] Severity: AESEV, AESER
7. [ ] Seriousness: AESDTH, AESLIFE, AESHOSP, AESDISAB, AESCONG, AESMIE, AESOD
8. [ ] Actions/Outcomes: AEACN, AEREL, AEOUT
9. [ ] Timing: AESTDTC, AEENDTC, AEDUR, AESTDY, AEENDY

## Content Verification

### Spot Check Records
Manually verify 3 random records:

**Record 1 (Subject: RECIST-001-002, AESEQ: 2)**
- [ ] AETERM = "SEVERE CHEST PAIN"
- [ ] AEDECOD = "ANGINA PECTORIS"
- [ ] AEPTCD = "10002383"
- [ ] AEBODSYS = "CARDIAC DISORDERS"
- [ ] AESEV = "SEVERE"
- [ ] AESER = "Y"
- [ ] AESLIFE = "Y" (life-threatening)
- [ ] AESHOSP = "Y" (hospitalization)
- [ ] AELOC = "LEFT CHEST"

**Record 2 (Subject: RECIST-001-005, AESEQ: 1)**
- [ ] AETERM = "MILD NAUSEA"
- [ ] AEDECOD = "NAUSEA"
- [ ] AEPTCD = "10028813"
- [ ] AEBODSYS = "GASTROINTESTINAL DISORDERS"
- [ ] AESEV = "MILD"
- [ ] AESER = "N"
- [ ] AEREL = "POSSIBLY RELATED"

**Record 3 (Subject: RECIST-001-007, AESEQ: 2)**
- [ ] AETERM = "SEVERE JOINT PAIN"
- [ ] AEDECOD = "ARTHRALGIA"
- [ ] AESEV = "SEVERE"
- [ ] AESER = "Y"
- [ ] AESHOSP = "Y"
- [ ] AESDISAB = "Y" (disability)
- [ ] AELOC = "BILATERAL KNEES"

## Pinnacle 21 Validation (Optional)

If Pinnacle 21 Community is available:
- [ ] Downloaded and installed Pinnacle 21 Community
- [ ] Loaded ae.xpt and suppae.xpt into validator
- [ ] Selected FDA validation rules (SDTM IG 3.3)
- [ ] Run validation
- [ ] Review validation report
- [ ] 0 errors (or all errors documented and justified)
- [ ] Review warnings (acceptable or fixed)

## Final Approval

### Testing Summary
- **Date Tested**: _____________________
- **Tester Name**: _____________________
- **Total Checks**: 100+
- **Checks Passed**: _____ / _____
- **Checks Failed**: _____ / _____
- **Critical Issues**: _____ (must be 0)

### Approval Decision
- [ ] **APPROVED**: All critical checks passed, ready for submission
- [ ] **APPROVED WITH NOTES**: Minor issues documented, acceptable for submission
- [ ] **NOT APPROVED**: Critical issues found, requires fixes before submission

### Notes/Issues:
```
Document any issues, deviations, or observations:




```

### Sign-Off
- **Programmer**: _____________________ Date: _____
- **Lead Programmer**: _____________________ Date: _____
- **QC Reviewer**: _____________________ Date: _____

---

## Troubleshooting Common Issues

### Issue: "DM domain not found"
**Solution**: Run `10_sdtm_dm.sas` first

### Issue: "Invalid AESEV value detected"
**Solution**: Check SEVERITY column in raw data for typos

### Issue: "Duplicate AESEQ found"
**Solution**: Remove duplicate rows from `adverse_events_raw.csv`

### Issue: "XPT file size is 0"
**Solution**: Check for SAS errors in data step, verify file permissions

### Issue: "Variable not found: MEDDRA_PT_CODE"
**Solution**: Ensure raw CSV has all 25 required columns

### Issue: "Treatment-emergent count is 0"
**Solution**: Verify RFSTDTC exists in DM domain, check date formats

---

## Next Steps After Testing

1. **If all tests pass**:
   - Archive test results
   - Proceed to Pinnacle 21 validation
   - Create define.xml
   - Generate Reviewer's Guide

2. **If tests fail**:
   - Document failures in detail
   - Fix code or data issues
   - Re-run complete test suite
   - Do not proceed until all critical tests pass

3. **For production use**:
   - Replace test data with real study data
   - Re-run all tests
   - Obtain independent QC review
   - Get approval from study statistician
