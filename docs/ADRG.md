# Analysis Data Reviewers Guide (ADRG)
## SAS-R Hybrid Clinical Pipeline for RECIST 1.1 Oncology Trials

**Document Version:** 1.0  
**Last Updated:** December 14, 2025  
**Pipeline Version:** 1.0  
**Repository:** https://github.com/stiigg/sas-r-hybrid-clinical-pipeline

---

## 1. Executive Summary

This ADRG provides FDA/EMA reviewers with step-by-step instructions to reproduce the analysis environment and execute the SAS-R hybrid clinical trial data pipeline. The pipeline generates CDISC-compliant SDTM and ADaM datasets with RECIST 1.1 oncology endpoints.

**Key Features:**
- Hybrid SAS-R architecture (SAS for SDTM/ADaM derivations, R for QC and visualization)
- Metadata-driven programming via pharmaverse (admiral, metacore, metatools)
- Automated QC with dual programming for critical endpoints
- Interactive Shiny explorer (exploratory use only, see Section 7)

**Estimated Setup Time:** 45-60 minutes  
**Estimated Execution Time:** 15-20 minutes (demo), 2-4 hours (full pipeline)

---

## 2. System Requirements

### 2.1 Operating System Requirements

**Supported Platforms:**
- Windows 10/11 (Primary testing environment)
- Windows Server 2019/2022
- Ubuntu 20.04/22.04 LTS
- macOS 12+ (Monterey or later)

**Required Disk Space:** 5 GB minimum (10 GB recommended)  
**Required Memory:** 8 GB minimum (16 GB recommended for full portfolio)  
**CPU:** Multi-core processor (4+ cores recommended for parallel execution)

### 2.2 Required Software

#### R (Required)

- **R version 4.2.0 or later** (tested with R 4.3.2)
- Download from: https://cran.r-project.org/
- **Important:** Install to path without spaces (e.g., `C:\R\R-4.3.2`)

**Windows-Specific Installation:**
1. Download R installer: https://cran.r-project.org/bin/windows/base/
2. Run installer as Administrator
3. **CRITICAL:** Select "Custom Installation"
4. Check "Add R to PATH" option
5. Verify installation:
   ```
   R --version
   ```
   Expected output: `R version 4.3.2 (2023-XX-XX)`

#### RTools (Windows Only)

- **Rtools43** required for package compilation
- Download: https://cran.r-project.org/bin/windows/Rtools/
- **Installation Path:** Must be `C:\rtools43` (default)
- Verify PATH includes `C:\rtools43\usr\bin`

**Verification:**
```
where make
```
Expected output: `C:\rtools43\usr\bin\make.exe`

#### SAS (Optional - Required for Hybrid Mode)

- **SAS 9.4 M7 or later** (tested with SAS 9.4 M8)
- **Required SAS Components:**
  - Base SAS
  - SAS/STAT
  - SAS/GRAPH (optional, for visualizations)
- **SAS License:** Ensure SETINIT date is valid
- **SAS Environment Variables:** Verify SASROOT is set

**Verification:**
```
sas -nodms -noterminal
```
Expected output: SAS session starts without errors

**R-Only Mode:** If SAS is not available, the pipeline can run in R-only mode using admiral for ADaM derivations.

#### System Dependencies (Linux/macOS)

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libfontconfig1-dev \
  libharfbuzz-dev \
  libfribidi-dev
```

**macOS** (requires Homebrew):
```bash
brew install libxml2 openssl curl
```

---

## 3. Environment Setup (Step-by-Step)

### 3.1 Clone Repository

**Using Git** (recommended):
```bash
cd C:\Projects  # or ~/projects on Linux/Mac
git clone https://github.com/stiigg/sas-r-hybrid-clinical-pipeline.git
cd sas-r-hybrid-clinical-pipeline
```

**Alternative: Download ZIP**:
1. Visit https://github.com/stiigg/sas-r-hybrid-clinical-pipeline
2. Click "Code" → "Download ZIP"
3. Extract to `C:\Projects\sas-r-hybrid-clinical-pipeline`
4. **IMPORTANT:** Verify no files are blocked (Right-click → Properties → Unblock)

### 3.2 Install R Packages Using renv

**Step 1: Restore Package Environment**

Open R in the repository directory:
```bash
cd C:\Projects\sas-r-hybrid-clinical-pipeline
R
```

In R console:
```r
# Install renv if not present
if (!require("renv")) install.packages("renv")

# Restore exact package versions from renv.lock
renv::restore()
```

**Expected Warnings** (safe to ignore):
- `package 'XXX' is not available for R version 4.3.2` → renv will build from source
- `Rtools required but not found` → install Rtools (see Section 2.2)
- `dependency 'YYY' is not available` → renv will auto-install dependencies

**Installation Progress:** Expect 15-25 minutes for ~80 packages

**Verification:**
```r
library(admiral)
library(metacore)
library(shiny)
packageVersion("admiral")  # Should match renv.lock version
```

**Troubleshooting Common Installation Errors:**

*Error: "package 'admiral' is not available"*
```r
# Install from pharmaverse GitHub
renv::install("pharmaverse/admiral")
```

*Error: "compilation failed for package 'stringi'"*
```r
# Install pre-compiled binary (Windows)
install.packages("stringi", type = "win.binary")
```

*Error: "cannot open file 'renv.lock'"*
```bash
# Verify you're in repository root
dir renv.lock  # Windows
ls renv.lock   # Linux/Mac
```

### 3.3 Verify Environment

**Run environment verification script:**
```r
source("validation/scripts/verify_environment.R")
```

Expected output:
```
================================================
  Clinical Pipeline Environment Verification    
================================================

[1/10] Checking R version...
        R version: 4.3.2 ✓ (meets requirement ≥4.2.0)

[2/10] Checking operating system...
        OS: Windows 11 ✓

[3/10] Checking SAS executable...
        SAS executable found: C:/Program Files/SASHome/SASFoundation/9.4/sas.exe ✓

[4/10] Checking build tools...
        Rtools detected: C:/rtools43 ✓

[5/10] Checking renv environment...
        renv installed: 1.0.3 ✓
        renv project active ✓

[6/10] Checking validated packages...
        ✓ admiral 1.0.0 (validated)
        ✓ metacore 0.1.2 (validated)
        ✓ metatools 0.1.3 (validated)
        ✓ shiny 1.8.0 (validated)
        ✓ dplyr 1.1.4 (validated)
        ✓ haven 2.5.4 (validated)

[... additional checks ...]

================================================
  ✓ Environment verification: PASSED              
================================================
```

### 3.4 Configure SAS Integration (Hybrid Mode Only)

**Edit `run_all.R` to point to SAS executable:**

Open `run_all.R` and update line 15-20:

```r
# Configure SAS path
SAS_EXECUTABLE <- "C:/Program Files/SASHome/SASFoundation/9.4/sas.exe"

# Verify SAS is accessible
if (!file.exists(SAS_EXECUTABLE)) {
  stop("SAS not found at: ", SAS_EXECUTABLE, 
       "\nUpdate SAS_EXECUTABLE path in run_all.R")
}
```

**For R-only mode** (skip SAS steps):
```r
Rscript run_r_only_pipeline.R
```

---

## 4. Execution Instructions

### 4.1 Quick Demo (RECIST 1.1 Core)

**Purpose:** Verify installation with minimal test data (3 subjects)  
**Runtime:** 2-3 minutes

```bash
cd demo
sas simple_recist_demo.sas
# Or if using R-only:
Rscript simple_recist_demo.R
```

**Expected Output:**
- `demo/output/adrs.sas7bdat` (20 observations)
- `demo/output/bor_summary.txt` (frequency table)
- Log file: `demo/simple_recist_demo.log`

**Verification:**
```sas
/* Check BOR derivation results */
proc print data=demo.adrs_bor;
  where PARAMCD = "BOR";
  var USUBJID AVALC ASEQ;
run;
```

Expected BOR results:
- Subject 001-001: PR (Partial Response)
- Subject 001-002: CR (Complete Response)
- Subject 001-003: PD (Progressive Disease)

**If demo fails:** See Section 9 (Troubleshooting)

### 4.2 Full Pipeline Execution

**Hybrid Mode** (SAS + R):
```bash
# Windows
run_pipeline.bat

# Linux/macOS
chmod +x run_pipeline.sh
./run_pipeline.sh
```

**R-Only Mode:**
```bash
# Windows PowerShell
.\run_r_only_pipeline.ps1

# Linux/macOS
./run_r_only_pipeline.sh
```

**Execution Stages** (monitor via logs/):
1. SDTM dataset generation (SAS): 5-8 minutes
2. ADaM dataset derivation (R + SAS): 8-12 minutes
3. QC comparison (R): 3-5 minutes
4. Validation checks (R): 2-3 minutes

**Total Runtime:** 18-28 minutes (demo data), 2-4 hours (full portfolio)

---

## 5. Output Verification

### 5.1 Generated Datasets

**Location:** `outputs/adam/`

**Expected Files:**
- `adsl.sas7bdat` - Subject-Level Analysis Dataset
- `adrs.sas7bdat` - Response Analysis Dataset (RECIST 1.1)
- `adtte.sas7bdat` - Time-to-Event Analysis Dataset

**Validation:** All datasets should pass Pinnacle 21 validation (see Section 6)

### 5.2 QC Reconciliation Reports

**Location:** `outputs/qc/reconciliation_report.html`

**Open in browser:**
```bash
start outputs/qc/reconciliation_report.html  # Windows
open outputs/qc/reconciliation_report.html   # macOS
xdg-open outputs/qc/reconciliation_report.html  # Linux
```

**Expected Content:**
- Summary table: All datasets show "PASS" status
- Discrepancy count: 0 differences for validated datasets
- Drill-down tables: Row-by-row comparison details

**Interpretation:**
- **PASS (0 differences):** Production and QC outputs identical
- **PASS (n differences, all within tolerance):** Numeric precision differences ≤1e-8
- **FAIL:** Investigate discrepancies in drill-down tables

### 5.3 Validation Evidence

**Location:** `validation/evidence/`

**Key Files:**
- `package_risk_scores.csv` - R package validation
- `environment_verification.txt` - System configuration
- `sessionInfo.txt` - R session details

---

## 6. CDISC Compliance Validation

### 6.1 Run Pinnacle 21 Community

**Download:** https://www.pinnacle21.com/products/pinnacle-21-community

**Validation Steps:**
1. Open Pinnacle 21 Community
2. Select "CDISC SDTM Validation"
3. Browse to `outputs/sdtm/`
4. Load `define.xml` (auto-generated by metatools)
5. Click "Validate"

**Acceptance Criteria:**
- 0 errors
- ≤5 warnings (document each in `validation/pinnacle21/warnings_justification.md`)
- Define.xml loads without schema errors

### 6.2 ADaM Validation

Repeat Section 6.1 for `outputs/adam/` with "CDISC ADaM Validation" option

**Expected Results:**
- ADaM IG v1.3 compliance
- All required variables present (STUDYID, USUBJID, PARAMCD, etc.)
- Controlled terminology matches CDISC CT 2023-12-15

---

## 7. Interactive Shiny Dashboard

### 7.1 Launch Application

```r
shiny::runApp('app/app.R', port = 8080)
```

**Access:** http://localhost:8080

### 7.2 Important Usage Disclaimers

**⚠️ REGULATORY NOTICE:**

This interactive application is for **exploratory data visualization only** and:

- ✗ NOT used for regulatory decision-making
- ✗ NOT used to generate results in submission documents
- ✓ Provided for FDA reviewer convenience to navigate datasets
- ✓ Filters and customizations applied in this interface do NOT modify regulatory analyses

**Statistical Safeguards:**
- P-values and statistical inferences have been removed from filterable views to prevent Type I error inflation through post-hoc exploration
- All pre-specified efficacy and safety analyses are documented in the Statistical Analysis Plan
- Regulatory analyses are executed via validated scripts, not this interactive interface

### 7.3 Features

- **Dataset Explorer:** Browse SDTM/ADaM datasets with filtering
- **RECIST Timeline:** Visualize tumor response trajectories
- **Portfolio Dashboard:** Multi-study timeline and dependency tracking
- **QC Status:** Real-time validation status monitoring

---

## 8. Troubleshooting

### 8.1 Common Installation Issues

**Issue:** "renv::restore() fails with compilation errors"

**Solution:**
```r
# Install binary packages instead (Windows)
options(pkgType = "win.binary")
renv::restore()
```

**Issue:** "SAS not found" error during hybrid execution

**Solution:** Verify SAS_EXECUTABLE path in `run_all.R` (see Section 3.4)

**Issue:** "Permission denied" on Linux/macOS

**Solution:**
```bash
chmod +x run_pipeline.sh run_r_only_pipeline.sh
```

### 8.2 QC Failures

**Issue:** QC report shows differences in numeric variables

**Solution:** Check tolerance settings in `qc/compare_datasets.R`:
```r
# Increase tolerance if needed (document justification)
NUMERIC_TOLERANCE <- 1e-8  # Default
```

### 8.3 Performance Issues

**Issue:** Pipeline execution exceeds 4 hours

**Solution:** Enable parallel processing in `run_all.R`:
```r
options(mc.cores = parallel::detectCores() - 1)
```

---

## 9. Technical Support

### 9.1 Contact Information

**Primary Contact:** Christian Baghai  
**Email:** christian.baghai@outlook.fr  
**GitHub:** https://github.com/stiigg

### 9.2 Issue Reporting

**GitHub Issues:** https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/issues

Please include:
- Operating system and version
- R version (`R --version`)
- SAS version (if using hybrid mode)
- Complete error message and log files
- Steps to reproduce issue

### 9.3 Documentation References

- **CDISC Standards:** https://www.cdisc.org/standards
- **pharmaverse Documentation:** https://pharmaverse.org
- **R Validation Hub:** https://www.pharmar.org
- **FDA Study Data Standards:** https://www.fda.gov/industry/fda-data-standards-advisory-board/study-data-standards

---

**Document Version:** 1.0  
**Last Review:** December 14, 2025  
**Next Review:** June 14, 2026  
**Maintained By:** Christian Baghai
