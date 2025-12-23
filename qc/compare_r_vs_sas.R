#!/usr/bin/env Rscript
#=============================================================================
# R vs SAS QUALITY CONTROL COMPARISON
# Compare admiral-generated ADRS/BOR with SAS macro outputs using diffdf
#=============================================================================

library(diffdf)
library(dplyr)
library(haven)
library(here)
library(logger)
library(tibble)
library(tidyr)

log_threshold(INFO)
log_info("Starting R vs SAS Quality Control Comparison")

#=============================================================================
# CONFIGURATION
#=============================================================================

# Paths to datasets
r_adrs_path <- here("outputs", "adam", "adrs_admiral.xpt")
sas_adrs_path <- here("outputs", "adam_sas", "adrs.xpt")  # Your SAS output

# Tolerance for numeric comparisons
NUM_TOLERANCE <- 1e-10

# Create output directory
qc_output_dir <- here("qc", "reports")
dir.create(qc_output_dir, recursive = TRUE, showWarnings = FALSE)

#=============================================================================
# HELPER FUNCTIONS
#=============================================================================

print_comparison_summary <- function(comparison, dataset_name) {
  """
  Print formatted summary of diffdf comparison results
  """
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat(sprintf(" %s COMPARISON RESULTS\n", toupper(dataset_name)))
  cat(strrep("=", 70), "\n")
  
  if (comparison$NumDiff == 0) {
    cat("✅ PERFECT MATCH - No differences detected\n")
    return(invisible(TRUE))
  }
  
  cat(sprintf("⚠️  DIFFERENCES FOUND: %d issues\n\n", comparison$NumDiff))
  
  # Variable differences
  if (!is.null(comparison$VarDiff)) {
    cat("Variable Differences:\n")
    print(comparison$VarDiff)
    cat("\n")
  }
  
  # Value differences
  if (!is.null(comparison$ExtRowsDiff)) {
    cat("Row Count Differences:\n")
    cat(sprintf("  R dataset: %d rows\n", nrow(comparison$ExtRowsDiff[[1]])))
    cat(sprintf("  SAS dataset: %d rows\n", nrow(comparison$ExtRowsDiff[[2]])))
    cat("\n")
  }
  
  # Actual data differences
  if (!is.null(comparison$VarDiff_values)) {
    cat("Value Differences by Variable:\n")
    for (var_name in names(comparison$VarDiff_values)) {
      var_diff <- comparison$VarDiff_values[[var_name]]
      cat(sprintf("  %s: %d differences\n", var_name, nrow(var_diff)))
    }
    cat("\n")
  }
  
  return(invisible(FALSE))
}

calculate_agreement_rate <- function(r_data, sas_data, key_vars, compare_vars) {
  """
  Calculate agreement rate for specific variables
  """
  merged <- inner_join(
    r_data %>% select(all_of(c(key_vars, compare_vars))),
    sas_data %>% select(all_of(c(key_vars, compare_vars))),
    by = key_vars,
    suffix = c("_R", "_SAS")
  )
  
  agreement_summary <- tibble(
    Variable = character(),
    Total_Obs = integer(),
    Matching = integer(),
    Differing = integer(),
    Agreement_Pct = numeric()
  )
  
  for (var in compare_vars) {
    r_col <- paste0(var, "_R")
    sas_col <- paste0(var, "_SAS")
    
    if (r_col %in% names(merged) && sas_col %in% names(merged)) {
      matches <- sum(merged[[r_col]] == merged[[sas_col]], na.rm = TRUE)
      total <- nrow(merged)
      
      agreement_summary <- agreement_summary %>%
        add_row(
          Variable = var,
          Total_Obs = total,
          Matching = matches,
          Differing = total - matches,
          Agreement_Pct = round(matches / total * 100, 2)
        )
    }
  }
  
  return(agreement_summary)
}

#=============================================================================
# MAIN COMPARISON LOGIC
#=============================================================================

log_info("Loading datasets for comparison...")

# Check if files exist
if (!file.exists(r_adrs_path)) {
  log_error("R ADRS not found: {r_adrs_path}")
  log_info("Run generate_adrs_with_admiral.R first")
  stop("Missing R dataset")
}

if (!file.exists(sas_adrs_path)) {
  log_warn("SAS ADRS not found: {sas_adrs_path}")
  log_info("Creating mock SAS dataset for demonstration...")
  
  # For demo: create mock SAS dataset (in production, this would be real SAS output)
  r_adrs <- read_xpt(r_adrs_path)
  sas_adrs <- r_adrs %>%
    mutate(
      # Introduce intentional difference for testing
      AVALC = if_else(row_number() == 1, "MOCK_DIFF", AVALC)
    )
  write_xpt(sas_adrs, sas_adrs_path)
  log_info("Mock SAS dataset created for demonstration")
} else {
  sas_adrs <- read_xpt(sas_adrs_path) %>% convert_blanks_to_na()
}

r_adrs <- read_xpt(r_adrs_path) %>% convert_blanks_to_na()

log_info("Loaded R ADRS: {nrow(r_adrs)} records")
log_info("Loaded SAS ADRS: {nrow(sas_adrs)} records")

#=============================================================================
# COMPARISON 1: FULL DATASET COMPARISON
#=============================================================================

log_info("\nPerforming full dataset comparison with diffdf...")

full_comparison <- diffdf(
  base = sas_adrs,
  compare = r_adrs,
  keys = c("USUBJID", "PARAMCD", "ASEQ"),
  suppress_warnings = TRUE,
  tolerance = NUM_TOLERANCE
)

full_match <- print_comparison_summary(full_comparison, "FULL ADRS")

# Save full comparison report
full_report_path <- file.path(qc_output_dir, "adrs_full_comparison.txt")
sink(full_report_path)
print(full_comparison)
sink()
log_info("Full comparison report saved: {full_report_path}")

#=============================================================================
# COMPARISON 2: BEST OVERALL RESPONSE (BOR) FOCUS
#=============================================================================

log_info("\nPerforming BOR-specific comparison...")

# Filter to BOR records only
r_bor <- r_adrs %>% filter(PARAMCD == "BOR")
sas_bor <- sas_adrs %>% filter(PARAMCD == "BOR")

log_info("R BOR records: {nrow(r_bor)}")
log_info("SAS BOR records: {nrow(sas_bor)}")

bor_comparison <- diffdf(
  base = sas_bor,
  compare = r_bor,
  keys = c("USUBJID"),
  suppress_warnings = TRUE,
  tolerance = NUM_TOLERANCE
)

bor_match <- print_comparison_summary(bor_comparison, "BEST OVERALL RESPONSE")

# Save BOR comparison report
bor_report_path <- file.path(qc_output_dir, "bor_comparison.txt")
sink(bor_report_path)
print(bor_comparison)
sink()
log_info("BOR comparison report saved: {bor_report_path}")

#=============================================================================
# COMPARISON 3: AGREEMENT RATE ANALYSIS
#=============================================================================

log_info("\nCalculating agreement rates for key variables...")

key_vars <- c("USUBJID", "PARAMCD")
compare_vars <- c("AVALC", "AVAL", "ADY", "AVISIT")

agreement_stats <- calculate_agreement_rate(
  r_data = r_adrs,
  sas_data = sas_adrs,
  key_vars = key_vars,
  compare_vars = compare_vars
)

cat("\n", strrep("=", 70), "\n", sep = "")
cat(" AGREEMENT RATE SUMMARY\n")
cat(strrep("=", 70), "\n")
print(agreement_stats, n = Inf)

# Save agreement statistics
agreement_path <- file.path(qc_output_dir, "agreement_statistics.csv")
write.csv(agreement_stats, agreement_path, row.names = FALSE)
log_info("Agreement statistics saved: {agreement_path}")

#=============================================================================
# COMPARISON 4: BOR CONCORDANCE TABLE
#=============================================================================

log_info("\nGenerating BOR concordance table...")

bor_concordance <- inner_join(
  r_bor %>% select(USUBJID, AVALC),
  sas_bor %>% select(USUBJID, AVALC),
  by = "USUBJID",
  suffix = c("_R", "_SAS")
) %>%
  count(AVALC_R, AVALC_SAS, name = "N") %>%
  pivot_wider(
    names_from = AVALC_SAS,
    values_from = N,
    values_fill = 0
  )

cat("\n", strrep("=", 70), "\n", sep = "")
cat(" BOR CONCORDANCE TABLE (R vs SAS)\n")
cat(strrep("=", 70), "\n")
print(bor_concordance, n = Inf)

# Save concordance table
concordance_path <- file.path(qc_output_dir, "bor_concordance.csv")
write.csv(bor_concordance, concordance_path, row.names = FALSE)
log_info("BOR concordance table saved: {concordance_path}")

#=============================================================================
# FINAL SUMMARY
#=============================================================================

cat("\n", strrep("=", 70), "\n", sep = "")
cat(" QC COMPARISON SUMMARY\n")
cat(strrep("=", 70), "\n")
cat(sprintf("Full Dataset Match: %s\n", if (full_match) "✅ YES" else "❌ NO"))
cat(sprintf("BOR Match: %s\n", if (bor_match) "✅ YES" else "❌ NO"))
cat(sprintf("\nReports generated in: %s\n", qc_output_dir))
cat("  - adrs_full_comparison.txt\n")
cat("  - bor_comparison.txt\n")
cat("  - agreement_statistics.csv\n")
cat("  - bor_concordance.csv\n")
cat(strrep("=", 70), "\n\n")

if (full_match && bor_match) {
  log_info("✅ QC PASSED: R and SAS outputs match perfectly")
  quit(status = 0)
} else {
  log_warn("⚠️  QC REVIEW NEEDED: Differences detected between R and SAS")
  quit(status = 1)
}
