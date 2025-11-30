#!/usr/bin/env Rscript

# Metadata-driven ETL orchestrator. Reads specs/etl_manifest.csv and
# executes each step in order. SAS steps are delegated to the SAS executable
# when available; R steps can be sourced directly. Use the dry_run flag to
# preview commands without executing them.

`%||%` <- function(x, y) {
  if (is.null(x) || is.na(x) || !nzchar(x)) y else x
}

read_etl_manifest <- function(path = "specs/etl_manifest.csv") {
  if (!file.exists(path)) {
    stop(sprintf("ETL manifest not found at %s", path), call. = FALSE)
  }
  manifest <- utils::read.csv(path, stringsAsFactors = FALSE)
  expected <- c("step_id", "dataset", "script", "engine", "description", "parity_group")
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
  engine <- tolower(step$engine %||% step$language %||% "")
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

  if (engine %in% c("sas", "sasmacro")) {
    sas_bin <- Sys.which("sas")
    log_path <- file.path("logs", sprintf("%s.log", tools::file_path_sans_ext(basename(script))))
    log_path_full <- normalizePath(log_path, winslash = "/", mustWork = FALSE)
    if (!dir.exists(dirname(log_path_full))) {
      dir.create(dirname(log_path_full), recursive = TRUE, showWarnings = FALSE)
    }
    sas_args <- c("-sysin", script, "-log", log_path_full, "-set", "ETL_LOG", log_path_full)
    command <- sprintf("%s %s", shQuote(sas_bin), paste(shQuote(sas_args), collapse = " "))
    if (dry_run || !nzchar(sas_bin)) {
      status <- if (dry_run) "dry_run" else "sas_missing"
      if (!nzchar(sas_bin) && !dry_run) {
        message <- "SAS executable not found on PATH"
      } else {
        message <- "Dry run - no execution"
      }
    } else {
      exit_code <- system2(sas_bin, sas_args)
      status <- if (identical(exit_code, 0L)) "success" else "error"
      message <- if (identical(exit_code, 0L)) "" else sprintf("Exited with code %s", exit_code)
    }
  } else if (engine %in% c("r", "rs")) {
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
    message <- sprintf("Unsupported engine '%s' for ETL step %s", engine, step$step_id)
  }

  list(
    step_id = step$step_id,
    dataset = step$dataset,
    engine = engine,
    description = description,
    status = status,
    message = message,
    command = command,
    parity_group = step$parity_group
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
  if (tolower(Sys.getenv("MOCK_ETL", "false")) == "true") {
    message("MOCK_ETL=true detected; skipping manifest-driven ETL in favour of mock outputs managed by run_all.R")
    quit(status = 0)
  }
  manifest_path <- commandArgs(trailingOnly = TRUE)
  manifest_path <- if (length(manifest_path) > 0) manifest_path[[1]] else "specs/etl_manifest.csv"
  summary <- run_full_etl(manifest_path = manifest_path, dry_run = dry_run)
  print(summary)
}
