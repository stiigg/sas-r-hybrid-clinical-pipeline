#!/usr/bin/env Rscript

source("outputs/tlf/r/utils/load_config.R")
source("outputs/tlf/r/utils/batch_runner.R")
source("automation/r/tlf/batch/batch_run_all_tlfs.R")

message("[AUTOMATION TEST] Preparing configuration...")
config <- try(load_tlf_config(), silent = TRUE)
if (inherits(config, "try-error")) {
  message("[AUTOMATION TEST] 'yaml' not available – using minimal inline config.")
  config <- list(
    paths = list(
      output_dir = "outputs/tlf/r/output",
      log_dir = "logs",
      qc_reports = "outputs/qc"
    ),
    options = list(
      default_population = "TEST",
      default_qc_tolerance = 1e-6,
      archive_outputs = FALSE
    )
  )
  options(
    tlf.config = config,
    tlf.paths = config$paths,
    tlf.output_dir = config$paths$output_dir,
    tlf.log_dir = config$paths$log_dir,
    tlf.qc_report_dir = config$paths$qc_reports,
    tlf.default_population = config$options$default_population,
    tlf.default_qc_tolerance = config$options$default_qc_tolerance,
    tlf.archive_outputs = isTRUE(config$options$archive_outputs)
  )
  dir.create(getOption("tlf.output_dir"), recursive = TRUE, showWarnings = FALSE)
  dir.create(getOption("tlf.log_dir"), recursive = TRUE, showWarnings = FALSE)
  dir.create(getOption("tlf.qc_report_dir"), recursive = TRUE, showWarnings = FALSE)
}

message("[AUTOMATION TEST] Loading TLF manifest...")
manifest <- load_tlf_shell_map()
if (!is.data.frame(manifest) || nrow(manifest) == 0) {
  stop("TLF shell map is empty", call. = FALSE)
}
required_manifest_cols <- c("tlf_id", "gen_script", "qc_script", "out_file")
if (!all(required_manifest_cols %in% names(manifest))) {
  stop("TLF shell map missing required columns", call. = FALSE)
}

message("[AUTOMATION TEST] Executing generation batch (dry assertions)...")
results <- run_all_tlfs(config)
if (!is.data.frame(results)) {
  stop("Generation batch did not return a data.frame", call. = FALSE)
}
expected_cols <- c("tlf_id", "status", "message", "script", "log")
if (!all(expected_cols %in% names(results))) {
  stop("Generation batch results missing expected columns", call. = FALSE)
}

message("Automation tests completed successfully.")
