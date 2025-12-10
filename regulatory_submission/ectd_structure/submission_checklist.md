# eCTD Submission Readiness Checklist

Use this checklist to validate submission package before delivery to regulatory agencies.

## Dataset Validation

### ADaM Datasets
- [ ] All ADaM datasets generated successfully (ADSL, ADRS, ADTTE, etc.)
- [ ] ADSL contains one record per subject
- [ ] BDS datasets follow proper structure
- [ ] All required ADaM variables present (STUDYID, USUBJID, etc.)
- [ ] Variable names ≤ 8 characters, alphanumeric
- [ ] All variables have labels ≤ 40 characters
- [ ] Character variables ≤ 200 characters
- [ ] Analysis flags use "Y"/"N"/null pattern
- [ ] Traceability variables included where applicable

### SDTM Datasets
- [ ] All required SDTM domains generated
- [ ] Datasets comply with declared SDTM version
- [ ] Required variables present per domain
- [ ] Controlled terminology values valid
- [ ] Date/time variables in ISO 8601 format

### XPT Transport Files
- [ ] All XPT files in SAS XPT v5 format
- [ ] File names lowercase, ≤ 8 characters
- [ ] Individual files ≤ 5GB
- [ ] XPT files readable by SAS (validation test)

## Define.xml Validation

### ADaM Define.xml
- [ ] Define-XML v2.1 format (FDA preference)
- [ ] CDISC version declared correctly (ADaM IG v1.3)
- [ ] All datasets documented
- [ ] All variables have:
  - [ ] Name
  - [ ] Label (≤ 40 characters)
  - [ ] Data type
  - [ ] Origin
  - [ ] Derivation comment (for derived variables)
- [ ] Value-level metadata for coded variables (PARAMCD, AVALC, etc.)
- [ ] Validates without errors (Pinnacle 21 Community)
- [ ] No XML syntax errors

### SDTM Define.xml
- [ ] CDISC version matches datasets (SDTM IG v3.4)
- [ ] All domains documented
- [ ] Controlled terminology references included
- [ ] Validates without errors

## Documentation

### ADRG (Analysis Data Reviewer's Guide)
- [ ] All 7 required sections complete:
  - [ ] 1. Introduction
  - [ ] 2. Protocol Description
  - [ ] 3. Analysis Datasets
  - [ ] 4. ADaM Conformance
  - [ ] 5. Data Dependencies
  - [ ] 6. Special Variables
  - [ ] 7. Program Inventory
- [ ] References correct define.xml file
- [ ] Dataset descriptions match actual datasets
- [ ] Program inventory matches repository files
- [ ] Complex derivations documented (RECIST, TTE, etc.)
- [ ] Converted to searchable PDF

### Program Inventory Accuracy
- [ ] All production programs listed
- [ ] All QC programs listed
- [ ] Input/output datasets documented
- [ ] Program purposes clear
- [ ] Execution order documented

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
- [ ] File naming conventions followed
- [ ] No extraneous files

## Cross-Validation

### Dataset Consistency
- [ ] Subject counts match (ADSL n = DM n)
- [ ] USUBJID values consistent across datasets
- [ ] Treatment coding consistent
- [ ] Date variables internally consistent
- [ ] Population flags align with dosing data

### Define.xml vs Datasets
- [ ] All variables in define.xml exist in datasets
- [ ] All variables in datasets exist in define.xml
- [ ] Variable types match
- [ ] Variable labels match
- [ ] Value-level metadata matches actual data

### ADRG vs Datasets
- [ ] Dataset names match XPT files
- [ ] Record counts match
- [ ] Variable descriptions consistent with define.xml

## QC and Validation

### Double Programming
- [ ] All ADaM datasets have independent QC
- [ ] QC programs completed
- [ ] 100% concordance achieved
- [ ] Discrepancies resolved and documented

### Validation Reports
- [ ] CDISC conformance validation completed
- [ ] Validation issues addressed
- [ ] Unit tests passed
- [ ] Integration tests passed

## Critical Showstoppers

**Must fix before submission:**

1. Define.xml fails validation
2. Variable names > 8 characters
3. Character variables > 200 characters
4. Missing ADRG sections
5. QC discrepancies unresolved

## Sign-Off

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
