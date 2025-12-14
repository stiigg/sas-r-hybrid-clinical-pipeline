#!/bin/bash
################################################################################
# Script: run_sas_qc.sh
# Purpose: Orchestrate all SAS PROC COMPARE QC validations
# Author: Christian Baghai
# Date: 2025-12-14
#
# Usage: 
#   chmod +x qc/run_sas_qc.sh
#   ./qc/run_sas_qc.sh
#
# Output:
#   - Individual SAS logs for each comparison
#   - HTML reports in outputs/qc_reports/
#   - Overall pass/fail status
################################################################################

echo "=========================================="
echo "SAS QC Comparison Suite"
echo "Date: $(date +%Y-%m-%d)"
echo "Time: $(date +%H:%M:%S)"
echo "=========================================="
echo ""

# Create necessary directories
mkdir -p logs
mkdir -p outputs/qc_reports

# Initialize status tracking
OVERALL_STATUS="PASS"
FAILED_DATASETS=""

# Define log file names with timestamps
LOG_DATE=$(date +%Y%m%d_%H%M%S)
LOG_DIR="logs"

echo "[INFO] Running ADSL comparison..."
sas qc/sas/compare_adsl.sas -log ${LOG_DIR}/qc_adsl_${LOG_DATE}.log -print ${LOG_DIR}/qc_adsl_${LOG_DATE}.lst

if grep -qi "ERROR:" ${LOG_DIR}/qc_adsl_${LOG_DATE}.log; then
    echo "[FAIL] ADSL comparison failed - check log for details"
    OVERALL_STATUS="FAIL"
    FAILED_DATASETS="${FAILED_DATASETS} ADSL"
else
    echo "[PASS] ADSL comparison completed successfully"
fi
echo ""

echo "[INFO] Running ADRS comparison..."
sas qc/sas/compare_adrs.sas -log ${LOG_DIR}/qc_adrs_${LOG_DATE}.log -print ${LOG_DIR}/qc_adrs_${LOG_DATE}.lst

if grep -qi "ERROR:" ${LOG_DIR}/qc_adrs_${LOG_DATE}.log; then
    echo "[FAIL] ADRS comparison failed - check log for details"
    OVERALL_STATUS="FAIL"
    FAILED_DATASETS="${FAILED_DATASETS} ADRS"
else
    echo "[PASS] ADRS comparison completed successfully"
fi
echo ""

echo "[INFO] Running ADTTE comparison..."
sas qc/sas/compare_adtte.sas -log ${LOG_DIR}/qc_adtte_${LOG_DATE}.log -print ${LOG_DIR}/qc_adtte_${LOG_DATE}.lst

if grep -qi "ERROR:" ${LOG_DIR}/qc_adtte_${LOG_DATE}.log; then
    echo "[FAIL] ADTTE comparison failed - check log for details"
    OVERALL_STATUS="FAIL"
    FAILED_DATASETS="${FAILED_DATASETS} ADTTE"
else
    echo "[PASS] ADTTE comparison completed successfully"
fi
echo ""

echo "=========================================="
echo "SAS QC Comparison Summary"
echo "=========================================="
echo "Overall Status: ${OVERALL_STATUS}"

if [ "$OVERALL_STATUS" = "FAIL" ]; then
    echo "Failed Datasets:${FAILED_DATASETS}"
    echo ""
    echo "Action Required:"
    echo "  1. Review discrepancy reports in outputs/qc_reports/"
    echo "  2. Check SAS logs in logs/ directory"
    echo "  3. Investigate and resolve differences"
    echo "  4. Re-run QC comparison after fixes"
    echo "=========================================="
    exit 1
else
    echo "✓ All QC comparisons PASSED"
    echo "✓ Production and QC datasets are identical"
    echo "✓ Ready for validation sign-off"
    echo "=========================================="
    exit 0
fi
