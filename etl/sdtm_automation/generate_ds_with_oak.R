#!/usr/bin/env Rscript
#=============================================================================
# SDTM DS DOMAIN GENERATION WITH sdtm.oak
# Disposition - Subject progression and study completion status (REQUIRED)
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating DS domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw disposition data from demo
raw_ds_path <- here("demo", "data", "test_sdtm_ds.csv")

if (!file.exists(raw_ds_path)) {
  log_error("Demo data not found: {raw_ds_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  raw_disposition <- tibble(
    SUBJID = c("001", "001", "001", "002", "002", "002", "002", "003", "003", "003"),
    DSEVENT = c(
      "INFORMED CONSENT OBTAINED", "RANDOMIZED", "COMPLETED",
      "INFORMED CONSENT OBTAINED", "RANDOMIZED", "DISCONTINUED", "ADVERSE EVENT",
      "INFORMED CONSENT OBTAINED", "RANDOMIZED", "COMPLETED"
    ),
    DSDECOD = c(
      "INFORMED CONSENT OBTAINED", "RANDOMIZED", "COMPLETED",
      "INFORMED CONSENT OBTAINED", "RANDOMIZED", "DISCONTINUED", "ADVERSE EVENT",
      "INFORMED CONSENT OBTAINED", "RANDOMIZED", "COMPLETED"
    ),
    DSCAT = c(
      "PROTOCOL MILESTONE", "PROTOCOL MILESTONE", "DISPOSITION EVENT",
      "PROTOCOL MILESTONE", "PROTOCOL MILESTONE", "DISPOSITION EVENT", "DISPOSITION EVENT",
      "PROTOCOL MILESTONE", "PROTOCOL MILESTONE", "DISPOSITION EVENT"
    ),
    DSSCAT = c(
      NA, NA, NA,
      NA, NA, "STUDY TREATMENT", "STUDY TREATMENT",
      NA, NA, NA
    ),
    EVENT_DATE = as.Date(c(
      "2023-12-28", "2024-01-01", "2024-04-01",
      "2024-01-02", "2024-01-05", "2024-02-15", "2024-02-15",
      "2023-12-30", "2024-01-03", "2024-04-05"
    ))
  )
} else {
  raw_disposition <- read_csv(raw_ds_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_disposition)} records from demo data")
}

# Generate DS domain using sdtm.oak algorithms
ds_domain <- raw_disposition %>%
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
    tgt_val = "DS"
  ) %>%
  
  # Algorithm 4: Disposition term (verbatim)
  assign_no_ct(
    tgt_var = "DSTERM",
    tgt_val = DSEVENT
  ) %>%
  
  # Algorithm 5: Disposition decoded term (standardized)
  assign_no_ct(
    tgt_var = "DSDECOD",
    tgt_val = DSDECOD
  ) %>%
  
  # Algorithm 6: Category
  assign_no_ct(
    tgt_var = "DSCAT",
    tgt_val = DSCAT
  ) %>%
  
  # Algorithm 7: Subcategory
  assign_no_ct(
    tgt_var = "DSSCAT",
    tgt_val = DSSCAT
  ) %>%
  
  # Algorithm 8: Event date
  assign_datetime(
    dtc_var = "DSSTDTC",
    dtm = EVENT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(DSSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ,
    DSTERM, DSDECOD, DSCAT, DSSCAT,
    DSSTDTC
  )

log_info("Generated {nrow(ds_domain)} DS records for {length(unique(ds_domain$USUBJID))} subjects")

# Calculate summary statistics
completers <- ds_domain %>% filter(DSDECOD == "COMPLETED") %>% nrow()
discontinued <- ds_domain %>% filter(DSDECOD == "DISCONTINUED") %>% nrow()

log_info("Completers: {completers}, Discontinued: {discontinued}")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "ds_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    ds_domain, 
    path = output_path,
    label = "Disposition",
    domain = "DS"
  )
  log_info("✓ DS domain written: {output_path}")
} else {
  haven::write_xpt(ds_domain, output_path)
  log_info("✓ DS domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "ds_oak.csv")
write_csv(ds_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM DS Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(ds_domain)))
message(sprintf("Subjects: %d", length(unique(ds_domain$USUBJID))))
message(sprintf("Completers: %d", completers))
message(sprintf("Discontinued: %d", discontinued))
message(sprintf("Output: %s", output_path))
message("========================================\n")
