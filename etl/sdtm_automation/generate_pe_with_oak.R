#!/usr/bin/env Rscript
#=============================================================================
# SDTM PE DOMAIN GENERATION WITH sdtm.oak
# Physical Examination - Body system examination findings
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating PE domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw physical exam data from demo
raw_pe_path <- here("demo", "data", "test_sdtm_pe.csv")

if (!file.exists(raw_pe_path)) {
  log_error("Demo data not found: {raw_pe_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  # Physical exam by body system across 3 subjects, 4 visits
  pe_panel <- expand.grid(
    SUBJID = c("001", "002", "003"),
    VISIT_NUM = 1:4,
    BODY_SYSTEM = c("HEENT", "CV", "RESP", "GI", "SKIN", "NEURO", "MUSCSKEL"),
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
      SYSTEM_NAME = case_when(
        BODY_SYSTEM == "HEENT" ~ "Head, Ears, Eyes, Nose, Throat",
        BODY_SYSTEM == "CV" ~ "Cardiovascular",
        BODY_SYSTEM == "RESP" ~ "Respiratory",
        BODY_SYSTEM == "GI" ~ "Gastrointestinal",
        BODY_SYSTEM == "SKIN" ~ "Skin",
        BODY_SYSTEM == "NEURO" ~ "Neurological",
        BODY_SYSTEM == "MUSCSKEL" ~ "Musculoskeletal"
      ),
      CATEGORY = "GENERAL",
      # Most exams are normal, occasionally abnormal
      FINDING = case_when(
        runif(n()) > 0.9 ~ "ABNORMAL",
        TRUE ~ "NORMAL"
      ),
      # Add specific abnormal findings for some cases
      FINDING_DETAIL = case_when(
        FINDING == "ABNORMAL" & BODY_SYSTEM == "SKIN" ~ "Mild erythema on right forearm",
        FINDING == "ABNORMAL" & BODY_SYSTEM == "CV" ~ "Grade 2/6 systolic murmur",
        FINDING == "ABNORMAL" & BODY_SYSTEM == "RESP" ~ "Decreased breath sounds bilateral bases",
        FINDING == "ABNORMAL" & BODY_SYSTEM == "NEURO" ~ "Diminished reflexes lower extremities",
        TRUE ~ NA_character_
      ),
      LOCATION = case_when(
        !is.na(FINDING_DETAIL) & BODY_SYSTEM == "SKIN" ~ "ARM",
        !is.na(FINDING_DETAIL) & BODY_SYSTEM == "CV" ~ "HEART",
        !is.na(FINDING_DETAIL) & BODY_SYSTEM == "RESP" ~ "LUNGS",
        !is.na(FINDING_DETAIL) & BODY_SYSTEM == "NEURO" ~ "LOWER EXTREMITY",
        TRUE ~ NA_character_
      ),
      EVALUATOR = "INVESTIGATOR",
      VISIT_DATE = as.Date("2024-01-01") + (VISIT_NUM - 1) * 28 + 
        as.numeric(factor(SUBJID)) - 1
    )
  
  raw_pe <- pe_panel
  
} else {
  raw_pe <- read_csv(raw_pe_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_pe)} records from demo data")
}

# Generate PE domain using sdtm.oak algorithms
pe_domain <- raw_pe %>%
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
    tgt_val = "PE"
  ) %>%
  
  # Algorithm 4: Body system codes
  assign_no_ct(
    tgt_var = "PETESTCD",
    tgt_val = BODY_SYSTEM
  ) %>%
  assign_no_ct(
    tgt_var = "PETEST",
    tgt_val = SYSTEM_NAME
  ) %>%
  
  # Algorithm 5: Category
  assign_no_ct(
    tgt_var = "PECAT",
    tgt_val = CATEGORY
  ) %>%
  
  # Algorithm 6: Finding (original result)
  assign_no_ct(
    tgt_var = "PEORRES",
    tgt_val = if_else(!is.na(FINDING_DETAIL), FINDING_DETAIL, FINDING)
  ) %>%
  
  # Algorithm 7: Standardized finding
  assign_no_ct(
    tgt_var = "PESTRESC",
    tgt_val = FINDING
  ) %>%
  
  # Algorithm 8: Location of finding
  assign_no_ct(
    tgt_var = "PELOC",
    tgt_val = LOCATION
  ) %>%
  
  # Algorithm 9: Evaluator
  assign_no_ct(
    tgt_var = "PEEVAL",
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
  
  # Algorithm 11: Examination date
  assign_datetime(
    dtc_var = "PEDTC",
    dtm = VISIT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 12: Baseline flag (first visit)
  mutate(
    PEBLFL = if_else(VISIT_NUM == 1, "Y", NA_character_)
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(PESEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, PESEQ,
    PETESTCD, PETEST, PECAT,
    PEORRES, PESTRESC, PELOC, PEEVAL,
    VISITNUM, VISIT, PEDTC, PEBLFL
  )

log_info("Generated {nrow(pe_domain)} PE records for {length(unique(pe_domain$USUBJID))} subjects")
log_info("Abnormal findings: {sum(pe_domain$PESTRESC == 'ABNORMAL')}")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "pe_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    pe_domain, 
    path = output_path,
    label = "Physical Examination",
    domain = "PE"
  )
  log_info("✓ PE domain written: {output_path}")
} else {
  haven::write_xpt(pe_domain, output_path)
  log_info("✓ PE domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "pe_oak.csv")
write_csv(pe_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM PE Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(pe_domain)))
message(sprintf("Subjects: %d", length(unique(pe_domain$USUBJID))))
message(sprintf("Body systems: %d", length(unique(pe_domain$PETESTCD))))
message(sprintf("Abnormal findings: %d", sum(pe_domain$PESTRESC == "ABNORMAL")))
message(sprintf("Output: %s", output_path))
message("========================================\n")
