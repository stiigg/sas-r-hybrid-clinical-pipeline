#!/usr/bin/env Rscript
#=============================================================================
# SDTM TR DOMAIN GENERATION WITH sdtm.oak
# Tumor Results - Longitudinal tumor measurements over time
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating TR domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw tumor measurement data from demo
raw_tr_path <- here("demo", "data", "test_sdtm_tr.csv")

if (!file.exists(raw_tr_path)) {
  log_error("Demo data not found: {raw_tr_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  # Subject 001: 2 target lesions measured over 4 visits
  raw_measurements <- tibble(
    SUBJID = rep(c("001", "001", "002", "002", "003", "003"), each = 4),
    LESION_ID = rep(c("TL01", "TL02", "TL01", "TL01", "TL01", "TL02"), each = 4),
    VISIT_NUM = rep(1:4, 6),
    VISIT = rep(c("Baseline", "Week 4", "Week 8", "Week 12"), 6),
    ASSESSMENT_DATE = as.Date("2024-01-01") + rep(c(0, 28, 56, 84), 6),
    # Subject 001 TL01 (liver): shrinking
    MEASUREMENT = c(
      45, 38, 25, 22,  # Subject 001, TL01
      30, 28, 20, 18,  # Subject 001, TL02
      42, 38, 30, 35,  # Subject 002, TL01
      38, 40, 42, 50,  # Subject 002, TL01 (duplicate for demo)
      50, 48, 55, 60,  # Subject 003, TL01
      35, 33, 38, 45   # Subject 003, TL02
    ),
    METHOD = rep("CT SCAN", 24)
  )
} else {
  raw_measurements <- read_csv(raw_tr_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_measurements)} records from demo data")
}

# Generate TR domain using sdtm.oak algorithms
tr_domain <- raw_measurements %>%
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
    tgt_val = "TR"
  ) %>%
  
  # Algorithm 4: Tumor result test codes
  assign_no_ct(
    tgt_var = "TRTESTCD",
    tgt_val = "LDIAM"
  ) %>%
  assign_no_ct(
    tgt_var = "TRTEST",
    tgt_val = "Longest Diameter"
  ) %>%
  
  # Algorithm 5: Original result
  assign_no_ct(
    tgt_var = "TRORRES",
    tgt_val = as.character(MEASUREMENT)
  ) %>%
  assign_no_ct(
    tgt_var = "TRORRESU",
    tgt_val = "mm"
  ) %>%
  
  # Algorithm 6: Standardized result
  assign_no_ct(
    tgt_var = "TRSTRESC",
    tgt_val = as.character(MEASUREMENT)
  ) %>%
  assign_no_ct(
    tgt_var = "TRSTRESN",
    tgt_val = MEASUREMENT
  ) %>%
  assign_no_ct(
    tgt_var = "TRSTRESU",
    tgt_val = "mm"
  ) %>%
  
  # Algorithm 7: Assessment method
  assign_no_ct(
    tgt_var = "TRMETHOD",
    tgt_val = METHOD
  ) %>%
  
  # Algorithm 8: Linking identifier (to connect with TU domain)
  assign_no_ct(
    tgt_var = "TRLNKID",
    tgt_val = LESION_ID
  ) %>%
  
  # Algorithm 9: Convert dates to ISO8601 format
  assign_datetime(
    dtc_var = "TRDTC",
    dtm = ASSESSMENT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 10: Derive visit information
  assign_no_ct(
    tgt_var = "VISITNUM",
    tgt_val = VISIT_NUM
  ) %>%
  assign_no_ct(
    tgt_var = "VISIT",
    tgt_val = VISIT
  ) %>%
  
  # Add sequence numbering and grouping
  group_by(USUBJID) %>%
  mutate(
    TRSEQ = row_number(),
    TRGRPID = paste(USUBJID, TRLNKID, sep = "-")
  ) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, TRSEQ,
    TRTESTCD, TRTEST, 
    TRORRES, TRORRESU, TRSTRESC, TRSTRESN, TRSTRESU,
    TRMETHOD,
    VISITNUM, VISIT, TRDTC,
    TRLNKID, TRGRPID
  )

log_info("Generated {nrow(tr_domain)} TR records for {length(unique(tr_domain$USUBJID))} subjects")
log_info("Measurements for {length(unique(tr_domain$TRLNKID))} tumors across {length(unique(tr_domain$VISITNUM))} visits")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "tr_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    tr_domain, 
    path = output_path,
    label = "Tumor Results",
    domain = "TR"
  )
  log_info("✓ TR domain written: {output_path}")
} else {
  # Fallback to haven if xportr not available
  haven::write_xpt(tr_domain, output_path)
  log_info("✓ TR domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "tr_oak.csv")
write_csv(tr_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM TR Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(tr_domain)))
message(sprintf("Subjects: %d", length(unique(tr_domain$USUBJID))))
message(sprintf("Tumors: %d", length(unique(tr_domain$TRLNKID))))
message(sprintf("Visits: %d", length(unique(tr_domain$VISITNUM))))
message(sprintf("Output: %s", output_path))
message("========================================\n")
