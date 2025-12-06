#!/bin/bash

# Portfolio-level pipeline runner
# Demonstrates multi-study coordination capability

set -e

echo "================================================="
echo "Clinical Trial Portfolio Pipeline Runner"
echo "================================================="
echo ""

# Default to dry-run unless explicitly disabled
export PORTFOLIO_DRY_RUN="${PORTFOLIO_DRY_RUN:-true}"
export PRIORITY_THRESHOLD="${PRIORITY_THRESHOLD:-3}"

echo "Configuration:"
echo "  PORTFOLIO_DRY_RUN: $PORTFOLIO_DRY_RUN"
echo "  PRIORITY_THRESHOLD: $PRIORITY_THRESHOLD"
echo ""

# Run portfolio orchestration
Rscript automation/portfolio_runner.R "$@"

echo ""
echo "Portfolio pipeline execution complete"
