#!/usr/bin/env Rscript
#=============================================================================
# DOMAIN-SPECIFIC QC CHECKS
# Additional validation rules specific to each SDTM domain
#=============================================================================

library(dplyr)
library(logger)

# DM-specific checks
check_dm_specific <- function(dm_data) {
  checks <- list()
  
  # Check 1: One record per subject
  dup_subjects <- dm_data %>%
    group_by(USUBJID) %>%
    filter(n() > 1) %>%
    nrow()
  
  checks[[1]] <- list(
    check = "DM One Record Per Subject",
    domain = "DM",
    status = if(dup_subjects == 0) "PASS" else "FAIL",
    message = if(dup_subjects == 0) "One record per subject" else paste(dup_subjects, "duplicate subjects"),
    severity = if(dup_subjects == 0) "INFO" else "CRITICAL"
  )
  
  # Check 2: Required DM variables
  required_dm_vars <- c("AGE", "SEX", "RACE", "ARM", "ACTARM", "RFSTDTC")
  missing_dm_vars <- setdiff(required_dm_vars, names(dm_data))
  
  checks[[2]] <- list(
    check = "DM Required Variables",
    domain = "DM",
    status = if(length(missing_dm_vars) == 0) "PASS" else "FAIL",
    message = if(length(missing_dm_vars) == 0) "All DM-specific variables present" else paste("Missing:", paste(missing_dm_vars, collapse = ", ")),
    severity = if(length(missing_dm_vars) == 0) "INFO" else "HIGH"
  )
  
  # Check 3: Age range validation
  if ("AGE" %in% names(dm_data)) {
    invalid_age <- sum(dm_data$AGE < 0 | dm_data$AGE > 120, na.rm = TRUE)
    
    checks[[3]] <- list(
      check = "DM Age Range",
      domain = "DM",
      status = if(invalid_age == 0) "PASS" else "WARNING",
      message = if(invalid_age == 0) "Age values are realistic" else paste(invalid_age, "subjects with age < 0 or > 120"),
      severity = if(invalid_age == 0) "INFO" else "MEDIUM"
    )
  }
  
  return(checks)
}

# AE-specific checks
check_ae_specific <- function(ae_data) {
  checks <- list()
  
  # Check 1: Start date before or equal to end date
  if (all(c("AESTDTC", "AEENDTC") %in% names(ae_data))) {
    ae_with_dates <- ae_data %>%
      filter(!is.na(AESTDTC), !is.na(AEENDTC)) %>%
      mutate(
        start_date = as.Date(substr(AESTDTC, 1, 10)),
        end_date = as.Date(substr(AEENDTC, 1, 10))
      ) %>%
      filter(start_date > end_date)
    
    checks[[1]] <- list(
      check = "AE Date Sequence",
      domain = "AE",
      status = if(nrow(ae_with_dates) == 0) "PASS" else "FAIL",
      message = if(nrow(ae_with_dates) == 0) "All AE dates are sequential" else paste(nrow(ae_with_dates), "AEs with start > end"),
      severity = if(nrow(ae_with_dates) == 0) "INFO" else "HIGH"
    )
  }
  
  # Check 2: Serious AE flag
  if ("AESER" %in% names(ae_data)) {
    invalid_aeser <- sum(!ae_data$AESER %in% c("Y", "N", NA))
    
    checks[[2]] <- list(
      check = "AE Serious Flag",
      domain = "AE",
      status = if(invalid_aeser == 0) "PASS" else "WARNING",
      message = if(invalid_aeser == 0) "AESER values are valid" else paste(invalid_aeser, "invalid AESER values"),
      severity = if(invalid_aeser == 0) "INFO" else "MEDIUM"
    )
  }
  
  # Check 3: Required AE variables
  required_ae_vars <- c("AETERM", "AEDECOD", "AESTDTC")
  missing_ae_vars <- setdiff(required_ae_vars, names(ae_data))
  
  checks[[3]] <- list(
    check = "AE Required Variables",
    domain = "AE",
    status = if(length(missing_ae_vars) == 0) "PASS" else "FAIL",
    message = if(length(missing_ae_vars) == 0) "All AE-specific variables present" else paste("Missing:", paste(missing_ae_vars, collapse = ", ")),
    severity = if(length(missing_ae_vars) == 0) "INFO" else "HIGH"
  )
  
  return(checks)
}

# LB-specific checks
check_lb_specific <- function(lb_data) {
  checks <- list()
  
  # Check 1: Numeric results for LBSTRESN
  if ("LBSTRESN" %in% names(lb_data)) {
    non_numeric <- sum(!is.na(lb_data$LBSTRESC) & is.na(lb_data$LBSTRESN))
    
    checks[[1]] <- list(
      check = "LB Numeric Results",
      domain = "LB",
      status = if(non_numeric < nrow(lb_data) * 0.1) "PASS" else "WARNING",
      message = paste(non_numeric, "of", nrow(lb_data), "results could not be converted to numeric"),
      severity = if(non_numeric < nrow(lb_data) * 0.1) "INFO" else "MEDIUM"
    )
  }
  
  # Check 2: Normal range indicator consistency
  if (all(c("LBSTRESN", "LBSTNRLO", "LBSTNRHI", "LBNRIND") %in% names(lb_data))) {
    lb_with_range <- lb_data %>%
      filter(!is.na(LBSTRESN), !is.na(LBSTNRLO), !is.na(LBSTNRHI), !is.na(LBNRIND)) %>%
      mutate(
        calculated_nrind = case_when(
          LBSTRESN < LBSTNRLO ~ "LOW",
          LBSTRESN > LBSTNRHI ~ "HIGH",
          TRUE ~ "NORMAL"
        ),
        mismatch = LBNRIND != calculated_nrind
      )
    
    mismatches <- sum(lb_with_range$mismatch, na.rm = TRUE)
    
    checks[[2]] <- list(
      check = "LB Normal Range Logic",
      domain = "LB",
      status = if(mismatches == 0) "PASS" else "WARNING",
      message = if(mismatches == 0) "LBNRIND consistent with ranges" else paste(mismatches, "LBNRIND mismatches"),
      severity = if(mismatches == 0) "INFO" else "MEDIUM"
    )
  }
  
  # Check 3: Specimen type
  if ("LBSPEC" %in% names(lb_data)) {
    missing_spec <- sum(is.na(lb_data$LBSPEC) | lb_data$LBSPEC == "")
    
    checks[[3]] <- list(
      check = "LB Specimen Type",
      domain = "LB",
      status = if(missing_spec == 0) "PASS" else "WARNING",
      message = if(missing_spec == 0) "All records have specimen type" else paste(missing_spec, "records missing LBSPEC"),
      severity = if(missing_spec == 0) "INFO" else "MEDIUM"
    )
  }
  
  return(checks)
}

# TR/TU linkage check
check_tumor_linkage <- function(tu_data, tr_data) {
  checks <- list()
  
  if (!all(c("TULNKID") %in% names(tu_data)) || !all(c("TRLNKID") %in% names(tr_data))) {
    checks[[1]] <- list(
      check = "TU-TR Linkage",
      domain = "TR",
      status = "SKIP",
      message = "Linking variables not found",
      severity = "INFO"
    )
    return(checks)
  }
  
  # Check that all TR records link to TU
  unlinked_tr <- tr_data %>%
    anti_join(tu_data, by = c("USUBJID", "TRLNKID" = "TULNKID")) %>%
    nrow()
  
  checks[[1]] <- list(
    check = "TU-TR Linkage",
    domain = "TR",
    status = if(unlinked_tr == 0) "PASS" else "FAIL",
    message = if(unlinked_tr == 0) "All TR records link to TU" else paste(unlinked_tr, "TR records without matching TU"),
    severity = if(unlinked_tr == 0) "INFO" else "CRITICAL"
  )
  
  return(checks)
}

# Export functions
log_info("Domain-specific QC checks loaded")
