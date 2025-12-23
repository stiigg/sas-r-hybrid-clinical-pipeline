#!/usr/bin/env Rscript
#=============================================================================
# ADaM ADRS GENERATION WITH ADMIRAL/ADMIRALONCO
# Replaces manual RECIST derivation macros with validated algorithms
#=============================================================================

library(admiral)
library(admiralonco)
library(dplyr)
library(haven)
library(here)
library(logger)

log_info("Generating ADRS with admiral/admiralonco")

# Create output directory
dir.create(here("outputs", "adam"), recursive = TRUE, showWarnings = FALSE)

# Read SDTM domains
rs_path <- here("outputs", "sdtm", "rs_oak.xpt")

if (!file.exists(rs_path)) {
  log_error("RS domain not found. Run generate_rs_with_oak.R first.")
  stop("Missing RS domain")
}

rs <- read_xpt(rs_path) %>%
  convert_blanks_to_na()

log_info("Loaded {nrow(rs)} RS records")

# Create minimal ADSL for demo (normally would read from SDTM DM)
adsl <- rs %>%
  distinct(STUDYID, USUBJID) %>%
  mutate(
    TRTSDT = as.Date("2024-01-01"),
    TRTEDT = as.Date("2024-04-30"),
    TRT01A = "Investigational Drug",
    TRT01P = "Investigational Drug",
    AGE = 65,
    SEX = "M",
    RACE = "WHITE"
  )

log_info("Created ADSL for {nrow(adsl)} subjects")

# Create base ADRS from RS
adrs <- rs %>%
  # Derive standard admiral variables
  derive_vars_dt(
    new_vars_prefix = "A",
    dtc = RSDTC
  ) %>%
  
  # Merge ADSL variables
  derive_vars_merged(
    dataset_add = adsl,
    by_vars = exprs(STUDYID, USUBJID),
    new_vars = exprs(TRTSDT, TRTEDT, TRT01A, TRT01P)
  ) %>%
  
  # Derive analysis day
  derive_vars_dy(
    reference_date = TRTSDT,
    source_vars = exprs(ADT)
  ) %>%
  
  # Derive analysis value from character result
  mutate(
    AVAL = case_when(
      RSSTRESC == "CR" ~ 1,
      RSSTRESC == "PR" ~ 2,
      RSSTRESC == "SD" ~ 3,
      RSSTRESC == "PD" ~ 4,
      RSSTRESC == "NE" ~ 5,
      TRUE ~ NA_real_
    ),
    AVALC = RSSTRESC,
    PARAMCD = "OVR",
    PARAM = "Overall Response by Investigator",
    PARCAT1 = "Tumor Response",
    AVISIT = VISIT,
    AVISITN = VISITNUM
  )

log_info("Created base ADRS with {nrow(adrs)} records")

# Derive Best Overall Response using admiralonco
# This replaces your derive_best_overall_response.sas macro
log_info("Deriving Best Overall Response with admiralonco...")

adrs_bor <- adrs %>%
  derive_param_bor(
    dataset_adsl = adsl,
    filter_source = PARAMCD == "OVR",
    source_pd = AVALC == "PD",
    source_cr = AVALC == "CR",
    source_pr = AVALC == "PR",
    source_sd = AVALC == "SD",
    source_ne = AVALC == "NE",
    reference_date = TRTSDT,
    ref_start_window = 28,
    set_values_to = exprs(
      PARAMCD = "BOR",
      PARAM = "Best Overall Response",
      PARCAT1 = "Tumor Response",
      AVISIT = "Overall"
    )
  )

log_info("Derived BOR for {nrow(adrs_bor)} records")

# Derive confirmed response
log_info("Deriving Confirmed Response...")

adrs_confirmed <- adrs %>%
  derive_param_confirmed_resp(
    dataset_adsl = adsl,
    filter_source = PARAMCD == "OVR",
    source_pd = AVALC == "PD",
    source_cr = AVALC == "CR",
    source_pr = AVALC == "PR",
    source_sd = AVALC == "SD",
    source_ne = AVALC == "NE",
    reference_date = TRTSDT,
    ref_confirm = 28,
    set_values_to = exprs(
      PARAMCD = "CBOR",
      PARAM = "Best Confirmed Overall Response",
      PARCAT1 = "Tumor Response",
      AVISIT = "Overall"
    )
  )

log_info("Derived confirmed response for {nrow(adrs_confirmed)} records")

# Combine all response parameters
adrs_final <- bind_rows(adrs, adrs_bor, adrs_confirmed) %>%
  arrange(USUBJID, PARAMCD, ADY) %>%
  group_by(USUBJID) %>%
  mutate(ASEQ = row_number()) %>%
  ungroup()

log_info("Final ADRS: {nrow(adrs_final)} records")

# Write ADaM dataset
output_path <- here("outputs", "adam", "adrs_admiral.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    adrs_final,
    path = output_path,
    label = "Response Analysis Dataset",
    domain = "ADRS"
  )
  log_info("✓ ADRS written: {output_path}")
} else {
  write_xpt(adrs_final, output_path)
  log_info("✓ ADRS written (haven): {output_path}")
}

# Also save CSV
csv_path <- here("outputs", "adam", "adrs_admiral.csv")
write_csv(adrs_final, csv_path)
log_info("✓ CSV version saved: {csv_path}")

# Save ADSL too
adsl_path <- here("outputs", "adam", "adsl.xpt")
write_xpt(adsl, adsl_path)
log_info("✓ ADSL written: {adsl_path}")

message("\n========================================")
message("ADaM ADRS Generation Complete")
message("========================================")
message(sprintf("Total records: %d", nrow(adrs_final)))
message(sprintf("Subjects: %d", length(unique(adrs_final$USUBJID))))
message(sprintf("Parameters: %s", paste(unique(adrs_final$PARAMCD), collapse = ", ")))
message(sprintf("Output: %s", output_path))
message("========================================\n")
