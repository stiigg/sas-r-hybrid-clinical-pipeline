#!/usr/bin/env Rscript
# One-click setup for AI/ML study module
# Run this first: Rscript setup.R

cat("\n")
cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║  AI/ML Module Setup for RECIST Clinical Pipeline          ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Check R version
r_version <- paste(R.version$major, R.version$minor, sep = ".")
cat(sprintf("→ R version: %s\n", r_version))

if (as.numeric(R.version$major) < 4) {
  warning("⚠ R version 4.0+ recommended. You may encounter compatibility issues.")
}

# Install required packages
cat("\n→ Installing R packages (this may take 5-10 minutes)...\n\n")

required_packages <- c(
  # Core data manipulation
  "tidyverse", "data.table", "lubridate",
  
  # Machine learning
  "xgboost", "randomForest", "caret", "recipes", "pROC",
  
  # Visualization and dashboard
  "shiny", "shinydashboard", "plotly", "DT", "ggplot2",
  
  # Text processing
  "stringdist", "fuzzyjoin", "tokenizers",
  
  # Utilities
  "yaml", "jsonlite"
)

# Check which packages are already installed
installed <- installed.packages()[, "Package"]
to_install <- required_packages[!required_packages %in% installed]

if (length(to_install) > 0) {
  cat(sprintf("Installing %d packages:\n", length(to_install)))
  cat(paste("  -", to_install, collapse = "\n"), "\n\n")
  
  install.packages(
    to_install,
    repos = "https://cloud.r-project.org",
    dependencies = TRUE
  )
} else {
  cat("✓ All required R packages already installed!\n\n")
}

# Verify installations
cat("\n→ Verifying installations...\n")
failed_packages <- c()

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    failed_packages <- c(failed_packages, pkg)
    cat(sprintf("  ✗ %s\n", pkg))
  } else {
    cat(sprintf("  ✓ %s\n", pkg))
  }
}

if (length(failed_packages) > 0) {
  cat("\n⚠ Some packages failed to install:\n")
  cat(paste("  -", failed_packages, collapse = "\n"), "\n")
  cat("\nTry installing manually:\n")
  cat(sprintf("install.packages(c('%s'))\n", paste(failed_packages, collapse = "', '")))
} else {
  cat("\n✓ All packages installed successfully!\n")
}

cat("\n")
cat("╔════════════════════════════════════════════════════════════╗\n")
cat("║  Setup Complete!                                           ║\n")
cat("╚════════════════════════════════════════════════════════════╝\n")
cat("\n")
cat("Next steps:\n")
cat("1. Run: Rscript examples/baby_steps.R (2 minutes)\n")
cat("2. Explore: cd 1_progression_prediction && Rscript scripts/run_all.R\n")
cat("3. Check each project's README.md for details\n")
cat("\n")
cat("Happy coding! 🚀\n\n")
