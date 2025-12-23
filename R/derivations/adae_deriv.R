#' Build ADAE (Adverse Events Analysis) Dataset
#'
#' Creates an ADaM-compliant ADAE dataset from SDTM AE data with comprehensive
#' derivations following CDISC standards and admiral best practices.
#'
#' @param ae SDTM AE (Adverse Events) data frame with required variables:
#'   USUBJID, AESTDTC, AEENDTC, AESEV, AEREL, AESER, etc.
#' @param adsl Derived ADSL data frame providing subject-level variables including:
#'   USUBJID, TRTSDT, TRTEDT, DTHDT, EOSDT, TRT01P, TRT01A, AGEGR1, SEX, etc.
#' @param ex SDTM EX (Exposure) data frame with required variables:
#'   USUBJID, EXSTDTC, EXENDTC, EXDOSE, EXTRT for last dose derivations.
#'   If NULL, exposure-related derivations (LDOSEDTM, DOSEON) will be skipped.
#'
#' @return ADAE data frame with the following key derived variables:
#'   - ASTDTM, AENDTM: Analysis start/end datetime with imputation
#'   - ASTDT, AENDT: Analysis start/end dates
#'   - ASTDY, AENDY: Relative days from treatment start
#'   - ADURN, ADURU: AE duration and unit
#'   - ASEV, ASEVN: Severity (character and numeric)
#'   - TRTEMFL: Treatment emergent flag
#'   - LDOSEDTM: Last dose datetime before AE onset
#'   - AOCCIFL: First occurrence flag (most severe)
#'   - ANL01FL: Analysis flag
#'
#' @details
#' The function implements the following derivation steps:
#' 1. Convert blank values to NA for proper data handling
#' 2. Merge minimal ADSL variables needed for derivations
#' 3. Derive datetime variables with proper date imputation
#' 4. Calculate relative days from treatment start
#' 5. Derive AE duration
#' 6. Integrate exposure data for last dose information (if ex provided)
#' 7. Derive severity variables with numeric ordering
#' 8. Calculate treatment emergent flag
#' 9. Derive first occurrence flags
#' 10. Merge remaining ADSL variables
#'
#' Date Imputation Strategy:
#' - Start dates: Imputed to earliest possible date, not before treatment start
#' - End dates: Imputed to latest possible date, not after death/end of study
#'
#' @examples
#' \dontrun{
#' library(admiral)
#' library(dplyr)
#' library(lubridate)
#'
#' # Build ADAE with exposure data
#' adae <- build_adae(ae = ae_data, adsl = adsl_data, ex = ex_data)
#'
#' # Build ADAE without exposure data
#' adae <- build_adae(ae = ae_data, adsl = adsl_data, ex = NULL)
#' }
#'
#' @references
#' - CDISC ADaM Implementation Guide v1.3
#' - admiral R package: https://pharmaverse.github.io/admiral/
#' - Pharmaverse ADAE examples: https://pharmaverse.github.io/examples/adam/adae.html
#'
#' @noRd
build_adae <- function(ae, adsl, ex = NULL) {
  
  # Input validation
  required_ae_vars <- c("USUBJID", "AESTDTC")
  required_adsl_vars <- c("USUBJID", "TRTSDT", "TRTEDT")
  
  missing_ae <- setdiff(required_ae_vars, names(ae))
  missing_adsl <- setdiff(required_adsl_vars, names(adsl))
  
  if (length(missing_ae) > 0) {
    stop(paste("Missing required AE variables:", paste(missing_ae, collapse = ", ")))
  }
  if (length(missing_adsl) > 0) {
    stop(paste("Missing required ADSL variables:", paste(missing_adsl, collapse = ", ")))
  }
  
  # Convert blanks to NA for proper data handling
  ae <- admiral::convert_blanks_to_na(ae)
  adsl <- admiral::convert_blanks_to_na(adsl)
  if (!is.null(ex)) {
    ex <- admiral::convert_blanks_to_na(ex)
  }
  
  # Create AESEQ if it doesn't exist (sequence number per subject)
  if (!"AESEQ" %in% names(ae)) {
    ae <- ae |>
      dplyr::group_by(USUBJID) |>
      dplyr::mutate(AESEQ = dplyr::row_number()) |>
      dplyr::ungroup()
  }
  
  # Define minimal ADSL variables needed for derivations
  # Include study dates for proper date derivations and flags
  adsl_derivation_vars <- admiral::exprs(TRTSDT, TRTEDT, DTHDT, EOSDT)
  
  # Step 1: Merge minimal ADSL variables for derivations
  adae <- ae |>
    admiral::derive_vars_merged(
      dataset_add = dplyr::select(adsl, STUDYID, USUBJID, !!!adsl_derivation_vars),
      by_vars = admiral::exprs(USUBJID)
    )
  
  # Step 2: Derive datetime variables with proper imputation
  # Start datetime: Impute to earliest possible, not before treatment start
  adae <- adae |>
    admiral::derive_vars_dtm(
      dtc = AESTDTC,
      new_vars_prefix = "AST",
      highest_imputation = "M",
      min_dates = admiral::exprs(TRTSDT)
    )
  
  # End datetime: Impute to latest possible, not after death/EOS
  # Only derive if AEENDTC exists in the data
  if ("AEENDTC" %in% names(adae)) {
    adae <- adae |>
      admiral::derive_vars_dtm(
        dtc = AEENDTC,
        new_vars_prefix = "AEN",
        highest_imputation = "M",
        date_imputation = "last",
        time_imputation = "last",
        max_dates = admiral::exprs(DTHDT, EOSDT)
      )
  }
  
  # Step 3: Convert datetime to date variables
  date_vars <- c("ASTDTM")
  if ("AENDTM" %in% names(adae)) {
    date_vars <- c(date_vars, "AENDTM")
  }
  
  adae <- adae |>
    admiral::derive_vars_dtm_to_dt(admiral::exprs(!!!rlang::syms(date_vars)))
  
  # Step 4: Derive relative days from treatment start
  study_day_vars <- c("ASTDT")
  if ("AENDT" %in% names(adae)) {
    study_day_vars <- c(study_day_vars, "AENDT")
  }
  
  adae <- adae |>
    admiral::derive_vars_dy(
      reference_date = TRTSDT,
      source_vars = admiral::exprs(!!!rlang::syms(study_day_vars))
    )
  
  # Step 5: Derive AE duration (in days)
  if ("AENDT" %in% names(adae)) {
    adae <- adae |>
      admiral::derive_vars_duration(
        new_var = ADURN,
        new_var_unit = ADURU,
        start_date = ASTDT,
        end_date = AENDT,
        in_unit = "days",
        out_unit = "days",
        add_one = TRUE,
        trunc_out = FALSE
      )
  }
  
  # Step 6: Derive last dose datetime from exposure data (if provided)
  if (!is.null(ex) && nrow(ex) > 0) {
    # Prepare exposure data with datetime variables
    ex_ext <- ex |>
      admiral::derive_vars_dtm(
        dtc = EXSTDTC,
        new_vars_prefix = "EXST",
        flag_imputation = "none"
      )
    
    # Only derive end datetime if EXENDTC exists
    if ("EXENDTC" %in% names(ex_ext)) {
      ex_ext <- ex_ext |>
        admiral::derive_vars_dtm(
          dtc = EXENDTC,
          new_vars_prefix = "EXEN",
          time_imputation = "last",
          flag_imputation = "none"
        )
    }
    
    # Derive last dose datetime before AE onset
    adae <- adae |>
      admiral::derive_vars_joined(
        dataset_add = ex_ext,
        by_vars = admiral::exprs(STUDYID, USUBJID),
        new_vars = admiral::exprs(LDOSEDTM = EXSTDTM),
        join_vars = admiral::exprs(EXSTDTM),
        join_type = "all",
        order = admiral::exprs(EXSTDTM),
        filter_add = (EXDOSE > 0 | (EXDOSE == 0 & grepl("PLACEBO", EXTRT, ignore.case = TRUE))) & 
                     !is.na(EXSTDTM),
        filter_join = EXSTDTM <= ASTDTM,
        mode = "last"
      )
  }
  
  # Step 7: Derive severity and causality variables
  # Create numeric severity for proper ordering and analysis
  severity_levels <- c("MILD", "MODERATE", "SEVERE", "DEATH THREATENING")
  
  adae <- adae |>
    dplyr::mutate(
      # Standardize severity variable name
      ASEV = dplyr::if_else(
        is.na(AESEV),
        NA_character_,
        toupper(AESEV)
      ),
      # Create numeric severity for ordering
      ASEVN = as.integer(factor(ASEV, levels = severity_levels)),
      # Causality variable (relationship to treatment)
      AREL = dplyr::if_else(
        !is.na(AEREL),
        toupper(AEREL),
        NA_character_
      )
    )
  
  # Step 8: Derive treatment emergent flag
  # AE is treatment emergent if it starts on or after treatment start
  # and within 30 days after treatment end
  adae <- adae |>
    admiral::derive_var_trtemfl(
      trt_start_date = TRTSDT,
      trt_end_date = TRTEDT,
      end_window = 30
    )
  
  # Step 9: Derive first occurrence flag for most severe treatment-emergent AE
  adae <- adae |>
    admiral::restrict_derivation(
      derivation = admiral::derive_var_extreme_flag,
      args = admiral::params(
        by_vars = admiral::exprs(USUBJID),
        order = admiral::exprs(desc(ASEVN), ASTDTM, AESEQ),
        new_var = AOCCIFL,
        mode = "first"
      ),
      filter = TRTEMFL == "Y"
    )
  
  # Step 10: Set analysis flag
  # ANL01FL = 'Y' indicates record should be included in primary analysis
  adae <- adae |>
    dplyr::mutate(ANL01FL = "Y")
  
  # Step 11: Merge remaining ADSL variables
  # Get all ADSL variables except those already merged
  remaining_adsl_vars <- setdiff(
    names(adsl),
    c("STUDYID", "USUBJID", as.character(adsl_derivation_vars))
  )
  
  adae <- adae |>
    admiral::derive_vars_merged(
      dataset_add = dplyr::select(adsl, STUDYID, USUBJID, !!!rlang::syms(remaining_adsl_vars)),
      by_vars = admiral::exprs(STUDYID, USUBJID)
    )
  
  # Data quality check: Validate date ordering
  invalid_dates <- adae |>
    dplyr::filter(!is.na(ASTDT) & !is.na(AENDT) & ASTDT > AENDT)
  
  if (nrow(invalid_dates) > 0) {
    warning(
      paste0(
        "Found ", nrow(invalid_dates), 
        " records where start date is after end date. ",
        "Please review these records: ",
        paste(unique(invalid_dates$USUBJID), collapse = ", ")
      )
    )
  }
  
  return(adae)
}
