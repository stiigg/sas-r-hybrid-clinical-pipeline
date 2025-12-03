#!/usr/bin/env Rscript

# Install pharmaverse packages required for R-only clinical trial programming
# Run this once before executing the pipeline in non-dry-run mode

# Core pharmaverse packages for SDTM/ADaM creation
pharmaverse_pkgs <- c(
  "admiral",        # ADaM dataset derivation
  "admiralonco",    # Oncology-specific ADaM extensions
  "metatools",      # Metadata management
  "metacore",       # Metadata specifications
  "xportr",         # CDISC XPT file exports
  "sdtm.oak"        # SDTM domain generation (available on CRAN)
)

# Supporting tidyverse packages (if not already installed)
tidyverse_pkgs <- c(
  "dplyr",
  "tidyr",
  "purrr",
  "readr",
  "stringr",
  "tibble",
  "haven"           # SAS dataset compatibility
)

# Install function with error handling
install_safe <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("Installing %s...", pkg))
    tryCatch(
      install.packages(pkg, repos = "https://cloud.r-project.org"),
      error = function(e) {
        warning(sprintf("Failed to install %s: %s", pkg, e$message))
      }
    )
  } else {
    message(sprintf("%s already installed", pkg))
  }
}

# Install all packages
message("Installing pharmaverse ecosystem...")
invisible(lapply(pharmaverse_pkgs, install_safe))

message("Installing supporting tidyverse packages...")
invisible(lapply(tidyverse_pkgs, install_safe))

message("\nVerifying installations...")
missing <- c(pharmaverse_pkgs, tidyverse_pkgs)[
  !vapply(c(pharmaverse_pkgs, tidyverse_pkgs),
          requireNamespace,
          logical(1),
          quietly = TRUE)
]

if (length(missing) > 0) {
  warning(sprintf(
    "The following packages failed to install: %s\n",
    paste(missing, collapse = ", ")
  ))
} else {
  message("All pharmaverse packages successfully installed!")
}
