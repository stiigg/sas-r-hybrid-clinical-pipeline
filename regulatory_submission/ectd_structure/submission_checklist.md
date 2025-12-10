# eCTD Submission Readiness Checklist

## Dataset Validation

### ADaM Datasets (Module 5.3.5.3/analysis/adam/)
- [ ] All ADaM datasets generated successfully
- [ ] ADSL contains one record per subject
- [ ] BDS datasets follow proper structure (one record per subject per parameter per timepoint)
- [ ] All required ADaM variables present (STUDYID, USUBJID, etc.)
- [ ] Variable names comply with CDISC naming conventions (alphanumeric, ≤8 characters)
- [ ] All variables have labels ≤40 characters
- [ ] Character variables respect 200-character limit
- [ ] Numeric variables have appropriate formats
- [ ] Analysis flags use "Y"/"N"/null pattern consistently
- [ ] Traceability variables included (--SEQ, --DTC where applicable)

### SDTM Datasets (Module 5.3.5.4/tabulations/sdtm/)
- [ ] All SDTM domains generated successfully
- [ ] Datasets comply with SDTM IG version declared in define.xml
- [ ] All required SDTM variables present per domain
- [ ] --TESTCD values match controlled terminology
- [ ] Date/time variables in ISO 8601 format
- [ ] Character variables respect 200-character limit
- [ ] All variables have labels

### XPT Transport Files
- [ ] All XPT files written in SAS XPT v5 format
- [ ] XPT file names are lowercase, ≤8 characters
- [ ] Individual XPT files ≤5GB (split if larger)
- [ ] XPT files can be read by SAS (validation test)
- [ ] No special characters in file names

## Define.xml Validation

### ADaM Define.xml
- [ ] Define.xml v2.0 or v2.1 format (v2.1 preferred)
- [ ] CDISC version declared matches datasets (ADaM IG v1.3)
- [ ] All datasets in define.xml match actual XPT files
- [ ] All variables documented with:
  - [ ] Variable name
  - [ ] Variable label (≤40 characters)
  - [ ] Data type
  - [ ] Origin (Assigned, Derived, Predecessor, etc.)
  - [ ] Derivation comment (for derived variables)
- [ ] Value-level metadata populated for:
  - [ ] PARAMCD (all parameter codes documented)
  - [ ] AVALC (coded analysis values)
  - [ ] Other coded variables
- [ ] Define.xml validates with no errors using:
  - [ ] Pinnacle 21 Community validator
  - [ ] FDA Validator (if available)
- [ ] No XML syntax errors
- [ ] Stylesheet reference included for human readability

### SDTM Define.xml
- [ ] CDISC version declared matches datasets (SDTM IG v3.4)
- [ ] All SDTM domains documented
- [ ] Controlled terminology references included
- [ ] Comments explain protocol-specific variables
- [ ] Define.xml validates with no errors

## Documentation

### ADRG (Analysis Data Reviewer's Guide)
- [ ] All 7 required sections complete:
  - [ ] 1. Introduction
  - [ ] 2. Protocol Description
  - [ ] 3. Analysis Datasets (detailed descriptions)
  - [ ] 4. ADaM Conformance (self-assessment)
  - [ ] 5. Data Dependencies (SDTM-to-ADaM traceability)
  - [ ] 6. Special Variables (complex derivations documented)
  - [ ] 7. Program Inventory (complete program listing)
- [ ] ADRG references correct define.xml file name
- [ ] Dataset descriptions match actual datasets
- [ ] Program inventory matches actual repository files
- [ ] Derivation algorithms documented with code references
- [ ] Complex derivations include:
  - [ ] RECIST 1.1 BOR derivation
  - [ ] Time-to-event censoring rules
  - [ ] Baseline value definitions
  - [ ] Imputation methods (if any)
- [ ] ADRG converted to searchable PDF (not scanned image)
- [ ] PDF bookmarks/table of contents included

### CSDRG (Clinical Study Data Reviewer's Guide)
- [ ] CSDRG created for SDTM datasets
- [ ] Protocol overview included
- [ ] SDTM domain descriptions provided
- [ ] Special data collection methods documented
- [ ] Converted to searchable PDF

## eCTD Structure

### Directory Organization
- [ ] Module 5.3.5.3/analysis/adam/ contains:
  - [ ] All ADaM XPT files
  - [ ] define.xml
  - [ ] adrg.pdf
- [ ] Module 5.3.5.4/tabulations/sdtm/ contains:
  - [ ] All SDTM XPT files
  - [ ] define.xml
  - [ ] csdrg.pdf (if applicable)
- [ ] File naming conventions followed (lowercase, no special characters)
- [ ] No extraneous files in submission directories

### Version Control
- [ ] All files have consistent version/date stamps
- [ ] ADRG document history table updated
- [ ] Define.xml file generation date correct
- [ ] Dataset labels include study and version info

## Cross-Validation

### Dataset Consistency
- [ ] Subject counts match across datasets:
  - [ ] ADSL n_subjects = DM n_subjects
  - [ ] ADRS USUBJID values subset of ADSL
  - [ ] ADTTE USUBJID values subset of ADSL
- [ ] Treatment coding consistent (TRT01P/TRT01A)
- [ ] Date variables internally consistent (TRTSDT ≤ TRTEDT)
- [ ] Population flags align (SAFFL subjects have TRTSDT)

### Define.xml vs Datasets
- [ ] All variables in define.xml exist in datasets
- [ ] All variables in datasets exist in define.xml
- [ ] Variable types match between define.xml and datasets
- [ ] Variable labels match exactly
- [ ] Value-level metadata matches actual coded values in data

### ADRG vs Datasets
- [ ] Dataset names in ADRG match actual XPT file names
- [ ] Record counts in ADRG match actual datasets
- [ ] Variable descriptions consistent with define.xml
- [ ] Program names in inventory match actual files

## QC and Validation

### Double Programming
- [ ] All ADaM datasets have independent QC programs
- [ ] QC programs completed and reconciled
- [ ] 100% dataset concordance achieved
- [ ] Discrepancy resolution documented

### Validation Reports
- [ ] CDISC conformance validation completed (Pinnacle 21)
- [ ] Validation issues addressed or explained
- [ ] Unit tests passed for derivation functions
- [ ] Integration tests passed for complete pipeline

### Regression Testing
- [ ] Golden patient test cases validated
- [ ] Edge cases tested (min/max values, missing data patterns)
- [ ] Date imputation logic verified

## Regulatory Requirements

### FDA-Specific
- [ ] Study data submitted via ESG (Electronic Submissions Gateway)
- [ ] eCTD backbone valid per FDA Technical Specifications
- [ ] Define.xml v2.1 used (FDA preference)
- [ ] ADRG follows PHUSE template structure

### EMA-Specific
- [ ] Define.xml includes controlled terminology references
- [ ] CSDRG includes protocol amendment history
- [ ] Date format compliance verified (ISO 8601)

### PMDA-Specific (if applicable)
- [ ] Japanese translations provided where required
- [ ] PMDA-specific validation rules checked

## Final Steps

### Pre-Submission Review
- [ ] Biostatistics team reviewed ADRG
- [ ] Data management reviewed SDTM mapping
- [ ] Regulatory affairs approved submission package
- [ ] Programming lead signed off on dataset quality

### Submission Package
- [ ] All files zipped/packaged per agency requirements
- [ ] Transmittal letter prepared
- [ ] Cover letter references correct eCTD modules
- [ ] MD5 checksums generated for all data files
- [ ] Submission metadata (study ID, date, version) correct

### Post-Submission
- [ ] Copy of final submission archived internally
- [ ] Version control tags created in Git (e.g., `submission-v1.0`)
- [ ] Lessons learned documented for future submissions
- [ ] Regulatory response tracking plan established

---

## Critical Path Items (Must Have Before Submission)

### Showstoppers
1. **Define.xml fails validation** → Must fix all errors
2. **Variable names >8 characters** → Must rename
3. **Character variables >200 characters** → Must truncate or split
4. **Missing ADRG sections** → Must complete all 7 sections
5. **QC discrepancies unresolved** → Must reconcile to 100% match

### High Priority (Strongly Recommended)
1. ADRG converted to searchable PDF with bookmarks
2. Program inventory exactly matches repository structure
3. Complex derivations fully documented with code references
4. Pinnacle 21 validation report shows zero errors

### Medium Priority (Best Practice)
1. Golden patient validation completed
2. Regression test suite passed
3. Version control tags created
4. Submission archived with MD5 checksums

---

## Checklist Sign-Off

| Role | Name | Date | Signature |
|------|------|------|----------|
| Lead Programmer | | | |
| QC Programmer | | | |
| Biostatistician | | | |
| Data Manager | | | |
| Regulatory Affairs | | | |

**Submission Ready**: [ ] Yes [ ] No

**Notes**:
```



```
