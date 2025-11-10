# TLF Outputs and Utilities

This directory hosts the code that generates R-based Tables, Listings, and
Figures (TLFs) as well as the canonical location for output artefacts. All
scripts resolve configuration and metadata from `specs/tlf/` via the helper
functions in `utils/`.

## Subfolders

| Folder | Description |
| --- | --- |
| `gen/` | Individual TLF generation scripts (`gen_tlf_*`). |
| `utils/` | Shared helpers (logging, path handling, manifest utilities). |
| `apps/` | Reviewer or explorer applications (e.g., Shiny). |
| `output/` | Canonical destination for generated artefacts (ignored by git). |

Quality-control scripts now live under `qc/r/tlf/` while batch runners sit in
`automation/r/tlf/`.

## Configuration

- `specs/tlf/tlf_config.yml` defines paths and default options (population, QC
  tolerance, logging destinations).
- `specs/tlf/tlf_shell_map.csv` enumerates TLF metadata (ID, script names,
  output filenames).
- `utils/load_config.R` provides helpers that read configuration files and set
  global options. Call `load_tlf_config()` before running batch scripts or
  generators.

## Logging and outputs

Use `tlf_log()` from `utils/tlf_logging.R` to emit timestamped messages. Output
files should always be resolved via `get_tlf_output_path()` so that directories
remain configurable. Never write artefacts directly into code folders.

## Adding new content

1. Copy an existing generation script as a template and register it in
   `specs/tlf/tlf_shell_map.csv`.
2. Implement or update the paired QC script under `qc/r/tlf/`.
3. Ensure scripts are idempotent, configurable, and emit useful log lines.
4. Run `Rscript run_all.R` (optionally disabling dry-run) to validate the
   end-to-end process.
