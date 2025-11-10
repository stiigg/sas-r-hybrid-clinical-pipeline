#!/usr/bin/env Rscript

# Lightweight validation harness that checks whether CDISC compliance tooling is
# available and, when possible, runs a simple metadata integrity check. The
# script intentionally avoids failing the pipeline when optional dependencies are
# absent; instead it records a structured report under outputs/qc.

required_packages <- c("admiral", "metatools")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

status <- if (length(missing_packages) == 0) "ready" else "missing_packages"
message <- if (identical(status, "ready")) {
  "All validation packages available"
} else {
  sprintf("Install missing packages to run validation: %s", paste(missing_packages, collapse = ", "))
}

shell_map_path <- "specs/tlf/tlf_shell_map.csv"
shell_map_present <- file.exists(shell_map_path)
if (shell_map_present) {
  shell_map <- utils::read.csv(shell_map_path, stringsAsFactors = FALSE)
  shell_validation <- list(
    total_shells = nrow(shell_map),
    unique_ids = length(unique(shell_map$tlf_id))
  )
} else {
  shell_validation <- list(error = sprintf("Shell map missing at %s", shell_map_path))
}

summary <- list(
  timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status = status,
  message = message,
  shell_map = shell_validation
)

if (identical(status, "ready")) {
  # Placeholder for integrating specific validation routines from available
  # packages. This keeps the harness extensible without requiring heavy
  # dependencies during initial onboarding.
  summary$validation_run <- "Tooling available - add domain-specific calls here"
} else {
  summary$validation_run <- "Validation skipped due to missing packages"
}

output_dir <- file.path("outputs", "qc")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}
output_path <- file.path(output_dir, "cdisc_validation.json")

if (requireNamespace("jsonlite", quietly = TRUE)) {
  jsonlite::write_json(summary, output_path, auto_unbox = TRUE, pretty = TRUE)
} else {
  saveRDS(summary, file = sub("\\\\.json$", ".rds", output_path))
}

if (identical(environment(), globalenv()) && !interactive()) {
  str(summary)
}
