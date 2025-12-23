#!/usr/bin/env Rscript
#=============================================================================
# SDTM VS DOMAIN GENERATION WITH sdtm.oak
# Vital Signs - Blood pressure, temperature, pulse, weight, height
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating VS domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw vital signs data from demo
raw_vs_path <- here("demo", "data", "test_sdtm_vs.csv")

if (!file.exists(raw_vs_path)) {
  log_error("Demo data not found: {raw_vs_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  # Common vital signs across 3 subjects, 4 visits
  vital_panel <- expand.grid(
    SUBJID = c("001", "002", "003"),
    VISIT_NUM = 1:4,
    TEST_CODE = c("SYSBP", "DIABP", "PULSE", "TEMP", "WEIGHT", "HEIGHT"),
    stringsAsFactors = FALSE
  ) %>%
    as_tibble() %>%
    mutate(
      VISIT = case_when(
        VISIT_NUM == 1 ~ "Baseline",
        VISIT_NUM == 2 ~ "Week 4",
        VISIT_NUM == 3 ~ "Week 8",
        VISIT_NUM == 4 ~ "Week 12"
      ),
      TEST_NAME = case_when(
        TEST_CODE == "SYSBP" ~ "Systolic Blood Pressure",
        TEST_CODE == "DIABP" ~ "Diastolic Blood Pressure",
        TEST_CODE == "PULSE" ~ "Pulse Rate",
        TEST_CODE == "TEMP" ~ "Temperature",
        TEST_CODE == "WEIGHT" ~ "Weight",
        TEST_CODE == "HEIGHT" ~ "Height"
      ),
      UNIT = case_when(
        TEST_CODE == "SYSBP" ~ "mmHg",
        TEST_CODE == "DIABP" ~ "mmHg",
        TEST_CODE == "PULSE" ~ "beats/min",
        TEST_CODE == "TEMP" ~ "C",
        TEST_CODE == "WEIGHT" ~ "kg",
        TEST_CODE == "HEIGHT" ~ "cm"
      ),
      POSITION = case_when(
        TEST_CODE %in% c("SYSBP", "DIABP", "PULSE") ~ "SITTING",
        TRUE ~ NA_character_
      ),
      LOCATION = case_when(
        TEST_CODE %in% c("SYSBP", "DIABP") ~ "ARM",
        TEST_CODE == "TEMP" ~ "ORAL",
        TRUE ~ NA_character_
      ),
      # Generate realistic random values
      RESULT = case_when(
        TEST_CODE == "SYSBP" ~ round(runif(n(), 110, 140), 0),
        TEST_CODE == "DIABP" ~ round(runif(n(), 70, 90), 0),
        TEST_CODE == "PULSE" ~ round(runif(n(), 60, 90), 0),
        TEST_CODE == "TEMP" ~ round(runif(n(), 36.2, 37.4), 1),
        TEST_CODE == "WEIGHT" ~ round(runif(n(), 65, 85), 1),
        TEST_CODE == "HEIGHT" ~ round(runif(n(), 165, 180), 0)
      ),
      VISIT_DATE = as.Date("2024-01-01") + (VISIT_NUM - 1) * 28 + 
        as.numeric(factor(SUBJID)) - 1
    )
  
  # Height only measured at baseline
  raw_vitals <- vital_panel %>%
    filter(!(TEST_CODE == "HEIGHT" & VISIT_NUM > 1))
  
} else {
  raw_vitals <- read_csv(raw_vs_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_vitals)} records from demo data")
}

# Generate VS domain using sdtm.oak algorithms
vs_domain <- raw_vitals %>%
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
    tgt_val = "VS"
  ) %>%
  
  # Algorithm 4: Vital sign test codes
  assign_no_ct(
    tgt_var = "VSTESTCD",
    tgt_val = TEST_CODE
  ) %>%
  assign_no_ct(
    tgt_var = "VSTEST",
    tgt_val = TEST_NAME
  ) %>%
  
  # Algorithm 5: Original result
  assign_no_ct(
    tgt_var = "VSORRES",
    tgt_val = as.character(RESULT)
  ) %>%
  assign_no_ct(
    tgt_var = "VSORRESU",
    tgt_val = UNIT
  ) %>%
  
  # Algorithm 6: Standardized result
  assign_no_ct(
    tgt_var = "VSSTRESC",
    tgt_val = as.character(RESULT)
  ) %>%
  assign_no_ct(
    tgt_var = "VSSTRESN",
    tgt_val = RESULT
  ) %>%
  assign_no_ct(
    tgt_var = "VSSTRESU",
    tgt_val = UNIT
  ) %>%
  
  # Algorithm 7: Position
  assign_no_ct(
    tgt_var = "VSPOS",
    tgt_val = POSITION
  ) %>%
  
  # Algorithm 8: Location
  assign_no_ct(
    tgt_var = "VSLOC",
    tgt_val = LOCATION
  ) %>%
  
  # Algorithm 9: Visit information
  assign_no_ct(
    tgt_var = "VISITNUM",
    tgt_val = VISIT_NUM
  ) %>%
  assign_no_ct(
    tgt_var = "VISIT",
    tgt_val = VISIT
  ) %>%
  
  # Algorithm 10: Assessment date
  assign_datetime(
    dtc_var = "VSDTC",
    dtm = VISIT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 11: Baseline flag (first visit)
  mutate(
    VSBLFL = if_else(VISIT_NUM == 1, "Y", NA_character_)
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(VSSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, VSSEQ,
    VSTESTCD, VSTEST,
    VSORRES, VSORRESU, VSSTRESC, VSSTRESN, VSSTRESU,
    VSPOS, VSLOC,
    VISITNUM, VISIT, VSDTC, VSBLFL
  )

log_info("Generated {nrow(vs_domain)} VS records for {length(unique(vs_domain$USUBJID))} subjects")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "vs_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    vs_domain, 
    path = output_path,
    label = "Vital Signs",
    domain = "VS"
  )
  log_info("✓ VS domain written: {output_path}")
} else {
  haven::write_xpt(vs_domain, output_path)
  log_info("✓ VS domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "vs_oak.csv")
write_csv(vs_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM VS Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(vs_domain)))
message(sprintf("Subjects: %d", length(unique(vs_domain$USUBJID))))
message(sprintf("Tests: %d unique vital signs", length(unique(vs_domain$VSTESTCD))))
message(sprintf("Output: %s", output_path))
message("========================================\n")
