# Outputs

Consolidated home for generated artefacts and supporting code. Subdirectories
mirror production processes to keep deliverables discoverable.

| Path | Purpose |
| --- | --- |
| `outputs/tlf/` | R-based TLF generators, utilities, and output staging area. |
| `outputs/tlf/sas/` | SAS-based TLF programs aligned with metadata macros. |
| `outputs/qc/` | Drop location for QC summaries and validation reports. |

The orchestrator (`run_all.R`) and QC runner (`qc/run_qc.R`) both write logs and
reports here based on the manifests in `specs/`.
