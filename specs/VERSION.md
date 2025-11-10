# Specs and Orchestration Versioning

This file tracks the canonical version for manifests (`specs/*.csv`,
`specs/tlf/*.csv`, YAML configs) and orchestration entry points
(`qc/run_qc.R`, `automation/r/tlf/batch/*.R`, `tests/run_tests.R`).

## Current version

- `qc` orchestrator: v1.1.0
- `automation` orchestrator: v1.1.0
- `manifests`: v1.1.0

## Change log

### v1.1.0
- Centralised TLF QC batch runner under `qc/r/tlf/run_tlf_qc_batch.R`.
- Introduced HTML/text QC reporting and repository-level tests.
- Standardised automation batch execution via `execute_tlf_manifest()`.
- Added contributor onboarding documentation and CI test harness.

### v1.0.0
- Initial manifest-driven QC and automation structure.
