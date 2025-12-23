#!/usr/bin/env Rscript
#=============================================================================
# PHARMAVERSE PACKAGE INSTALLER
# Installs all required packages for CDISC 360i automation
#=============================================================================

message("Installing pharmaverse packages for CDISC 360i automation...")

# Core pharmaverse packages
core_pkgs <- c(
  # SDTM automation - THE KEY PACKAGE
  "sdtm.oak",           # 22 pre-built SDTM algorithms
  
  # ADaM automation
  "admiral",            # Core ADaM functions
  "admiralonco",        # Oncology-specific (RECIST, BOR, PFS, DoR)
  
  # Supporting infrastructure
  "pharmaversesdtm",    # Test SDTM datasets
  "pharmaverseadam",    # Test ADaM datasets  
  "metacore",           # Metadata management
  "metatools",          # Metadata utilities
  "xportr",             # XPT creation with validation
  
  # Quality & validation
  "diffdf",             # Dataset comparison for QC
  "testthat"            # Automated testing
)

# Additional supporting packages
support_pkgs <- c(
  "here",               # Path management
  "logger",             # Logging
  "cli",                # CLI interface
  "haven",              # SAS file I/O
  "readr",              # CSV reading
  "dplyr",              # Data manipulation
  "tidyr",              # Data tidying
  "lubridate",          # Date handling
  "stringr",            # String manipulation
  "purrr",              # Functional programming
  "rlang",              # R language features
  "glue"                # String interpolation
)

# Shiny dashboard packages
shiny_pkgs <- c(
  "shiny",
  "DT",
  "ggplot2",
  "plotly",
  "scales",
  "bslib"
)

all_pkgs <- c(core_pkgs, support_pkgs, shiny_pkgs)

# Install packages
for (pkg in all_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("Installing %s...", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  } else {
    message(sprintf("✓ %s already installed", pkg))
  }
}

message("\n✅ All pharmaverse packages installed successfully!")
message("\nNext steps:")
message("  1. Install Python tools: pip install cdisc-rules-engine odmlib")
message("  2. Run: ./run_all.R")
