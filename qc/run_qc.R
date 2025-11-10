#!/usr/bin/env Rscript

# Central quality-control orchestrator driven by specs/qc_manifest.csv. Each
# row defines a QC task, the runner to use, and the target script. Tasks can be
# SAS command lines, standalone R scripts, or metadata-driven batch processes
# (e.g., TLF QC using the shell map).

source("outputs/tlf/r/utils/load_config.R")
source("automation/r/tlf/batch/batch_run_qc_all_tlfs.R")

read_qc_manifest <- function(path = "specs/qc_manifest.csv") {
  if (!file.exists(path)) {
    stop(sprintf("QC manifest not found at %s", path), call. = FALSE)
  }
  manifest <- utils::read.csv(path, stringsAsFactors = FALSE)
  expected <- c("task_id", "runner", "language", "script", "description")
  missing <- setdiff(expected, names(manifest))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "QC manifest missing required columns: %s",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  manifest
}

run_qc_task <- function(task, dry_run = TRUE, config = NULL) {
  runner <- tolower(task$runner)
  language <- tolower(task$language)
  script <- task$script
  message <- ""
  status <- "skipped"
  command <- NULL

  if (runner == "tlf_batch") {
    command <- "run_qc_for_all_tlfs()"
    if (dry_run) {
      status <- "dry_run"
      message <- "Dry run - batch QC not executed"
    } else {
      config <- config %||% load_tlf_config()
      results <- run_qc_for_all_tlfs(config)
      status <- if (all(results$status == "success")) "success" else "warning"
      message <- sprintf("Processed %d TLF QC scripts", nrow(results))
    }
  } else if (runner %in% c("rscript", "rs")) {
    command <- sprintf("Rscript %s", shQuote(script))
    if (!file.exists(script)) {
      status <- "missing"
      message <- sprintf("QC script not found at %s", script)
    } else if (dry_run) {
      status <- "dry_run"
      message <- "Dry run - no execution"
    } else {
      exit_code <- system2("Rscript", c(script))
      status <- if (identical(exit_code, 0L)) "success" else "error"
      message <- if (identical(exit_code, 0L)) "" else sprintf("Exited with code %s", exit_code)
    }
  } else if (runner %in% c("sas", "sas_batch")) {
    sas_bin <- Sys.which("sas")
    command <- sprintf("%s -sysin %s", sas_bin, shQuote(script))
    if (!file.exists(script)) {
      status <- "missing"
      message <- sprintf("QC script not found at %s", script)
    } else if (!nzchar(sas_bin)) {
      status <- "sas_missing"
      message <- "SAS executable not found on PATH"
    } else if (dry_run) {
      status <- "dry_run"
      message <- "Dry run - no execution"
    } else {
      exit_code <- system2(sas_bin, c("-sysin", script))
      status <- if (identical(exit_code, 0L)) "success" else "error"
      message <- if (identical(exit_code, 0L)) "" else sprintf("Exited with code %s", exit_code)
    }
  } else {
    status <- "unsupported"
    message <- sprintf("Unsupported runner '%s' for task %s", runner, task$task_id)
  }

  list(
    task_id = task$task_id,
    description = task$description,
    status = status,
    message = message,
    command = command
  )
}

run_qc_plan <- function(manifest_path = "specs/qc_manifest.csv", dry_run = TRUE, config = NULL) {
  manifest <- read_qc_manifest(manifest_path)
  results <- lapply(seq_len(nrow(manifest)), function(i) {
    run_qc_task(manifest[i, ], dry_run = dry_run, config = config)
  })
  do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

if (identical(environment(), globalenv()) && !interactive()) {
  dry_run_env <- tolower(Sys.getenv("QC_DRY_RUN", "true"))
  dry_run <- dry_run_env %in% c("true", "1", "yes", "y")
  manifest_path <- commandArgs(trailingOnly = TRUE)
  manifest_path <- if (length(manifest_path) > 0) manifest_path[[1]] else "specs/qc_manifest.csv"
  config <- NULL
  if (!dry_run) {
    config <- load_tlf_config()
  }
  summary <- run_qc_plan(manifest_path = manifest_path, dry_run = dry_run, config = config)
  print(summary)
}
