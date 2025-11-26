#' Run a set of TLF generation scripts
#'
#' This helper wires the existing manifest-driven batch runner into the
#' package namespace. It keeps the workshop-style interface lightweight while
#' deferring to the established `automation/r/tlf` utilities.
#'
#' @param target_ids Optional character vector of TLF IDs to generate. If
#'   `NULL`, the manifest drives execution.
#' @param config Optional configuration list. If omitted, the function will
#'   attempt to load the TLF config using the repository utilities.
#' @return Data frame summarising generation status for each TLF.
#' @export
run_tlf_set <- function(target_ids = NULL, config = NULL) {
  batch_script <- file.path(getwd(), "automation", "r", "tlf", "batch", "batch_run_all_tlfs.R")
  if (!file.exists(batch_script)) {
    stop("Batch TLF runner not found; expected automation/r/tlf/batch/batch_run_all_tlfs.R.", call. = FALSE)
  }

  if (is.null(config)) {
    cfg_env <- new.env(parent = baseenv())
    cfg_file <- file.path(getwd(), "outputs", "tlf", "r", "utils", "load_config.R")
    if (file.exists(cfg_file)) {
      sys.source(cfg_file, envir = cfg_env)
      if (is.function(cfg_env$load_tlf_config)) {
        config <- cfg_env$load_tlf_config()
      }
    }
  }

  if (!is.null(config)) {
    options(tlf.config = config)
    on.exit(options(tlf.config = NULL), add = TRUE)
  }

  runner_env <- new.env(parent = baseenv())
  sys.source(batch_script, envir = runner_env)
  if (!is.function(runner_env$run_all_tlfs)) {
    stop("Expected run_all_tlfs() to be defined by batch_run_all_tlfs.R.", call. = FALSE)
  }

  runner_env$run_all_tlfs(config = getOption("tlf.config"), target_ids = target_ids)
}
