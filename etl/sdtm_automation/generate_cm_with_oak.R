#!/usr/bin/env Rscript
#=============================================================================
# SDTM CM DOMAIN GENERATION WITH sdtm.oak
# Concomitant Medications - Non-study drugs taken during trial
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating CM domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw concomitant medication data from demo
raw_cm_path <- here("demo", "data", "test_sdtm_cm.csv")

if (!file.exists(raw_cm_path)) {
  log_error("Demo data not found: {raw_cm_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  raw_conmeds <- tibble(
    SUBJID = c("001", "001", "001", "002", "002", "003", "003"),
    MEDICATION = c("Aspirin", "Metformin", "Lisinopril", 
                   "Ibuprofen", "Simvastatin", 
                   "Omeprazole", "Atorvastatin"),
    MED_DECODE = c("ASPIRIN", "METFORMIN", "LISINOPRIL",
                   "IBUPROFEN", "SIMVASTATIN",
                   "OMEPRAZOLE", "ATORVASTATIN"),
    INDICATION = c("CARDIOVASCULAR PROPHYLAXIS", "TYPE 2 DIABETES MELLITUS", "HYPERTENSION",
                   "PAIN", "HYPERCHOLESTEROLEMIA",
                   "GASTROESOPHAGEAL REFLUX", "HYPERCHOLESTEROLEMIA"),
    DOSE = c(81, 500, 10, 400, 20, 20, 40),
    DOSE_UNIT = c("mg", "mg", "mg", "mg", "mg", "mg", "mg"),
    DOSE_FORM = c("TABLET", "TABLET", "TABLET", "TABLET", "TABLET", "CAPSULE", "TABLET"),
    ROUTE = rep("ORAL", 7),
    FREQUENCY = c("QD", "BID", "QD", "PRN", "QD", "QD", "QD"),
    ONGOING = c("Y", "Y", "Y", "N", "Y", "Y", "Y"),
    START_DATE = as.Date(c(
      "2023-01-01", "2022-06-15", "2023-03-01",
      "2024-01-15", "2023-11-01",
      "2023-08-01", "2022-12-01"
    )),
    END_DATE = as.Date(c(
      NA, NA, NA,
      "2024-01-20", NA,
      NA, NA
    ))
  )
} else {
  raw_conmeds <- read_csv(raw_cm_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_conmeds)} records from demo data")
}

# Generate CM domain using sdtm.oak algorithms
cm_domain <- raw_conmeds %>%
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
    tgt_val = "CM"
  ) %>%
  
  # Algorithm 4: Medication name (verbatim)
  assign_no_ct(
    tgt_var = "CMTRT",
    tgt_val = MEDICATION
  ) %>%
  
  # Algorithm 5: Medication decoded term (WHODrug)
  assign_no_ct(
    tgt_var = "CMDECOD",
    tgt_val = MED_DECODE
  ) %>%
  
  # Algorithm 6: Indication
  assign_no_ct(
    tgt_var = "CMINDC",
    tgt_val = INDICATION
  ) %>%
  
  # Algorithm 7: Dose
  assign_no_ct(
    tgt_var = "CMDOSE",
    tgt_val = DOSE
  ) %>%
  
  # Algorithm 8: Dose unit
  assign_no_ct(
    tgt_var = "CMDOSU",
    tgt_val = DOSE_UNIT
  ) %>%
  
  # Algorithm 9: Dose form
  assign_no_ct(
    tgt_var = "CMDOSFRM",
    tgt_val = DOSE_FORM
  ) %>%
  
  # Algorithm 10: Route of administration
  assign_no_ct(
    tgt_var = "CMROUTE",
    tgt_val = ROUTE
  ) %>%
  
  # Algorithm 11: Dosing frequency
  assign_no_ct(
    tgt_var = "CMDOSFRQ",
    tgt_val = FREQUENCY
  ) %>%
  
  # Algorithm 12: Ongoing flag
  assign_no_ct(
    tgt_var = "CMONGO",
    tgt_val = ONGOING
  ) %>%
  
  # Algorithm 13: Start date
  assign_datetime(
    dtc_var = "CMSTDTC",
    dtm = START_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 14: End date
  assign_datetime(
    dtc_var = "CMENDTC",
    dtm = END_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(CMSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, CMSEQ,
    CMTRT, CMDECOD, CMINDC,
    CMDOSE, CMDOSU, CMDOSFRM, CMROUTE, CMDOSFRQ,
    CMONGO, CMSTDTC, CMENDTC
  )

log_info("Generated {nrow(cm_domain)} CM records for {length(unique(cm_domain$USUBJID))} subjects")
log_info("Ongoing medications: {sum(cm_domain$CMONGO == 'Y')}")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "cm_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    cm_domain, 
    path = output_path,
    label = "Concomitant Medications",
    domain = "CM"
  )
  log_info("✓ CM domain written: {output_path}")
} else {
  haven::write_xpt(cm_domain, output_path)
  log_info("✓ CM domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "cm_oak.csv")
write_csv(cm_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM CM Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(cm_domain)))
message(sprintf("Subjects: %d", length(unique(cm_domain$USUBJID))))
message(sprintf("Ongoing: %d", sum(cm_domain$CMONGO == "Y")))
message(sprintf("Output: %s", output_path))
message("========================================\n")
