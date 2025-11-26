#!/usr/bin/env Rscript

# Wrapper to run sdtmchecks against locally generated SDTM domains.

if (!requireNamespace("sdtmchecks", quietly = TRUE)) {
  stop("Package 'sdtmchecks' is required to run SDTM QC checks.", call. = FALSE)
}
if (!requireNamespace("readr", quietly = TRUE)) {
  stop("Package 'readr' is required to write SDTM QC results.", call. = FALSE)
}

sdtm_dir <- file.path("data", "sdtm")
results <- sdtmchecks::run_sdtm_checks(path = sdtm_dir)

output_dir <- file.path("validation")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

out_path <- file.path(output_dir, "sdtm_checks_results.csv")
readr::write_csv(results, out_path)

message(sprintf("SDTM checks complete. Results written to %s", out_path))
