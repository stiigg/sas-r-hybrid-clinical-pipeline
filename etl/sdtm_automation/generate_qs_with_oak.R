#!/usr/bin/env Rscript
#=============================================================================
# SDTM QS DOMAIN GENERATION WITH sdtm.oak
# Questionnaires - Patient-reported outcomes, quality of life, scales
#=============================================================================

library(sdtm.oak)
library(dplyr)
library(haven)
library(readr)
library(here)
library(logger)

log_info("Generating QS domain with sdtm.oak algorithms")

# Create output directory
dir.create(here("outputs", "sdtm"), recursive = TRUE, showWarnings = FALSE)

# Read raw questionnaire data from demo
raw_qs_path <- here("demo", "data", "test_sdtm_qs.csv")

if (!file.exists(raw_qs_path)) {
  log_error("Demo data not found: {raw_qs_path}")
  log_info("Creating synthetic test data...")
  
  # Create minimal test data if demo file doesn't exist
  # ECOG Performance Status and EORTC QLQ-C30 selected items
  
  # ECOG Performance Status (0-4 scale)
  ecog_data <- expand.grid(
    SUBJID = c("001", "002", "003"),
    VISIT_NUM = 1:4,
    stringsAsFactors = FALSE
  ) %>%
    as_tibble() %>%
    mutate(
      QUESTIONNAIRE = "ECOG PERFORMANCE STATUS",
      ITEM_CODE = "ECOG",
      ITEM_TEXT = "ECOG Performance Status",
      SUBSCALE = NA_character_,
      RESPONSE = sample(0:2, n(), replace = TRUE, prob = c(0.4, 0.4, 0.2)),
      RESPONSE_TEXT = case_when(
        RESPONSE == 0 ~ "Fully active",
        RESPONSE == 1 ~ "Restricted in physically strenuous activity",
        RESPONSE == 2 ~ "Ambulatory and capable of all selfcare",
        RESPONSE == 3 ~ "Capable of only limited selfcare",
        RESPONSE == 4 ~ "Completely disabled"
      )
    )
  
  # EORTC QLQ-C30 sample items (simplified)
  eortc_items <- tibble(
    ITEM_CODE = c("QLQ01", "QLQ02", "QLQ03", "QLQ29", "QLQ30"),
    ITEM_TEXT = c(
      "Do you have any trouble doing strenuous activities?",
      "Do you have any trouble taking a long walk?",
      "Do you have any trouble taking a short walk outside?",
      "How would you rate your overall health during the past week?",
      "How would you rate your overall quality of life during the past week?"
    ),
    SUBSCALE = c(
      "PHYSICAL FUNCTIONING", "PHYSICAL FUNCTIONING", "PHYSICAL FUNCTIONING",
      "GLOBAL HEALTH STATUS", "GLOBAL HEALTH STATUS"
    )
  )
  
  eortc_data <- expand.grid(
    SUBJID = c("001", "002", "003"),
    VISIT_NUM = 1:4,
    ITEM_CODE = eortc_items$ITEM_CODE,
    stringsAsFactors = FALSE
  ) %>%
    as_tibble() %>%
    left_join(eortc_items, by = "ITEM_CODE") %>%
    mutate(
      QUESTIONNAIRE = "EORTC QLQ-C30",
      # Likert scale 1-4 for most items, 1-7 for global items
      RESPONSE = case_when(
        ITEM_CODE %in% c("QLQ29", "QLQ30") ~ sample(1:7, n(), replace = TRUE),
        TRUE ~ sample(1:4, n(), replace = TRUE)
      ),
      RESPONSE_TEXT = case_when(
        ITEM_CODE %in% c("QLQ01", "QLQ02", "QLQ03") & RESPONSE == 1 ~ "Not at all",
        ITEM_CODE %in% c("QLQ01", "QLQ02", "QLQ03") & RESPONSE == 2 ~ "A little",
        ITEM_CODE %in% c("QLQ01", "QLQ02", "QLQ03") & RESPONSE == 3 ~ "Quite a bit",
        ITEM_CODE %in% c("QLQ01", "QLQ02", "QLQ03") & RESPONSE == 4 ~ "Very much",
        ITEM_CODE %in% c("QLQ29", "QLQ30") ~ paste("Score", RESPONSE),
        TRUE ~ NA_character_
      )
    )
  
  # Combine both questionnaires
  raw_qs <- bind_rows(ecog_data, eortc_data) %>%
    mutate(
      VISIT = case_when(
        VISIT_NUM == 1 ~ "Baseline",
        VISIT_NUM == 2 ~ "Week 4",
        VISIT_NUM == 3 ~ "Week 8",
        VISIT_NUM == 4 ~ "Week 12"
      ),
      VISIT_DATE = as.Date("2024-01-01") + (VISIT_NUM - 1) * 28 + 
        as.numeric(factor(SUBJID)) - 1,
      # Randomly mark some items as not done (missing data)
      STATUS = if_else(runif(n()) > 0.95, "NOT DONE", NA_character_),
      REASON_ND = if_else(STATUS == "NOT DONE", "SUBJECT REFUSED", NA_character_)
    ) %>%
    mutate(
      # Set response to NA if not done
      RESPONSE = if_else(STATUS == "NOT DONE", NA_real_, RESPONSE),
      RESPONSE_TEXT = if_else(STATUS == "NOT DONE", NA_character_, RESPONSE_TEXT)
    )
  
} else {
  raw_qs <- read_csv(raw_qs_path, show_col_types = FALSE)
  log_info("Loaded {nrow(raw_qs)} records from demo data")
}

# Generate QS domain using sdtm.oak algorithms
qs_domain <- raw_qs %>%
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
    tgt_val = "QS"
  ) %>%
  
  # Algorithm 4: Questionnaire category
  assign_no_ct(
    tgt_var = "QSCAT",
    tgt_val = QUESTIONNAIRE
  ) %>%
  
  # Algorithm 5: Subscale (if applicable)
  assign_no_ct(
    tgt_var = "QSSCAT",
    tgt_val = SUBSCALE
  ) %>%
  
  # Algorithm 6: Item codes and text
  assign_no_ct(
    tgt_var = "QSTESTCD",
    tgt_val = ITEM_CODE
  ) %>%
  assign_no_ct(
    tgt_var = "QSTEST",
    tgt_val = ITEM_TEXT
  ) %>%
  
  # Algorithm 7: Original response
  assign_no_ct(
    tgt_var = "QSORRES",
    tgt_val = if_else(!is.na(RESPONSE_TEXT), RESPONSE_TEXT, as.character(RESPONSE))
  ) %>%
  
  # Algorithm 8: Standardized response (character)
  assign_no_ct(
    tgt_var = "QSSTRESC",
    tgt_val = as.character(RESPONSE)
  ) %>%
  
  # Algorithm 9: Standardized response (numeric)
  assign_no_ct(
    tgt_var = "QSSTRESN",
    tgt_val = RESPONSE
  ) %>%
  
  # Algorithm 10: Status (NOT DONE)
  assign_no_ct(
    tgt_var = "QSSTAT",
    tgt_val = STATUS
  ) %>%
  
  # Algorithm 11: Reason not done
  assign_no_ct(
    tgt_var = "QSREASND",
    tgt_val = REASON_ND
  ) %>%
  
  # Algorithm 12: Visit information
  assign_no_ct(
    tgt_var = "VISITNUM",
    tgt_val = VISIT_NUM
  ) %>%
  assign_no_ct(
    tgt_var = "VISIT",
    tgt_val = VISIT
  ) %>%
  
  # Algorithm 13: Assessment date
  assign_datetime(
    dtc_var = "QSDTC",
    dtm = VISIT_DATE,
    date_fmt = "%Y-%m-%d"
  ) %>%
  
  # Algorithm 14: Baseline flag (first visit)
  mutate(
    QSBLFL = if_else(VISIT_NUM == 1 & is.na(QSSTAT), "Y", NA_character_)
  ) %>%
  
  # Add sequence numbering
  group_by(USUBJID) %>%
  mutate(QSSEQ = row_number()) %>%
  ungroup() %>%
  
  # Select final SDTM variables
  select(
    STUDYID, DOMAIN, USUBJID, QSSEQ,
    QSTESTCD, QSTEST, QSCAT, QSSCAT,
    QSORRES, QSSTRESC, QSSTRESN,
    QSSTAT, QSREASND,
    VISITNUM, VISIT, QSDTC, QSBLFL
  )

log_info("Generated {nrow(qs_domain)} QS records for {length(unique(qs_domain$USUBJID))} subjects")
log_info("Questionnaires: {paste(unique(qs_domain$QSCAT), collapse = ', ')}")
log_info("Missing responses: {sum(!is.na(qs_domain$QSSTAT))}")

# Write SDTM-compliant XPT file
output_path <- here("outputs", "sdtm", "qs_oak.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    qs_domain, 
    path = output_path,
    label = "Questionnaires",
    domain = "QS"
  )
  log_info("✓ QS domain written: {output_path}")
} else {
  haven::write_xpt(qs_domain, output_path)
  log_info("✓ QS domain written (haven): {output_path}")
}

# Also save as CSV for inspection
csv_path <- here("outputs", "sdtm", "qs_oak.csv")
write_csv(qs_domain, csv_path)
log_info("✓ CSV version saved: {csv_path}")

message("\n========================================")
message("SDTM QS Domain Generation Complete")
message("========================================")
message(sprintf("Records: %d", nrow(qs_domain)))
message(sprintf("Subjects: %d", length(unique(qs_domain$USUBJID))))
message(sprintf("Questionnaires: %s", paste(unique(qs_domain$QSCAT), collapse = ", ")))
message(sprintf("Missing responses: %d", sum(!is.na(qs_domain$QSSTAT))))
message(sprintf("Output: %s", output_path))
message("========================================\n")
