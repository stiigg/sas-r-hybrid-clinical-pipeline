# Automation

The `automation/` directory provides orchestration entry points and shared
helpers for batch generation tasks. QC logic now lives exclusively under
`qc/`, while automation focuses on sequencing jobs and coordinating manifests.

## Workflow overview

```
┌──────────────────────┐      ┌────────────────────────┐
│ specs/tlf_shell_map  │ ───▶ │ automation/r/tlf/batch │
│ specs/etl_manifest   │      │  • manifest reader     │
│ specs/automation_*   │      │  • batch dispatcher    │
└──────────────────────┘      │  • logging integration │
                               └────────┬──────────────┘
                                        │
                                        ▼
                             outputs/tlf/r/gen/** (generation scripts)
```

All batch runners call `execute_tlf_manifest()` to standardise logging, error
handling, and output structures.

## Runners

| Path | Purpose |
| --- | --- |
| `automation/r/tlf/batch/batch_run_all_tlfs.R` | Execute all generation scripts listed in the TLF shell map using manifest-driven orchestration. |

QC batch execution is now defined in `qc/r/tlf/run_tlf_qc_batch.R` and consumed
via the QC manifest.

## Usage

Run the generation batch from the repository root:

```bash
Rscript -e "source('automation/r/tlf/batch/batch_run_all_tlfs.R'); run_all_tlfs()"
```

The function returns a `data.frame` containing TLF IDs, statuses, messages,
and log locations. Generation runs also respect the configuration in
`specs/tlf/tlf_config.yml`.

## Input/output contracts

* **Inputs:** Shell metadata is stored in `specs/tlf/tlf_shell_map.csv`, and
  configuration (output directories, log locations, tolerances) lives in
  `specs/tlf/tlf_config.yml`.
* **Outputs:** Batch runners log to `logs/` and write TLF artifacts under
  `outputs/tlf/r/output/` by default. Intermediate RDS or CSV artefacts should
  be stored alongside the generated tables.
* **R ↔ SAS boundaries:** SAS jobs should export tabular data as CSV (UTF-8,
  header row included). R scripts should read those CSV files explicitly and
  emit QC deltas or new datasets following the same convention.

## Tests

Automation-specific smoke tests live in `automation/tests/` and can be executed
with:

```bash
Rscript automation/tests/run_tests.R
```

The checks validate manifest columns, dry-run capabilities, and logging paths
without requiring SAS tooling.

## Versioning and governance

* Update `specs/VERSION.md` when changing manifest schemas or orchestration
  behaviour.
* Use semantic commit messages to document automation-level changes.
* Tag release-ready orchestration changes with `automation-v<major>.<minor>`
  to keep audit trails aligned with QC releases.

## Directory boundaries

* `automation/` – orchestration, scheduling, manifest plumbing, and cross-cutting
  helpers.
* `qc/` – validation logic, QC manifests, and report generation.

Keeping these boundaries explicit ensures contributors know where to add new
capabilities and prevents duplicated QC logic.
