# Generate Demographics (DM) Domain using sdtm.oak
# Author: Christian Baghai
# Date: 2024-12-24
# Description: Foundation domain implementation using sdtm.oak v0.2.0

# Load required packages
library(sdtm.oak)
library(dplyr)
library(logger)

# Source configuration
source(here::here("config", "paths.R"))
source(here::here("config", "controlled_terminology.R"))

log_info("Starting DM domain generation with sdtm.oak")

# Load raw demographics data
# Using pharmaverseraw for initial implementation
library(pharmaverseraw)
dm_raw <- pharmaverseraw::dm_raw

log_info("Raw DM records loaded: {nrow(dm_raw)}")

# Step 1: Generate oak ID variables (REQUIRED FIRST STEP)
dm_raw <- dm_raw %>%
  generate_oak_id_vars(
    pat_var = "USUBJID",
    raw_src = "DM"
  )

# Step 2: Assign domain-specific variables
dm <- dm_raw %>%
  # Study identifier
  hardcode_ct(
    raw_dat = .,
    raw_var = "STUDYID",
    tgt_var = "STUDYID",
    ct_spec = oak_ct_spec$studyid,
    ct_clst = "STUDYID"
  ) %>%
  # Domain code
  hardcode_no_ct(
    raw_dat = .,
    raw_var = NULL,
    tgt_var = "DOMAIN",
    tgt_val = "DM"
  ) %>%
  # Subject identifier
  assign_no_ct(
    raw_dat = .,
    raw_var = "USUBJID",
    tgt_var = "USUBJID"
  ) %>%
  # Site identifier  
  assign_no_ct(
    raw_dat = .,
    raw_var = "SITEID",
    tgt_var = "SITEID"
  ) %>%
  # Subject ID within site
  assign_no_ct(
    raw_dat = .,
    raw_var = "SUBJID",
    tgt_var = "SUBJID"
  ) %>%
  # Reference start date
  assign_datetime(
    raw_dat = .,
    raw_var = "RFSTDTC",
    tgt_var = "RFSTDTC"
  ) %>%
  # Reference end date
  assign_datetime(
    raw_dat = .,
    raw_var = "RFENDTC",
    tgt_var = "RFENDTC"
  ) %>%
  # Birth year
  assign_no_ct(
    raw_dat = .,
    raw_var = "BRTHDTC",
    tgt_var = "BRTHDTC"
  ) %>%
  # Age
  assign_no_ct(
    raw_dat = .,
    raw_var = "AGE",
    tgt_var = "AGE"
  ) %>%
  # Age units
  hardcode_ct(
    raw_dat = .,
    raw_var = "AGEU",
    tgt_var = "AGEU",
    ct_spec = oak_ct_spec$ageu,
    ct_clst = "C66781"
  ) %>%
  # Sex
  assign_ct(
    raw_dat = .,
    raw_var = "SEX",
    tgt_var = "SEX",
    ct_spec = oak_ct_spec$sex,
    ct_clst = "C66731"
  ) %>%
  # Race
  assign_ct(
    raw_dat = .,
    raw_var = "RACE",
    tgt_var = "RACE",
    ct_spec = oak_ct_spec$race,
    ct_clst = "C74457"
  ) %>%
  # Ethnicity
  assign_ct(
    raw_dat = .,
    raw_var = "ETHNIC",
    tgt_var = "ETHNIC",
    ct_spec = oak_ct_spec$ethnic,
    ct_clst = "C66790"
  ) %>%
  # Country
  assign_ct(
    raw_dat = .,
    raw_var = "COUNTRY",
    tgt_var = "COUNTRY",
    ct_spec = oak_ct_spec$country,
    ct_clst = "C66789"
  ) %>%
  # Planned ARM
  assign_no_ct(
    raw_dat = .,
    raw_var = "ARMCD",
    tgt_var = "ARMCD"
  ) %>%
  # ARM description
  assign_no_ct(
    raw_dat = .,
    raw_var = "ARM",
    tgt_var = "ARM"
  ) %>%
  # Actual ARM code
  assign_no_ct(
    raw_dat = .,
    raw_var = "ACTARMCD",
    tgt_var = "ACTARMCD"
  ) %>%
  # Actual ARM
  assign_no_ct(
    raw_dat = .,
    raw_var = "ACTARM",
    tgt_var = "ACTARM"
  )

# Step 3: Select final variables in SDTM order
dm_final <- dm %>%
  select(
    STUDYID, DOMAIN, USUBJID, SUBJID, SITEID,
    RFSTDTC, RFENDTC, BRTHDTC, AGE, AGEU,
    SEX, RACE, ETHNIC, COUNTRY,
    ARMCD, ARM, ACTARMCD, ACTARM
  ) %>%
  arrange(USUBJID)

log_info("DM domain generated: {nrow(dm_final)} records")

# Step 4: Write outputs
# Create output directories if they don't exist
dir.create(PATH_SDTM_XPT, showWarnings = FALSE, recursive = TRUE)
dir.create(PATH_SDTM_CSV, showWarnings = FALSE, recursive = TRUE)

# Write CSV
readr::write_csv(dm_final, file.path(PATH_SDTM_CSV, "dm.csv"))
log_info("DM CSV written to: {file.path(PATH_SDTM_CSV, 'dm.csv')}")

# Write XPT for regulatory submission
library(xportr)
xportr::xportr_write(
  dm_final,
  file.path(PATH_SDTM_XPT, "dm.xpt"),
  label = "Demographics",
  domain = "DM"
)
log_info("DM XPT written to: {file.path(PATH_SDTM_XPT, 'dm.xpt')}")

log_info("DM domain generation complete")
