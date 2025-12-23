#!/usr/bin/env Rscript
#=============================================================================
# SDTM SV DOMAIN GENERATION WITH sdtm.oak
# Subject Visits - Actual visit attendance tracking
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating SV domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw visit data from demo
raw_sv_path <- here("demo", "data", "test_sdtm_sv.csv")

if (!file.exists(raw_sv_path)) {
  log_error("Demo data not found: {raw_sv_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  raw_visits <- tibble(
    SUBJID = rep(c("001", "002", "003"), each = 4),
    VISIT_NUM = rep(1:4, 3),
    VISIT = rep(c("Baseline", "Week 4", "Week 8", "Week 12"), 3),
    VISIT_DATE = as.Date(c(
      "2024-01-01", "2024-01-29", "2024-02-26", "2024-03-25",
      "2024-01-05", "2024-02-02", "2024-03-01", NA,
      "2024-01-03", "2024-01-31", "2024-02-28", "2024-03-27"
    ))
  )
} else {
  raw_visits <- read_csv(raw_sv_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_visits)} records from demo data")
}

# Generate SV domain using sdtm.oak algorithms
sv_domain <- raw_visits %>%
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
    tgt_val = "SV"
  ) %>%
  
  # Algorithm 4: Visit number
  assign_no_ct(
    tgt_var = "VISITNUM",
    tgt_val = VISIT_NUM
  ) %>%
  
  # Algorithm 5: Visit name
  assign_no_ct(
    tgt_var = "VISIT",
    tgt_val = VISIT
  ) %>%
  
  # Algorithm 6: Visit start date (same as visit date for this demo)
  assign_datetime(
    dtc_var = "SVSTDTC",
    dtm = VISIT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 7: Visit end date (same as visit date for single-day visits)
  assign_datetime(
    dtc_var = "SVENDTC",
    dtm = VISIT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(SVSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, SVSEQ,
    VISITNUM, VISIT,
    SVSTDTC, SVENDTC
  )

log_info("Generated {nrow(sv_domain)} SV records for {length(unique(sv_domain$USUBJID))} subjects")
log_info("Total visits: {sum(!is.na(sv_domain$SVSTDTC))} completed, {sum(is.na(sv_domain$SVSTDTC))} missed")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "sv_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    sv_domain, 
    path = output_path,
    label = "Subject Visits",
    domain = "SV"
  )
  log_info("✓ SV domain written: {output_path}")
} else {
  haven::write_xpt(sv_domain, output_path)
  log_info("✓ SV domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "sv_oak.csv")
write_csv(sv_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM SV Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(sv_domain)))
message(sprintf("Subjects: %d", length(unique(sv_domain$USUBJID))))
message(sprintf("Completed Visits: %d", sum(!is.na(sv_domain$SVSTDTC))))
message(sprintf("Output: %s", output_path))
message("========================================\n")
