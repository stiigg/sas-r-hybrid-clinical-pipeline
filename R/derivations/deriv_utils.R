#' Common derivation utilities
#'
#' Contains helper functions shared across ADaM derivations.
#'
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x)) || identical(x, "")) y else x
}

ensure_input <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Required SDTM file missing at %s", path), call. = FALSE)
  }
  path
}
