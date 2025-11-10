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
  library(tibble)
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

validate_key_vars <- function(df, key_vars, domain, source) {
  missing_keys <- setdiff(key_vars, names(df))
  if (length(missing_keys)) {
    stop(sprintf("%s missing key columns in %s: %s", domain, source, toString(missing_keys)), call. = FALSE)
  }
  invisible(TRUE)
}

detect_duplicate_keys <- function(df, key_vars, domain, source) {
  duplicates <- df %>%
    count(across(all_of(key_vars)), name = "n") %>%
    filter(n > 1)
  if (nrow(duplicates) > 0) {
    stop(sprintf(
      "%s duplicate key combinations detected in %s. Sample: %s",
      domain,
      source,
      preview_rows(select(duplicates, -n), limit = 3)
    ), call. = FALSE)
  }
  invisible(TRUE)
}

preview_rows <- function(df, limit = 5) {
  if (nrow(df) == 0) {
    return("<none>")
  }
  preview <- utils::capture.output(print(utils::head(df, limit)))
  paste(preview, collapse = " | ")
}

vector_equal_tol <- function(a, b, tolerance = 1e-8) {
  stopifnot(length(a) == length(b))
  both_na <- is.na(a) & is.na(b)
  eq <- both_na
  idx <- !both_na
  if (any(idx)) {
    if (is.numeric(a) && is.numeric(b)) {
      eq[idx] <- dplyr::near(a[idx], b[idx], tolerance)
    } else if (inherits(a, "POSIXt") && inherits(b, "POSIXt")) {
      eq[idx] <- abs(as.numeric(a[idx]) - as.numeric(b[idx])) <= tolerance
    } else {
      eq[idx] <- a[idx] == b[idx]
    }
  }
  eq
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

dual_validate <- function(df_primary,
                         df_secondary,
                         key_vars,
                         logger,
                         domain,
                         tolerance = 1e-8,
                         diff_limit = 5) {
  validate_key_vars(df_primary, key_vars, domain, "primary (R)")
  validate_key_vars(df_secondary, key_vars, domain, "secondary (SAS)")
  detect_duplicate_keys(df_primary, key_vars, domain, "primary (R)")
  detect_duplicate_keys(df_secondary, key_vars, domain, "secondary (SAS)")

  by_vars <- key_vars
  primary_sorted <- df_primary %>% arrange(across(all_of(by_vars)))
  secondary_sorted <- df_secondary %>% arrange(across(all_of(by_vars)))

  joined <- full_join(
    primary_sorted %>% mutate(`__primary__` = TRUE),
    secondary_sorted %>% mutate(`__secondary__` = TRUE),
    by = by_vars,
    suffix = c("_primary", "_secondary")
  )

  primary_only <- joined %>%
    filter(!is.na(`__primary__`) & is.na(`__secondary__`)) %>%
    select(all_of(by_vars))
  secondary_only <- joined %>%
    filter(is.na(`__primary__`) & !is.na(`__secondary__`)) %>%
    select(all_of(by_vars))

  issues_detected <- FALSE

  if (nrow(primary_only) > 0) {
    issues_detected <- TRUE
    audit_checkpoint(
      logger,
      "DUAL-VALIDATION",
      domain,
      sprintf(
        "Records missing in SAS comparator. Count=%s Preview=%s",
        nrow(primary_only),
        preview_rows(primary_only, diff_limit)
      ),
      level = "error"
    )
  }

  if (nrow(secondary_only) > 0) {
    issues_detected <- TRUE
    audit_checkpoint(
      logger,
      "DUAL-VALIDATION",
      domain,
      sprintf(
        "Records missing in R primary. Count=%s Preview=%s",
        nrow(secondary_only),
        preview_rows(secondary_only, diff_limit)
      ),
      level = "error"
    )
  }

  common_cols <- intersect(names(df_primary), names(df_secondary))
  compare_cols <- setdiff(common_cols, by_vars)

  value_mismatches <- map_dfr(compare_cols, function(col) {
    primary_col <- joined[[paste0(col, "_primary")]]
    secondary_col <- joined[[paste0(col, "_secondary")]]
    present_idx <- !is.na(joined$`__primary__`) & !is.na(joined$`__secondary__`)
    if (is.null(primary_col) || is.null(secondary_col)) {
      return(NULL)
    }
    eq <- vector_equal_tol(primary_col, secondary_col, tolerance)
    mismatch_idx <- which(present_idx & !eq)
    if (length(mismatch_idx) == 0) {
      return(NULL)
    }
    keys_df <- as_tibble(joined[mismatch_idx, by_vars, drop = FALSE])
    bind_cols(
      keys_df,
      tibble(
        column = rep(col, length(mismatch_idx)),
        value_primary = primary_col[mismatch_idx],
        value_secondary = secondary_col[mismatch_idx]
      )
    )
  })

  if (nrow(value_mismatches) > 0) {
    issues_detected <- TRUE
    audit_checkpoint(
      logger,
      "DUAL-VALIDATION",
      domain,
      sprintf(
        "Value mismatches detected. Count=%s Preview=%s",
        nrow(value_mismatches),
        preview_rows(value_mismatches, diff_limit)
      ),
      level = "error"
    )
  }

  if (issues_detected) {
    stop("Dual validation failure", call. = FALSE)
  }

  audit_checkpoint(logger, "DUAL-VALIDATION", domain, "Passed. You're not getting fired today.")
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
