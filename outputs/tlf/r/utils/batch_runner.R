# Shared helper functions for executing manifest-driven TLF batches.

source("outputs/tlf/r/utils/tlf_logging.R")
source("outputs/tlf/r/utils/load_config.R")

#' Execute a manifest-driven batch of scripts.
#'
#' @param manifest data.frame returned by load_tlf_shell_map().
#' @param script_column Column in the manifest that contains the script name.
#' @param script_type Either "gen" or "qc" to determine the folder lookup.
#' @param log_suffix Suffix appended to the generated log file name.
#' @param config Named list returned by load_tlf_config().
#' @return data.frame summarising execution results for each TLF.
execute_tlf_manifest <- function(
  manifest,
  script_column,
  script_type = c("gen", "qc"),
  log_suffix = "log",
  config = getOption("tlf.config")
) {
  script_type <- match.arg(script_type)

  if (is.null(config)) {
    config <- load_tlf_config()
  }

  if (!is.data.frame(manifest) || nrow(manifest) == 0) {
    stop("TLF manifest must be a non-empty data.frame", call. = FALSE)
  }

  if (!script_column %in% names(manifest)) {
    stop(sprintf("Manifest is missing required column '%s'", script_column), call. = FALSE)
  }

  results <- vector("list", nrow(manifest))

  for (i in seq_len(nrow(manifest))) {
    entry <- manifest[i, , drop = FALSE]
    script_path <- resolve_tlf_script_path(entry[[script_column]], type = script_type)
    log_file <- get_tlf_log_path(sprintf("%s_%s", entry$tlf_id, log_suffix))

    if (!file.exists(script_path)) {
      msg <- sprintf("Script missing for %s at %s", entry$tlf_id, script_path)
      tlf_log(msg, log_file = log_file)
      results[[i]] <- list(
        tlf_id = entry$tlf_id,
        status = "missing",
        message = msg,
        script = script_path,
        log = log_file
      )
      next
    }

    tlf_log(sprintf("Starting %s for %s", script_type, entry$tlf_id), log_file = log_file)

    env <- new.env(parent = globalenv())
    env$manifest_entry <- entry
    env$config <- config

    tryCatch({
      sys.source(script_path, envir = env)
      tlf_log(sprintf("Completed %s for %s", script_type, entry$tlf_id), log_file = log_file)
      results[[i]] <- list(
        tlf_id = entry$tlf_id,
        status = "success",
        message = "",
        script = script_path,
        log = log_file
      )
    }, error = function(e) {
      msg <- sprintf("Execution failed for %s: %s", entry$tlf_id, conditionMessage(e))
      tlf_log(msg, log_file = log_file)
      results[[i]] <- list(
        tlf_id = entry$tlf_id,
        status = "error",
        message = conditionMessage(e),
        script = script_path,
        log = log_file
      )
    })
  }

  do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
}
