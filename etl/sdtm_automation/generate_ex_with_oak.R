#!/usr/bin/env Rscript
#=============================================================================
# SDTM EX DOMAIN GENERATION WITH sdtm.oak
# Exposure - Study drug administration records
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating EX domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw exposure data from demo
raw_ex_path <- here("demo", "data", "test_sdtm_ex.csv")

if (!file.exists(raw_ex_path)) {
  log_error("Demo data not found: {raw_ex_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  raw_exposure <- tibble(
    SUBJID = rep(c("001", "002", "003"), each = 3),
    TREATMENT = c(rep("Drug A", 3), rep("Drug A", 3), rep("Placebo", 3)),
    DOSE = c(100, 100, 100, 100, 50, 0, 0, 0, 0),
    DOSE_UNIT = rep("mg", 9),
    DOSE_FORM = rep("TABLET", 9),
    ROUTE = rep("ORAL", 9),
    FREQUENCY = rep("QD", 9),
    START_DATE = as.Date(c(
      "2024-01-01", "2024-01-29", "2024-02-26",
      "2024-01-05", "2024-02-02", "2024-03-02",
      "2024-01-03", "2024-01-31", "2024-02-28"
    )),
    END_DATE = as.Date(c(
      "2024-01-28", "2024-02-25", "2024-03-25",
      "2024-02-01", "2024-02-29", "2024-03-29",
      "2024-01-30", "2024-02-27", "2024-03-27"
    ))
  )
} else {
  raw_exposure <- read_csv(raw_ex_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_exposure)} records from demo data")
}

# Generate EX domain using sdtm.oak algorithms
ex_domain <- raw_exposure %>%
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
    tgt_val = "EX"
  ) %>%
  
  # Algorithm 4: Treatment name
  assign_no_ct(
    tgt_var = "EXTRT",
    tgt_val = TREATMENT
  ) %>%
  
  # Algorithm 5: Dose administered
  assign_no_ct(
    tgt_var = "EXDOSE",
    tgt_val = DOSE
  ) %>%
  
  # Algorithm 6: Dose units
  assign_no_ct(
    tgt_var = "EXDOSU",
    tgt_val = DOSE_UNIT
  ) %>%
  
  # Algorithm 7: Dose form
  assign_no_ct(
    tgt_var = "EXDOSFRM",
    tgt_val = DOSE_FORM
  ) %>%
  
  # Algorithm 8: Route of administration
  assign_no_ct(
    tgt_var = "EXROUTE",
    tgt_val = ROUTE
  ) %>%
  
  # Algorithm 9: Dosing frequency
  assign_no_ct(
    tgt_var = "EXDOSFRQ",
    tgt_val = FREQUENCY
  ) %>%
  
  # Algorithm 10: Start date
  assign_datetime(
    dtc_var = "EXSTDTC",
    dtm = START_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 11: End date
  assign_datetime(
    dtc_var = "EXENDTC",
    dtm = END_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(EXSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, EXSEQ,
    EXTRT, EXDOSE, EXDOSU, EXDOSFRM, EXROUTE, EXDOSFRQ,
    EXSTDTC, EXENDTC
  )

log_info("Generated {nrow(ex_domain)} EX records for {length(unique(ex_domain$USUBJID))} subjects")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "ex_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    ex_domain, 
    path = output_path,
    label = "Exposure",
    domain = "EX"
  )
  log_info("✓ EX domain written: {output_path}")
} else {
  haven::write_xpt(ex_domain, output_path)
  log_info("✓ EX domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "ex_oak.csv")
write_csv(ex_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM EX Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(ex_domain)))
message(sprintf("Subjects: %d", length(unique(ex_domain$USUBJID))))
message(sprintf("Output: %s", output_path))
message("========================================\n")
