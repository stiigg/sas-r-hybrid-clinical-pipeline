#!/usr/bin/env Rscript

# QC that reconciles derivation metadata across specs, YAML definitions and SAS
# implementation comments.

`%||%` <- function(x, y) ifelse(is.null(x) || length(x) == 0, y, x)

read_var_spec <- function(path) {
  if (!requireNamespace("readr", quietly = TRUE)) {
    stop("Package 'readr' is required to parse the variable specification.", call. = FALSE)
  }
  readr::read_csv(path, show_col_types = FALSE)
}

read_derivations <- function(path) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' is required to read derivation metadata.", call. = FALSE)
  }
  yaml::read_yaml(path)
}

extract_sas_derivation_ids <- function(dir_path = "etl/sas") {
  sas_files <- list.files(dir_path, pattern = "\\\.sas$", full.names = TRUE)
  ids <- character()
  for (f in sas_files) {
    lines <- readLines(f, warn = FALSE)
    matches <- regmatches(lines, gregexpr("DERIVATION_ID=([A-Za-z0-9\-]+)", lines))
    matches <- unlist(matches)
    if (length(matches) > 0) {
      ids <- c(ids, sub(".*DERIVATION_ID=([A-Za-z0-9\-]+).*", "\\1", matches))
    }
  }
  unique(ids)
}

qc_check_derivation_coverage <- function(
  deriv_path = "specs/common/derivations.yml",
  var_spec_path = "specs/adam/adam_variable_spec.csv",
  sas_dir = "etl/sas",
  output_path = "outputs/qc/derivation_coverage.json"
) {
  spec <- read_var_spec(var_spec_path)
  deriv <- read_derivations(deriv_path)
  ids_yaml <- names(deriv)

  derived_spec <- spec[tolower(spec$origin) == "derived", , drop = FALSE]
  ids_spec <- na.omit(unique(derived_spec$derivation_id))
  missing_id <- derived_spec$var[is.na(derived_spec$derivation_id) | derived_spec$derivation_id == ""]
  missing_id <- unique(missing_id)

  unknown_spec_ids <- setdiff(ids_spec, ids_yaml)
  ids_sas <- extract_sas_derivation_ids(sas_dir)
  sas_missing_yaml <- setdiff(ids_sas, ids_yaml)

  summary <- list(
    derived_variables_without_id = missing_id,
    spec_ids_missing_in_yaml = unknown_spec_ids,
    sas_ids_missing_in_yaml = sas_missing_yaml,
    spec_ids = ids_spec,
    yaml_ids = ids_yaml,
    sas_ids = ids_sas
  )

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    warning("jsonlite package missing; writing RDS summary")
    saveRDS(summary, sub("\\\.json$", ".rds", output_path))
  } else {
    jsonlite::write_json(summary, output_path, auto_unbox = TRUE, pretty = TRUE)
  }
  invisible(summary)
}

if (identical(environment(), globalenv()) && !interactive()) {
  qc_check_derivation_coverage()
}
