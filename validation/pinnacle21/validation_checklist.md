# Pinnacle 21 Community Validation Checklist

**Document Version**: 1.0  
**Date**: December 2025  
**Prepared By**: Christian Baghai  
**Purpose**: Step-by-step guide for CDISC ADaM validation using Pinnacle 21 Community

---

## 1. Pre-Validation Setup

### 1.1 Software Installation

- [ ] **Download Pinnacle 21 Community Edition**
  - URL: [https://www.pinnacle21.com/downloads](https://www.pinnacle21.com/downloads)
  - Version: 4.0.0 or later recommended
  - Platform: Windows, macOS, or Linux
  - License: Free (community edition)

- [ ] **Install Pinnacle 21 Community**
  - Follow installation wizard
  - Accept license agreement
  - Set installation directory
  - Verify successful installation by launching application

### 1.2 CDISC Controlled Terminology

- [ ] **Configure CDISC CT Version**
  - Open Pinnacle 21 Community
  - Navigate to: `Settings` → `CDISC Controlled Terminology`
  - Select CT version: **2023-12-15** or later
  - Download CT package if not already installed
  - Verify CT loaded successfully

**Why this matters**: FDA submissions require compliance with specific CDISC CT versions. Using outdated terminology results in validation errors.

### 1.3 Export ADaM Datasets to XPT Format

- [ ] **Run XPT export SAS program**
  ```bash
  sas validation/pinnacle21/prepare_xpt_export.sas
  ```

- [ ] **Verify XPT files created**
  - Check directory: `validation/pinnacle21/xpt_files/`
  - Expected files:
    - `adsl.xpt` (Subject-Level Analysis Dataset)
    - `adrs.xpt` (Response Analysis Dataset)
    - `adtte.xpt` (Time-to-Event Analysis Dataset)

- [ ] **Verify file sizes are reasonable**
  - ADSL: ~50-500 KB (depending on number of subjects)
  - ADRS: ~100 KB - 5 MB (multiple records per subject)
  - ADTTE: ~50-500 KB (one record per subject per endpoint)

**Common Issue**: Native SAS7BDAT files will NOT work with Pinnacle 21. Must use XPT format.

### 1.4 Prepare Define.xml Metadata

- [ ] **Generate or update define.xml**
  - Tool options:
    - **Option 1**: Use Pinnacle 21 Define-XML Generator (recommended)
    - **Option 2**: Manually create using XML editor
    - **Option 3**: Use SAS-based define.xml generators

- [ ] **Define.xml must include**:
  - Dataset metadata (names, labels, structures)
  - Variable metadata (names, labels, data types, lengths)
  - Value-level metadata (codelists, controlled terminology)
  - Computational algorithms for derived variables
  - Comments explaining derivation logic

- [ ] **Validate define.xml structure**
  - Open define.xml in Pinnacle 21
  - Check for XML parsing errors
  - Verify all datasets and variables documented

**Critical**: Define.xml is **required** for ADaM validation. Without it, Pinnacle 21 cannot validate controlled terminology or derivation algorithms.

---

## 2. Validation Execution

### 2.1 Launch Pinnacle 21 Validation

- [ ] **Open Pinnacle 21 Community**

- [ ] **Select validation type**: `ADaM`

- [ ] **Configure validation settings**:
  - **Standard**: CDISC ADaM v1.1 or v1.3 (specify version used)
  - **CDISC CT Version**: 2023-12-15 or latest
  - **Validation Level**: Full (includes all checks)

### 2.2 Load Study Data

- [ ] **Load XPT files**
  - Click: `Add Data`
  - Navigate to: `validation/pinnacle21/xpt_files/`
  - Select all XPT files (adsl.xpt, adrs.xpt, adtte.xpt)
  - Click: `Open`

- [ ] **Load define.xml**
  - Click: `Add Define-XML`
  - Navigate to: `validation/pinnacle21/define.xml`
  - Click: `Open`

- [ ] **Verify files loaded**
  - Check that all datasets appear in file list
  - Check that define.xml status shows "Loaded"

### 2.3 Execute Validation

- [ ] **Click**: `Validate`

- [ ] **Wait for validation to complete**
  - Time estimate: 1-5 minutes (depending on data volume)
  - Progress bar shows validation status

- [ ] **Validation completes successfully**
  - No fatal errors encountered
  - Validation report generated

---

## 3. Validation Report Review

### 3.1 Understanding Error Categories

Pinnacle 21 uses a traffic-light system:

| Category | Color | Severity | Action Required |
|----------|-------|----------|----------------|
| **Errors** | 🔴 Red | Critical | **MUST FIX** before submission |
| **Warnings** | 🟡 Yellow | Potential issue | Review and justify or fix |
| **Notices** | 🔵 Blue | Informational | No action required |

### 3.2 Review Validation Results

- [ ] **Open validation report**
  - Report automatically displays after validation
  - Can also be saved as HTML or PDF

- [ ] **Check error summary**
  - Target: **Zero red (critical) errors**
  - Review all yellow warnings
  - Document justification for any unresolved warnings

### 3.3 Common Error Codes and Resolutions

#### AD0001: Required variable is missing

**Example**: `Variable USUBJID is missing from ADSL`

**Resolution**:
1. Check ADaM IG for required variables
2. Add missing variable to derivation program
3. Re-run ADaM generation
4. Re-export to XPT and re-validate

#### AD0015: Invalid controlled terminology value

**Example**: `Value 'MISSING' for variable SEX is not in CDISC CT`

**Resolution**:
1. Check CDISC CT for valid values (e.g., SEX: M, F, U, UNDIFFERENTIATED)
2. Update derivation to use valid CT values
3. Update define.xml codelist
4. Re-validate

#### AD0070: PARAMCD not in define.xml

**Example**: `PARAMCD='BOR' found in ADRS but not documented in define.xml`

**Resolution**:
1. Add BOR to define.xml codelist for PARAMCD
2. Include parameter description: "Best Overall Response"
3. Re-validate

#### AD0120: Missing variable label

**Example**: `Variable CHG in ADRS does not have a label`

**Resolution**:
1. Add LABEL statement in SAS program:
   ```sas
   label CHG = "Change from Baseline";
   ```
2. Re-run derivation
3. Re-export and re-validate

#### AD0235: Invalid date format

**Example**: `Variable ADT has invalid date format`

**Resolution**:
1. Ensure dates use SAS date format (numeric, not character)
2. Apply appropriate SAS date format:
   ```sas
   format ADT DATE9.;
   ```
3. Re-validate

### 3.4 Warning Justifications

For warnings that cannot be fixed (e.g., study-specific design), document justification:

**Example Warning**: "ADSL contains variable REGION which is not in ADaM IG"

**Justification**: "REGION is a protocol-specific stratification variable required for subgroup analyses per statistical analysis plan (SAP) Section 9.2.3. Inclusion is justified and has been approved by sponsor."

---

## 4. Acceptance Criteria

### 4.1 Validation Success Criteria

- [ ] **Zero critical errors (red flags)**
  - All AD0xxx errors resolved
  - No missing required variables
  - No invalid controlled terminology

- [ ] **All warnings documented**
  - Each yellow warning reviewed
  - Justification provided for unresolved warnings
  - Justifications approved by QA

- [ ] **Define.xml passes structural validation**
  - No XML parsing errors
  - All datasets and variables documented
  - Codelists complete and accurate

- [ ] **XPT files comply with SAS V5 transport specification**
  - Files readable by Pinnacle 21
  - No file corruption detected
  - Record counts match source datasets

### 4.2 Deliverables

- [ ] **Pinnacle 21 validation report**
  - Format: HTML or PDF
  - Filename: `p21_validation_YYYYMMDD.html`
  - Location: `validation/pinnacle21/reports/`

- [ ] **Issue resolution log**
  - Document all errors and resolutions
  - Track validation iterations
  - Filename: `issue_resolution_log.csv`
  - Location: `validation/pinnacle21/`

- [ ] **Define.xml (final version)**
  - Version-controlled
  - Matches validated XPT files
  - Location: `validation/pinnacle21/define.xml`

---

## 5. Post-Validation Steps

### 5.1 Archive Validation Evidence

- [ ] **Save validation report**
  ```bash
  cp validation_report.html validation/pinnacle21/reports/p21_validation_$(date +%Y%m%d).html
  ```

- [ ] **Archive XPT files**
  - Keep validated XPT files with validation report
  - Do not modify after validation

- [ ] **Version control define.xml**
  - Commit final define.xml to Git
  - Tag with validation date

### 5.2 Sign-Off and Approval

- [ ] **Validation Lead sign-off**
  - Name: ________________________________
  - Date: ________________________________
  - Signature: ________________________________

- [ ] **QA Reviewer sign-off**
  - Name: ________________________________
  - Date: ________________________________
  - Signature: ________________________________

- [ ] **Regulatory Affairs approval (if required)**
  - Name: ________________________________
  - Date: ________________________________
  - Signature: ________________________________

---

## 6. Iteration Tracker

**Expected**: First-pass validation typically yields 30-50 warnings/errors. Plan for 3-4 validation cycles to achieve clean validation.

| Iteration | Date | Errors | Warnings | Status | Notes |
|-----------|------|--------|----------|--------|-------|
| 1 | ______ | _____ | _____ | ☐ Pass ☐ Fail | __________________ |
| 2 | ______ | _____ | _____ | ☐ Pass ☐ Fail | __________________ |
| 3 | ______ | _____ | _____ | ☐ Pass ☐ Fail | __________________ |
| 4 | ______ | _____ | _____ | ☐ Pass ☐ Fail | __________________ |

**Final Validation Status**: ☐ PASSED ☐ FAILED

---

## 7. Resources

### Official Documentation
- Pinnacle 21 User Guide: [https://help.pinnacle21.com](https://help.pinnacle21.com)
- CDISC ADaM IG v1.1: [https://www.cdisc.org/standards/foundational/adam](https://www.cdisc.org/standards/foundational/adam)
- CDISC Controlled Terminology: [https://evs.nci.nih.gov/ftp1/CDISC/](https://evs.nci.nih.gov/ftp1/CDISC/)

### Support
- Pinnacle 21 Forum: [https://forum.certara.com/](https://forum.certara.com/)
- CDISC Community Forum: [https://www.cdisc.org/cdisc-community](https://www.cdisc.org/cdisc-community)

---

**End of Pinnacle 21 Validation Checklist**
