# Clinical Trial Data Pipeline - Multi-Study Orchestration

A production-ready R pipeline for SDTM/ADaM data transformations across concurrent oncology trials, built on pharmaverse packages with automated quality control and interactive monitoring.

## Features

- **Multi-Study Processing**: Concurrent execution of Phase I-III trials with priority-based queuing
- **RECIST 1.1 Standardization**: Validated derivation library for tumor response endpoints (BOR, ORR, DoR)
- **Pooled Analysis Support**: Integrated Safety/Efficacy Summary (ISS/ISE) coordination
- **Metadata-Driven Architecture**: YAML-based study registry with automated dependency tracking
- **Quality Control Framework**: R-based QC with automated reconciliation reports
- **Interactive Dashboard**: Shiny application for portfolio monitoring and timeline visualization

## Quick Start

### Prerequisites
```
# R >= 4.2 required
# System dependencies (Linux/Mac)
sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev
```

### Installation
```
git clone https://github.com/stiigg/sas-r-hybrid-clinical-pipeline.git
cd sas-r-hybrid-clinical-pipeline
Rscript install_pharmaverse.R
```

### Basic Execution
```
# Run all active studies
./run_portfolio.sh

# Run high-priority studies only
PRIORITY_THRESHOLD=1 ./run_portfolio.sh

# Run single study
Rscript run_all.R
```

### Launch Dashboard
```
Rscript -e "shiny::runApp('app/app.R')"
# Access at http://localhost:8080
```

## Repository Structure

```
├── studies/                    # Study-specific configurations and data
│   ├── portfolio_registry.yml  # Master study registry
│   ├── STUDY001/              # Phase III (n=850, Priority 1)
│   ├── STUDY002/              # Phase II (n=120, Priority 2)
│   ├── STUDY003/              # Phase I (n=45, Priority 3, completed)
│   └── pooled_analyses/
│       ├── ISS/               # Integrated Safety (1,015 patients)
│       └── ISE/               # Integrated Efficacy (970 patients)
├── etl/                       # ETL and derivation modules
│   ├── adam_program_library/  # Standardized ADaM derivations
│   │   ├── oncology_response/ # RECIST 1.1 macros
│   │   ├── time_to_event/     # TTE endpoints
│   │   └── safety_standards/  # Safety parameters
│   ├── sdtm/                  # SDTM transformation scripts
│   └── adam/                  # ADaM dataset generation
├── automation/                # Orchestration and scheduling
│   ├── portfolio_runner.R     # Multi-study execution engine
│   └── dependencies.R         # Cross-study dependency tracker
├── qc/                        # Quality control framework
├── validation/                # Validation reports and test results
├── app/                       # Shiny dashboard
└── outputs/                   # Generated datasets and reports

```

## Configuration

### Study Registry (`studies/portfolio_registry.yml`)

```
studies:
  STUDY001:
    phase: "III"
    status: "Active"
    n_patients: 850
    priority: 1
    sdtm_version: "1.7"
    database_lock: "2025-06-30"
    
  STUDY002:
    phase: "II"
    status: "Active"
    n_patients: 120
    priority: 2
    sdtm_version: "1.7"
    database_lock: "2025-05-01"
```

### Adding a New Study

1. Add study entry to `portfolio_registry.yml`
2. Create study directory: `mkdir studies/STUDY00X`
3. Copy configuration template: `cp studies/STUDY001/config/study_metadata.yml studies/STUDY00X/config/`
4. Update metadata with study-specific parameters
5. Run validation: `Rscript automation/validate_study_config.R STUDY00X`

## Use Cases

### Scenario 1: Timeline Impact Analysis

When a study's database lock date changes:

```
# Update portfolio_registry.yml with new date
vim studies/portfolio_registry.yml

# Analyze downstream impacts
Rscript automation/dependencies.R --study STUDY001 --new-date 2025-07-15

# View timeline visualization in dashboard
Rscript -e "shiny::runApp('app/app.R')"
```

The dependency tracker identifies:
- Pooled ISS analysis requiring 3-week lead time
- Affected milestones and deliverables
- Resource reallocation recommendations

### Scenario 2: Priority-Based Execution

During resource constraints, execute only critical-path studies:

```
# Run only Priority 1 studies
PRIORITY_THRESHOLD=1 ./run_portfolio.sh

# Run Priority 1-2 studies
PRIORITY_THRESHOLD=2 ./run_portfolio.sh
```

### Scenario 3: SDTM Version Harmonization

Handle legacy studies with different CDISC versions:

```
# STUDY003 uses SDTM 1.5, needs harmonization for pooled ISS
Rscript etl/sdtm/harmonize_versions.R --from 1.5 --to 1.7 --study STUDY003

# Validate harmonization
Rscript validation/check_sdtm_compliance.R STUDY003
```

## RECIST 1.1 Derivation Library

### Available Functions

Located in `etl/adam_program_library/oncology_response/`:

- `derive_bor()`: Best Overall Response with confirmation logic
- `calculate_orr()`: Objective Response Rate with exact binomial CI
- `derive_dor()`: Duration of Response with censoring rules
- `derive_ttp()`: Time to Progression
- `derive_pfs()`: Progression-Free Survival

### Usage Example

```
library(admiral)
source("etl/adam_program_library/oncology_response/recist_11_macros.R")

# Derive Best Overall Response
adrs <- derive_bor(
  dataset = rs_data,
  subject_keys = c("STUDYID", "USUBJID"),
  confirmation_period = 28,  # days
  baseline_required = TRUE
)

# Calculate Objective Response Rate
orr_results <- calculate_orr(
  dataset = adrs,
  response_var = "AVALC",
  ci_method = "exact",
  alpha = 0.05
)
```

### Unit Testing

```
# Run unit tests for derivation library
Rscript tests/testthat.R

# Run specific oncology module tests
Rscript -e "testthat::test_file('tests/testthat/test-recist-derivations.R')"
```

## Quality Control

### Double Programming Framework

The QC process compares production outputs against independent QC programs:

```
# Run QC for specific ADaM dataset
Rscript qc/r/adam/qc_adam_adsl.R

# Run QC for all datasets
./run_pipeline.sh --with-qc

# View reconciliation report
open outputs/qc/reconciliation_report.html
```

### Validation Reports

- Unit test coverage: `validation/coverage_report.html`
- CDISC conformance: `validation/pinnacle21/`
- Cross-study consistency: `validation/pooled_analysis_checks.html`

## Troubleshooting

### Common Issues

**Error: "Study configuration not found"**
```
# Verify study exists in registry
cat studies/portfolio_registry.yml | grep STUDY001

# Validate configuration syntax
Rscript automation/validate_study_config.R STUDY001
```

**Error: "Dependency cycle detected"**
```
# Visualize dependency graph
Rscript automation/dependencies.R --visualize

# Check for circular dependencies in pooled analyses
```

**Execution hangs on high-priority studies**
```
# Check log files
tail -f logs/portfolio_runner.log

# Verify resource allocation
ps aux | grep Rscript
```

### Performance Optimization

For large datasets (n > 500):
```
# Enable parallel processing in run_all.R
options(mc.cores = parallel::detectCores() - 1)

# Use data.table for large merges
library(data.table)
setDTthreads(threads = 4)
```

## Development

### Running Tests

```
# All tests
Rscript -e "testthat::test_dir('tests/testthat')"

# Specific test file
Rscript -e "testthat::test_file('tests/testthat/test-portfolio-runner.R')"

# With coverage
Rscript -e "covr::package_coverage()"
```

### Adding New Derivations

1. Create function in appropriate library module
2. Add unit tests in `tests/testthat/test-{module}.R`
3. Document function with roxygen2 comments
4. Update module README with usage example
5. Run validation suite

### Code Style

- Follow [tidyverse style guide](https://style.tidyverse.org/)
- Use `lintr` for static analysis: `Rscript -e "lintr::lint_package()"`
- Format with `styler`: `Rscript -e "styler::style_pkg()"`

## Dependencies

### Core Packages

- `admiral` >= 0.12.0: ADaM derivations
- `metacore` >= 0.1.0: Metadata management
- `metatools` >= 0.1.0: Metadata-driven programming
- `pharmaversesdtm` >= 0.2.0: SDTM operations
- `shiny` >= 1.7.0: Dashboard
- `yaml` >= 2.3.0: Configuration management

### Development Packages

- `testthat` >= 3.0.0: Unit testing
- `covr` >= 3.5.0: Code coverage
- `lintr` >= 3.0.0: Static analysis
- `styler` >= 1.9.0: Code formatting

See `renv.lock` for complete dependency list.

## CDISC Compliance

This pipeline conforms to:
- **SDTM IG** v3.4 (with v1.5 harmonization support)
- **ADaM IG** v1.3
- **RECIST 1.1** criteria for oncology response

Validation reports available in `validation/cdisc_compliance/`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Code style and conventions
- Testing requirements
- Pull request process
- Documentation standards

## License

[Include your license information]

## Support

For questions or issues:
1. Check [documentation](docs/)
2. Review [troubleshooting section](#troubleshooting)
3. Search [existing issues](https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/issues)
4. Open new issue with reproducible example

## Changelog

See [CHANGELOG.md](docs/CHANGELOG.md) for version history and migration guides.
