# sas-r-hybrid-clinical-pipeline

Minimal example of a SAS–R hybrid pipeline for clinical trial programming, with
SDTM/ADaM-style datasets, metadata-driven mappings, R-based QC, and a Shiny
explorer.

## Quick start

```bash
git clone https://github.com/stiigg/sas-r-hybrid-clinical-pipeline.git
cd sas-r-hybrid-clinical-pipeline
Rscript run_all.R
```

The orchestrator writes TLF outputs to `r/tlf/output/` and execution logs to
`logs/`. QC artefacts (diff reports, textual summaries) are placed in
`r/tlf/output/qc/`.

## Repository layout

| Path | Purpose |
| --- | --- |
| `r/tlf/` | R TLF subsystem containing generation, QC, batch, and utility scripts |
| `r/tlf/output/` | Canonical location for R-generated tables, listings, and figures |
| `logs/` | Aggregated execution logs for orchestrated runs |
| `adam/`, `data/` | Example SDTM/ADaM data inputs (ignored by default) |
| `sas/` | SAS-side examples for hybrid workflows |
| `specs/` | Shell specifications and metadata manifests |
| `tlf/` | Legacy SAS programs |

## Adding new TLFs

1. Create paired scripts under `r/tlf/gen/` and `r/tlf/qc/` using the naming
   convention `gen_tlf_<id>_<desc>.R` and `qc_tlf_<id>_<desc>.R`.
2. Register the TLF in both `r/tlf/config/tlf_config.yml` and
   `r/tlf/config/tlf_shell_map.csv`.
3. Ensure scripts log key milestones via `tlf_log()` and write outputs using
   `get_tlf_output_path()`.
4. Run `Rscript run_all.R` to validate end-to-end orchestration.

For contribution guidelines and coding conventions see
[`CONTRIBUTING.md`](CONTRIBUTING.md).
