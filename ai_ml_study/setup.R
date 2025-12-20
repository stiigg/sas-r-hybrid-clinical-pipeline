#!/usr/bin/env Rscript
# One-Click Setup for AI/ML Study Module
# Installs all required R packages for the three projects

cat("\n")
cat("==========================================================\n")
cat("  AI/ML Study Module Setup                                \n")
cat("  SAS-R Hybrid Clinical Pipeline                          \n")
cat("==========================================================\n\n")

# ============================================================================
# Check R Version
# ============================================================================

r_version <- as.numeric(paste0(R.version$major, ".", R.version$minor))

if (r_version < 4.0) {
  cat("⚠️  Warning: R version", r_version, "detected.\n")
  cat("   Recommended: R >= 4.2 for best compatibility\n\n")
} else {
  cat("✓ R version", r_version, "- OK\n\n")
}

# ============================================================================
# Define Required Packages
# ============================================================================

cat("Checking required packages...\n\n")

packages <- list(
  # Core data manipulation
  core = c("tidyverse", "data.table", "lubridate"),
  
  # Machine Learning (Project 1: Progression Prediction)
  ml = c("xgboost", "randomForest", "caret", "recipes", "pROC"),
  
  # Dashboard (Project 2: Quality Monitoring)
  dashboard = c("shiny", "shinydashboard", "plotly", "DT", "yaml"),
  
  # NLP Support (Project 3: Adverse Events - Optional)
  nlp = c("reticulate", "text", "tokenizers", "stringdist", "fuzzyjoin"),
  
  # Utilities
  utils = c("devtools", "roxygen2", "testthat")
)

# Flatten to single vector
all_packages <- unlist(packages, use.names = FALSE)

# ============================================================================
# Check Installed Packages
# ============================================================================

installed <- installed.packages()[, "Package"]
missing <- all_packages[!all_packages %in% installed]

if (length(missing) == 0) {
  cat("✓ All packages already installed!\n\n")
} else {
  cat(sprintf("📦 Need to install %d packages...\n\n", length(missing)))
  
  # ============================================================================
  # Install Missing Packages
  # ============================================================================
  
  cat("Installing from CRAN:\n")
  for (pkg in missing) {
    cat(sprintf("  - %s...", pkg))
    
    tryCatch({
      suppressMessages(
        install.packages(
          pkg, 
          repos = "https://cloud.r-project.org",
          quiet = TRUE,
          dependencies = TRUE
        )
      )
      cat(" ✓\n")
    }, error = function(e) {
      cat(" ✘ FAILED\n")
      cat(sprintf("    Error: %s\n", e$message))
    })
  }
  
  cat("\n")
}

# ============================================================================
# Verify Critical Packages
# ============================================================================

cat("Verifying critical packages...\n\n")

critical_packages <- c("tidyverse", "xgboost", "shiny")

for (pkg in critical_packages) {
  tryCatch({
    suppressPackageStartupMessages(library(pkg, character.only = TRUE))
    cat(sprintf("✓ %s loaded successfully\n", pkg))
  }, error = function(e) {
    cat(sprintf("✘ %s failed to load\n", pkg))
    cat(sprintf("  Error: %s\n", e$message))
  })
}

cat("\n")

# ============================================================================
# Optional: Python Setup for NLP Module
# ============================================================================

cat("==========================================================\n")
cat("Optional: Python Setup for NLP Module (Project 3)\n")
cat("==========================================================\n\n")

cat("Python environment setup is OPTIONAL and only needed for\n")
cat("Project 3 (NLP Adverse Events).\n\n")

cat("To setup Python for NLP later, run:\n")
cat("  Rscript ai_ml_study/04_nlp_adverse_events/setup_python.R\n\n")

# ============================================================================
# Create Output Directories
# ============================================================================

cat("Creating output directories...\n\n")

dirs_to_create <- c(
  "ai_ml_study/01_quick_demo/outputs",
  "ai_ml_study/02_progression_prediction/data",
  "ai_ml_study/02_progression_prediction/models",
  "ai_ml_study/02_progression_prediction/outputs",
  "ai_ml_study/03_quality_dashboard/data",
  "ai_ml_study/04_nlp_adverse_events/data",
  "ai_ml_study/04_nlp_adverse_events/models",
  "ai_ml_study/04_nlp_adverse_events/outputs"
)

for (dir_path in dirs_to_create) {
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    cat(sprintf("✓ Created: %s\n", dir_path))
  }
}

cat("\n")

# ============================================================================
# Setup Summary
# ============================================================================

cat("==========================================================\n")
cat("✓ Setup Complete!\n")
cat("==========================================================\n\n")

cat("Next Steps:\n\n")

cat("1. Run the Quick Demo (5 minutes):\n")
cat("   Rscript ai_ml_study/01_quick_demo/quick_demo.R\n\n")

cat("2. Explore Project 1 (Progression Prediction):\n")
cat("   cd ai_ml_study/02_progression_prediction\n")
cat("   See README.md for instructions\n\n")

cat("3. Launch Project 2 (Quality Dashboard):\n")
cat("   cd ai_ml_study/03_quality_dashboard\n")
cat("   Rscript -e 'shiny::runApp(\"app\")' \n\n")

cat("Documentation:\n")
cat("  - ai_ml_study/README.md (overview)\n")
cat("  - ai_ml_study/IMPLEMENTATION_GUIDE.md (technical details)\n\n")

cat("Questions? Check the README files in each module directory.\n\n")
