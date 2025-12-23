#!/usr/bin/env Rscript
#=============================================================================
# SDTM LB DOMAIN GENERATION WITH sdtm.oak
# Laboratory Tests - Blood tests, chemistry, hematology, urinalysis
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating LB domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw lab data from demo
raw_lb_path <- here("demo", "data", "test_sdtm_lb.csv")

if (!file.exists(raw_lb_path)) {
  log_error("Demo data not found: {raw_lb_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  # Common lab tests across 3 subjects, 4 visits
  test_panel <- expand.grid(
    SUBJID = c("001", "002", "003"),
    VISIT_NUM = 1:4,
    TEST_CODE = c("HGB", "WBC", "PLT", "CREAT", "ALT", "AST"),
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
        TEST_CODE == "HGB" ~ "Hemoglobin",
        TEST_CODE == "WBC" ~ "White Blood Cells",
        TEST_CODE == "PLT" ~ "Platelets",
        TEST_CODE == "CREAT" ~ "Creatinine",
        TEST_CODE == "ALT" ~ "Alanine Aminotransferase",
        TEST_CODE == "AST" ~ "Aspartate Aminotransferase"
      ),
      CATEGORY = case_when(
        TEST_CODE %in% c("HGB", "WBC", "PLT") ~ "HEMATOLOGY",
        TEST_CODE %in% c("CREAT", "ALT", "AST") ~ "CHEMISTRY"
      ),
      UNIT = case_when(
        TEST_CODE == "HGB" ~ "g/dL",
        TEST_CODE == "WBC" ~ "10^9/L",
        TEST_CODE == "PLT" ~ "10^9/L",
        TEST_CODE == "CREAT" ~ "mg/dL",
        TEST_CODE %in% c("ALT", "AST") ~ "U/L"
      ),
      NRLO = case_when(
        TEST_CODE == "HGB" ~ 12.0,
        TEST_CODE == "WBC" ~ 4.0,
        TEST_CODE == "PLT" ~ 150,
        TEST_CODE == "CREAT" ~ 0.6,
        TEST_CODE == "ALT" ~ 7,
        TEST_CODE == "AST" ~ 10
      ),
      NRHI = case_when(
        TEST_CODE == "HGB" ~ 16.0,
        TEST_CODE == "WBC" ~ 11.0,
        TEST_CODE == "PLT" ~ 400,
        TEST_CODE == "CREAT" ~ 1.2,
        TEST_CODE == "ALT" ~ 56,
        TEST_CODE == "AST" ~ 40
      ),
      # Generate realistic random values
      RESULT = case_when(
        TEST_CODE == "HGB" ~ round(runif(n(), 11.5, 16.5), 1),
        TEST_CODE == "WBC" ~ round(runif(n(), 3.5, 12.0), 1),
        TEST_CODE == "PLT" ~ round(runif(n(), 140, 420), 0),
        TEST_CODE == "CREAT" ~ round(runif(n(), 0.7, 1.3), 2),
        TEST_CODE == "ALT" ~ round(runif(n(), 15, 60), 0),
        TEST_CODE == "AST" ~ round(runif(n(), 18, 45), 0)
      ),
      VISIT_DATE = as.Date("2024-01-01") + (VISIT_NUM - 1) * 28 + 
        as.numeric(factor(SUBJID)) - 1,
      SPECIMEN = case_when(
        CATEGORY == "HEMATOLOGY" ~ "WHOLE BLOOD",
        CATEGORY == "CHEMISTRY" ~ "SERUM"
      )
    ) %>%
    mutate(
      NRIND = case_when(
        RESULT < NRLO ~ "LOW",
        RESULT > NRHI ~ "HIGH",
        TRUE ~ "NORMAL"
      )
    )
  
  raw_labs <- test_panel
} else {
  raw_labs <- read_csv(raw_lb_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_labs)} records from demo data")
}

# Generate LB domain using sdtm.oak algorithms
lb_domain <- raw_labs %>%
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
    tgt_val = "LB"
  ) %>%
  
  # Algorithm 4: Lab test codes
  assign_no_ct(
    tgt_var = "LBTESTCD",
    tgt_val = TEST_CODE
  ) %>%
  assign_no_ct(
    tgt_var = "LBTEST",
    tgt_val = TEST_NAME
  ) %>%
  
  # Algorithm 5: Category
  assign_no_ct(
    tgt_var = "LBCAT",
    tgt_val = CATEGORY
  ) %>%
  
  # Algorithm 6: Specimen type
  assign_no_ct(
    tgt_var = "LBSPEC",
    tgt_val = SPECIMEN
  ) %>%
  
  # Algorithm 7: Original result
  assign_no_ct(
    tgt_var = "LBORRES",
    tgt_val = as.character(RESULT)
  ) %>%
  assign_no_ct(
    tgt_var = "LBORRESU",
    tgt_val = UNIT
  ) %>%
  
  # Algorithm 8: Standardized result
  assign_no_ct(
    tgt_var = "LBSTRESC",
    tgt_val = as.character(RESULT)
  ) %>%
  assign_no_ct(
    tgt_var = "LBSTRESN",
    tgt_val = RESULT
  ) %>%
  assign_no_ct(
    tgt_var = "LBSTRESU",
    tgt_val = UNIT
  ) %>%
  
  # Algorithm 9: Normal range
  assign_no_ct(
    tgt_var = "LBSTNRLO",
    tgt_val = NRLO
  ) %>%
  assign_no_ct(
    tgt_var = "LBSTNRHI",
    tgt_val = NRHI
  ) %>%
  
  # Algorithm 10: Normal range indicator
  assign_no_ct(
    tgt_var = "LBNRIND",
    tgt_val = NRIND
  ) %>%
  
  # Algorithm 11: Visit information
  assign_no_ct(
    tgt_var = "VISITNUM",
    tgt_val = VISIT_NUM
  ) %>%
  assign_no_ct(
    tgt_var = "VISIT",
    tgt_val = VISIT
  ) %>%
  
  # Algorithm 12: Lab date
  assign_datetime(
    dtc_var = "LBDTC",
    dtm = VISIT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 13: Baseline flag (first visit)
  mutate(
    LBBLFL = if_else(VISIT_NUM == 1, "Y", NA_character_)
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(LBSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, LBSEQ,
    LBTESTCD, LBTEST, LBCAT, LBSPEC,
    LBORRES, LBORRESU, LBSTRESC, LBSTRESN, LBSTRESU,
    LBSTNRLO, LBSTNRHI, LBNRIND,
    VISITNUM, VISIT, LBDTC, LBBLFL
  )

log_info("Generated {nrow(lb_domain)} LB records for {length(unique(lb_domain$USUBJID))} subjects")
log_info("Abnormal results: {sum(lb_domain$LBNRIND != 'NORMAL', na.rm = TRUE)}")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "lb_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    lb_domain, 
    path = output_path,
    label = "Laboratory Tests",
    domain = "LB"
  )
  log_info("✓ LB domain written: {output_path}")
} else {
  haven::write_xpt(lb_domain, output_path)
  log_info("✓ LB domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "lb_oak.csv")
write_csv(lb_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM LB Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(lb_domain)))
message(sprintf("Subjects: %d", length(unique(lb_domain$USUBJID))))
message(sprintf("Tests: %d unique tests", length(unique(lb_domain$LBTESTCD))))
message(sprintf("Abnormal: %d", sum(lb_domain$LBNRIND != "NORMAL", na.rm = TRUE)))
message(sprintf("Output: %s", output_path))
message("========================================\n")
