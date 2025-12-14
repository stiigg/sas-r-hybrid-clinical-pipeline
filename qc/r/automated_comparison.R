# Automated QC Comparison Framework
# Uses diffdf package for pharmaceutical-grade dataset comparison

library(diffdf)
library(haven)
library(dplyr)
library(purrr)
library(tibble)

#' Compare production and QC datasets with automated reporting
#'
#' @param prod_path Path to production dataset (SAS or CSV)
#' @param qc_path Path to QC dataset (SAS or CSV)
#' @param dataset_name Dataset identifier for reporting
#' @param key_vars Character vector of key variables for comparison
#' @param tolerances Named list of numeric tolerances (default 0.001)
#'
#' @return List containing comparison results and report path
compare_adam_datasets <- function(prod_path, 
                                 qc_path, 
                                 dataset_name, 
                                 key_vars,
                                 tolerances = NULL) {
  
  # Load datasets based on file extension
  prod <- if (grepl("\\.sas7bdat$", prod_path)) {
    read_sas(prod_path)
  } else {
    read.csv(prod_path, stringsAsFactors = FALSE)
  }
  
  qc <- if (grepl("\\.sas7bdat$", qc_path)) {
    read_sas(qc_path)
  } else {
    read.csv(qc_path, stringsAsFactors = FALSE)
  }
  
  # Default numeric tolerance if not specified
  if (is.null(tolerances)) {
    tolerances <- list(
      AVAL = 0.001,
      CHG = 0.001,
      PCHG = 0.01,
      SLD = 0.1,
      LDIAM = 0.1,
      BASE = 0.001
    )
  }
  
  # Execute diffdf comparison
  comparison <- tryCatch({
    diffdf(
      base = prod,
      compare = qc,
      keys = key_vars,
      tolerance = tolerances,
      suppress_warnings = FALSE,
      strict_numeric = TRUE,
      strict_factor = TRUE
    )
  }, error = function(e) {
    list(
      error = TRUE,
      message = as.character(e),
      VarDiff_Differences = data.frame()
    )
  })
  
  # Generate timestamped report path
  report_dir <- "outputs/qc"
  if (!dir.exists(report_dir)) {
    dir.create(report_dir, recursive = TRUE)
  }
  
  report_path <- sprintf("%s/%s_comparison_%s.html", 
                        report_dir,
                        dataset_name, 
                        format(Sys.Date(), "%Y%m%d"))
  
  # Generate HTML comparison report
  if (!isTRUE(comparison$error)) {
    create_output_table(comparison, output = report_path)
  }
  
  # Calculate difference metrics
  n_differences <- if (!is.null(comparison$VarDiff_Differences)) {
    nrow(comparison$VarDiff_Differences)
  } else {
    0
  }
  
  # Return structured results
  list(
    dataset = dataset_name,
    n_differences = n_differences,
    n_rows_prod = nrow(prod),
    n_rows_qc = nrow(qc),
    differences = comparison,
    report_path = report_path,
    status = if(n_differences == 0) "PASS" else "FAIL",
    timestamp = Sys.time()
  )
}

#' Execute QC comparison across multiple datasets using manifest
#'
#' @param manifest_path Path to comparison manifest CSV
#'
#' @return List of comparison results
execute_qc_manifest <- function(manifest_path = "qc/comparison_manifest.csv") {
  
  # Load comparison manifest
  if (!file.exists(manifest_path)) {
    message("Creating default comparison manifest...")
    create_default_manifest(manifest_path)
  }
  
  manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)
  
  # Parse key_vars (stored as comma-separated string)
  manifest$key_vars <- strsplit(manifest$key_vars, ",")
  
  # Execute all comparisons
  results <- manifest %>%
    pmap(function(dataset, prod_path, qc_path, key_vars, ...) {
      message(sprintf("Comparing %s...", dataset))
      compare_adam_datasets(prod_path, qc_path, dataset, key_vars)
    })
  
  # Generate summary report
  summary_df <- bind_rows(lapply(results, function(r) {
    tibble(
      dataset = r$dataset,
      n_differences = r$n_differences,
      status = r$status,
      report_path = r$report_path,
      timestamp = as.character(r$timestamp)
    )
  }))
  
  # Write summary CSV
  summary_path <- sprintf("outputs/qc/qc_summary_%s.csv", 
                         format(Sys.Date(), "%Y%m%d"))
  write.csv(summary_df, summary_path, row.names = FALSE)
  
  message(sprintf("\nQC Summary written to: %s", summary_path))
  message(sprintf("Total datasets compared: %d", nrow(summary_df)))
  message(sprintf("Passed: %d | Failed: %d", 
                 sum(summary_df$status == "PASS"),
                 sum(summary_df$status == "FAIL")))
  
  results
}

#' Create default comparison manifest template
#'
#' @param manifest_path Output path for manifest CSV
create_default_manifest <- function(manifest_path) {
  
  default_manifest <- tibble(
    dataset = c("adsl", "adrs", "adtte"),
    prod_path = c(
      "outputs/adam/adsl.sas7bdat",
      "outputs/adam/adrs.sas7bdat",
      "outputs/adam/adtte.sas7bdat"
    ),
    qc_path = c(
      "qc/outputs/adsl.sas7bdat",
      "qc/outputs/adrs.sas7bdat",
      "qc/outputs/adtte.sas7bdat"
    ),
    key_vars = c(
      "USUBJID",
      "USUBJID,PARAMCD,AVISIT",
      "USUBJID,PARAMCD"
    )
  )
  
  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  write.csv(default_manifest, manifest_path, row.names = FALSE)
  message(sprintf("Default manifest created: %s", manifest_path))
}

# Main execution when sourced
if (!interactive()) {
  message("==========================================")
  message("Automated QC Comparison Framework")
  message("==========================================\n")
  
  results <- execute_qc_manifest()
  
  # Exit with status code based on results
  all_passed <- all(sapply(results, function(r) r$status == "PASS"))
  quit(status = if (all_passed) 0 else 1)
}
