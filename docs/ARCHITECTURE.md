# Architecture Documentation

## System Overview

This pipeline implements a metadata-driven ETL architecture for clinical trial data processing, supporting concurrent execution of multiple studies with automated dependency management.

## Core Components

### 1. Study Registry (`studies/portfolio_registry.yml`)

Central configuration file defining:
- Study metadata (phase, status, sample size)
- Execution priorities (1=highest)
- CDISC version specifications
- Database lock dates and milestones

**Design Pattern**: Registry pattern with YAML-based declarative configuration.

### 2. Orchestration Engine (`automation/portfolio_runner.R`)

Responsibilities:
- Parse study registry and filter by priority threshold
- Build execution DAG based on dependencies
- Schedule study processing with parallel execution
- Aggregate logs and status reports

**Design Pattern**: Pipeline orchestration with topological sorting for dependency resolution.

### 3. Derivation Library (`etl/adam_program_library/`)

Modular library structure:
```
adam_program_library/
├── oncology_response/
│   ├── recist_11_macros.R      # RECIST derivation functions
│   ├── derive_bor.R            # Best Overall Response
│   ├── calculate_orr.R         # Objective Response Rate
│   └── tests/                  # Unit tests for each function
├── time_to_event/
│   ├── derive_tte.R            # Time-to-event endpoints
│   └── survival_functions.R   # Kaplan-Meier utilities
└── safety_standards/
    ├── derive_ae_summary.R     # Adverse event summaries
    └── lab_shift_tables.R      # Laboratory shift derivations
```

**Design Pattern**: Library pattern with functional programming approach, avoiding side effects.

### 4. Quality Control Framework (`qc/`)

Independent double-programming architecture:
- QC programs in `qc/r/` mirror production programs in `etl/`
- Automated comparison using `diffdf` package
- Discrepancy reports generated in `outputs/qc/`

**Design Pattern**: Test double with automated reconciliation.

### 5. Metadata Management

Uses `metacore` and `metatools` for specification-driven programming:

```
# Load metadata
metadata <- metacore::metacore("specs/adsl_spec.yaml")

# Build dataset from spec
adsl <- dataset %>%
  metatools::build_from_derived(metadata) %>%
  metatools::drop_unspec_vars(metadata) %>%
  metatools::check_variables(metadata)
```

**Design Pattern**: Specification pattern with metadata-driven validation.

## Data Flow

```
Raw Data (EDC)
    ↓
SDTM Transformation (etl/sdtm/)
    ↓
SDTM Datasets (studies/STUDY00X/data/sdtm/)
    ↓
ADaM Derivation (etl/adam/ + adam_program_library/)
    ↓
ADaM Datasets (studies/STUDY00X/data/adam/)
    ↓
Quality Control (qc/)
    ↓
TLF Generation (outputs/tlf/)
```

### Cross-Study Data Flow

```
STUDY001/adam/   ─┐
STUDY002/adam/   ─┼→ Pooled ISS (studies/pooled_analyses/ISS/)
STUDY003/adam/   ─┘

STUDY001/adam/   ─┬→ Pooled ISE (studies/pooled_analyses/ISE/)
STUDY002/adam/   ─┘
```

## Dependency Management

### Study-Level Dependencies

Defined in `studies/portfolio_registry.yml`:

```
pooled_analyses:
  ISS:
    depends_on: [STUDY001, STUDY002, STUDY003]
    min_lead_time_days: 21
    
  ISE:
    depends_on: [STUDY001, STUDY002]
    min_lead_time_days: 14
```

### Execution Order Resolution

The `automation/dependencies.R` module:
1. Parses dependency declarations
2. Builds directed acyclic graph (DAG)
3. Performs topological sort
4. Detects circular dependencies
5. Calculates critical path for timeline visualization

## Parallel Execution Strategy

### Study-Level Parallelization

Independent studies execute concurrently:
```
# In portfolio_runner.R
study_results <- parallel::mclapply(
  eligible_studies,
  function(study) run_study_pipeline(study),
  mc.cores = min(length(eligible_studies), parallel::detectCores() - 1)
)
```

### Dataset-Level Parallelization

Within a study, independent ADaM datasets execute in parallel:
```
# In run_all.R
adam_datasets <- c("ADSL", "ADAE", "ADLB", "ADVS")
parallel::mclapply(
  adam_datasets,
  function(ds) source(paste0("etl/adam/gen_", tolower(ds), ".R")),
  mc.cores = 4
)
```

**Constraint**: Datasets with dependencies (e.g., ADRS requires ADSL) execute sequentially.

## Error Handling and Logging

### Logging Architecture

Three-tier logging system:
1. **Study-level logs**: `logs/STUDY00X/study_execution.log`
2. **Dataset-level logs**: `logs/STUDY00X/adam/gen_adsl.log`
3. **Portfolio-level logs**: `logs/portfolio_runner.log`

### Error Recovery

```
# In portfolio_runner.R
tryCatch(
  {
    result <- run_study_pipeline(study)
    log_success(study, result)
  },
  error = function(e) {
    log_error(study, e)
    if (study$priority == 1) {
      stop("Critical study failed: ", study$id)
    } else {
      warning("Non-critical study failed: ", study$id)
    }
  }
)
```

**Strategy**: Fail-fast for Priority 1 studies; continue with warnings for lower priorities.

## Configuration Management

### Environment-Specific Configuration

```
# Development
ETL_DRY_RUN=true Rscript run_all.R

# Production
ETL_DRY_RUN=false QC_ENABLED=true Rscript run_all.R
```

### Configuration Hierarchy

1. **Default values**: Hardcoded in scripts
2. **Project config**: `studies/portfolio_registry.yml`
3. **Study config**: `studies/STUDY00X/config/study_metadata.yml`
4. **Environment variables**: Runtime overrides

Later configurations override earlier ones.

## Performance Characteristics

### Execution Times (Typical)

- ADSL generation: 2-5 minutes (n=850)
- ADAE generation: 10-15 minutes (n=850, ~3000 AEs)
- ADLB generation: 20-30 minutes (n=850, ~50K labs)
- Full study pipeline: 45-60 minutes
- Pooled ISS: 30-40 minutes (1,015 patients)

### Memory Usage

- Peak memory per study: 2-4 GB
- Recommended system RAM: 16 GB (for 3 concurrent studies)
- Swap usage: Minimal if sufficient RAM available

### Scalability Limits

- Concurrent studies: Tested up to 5 studies
- Maximum patients per study: Tested up to 2,000
- Maximum pooled analysis: Tested with 3,000 patients

## Security Considerations

### Data Handling

- No PHI/PII in repository (all data is synthetic)
- Real data should be stored outside version control
- Use environment variables for sensitive paths: `DATA_ROOT=/secure/path/to/data`

### Access Control

For production deployments:
- Restrict write access to `studies/` directory
- Separate production and validation environments
- Use read-only mounts for source data

## Testing Strategy

### Unit Tests (`tests/testthat/`)

Test individual derivation functions:
```
test_that("derive_bor calculates correct Best Overall Response", {
  input <- data.frame(
    USUBJID = c("001", "001", "001"),
    VISIT = c(1, 2, 3),
    AVALC = c("PD", "PR", "CR")
  )
  
  result <- derive_bor(input)
  
  expect_equal(result$BOR[result$USUBJID == "001"], "CR")
})
```

### Integration Tests (`tests/integration/`)

Test full pipeline execution:
```
test_that("ADSL generation completes without errors", {
  expect_no_error(source("etl/adam/gen_adsl.R"))
  expect_true(file.exists("studies/STUDY001/data/adam/adsl.sas7bdat"))
})
```

### Validation Tests (`validation/`)

Test regulatory compliance:
```
test_that("ADSL conforms to CDISC ADaM IG v1.3", {
  adsl <- haven::read_sas("studies/STUDY001/data/adam/adsl.sas7bdat")
  
  # Required variables
  expect_true(all(c("STUDYID", "USUBJID", "SUBJID") %in% names(adsl)))
  
  # Variable attributes
  expect_equal(attr(adsl$TRTA, "label"), "Actual Treatment")
})
```

## Future Enhancements

### Planned Features

1. **Cloud deployment**: Containerization with Docker, orchestration with Kubernetes
2. **Real-time monitoring**: WebSocket-based dashboard updates
3. **Advanced scheduling**: Cron-based automated execution
4. **Data provenance**: Blockchain-style audit trail for derivations
5. **Machine learning QC**: Anomaly detection for flagging unusual patterns

### Technical Debt

1. Hard-coded RECIST confirmation period (28 days) - should be configurable
2. Limited support for adaptive trial designs
3. Dashboard lacks authentication/authorization
4. No automated rollback for failed executions

## References

- [CDISC SDTM IG v3.4](https://www.cdisc.org/standards/foundational/sdtm)
- [CDISC ADaM IG v1.3](https://www.cdisc.org/standards/foundational/adam)
- [RECIST 1.1 Criteria](https://pubmed.ncbi.nlm.nih.gov/19058754/)
- [Pharmaverse Documentation](https://pharmaverse.org)
- [Admiral Package Guide](https://pharmaverse.github.io/admiral/)
