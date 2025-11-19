# Shared helper functions for working with the lightweight metadata repository
# that now lives under specs/. These utilities are intentionally dependency
# light so they can be sourced from orchestration and QC scripts.

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (is.character(x) && all(!nzchar(x)))) {
    y
  } else {
    x
  }
}

require_readr <- function() {
  if (!requireNamespace("readr", quietly = TRUE)) {
    stop("Package 'readr' is required for MDR utilities.", call. = FALSE)
  }
}

read_adam_dataset_spec <- function(path = "specs/adam/adam_dataset_spec.csv") {
  require_readr()
  if (!file.exists(path)) {
    stop(sprintf("ADaM dataset specification not found at %s", path), call. = FALSE)
  }
  readr::read_csv(path, show_col_types = FALSE)
}

read_adam_variable_spec <- function(path = "specs/adam/adam_variable_spec.csv") {
  require_readr()
  if (!file.exists(path)) {
    stop(sprintf("ADaM variable specification not found at %s", path), call. = FALSE)
  }
  readr::read_csv(path, show_col_types = FALSE)
}

resolve_adam_dataset_path <- function(dataset, adam_dir = "data/adam") {
  base <- tolower(dataset)
  candidates <- file.path(adam_dir, paste0(base, c(".xpt", ".sas7bdat")))
  existing <- candidates[file.exists(candidates)]
  list(
    dataset = dataset,
    expected_path = candidates[[1]],
    located_path = if (length(existing) > 0) existing[[1]] else NA_character_,
    exists = length(existing) > 0
  )
}

check_expected_adam_datasets <- function(spec_df, adam_dir = "data/adam") {
  checks <- lapply(spec_df$dataset, resolve_adam_dataset_path, adam_dir = adam_dir)
  do.call(rbind, lapply(checks, as.data.frame))
}

ensure_adam_datasets <- function(spec_df = read_adam_dataset_spec(), adam_dir = "data/adam") {
  checks <- check_expected_adam_datasets(spec_df, adam_dir)
  missing <- subset(checks, !exists)
  if (nrow(missing) > 0) {
    stop(
      sprintf(
        "Expected ADaM datasets not found: %s",
        paste(sprintf("%s (looking for %s)", missing$dataset, missing$expected_path), collapse = "; ")
      ),
      call. = FALSE
    )
  }
  invisible(checks)
}
