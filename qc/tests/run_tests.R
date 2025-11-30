#!/usr/bin/env Rscript

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("The 'jsonlite' package is required to run QC tests. Please install it and retry.", call. = FALSE)
}

source(file.path("qc", "run_qc.R"))

message("[QC TEST] Loading manifest...")
manifest <- read_qc_manifest()
required_cols <- c("task_id", "runner", "language", "script", "description")
if (!all(required_cols %in% names(manifest))) {
  stop("QC manifest is missing required columns", call. = FALSE)
}

message("[QC TEST] Executing dry-run plan...")
summary <- run_qc_plan(dry_run = TRUE)
if (!is.data.frame(summary)) {
  stop("QC plan did not return a data.frame", call. = FALSE)
}
if (nrow(summary) == 0) {
  stop("QC plan returned zero tasks", call. = FALSE)
}

message("[QC TEST] Generating reports...")
reports <- write_qc_reports(summary)
if (!file.exists(reports$html) || !file.exists(reports$text)) {
  stop("QC reports were not generated", call. = FALSE)
}

message("QC tests completed successfully.")
