#!/usr/bin/env Rscript
################################################################################
# Script: check_r_env.R
# Purpose: Validate R environment for IQ protocol (IQ-002)
# Author: Christian Baghai
# Date: 2025-12-14
#
# Checks:
#   - R version >= 4.2.0
#   - Required packages installed with correct versions
#   - No dependency conflicts
#
# Output:
#   - Console summary with PASS/FAIL status
#   - Detailed report: validation/evidence/iq_002_r_env_check.txt
################################################################################

message("========================================")
message("R Environment Validation (IQ-002)")
message("========================================\n")

# Create evidence directory if needed
if (!dir.exists("validation/evidence")) {
  dir.create("validation/evidence", recursive = TRUE)
}

# Capture output to file
sink("validation/evidence/iq_002_r_env_check.txt", split = TRUE)

cat("Test Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Test ID: IQ-002\n")
cat("Test Description: R Package Installation Verification\n\n")

# Check 1: R Version
cat("========================================\n")
cat("Check 1: R Version\n")
cat("========================================\n")

r_version <- R.version.string
cat("Detected R version:", r_version, "\n")

r_version_num <- as.numeric(paste0(R.version$major, ".", R.version$minor))
min_r_version <- 4.2

if (r_version_num >= min_r_version) {
  cat("[PASS] R version meets minimum requirement (>=", min_r_version, ")\n\n")
  r_version_status <- "PASS"
} else {
  cat("[FAIL] R version too low. Required:", min_r_version, "Detected:", r_version_num, "\n\n")
  r_version_status <- "FAIL"
}

# Check 2: Required Packages
cat("========================================\n")
cat("Check 2: Required Package Installation\n")
cat("========================================\n")

required_packages <- data.frame(
  Package = c("admiral", "dplyr", "haven", "testthat", 
              "diffdf", "yaml", "lubridate"),
  MinVersion = c("0.10.0", "1.1.0", "2.5.0", "3.1.0", 
                 "1.0.0", "2.3.0", "1.9.0"),
  stringsAsFactors = FALSE
)

installed <- as.data.frame(installed.packages()[, c("Package", "Version")], 
                          stringsAsFactors = FALSE)

results <- merge(required_packages, installed, by = "Package", all.x = TRUE)

results$Status <- ifelse(
  is.na(results$Version), 
  "MISSING",
  ifelse(
    package_version(results$Version) >= package_version(results$MinVersion),
    "PASS",
    "VERSION TOO LOW"
  )
)

cat("\nPackage Validation Results:\n")
cat("--------------------------------------------------\n")
print(results, row.names = FALSE)
cat("\n")

# Summary statistics
n_total <- nrow(results)
n_pass <- sum(results$Status == "PASS")
n_fail <- sum(results$Status != "PASS")

cat("Summary:\n")
cat("  Total packages checked:", n_total, "\n")
cat("  Passed:", n_pass, "\n")
cat("  Failed:", n_fail, "\n\n")

if (all(results$Status == "PASS")) {
  cat("[PASS] All required packages installed with correct versions\n\n")
  package_status <- "PASS"
} else {
  cat("[FAIL] Package installation issues detected\n")
  cat("\nFailed packages:\n")
  print(results[results$Status != "PASS", ], row.names = FALSE)
  cat("\n")
  package_status <- "FAIL"
}

# Check 3: Dependency Conflicts
cat("========================================\n")
cat("Check 3: Dependency Conflicts\n")
cat("========================================\n")

cat("Checking for package dependency conflicts...\n")

# Attempt to load all packages
conflict_found <- FALSE
for (pkg in required_packages$Package) {
  if (results$Status[results$Package == pkg] == "PASS") {
    tryCatch({
      suppressPackageStartupMessages(library(pkg, character.only = TRUE))
      cat("  ✓", pkg, "loaded successfully\n")
    }, error = function(e) {
      cat("  ✗", pkg, "failed to load:", e$message, "\n")
      conflict_found <<- TRUE
    })
  }
}

cat("\n")

if (!conflict_found) {
  cat("[PASS] No dependency conflicts detected\n\n")
  dependency_status <- "PASS"
} else {
  cat("[FAIL] Dependency conflicts detected\n\n")
  dependency_status <- "FAIL"
}

# Overall Assessment
cat("========================================\n")
cat("Overall IQ-002 Assessment\n")
cat("========================================\n")

overall_status <- ifelse(
  r_version_status == "PASS" && 
  package_status == "PASS" && 
  dependency_status == "PASS",
  "PASS",
  "FAIL"
)

cat("R Version Check:", r_version_status, "\n")
cat("Package Installation:", package_status, "\n")
cat("Dependency Conflicts:", dependency_status, "\n")
cat("\n")
cat("OVERALL STATUS:", overall_status, "\n")

if (overall_status == "PASS") {
  cat("\n✓ R environment validation PASSED\n")
  cat("✓ Environment is ready for RECIST 1.1 pipeline execution\n")
} else {
  cat("\n✗ R environment validation FAILED\n")
  cat("Action Required: Install/update required packages\n")
  cat("\nInstallation commands:\n")
  for (i in 1:nrow(results)) {
    if (results$Status[i] != "PASS") {
      cat("  install.packages('", results$Package[i], "')\n", sep = "")
    }
  }
}

cat("\n========================================\n")
cat("Evidence saved to: validation/evidence/iq_002_r_env_check.txt\n")
cat("========================================\n")

sink()

# Return appropriate exit code
if (overall_status == "PASS") {
  quit(status = 0)
} else {
  quit(status = 1)
}
