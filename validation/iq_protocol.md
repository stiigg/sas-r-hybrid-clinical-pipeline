# Installation Qualification Protocol

**System**: Clinical Trial Data Pipeline - RECIST 1.1 Module  
**Protocol Version**: 1.0  
**Date**: December 2025  
**Prepared By**: Christian Baghai  
**Regulatory Framework**: 21 CFR Part 11, EU Annex 11

---

## 1. Executive Summary

### 1.1 Objective
Verify that the computational environment for the RECIST 1.1 clinical data derivation pipeline is correctly installed, configured, and documented per FDA 21 CFR Part 11 requirements for electronic records and signatures.

### 1.2 Scope
This Installation Qualification validates:
- R statistical environment (v4.2.0 or later)
- Required R packages with version tracking
- SAS software installation (v9.4 M6 or later)
- Repository file structure integrity
- RECIST derivation macros in SAS Autocall library
- Development environment configuration

### 1.3 Regulatory Basis
- **21 CFR Part 11**: Electronic records; electronic signatures (FDA)
- **EU Annex 11**: Computerised Systems (EMA)
- **ICH E6(R2)**: Good Clinical Practice guideline
- **GAMP 5**: Risk-based approach to compliant GxP computerized systems

---

## 2. System Description

### 2.1 Purpose
The RECIST 1.1 Derivation Pipeline is a validated software system for:
- Processing CDISC SDTM oncology response data (RS, TU, TR domains)
- Deriving ADaM analysis datasets (ADSL, ADRS, ADTTE)
- Calculating Best Overall Response per RECIST 1.1 criteria (Eisenhauer et al. 2009)
- Generating time-to-event endpoints (PFS, DoR, OS)

### 2.2 System Classification
GAMP 5 Category: **Category 4** (Configured Products)  
Risk Level: **Medium** (impacts clinical study analysis, not direct patient care)

### 2.3 Hardware Requirements
- **Processor**: x86_64 architecture, 2+ cores
- **Memory**: Minimum 8 GB RAM (16 GB recommended)
- **Storage**: 5 GB free disk space
- **Operating System**: Windows 10/11, macOS 11+, or Linux (Ubuntu 20.04+)

---

## 3. Installation Qualification Test Cases

### IQ-001: R Version Verification

**Objective**: Confirm R version meets minimum requirements for package compatibility

**Procedure**:
1. Open command line terminal
2. Execute: `R --version`
3. Record R version number
4. Verify version ≥ 4.2.0

**Acceptance Criteria**:
- R version 4.2.0 or higher installed
- R executable accessible from system PATH

**Expected Output**:
```
R version 4.2.0 (2022-04-22) -- "Vigorous Calisthenics"
Copyright (C) 2022 The R Foundation for Statistical Computing
Platform: x86_64-pc-linux-gnu (64-bit)
```

**Test Record**:
- Date Tested: ________________
- Tested By: ________________
- Actual R Version: ________________
- Status: ☐ Pass ☐ Fail ☐ N/A
- Comments: ________________________________________________

---

### IQ-002: R Package Installation Verification

**Objective**: Verify all required R packages are installed with correct versions

**Required Packages**:
- `admiral` (ADaM derivation toolkit) ≥ 0.10.0
- `dplyr` (data manipulation) ≥ 1.1.0
- `haven` (SAS dataset I/O) ≥ 2.5.0
- `testthat` (unit testing) ≥ 3.1.0
- `diffdf` (dataset comparison) ≥ 1.0.0
- `yaml` (configuration management) ≥ 2.3.0
- `lubridate` (date/time handling) ≥ 1.9.0

**Procedure**:
1. Create validation script `validation/scripts/check_r_packages.R`
2. Execute script from R console
3. Review output for missing packages or version conflicts

**Validation Script**:
```r
# Check R package installation and versions
required_packages <- data.frame(
  Package = c("admiral", "dplyr", "haven", "testthat", 
              "diffdf", "yaml", "lubridate"),
  MinVersion = c("0.10.0", "1.1.0", "2.5.0", "3.1.0", 
                 "1.0.0", "2.3.0", "1.9.0"),
  stringsAsFactors = FALSE
)

installed <- installed.packages()[, c("Package", "Version")]

results <- merge(required_packages, installed, by = "Package", all.x = TRUE)
results$Status <- ifelse(
  is.na(results$Version), 
  "MISSING",
  ifelse(
    package_version(results$Version) >= package_version(results$MinVersion),
    "PASS",
    "VERSION TOO LOW"
  )
)

print(results)

# Overall assessment
if (all(results$Status == "PASS")) {
  cat("\n[PASS] All required packages installed with correct versions\n")
} else {
  cat("\n[FAIL] Package installation issues detected\n")
  print(results[results$Status != "PASS", ])
}
```

**Acceptance Criteria**:
- All required packages present
- All package versions meet minimum requirements
- No dependency conflicts reported

**Test Record**:
- Date Tested: ________________
- Tested By: ________________
- Script Output: (attach `validation/evidence/iq_002_output.txt`)
- Status: ☐ Pass ☐ Fail ☐ N/A
- Comments: ________________________________________________

---

### IQ-003: SAS Installation Verification

**Objective**: Confirm SAS software version and licensing

**Procedure**:
1. Launch SAS session
2. Execute SAS program:
```sas
proc options option=config;
run;

proc setinit;
run;

proc product_status;
run;
```
3. Record SAS version, license expiration, and installed components

**Acceptance Criteria**:
- SAS 9.4 M6 or later installed
- Valid SAS/BASE license
- Valid SAS/STAT license (for PROC COMPARE)
- License not expired

**Test Record**:
- Date Tested: ________________
- Tested By: ________________
- SAS Version: ________________
- License Expiration: ________________
- Status: ☐ Pass ☐ Fail ☐ N/A
- Comments: ________________________________________________

---

### IQ-004: Repository File Structure Integrity

**Objective**: Verify complete repository structure with all required files

**Critical Files and Directories**:
```
sas-r-hybrid-clinical-pipeline/
├── etl/
│   └── adam_program_library/
│       └── oncology_response/
│           ├── recist_11_core/
│           │   ├── derive_target_lesion_response.sas
│           │   ├── derive_non_target_lesion_response.sas
│           │   ├── derive_overall_timepoint_response.sas
│           │   └── derive_best_overall_response.sas
│           ├── time_to_event/
│           ├── advanced_endpoints/
│           └── immunotherapy/
├── demo/
│   ├── data/
│   │   ├── comprehensive_sdtm_rs.csv
│   │   └── expected_bor_comprehensive.csv
│   └── simple_recist_demo.sas
├── qc/
│   ├── r/
│   │   └── automated_comparison.R
│   └── sas/
├── tests/
│   ├── testthat/
│   │   ├── test-recist-boundaries.R
│   │   └── test-recist-confirmation.R
│   └── run_all_tests.R
├── validation/
│   ├── iq_protocol.md
│   ├── oq_protocol.md (pending)
│   └── pq_protocol.md (pending)
└── README.md
```

**Procedure**:
1. Execute file structure validation script
2. Verify presence of all critical files
3. Check file permissions (read/execute for SAS macros)

**Validation Script** (`validation/scripts/check_file_structure.R`):
```r
critical_files <- c(
  "etl/adam_program_library/oncology_response/recist_11_core/derive_target_lesion_response.sas",
  "etl/adam_program_library/oncology_response/recist_11_core/derive_non_target_lesion_response.sas",
  "etl/adam_program_library/oncology_response/recist_11_core/derive_overall_timepoint_response.sas",
  "etl/adam_program_library/oncology_response/recist_11_core/derive_best_overall_response.sas",
  "demo/data/comprehensive_sdtm_rs.csv",
  "demo/data/expected_bor_comprehensive.csv",
  "qc/r/automated_comparison.R",
  "tests/run_all_tests.R",
  "README.md"
)

missing_files <- critical_files[!file.exists(critical_files)]

if (length(missing_files) == 0) {
  cat("[PASS] All critical files present\n")
} else {
  cat("[FAIL] Missing files:\n")
  cat(paste("-", missing_files, collapse = "\n"), "\n")
}
```

**Acceptance Criteria**:
- All critical files present
- No file corruption (readable with appropriate tools)
- Correct directory structure

**Test Record**:
- Date Tested: ________________
- Tested By: ________________
- Missing Files: ________________
- Status: ☐ Pass ☐ Fail ☐ N/A
- Comments: ________________________________________________

---

### IQ-005: SAS Autocall Library Configuration

**Objective**: Verify SAS macros accessible via Autocall facility

**Procedure**:
1. Configure SAS Autocall path in `autoexec.sas` or session startup:
```sas
options mautosource sasautos=(
    "etl/adam_program_library/oncology_response/recist_11_core",
    "etl/adam_program_library/oncology_response/time_to_event",
    sasautos
);
```
2. Test macro accessibility:
```sas
proc options option=sasautos;
run;

/* Test macro call without %include */
%derive_target_lesion_response();
```

**Acceptance Criteria**:
- SAS Autocall paths correctly configured
- RECIST macros accessible without explicit %include statements
- No "macro not found" errors

**Test Record**:
- Date Tested: ________________
- Tested By: ________________
- Autocall Paths: ________________
- Status: ☐ Pass ☐ Fail ☐ N/A
- Comments: ________________________________________________

---

### IQ-006: Git Version Control Configuration

**Objective**: Verify repository under version control with proper configuration

**Procedure**:
1. Execute: `git --version`
2. Execute: `git log -1 --oneline` (verify commit history)
3. Execute: `git remote -v` (verify GitHub remote configured)
4. Check `.gitignore` for proper exclusions

**Acceptance Criteria**:
- Git version 2.30 or later
- Repository initialized with commit history
- Remote origin points to GitHub repository
- `.gitignore` excludes sensitive files (SAS datasets, logs, temporary files)

**Test Record**:
- Date Tested: ________________
- Tested By: ________________
- Git Version: ________________
- Remote URL: ________________
- Status: ☐ Pass ☐ Fail ☐ N/A
- Comments: ________________________________________________

---

## 4. Installation Summary

### 4.1 Test Results Summary

| Test ID | Test Description | Status | Tester | Date |
|---------|------------------|--------|--------|------|
| IQ-001 | R Version Verification | ☐ P ☐ F | ______ | ____ |
| IQ-002 | R Package Installation | ☐ P ☐ F | ______ | ____ |
| IQ-003 | SAS Installation | ☐ P ☐ F | ______ | ____ |
| IQ-004 | File Structure Integrity | ☐ P ☐ F | ______ | ____ |
| IQ-005 | SAS Autocall Configuration | ☐ P ☐ F | ______ | ____ |
| IQ-006 | Git Version Control | ☐ P ☐ F | ______ | ____ |

### 4.2 Overall IQ Status

**Installation Qualification Status**: ☐ PASS ☐ FAIL ☐ PASS WITH DEVIATIONS

**Acceptance Criteria**:
- All IQ test cases must pass (Status = PASS)
- Environment configuration documented and reproducible
- Software versions meet regulatory requirements (21 CFR Part 11 compliance)

**Deviations**:
(Document any test failures or deviations with justification and corrective actions)

---

## 5. Change Control

### 5.1 Document History

| Version | Date | Author | Description of Changes |
|---------|------|--------|------------------------|
| 1.0 | 2025-12-14 | C. Baghai | Initial IQ protocol for RECIST 1.1 pipeline |

### 5.2 Future Updates
This protocol must be re-executed when:
- R or SAS software versions are upgraded
- Critical R packages are updated (major version changes)
- Repository structure significantly modified
- New RECIST modules added (e.g., iRECIST, RECIST 1.1)

---

## 6. Signature and Approval

### 6.1 Tester Sign-Off
I certify that I have executed all IQ test cases according to this protocol and that the results are accurately documented.

**Tester Name**: ________________________________  
**Signature**: ________________________________  
**Date**: ________________________________

### 6.2 Reviewer Sign-Off
I certify that I have reviewed the IQ test results and that the installation meets all acceptance criteria.

**Reviewer Name**: ________________________________  
**Title**: ________________________________  
**Signature**: ________________________________  
**Date**: ________________________________

### 6.3 Quality Assurance Approval
I certify that the installation qualification has been completed in accordance with regulatory requirements (21 CFR Part 11, EU Annex 11) and organizational SOPs.

**QA Manager Name**: ________________________________  
**Signature**: ________________________________  
**Date**: ________________________________

---

## 7. References

1. FDA 21 CFR Part 11: Electronic Records; Electronic Signatures (1997)
2. EU Annex 11: Computerised Systems (2011)
3. ICH E6(R2): Good Clinical Practice (2016)
4. GAMP 5: A Risk-Based Approach to Compliant GxP Computerized Systems (2008)
5. Eisenhauer EA, et al. New response evaluation criteria in solid tumours: Revised RECIST guideline (version 1.1). Eur J Cancer. 2009;45(2):228-247.
6. CDISC ADaM Implementation Guide v1.1 (2016)

---

**End of Installation Qualification Protocol**
