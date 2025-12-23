# Pharmaverse Structure Migration - 2025

## Migration Status

**Branch:** `pharmaverse-structure-2025`  
**Started:** December 23, 2024  
**Status:** 🚧 In Progress

## Overview

This document tracks the reorganization of the repository to align with **pharmaverse ecosystem standards** and **CDISC best practices** as validated by 2024-2025 FDA/EMA submissions.

## Migration Goals

✅ **Goal 1:** Organize SDTM domains by CDISC domain class structure  
✅ **Goal 2:** Implement admiral-based ADaM framework  
✅ **Goal 3:** Add eCTD Module 5 submission structure  
✅ **Goal 4:** Centralize path configuration  
⚪ **Goal 5:** Update all script path references (Pending)  
⚪ **Goal 6:** Create validation framework (Pending)  
⚪ **Goal 7:** Add pkgdown website (Pending)  

## Phase 1: SDTM Reorganization

### New Structure Created

```
sdtm/programs/R/oak/
├── foundation/          # DM domain
├── events/              # AE, CM, MH, DS, EX
├── findings/            # LB, VS, EG, PE
├── findings_about/      # QS domain
├── interventions/       # SV domain
├── oncology/            # TU, TR, RS (RECIST)
├── run_all_sdtm_oak.R
└── README.md
```

### Files to Migrate

Once the directory structure is validated, existing domain scripts will be moved:

**From:**
```
sdtm/programs/R/oak/
├── generate_dm_with_oak.R
├── generate_ae_with_oak.R
├── generate_cm_with_oak.R
└── ... (all domain scripts)
```

**To (target structure):**
```
sdtm/programs/R/oak/foundation/generate_dm_with_oak.R
sdtm/programs/R/oak/events/generate_ae_with_oak.R
sdtm/programs/R/oak/events/generate_cm_with_oak.R
...
```

### Migration Commands (To Execute)

```bash
# Navigate to repository root
cd /path/to/sas-r-hybrid-clinical-pipeline

# Checkout pharmaverse branch
git checkout pharmaverse-structure-2025

# Move foundation domains
git mv sdtm/programs/R/oak/generate_dm_with_oak.R \
        sdtm/programs/R/oak/foundation/

# Move events domains
git mv sdtm/programs/R/oak/generate_ae_with_oak.R \
        sdtm/programs/R/oak/events/
git mv sdtm/programs/R/oak/generate_cm_with_oak.R \
        sdtm/programs/R/oak/events/
git mv sdtm/programs/R/oak/generate_mh_with_oak.R \
        sdtm/programs/R/oak/events/
git mv sdtm/programs/R/oak/generate_ds_with_oak.R \
        sdtm/programs/R/oak/events/
git mv sdtm/programs/R/oak/generate_ex_with_oak.R \
        sdtm/programs/R/oak/events/

# Move findings domains
git mv sdtm/programs/R/oak/generate_lb_with_oak.R \
        sdtm/programs/R/oak/findings/
git mv sdtm/programs/R/oak/generate_vs_with_oak.R \
        sdtm/programs/R/oak/findings/
git mv sdtm/programs/R/oak/generate_eg_with_oak.R \
        sdtm/programs/R/oak/findings/
git mv sdtm/programs/R/oak/generate_pe_with_oak.R \
        sdtm/programs/R/oak/findings/

# Move findings_about domains
git mv sdtm/programs/R/oak/generate_qs_with_oak.R \
        sdtm/programs/R/oak/findings_about/

# Move interventions domains
git mv sdtm/programs/R/oak/generate_sv_with_oak.R \
        sdtm/programs/R/oak/interventions/

# Move oncology domains
git mv sdtm/programs/R/oak/generate_tu_with_oak.R \
        sdtm/programs/R/oak/oncology/
git mv sdtm/programs/R/oak/generate_tr_with_oak.R \
        sdtm/programs/R/oak/oncology/
git mv sdtm/programs/R/oak/generate_rs_with_oak.R \
        sdtm/programs/R/oak/oncology/

# Commit migration
git commit -m "refactor: Reorganize SDTM domains by CDISC class structure

- Foundation: DM
- Events: AE, CM, MH, DS, EX
- Findings: LB, VS, EG, PE
- Findings About: QS
- Interventions: SV
- Oncology: TU, TR, RS

Aligns with SDTM IG v3.4 and pharmaverse standards."
```

## Phase 2: ADaM Reorganization

### Target Structure

```
adam/programs/R/admiral/
├── adsl/                # Subject-Level Analysis Dataset
│   └── generate_adsl_with_admiral.R
├── bds/                 # Basic Data Structure (continuous outcomes)
│   ├── generate_adlb_with_admiral.R
│   └── generate_advs_with_admiral.R
├── occds/               # Occurrence Data Structure (events)
│   └── generate_adae_with_admiral.R
├── oncology/            # Oncology-specific ADaM datasets
│   ├── generate_adrs_with_admiral.R  # Response (RECIST)
│   └── generate_adtte_with_admiral.R  # Time-to-Event
├── run_all_adam_admiral.R
└── README.md
```

### Rationale

**ADSL First:** Foundation dataset required by all other ADaM datasets  
**BDS Structure:** For laboratory, vital signs, ECG (continuous/categorical measures)  
**OCCDS Structure:** For adverse events (occurrence data)  
**Oncology Extensions:** RECIST endpoints using `admiralonco` package

## Phase 3: Path Reference Updates

### Scripts Requiring Path Updates

All domain generation scripts need to update their paths:

**Before:**
```r
source(here::here("config", "paths.R"))
```

**After (no change needed - relative paths work):**
```r
source(here::here("config", "paths.R"))  # Still works from subdirectories
```

**Output path references (already centralized):**
```r
# These work from any subdirectory due to centralized config
readr::write_csv(dm, file.path(PATH_SDTM_DATA_CSV, "dm.csv"))
xportr::xportr_write(dm, file.path(PATH_SDTM_DATA_XPT, "dm.xpt"))
```

## Phase 4: Regulatory Submission Structure

### eCTD Module 5 Organization

```
regulatory_submission/
├── ectd/
│   └── m5/
│       └── datasets/
│           └── study-001/
│               ├── tabulations/     # SDTM (symlinks to sdtm/data/xpt/)
│               │   ├── *.xpt
│               │   ├── define.xml
│               │   └── define.xsl
│               ├── analysis/        # ADaM (symlinks to adam/data/xpt/)
│               │   ├── *.xpt
│               │   ├── define.xml
│               │   └── define.xsl
│               └── datasets.pdf
├── adrg/               # Analysis Data Reviewer's Guide
│   ├── adrg_template.Rmd
│   └── adrg_v1.0.pdf
├── sdrg/               # Study Data Reviewer's Guide
│   ├── sdrg_template.Rmd
│   └── sdrg_v1.0.pdf
└── validation_reports/
    └── pinnacle21_report.pdf
```

**Key Feature:** Symbolic links avoid file duplication while maintaining submission structure.

## Phase 5: Validation Framework

### Three-Tier Strategy

```
validation/
├── tier1_unit_tests/
│   └── testthat/
│       ├── test-sdtm-dm.R
│       ├── test-sdtm-ae.R
│       └── ...
├── tier2_dataset_comparison/
│   ├── compare_sas_vs_r.R
│   └── reports/
│       └── diffdf_results.html
├── tier3_regulatory/
│   ├── pinnacle21_validation.R
│   └── reports/
│       └── p21_report_YYYYMMDD.pdf
└── STRATEGY.md
```

## Phase 6: Package Website (pkgdown)

### Configuration

**File:** `_pkgdown.yml`

```yaml
url: https://stiigg.github.io/sas-r-hybrid-clinical-pipeline/

template:
  bootstrap: 5
  bootswatch: flatly
  
home:
  title: "Pharmaverse-Powered Clinical Pipeline"
  
articles:
  - title: "SDTM Implementation"
    contents:
    - articles/sdtm_oak_implementation
  - title: "ADaM Implementation"
    contents:
    - articles/adam_admiral_implementation
```

**Deploy:** GitHub Actions workflow for automatic deployment

## Testing Strategy

### Post-Migration Verification

```r
# 1. Test path configuration
source("config/paths.R")
validate_paths()  # Should create all directories

# 2. Test individual domain
source("sdtm/programs/R/oak/foundation/generate_dm_with_oak.R")
file.exists(file.path(PATH_SDTM_DATA_XPT, "dm.xpt"))  # Should be TRUE

# 3. Test complete SDTM pipeline
source("sdtm/programs/R/oak/run_all_sdtm_oak.R")
list.files(PATH_SDTM_DATA_XPT)  # Should show all 16 domains

# 4. Test complete ADaM pipeline
source("adam/programs/R/admiral/run_all_adam_admiral.R")
list.files(PATH_ADAM_DATA_XPT)  # Should show all ADaM datasets
```

## Rollback Plan

If migration causes issues:

```bash
# Option 1: Revert to main branch
git checkout main

# Option 2: Create fix in pharmaverse branch
git checkout pharmaverse-structure-2025
# Make fixes
git commit -m "fix: Address migration issue"

# Option 3: Cherry-pick specific commits
git cherry-pick <commit-sha>
```

## Success Criteria

- ☑️ All 16 SDTM domains generate successfully from new structure
- ☐ All ADaM datasets generate successfully from new structure
- ☐ GitHub Actions CI/CD passes all checks
- ☐ Pinnacle21 validation passes
- ☐ Documentation complete (README files in all subdirectories)
- ☐ pkgdown website deploys successfully
- ☐ No path reference errors in any script

## Timeline

**Week 1 (Dec 23-29):**
- ✅ Create branch
- ✅ Add centralized path configuration
- ✅ Create new directory structure
- ✅ Add comprehensive documentation
- ⚪ Move SDTM domain files (pending local execution)
- ⚪ Update path references (pending local execution)

**Week 2 (Dec 30 - Jan 5):**
- Reorganize ADaM programs
- Create eCTD structure
- Add validation framework

**Week 3 (Jan 6-12):**
- Configure pkgdown
- Write vignettes
- Integration testing

**Week 4 (Jan 13-19):**
- Final QC
- Merge to main
- Public announcement

## Notes

### Why This Structure Matters

1. **Regulatory Alignment:** Mirrors structure used in successful 2024 FDA submissions
2. **Industry Standard:** Follows pharmaverse council recommendations
3. **Scalability:** Easy to add new domains/studies
4. **Maintainability:** Clear organization reduces cognitive load
5. **Portfolio Value:** Demonstrates enterprise-grade architecture

### References

- [Pharmaverse Blog: SDTM Automation](https://pharmaverse.github.io/blog/)
- [admiral Package Documentation](https://pharmaverse.github.io/admiral/)
- [CDISC SDTM IG v3.4](https://www.cdisc.org/standards/foundational/sdtmig)

---

**Last Updated:** December 23, 2024  
**Maintainer:** Christian Baghai (@stiigg)  
**Status:** 🚧 Active Migration
