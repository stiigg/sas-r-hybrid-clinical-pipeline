# ADTR Pipeline Quick Start Guide

**Version:** 3.1  
**Last Updated:** 2026-01-04  
**Author:** Christian Baghai

---

## Prerequisites

1. **SAS Environment**: SAS 9.4 or later
2. **Project Structure**: Clone repository to local workspace
3. **Data**: SDTM datasets (TR, TU, DM or ADSL) in CSV format
4. **Environment Variable**: Set `PROJ_ROOT` to repository path

---

## Quick Start: Running ADTR Programs

### Option 1: Consolidated Program (Recommended)

**Best for:** Production execution with all validations

```bash
# Set project root
export PROJ_ROOT=/path/to/sas-r-hybrid-clinical-pipeline

# Run consolidated program
cd $PROJ_ROOT/adam/programs/sas
sas 80_adam_adtr_consolidated.sas
```

**What it does:**
- Automatically loads ADTR_CORE package with all utilities
- Imports TR/TU data with validation
- Runs quality control checks  
- Reports data quality issues in log
- Creates ADTR dataset per RECIST 1.1

**Expected runtime:** 2-5 minutes depending on data size

---

### Option 2: Original ADTR Program

**Best for:** Basic SDIAM-only analysis

```bash
cd $PROJ_ROOT/adam/programs/sas
sas 80_adam_adtr.sas
```

**Features:**
- Simple SLD (Sum of Longest Diameters) parameter
- Baseline and nadir derivations
- Percent change calculations
- Fast execution (~2 minutes)

---

### Option 3: Enhanced BDS Program

**Best for:** Regulatory submission with full BDS structure

```bash
cd $PROJ_ROOT/adam/programs/sas
sas 80_adam_adtr_v2.sas
```

**Features:**
- Multiple parameters: LDIAM, SDIAM, SNTLDIAM
- PARCAT1/2/3 categorization
- CRIT1-4 algorithm flags
- ANL01-04 analysis flags
- Full CDISC ADaM compliance
- Longer execution (~5-7 minutes)

---

## Configuration

### Set Execution Mode

Edit `config/global_parameters.sas`:

```sas
/* MODE 1: Basic SDIAM only (fast execution) */
%let ADTR_MODE = 1;

/* MODE 2: Enhanced BDS with LDIAM+SDIAM+SNTLDIAM (regulatory ready) */
%let ADTR_MODE = 2;
```

### Configure Paths

```sas
%let SDTM_PATH = ../../sdtm/data/csv;  /* Your SDTM data location */
%let ADAM_PATH = ../../adam/data;       /* ADaM output location */
```

### Algorithm Options

```sas
/* BASELINE METHOD */
%let BASELINE_METHOD = PRETREAT;  /* PRETREAT or FIRST */

/* NADIR CALCULATION */
%let NADIR_EXCLUDE_BASELINE = 1;  /* 1=Exclude baseline per Vitale 2025, 0=Include */

/* ENAWORU 25MM RULE */
%let APPLY_ENAWORU_RULE = 1;      /* 1=Apply 25mm threshold for progression, 0=Standard */

/* VALIDATION */
%let VALIDATE_IMPORTS = 1;        /* 1=Validate all imports, 0=Skip */
%let RUN_VALIDATION = 1;          /* 1=Run QC checks, 0=Skip */
```

---

## Troubleshooting

### ERROR: File not found: path/tr.csv

**Cause:** SDTM_PATH incorrect or tr.csv doesn't exist

**Solution:**
1. Verify `config/global_parameters.sas` has correct path
2. Check that `tr.csv` exists: `ls $PROJ_ROOT/sdtm/data/csv/tr.csv`
3. Verify file permissions: `chmod 644 $PROJ_ROOT/sdtm/data/csv/tr.csv`

---

### ERROR: USUBJID not found

**Cause:** Source data not CDISC SDTM compliant

**Solution:**
1. Open `tr.csv` and verify column headers
2. Check for USUBJID column (required SDTM variable)
3. If using non-standard data, map to SDTM format first

---

### ERROR: Package ADTR_CORE not found

**Cause:** PROJ_ROOT not set or incorrect

**Solution:**
1. Set environment variable: `export PROJ_ROOT=/path/to/repo`
2. Or edit program directly:
   ```sas
   %let PROJ_ROOT = /your/full/path/sas-r-hybrid-clinical-pipeline;
   ```
3. Verify packages directory exists: `ls $PROJ_ROOT/adam/programs/sas/packages/`

---

### WARNING: Nadir exceeds baseline

**Cause:** Data quality issue or algorithm error

**Solution:**
1. Review subject-level data in log
2. Check TRDY values for correct visit ordering
3. Verify BASEFL='Y' assigned to correct record
4. Set `DEBUG_MODE=1` in config for detailed output

---

## Validation Testing

### Run Unit Tests

```bash
cd $PROJ_ROOT/adam/programs/sas/validation/unit_tests
sas test_derive_baseline.sas
```

**Expected:** All tests PASS with summary statistics

---

### Run Integration Tests

```bash
cd $PROJ_ROOT/adam/programs/sas/validation/integration_tests
sas test_import_tr_integration.sas
```

**Expected:** 5/5 tests PASSED

---

## Output Files

Successful execution creates:

```
adam/data/
├── adtr.csv                 # CSV format for analysis
└── xpt/
    └── adtr.xpt             # XPT transport for submission
```

### Verify Output

```bash
# Check record counts
wc -l $PROJ_ROOT/adam/data/adtr.csv

# Preview first 10 records
head $PROJ_ROOT/adam/data/adtr.csv

# Check for QC flags
grep "ERROR\|WARNING" $PROJ_ROOT/adam/programs/sas/*.log
```

---

## Next Steps

1. **Review Output**: Check ADTR dataset for completeness
2. **QC Validation**: Review log for QCFLAG warnings
3. **Waterfall Data**: Use output for tumor response plots
4. **ADRS Derivation**: Use ADTR as input for Best Overall Response
5. **TLFs**: Generate tables, listings, figures

---

## Getting Help

- **Documentation**: See [README.md](README.md) for full details
- **Macro Help**: Run `%package_info(ADTR_CORE);` for macro documentation
- **Issues**: Check repository issues or create new one
- **Contact**: christian.baghai@outlook.fr

---

## Quick Reference Commands

```bash
# Full pipeline from scratch
export PROJ_ROOT=/path/to/repo
cd $PROJ_ROOT/adam/programs/sas
sas 80_adam_adtr_consolidated.sas

# Run with specific mode
sas -sysparm "MODE=1" 80_adam_adtr_consolidated.sas    # Fast mode
sas -sysparm "MODE=2" 80_adam_adtr_consolidated.sas    # Full BDS

# Check execution log
tail -100 80_adam_adtr_consolidated.log | grep "NOTE:\|ERROR:\|WARNING:"

# Validate outputs
diff adam/data/adtr.csv adam/data/archived/adtr_baseline.csv
```

---

**For detailed architecture and development information, see [README.md](README.md)**
