#!/bin/bash
# Bash script to run R-only clinical pipeline

echo "Installing pharmaverse packages..."
Rscript install_pharmaverse.R

echo "Running R-only pipeline in non-dry-run mode..."
export ETL_DRY_RUN=false
export QC_DRY_RUN=false
export TLF_DRY_RUN=false

Rscript -e "options(repos = c(CRAN = 'https://cloud.r-project.org')); source('run_all.R')"

echo "Pipeline execution complete!"
echo "Check outputs/ directory for generated files"
