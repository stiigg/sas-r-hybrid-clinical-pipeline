# User Guide

## Target Audience

This guide is for:
- Statistical programmers implementing SDTM/ADaM transformations
- Data managers configuring study pipelines
- Biostatisticians needing to understand data processing
- Regulatory affairs personnel reviewing validation documentation

## Getting Started

### Installation

#### System Requirements

- **Operating System**: Linux (Ubuntu 20.04+), macOS (11+), or Windows 10+ with WSL2
- **R Version**: >= 4.2.0
- **RAM**: 16 GB recommended for concurrent study processing
- **Disk Space**: 10 GB for software + 5 GB per study

#### Step-by-Step Setup

1. **Install R**
   ```
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install r-base r-base-dev
   
   # macOS (with Homebrew)
   brew install r
   ```

2. **Install System Dependencies**
   ```
   # Ubuntu/Debian
   sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev
   
   # macOS
   brew install curl openssl libxml2
   ```

3. **Clone Repository**
   ```
   git clone https://github.com/stiigg/sas-r-hybrid-clinical-pipeline.git
   cd sas-r-hybrid-clinical-pipeline
   ```

4. **Install R Packages**
   ```
   Rscript install_pharmaverse.R
   ```
   
   This installs:
   - admiral, metacore, metatools (pharmaverse core)
   - shiny, plotly (dashboard)
   - testthat, covr (testing)
   - Additional dependencies from renv.lock

5. **Verify Installation**
   ```
   Rscript -e "library(admiral); library(metacore); library(shiny)"
   # Should complete without errors
   ```

### Running Your First Pipeline

Execute the example STUDY001 pipeline:

```
# Dry run (validates configuration without processing data)
Rscript run_all.R

# Full execution
ETL_DRY_RUN=false Rscript run_all.R
```

**Expected output:**
```
[INFO] Loading study configuration...
[INFO] Processing SDTM transformations...
[INFO] Generating ADSL...
[INFO] Generating ADAE...
[SUCCESS] Pipeline completed in 12.3 minutes
[INFO] Outputs written to: studies/STUDY001/data/adam/
```

## Common Workflows

### Workflow 1: Adding a New Study

**Scenario**: You need to add STUDY004 (Phase II, n=200, Priority 2)

**Steps**:

1. **Update Portfolio Registry**
   
   Edit `studies/portfolio_registry.yml`:
   ```
   studies:
     STUDY004:
       phase: "II"
       status: "Active"
       n_patients: 200
       priority: 2
       sdtm_version: "1.7"
       database_lock: "2026-03-31"
       indication: "NSCLC"
       treatment_arms: ["Compound-X 100mg", "Placebo"]
   ```

2. **Create Study Directory Structure**
   ```
   mkdir -p studies/STUDY004/{config,data/{raw,sdtm,adam},outputs,logs}
   ```

3. **Copy Configuration Template**
   ```
   cp studies/STUDY001/config/study_metadata.yml studies/STUDY004/config/
   ```

4. **Customize Study Metadata**
   
   Edit `studies/STUDY004/config/study_metadata.yml`:
   ```
   study_id: "STUDY004"
   protocol: "STUDY004"
   sponsor: "Acme Pharma"
   
   adam_datasets:
     - ADSL
     - ADAE
     - ADLB
     - ADVS
     - ADRS
   
   recist_confirmation_period: 28
   ```

5. **Place Raw Data**
   ```
   # Copy raw data files to studies/STUDY004/data/raw/
   cp /path/to/raw/*.csv studies/STUDY004/data/raw/
   ```

6. **Validate Configuration**
   ```
   Rscript automation/validate_study_config.R STUDY004
   ```
   
   Expected output:
   ```
   [✓] Study ID is valid
   [✓] SDTM version is supported
   [✓] Required directories exist
   [✓] Raw data files found
   [✓] Configuration syntax is valid
   ```

7. **Run Study Pipeline**
   ```
   STUDY_ID=STUDY004 Rscript run_all.R
   ```

### Workflow 2: Modifying Database Lock Date

**Scenario**: STUDY001 database lock delayed from 2025-06-30 to 2025-07-15

**Steps**:

1. **Update Portfolio Registry**
   ```
   studies:
     STUDY001:
       database_lock: "2025-07-15"  # Changed from 2025-06-30
   ```

2. **Analyze Downstream Impacts**
   ```
   Rscript automation/dependencies.R \
     --study STUDY001 \
     --new-date 2025-07-15 \
     --report
   ```
   
   Output shows affected milestones:
   ```
   [WARNING] Impact Analysis for STUDY001 DB Lock Change
   
   Affected Deliverables:
   - Pooled ISS: Requires 21-day lead time
     Original delivery: 2025-06-09
     New delivery: 2025-06-24
     Impact: 15-day delay
   
   Critical Path Status:
   - NDA submission date: 2025-07-30 (FIXED)
   - New buffer: 6 days (was 21 days)
   - Risk level: MEDIUM (buffer < 10 days)
   ```

3. **Visualize Timeline**
   ```
   Rscript -e "shiny::runApp('app/app.R')"
   # Navigate to "Timeline" tab to see Gantt chart
   ```

4. **Communicate Changes**
   ```
   # Generate stakeholder report
   Rscript automation/generate_timeline_report.R --output timeline_update.html
   ```

### Workflow 3: Running Pooled Analysis

**Scenario**: Generate Integrated Safety Summary (ISS) from 3 studies

**Prerequisites**:
- All contributing studies have completed database lock
- ADaM datasets exist for STUDY001, STUDY002, STUDY003

**Steps**:

1. **Verify Study Completion**
   ```
   Rscript automation/check_pooled_readiness.R --analysis ISS
   ```
   
   Output:
   ```
   [✓] STUDY001: ADSL, ADAE, ADLB complete
   [✓] STUDY002: ADSL, ADAE, ADLB complete
   [✓] STUDY003: ADSL, ADAE, ADLB complete (SDTM 1.5 harmonized)
   [INFO] All prerequisites met for ISS
   ```

2. **Configure Pooled Analysis**
   
   Edit `studies/pooled_analyses/ISS/config/iss_metadata.yml`:
   ```
   analysis_id: "ISS"
   analysis_type: "safety"
   contributing_studies:
     - STUDY001
     - STUDY002
     - STUDY003
   
   datasets:
     - ADSL
     - ADAE
     - ADLB
   
   study_weights:
     equal: true  # Equal weighting across studies
   ```

3. **Run Pooled ISS**
   ```
   ANALYSIS=ISS Rscript etl/pooled_analyses/run_pooled_analysis.R
   ```
   
   Processing steps:
   ```
   [INFO] Loading ADSL from 3 studies...
   [INFO] Harmonizing treatment variables...
   [INFO] Stacking datasets (n=1,015 total)...
   [INFO] Deriving pooled safety parameters...
   [INFO] Generating ISS-specific ADaM datasets...
   [SUCCESS] Pooled ISS complete
   [INFO] Output: studies/pooled_analyses/ISS/data/adam/
   ```

4. **Validate Pooled Datasets**
   ```
   Rscript validation/check_pooled_consistency.R --analysis ISS
   ```
   
   Checks performed:
   - Subject counts match expected totals
   - No duplicate subjects across studies
   - Treatment variable consistency
   - Variable type/length consistency
   - Label alignment across studies

### Workflow 4: Quality Control Review

**Scenario**: Perform double-programming QC on ADSL

**Steps**:

1. **Generate Production ADSL**
   ```
   Rscript etl/adam/gen_adsl.R
   ```

2. **Generate QC ADSL (Independent)**
   ```
   Rscript qc/r/adam/qc_adam_adsl.R
   ```

3. **Run Comparison**
   ```
   Rscript qc/compare_datasets.R \
     --prod studies/STUDY001/data/adam/adsl.sas7bdat \
     --qc outputs/qc/adsl_qc.sas7bdat \
     --output outputs/qc/adsl_comparison.html
   ```

4. **Review Discrepancies**
   
   Open `outputs/qc/adsl_comparison.html`. The report shows:
   - **Summary**: Match rate, discrepancy count
   - **Variable-level**: Variables with differences
   - **Subject-level**: Specific subjects with discrepancies
   - **Value-level**: Expected vs. actual values

5. **Reconcile Differences**
   
   If discrepancies found:
   ```
   # Log investigation
   echo "Investigating ADSL discrepancies..." >> logs/qc_reconciliation.log
   
   # Review derivation logic
   vim etl/adam/gen_adsl.R
   
   # Re-run after fix
   Rscript etl/adam/gen_adsl.R
   Rscript qc/compare_datasets.R --prod ... --qc ...
   ```

6. **Document Sign-Off**
   ```
   # After perfect match
   Rscript qc/sign_off_dataset.R --dataset ADSL --study STUDY001
   ```
   
   Creates sign-off record:
   ```
   Dataset: ADSL
   Study: STUDY001
   QC Status: PASSED
   Discrepancies: 0
   QC Programmer: [Your Name]
   Sign-Off Date: 2025-12-06
   ```

## Dashboard Usage

### Launching Dashboard

```
Rscript -e "shiny::runApp('app/app.R', port=8080, host='0.0.0.0')"
```

Access at: `http://localhost:8080`

### Dashboard Features

#### Study Overview Tab

Displays:
- Active studies with status indicators
- Priority levels and patient counts
- Database lock dates
- Progress bars for completion percentage

**Use Case**: Quick portfolio status check

#### Timeline Tab

Shows:
- Gantt chart of study milestones
- Critical path highlighting
- Database lock dates
- Pooled analysis dependencies

**Use Case**: Identify scheduling conflicts and timeline risks

#### Dependencies Tab

Visualizes:
- Directed graph of study dependencies
- Cross-study data flows
- Pooled analysis requirements

**Use Case**: Understand impact of study delays

#### Resource Allocation Tab

Displays:
- Programmer assignments
- Study workload distribution
- CRO vendor assignments

**Use Case**: Balance workload and identify bottlenecks

### Dashboard Filters

Apply filters to focus on specific studies:
- **Priority**: Show only Priority 1 studies
- **Status**: Filter by Active/Complete/Planned
- **Phase**: Show only Phase III studies
- **Date Range**: Filter milestones by date

## Troubleshooting

### Issue: "Package 'admiral' not found"

**Cause**: R packages not installed

**Solution**:
```
Rscript install_pharmaverse.R
```

If that fails:
```
# Install manually in R console
install.packages("admiral", repos = "https://cloud.r-project.org")
```

### Issue: "Study configuration not found"

**Cause**: Study not defined in portfolio registry

**Solution**:
1. Verify study exists:
   ```
   cat studies/portfolio_registry.yml | grep STUDY001
   ```

2. Add if missing:
   ```
   studies:
     STUDY001:
       phase: "III"
       # ... other parameters
   ```

### Issue: Pipeline hangs during execution

**Cause**: Insufficient memory for parallel processing

**Solution**:
1. Check memory usage:
   ```
   free -h  # Linux
   top      # Monitor in real-time
   ```

2. Reduce parallelization:
   ```
   # In run_all.R
   options(mc.cores = 2)  # Reduce from default 4
   ```

3. Execute studies sequentially:
   ```
   PARALLEL=false Rscript run_all.R
   ```

### Issue: SDTM validation errors

**Cause**: Data doesn't conform to CDISC standards

**Solution**:
1. Review error log:
   ```
   cat logs/STUDY001/sdtm/validation_errors.log
   ```

2. Common fixes:
   - Missing required variables: Add to ETL script
   - Invalid controlled terminology: Update to CT 2024-12-20
   - Incorrect variable types: Check specification

3. Re-validate:
   ```
   Rscript validation/validate_sdtm.R STUDY001
   ```

### Issue: QC discrepancies won't resolve

**Cause**: Different derivation logic or input data

**Solution**:
1. Compare input data:
   ```
   prod_input <- haven::read_sas("data/sdtm/dm.sas7bdat")
   qc_input <- haven::read_sas("qc/data/dm.sas7bdat")
   all.equal(prod_input, qc_input)
   ```

2. Trace derivation step-by-step:
   ```
   # Add debug prints to gen_adsl.R
   print("Step 1: Merge DM and SUPPDM")
   print(nrow(adsl_step1))
   ```

3. Document as known difference if justified:
   ```
   # Add to qc/reconciliation_log.csv
   Dataset,Variable,Subject,Reason,Status
   ADSL,AGE,001-001,Rounding difference,ACCEPTABLE
   ```

## Best Practices

### Configuration Management

- **Version control**: Always commit configuration changes with descriptive messages
- **Documentation**: Comment non-obvious YAML parameters
- **Validation**: Run `validate_study_config.R` before executing pipelines
- **Backup**: Keep copy of working configuration before major changes

### Data Quality

- **Validation early**: Run SDTM validation before proceeding to ADaM
- **Logging**: Enable verbose logging during development
- **Unit tests**: Add test cases for custom derivations
- **Manual review**: Spot-check key variables (AGE, SEX, treatment arms)

### Performance

- **Parallel execution**: Use for independent studies/datasets
- **Data.table**: For large datasets (n > 1000), use data.table instead of data.frame
- **Incremental updates**: Only reprocess changed datasets
- **Resource monitoring**: Watch CPU/memory during execution

### Collaboration

- **Branching**: Use feature branches for development
- **Pull requests**: Require peer review for production code
- **Documentation**: Update README when changing workflows
- **Communication**: Notify team of database lock date changes

## Advanced Topics

### Custom Derivations

Creating a new derivation function:

```
# File: etl/adam_program_library/oncology_response/derive_ttp.R

#' Derive Time to Progression
#'
#' @param dataset Input dataset with tumor assessments
#' @param subject_keys Character vector of subject ID variables
#' @return Dataset with TTP variable
#' @export
derive_ttp <- function(dataset, subject_keys = c("STUDYID", "USUBJID")) {
  # Implementation
  # ...
  
  return(dataset)
}
```

Add unit test:
```
# File: tests/testthat/test-derive-ttp.R

test_that("derive_ttp handles censoring correctly", {
  input <- data.frame(
    USUBJID = c("001", "001", "001"),
    ADT = as.Date(c("2025-01-01", "2025-02-01", "2025-03-01")),
    AVALC = c("SD", "SD", "PD")
  )
  
  result <- derive_ttp(input)
  
  expect_equal(result$TTP, 59)  # Days from start to PD[1]
})
```

### Cloud Deployment

Deploy to AWS using Docker:

```
# Dockerfile
FROM rocker/r-ver:4.3.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev

# Copy application
WORKDIR /app
COPY . /app

# Install R packages
RUN Rscript install_pharmaverse.R

# Run pipeline
CMD ["Rscript", "run_all.R"]
```

Build and run:
```
docker build -t clinical-pipeline .
docker run -v /data:/app/studies clinical-pipeline
```

### CI/CD Integration

GitHub Actions workflow:

```
# .github/workflows/pipeline.yml
name: Run Pipeline Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: r-lib/actions/setup-r@v2
      - name: Install dependencies
        run: Rscript install_pharmaverse.R
      - name: Run tests
        run: Rscript -e "testthat::test_dir('tests/testthat')"
```

## FAQ

**Q: Can I use this pipeline with SAS data?**  
A: Yes, the pipeline reads/writes SAS datasets via the `haven` package.

**Q: How do I handle missing data in derivations?**  
A: Use `na.omit()` or `complete.cases()` with appropriate documentation in logs.

**Q: What if my study uses SDTM 1.4 instead of 1.7?**  
A: Update `sdtm_version` in portfolio registry. The harmonization module handles version differences.

**Q: Can I add custom ADaM datasets beyond standard?**  
A: Yes, create new generation script in `etl/adam/` and add to study metadata YAML.

**Q: How do I export datasets for regulatory submission?**  
A: Use `export_for_submission.R` to generate Define.xml and xpt files.

## Getting Help

1. **Documentation**: Check [docs/](docs/) directory
2. **Examples**: Review example studies in `studies/STUDY00X/`
3. **Issues**: Search [GitHub issues](https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/issues)
4. **Community**: Post questions to pharmaverse Slack or Posit Community

## Appendix: Command Reference

### Pipeline Execution
```
# Run all studies
./run_portfolio.sh

# Run specific study
STUDY_ID=STUDY001 Rscript run_all.R

# Run with priority filter
PRIORITY_THRESHOLD=1 ./run_portfolio.sh

# Dry run (validation only)
ETL_DRY_RUN=true Rscript run_all.R
```

### Quality Control
```
# Run QC for specific dataset
Rscript qc/r/adam/qc_adam_adsl.R

# Compare production vs QC
Rscript qc/compare_datasets.R --prod <file> --qc <file>

# Sign off dataset
Rscript qc/sign_off_dataset.R --dataset ADSL --study STUDY001
```

### Validation
```
# Validate study configuration
Rscript automation/validate_study_config.R STUDY001

# Validate SDTM conformance
Rscript validation/validate_sdtm.R STUDY001

# Check pooled analysis readiness
Rscript automation/check_pooled_readiness.R --analysis ISS
```

### Dashboard
```
# Launch dashboard
Rscript -e "shiny::runApp('app/app.R')"

# Launch on specific port
Rscript -e "shiny::runApp('app/app.R', port=3838)"
```

### Testing
```
# Run all tests
Rscript -e "testthat::test_dir('tests/testthat')"

# Run specific test file
Rscript -e "testthat::test_file('tests/testthat/test-derive-bor.R')"

# Generate coverage report
Rscript -e "covr::package_coverage()"
```
