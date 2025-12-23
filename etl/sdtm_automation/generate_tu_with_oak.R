#!/usr/bin/env Rscript
#=============================================================================
# SDTM TU DOMAIN GENERATION WITH sdtm.oak
# Tumor Identification - Baseline tumor inventory for oncology trials
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating TU domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw tumor identification data from demo
raw_tu_path <- here("demo", "data", "test_sdtm_tu.csv")

if (!file.exists(raw_tu_path)) {
  log_error("Demo data not found: {raw_tu_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  raw_tumor_id <- tibble(
    SUBJID = c("001", "001", "001", "002", "002", "003", "003", "003"),
    VISIT = rep("Baseline", 8),
    VISIT_NUM = rep(1, 8),
    ASSESSMENT_DATE = as.Date("2024-01-01"),
    LESION_ID = c("TL01", "TL02", "NTL01", "TL01", "NTL01", "TL01", "TL02", "NTL01"),
    LESION_TYPE = c("TARGET LESION", "TARGET LESION", "NON-TARGET LESION",
                    "TARGET LESION", "NON-TARGET LESION",
                    "TARGET LESION", "TARGET LESION", "NON-TARGET LESION"),
    LOCATION = c("LIVER", "LUNG", "LYMPH NODE", 
                 "LIVER", "BONE",
                 "LUNG", "LIVER", "LYMPH NODE"),
    LATERALITY = c("LEFT", "RIGHT", NA, "RIGHT", NA, "LEFT", "LEFT", NA),
    DIRECTIONALITY = c(NA, "UPPER", NA, NA, NA, "LOWER", NA, NA),
    METHOD = rep("CT SCAN", 8)
  )
} else {
  raw_tumor_id <- read_csv(raw_tu_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_tumor_id)} records from demo data")
}

# Generate TU domain using sdtm.oak algorithms
tu_domain <- raw_tumor_id %>%
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
    tgt_val = "TU"
  ) %>%
  
  # Algorithm 4: Tumor identification test codes
  assign_no_ct(
    tgt_var = "TUTESTCD",
    tgt_val = "TUMIDENT"
  ) %>%
  assign_no_ct(
    tgt_var = "TUTEST",
    tgt_val = "Tumor Identification"
  ) %>%
  
  # Algorithm 5: Tumor identification result (lesion type)
  assign_no_ct(
    tgt_var = "TUORRES",
    tgt_val = LESION_TYPE
  ) %>%
  assign_no_ct(
    tgt_var = "TUSTRESC",
    tgt_val = LESION_TYPE
  ) %>%
  
  # Algorithm 6: Tumor location
  assign_no_ct(
    tgt_var = "TULOC",
    tgt_val = LOCATION
  ) %>%
  
  # Algorithm 7: Laterality (if applicable)
  assign_no_ct(
    tgt_var = "TULAT",
    tgt_val = LATERALITY
  ) %>%
  
  # Algorithm 8: Directionality (if applicable)
  assign_no_ct(
    tgt_var = "TUDIR",
    tgt_val = DIRECTIONALITY
  ) %>%
  
  # Algorithm 9: Assessment method
  assign_no_ct(
    tgt_var = "TUMETHOD",
    tgt_val = METHOD
  ) %>%
  
  # Algorithm 10: Linking identifier (to connect with TR domain)
  assign_no_ct(
    tgt_var = "TULNKID",
    tgt_val = LESION_ID
  ) %>%
  
  # Algorithm 11: Convert dates to ISO8601 format
  assign_datetime(
    dtc_var = "TUDTC",
    dtm = ASSESSMENT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 12: Derive visit information
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
    TUSEQ = row_number(),
    TUGRPID = paste(USUBJID, TULNKID, sep = "-")
  ) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, TUSEQ,
    TUTESTCD, TUTEST, TUORRES, TUSTRESC,
    TULOC, TULAT, TUDIR, TUMETHOD,
    VISITNUM, VISIT, TUDTC,
    TULNKID, TUGRPID
  )

log_info("Generated {nrow(tu_domain)} TU records for {length(unique(tu_domain$USUBJID))} subjects")
log_info("Total tumors identified: {length(unique(tu_domain$TULNKID))}")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "tu_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    tu_domain, 
    path = output_path,
    label = "Tumor Identification",
    domain = "TU"
  )
  log_info("✓ TU domain written: {output_path}")
} else {
  # Fallback to haven if xportr not available
  haven::write_xpt(tu_domain, output_path)
  log_info("✓ TU domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "tu_oak.csv")
write_csv(tu_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM TU Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(tu_domain)))
message(sprintf("Subjects: %d", length(unique(tu_domain$USUBJID))))
message(sprintf("Tumors: %d", length(unique(tu_domain$TULNKID))))
message(sprintf("Output: %s", output_path))
message("========================================\n")
