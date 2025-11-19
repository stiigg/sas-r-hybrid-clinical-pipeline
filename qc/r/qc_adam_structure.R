#!/usr/bin/env Rscript

# Structural QC that reconciles specs/adam/adam_variable_spec.csv with the
# materialised ADaM datasets. The script reports variable-level gaps and basic
# type mismatches and writes a CSV summary under outputs/qc.

suppressPackageStartupMessages({
  if (!requireNamespace("readr", quietly = TRUE)) {
    stop("Package 'readr' is required for ADaM structure QC.", call. = FALSE)
  }
})

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

resolve_dataset_path <- function(dataset, adam_dir) {
  base <- tolower(dataset)
  candidates <- file.path(adam_dir, paste0(base, c(".xpt", ".sas7bdat")))
  existing <- candidates[file.exists(candidates)]
  if (length(existing) > 0) existing[[1]] else candidates[[1]]
}

load_dataset <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  if (!requireNamespace("haven", quietly = TRUE)) {
    stop("Package 'haven' is required to read ADaM datasets.", call. = FALSE)
  }
  if (grepl("\\.xpt$", path, ignore.case = TRUE)) {
    haven::read_xpt(path)
  } else {
    haven::read_sas(path)
  }
}

qc_check_adam_structure <- function(
  var_spec_path = "specs/adam/adam_variable_spec.csv",
  adam_dir = "data/adam",
  output_path = "outputs/qc/adam_structure_checks.csv"
) {
  spec <- readr::read_csv(var_spec_path, show_col_types = FALSE)
  datasets <- unique(spec$dataset)
  results <- lapply(datasets, function(ds) {
    ds_spec <- spec[spec$dataset == ds, , drop = FALSE]
    expected_types <- setNames(ds_spec$type, ds_spec$var)
    dataset_path <- resolve_dataset_path(ds, adam_dir)
    dat <- load_dataset(dataset_path)
    if (is.null(dat)) {
      return(list(data.frame(
        dataset = ds,
        variable = ds_spec$var,
        issue = sprintf("Dataset missing at %s", dataset_path),
        stringsAsFactors = FALSE
      )))
    }
    lapply(names(expected_types), function(var) {
      if (!var %in% names(dat)) {
        return(data.frame(dataset = ds, variable = var, issue = "variable_missing", stringsAsFactors = FALSE))
      }
      val <- dat[[var]]
      type <- expected_types[[var]]
      is_ok <- switch(
        tolower(type),
        num = is.numeric(val),
        char = is.character(val) || is.factor(val),
        TRUE
      )
      if (!is_ok) {
        issue <- sprintf("type_mismatch (expected %s)", type)
      } else {
        issue <- "ok"
      }
      data.frame(dataset = ds, variable = var, issue = issue, stringsAsFactors = FALSE)
    })
  })
  flat <- do.call(c, results)
  results <- do.call(rbind, flat)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(results, output_path)
  invisible(results)
}

if (identical(environment(), globalenv()) && !interactive()) {
  qc_check_adam_structure()
}
