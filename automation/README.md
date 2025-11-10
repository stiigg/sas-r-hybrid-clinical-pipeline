# Automation

Holds orchestration helpers that sit above individual ETL/QC scripts. The R
batch runners execute TLF generation and QC iteratively using the manifests in
`specs/tlf/`.

| Path | Purpose |
| --- | --- |
| `automation/r/tlf/batch/batch_run_all_tlfs.R` | Execute all generation scripts listed in the TLF shell map. |
| `automation/r/tlf/batch/batch_run_qc_all_tlfs.R` | Execute all QC scripts listed in the TLF shell map. |

These modules are consumed by `run_all.R` and `qc/run_qc.R`.
