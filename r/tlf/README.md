# R TLF Subsystem

This directory hosts the R-based portion of the Table/Listing/Figure (TLF)
workflow. Scripts are organised so that generation, QC, batch execution, and
reviewer tooling are easy to navigate and validate.

## Subfolders

| Folder | Description |
| --- | --- |
| `gen/` | Individual TLF generation scripts (`gen_tlf_*`). |
| `qc/` | QC scripts for double-programming each TLF (`qc_tlf_*`). |
| `batch/` | Orchestration entry points that iterate over all configured TLFs. |
| `apps/` | Reviewer or explorer applications (e.g., Shiny). |
| `config/` | YAML/CSV configuration files describing manifests and paths. |
| `utils/` | Shared helpers (logging, path handling, formatting). |
| `output/` | Canonical destination for R-generated TLF artefacts (ignored by git). |

## Configuration

- `config/tlf_config.yml` defines paths and default options (population, QC
  tolerance, logging destinations).
- `config/tlf_shell_map.csv` enumerates TLF metadata (ID, script names, output
  filenames).
- `config/load_config.R` provides helpers that read configuration files and set
  global options. Call `load_tlf_config()` before running batch scripts.

## Orchestration

- `batch/batch_run_all_tlfs.R` executes every generation script listed in the
  manifest, logging progress to `logs/`.
- `batch/batch_run_qc_all_tlfs.R` runs the QC counterparts and writes QC reports
  to `r/tlf/output/qc/`.
- `run_all.R` (project root) is the recommended entry point; it restores config,
  runs QC, then generation.

## Logging and outputs

Use `tlf_log()` from `utils/tlf_logging.R` to emit timestamped messages. Output
files should always be resolved via `get_tlf_output_path()` so that directories
remain configurable. Never write artefacts directly into code folders.

## Adding new content

1. Copy an existing pair of generation/QC scripts as a template.
2. Update the manifest entries and YAML configuration with the new TLF.
3. Ensure scripts are idempotent, configurable, and emit useful log lines.
4. Run `Rscript run_all.R` from the project root to validate the end-to-end
   process.
