#!/usr/bin/env Rscript
#=============================================================================
# SDTM EG DOMAIN GENERATION WITH sdtm.oak
# ECG Tests - Electrocardiogram measurements for cardiac safety
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating EG domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw ECG data from demo
raw_eg_path <- here("demo", "data", "test_sdtm_eg.csv")

if (!file.exists(raw_eg_path)) {
  log_error("Demo data not found: {raw_eg_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  # ECG parameters across 3 subjects, 4 visits
  ecg_panel <- expand.grid(
    SUBJID = c("001", "002", "003"),
    VISIT_NUM = 1:4,
    TEST_CODE = c("HR", "QT", "QTCF", "QTCB", "PR", "QRS", "RR"),
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
        TEST_CODE == "HR" ~ "Heart Rate",
        TEST_CODE == "QT" ~ "QT Interval",
        TEST_CODE == "QTCF" ~ "QTcF Corrected QT Interval",
        TEST_CODE == "QTCB" ~ "QTcB Corrected QT Interval",
        TEST_CODE == "PR" ~ "PR Interval",
        TEST_CODE == "QRS" ~ "QRS Duration",
        TEST_CODE == "RR" ~ "RR Interval"
      ),
      UNIT = case_when(
        TEST_CODE == "HR" ~ "beats/min",
        TRUE ~ "msec"
      ),
      # Generate realistic random values
      RESULT = case_when(
        TEST_CODE == "HR" ~ round(runif(n(), 60, 85), 0),
        TEST_CODE == "QT" ~ round(runif(n(), 360, 440), 0),
        TEST_CODE == "QTCF" ~ round(runif(n(), 380, 450), 0),
        TEST_CODE == "QTCB" ~ round(runif(n(), 385, 455), 0),
        TEST_CODE == "PR" ~ round(runif(n(), 120, 200), 0),
        TEST_CODE == "QRS" ~ round(runif(n(), 80, 120), 0),
        TEST_CODE == "RR" ~ round(runif(n(), 700, 1000), 0)
      ),
      POSITION = "SUPINE",
      METHOD = "12-LEAD ECG",
      EVALUATOR = case_when(
        VISIT_NUM <= 2 ~ "INVESTIGATOR",
        TRUE ~ "CENTRAL READER"
      ),
      VISIT_DATE = as.Date("2024-01-01") + (VISIT_NUM - 1) * 28 + 
        as.numeric(factor(SUBJID)) - 1
    )
  
  raw_ecg <- ecg_panel
  
} else {
  raw_ecg <- read_csv(raw_eg_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_ecg)} records from demo data")
}

# Generate EG domain using sdtm.oak algorithms
eg_domain <- raw_ecg %>%
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
    tgt_val = "EG"
  ) %>%
  
  # Algorithm 4: ECG test codes
  assign_no_ct(
    tgt_var = "EGTESTCD",
    tgt_val = TEST_CODE
  ) %>%
  assign_no_ct(
    tgt_var = "EGTEST",
    tgt_val = TEST_NAME
  ) %>%
  
  # Algorithm 5: Original result
  assign_no_ct(
    tgt_var = "EGORRES",
    tgt_val = as.character(RESULT)
  ) %>%
  assign_no_ct(
    tgt_var = "EGORRESU",
    tgt_val = UNIT
  ) %>%
  
  # Algorithm 6: Standardized result
  assign_no_ct(
    tgt_var = "EGSTRESC",
    tgt_val = as.character(RESULT)
  ) %>%
  assign_no_ct(
    tgt_var = "EGSTRESN",
    tgt_val = RESULT
  ) %>%
  assign_no_ct(
    tgt_var = "EGSTRESU",
    tgt_val = UNIT
  ) %>%
  
  # Algorithm 7: Position during ECG
  assign_no_ct(
    tgt_var = "EGPOS",
    tgt_val = POSITION
  ) %>%
  
  # Algorithm 8: ECG method
  assign_no_ct(
    tgt_var = "EGMETHOD",
    tgt_val = METHOD
  ) %>%
  
  # Algorithm 9: Evaluator
  assign_no_ct(
    tgt_var = "EGEVAL",
    tgt_val = EVALUATOR
  ) %>%
  
  # Algorithm 10: Visit information
  assign_no_ct(
    tgt_var = "VISITNUM",
    tgt_val = VISIT_NUM
  ) %>%
  assign_no_ct(
    tgt_var = "VISIT",
    tgt_val = VISIT
  ) %>%
  
  # Algorithm 11: ECG date
  assign_datetime(
    dtc_var = "EGDTC",
    dtm = VISIT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 12: Baseline flag (first visit)
  mutate(
    EGBLFL = if_else(VISIT_NUM == 1, "Y", NA_character_)
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(EGSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, EGSEQ,
    EGTESTCD, EGTEST,
    EGORRES, EGORRESU, EGSTRESC, EGSTRESN, EGSTRESU,
    EGPOS, EGMETHOD, EGEVAL,
    VISITNUM, VISIT, EGDTC, EGBLFL
  )

log_info("Generated {nrow(eg_domain)} EG records for {length(unique(eg_domain$USUBJID))} subjects")

# Check for QT prolongation concerns (QTcF > 450 msec)
qt_prolonged <- eg_domain %>% 
  filter(EGTESTCD == "QTCF", EGSTRESN > 450) %>% 
  nrow()

if (qt_prolonged > 0) {
  log_warn("QTcF prolongation detected in {qt_prolonged} measurements (>450 msec)")
}

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "eg_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    eg_domain, 
    path = output_path,
    label = "ECG Tests",
    domain = "EG"
  )
  log_info("✓ EG domain written: {output_path}")
} else {
  haven::write_xpt(eg_domain, output_path)
  log_info("✓ EG domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "eg_oak.csv")
write_csv(eg_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM EG Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(eg_domain)))
message(sprintf("Subjects: %d", length(unique(eg_domain$USUBJID))))
message(sprintf("Parameters: %d unique ECG tests", length(unique(eg_domain$EGTESTCD))))
if (qt_prolonged > 0) {
  message(sprintf("WARNING: QTcF prolongation: %d measurements", qt_prolonged))
}
message(sprintf("Output: %s", output_path))
message("========================================\n")
