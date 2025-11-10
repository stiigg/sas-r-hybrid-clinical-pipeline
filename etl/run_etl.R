#!/usr/bin/env Rscript

# Metadata-driven ETL orchestrator. Reads specs/etl_manifest.csv and
# executes each step in order. SAS steps are delegated to the SAS executable
# when available; R steps can be sourced directly. Use the dry_run flag to
# preview commands without executing them.

read_etl_manifest <- function(path = "specs/etl_manifest.csv") {
  if (!file.exists(path)) {
    stop(sprintf("ETL manifest not found at %s", path), call. = FALSE)
  }
  manifest <- utils::read.csv(path, stringsAsFactors = FALSE)
  expected <- c("step_id", "language", "script", "description")
  missing <- setdiff(expected, names(manifest))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "ETL manifest is missing required columns: %s",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  manifest
}

run_etl_step <- function(step, dry_run = TRUE, env = parent.frame()) {
  language <- tolower(step$language)
  script <- step$script
  description <- step$description
  command <- NULL
  status <- "skipped"
  message <- ""

  if (!file.exists(script)) {
    return(
      list(
        step_id = step$step_id,
        status = "missing",
        message = sprintf("Script not found at %s", script),
        command = NA_character_
      )
    )
  }

  if (language %in% c("sas", "sasmacro")) {
    sas_bin <- Sys.which("sas")
    command <- sprintf("%s -sysin %s", sas_bin, shQuote(script))
    if (dry_run || !nzchar(sas_bin)) {
      status <- if (dry_run) "dry_run" else "sas_missing"
      if (!nzchar(sas_bin) && !dry_run) {
        message <- "SAS executable not found on PATH"
      } else {
        message <- "Dry run - no execution"
      }
    } else {
      exit_code <- system2(sas_bin, c("-sysin", script))
      status <- if (identical(exit_code, 0L)) "success" else "error"
      message <- if (identical(exit_code, 0L)) "" else sprintf("Exited with code %s", exit_code)
    }
  } else if (language %in% c("r", "rs")) {
    command <- sprintf("Rscript %s", shQuote(script))
    if (dry_run) {
      status <- "dry_run"
      message <- "Dry run - no execution"
    } else {
      exit_code <- system2("Rscript", c(script))
      status <- if (identical(exit_code, 0L)) "success" else "error"
      message <- if (identical(exit_code, 0L)) "" else sprintf("Exited with code %s", exit_code)
    }
  } else {
    status <- "unsupported"
    message <- sprintf("Unsupported language '%s' for ETL step %s", language, step$step_id)
  }

  list(
    step_id = step$step_id,
    description = description,
    status = status,
    message = message,
    command = command
  )
}

run_full_etl <- function(manifest_path = "specs/etl_manifest.csv", dry_run = TRUE) {
  manifest <- read_etl_manifest(manifest_path)
  results <- lapply(seq_len(nrow(manifest)), function(i) {
    run_etl_step(manifest[i, ], dry_run = dry_run)
  })
  do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
}

if (identical(environment(), globalenv()) && !interactive()) {
  dry_run_env <- tolower(Sys.getenv("ETL_DRY_RUN", "true"))
  dry_run <- dry_run_env %in% c("true", "1", "yes", "y")
  manifest_path <- commandArgs(trailingOnly = TRUE)
  manifest_path <- if (length(manifest_path) > 0) manifest_path[[1]] else "specs/etl_manifest.csv"
  summary <- run_full_etl(manifest_path = manifest_path, dry_run = dry_run)
  print(summary)
}
