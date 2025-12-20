#!/usr/bin/env Rscript
# Feature Engineering for RECIST Progression Prediction
# Transforms raw tumor measurements into ML-ready features

library(tidyverse)
library(lubridate)

#' Engineer features from RECIST tumor assessment data
#' 
#' Creates 25+ features that predict progression including:
#' - Baseline characteristics
#' - Early tumor dynamics  
#' - Temporal patterns
#' - Velocity and acceleration
#' 
#' @param rs_data SDTM RS domain or equivalent with columns:
#'   USUBJID, RSDTC, RSSTRESC, LESIONID (optional)
#' @return Engineered features dataset (one row per subject)
#' @export
engineer_progression_features <- function(rs_data) {
  
  cat("=== Feature Engineering Pipeline ===\n\n")
  
  # Data validation
  required_cols <- c("USUBJID", "RSDTC", "RSSTRESC")
  missing_cols <- setdiff(required_cols, names(rs_data))
  
  if (length(missing_cols) > 0) {
    stop(sprintf("❌ Missing required columns: %s", 
                 paste(missing_cols, collapse = ", ")))
  }
  
  # Data preparation
  cat("→ Preparing data...\n")
  
  rs_clean <- rs_data %>%
    arrange(USUBJID, RSDTC) %>%
    mutate(
      RSDTC = as.Date(RSDTC),
      SLD = as.numeric(RSSTRESC),
      LESIONID = if ("LESIONID" %in% names(.)) LESIONID else 1
    ) %>%
    filter(!is.na(SLD))
  
  # Calculate study day from first assessment
  rs_clean <- rs_clean %>%
    group_by(USUBJID) %>%
    mutate(
      STUDYDAY = as.numeric(difftime(RSDTC, min(RSDTC), units = "days"))
    ) %>%
    ungroup()
  
  cat(sprintf("  ✓ Cleaned data: %d assessments for %d subjects\n\n", 
              nrow(rs_clean), n_distinct(rs_clean$USUBJID)))
  
  # Feature engineering
  cat("→ Engineering features...\n")
  
  features <- rs_clean %>%
    group_by(USUBJID) %>%
    arrange(STUDYDAY) %>%
    summarise(
      # ========================================
      # BASELINE FEATURES
      # ========================================
      baseline_sld = first(SLD),
      baseline_lesion_count = n_distinct(LESIONID),
      
      # ========================================
      # EARLY RESPONSE (First follow-up)
      # ========================================
      first_fu_sld = if (n() >= 2) nth(SLD, 2) else NA_real_,
      first_fu_days = if (n() >= 2) nth(STUDYDAY, 2) else NA_real_,
      first_fu_change_abs = first_fu_sld - baseline_sld,
      first_fu_change_pct = if (!is.na(first_fu_sld)) {
        100 * (first_fu_sld - baseline_sld) / baseline_sld
      } else {
        NA_real_
      },
      
      # Early response classification per RECIST
      early_response_pr = !is.na(first_fu_change_pct) && first_fu_change_pct <= -30,
      early_response_pd = !is.na(first_fu_change_pct) && first_fu_change_pct >= 20,
      early_response_sd = !early_response_pr && !early_response_pd,
      
      # ========================================
      # NADIR (Best response)
      # ========================================
      nadir_sld = min(SLD, na.rm = TRUE),
      nadir_change_abs = nadir_sld - baseline_sld,
      nadir_change_pct = 100 * (nadir_sld - baseline_sld) / baseline_sld,
      days_to_nadir = STUDYDAY[which.min(SLD)][1],
      
      achieved_pr_threshold = any(SLD <= baseline_sld * 0.7, na.rm = TRUE),
      achieved_cr_threshold = any(SLD == 0, na.rm = TRUE),
      
      # ========================================
      # VELOCITY (Rate of tumor change)
      # ========================================
      overall_velocity = if (n() >= 2) {
        (last(SLD) - first(SLD)) / (last(STUDYDAY) - first(STUDYDAY))
      } else {
        NA_real_
      },
      
      early_velocity = if (n() >= 2) {
        (nth(SLD, 2) - first(SLD)) / (nth(STUDYDAY, 2) - first(STUDYDAY))
      } else {
        NA_real_
      },
      
      late_velocity = if (n() >= 3) {
        (last(SLD) - nth(SLD, -2)) / (last(STUDYDAY) - nth(STUDYDAY, -2))
      } else {
        NA_real_
      },
      
      # ========================================
      # ACCELERATION (Change in velocity)
      # ========================================
      acceleration = if (!is.na(early_velocity) && !is.na(late_velocity)) {
        late_velocity - early_velocity
      } else {
        NA_real_
      },
      
      is_accelerating = !is.na(acceleration) && acceleration > 0,
      
      # ========================================
      # VARIABILITY & STABILITY
      # ========================================
      sld_sd = sd(SLD, na.rm = TRUE),
      sld_cv = sd(SLD, na.rm = TRUE) / mean(SLD, na.rm = TRUE),
      sld_range = max(SLD, na.rm = TRUE) - min(SLD, na.rm = TRUE),
      sld_range_pct = 100 * sld_range / baseline_sld,
      
      # ========================================
      # PATTERN FEATURES
      # ========================================
      n_consecutive_increases = {
        if (n() >= 2) {
          diffs <- diff(SLD)
          increases <- diffs > 0
          if (any(increases)) {
            max(rle(increases)$lengths[rle(increases)$values], 0)
          } else {
            0
          }
        } else {
          0
        }
      },
      
      n_consecutive_decreases = {
        if (n() >= 2) {
          diffs <- diff(SLD)
          decreases <- diffs < 0
          if (any(decreases)) {
            max(rle(decreases)$lengths[rle(decreases)$values], 0)
          } else {
            0
          }
        } else {
          0
        }
      },
      
      n_direction_changes = if (n() >= 3) {
        diffs <- diff(SLD)
        signs <- sign(diffs)
        sum(diff(signs) != 0, na.rm = TRUE)
      } else {
        0
      },
      
      # ========================================
      # TEMPORAL FEATURES
      # ========================================
      n_assessments = n(),
      days_on_study = max(STUDYDAY, na.rm = TRUE),
      avg_assessment_interval = if (n() >= 2) {
        mean(diff(STUDYDAY), na.rm = TRUE)
      } else {
        NA_real_
      },
      assessment_frequency = n() / (max(STUDYDAY) / 30 + 0.001),
      
      time_in_response = sum(SLD <= baseline_sld * 0.7, na.rm = TRUE) * avg_assessment_interval,
      time_in_progression = sum(SLD >= nadir_sld * 1.2, na.rm = TRUE) * avg_assessment_interval,
      
      # ========================================
      # DERIVED RATIOS
      # ========================================
      response_maintenance = if (!is.na(nadir_change_pct) && nadir_change_pct < 0) {
        (last(SLD) - baseline_sld) / (nadir_sld - baseline_sld)
      } else {
        NA_real_
      },
      
      velocity_ratio = if (!is.na(early_velocity) && early_velocity != 0) {
        late_velocity / early_velocity
      } else {
        NA_real_
      },
      
      # ========================================
      # OUTCOME VARIABLE (What we predict)
      # ========================================
      progressed = any(SLD >= nadir_sld * 1.2 + 5, na.rm = TRUE),
      
      days_to_progression = if (any(SLD >= nadir_sld * 1.2 + 5, na.rm = TRUE)) {
        min(STUDYDAY[SLD >= nadir_sld * 1.2 + 5], na.rm = TRUE)
      } else {
        max(STUDYDAY, na.rm = TRUE)
      },
      
      .groups = "drop"
    )
  
  # Handle missing values with median imputation
  cat("→ Handling missing values...\n")
  
  numeric_cols <- features %>%
    select(where(is.numeric), -USUBJID) %>%
    names()
  
  features_imputed <- features %>%
    mutate(across(
      all_of(numeric_cols),
      ~if_else(is.na(.), median(., na.rm = TRUE), .)
    ))
  
  # Convert logical to numeric for ML models
  features_final <- features_imputed %>%
    mutate(across(where(is.logical), as.numeric))
  
  # Summary statistics
  cat("\n=== Feature Engineering Summary ===\n")
  cat(sprintf("Subjects processed:        %d\n", nrow(features_final)))
  cat(sprintf("Features created:          %d\n", ncol(features_final) - 3))
  cat(sprintf("Progression rate:          %.1f%%\n", 
              100 * mean(features_final$progressed)))
  cat(sprintf("Median follow-up:          %.0f days\n", 
              median(features_final$days_on_study)))
  cat(sprintf("Median assessments/patient: %.0f\n", 
              median(features_final$n_assessments)))
  
  cat("\nFeature Categories:\n")
  cat(sprintf("  Baseline:     %d features\n", 
              sum(str_detect(names(features_final), "^baseline"))))
  cat(sprintf("  Early response: %d features\n", 
              sum(str_detect(names(features_final), "^first_fu|^early_response"))))
  cat(sprintf("  Nadir:        %d features\n", 
              sum(str_detect(names(features_final), "^nadir"))))
  cat(sprintf("  Velocity:     %d features\n", 
              sum(str_detect(names(features_final), "velocity"))))
  cat(sprintf("  Temporal:     %d features\n", 
              sum(str_detect(names(features_final), "days|time|assessment"))))
  
  return(features_final)
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

if (sys.nframe() == 0) {
  
  cat("\n")
  cat("╔═══════════════════════════════════════════════════════╗\n")
  cat("║   RECIST Progression - Feature Engineering            ║\n")
  cat("╚═══════════════════════════════════════════════════════╝\n")
  cat("\n")
  
  # Try to load data from various sources
  data_sources <- c(
    "../data/demo_rs_data.csv",
    "../../../demo/data/test_sdtm_rs.csv",
    "../../demo/data/test_sdtm_rs.csv"
  )
  
  rs_data <- NULL
  for (source in data_sources) {
    if (file.exists(source)) {
      cat(sprintf("→ Loading data from: %s\n", source))
      rs_data <- read_csv(source, show_col_types = FALSE)
      break
    }
  }
  
  if (is.null(rs_data)) {
    stop("❌ No input data found. Please run setup.R first or provide RS domain data.")
  }
  
  # Engineer features
  features <- engineer_progression_features(rs_data)
  
  # Save results
  dir.create("../data", showWarnings = FALSE, recursive = TRUE)
  output_file <- "../data/engineered_features.csv"
  write_csv(features, output_file)
  
  cat(sprintf("\n✓ Features saved to: %s\n", output_file))
  
  # Show sample
  cat("\n=== Sample Features (first 5 subjects, first 10 columns) ===\n")
  print(features %>% select(1:10) %>% head(5), width = Inf)
  
  cat("\n✓ Feature engineering complete!\n")
  cat("\nNext step: Rscript step2_train_model.R\n\n")
}
