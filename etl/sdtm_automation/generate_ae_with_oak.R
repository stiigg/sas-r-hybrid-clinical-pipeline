#!/usr/bin/env Rscript
#=============================================================================
# SDTM AE DOMAIN GENERATION WITH sdtm.oak
# Adverse Events - Critical for FDA safety review
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating AE domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw adverse events data from demo
raw_ae_path <- here("demo", "data", "test_sdtm_ae.csv")

if (!file.exists(raw_ae_path)) {
  log_error("Demo data not found: {raw_ae_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  raw_ae <- tibble(
    SUBJID = c("001", "001", "001", "002", "002", "003"),
    AE_TERM = c("Nausea", "Headache", "Fatigue", "Diarrhea", "Dizziness", "Rash"),
    AE_DECODE = c("NAUSEA", "HEADACHE", "FATIGUE", "DIARRHOEA", "DIZZINESS", "RASH"),
    SEVERITY = c("MILD", "MODERATE", "MILD", "SEVERE", "MILD", "MODERATE"),
    SERIOUS = c("N", "N", "N", "Y", "N", "N"),
    RELATIONSHIP = c("POSSIBLE", "NOT RELATED", "PROBABLE", "RELATED", "POSSIBLE", "RELATED"),
    ACTION_TAKEN = c("DOSE NOT CHANGED", "DOSE NOT CHANGED", "DOSE NOT CHANGED", 
                     "DRUG WITHDRAWN", "DOSE NOT CHANGED", "DOSE REDUCED"),
    OUTCOME = c("RECOVERED/RESOLVED", "RECOVERED/RESOLVED", "RECOVERING/RESOLVING",
                "RECOVERED/RESOLVED", "RECOVERED/RESOLVED", "RECOVERING/RESOLVING"),
    START_DATE = as.Date(c("2024-01-05", "2024-01-10", "2024-01-15",
                          "2024-01-12", "2024-01-20", "2024-01-08")),
    END_DATE = as.Date(c("2024-01-08", "2024-01-12", NA,
                        "2024-02-01", "2024-01-22", NA))
  )
} else {
  raw_ae <- read_csv(raw_ae_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_ae)} records from demo data")
}

# Generate AE domain using sdtm.oak algorithms
ae_domain <- raw_ae %>%
  # Algorithm 1: Assign study identifier
  assign_no_ct(
    tgt_var = "STUDYID",
    tgt_val = "RECIST-DEMO"
  ) %>%
  
  # Algorithm 2: Create unique subject ID
  assign_no_ct(
    tgt_var = "USUBJID",
    tgt_val = paste("RECIST-DEMO", SUBJID, sep = "-")
  ) %>%
  
  # Algorithm 3: Assign domain code
  assign_no_ct(
    tgt_var = "DOMAIN",
    tgt_val = "AE"
  ) %>%
  
  # Algorithm 4: Adverse event term (verbatim)
  assign_no_ct(
    tgt_var = "AETERM",
    tgt_val = AE_TERM
  ) %>%
  
  # Algorithm 5: Adverse event decoded term (MedDRA preferred term)
  assign_no_ct(
    tgt_var = "AEDECOD",
    tgt_val = AE_DECODE
  ) %>%
  
  # Algorithm 6: Severity
  assign_no_ct(
    tgt_var = "AESEV",
    tgt_val = SEVERITY
  ) %>%
  
  # Algorithm 7: Serious event flag
  assign_no_ct(
    tgt_var = "AESER",
    tgt_val = SERIOUS
  ) %>%
  
  # Algorithm 8: Relationship to study drug
  assign_no_ct(
    tgt_var = "AEREL",
    tgt_val = RELATIONSHIP
  ) %>%
  
  # Algorithm 9: Action taken with study treatment
  assign_no_ct(
    tgt_var = "AEACN",
    tgt_val = ACTION_TAKEN
  ) %>%
  
  # Algorithm 10: Outcome of adverse event
  assign_no_ct(
    tgt_var = "AEOUT",
    tgt_val = OUTCOME
  ) %>%
  
  # Algorithm 11: Start date
  assign_datetime(
    dtc_var = "AESTDTC",
    dtm = START_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 12: End date
  assign_datetime(
    dtc_var = "AEENDTC",
    dtm = END_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(AESEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, AESEQ,
    AETERM, AEDECOD,
    AESEV, AESER, AEREL, AEACN, AEOUT,
    AESTDTC, AEENDTC
  )

log_info("Generated {nrow(ae_domain)} AE records for {length(unique(ae_domain$USUBJID))} subjects")
log_info("Serious AEs: {sum(ae_domain$AESER == 'Y')}")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "ae_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    ae_domain, 
    path = output_path,
    label = "Adverse Events",
    domain = "AE"
  )
  log_info("✓ AE domain written: {output_path}")
} else {
  haven::write_xpt(ae_domain, output_path)
  log_info("✓ AE domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "ae_oak.csv")
write_csv(ae_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM AE Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(ae_domain)))
message(sprintf("Subjects with AEs: %d", length(unique(ae_domain$USUBJID))))
message(sprintf("Serious AEs: %d", sum(ae_domain$AESER == "Y")))
message(sprintf("Output: %s", output_path))
message("========================================\n")
