#!/usr/bin/env Rscript

# Quality control script for the ADaM ADSL dataset. The script is metadata-driven
# and relies on specs/adam_adsl_spec.csv plus specs/pipeline_paths.csv to locate
# the expected output directory. When the ADSL dataset is available it verifies
# that all required variables exist and reports missing fields. The script is
# resilient to missing optional tooling (e.g., the haven package) and will emit a
# structured summary regardless of the execution environment.

read_paths_manifest <- function(path = "specs/pipeline_paths.csv") {
  if (!file.exists(path)) {
    stop(sprintf("Pipeline paths manifest not found at %s", path), call. = FALSE)
  }
  manifest <- utils::read.csv(path, stringsAsFactors = FALSE)
  structure(manifest$value, names = manifest$key)
}

read_adsl_spec <- function(path = "specs/adam_adsl_spec.csv") {
  if (!file.exists(path)) {
    stop(sprintf("ADSL specification missing at %s", path), call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

check_adsl_dataset <- function(adam_dir, expected_vars) {
  dataset_path <- file.path(adam_dir, "adsl.sas7bdat")
  result <- list(
    dataset_path = dataset_path,
    status = "not_found",
    missing_variables = expected_vars,
    present_variables = character(0)
  )

  if (!file.exists(dataset_path)) {
    result$message <- sprintf("Dataset not available at %s", dataset_path)
    return(result)
  }

  if (!requireNamespace("haven", quietly = TRUE)) {
    result$status <- "haven_missing"
    result$message <- "Install the 'haven' package to inspect SAS datasets"
    return(result)
  }

  adsl <- haven::read_sas(dataset_path)
  vars <- names(adsl)
  missing_vars <- setdiff(expected_vars, vars)
  result$status <- if (length(missing_vars) == 0) "success" else "missing_columns"
  result$missing_variables <- missing_vars
  result$present_variables <- intersect(expected_vars, vars)
  result$message <- if (length(missing_vars) == 0) {
    sprintf("All %d expected variables present", length(expected_vars))
  } else {
    sprintf("%d variables missing: %s", length(missing_vars), paste(missing_vars, collapse = ", "))
  }
  result
}

run_adsl_qc <- function() {
  paths <- read_paths_manifest()
  adsl_spec <- read_adsl_spec()
  adam_dir <- paths[["adam_data_dir"]]
  if (is.null(adam_dir)) {
    stop("Path manifest does not define 'adam_data_dir'", call. = FALSE)
  }

  expected_vars <- unique(adsl_spec$target_var)
  qc_result <- check_adsl_dataset(adam_dir, expected_vars)

  summary <- list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    status = qc_result$status,
    dataset_path = qc_result$dataset_path,
    message = qc_result$message,
    missing_variables = qc_result$missing_variables,
    present_variables = qc_result$present_variables
  )

  output_dir <- file.path("outputs", "qc")
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  json_path <- file.path(output_dir, "adam_adsl_qc.json")
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    warning("jsonlite package is not installed; QC summary will be written as RDS")
    saveRDS(summary, file = sub("\\\\.json$", ".rds", json_path))
  } else {
    jsonlite::write_json(summary, json_path, auto_unbox = TRUE, pretty = TRUE)
  }

  summary
}

if (identical(environment(), globalenv()) && !interactive()) {
  result <- run_adsl_qc()
  str(result)
}
