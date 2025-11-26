#!/usr/bin/env Rscript

# Pharmaverse-flavoured SDTM builder driven by sdtm.oak.
# Produces foundational DM and AE domains from lightweight example data
# so the pipeline can run end-to-end without SAS.

required_pkgs <- c("dplyr", "readr", "haven", "sdtm.oak", "tibble")

load_required <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(
      sprintf("Missing required packages: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x)) || identical(x, "")) y else x
}

load_required(required_pkgs)
invisible(lapply(required_pkgs, require, character.only = TRUE))

root <- getwd()
raw_dir <- file.path(root, "data", "raw")
sdtm_dir <- file.path(root, "data", "sdtm")

ensure_dir <- function(path) {
  dir.create(path, showWarnings = FALSE, recursive = TRUE)
  path
}

load_or_example_ae <- function(path) {
  if (file.exists(path)) {
    return(readr::read_csv(path, show_col_types = FALSE))
  }

  message("No raw AE CSV found; generating minimal example records.")
  tibble::tibble(
    SUBJID = sprintf("SUBJ%03d", 1:4),
    AETERM = c("Headache", "Nausea", "Fatigue", "Vomiting"),
    AESTDAT = as.Date("2020-01-01") + c(5, 12, 20, 35),
    AEENDAT = as.Date("2020-01-01") + c(7, 14, 24, 40),
    SERIOUS = c("N", "N", "Y", "N"),
    STUDYID = "PHARMAVERSE"
  )
}

load_or_example_dm <- function(path) {
  if (file.exists(path)) {
    return(readr::read_csv(path, show_col_types = FALSE))
  }

  message("No raw DM CSV found; generating minimal example subject records.")
  tibble::tibble(
    STUDYID = "PHARMAVERSE",
    SUBJID = sprintf("SUBJ%03d", 1:4),
    ARM = c("Placebo", "DrugX", "DrugX", "Placebo"),
    SEX = c("M", "F", "F", "M"),
    AGE = c(55, 62, 48, 70)
  )
}

ae_cfg <- list(
  USUBJID = "SUBJID",
  AETERM = "AETERM",
  AESTDTC = "AESTDAT",
  AEENDTC = "AEENDAT",
  AESER = "SERIOUS"
)

dm_cfg <- list(
  STUDYID = "STUDYID",
  USUBJID = "SUBJID",
  ARM = "ARM",
  SEX = "SEX",
  AGE = "AGE"
)

ensure_dir(sdtm_dir)

ae_raw <- load_or_example_ae(file.path(raw_dir, "raw_ae.csv"))
dm_raw <- load_or_example_dm(file.path(raw_dir, "raw_dm.csv"))

if (!"STUDYID" %in% names(ae_raw)) {
  ae_raw$STUDYID <- dm_raw$STUDYID[[1]] %||% "PHARMAVERSE"
}

ae_sdtm <- sdtm.oak::build_ae(ae_raw, cfg = ae_cfg)
dm_sdtm <- sdtm.oak::build_dm(dm_raw, cfg = dm_cfg)

haven::write_xpt(ae_sdtm, file.path(sdtm_dir, "ae.xpt"))
haven::write_xpt(dm_sdtm, file.path(sdtm_dir, "dm.xpt"))

message(sprintf("Pharmaverse SDTM build complete at %s", sdtm_dir))
