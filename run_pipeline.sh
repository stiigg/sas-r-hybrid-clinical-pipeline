#!/usr/bin/env bash

# Default to safe dry-run unless user overrides externally
export ETL_DRY_RUN="${ETL_DRY_RUN:-true}"
export QC_DRY_RUN="${QC_DRY_RUN:-true}"
export TLF_DRY_RUN="${TLF_DRY_RUN:-true}"

if ! command -v Rscript >/dev/null 2>&1; then
  echo "Error: Rscript is not available on PATH. Please install R first."
  exit 1
fi

echo "Running sas-r-hybrid-clinical-pipeline with:"
echo "  ETL_DRY_RUN=$ETL_DRY_RUN"
echo "  QC_DRY_RUN=$QC_DRY_RUN"
echo "  TLF_DRY_RUN=$TLF_DRY_RUN"

Rscript run_all.R
