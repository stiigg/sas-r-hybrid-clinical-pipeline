#!/usr/bin/env Rscript

# Thin wrapper delegating to the project-specific package API.
if (!requireNamespace("sasrhybrid", quietly = TRUE)) {
  stop("Package 'sasrhybrid' must be installed or loaded to run this script.", call. = FALSE)
}

sasrhybrid::build_adam_pharmaverse()
