# Quality Control (QC)

The `qc/` directory owns all validation logic for the repository. QC execution
is manifest-driven so every task is discoverable, versioned, and reproducible.
Automation helpers in `automation/` invoke these entry points but do not
re-implement QC logic.

## Workflow overview

```
┌────────────────────┐      ┌──────────────────────┐
│ specs/qc_manifest  │ ───▶ │ qc/run_qc.R          │
│  • task metadata   │      │  • manifest loader   │
│  • runner/command  │      │  • task dispatcher   │
└────────────────────┘      │  • report generator  │
                            └────────┬─────────────┘
                                     │
                                     ▼
                           qc/r/**            (R + SAS task library)
```

All QC tasks must be registered in `specs/qc_manifest.csv`. Batch TLF QC is
implemented in `qc/r/tlf/run_tlf_qc_batch.R` and re-used by the top-level
runner.

## Usage

Dry runs allow planning the execution order without invoking external tooling:

```bash
Rscript qc/run_qc.R               # dry run (default)
QC_DRY_RUN=false Rscript qc/run_qc.R   # execute QC tasks
Rscript qc/run_qc.R specs/custom_manifest.csv  # alternate manifest
```

When execution is enabled the script emits machine-readable artifacts under
`qc/reports/`:

* `qc_summary_<timestamp>.html` – formatted dashboard of task status, issues,
  and validation flag.
* `qc_summary_<timestamp>.txt` – text log for quick inspection or CLI use.
* `qc_summary_latest.*` – rolling pointers to the most recent report.

Issue messages link back to individual task logs (for example, the TLF batch
runner writes one log per TLF into `logs/`).

## Manifest-driven orchestration

The manifest defines the runner, language, script path, and description for each
QC task. Supported runners:

| Runner      | Description |
| ----------- | ----------- |
| `tlf_batch` | Executes all TLF QC scripts via `run_qc_for_all_tlfs()`. |
| `rscript`   | Invokes an R script through `Rscript`. |
| `sas`       | Launches SAS in batch mode (if available on `PATH`). |

Add new QC tasks by appending a row to `specs/qc_manifest.csv`. Keep scripts
under `qc/r/...` for R or in `qc/sas/...` for SAS and reference the relative
path in the manifest.

## Input/output conventions

* **Inputs:** QC scripts expect analysis-ready datasets in `data/` and metadata
  from `specs/`. TLF QC receives configuration via `specs/tlf/tlf_config.yml` and
  `specs/tlf/tlf_shell_map.csv`.
* **Outputs:** Validation summaries go to `qc/reports/`. Script-level logging
  writes to `logs/` and should use `tlf_log()` for consistent formatting.
* **Exchange format:** Use CSV for tabular exchanges between SAS and R, and YAML
  for configuration. When sharing derived values, prefer tidy column names and
  include units where relevant.

## Tests

Run QC-focused assertions with:

```bash
Rscript qc/tests/run_tests.R
```

The test suite validates manifest integrity, ensures dry-run execution of all
tasks, and verifies the presence of generated reports.

## Versioning and change control

* Update `specs/VERSION.md` when manifests or orchestration logic change.
* Tag Git commits that modify QC manifests using `git tag qc-v<major>.<minor>`
  so historical runs can be reproduced.
* Document breaking changes in commit messages and README updates.

## Contributing

1. Fork or branch from `main`.
2. Add new QC scripts under `qc/r/` or `qc/sas/`.
3. Register the task in `specs/qc_manifest.csv`.
4. Update or create tests in `qc/tests/`.
5. Run `Rscript qc/run_qc.R` (with and without `QC_DRY_RUN=false`) and
   `Rscript qc/tests/run_tests.R`.
6. Submit a PR including updated reports or sample output where appropriate.
