#!/usr/bin/env Rscript
################################################################################
# Script: generate_coverage_report.R
# Purpose: Generate test coverage report for validation evidence
# Author: Christian Baghai
# Date: 2025-12-14
#
# Generates HTML coverage report showing which code is tested
# Required for regulatory validation documentation
################################################################################

message("========================================")
message("Test Coverage Report Generation")
message("========================================\n")

# Check if covr package is installed
if (!requireNamespace("covr", quietly = TRUE)) {
  message("Installing covr package...")
  install.packages("covr")
}

library(covr)

message("Calculating test coverage...\n")

# Calculate coverage for the entire package/repository
# Adjust path if your R code is in a specific directory
cov <- tryCatch({
  package_coverage(
    type = "tests",
    quiet = FALSE
  )
}, error = function(e) {
  message("Note: package_coverage() requires package structure.")
  message("Attempting alternative coverage calculation...\n")
  
  # Alternative: Calculate coverage for specific files
  file_coverage(
    source_files = list.files("R", pattern = "\\.R$", full.names = TRUE),
    test_files = list.files("tests/testthat", pattern = "^test.*\\.R$", full.names = TRUE)
  )
})

# Display coverage summary
message("\nCoverage Summary:\n")
print(cov)

# Generate HTML report
output_file <- "validation/test_coverage_report.html"

message("\nGenerating HTML coverage report...")

tryCatch({
  report(cov, file = output_file)
  message("✓ Coverage report saved: ", output_file, "\n")
}, error = function(e) {
  message("Error generating HTML report: ", e$message)
  message("Saving to alternative format...\n")
  
  # Alternative: Save as simple text summary
  sink("validation/test_coverage_summary.txt")
  cat("Test Coverage Summary\n")
  cat("=====================\n\n")
  cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
  print(cov)
  sink()
  
  message("✓ Coverage summary saved: validation/test_coverage_summary.txt\n")
})

# Calculate overall coverage percentage
coverage_pct <- percent_coverage(cov)

message("\n========================================")
message("Overall Test Coverage: ", round(coverage_pct, 1), "%")
message("========================================\n")

if (coverage_pct >= 80) {
  message("✓ Coverage meets acceptance criteria (≥80%)\n")
  quit(status = 0)
} else {
  message("⚠ Coverage below recommended threshold (target: 80%)\n")
  message("Action: Increase test coverage for critical functions\n")
  quit(status = 1)
}
