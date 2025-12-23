#!/usr/bin/env Rscript
#=============================================================================
# SDTM MH DOMAIN GENERATION WITH sdtm.oak
# Medical History - Pre-existing conditions before study enrollment
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating MH domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw medical history data from demo
raw_mh_path <- here("demo", "data", "test_sdtm_mh.csv")

if (!file.exists(raw_mh_path)) {
  log_error("Demo data not found: {raw_mh_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  raw_medhist <- tibble(
    SUBJID = c("001", "001", "001", "002", "002", "003", "003", "003"),
    CONDITION = c(
      "Type 2 Diabetes Mellitus", "Hypertension", "Appendectomy",
      "Hypercholesterolemia", "Osteoarthritis",
      "Gastroesophageal Reflux Disease", "Benign Prostatic Hyperplasia", "Cataract Surgery"
    ),
    MH_DECODE = c(
      "TYPE 2 DIABETES MELLITUS", "HYPERTENSION", "APPENDICECTOMY",
      "HYPERCHOLESTEROLAEMIA", "OSTEOARTHRITIS",
      "GASTROOESOPHAGEAL REFLUX DISEASE", "PROSTATIC HYPERTROPHY BENIGN", "CATARACT OPERATION"
    ),
    CATEGORY = c(
      "GENERAL", "GENERAL", "SURGICAL HISTORY",
      "GENERAL", "GENERAL",
      "GENERAL", "GENERAL", "SURGICAL HISTORY"
    ),
    ONGOING = c("Y", "Y", "N", "Y", "Y", "Y", "Y", "N"),
    START_DATE = as.Date(c(
      "2015-06-01", "2018-03-15", "2010-08-20",
      "2019-11-01", "2020-05-10",
      "2017-02-14", "2021-09-30", "2022-04-12"
    )),
    END_DATE = as.Date(c(
      NA, NA, "2010-08-20",
      NA, NA,
      NA, NA, "2022-04-12"
    ))
  )
} else {
  raw_medhist <- read_csv(raw_mh_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_medhist)} records from demo data")
}

# Generate MH domain using sdtm.oak algorithms
mh_domain <- raw_medhist %>%
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
    tgt_val = "MH"
  ) %>%
  
  # Algorithm 4: Medical history term (verbatim)
  assign_no_ct(
    tgt_var = "MHTERM",
    tgt_val = CONDITION
  ) %>%
  
  # Algorithm 5: Medical history decoded term (MedDRA)
  assign_no_ct(
    tgt_var = "MHDECOD",
    tgt_val = MH_DECODE
  ) %>%
  
  # Algorithm 6: Category
  assign_no_ct(
    tgt_var = "MHCAT",
    tgt_val = CATEGORY
  ) %>%
  
  # Algorithm 7: Ongoing flag
  assign_no_ct(
    tgt_var = "MHONGO",
    tgt_val = ONGOING
  ) %>%
  
  # Algorithm 8: Start date
  assign_datetime(
    dtc_var = "MHSTDTC",
    dtm = START_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 9: End date
  assign_datetime(
    dtc_var = "MHENDTC",
    dtm = END_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(MHSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, MHSEQ,
    MHTERM, MHDECOD, MHCAT,
    MHONGO, MHSTDTC, MHENDTC
  )

log_info("Generated {nrow(mh_domain)} MH records for {length(unique(mh_domain$USUBJID))} subjects")
log_info("Ongoing conditions: {sum(mh_domain$MHONGO == 'Y')}")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "mh_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    mh_domain, 
    path = output_path,
    label = "Medical History",
    domain = "MH"
  )
  log_info("✓ MH domain written: {output_path}")
} else {
  haven::write_xpt(mh_domain, output_path)
  log_info("✓ MH domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "mh_oak.csv")
write_csv(mh_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM MH Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(mh_domain)))
message(sprintf("Subjects: %d", length(unique(mh_domain$USUBJID))))
message(sprintf("Ongoing: %d", sum(mh_domain$MHONGO == "Y")))
message(sprintf("Output: %s", output_path))
message("========================================\n")
