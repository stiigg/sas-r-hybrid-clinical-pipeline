################################################################################
# Script: generate_adrs_imwg_with_admiral.R
# Purpose: Generate ADRS for Multiple Myeloma using IMWG criteria
# Author: Christian Baghai
# Date: December 2025
#
# ADMIRALONCO EXTENSION FOR HEMATOLOGIC MALIGNANCIES
# Reference: https://cran.r-project.org/web/packages/admiralonco/vignettes/adrs_imwg.html
#
# KEY DIFFERENCES FROM YOUR SOLID TUMOR ADRS:
# 1. Input: SDTM LB domain (not RS domain)
# 2. Parameters: M-protein, FLC (not tumor measurements)
# 3. Thresholds: 50% PR, 90% VGPR (not 30%/20%)
################################################################################

library(admiral)
library(admiralonco)
library(dplyr)
library(lubridate)
library(haven)

# Set paths
repo_root <- here::here()
sdtm_path <- file.path(repo_root, "demo", "data")
adam_path <- file.path(repo_root, "outputs", "adam")

cat("\n========================================\n")
cat("IMWG Response Derivation with admiral\n")
cat("Repository:", repo_root, "\n")
cat("========================================\n\n")

################################################################################
# STEP 1: Load SDTM data
################################################################################

cat("Loading SDTM LB domain...\n")
lb <- read.csv(file.path(sdtm_path, "test_sdtm_lb_myeloma.csv"),
               stringsAsFactors = FALSE)

cat("Loading SDTM MB domain...\n")
mb <- read.csv(file.path(sdtm_path, "test_sdtm_mb_myeloma.csv"),
               stringsAsFactors = FALSE)

################################################################################
# STEP 2: Derive M-protein parameters in ADLB
################################################################################

cat("\nDeriving M-protein and FLC parameters...\n")

# Extract M-protein values
adlb_mprotein <- lb %>%
  filter(LBTESTCD %in% c("SPROT", "KAPPA", "LAMBDA", "IMFIX")) %>%
  mutate(
    AVAL = as.numeric(LBSTRESC),
    ADT = as.Date(LBDTC),
    ABLFL = if_else(ABLFL == "Y", "Y", NA_character_),
    PARAMCD = LBTESTCD,
    PARAM = LBTEST
  ) %>%
  # Derive baseline value
  admiral::derive_var_base(
    by_vars = exprs(USUBJID, PARAMCD),
    source_var = AVAL,
    new_var = BASE
  ) %>%
  # Derive change from baseline
  admiral::derive_var_chg() %>%
  # Derive percent change
  admiral::derive_var_pchg()

################################################################################
# STEP 3: Calculate dFLC (difference in free light chains)
################################################################################

cat("Calculating dFLC...\n")

# Pivot FLC data to wide format
flc_wide <- adlb_mprotein %>%
  filter(PARAMCD %in% c("KAPPA", "LAMBDA")) %>%
  select(USUBJID, VISIT, ADT, PARAMCD, AVAL, BASE) %>%
  tidyr::pivot_wider(
    id_cols = c(USUBJID, VISIT, ADT),
    names_from = PARAMCD,
    values_from = c(AVAL, BASE),
    names_sep = "_"
  )

# Calculate dFLC and FLC ratio
adlb_flc <- flc_wide %>%
  mutate(
    # dFLC = |Involved - Uninvolved| (assuming Kappa is involved)
    dFLC = abs(AVAL_KAPPA - AVAL_LAMBDA),
    BASE_dFLC = abs(BASE_KAPPA - BASE_LAMBDA),
    # FLC ratio
    FLC_RATIO = AVAL_KAPPA / AVAL_LAMBDA,
    BASE_FLC_RATIO = BASE_KAPPA / BASE_LAMBDA,
    # Percent change in dFLC
    CHG_dFLC = dFLC - BASE_dFLC,
    PCHG_dFLC = (CHG_dFLC / BASE_dFLC) * 100,
    # Create PARAMCD/PARAM
    PARAMCD = "dFLC",
    PARAM = "Difference in Free Light Chains",
    AVAL = dFLC
  ) %>%
  select(USUBJID, VISIT, ADT, PARAMCD, PARAM, AVAL, BASE, CHG_dFLC, PCHG_dFLC, FLC_RATIO)

################################################################################
# STEP 4: Derive IMWG response using admiralonco-style logic
################################################################################

cat("\nDeriving IMWG response categories...\n")

# Combine M-protein and dFLC data
combined_data <- adlb_mprotein %>%
  filter(PARAMCD == "SPROT") %>%
  full_join(adlb_flc, by = c("USUBJID", "VISIT", "ADT"))

# Merge bone marrow data
mb_processed <- mb %>%
  filter(MBTESTCD == "BMPC") %>%
  mutate(
    BMPC_PERCENT = as.numeric(MBSTRESC),
    ADT = as.Date(MBDTC)
  ) %>%
  select(USUBJID, VISIT, BMPC_PERCENT)

combined_data <- combined_data %>%
  left_join(mb_processed, by = c("USUBJID", "VISIT"))

# Derive IMWG response per hierarchy
adrs_imwg <- combined_data %>%
  mutate(
    # Derive IMWG response category
    IMWG_RESP = case_when(
      # Progressive Disease (PD): ≥25% increase from nadir + absolute ≥0.5 g/dL
      # Note: Nadir tracking would require window functions across visits
      PCHG >= 25 & CHG >= 0.5 ~ "PD",

      # Stringent Complete Response (sCR)
      # Simplified: Would need immunofixation, BM, FLC ratio, clonal cells
      BMPC_PERCENT < 5 & FLC_RATIO >= 0.26 & FLC_RATIO <= 1.65 ~ "sCR",

      # Complete Response (CR)
      BMPC_PERCENT < 5 ~ "CR",

      # Very Good Partial Response (VGPR)
      PCHG <= -90 | dFLC < 100 ~ "VGPR",

      # Partial Response (PR)
      PCHG <= -50 | PCHG_dFLC <= -50 ~ "PR",

      # Stable Disease (SD)
      !is.na(AVAL) ~ "SD",

      # Not Evaluable (NE)
      TRUE ~ "NE"
    ),

    # Assign PARAMCD/PARAM for BDS structure
    PARAMCD = "IMWGR",
    PARAM = "IMWG Response Category",
    AVALC = IMWG_RESP,
    AVAL = as.numeric(factor(IMWG_RESP,
                             levels = c("sCR", "CR", "VGPR", "PR", "SD", "PD", "NE")))
  ) %>%
  # Add labels
  admiral::derive_vars_merged(
    dataset_add = combined_data %>%
      group_by(USUBJID) %>%
      slice(1) %>%
      select(USUBJID, STUDYID),
    by_vars = exprs(USUBJID)
  )

################################################################################
# STEP 5: Output
################################################################################

cat("\nGenerating outputs...\n")

# Print summary
cat("\nIMWG Response Distribution:\n")
print(table(adrs_imwg$IMWG_RESP, useNA = "always"))

# Save as CSV
write.csv(adrs_imwg,
          file.path(adam_path, "adrs_imwg_admiral.csv"),
          row.names = FALSE)
cat("CSV saved:", file.path(adam_path, "adrs_imwg_admiral.csv"), "\n")

# Save as SAS XPT (parallel to your RECIST output)
haven::write_xpt(adrs_imwg,
                 file.path(adam_path, "adrs_imwg.xpt"),
                 version = 5)
cat("XPT saved:", file.path(adam_path, "adrs_imwg.xpt"), "\n")

cat("\n========================================\n")
cat("IMWG Response Derivation Complete\n")
cat(sprintf("Records: %d | Subjects: %d\n",
            nrow(adrs_imwg),
            n_distinct(adrs_imwg$USUBJID)))
cat("========================================\n")
