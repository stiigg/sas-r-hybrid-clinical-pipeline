#!/usr/bin/env Rscript
#=============================================================================
# SDTM RS DOMAIN GENERATION WITH sdtm.oak
# Replaces manual SAS data steps with automated algorithms
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating RS domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw tumor assessment data from demo
raw_rs_path <- here("demo", "data", "test_sdtm_rs.csv")

if (!file.exists(raw_rs_path)) {
  log_error("Demo data not found: {raw_rs_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  raw_tumor <- tibble(
    SUBJID = rep(c("001", "002", "003"), each = 4),
    VISIT_NUM = rep(1:4, 3),
    VISIT = rep(c("Baseline", "Week 4", "Week 8", "Week 12"), 3),
    ASSESSMENT_DATE = as.Date("2024-01-01") + rep(c(0, 28, 56, 84), 3),
    RESPONSE = c(
      # Subject 001: Complete Response
      "PD", "PR", "CR", "CR",
      # Subject 002: Partial Response  
      "SD", "PR", "PR", "PD",
      # Subject 003: Progressive Disease
      "SD", "SD", "PD", "PD"
    ),
    LONGEST_DIAMETER = c(
      45, 25, 0, 0,
      38, 22, 20, 55,
      42, 40, 62, 68
    )
  )
} else {
  raw_tumor <- read_csv(raw_rs_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_tumor)} records from demo data")
}

# Generate RS domain using sdtm.oak algorithms
rs_domain <- raw_tumor %>%
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
    tgt_val = "RS"
  ) %>%
  
  # Algorithm 4: Set test codes for tumor response
  assign_no_ct(
    tgt_var = "RSTESTCD",
    tgt_val = "OVRLRESP"
  ) %>%
  assign_no_ct(
    tgt_var = "RSTEST", 
    tgt_val = "Overall Response"
  ) %>%
  
  # Algorithm 5: Map response values
  assign_no_ct(
    tgt_var = "RSSTRESC",
    tgt_val = RESPONSE
  ) %>%
  assign_no_ct(
    tgt_var = "RSORRES",
    tgt_val = RESPONSE
  ) %>%
  
  # Algorithm 6: Convert dates to ISO8601 format
  assign_datetime(
    dtc_var = "RSDTC",
    dtm = ASSESSMENT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 7: Derive visit information
  assign_no_ct(
    tgt_var = "VISITNUM",
    tgt_val = VISIT_NUM
  ) %>%
  assign_no_ct(
    tgt_var = "VISIT",
    tgt_val = VISIT
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(RSSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, RSSEQ,
    RSTESTCD, RSTEST, RSORRES, RSSTRESC,
    VISITNUM, VISIT, RSDTC
  )

log_info("Generated {nrow(rs_domain)} RS records for {length(unique(rs_domain$USUBJID))} subjects")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "rs_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    rs_domain, 
    path = output_path,
    label = "Disease Response",
    domain = "RS"
  )
  log_info("✓ RS domain written: {output_path}")
} else {
  # Fallback to haven if xportr not available
  haven::write_xpt(rs_domain, output_path)
  log_info("✓ RS domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "rs_oak.csv")
write_csv(rs_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM RS Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(rs_domain)))
message(sprintf("Subjects: %d", length(unique(rs_domain$USUBJID))))
message(sprintf("Output: %s", output_path))
message("========================================\n")
