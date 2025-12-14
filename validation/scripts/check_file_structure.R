#!/usr/bin/env Rscript
################################################################################
# Script: check_file_structure.R
# Purpose: Validate repository file structure for IQ protocol (IQ-004)
# Author: Christian Baghai
# Date: 2025-12-14
################################################################################

message("========================================")
message("File Structure Validation (IQ-004)")
message("========================================\n")

# Create evidence directory
if (!dir.exists("validation/evidence")) {
  dir.create("validation/evidence", recursive = TRUE)
}

sink("validation/evidence/iq_004_file_structure_check.txt", split = TRUE)

cat("Test Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Test ID: IQ-004\n")
cat("Test Description: Repository File Structure Integrity\n\n")

# Define critical files that must exist
critical_files <- c(
  # RECIST core derivation macros
  "etl/adam_program_library/oncology_response/recist_11_core/derive_target_lesion_response.sas",
  "etl/adam_program_library/oncology_response/recist_11_core/derive_non_target_lesion_response.sas",
  "etl/adam_program_library/oncology_response/recist_11_core/derive_overall_timepoint_response.sas",
  "etl/adam_program_library/oncology_response/recist_11_core/derive_best_overall_response.sas",
  
  # Test data
  "demo/data/comprehensive_sdtm_rs.csv",
  "demo/data/expected_bor_comprehensive.csv",
  "demo/simple_recist_demo.sas",
  
  # QC framework
  "qc/r/automated_comparison.R",
  "qc/sas/compare_adsl.sas",
  "qc/sas/compare_adrs.sas",
  "qc/sas/compare_adtte.sas",
  
  # Testing
  "tests/run_all_tests.R",
  "tests/testthat/test-recist-boundaries.R",
  "tests/testthat/test-recist-confirmation.R",
  
  # Validation
  "validation/iq_protocol.md",
  "validation/oq_protocol.md",
  "validation/pq_protocol.md",
  "validation/requirements_traceability_matrix.csv",
  
  # Documentation
  "README.md",
  "STATUS.md"
)

cat("========================================\n")
cat("Checking Critical Files\n")
cat("========================================\n\n")

results <- data.frame(
  File = critical_files,
  Exists = file.exists(critical_files),
  Status = ifelse(file.exists(critical_files), "PASS", "FAIL"),
  stringsAsFactors = FALSE
)

cat("File Validation Results:\n")
cat("--------------------------------------------------\n")
for (i in 1:nrow(results)) {
  status_symbol <- ifelse(results$Status[i] == "PASS", "✓", "✗")
  cat(sprintf("  %s %s\n", status_symbol, results$File[i]))
}

cat("\n")

# Summary
n_total <- nrow(results)
n_pass <- sum(results$Status == "PASS")
n_fail <- sum(results$Status == "FAIL")

cat("Summary:\n")
cat("  Total files checked:", n_total, "\n")
cat("  Present:", n_pass, "\n")
cat("  Missing:", n_fail, "\n\n")

if (n_fail > 0) {
  cat("[FAIL] Missing critical files:\n")
  missing <- results[results$Status == "FAIL", "File"]
  for (f in missing) {
    cat("  -", f, "\n")
  }
  cat("\n")
  overall_status <- "FAIL"
} else {
  cat("[PASS] All critical files present\n\n")
  overall_status <- "PASS"
}

# Check directory structure
cat("========================================\n")
cat("Directory Structure Check\n")
cat("========================================\n\n")

critical_dirs <- c(
  "etl/adam_program_library/oncology_response/recist_11_core",
  "etl/adam_program_library/oncology_response/time_to_event",
  "demo/data",
  "qc/r",
  "qc/sas",
  "tests/testthat",
  "validation",
  "validation/scripts",
  "validation/evidence"
)

for (d in critical_dirs) {
  exists <- dir.exists(d)
  status_symbol <- ifelse(exists, "✓", "✗")
  cat(sprintf("  %s %s/\n", status_symbol, d))
  if (!exists) overall_status <- "FAIL"
}

cat("\n")

# Overall Assessment
cat("========================================\n")
cat("Overall IQ-004 Assessment\n")
cat("========================================\n")
cat("OVERALL STATUS:", overall_status, "\n\n")

if (overall_status == "PASS") {
  cat("✓ File structure validation PASSED\n")
  cat("✓ Repository structure is complete and ready\n")
} else {
  cat("✗ File structure validation FAILED\n")
  cat("Action Required: Ensure all critical files are present\n")
}

cat("\n========================================\n")
cat("Evidence saved to: validation/evidence/iq_004_file_structure_check.txt\n")
cat("========================================\n")

sink()

if (overall_status == "PASS") {
  quit(status = 0)
} else {
  quit(status = 1)
}
