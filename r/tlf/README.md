# TLF Subsystem (R-side)

This directory organizes scripts for Table/Listing/Figure (TLF) generation, quality control, batch execution, reviewer apps, configuration, and reusable utilities. The structure follows a validated blueprint to enable high-reproducibility, audit-ready clinical trial reporting.

## Subfolders
- gen/: TLF generation scripts (one per output, e.g., gen_tlf_*)
- qc/: QC scripts for double-programming (qc_tlf_*)
- batch/: Batch drivers for full orchestration, logging, reproducibility
- apps/: Shiny/reviewer apps for TLF/QC
- utils/: TLF- and formatting-specific helpers
- config/: YAML/CSV configuration (run manifests, paths)

Follow documentation for function signatures, batch execution, renv usage, and audit logging.