# Contributing Guidelines

Thank you for your interest in improving the SAS–R hybrid clinical pipeline. The
project follows a metadata-driven layout so that new Tables, Listings, and
Figures (TLFs) can be audited and reproduced consistently. Please follow the
conventions below when contributing.

## Workflow

1. Fork the repository and create a feature branch.
2. Install dependencies (at minimum R \>= 4.2 and the `yaml` package).
3. Run the orchestration script from the project root:

   ```bash
   Rscript run_all.R
   ```

   Generated TLFs are written to `r/tlf/output/` and logs to `logs/`.
4. Submit a pull request with a clear description of the changes and any
   validation performed.

## Naming conventions

- Generation scripts: `r/tlf/gen/gen_tlf_<id>_<description>.R`
- QC scripts: `r/tlf/qc/qc_tlf_<id>_<description>.R`
- Batch runners must log their progress using `tlf_log()`.
- Update both `r/tlf/config/tlf_config.yml` and `r/tlf/config/tlf_shell_map.csv`
  when adding or renaming TLFs.

## Code style

- Prefer functional, script-level code without side effects outside the
  orchestrator.
- Use helper functions in `r/tlf/utils/` for shared logic (paths, logging,
  formatting, etc.).
- Avoid hard-coded absolute paths; rely on `get_tlf_output_path()` and related
  helpers to resolve locations.

## Outputs and logs

- Never commit generated outputs or log files. They are ignored via `.gitignore`.
- Ensure each generation and QC script writes meaningful log statements using
  `tlf_log()` to aid audit trails.
- Place any QC artefacts (comparisons, diff reports) in
  `getOption("tlf.qc_report_dir")` (defaults to `r/tlf/output/qc`).

## Documentation

- Update `README.md` (root or `r/tlf/README.md`) when changing execution steps or
  folder layout.
- Include context and references to specifications in commit messages and pull
  requests whenever possible.

By following these guidelines you help keep the project reproducible and easy to
review.
