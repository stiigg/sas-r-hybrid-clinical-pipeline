#!/usr/bin/env Rscript
#=============================================================================
# SDTM DM DOMAIN GENERATION WITH sdtm.oak
# Demographics - Foundation domain for all SDTM datasets
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating DM domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw demographics data from demo
raw_dm_path <- here("demo", "data", "test_sdtm_dm.csv")

if (!file.exists(raw_dm_path)) {
  log_error("Demo data not found: {raw_dm_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  raw_demo <- tibble(
    SUBJID = c("001", "002", "003"),
    SEX = c("M", "F", "M"),
    AGE = c(62, 58, 71),
    RACE = c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN"),
    ETHNIC = c("NOT HISPANIC OR LATINO", "NOT HISPANIC OR LATINO", "HISPANIC OR LATINO"),
    COUNTRY = c("USA", "USA", "FRA"),
    SITEID = c("101", "102", "101"),
    ARM = c("Drug A", "Drug A", "Placebo"),
    ARMCD = c("DRGA", "DRGA", "PLBO"),
    RFSTDTC = as.Date(c("2024-01-01", "2024-01-05", "2024-01-03")),
    RFENDTC = as.Date(c("2024-04-01", "2024-02-15", "2024-04-05")),
    RFICDTC = as.Date(c("2023-12-28", "2024-01-02", "2023-12-30")),
    DTHFL = c("N", "N", "N"),
    DTHDTC = as.Date(c(NA, NA, NA))
  )
} else {
  raw_demo <- read_csv(raw_dm_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_demo)} records from demo data")
}

# Generate DM domain using sdtm.oak algorithms
dm_domain <- raw_demo %>%
  # Algorithm 1: Assign study identifier
  assign_no_ct(
    tgt_var = "STUDYID",
    tgt_val = "RECIST-DEMO"
  ) %>%
  
  # Algorithm 2: Assign domain code
  assign_no_ct(
    tgt_var = "DOMAIN",
    tgt_val = "DM"
  ) %>%
  
  # Algorithm 3: Create unique subject ID
  assign_no_ct(
    tgt_var = "USUBJID",
    tgt_val = paste("RECIST-DEMO", SUBJID, sep = "-")
  ) %>%
  
  # Algorithm 4: Subject identifier (pass through)
  assign_no_ct(
    tgt_var = "SUBJID",
    tgt_val = SUBJID
  ) %>%
  
  # Algorithm 5: Reference dates - informed consent
  assign_datetime(
    dtc_var = "RFICDTC",
    dtm = RFICDTC,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 6: Reference dates - study start
  assign_datetime(
    dtc_var = "RFSTDTC",
    dtm = RFSTDTC,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 7: Reference dates - study end
  assign_datetime(
    dtc_var = "RFENDTC",
    dtm = RFENDTC,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 8: First study drug date (same as RFSTDTC for this demo)
  assign_no_ct(
    tgt_var = "RFXSTDTC",
    tgt_val = RFSTDTC
  ) %>%
  
  # Algorithm 9: Last study drug date (same as RFENDTC for this demo)
  assign_no_ct(
    tgt_var = "RFXENDTC",
    tgt_val = RFENDTC
  ) %>%
  
  # Algorithm 10: Study participation end (same as RFENDTC)
  assign_no_ct(
    tgt_var = "RFPENDTC",
    tgt_val = RFENDTC
  ) %>%
  
  # Algorithm 11: Demographics - Sex
  assign_no_ct(
    tgt_var = "SEX",
    tgt_val = SEX
  ) %>%
  
  # Algorithm 12: Demographics - Race
  assign_no_ct(
    tgt_var = "RACE",
    tgt_val = RACE
  ) %>%
  
  # Algorithm 13: Demographics - Ethnicity
  assign_no_ct(
    tgt_var = "ETHNIC",
    tgt_val = ETHNIC
  ) %>%
  
  # Algorithm 14: Demographics - Age
  assign_no_ct(
    tgt_var = "AGE",
    tgt_val = AGE
  ) %>%
  
  # Algorithm 15: Age units
  assign_no_ct(
    tgt_var = "AGEU",
    tgt_val = "YEARS"
  ) %>%
  
  # Algorithm 16: Treatment arms - Planned
  assign_no_ct(
    tgt_var = "ARM",
    tgt_val = ARM
  ) %>%
  assign_no_ct(
    tgt_var = "ARMCD",
    tgt_val = ARMCD
  ) %>%
  
  # Algorithm 17: Treatment arms - Actual (same as planned for this demo)
  assign_no_ct(
    tgt_var = "ACTARM",
    tgt_val = ARM
  ) %>%
  assign_no_ct(
    tgt_var = "ACTARMCD",
    tgt_val = ARMCD
  ) %>%
  
  # Algorithm 18: Country
  assign_no_ct(
    tgt_var = "COUNTRY",
    tgt_val = COUNTRY
  ) %>%
  
  # Algorithm 19: Site identifier
  assign_no_ct(
    tgt_var = "SITEID",
    tgt_val = SITEID
  ) %>%
  
  # Algorithm 20: Death flag
  assign_no_ct(
    tgt_var = "DTHFL",
    tgt_val = DTHFL
  ) %>%
  
  # Algorithm 21: Death date (if applicable)
  mutate(
    DTHDTC = if_else(DTHFL == "Y", as.character(DTHDTC), NA_character_)
  ) %>%
  
  # Select final SDTM variables in required order
  select(
    STUDYID, DOMAIN, USUBJID, SUBJID,
    RFSTDTC, RFENDTC, RFXSTDTC, RFXENDTC, RFICDTC, RFPENDTC,
    DTHDTC, DTHFL,
    SITEID, AGE, AGEU, SEX, RACE, ETHNIC,
    ARMCD, ARM, ACTARMCD, ACTARM,
    COUNTRY
  )

log_info("Generated {nrow(dm_domain)} DM records for {nrow(dm_domain)} subjects")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "dm_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    dm_domain, 
    path = output_path,
    label = "Demographics",
    domain = "DM"
  )
  log_info("✓ DM domain written: {output_path}")
} else {
  # Fallback to haven if xportr not available
  haven::write_xpt(dm_domain, output_path)
  log_info("✓ DM domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "dm_oak.csv")
write_csv(dm_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM DM Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(dm_domain)))
message(sprintf("Subjects: %d", nrow(dm_domain)))
message(sprintf("Output: %s", output_path))
message("========================================\n")
