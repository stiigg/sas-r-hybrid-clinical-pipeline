################################################################################
# Script: compare_imwg_datasets.R
# Purpose: QC comparison of SAS vs R IMWG response derivations using diffdf
# Author: Christian Baghai
# Date: December 2025
#
# PARALLEL TO: qc/compare_recist_datasets.R (your existing QC script)
################################################################################

library(diffdf)
library(haven)
library(dplyr)

# Paths
repo_root <- here::here()
adam_path <- file.path(repo_root, "outputs", "adam")
qc_path <- file.path(repo_root, "qc", "reports")

cat("\n========================================\n")
cat("IMWG Response QC Comparison\n")
cat("========================================\n\n")

################################################################################
# Load datasets
################################################################################

cat("Loading SAS-derived IMWG response...\n")
adrs_sas <- haven::read_xpt(file.path(adam_path, "adrs_imwg_sas.xpt"))

cat("Loading R-derived IMWG response...\n")
adrs_r <- haven::read_xpt(file.path(adam_path, "adrs_imwg_admiral.xpt"))

################################################################################
# Perform diffdf comparison
################################################################################

cat("\nPerforming variable-by-variable comparison...\n")

# Run diffdf with tolerance for numeric variables
diff_result <- diffdf::diffdf(
  base = adrs_sas,
  compare = adrs_r,
  keys = c("USUBJID", "VISIT"),
  tolerance = 1e-6,  # Tolerance for floating-point differences
  suppress_warnings = FALSE
)

################################################################################
# Generate HTML report
################################################################################

cat("\nGenerating HTML QC report...\n")

# Create summary
discrepancy_count <- length(diff_result$VarDiff_Variables)

html_content <- sprintf('
<!DOCTYPE html>
<html>
<head>
  <title>IMWG Response QC Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #0366d6; }
    .pass { color: green; font-weight: bold; }
    .fail { color: red; font-weight: bold; }
    table { border-collapse: collapse; width: 100%%; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
  </style>
</head>
<body>
  <h1>IMWG Response QC Comparison Report</h1>
  <p><strong>Generated:</strong> %s</p>
  <p><strong>SAS Dataset:</strong> adrs_imwg_sas.xpt (%d records)</p>
  <p><strong>R Dataset:</strong> adrs_imwg_admiral.xpt (%d records)</p>
  
  <h2>Summary</h2>
  %s
  
  <h2>Variable Comparison</h2>
  <pre>%s</pre>
  
  <h2>Response Distribution Comparison</h2>
  <table>
    <tr>
      <th>IMWG Response</th>
      <th>SAS Count</th>
      <th>R Count</th>
      <th>Match</th>
    </tr>
    %s
  </table>
</body>
</html>
',
  format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  nrow(adrs_sas),
  nrow(adrs_r),
  ifelse(discrepancy_count == 0,
         '<p class="pass">✓ NO DISCREPANCIES FOUND</p>',
         sprintf('<p class="fail">✗ %d VARIABLE(S) WITH DISCREPANCIES</p>', discrepancy_count)),
  paste(capture.output(print(diff_result)), collapse = "\n"),
  paste(
    # Response distribution table rows
    sapply(unique(c(adrs_sas$IMWG_RESP, adrs_r$IMWG_RESP)), function(resp) {
      sas_count <- sum(adrs_sas$IMWG_RESP == resp, na.rm = TRUE)
      r_count <- sum(adrs_r$IMWG_RESP == resp, na.rm = TRUE)
      match_icon <- ifelse(sas_count == r_count, "✓", "✗")
      sprintf("<tr><td>%s</td><td>%d</td><td>%d</td><td>%s</td></tr>",
              resp, sas_count, r_count, match_icon)
    }),
    collapse = "\n"
  )
)

# Write HTML report
report_file <- file.path(qc_path, "imwg_qc_report.html")
writeLines(html_content, report_file)

cat("HTML report saved:", report_file, "\n")

################################################################################
# Console summary
################################################################################

cat("\n========================================\n")
cat("QC Comparison Complete\n")
cat("========================================\n")
if (discrepancy_count == 0) {
  cat("✓ All variables match between SAS and R\n")
} else {
  cat(sprintf("✗ %d variable(s) with discrepancies\n", discrepancy_count))
  cat("Review HTML report for details\n")
}
cat("========================================\n\n")
