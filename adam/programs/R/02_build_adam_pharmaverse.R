#!/usr/bin/env Rscript

# Pharmaverse-flavoured ADaM builder using admiral package
# Creates ADSL (subject-level analysis dataset) from SDTM domains

required_pkgs <- c("admiral", "dplyr", "haven", "lubridate", "stringr")

load_required <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(
      sprintf("Missing required packages: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
}

load_required(required_pkgs)
invisible(lapply(required_pkgs, require, character.only = TRUE))

# Define paths - now reads from sdtm/data/output
root <- getwd()
sdtm_dir <- file.path(root, "sdtm", "data", "output")
adam_dir <- file.path(root, "adam", "data", "output")

# Create output directory
dir.create(adam_dir, showWarnings = FALSE, recursive = TRUE)

# Load SDTM domains from dedicated sdtm/ directory
dm <- haven::read_xpt(file.path(sdtm_dir, "dm.xpt"))
ae <- haven::read_xpt(file.path(sdtm_dir, "ae.xpt"))

# Build ADSL using admiral
adsl <- dm %>%
  # Add standard admiral derivations
  admiral::derive_vars_merged(
    dataset_add = ae,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(TRTEMFL = AETERM),
    filter_add = !is.na(AETERM)
  ) %>%
  # Add safety population flag
  dplyr::mutate(
    SAFFL = "Y",
    ITTFL = "Y",
    # Treatment dates (simplified for example)
    TRTSDT = as.Date("2020-01-01"),
    TRTEDT = as.Date("2020-12-31"),
    # Baseline age
    AAGE = AGE
  ) %>%
  # Select final variables
  dplyr::select(STUDYID, USUBJID, SUBJID, ARM, SEX, AGE, SAFFL, ITTFL, TRTSDT, TRTEDT, AAGE)

# Write ADSL to dedicated adam/ directory
haven::write_xpt(adsl, file.path(adam_dir, "adsl.xpt"))

message(sprintf("Pharmaverse ADaM build complete at %s", adam_dir))
message(sprintf("Created ADSL with %d subjects", nrow(adsl)))
