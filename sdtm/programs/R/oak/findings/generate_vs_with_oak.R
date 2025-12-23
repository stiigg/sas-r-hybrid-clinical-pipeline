# Generate Vital Signs (VS) Domain using sdtm.oak
# Author: Christian Baghai
# Date: 2024-12-24
# Description: Findings domain implementation using sdtm.oak v0.2.0

# Load required packages
library(sdtm.oak)
library(dplyr)
library(logger)

# Source configuration
source(here::here("config", "paths.R"))
source(here::here("config", "controlled_terminology.R"))

log_info("Starting VS domain generation with sdtm.oak")

# Load raw vital signs data
# Using pharmaverseraw for initial implementation
library(pharmaverseraw)
vs_raw <- pharmaverseraw::vs_raw

log_info("Raw VS records loaded: {nrow(vs_raw)}")

# Step 1: Generate oak ID variables (REQUIRED FIRST STEP)
vs_raw <- vs_raw %>%
  generate_oak_id_vars(
    pat_var = "USUBJID",
    raw_src = "VS"
  )

# Step 2: Assign domain-specific variables
vs <- vs_raw %>%
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
    tgt_val = "VS"
  ) %>%
  # Subject identifier
  assign_no_ct(
    raw_dat = .,
    raw_var = "USUBJID",
    tgt_var = "USUBJID"
  ) %>%
  # Vital signs test code (with CT)
  assign_ct(
    raw_dat = .,
    raw_var = "VSTESTCD",
    tgt_var = "VSTESTCD",
    ct_spec = oak_ct_spec$vstestcd,
    ct_clst = "C67153"
  ) %>%
  # Vital signs test name (derived from test code)
  assign_ct(
    raw_dat = .,
    raw_var = "VSTESTCD",
    tgt_var = "VSTEST",
    ct_spec = oak_ct_spec$vstestcd,
    ct_clst = "C67153",
    id_vars = "collected_value"
  ) %>%
  # Original result as collected
  assign_no_ct(
    raw_dat = .,
    raw_var = "VSORRES",
    tgt_var = "VSORRES"
  ) %>%
  # Original units
  assign_ct(
    raw_dat = .,
    raw_var = "VSORRESU",
    tgt_var = "VSORRESU",
    ct_spec = oak_ct_spec$unit,
    ct_clst = "C71620"
  ) %>%
  # Standardized result (same as original for now)
  assign_no_ct(
    raw_dat = .,
    raw_var = "VSORRES",
    tgt_var = "VSSTRESC"
  ) %>%
  # Standardized numeric result
  mutate(
    VSSTRESN = as.numeric(VSSTRESC)
  ) %>%
  # Standardized units (same as original for now)
  assign_ct(
    raw_dat = .,
    raw_var = "VSORRESU",
    tgt_var = "VSSTRESU",
    ct_spec = oak_ct_spec$unit,
    ct_clst = "C71620"
  ) %>%
  # Visit name
  assign_no_ct(
    raw_dat = .,
    raw_var = "VISIT",
    tgt_var = "VISIT"
  ) %>%
  # Visit number
  assign_no_ct(
    raw_dat = .,
    raw_var = "VISITNUM",
    tgt_var = "VISITNUM"
  ) %>%
  # Date/time of vital signs collection
  assign_datetime(
    raw_dat = .,
    raw_var = "VSDTC",
    tgt_var = "VSDTC"
  ) %>%
  # Position during measurement
  assign_no_ct(
    raw_dat = .,
    raw_var = "VSPOS",
    tgt_var = "VSPOS"
  ) %>%
  # Location on body
  assign_no_ct(
    raw_dat = .,
    raw_var = "VSLOC",
    tgt_var = "VSLOC"
  )

# Step 3: Derive study day
# Note: Requires DM domain for reference start date
# For now, using placeholder logic
vs <- vs %>%
  mutate(
    VSDY = if_else(
      !is.na(VSDTC),
      as.integer(difftime(as.Date(substr(VSDTC, 1, 10)), 
                          as.Date("2024-01-01"), 
                          units = "days")) + 1,
      NA_integer_
    )
  )

# Step 4: Derive baseline flag
vs <- vs %>%
  group_by(USUBJID, VSTESTCD) %>%
  mutate(
    VSBLFL = if_else(
      VISIT %in% c("SCREENING", "BASELINE") & 
      VISITNUM == min(VISITNUM[VISIT %in% c("SCREENING", "BASELINE")], na.rm = TRUE),
      "Y",
      NA_character_
    )
  ) %>%
  ungroup()

# Step 5: Derive sequence number
vs <- vs %>%
  group_by(STUDYID, USUBJID) %>%
  mutate(VSSEQ = row_number()) %>%
  ungroup()

# Step 6: Select final variables in SDTM order
vs_final <- vs %>%
  select(
    STUDYID, DOMAIN, USUBJID, VSSEQ,
    VSTESTCD, VSTEST,
    VSORRES, VSORRESU, VSSTRESC, VSSTRESN, VSSTRESU,
    VISIT, VISITNUM, VSDTC, VSDY,
    VSPOS, VSLOC, VSBLFL
  ) %>%
  arrange(USUBJID, VSSEQ)

log_info("VS domain generated: {nrow(vs_final)} records")

# Step 7: Write outputs
dir.create(PATH_SDTM_XPT, showWarnings = FALSE, recursive = TRUE)
dir.create(PATH_SDTM_CSV, showWarnings = FALSE, recursive = TRUE)

# Write CSV
readr::write_csv(vs_final, file.path(PATH_SDTM_CSV, "vs.csv"))
log_info("VS CSV written to: {file.path(PATH_SDTM_CSV, 'vs.csv')}")

# Write XPT for regulatory submission
library(xportr)
xportr::xportr_write(
  vs_final,
  file.path(PATH_SDTM_XPT, "vs.xpt"),
  label = "Vital Signs",
  domain = "VS"
)
log_info("VS XPT written to: {file.path(PATH_SDTM_XPT, 'vs.xpt')}")

log_info("VS domain generation complete")
