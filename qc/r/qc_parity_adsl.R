#!/usr/bin/env Rscript

# Lightweight parity check between SAS- and R-authored versions of ADSL.

if (!requireNamespace("readr", quietly = TRUE)) {
  stop("Package 'readr' is required for the parity check.", call. = FALSE)
}

require_parity_pkgs <- function() {
  if (!requireNamespace("haven", quietly = TRUE)) {
    stop("Package 'haven' is required for the parity check.", call. = FALSE)
  }
}

read_adsl_version <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  require_parity_pkgs()
  if (grepl("\\.xpt$", path, ignore.case = TRUE)) {
    haven::read_xpt(path)
  } else {
    haven::read_sas(path)
  }
}

align_dataset <- function(df, key = "USUBJID") {
  if (is.null(df)) return(NULL)
  if (!key %in% names(df)) {
    return(df[seq_len(nrow(df)), , drop = FALSE])
  }
  df[order(df[[key]]), , drop = FALSE]
}

compare_vectors <- function(a, b, tol = 1e-8) {
  len <- min(length(a), length(b))
  if (len == 0) {
    return(0L)
  }
  a <- a[seq_len(len)]
  b <- b[seq_len(len)]
  if (is.numeric(a) && is.numeric(b)) {
    delta <- abs(a - b)
    sum(!((is.na(a) & is.na(b)) | (delta <= tol)), na.rm = FALSE)
  } else {
    sum(!( (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b) ))
  }
}

qc_parity_adsl <- function(
  sas_path = "data/adam/adsl_sas.xpt",
  r_path = "data/adam/adsl_r.xpt",
  out_path = "outputs/qc/adsl_parity_report.csv"
) {
  sas_ds <- read_adsl_version(sas_path)
  r_ds <- read_adsl_version(r_path)

  if (is.null(sas_ds) || is.null(r_ds)) {
    message <- sprintf("Parity inputs missing (sas: %s, r: %s)", file.exists(sas_path), file.exists(r_path))
    warning(message)
    dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(data.frame(status = message), out_path)
    return(list(status = "inputs_missing", message = message))
  }

  common_cols <- intersect(names(sas_ds), names(r_ds))
  if (length(common_cols) == 0) {
    stop("No overlapping columns between SAS and R datasets", call. = FALSE)
  }

  sas_ds <- align_dataset(sas_ds[common_cols])
  r_ds <- align_dataset(r_ds[common_cols])

  if (nrow(sas_ds) != nrow(r_ds)) {
    warning("Row count mismatch between SAS and R ADSL extracts")
  }

  comp <- data.frame(variable = character(), n_diff = integer(), stringsAsFactors = FALSE)
  for (var in common_cols) {
    diffs <- compare_vectors(sas_ds[[var]], r_ds[[var]])
    comp <- rbind(comp, data.frame(variable = var, n_diff = diffs, stringsAsFactors = FALSE))
  }

  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(comp, out_path)
  list(status = "success", comparison = comp)
}

if (identical(environment(), globalenv()) && !interactive()) {
  qc_parity_adsl()
}
