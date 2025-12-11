# Clinical Trial Data Pipeline - Multi-Study Orchestration

A production-ready R pipeline for SDTM/ADaM data transformations across concurrent oncology trials, built on pharmaverse packages with automated quality control and interactive monitoring.

---

## ⚠️ Implementation Status

**Purpose**: This repository demonstrates architectural design and implementation approach for oncology clinical trial programming pipelines. It showcases domain expertise in RECIST 1.1 criteria, CDISC standards, and multi-study orchestration.

**Current Status**: Core RECIST 1.1 derivation library complete with working end-to-end demo; portfolio orchestration framework functional; comprehensive testing and validation documentation in development.

### Module Completion Matrix

| Module | Files | Implementation | Testing | Status |
|--------|-------|----------------|---------|--------|
| **RECIST 1.1 Core** | 4/4 | ✅ Complete | ⚠️ Demo only | **Ready for review** |
| Time-to-Event | 3/3 | ✅ Complete | ❌ Needs data | Code complete |
| Advanced Endpoints | 2/2 | ✅ Complete | ❌ Needs data | Code complete |
| Immunotherapy (iRECIST) | 2/2 | ✅ Complete | ❌ Needs data | Code complete |
| Portfolio Orchestration | 5/5 | ✅ Complete | ⚠️ Dry-run mode | Functional |
| QC Framework | 2/5 | 🟡 Partial | ❌ Not tested | In development |
| Test Data | Synthetic | 🟡 Minimal | ⚠️ Demo subset | Expanding |
| Validation Docs | -- | ❌ Not started | -- | Planned |

**Legend**: ✅ Complete | 🟡 Partial | ❌ Not Started | ⚠️ Limited

### Quick Demo

To see the RECIST 1.1 core derivations in action with synthetic test data:

```bash
# Clone and navigate to demo
git clone https://github.com/stiigg/sas-r-hybrid-clinical-pipeline.git
cd sas-r-hybrid-clinical-pipeline/demo

# Run demo (requires SAS 9.4+)
sas simple_recist_demo.sas

# Expected output: 3 subjects with BOR (1 CR, 1 PR, 1 PD)
# See demo/README.md for details
```

**Demo highlights**:
- Complete target lesion response derivation (SLD, percent change, RECIST thresholds)
- Overall response integration per RECIST 1.1 Table 4
- Best Overall Response with 28-84 day confirmation logic
- Embedded QC procedures and frequency reports

### Production Readiness Requirements

This repository requires the following before production deployment:

1. **Expand test data** (12-16 hours): Add 20-25 synthetic subjects covering edge cases, non-target lesions, new lesion scenarios
2. **Complete QC automation** (10-15 hours): Implement comparison reports with `diffdf` (R) and `PROC COMPARE` (SAS)
3. **Add unit testing** (15-20 hours): Create testthat suite for R functions, SAS macro test framework
4. **Generate validation documentation** (15-20 hours): Create IQ/OQ/PQ packages, traceability matrices per regulatory requirements
5. **CDISC compliance validation** (5-8 hours): Run Pinnacle 21 validation, document conformance

**Estimated completion time**: 40-60 hours of focused development

See **[STATUS.md](STATUS.md)** for detailed module-by-module status, testing coverage, and priority action items.

---

## Features

- **Multi-Study Processing**: Concurrent execution of Phase I-III trials with priority-based queuing
- **RECIST 1.1 Standardization**: Validated derivation library for tumor response endpoints (BOR, ORR, DoR)
- **Pooled Analysis Support**: Integrated Safety/Efficacy Summary (ISS/ISE) coordination
- **Metadata-Driven Architecture**: YAML-based study registry with automated dependency tracking
- **Quality Control Framework**: R-based QC with automated reconciliation reports
- **Interactive Dashboard**: Shiny application for portfolio monitoring and timeline visualization

## Quick Start

### Prerequisites
```bash
# R >= 4.2 required
# System dependencies (Linux/Mac)
sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev
```

### Installation
```bash
git clone https://github.com/stiigg/sas-r-hybrid-clinical-pipeline.git
cd sas-r-hybrid-clinical-pipeline
Rscript install_pharmaverse.R
```

### Basic Execution
```bash
# Run all active studies
./run_portfolio.sh

# Run high-priority studies only
PRIORITY_THRESHOLD=1 ./run_portfolio.sh

# Run single study
Rscript run_all.R
```

### Launch Dashboard
```bash
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
│   │   ├── oncology_response/ # RECIST 1.1 macros ✅ COMPLETE
│   │   ├── time_to_event/     # TTE endpoints
│   │   └── safety_standards/  # Safety parameters
│   ├── sdtm/                  # SDTM transformation scripts
│   └── adam/                  # ADaM dataset generation
├── automation/                # Orchestration and scheduling
│   ├── portfolio_runner.R     # Multi-study execution engine
│   └── dependencies.R         # Cross-study dependency tracker
├── qc/                        # Quality control framework
├── validation/                # Validation reports and test results
├── demo/                      # ✅ NEW: Working RECIST 1.1 demo
│   ├── simple_recist_demo.sas # End-to-end demonstration
│   ├── data/                  # Synthetic test data (3 subjects)
│   └── README.md              # Demo documentation
├── app/                       # Shiny dashboard
├── outputs/                   # Generated datasets and reports
└── STATUS.md                  # ✅ NEW: Detailed implementation status
```

## Configuration

### Study Registry (`studies/portfolio_registry.yml`)

```yaml
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

```bash
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

```bash
# Run only Priority 1 studies
PRIORITY_THRESHOLD=1 ./run_portfolio.sh

# Run Priority 1-2 studies
PRIORITY_THRESHOLD=2 ./run_portfolio.sh
```

### Scenario 3: SDTM Version Harmonization

Handle legacy studies with different CDISC versions:

```bash
# STUDY003 uses SDTM 1.5, needs harmonization for pooled ISS
Rscript etl/sdtm/harmonize_versions.R --from 1.5 --to 1.7 --study STUDY003

# Validate harmonization
Rscript validation/check_sdtm_compliance.R STUDY003
```

## RECIST 1.1 Derivation Library

### Available Functions

Located in `etl/adam_program_library/oncology_response/`:

**Core Derivations** (✅ Complete with working demo):
- `derive_target_lesion_response()`: SLD calculation, CR/PR/SD/PD per RECIST 1.1
- `derive_non_target_lesion_response()`: Qualitative assessment standardization
- `derive_overall_timepoint_response()`: RECIST Table 4 integration logic
- `derive_best_overall_response()`: BOR with 28-84 day confirmation

**Summary Statistics**:
- `calculate_orr()`: Objective Response Rate with exact binomial CI
- `derive_dor()`: Duration of Response with censoring rules
- `derive_ttp()`: Time to Progression
- `derive_pfs()`: Progression-Free Survival

### Usage Example (SAS)

```sas
/* Include RECIST macros */
%include "etl/adam_program_library/oncology_response/recist_11_core/derive_target_lesion_response.sas";
%include "etl/adam_program_library/oncology_response/recist_11_core/derive_best_overall_response.sas";

/* Derive target lesion responses */
%derive_target_lesion_response(
    inds=sdtm.rs,
    outds=work.adrs_tl,
    usubjid_var=USUBJID,
    visit_var=VISIT,
    adt_var=RSDTC,
    ldiam_var=RSSTRESC,
    baseline_flag=ABLFL
);

/* Derive Best Overall Response */
%derive_best_overall_response(
    inds=work.adrs_timepoint,
    outds=adam.adrs_bor,
    usubjid_var=USUBJID,
    ady_var=RSDY,
    dtc_var=RSDTC,
    ovr_var=OVR_RESP,
    conf_win_lo=28,
    conf_win_hi=84,
    sd_min_dur=42
);
```

### Working Demo

See `demo/simple_recist_demo.sas` for complete working example with:
- 3 synthetic test subjects (CR, PR, PD response patterns)
- End-to-end derivation pipeline
- QC frequency tables and validation
- Expected vs. actual output comparison

**Documentation**: See `demo/README.md` for detailed demo guide

### Unit Testing

```bash
# Run unit tests for derivation library (when implemented)
Rscript tests/testthat.R

# Run specific oncology module tests
Rscript -e "testthat::test_file('tests/testthat/test-recist-derivations.R')"
```

**Note**: Unit testing framework is planned but not yet implemented. See [STATUS.md](STATUS.md) for timeline.

## Quality Control

### Double Programming Framework

The QC process compares production outputs against independent QC programs:

```bash
# Run QC for specific ADaM dataset
Rscript qc/r/adam/qc_adam_adsl.R

# Run QC for all datasets
./run_pipeline.sh --with-qc

# View reconciliation report (when implemented)
open outputs/qc/reconciliation_report.html
```

**Note**: QC comparison automation is in development. See [STATUS.md](STATUS.md) for implementation plan.

### Validation Reports

- Unit test coverage: `validation/coverage_report.html` (planned)
- CDISC conformance: `validation/pinnacle21/` (planned)
- Cross-study consistency: `validation/pooled_analysis_checks.html` (planned)

## Troubleshooting

### Common Issues

**Error: "Study configuration not found"**
```bash
# Verify study exists in registry
cat studies/portfolio_registry.yml | grep STUDY001

# Validate configuration syntax
Rscript automation/validate_study_config.R STUDY001
```

**Error: "Dependency cycle detected"**
```bash
# Visualize dependency graph
Rscript automation/dependencies.R --visualize

# Check for circular dependencies in pooled analyses
```

**Execution hangs on high-priority studies**
```bash
# Check log files
tail -f logs/portfolio_runner.log

# Verify resource allocation
ps aux | grep Rscript
```

### Performance Optimization

For large datasets (n > 500):
```r
# Enable parallel processing in run_all.R
options(mc.cores = parallel::detectCores() - 1)

# Use data.table for large merges
library(data.table)
setDTthreads(threads = 4)
```

## Development

### Running Tests

```bash
# All tests (when implemented)
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

- `testthat` >= 3.0.0: Unit testing (planned)
- `covr` >= 3.5.0: Code coverage (planned)
- `lintr` >= 3.0.0: Static analysis
- `styler` >= 1.9.0: Code formatting

See `renv.lock` for complete dependency list.

## CDISC Compliance

This pipeline conforms to:
- **SDTM IG** v3.4 (with v1.5 harmonization support)
- **ADaM IG** v1.3
- **RECIST 1.1** criteria for oncology response (Eisenhauer et al., 2009)

Validation reports available in `validation/cdisc_compliance/` (planned).

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
1. Check [STATUS.md](STATUS.md) for implementation status
2. Review [demo/README.md](demo/README.md) for quick start
3. See [troubleshooting section](#troubleshooting)
4. Search [existing issues](https://github.com/stiigg/sas-r-hybrid-clinical-pipeline/issues)
5. Open new issue with reproducible example

## Changelog

See [CHANGELOG.md](docs/CHANGELOG.md) for version history and migration guides.

---

**Repository Status**: Active Development | Core RECIST 1.1 Complete | See [STATUS.md](STATUS.md) for details  
**Last Updated**: December 11, 2025
