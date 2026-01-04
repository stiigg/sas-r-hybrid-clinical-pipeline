# ADTR Program Documentation

## Overview

This directory contains the consolidated ADTR (Tumor Results Analysis Dataset) program implementing RECIST 1.1 tumor measurement analysis with a modern, modular, package-based architecture.

### Key Features

- **Modular Design**: Hierarchical macro library following PharmaSUG 2025-SD-116 SAS Packages framework
- **Configuration-Driven**: Single-file configuration for execution mode and options
- **Self-Documenting**: All macros include embedded documentation per PharmaSUG 2024-SD-211
- **Validated**: Built-in quality control with unit testing framework
- **Efficient**: 66% reduction in manual effort through reusable components (PharmaSUG 2025-AI-239)
- **Standards-Compliant**: CDISC ADaM v1.3 and RECIST 1.1 conformant

## Quick Start

See [QUICKSTART.md](QUICKSTART.md) for detailed getting started instructions.

### Basic Execution

```sas
/* 1. Set project root */
%let PROJ_ROOT = /path/to/sas-r-hybrid-clinical-pipeline;

/* 2. Configure execution mode */
/* Edit config/global_parameters.sas */
%let ADTR_MODE = 2;  /* 1=Basic SDIAM, 2=Enhanced BDS */

/* 3. Run consolidated program */
%include "&PROJ_ROOT/adam/programs/sas/80_adam_adtr_consolidated.sas";
```

### Using Individual Macros

```sas
/* Load package system */
%include "packages/package_loader.sas";
%load_package(ADTR_CORE);

/* Use specific macros */
%derive_baseline(
    inds=work.measurements,
    outds=work.with_baseline,
    method=PRETREAT,
    paramcd=SDIAM
);
```

## Development Roadmap

### Phase 1: Framework (Completed ✓)

- ✓ Configuration management system
- ✓ Package loading framework  
- ✓ Level 1 utilities (import_tr, import_tu, import_adsl, validate_input, format_dates)
- ✓ Example modular macro (derive_baseline)
- ✓ Unit test framework
- ✓ Consolidated main program structure
- ✓ Documentation
- ✓ Integration of import macros into production programs (v3.1)

**Update 2026-01-04:** All Level 1 utilities now integrated via ADTR_CORE package.
Programs 80_adam_adtr.sas (v1.1), 80_adam_adtr_v2.sas (v2.1), and 80_adam_adtr_consolidated.sas 
now use validated import macros instead of inline PROC IMPORT statements.

### Phase 2: Core Macros (Next)

- □ Complete Level 2 derivations (nadir, pchg, ENAWORU)
- □ Level 3 parameter derivations (LDIAM, SDIAM, SNTLDIAM)
- □ BDS structure components (PARCAT, CRIT, ANL)

### Phase 3: Validation (Future)

- □ Comprehensive unit test suite
- □ Regression tests vs v1.0/v2.0
- □ Output comparison utilities
- □ Automated validation reports

### Phase 4: Extension (Future)

- □ Apply architecture to ADLB
- □ Apply architecture to ADRS
- □ Apply architecture to ADTTE
- □ Cross-study reusability framework

## References

### PharmaSUG Conference Papers

1. **PharmaSUG 2025-SD-116**: SAS Packages framework for modular programming and reusability
2. **PharmaSUG 2025-SA-287**: Efficacy roadmap for early phase oncology trials
3. **PharmaSUG 2025-AI-239**: GenAI-assisted code conversion achieving 66% efficiency gains
4. **PharmaSUG 2024-SD-211**: Utility macros and self-documenting code best practices

### Clinical Research Publications

1. **Vitale et al. JNCI 2025**: Censoring transparency in oncology trials - informed nadir calculation methods
2. **Enaworu et al. Cureus 2025**: 25mm nadir rule for progression assessment in solid tumors

### CDISC Standards

1. **CDISC ADaM Implementation Guide v1.3**: Analysis Data Model standards
2. **RECIST v1.1**: Response Evaluation Criteria in Solid Tumors

---

**Last Updated**: 2026-01-04  
**Version**: 3.1  
**Author**: Christian Baghai  
**License**: [Project License]
