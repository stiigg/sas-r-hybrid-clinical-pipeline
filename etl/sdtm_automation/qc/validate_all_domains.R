#!/usr/bin/env Rscript
#=============================================================================
# SDTM QUALITY CONTROL - VALIDATE ALL DOMAINS
# Automated checks for SDTM compliance and data quality
#=============================================================================

library(dplyr)
library(purrr)
library(haven)
library(readr)
library(here)
library(logger)
library(stringr)

log_info("Starting SDTM Quality Control Validation")

# Define expected domains
expected_domains <- c("DM", "TU", "TR", "RS", "AE", "EX", "SV", 
                      "DS", "CM", "MH", "LB", "VS", "EG", "PE", "QS")

# QC Check Functions
#=============================================================================

# Check 1: Required variables present
check_required_variables <- function(domain_data, domain_name) {
  required_vars <- c("STUDYID", "DOMAIN", "USUBJID")
  
  missing_vars <- setdiff(required_vars, names(domain_data))
  
  if (length(missing_vars) > 0) {
    return(list(
      check = "Required Variables",
      domain = domain_name,
      status = "FAIL",
      message = paste("Missing required variables:", paste(missing_vars, collapse = ", ")),
      severity = "CRITICAL"
    ))
  }
  
  list(
    check = "Required Variables",
    domain = domain_name,
    status = "PASS",
    message = "All required variables present",
    severity = "INFO"
  )
}

# Check 2: Domain code matches
check_domain_code <- function(domain_data, domain_name) {
  if (!"DOMAIN" %in% names(domain_data)) {
    return(list(
      check = "Domain Code",
      domain = domain_name,
      status = "FAIL",
      message = "DOMAIN variable not found",
      severity = "CRITICAL"
    ))
  }
  
  unique_domains <- unique(domain_data$DOMAIN)
  
  if (length(unique_domains) != 1 || unique_domains[1] != domain_name) {
    return(list(
      check = "Domain Code",
      domain = domain_name,
      status = "FAIL",
      message = paste("DOMAIN mismatch. Expected:", domain_name, "Found:", paste(unique_domains, collapse = ", ")),
      severity = "CRITICAL"
    ))
  }
  
  list(
    check = "Domain Code",
    domain = domain_name,
    status = "PASS",
    message = "Domain code is correct",
    severity = "INFO"
  )
}

# Check 3: USUBJID consistency across domains
check_usubjid_format <- function(domain_data, domain_name) {
  if (!"USUBJID" %in% names(domain_data)) {
    return(list(
      check = "USUBJID Format",
      domain = domain_name,
      status = "FAIL",
      message = "USUBJID variable not found",
      severity = "CRITICAL"
    ))
  }
  
  # Check for missing USUBJID
  missing_count <- sum(is.na(domain_data$USUBJID) | domain_data$USUBJID == "")
  
  if (missing_count > 0) {
    return(list(
      check = "USUBJID Format",
      domain = domain_name,
      status = "FAIL",
      message = paste(missing_count, "records with missing USUBJID"),
      severity = "CRITICAL"
    ))
  }
  
  # Check format (should be STUDYID-SUBJID)
  invalid_format <- domain_data %>%
    filter(!str_detect(USUBJID, "^[A-Z0-9]+-[A-Z0-9]+$")) %>%
    nrow()
  
  if (invalid_format > 0) {
    return(list(
      check = "USUBJID Format",
      domain = domain_name,
      status = "WARNING",
      message = paste(invalid_format, "USUBJIDs with non-standard format"),
      severity = "MEDIUM"
    ))
  }
  
  list(
    check = "USUBJID Format",
    domain = domain_name,
    status = "PASS",
    message = "USUBJID format is valid",
    severity = "INFO"
  )
}

# Check 4: Date logic validation
check_date_logic <- function(domain_data, domain_name) {
  date_vars <- names(domain_data)[str_detect(names(domain_data), "DTC$")]
  
  if (length(date_vars) == 0) {
    return(list(
      check = "Date Logic",
      domain = domain_name,
      status = "SKIP",
      message = "No date variables found",
      severity = "INFO"
    ))
  }
  
  issues <- c()
  
  # Check for future dates
  for (date_var in date_vars) {
    dates <- as.Date(substr(domain_data[[date_var]], 1, 10))
    future_dates <- sum(!is.na(dates) & dates > Sys.Date())
    
    if (future_dates > 0) {
      issues <- c(issues, paste(date_var, "has", future_dates, "future dates"))
    }
  }
  
  # Check start <= end for paired dates
  if ("RFSTDTC" %in% names(domain_data) && "RFENDTC" %in% names(domain_data)) {
    start_dates <- as.Date(substr(domain_data$RFSTDTC, 1, 10))
    end_dates <- as.Date(substr(domain_data$RFENDTC, 1, 10))
    
    invalid_ranges <- sum(!is.na(start_dates) & !is.na(end_dates) & start_dates > end_dates)
    
    if (invalid_ranges > 0) {
      issues <- c(issues, paste(invalid_ranges, "records where RFSTDTC > RFENDTC"))
    }
  }
  
  if (length(issues) > 0) {
    return(list(
      check = "Date Logic",
      domain = domain_name,
      status = "FAIL",
      message = paste(issues, collapse = "; "),
      severity = "HIGH"
    ))
  }
  
  list(
    check = "Date Logic",
    domain = domain_name,
    status = "PASS",
    message = "Date logic is valid",
    severity = "INFO"
  )
}

# Check 5: Duplicate records
check_duplicates <- function(domain_data, domain_name) {
  # Check for duplicate keys (USUBJID + SEQ)
  seq_var <- paste0(domain_name, "SEQ")
  
  if (!seq_var %in% names(domain_data)) {
    return(list(
      check = "Duplicate Records",
      domain = domain_name,
      status = "SKIP",
      message = paste("No", seq_var, "variable found"),
      severity = "INFO"
    ))
  }
  
  dup_count <- domain_data %>%
    group_by(USUBJID, !!sym(seq_var)) %>%
    filter(n() > 1) %>%
    nrow()
  
  if (dup_count > 0) {
    return(list(
      check = "Duplicate Records",
      domain = domain_name,
      status = "FAIL",
      message = paste(dup_count, "duplicate USUBJID +", seq_var, "combinations"),
      severity = "CRITICAL"
    ))
  }
  
  list(
    check = "Duplicate Records",
    domain = domain_name,
    status = "PASS",
    message = "No duplicate records found",
    severity = "INFO"
  )
}

# Check 6: Record counts
check_record_counts <- function(domain_data, domain_name) {
  total_records <- nrow(domain_data)
  unique_subjects <- n_distinct(domain_data$USUBJID)
  
  if (total_records == 0) {
    return(list(
      check = "Record Counts",
      domain = domain_name,
      status = "WARNING",
      message = "Domain is empty",
      severity = "MEDIUM"
    ))
  }
  
  list(
    check = "Record Counts",
    domain = domain_name,
    status = "PASS",
    message = paste(total_records, "records for", unique_subjects, "subjects"),
    severity = "INFO"
  )
}

# Main validation function
#=============================================================================

validate_domain <- function(domain_name) {
  log_info("Validating {domain_name} domain...")
  
  # Try to read XPT file
  xpt_path <- here("outputs", "sdtm", paste0(tolower(domain_name), "_oak.xpt"))
  
  if (!file.exists(xpt_path)) {
    return(list(
      list(
        check = "File Existence",
        domain = domain_name,
        status = "FAIL",
        message = paste("XPT file not found:", xpt_path),
        severity = "CRITICAL"
      )
    ))
  }
  
  # Read domain data
  tryCatch({
    domain_data <- read_xpt(xpt_path)
    
    # Run all QC checks
    checks <- list(
      check_required_variables(domain_data, domain_name),
      check_domain_code(domain_data, domain_name),
      check_usubjid_format(domain_data, domain_name),
      check_date_logic(domain_data, domain_name),
      check_duplicates(domain_data, domain_name),
      check_record_counts(domain_data, domain_name)
    )
    
    return(checks)
    
  }, error = function(e) {
    return(list(
      list(
        check = "File Read",
        domain = domain_name,
        status = "FAIL",
        message = paste("Error reading file:", e$message),
        severity = "CRITICAL"
      )
    ))
  })
}

# Run validation on all domains
#=============================================================================

log_info("Running QC checks on all SDTM domains...")

all_results <- expected_domains %>%
  map(validate_domain) %>%
  flatten() %>%
  bind_rows()

# Create output directory
dir.create(here("outputs", "qc"), recursive = TRUE, showWarnings = FALSE)

# Write results
qc_report_path <- here("outputs", "qc", "sdtm_validation_report.csv")
write_csv(all_results, qc_report_path)

log_info("✓ QC report written: {qc_report_path}")

# Summary statistics
summary_stats <- all_results %>%
  group_by(status) %>%
  summarise(
    count = n(),
    .groups = "drop"
  )

# Print summary
message("\n========================================")
message("SDTM Quality Control Summary")
message("========================================")
message(sprintf("Total checks performed: %d", nrow(all_results)))
message(sprintf("Domains validated: %d", length(expected_domains)))
message("\nResults by status:")
for (i in seq_len(nrow(summary_stats))) {
  message(sprintf("  %s: %d", summary_stats$status[i], summary_stats$count[i]))
}

# Critical issues
critical_issues <- all_results %>% filter(severity == "CRITICAL")
if (nrow(critical_issues) > 0) {
  message("\n⚠️  CRITICAL ISSUES FOUND:")
  for (i in seq_len(nrow(critical_issues))) {
    message(sprintf("  [%s] %s: %s", 
                    critical_issues$domain[i], 
                    critical_issues$check[i],
                    critical_issues$message[i]))
  }
}

message("========================================\n")

# Exit with error if critical issues found
if (nrow(critical_issues) > 0) {
  log_error("Validation FAILED - {nrow(critical_issues)} critical issues")
  quit(status = 1)
} else {
  log_info("Validation PASSED - No critical issues")
  quit(status = 0)
}
