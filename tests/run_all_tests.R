#!/usr/bin/env Rscript
# Test Runner for RECIST 1.1 Derivation Pipeline
# Executes all unit tests and generates coverage reports

library(testthat)

message("==========================================")
message("RECIST 1.1 Unit Test Suite")
message("==========================================\n")

# Run all tests in testthat directory
test_results <- test_dir(
  "tests/testthat",
  reporter = "summary",
  stop_on_failure = FALSE
)

message("\n==========================================")
message("Test Summary")
message("==========================================\n")

# Extract test statistics
test_summary <- as.data.frame(test_results)

if (nrow(test_summary) > 0) {
  total_tests <- nrow(test_summary)
  passed_tests <- sum(test_summary$passed, na.rm = TRUE)
  failed_tests <- sum(test_summary$failed, na.rm = TRUE)
  skipped_tests <- sum(test_summary$skipped, na.rm = TRUE)
  
  message(sprintf("Total tests: %d", total_tests))
  message(sprintf("Passed: %d", passed_tests))
  message(sprintf("Failed: %d", failed_tests))
  message(sprintf("Skipped: %d", skipped_tests))
  
  if (failed_tests > 0) {
    message("\n[FAIL] Some tests failed. Review output above.\n")
  } else {
    message("\n[PASS] All tests passed successfully!\n")
  }
} else {
  message("No tests were executed.\n")
}

# Generate code coverage report (optional, requires covr package)
if (requireNamespace("covr", quietly = TRUE)) {
  message("\n==========================================")
  message("Code Coverage Analysis")
  message("==========================================\n")
  
  tryCatch({
    coverage_results <- covr::package_coverage(
      path = ".",
      type = "tests",
      code = c(
        "etl/adam_program_library/**/*.R",
        "qc/**/*.R"
      )
    )
    
    # Print coverage summary
    print(coverage_results)
    
    # Generate HTML coverage report
    coverage_report_path <- "validation/test_coverage_report.html"
    dir.create(dirname(coverage_report_path), 
              recursive = TRUE, 
              showWarnings = FALSE)
    
    covr::report(
      coverage_results, 
      file = coverage_report_path,
      browse = FALSE
    )
    
    message(sprintf("\nCoverage report generated: %s\n", coverage_report_path))
    
  }, error = function(e) {
    message(sprintf("Warning: Could not generate coverage report: %s\n", 
                   e$message))
  })
} else {
  message("\nNote: Install 'covr' package for code coverage analysis\n")
}

# Exit with appropriate status code
if (nrow(test_summary) > 0 && failed_tests > 0) {
  quit(status = 1)  # Non-zero exit for failures
} else {
  quit(status = 0)  # Success
}
