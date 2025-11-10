# Extract-Transform-Load (ETL)

Process-oriented home for SAS/R scripts that transform raw data into SDTM and
ADaM structures. The execution order is controlled by `specs/etl_manifest.csv`
and orchestrated via `etl/run_etl.R`.

## Structure

| Path | Purpose |
| --- | --- |
| `etl/sas/` | Metadata-driven SAS programs (setup, SDTM, ADaM). |
| `etl/run_etl.R` | R wrapper that reads the ETL manifest and executes each step. |

## Usage

```bash
Rscript etl/run_etl.R              # dry run (default)
ETL_DRY_RUN=false Rscript etl/run_etl.R  # execute when SAS is available
```

Ensure new steps are added to `specs/etl_manifest.csv` with an informative
`description` and the correct runner `language`.
