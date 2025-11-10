# Quality Control (QC)

Hosts metadata-driven QC automation and supporting scripts. The primary entry
point is `qc/run_qc.R`, which consumes `specs/qc_manifest.csv` to orchestrate QC
for datasets, TLFs, and compliance tooling.

## Structure

| Path | Purpose |
| --- | --- |
| `qc/run_qc.R` | Manifest-driven QC orchestrator (dry-run capable). |
| `qc/r/adam/` | R QC scripts for ADaM assets. |
| `qc/r/tlf/` | R QC scripts for TLF outputs. |

## Usage

```bash
Rscript qc/run_qc.R               # dry run (default)
QC_DRY_RUN=false Rscript qc/run_qc.R   # execute QC tasks
```

Additions should be registered in `specs/qc_manifest.csv` with an appropriate
`runner` (`rscript`, `sas`, or `tlf_batch`).
