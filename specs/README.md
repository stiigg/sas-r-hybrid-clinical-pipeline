# Specifications

Central repository for metadata manifests that drive ETL, QC, and TLF
execution.

## Key files

| File | Purpose |
| --- | --- |
| `etl_manifest.csv` | Defines ordered ETL steps and their execution language. |
| `qc_manifest.csv` | Lists QC tasks and their runners (R script, SAS, or TLF batch). |
| `pipeline_paths.csv` | Central catalogue of repository-relative directories for SAS macros. |
| `tlf/tlf_config.yml` | YAML configuration for TLF defaults and output directories. |
| `tlf/tlf_shell_map.csv` | Manifest describing available TLFs and script names. |

Tooling scripts that derive or audit manifests live under `specs/tools/`.
