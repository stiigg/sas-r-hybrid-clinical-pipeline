# Generate Adverse Events (AE) Domain using sdtm.oak
# Author: Christian Baghai
# Date: 2024-12-24
# Description: Events domain implementation using sdtm.oak v0.2.0

# Load required packages
library(sdtm.oak)
library(dplyr)
library(logger)

# Source configuration
source(here::here("config", "paths.R"))
source(here::here("config", "controlled_terminology.R"))

log_info("Starting AE domain generation with sdtm.oak")

# Load raw adverse events data
# Using pharmaverseraw for initial implementation
library(pharmaverseraw)
ae_raw <- pharmaverseraw::ae_raw

log_info("Raw AE records loaded: {nrow(ae_raw)}")

# Step 1: Generate oak ID variables (REQUIRED FIRST STEP)
ae_raw <- ae_raw %>%
  generate_oak_id_vars(
    pat_var = "USUBJID",
    raw_src = "AE"
  )

# Step 2: Assign domain-specific variables
ae <- ae_raw %>%
  # Study identifier
  assign_no_ct(
    raw_dat = .,
    raw_var = "STUDYID",
    tgt_var = "STUDYID"
  ) %>%
  # Domain code
  hardcode_no_ct(
    raw_dat = .,
    raw_var = NULL,
    tgt_var = "DOMAIN",
    tgt_val = "AE"
  ) %>%
  # Subject identifier
  assign_no_ct(
    raw_dat = .,
    raw_var = "USUBJID",
    tgt_var = "USUBJID"
  ) %>%
  # Adverse event term (verbatim)
  assign_no_ct(
    raw_dat = .,
    raw_var = "AETERM",
    tgt_var = "AETERM"
  ) %>%
  # Modified term (if available)
  assign_no_ct(
    raw_dat = .,
    raw_var = "AEMODIFY",
    tgt_var = "AEMODIFY"
  ) %>%
  # Preferred term (MedDRA/WHODrug coded term)
  assign_no_ct(
    raw_dat = .,
    raw_var = "AEDECOD",
    tgt_var = "AEDECOD"
  ) %>%
  # Severity/Intensity
  assign_ct(
    raw_dat = .,
    raw_var = "AESEV",
    tgt_var = "AESEV",
    ct_spec = oak_ct_spec$aesev,
    ct_clst = "C66769"
  ) %>%
  # Serious event flag
  assign_ct(
    raw_dat = .,
    raw_var = "AESER",
    tgt_var = "AESER",
    ct_spec = oak_ct_spec$ny,
    ct_clst = "C66742"
  ) %>%
  # Action taken with study treatment
  assign_no_ct(
    raw_dat = .,
    raw_var = "AEACN",
    tgt_var = "AEACN"
  ) %>%
  # Relationship to study treatment
  assign_no_ct(
    raw_dat = .,
    raw_var = "AEREL",
    tgt_var = "AEREL"
  ) %>%
  # Outcome of adverse event
  assign_no_ct(
    raw_dat = .,
    raw_var = "AEOUT",
    tgt_var = "AEOUT"
  ) %>%
  # Start date/time
  assign_datetime(
    raw_dat = .,
    raw_var = "AESTDTC",
    tgt_var = "AESTDTC"
  ) %>%
  # End date/time
  assign_datetime(
    raw_dat = .,
    raw_var = "AEENDTC",
    tgt_var = "AEENDTC"
  )

# Step 3: Derive study day for start and end
# Note: Requires DM domain for reference start date
# Using placeholder logic for now
ae <- ae %>%
  mutate(
    AESTDY = if_else(
      !is.na(AESTDTC),
      as.integer(difftime(as.Date(substr(AESTDTC, 1, 10)), 
                          as.Date("2024-01-01"), 
                          units = "days")) + 1,
      NA_integer_
    ),
    AEENDY = if_else(
      !is.na(AEENDTC),
      as.integer(difftime(as.Date(substr(AEENDTC, 1, 10)), 
                          as.Date("2024-01-01"), 
                          units = "days")) + 1,
      NA_integer_
    )
  )

# Step 4: Derive duration
ae <- ae %>%
  mutate(
    AEDUR = if_else(
      !is.na(AESTDTC) & !is.na(AEENDTC),
      as.integer(difftime(as.Date(substr(AEENDTC, 1, 10)),
                          as.Date(substr(AESTDTC, 1, 10)),
                          units = "days")) + 1,
      NA_integer_
    )
  )

# Step 5: Derive sequence number
ae <- ae %>%
  group_by(STUDYID, USUBJID) %>%
  mutate(AESEQ = row_number()) %>%
  ungroup()

# Step 6: Select final variables in SDTM order
ae_final <- ae %>%
  select(
    STUDYID, DOMAIN, USUBJID, AESEQ,
    AETERM, AEMODIFY, AEDECOD,
    AESEV, AESER, AEACN, AEREL, AEOUT,
    AESTDTC, AEENDTC, AESTDY, AEENDY, AEDUR
  ) %>%
  arrange(USUBJID, AESEQ)

log_info("AE domain generated: {nrow(ae_final)} records")

# Step 7: Write outputs
dir.create(PATH_SDTM_XPT, showWarnings = FALSE, recursive = TRUE)
dir.create(PATH_SDTM_CSV, showWarnings = FALSE, recursive = TRUE)

# Write CSV
readr::write_csv(ae_final, file.path(PATH_SDTM_CSV, "ae.csv"))
log_info("AE CSV written to: {file.path(PATH_SDTM_CSV, 'ae.csv')}")

# Write XPT for regulatory submission
library(xportr)
xportr::xportr_write(
  ae_final,
  file.path(PATH_SDTM_XPT, "ae.xpt"),
  label = "Adverse Events",
  domain = "AE"
)
log_info("AE XPT written to: {file.path(PATH_SDTM_XPT, 'ae.xpt')}")

log_info("AE domain generation complete")
