# sas-r-hybrid-clinical-pipeline

Minimal example of a SAS–R hybrid pipeline for clinical trial programming. The
repository has been reorganised around modern metadata-driven practices so that
SDTM/ADaM transformations, QC, and output generation can be orchestrated from a
single manifest-driven entry point.

## Quick start

```bash
git clone https://github.com/stiigg/sas-r-hybrid-clinical-pipeline.git
cd sas-r-hybrid-clinical-pipeline
Rscript run_all.R    # defaults to metadata-driven dry-run mode
```

Override the default dry-run behaviour by exporting `ETL_DRY_RUN=false`,
`QC_DRY_RUN=false`, or `TLF_DRY_RUN=false` before invoking the orchestrator.
Generated artefacts are written to `outputs/` while consolidated logs live in
`logs/`.

## Repository layout

| Path | Purpose |
| --- | --- |
| `specs/` | Centralised metadata manifests (ETL, QC, shell maps, path catalogue) |
| `data/` | Example raw (`data/raw/`), SDTM (`data/sdtm/`), and ADaM (`data/adam/`) data roots |
| `etl/` | Transformation scripts organised by process, e.g. `etl/sas/*.sas` |
| `qc/` | Quality-control scripts and orchestrators (`qc/run_qc.R`) |
| `outputs/` | Generated artefacts and supporting code (`outputs/tlf/`, `outputs/qc/`) |
| `automation/` | Batch runners and orchestration helpers (e.g. TLF QC/generation) |
| `validation/` | CDISC/SDTM/ADaM compliance harnesses |
| `archive/` | Legacy folder layout retained for traceability |
| `logs/` | Execution logs written by the orchestrator |

## Adding new TLFs

1. Create paired scripts under `outputs/tlf/r/gen/` and `qc/r/tlf/` using the
   naming convention `gen_tlf_<id>_<desc>.R` and `qc_tlf_<id>_<desc>.R`.
2. Register the TLF in `specs/tlf/tlf_config.yml` and
   `specs/tlf/tlf_shell_map.csv`.
3. Ensure scripts log key milestones via `tlf_log()` and write outputs using
   `get_tlf_output_path()`.
4. Run `Rscript run_all.R` (optionally disabling dry-run) to validate end-to-end
   orchestration.

For contribution guidelines and coding conventions see
[`CONTRIBUTING.md`](CONTRIBUTING.md).
