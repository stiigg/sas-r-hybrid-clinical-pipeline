#' Clinical Data Automation Pipeline (R)
#'
#' Ruthless dual validation and QC automation mirroring SAS controls.
#' Designed for audit-ready deployments with aggressive logging and
#' deterministic checkpoints that surface every data anomaly.

suppressPackageStartupMessages({
  library(log4r)
  library(readr)
  library(dplyr)
  library(purrr)
})

# -----------------------------------------------------------------------------
# Version stamping utilities ---------------------------------------------------
# -----------------------------------------------------------------------------

.version_info <- list(
  version = "v2025.11.10",
  launched_by = Sys.info()["user"],
  launched_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
)

version_stamp <- function(logger = NULL) {
  message <- sprintf(
    "=== Pipeline Version: %s | User: %s | Launch: %s ===",
    .version_info$version,
    .version_info$launched_by,
    .version_info$launched_at
  )
  if (!is.null(logger)) {
    info(logger, message)
  } else {
    message(message)
  }
  invisible(.version_info)
}

# -----------------------------------------------------------------------------
# Logging helpers --------------------------------------------------------------
# -----------------------------------------------------------------------------

init_logger <- function(path = file.path("logs", "r_pipeline.log"), level = "INFO") {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  logger <- create.logger()
  logfile(logger) <- path
  level(logger) <- level
  version_stamp(logger)
  logger
}

audit_checkpoint <- function(logger, stage, domain, status, level = c("info", "warn", "error", "fatal")) {
  level <- match.arg(level)
  message <- sprintf("=== [%s] for domain %s: %s ===", stage, domain, status)
  switch(level,
    info = info(logger, message),
    warn = warn(logger, message),
    error = error(logger, message),
    fatal = fatal(logger, message)
  )
  invisible(message)
}

# -----------------------------------------------------------------------------
# Core ETL functions -----------------------------------------------------------
# -----------------------------------------------------------------------------

extract <- function(path, logger, domain) {
  tryCatch({
    df <- read_csv(path, show_col_types = FALSE, progress = FALSE)
    audit_checkpoint(logger, "EXTRACT", domain, sprintf("Success from %s", path))
    df
  }, error = function(e) {
    audit_checkpoint(logger, "EXTRACT", domain, sprintf("Epic fail: %s", e$message), level = "fatal")
    stop(e)
  })
}

qc_check <- function(df, domain) {
  errors <- character()
  if (!"subject_id" %in% names(df)) {
    errors <- c(errors, sprintf("%s missing subject_id column. Shut it down.", domain))
  } else if (any(is.na(df$subject_id))) {
    errors <- c(errors, sprintf("%s missing subject_id values. You should panic.", domain))
  }
  if (!"trtgrp" %in% names(df)) {
    errors <- c(errors, sprintf("%s missing trtgrp column. QA escalation required.", domain))
  } else {
    bad_trtgrp <- setdiff(unique(toupper(df$trtgrp)), c("DRUG", "PLACEBO"))
    if (length(bad_trtgrp) > 0) {
      errors <- c(errors, sprintf("%s bad trtgrp values: %s", domain, toString(bad_trtgrp)))
    }
  }
  errors
}

transform <- function(df, domain, logger) {
  errors <- qc_check(df, domain)
  if (length(errors)) {
    walk(errors, ~audit_checkpoint(logger, "QC", domain, .x, level = "error"))
    stop(sprintf("QC failed for %s: %s", domain, toString(errors)))
  }
  audit_checkpoint(logger, "QC", domain, "Passed. Prepare for dual validation war.")
  df %>% mutate(trtgrp = toupper(trtgrp))
}

load_output <- function(df, path, logger, version = .version_info$version) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  write_csv(df, path)
  audit_checkpoint(logger, "LOAD", "GLOBAL", sprintf("Version %s exported to %s", version, path))
  invisible(path)
}

# -----------------------------------------------------------------------------
# Dual validation --------------------------------------------------------------
# -----------------------------------------------------------------------------

dual_validate <- function(df_primary, df_secondary, key_vars, logger, domain) {
  mismatch <- !isTRUE(all.equal(df_primary[key_vars], df_secondary[key_vars], check.attributes = FALSE))
  if (mismatch) {
    audit_checkpoint(logger, "DUAL-VALIDATION", domain, "Output mismatch detected – escalate CAPA now!", level = "fatal")
    stop("Dual validation failure")
  } else {
    audit_checkpoint(logger, "DUAL-VALIDATION", domain, "Passed. You're not getting fired today.")
  }
  invisible(TRUE)
}

# -----------------------------------------------------------------------------
# SAS vs R comparison utilities ------------------------------------------------
# -----------------------------------------------------------------------------

compare_with_sas <- function(r_path, sas_path, key_vars, logger, domain) {
  if (!file.exists(r_path)) {
    stop(sprintf("R output not found at %s", r_path))
  }
  if (!file.exists(sas_path)) {
    stop(sprintf("SAS output not found at %s", sas_path))
  }
  r_df <- read_csv(r_path, show_col_types = FALSE, progress = FALSE)
  sas_df <- if (grepl("\\\.sas7bdat$", sas_path, ignore.case = TRUE)) {
    if (!requireNamespace("haven", quietly = TRUE)) {
      stop("Package 'haven' required to read SAS datasets. Install it or export CSV counterparts.")
    }
    haven::read_sas(sas_path)
  } else {
    suppressMessages(readr::read_csv(sas_path, show_col_types = FALSE, progress = FALSE))
  }
  dual_validate(r_df, sas_df, key_vars, logger, domain)
}

# -----------------------------------------------------------------------------
# Full pipeline orchestrator ---------------------------------------------------
# -----------------------------------------------------------------------------

run_pipeline <- function(primary_path,
                         secondary_path,
                         output_path,
                         domain = "DM",
                         key_vars = c("subject_id", "trtgrp"),
                         logger = init_logger()) {
  tryCatch({
    primary <- extract(primary_path, logger, domain)
    secondary <- extract(secondary_path, logger, domain)
    clean_primary <- transform(primary, domain, logger)
    clean_secondary <- transform(secondary, domain, logger)
    dual_validate(clean_primary, clean_secondary, key_vars, logger, domain)
    load_output(clean_primary, output_path, logger)
    list(primary = clean_primary, secondary = clean_secondary)
  }, error = function(e) {
    fatal(logger, paste("PIPELINE CRITICAL FAIL:", e$message))
    stop(e)
  })
}

# Example invocation (commented):
# logger <- init_logger("logs/r_pipeline.log")
# run_pipeline("data/raw_clinical.csv", "data/raw_clinical_copy.csv", "outputs/final_sdtm_dm.csv", logger = logger)
