# Batch runner for executing all QC scripts listed in the manifest.

source("outputs/tlf/r/utils/load_config.R")
source("outputs/tlf/r/utils/tlf_logging.R")

run_qc_for_all_tlfs <- function(config = getOption("tlf.config")) {
  if (is.null(config)) {
    config <- load_tlf_config()
  }

  manifest <- load_tlf_shell_map()
  results <- vector("list", nrow(manifest))

  for (i in seq_len(nrow(manifest))) {
    entry <- manifest[i, ]
    script_path <- resolve_tlf_script_path(entry$qc_script, type = "qc")
    log_file <- paste0(entry$tlf_id, "_qc.log")

    if (!file.exists(script_path)) {
      msg <- sprintf("QC script missing for %s at %s", entry$tlf_id, script_path)
      tlf_log(msg, log_file = log_file)
      results[[i]] <- list(tlf_id = entry$tlf_id, status = "missing", message = msg)
      next
    }

    tlf_log(sprintf("Starting QC for %s", entry$tlf_id), log_file = log_file)
    env <- new.env(parent = globalenv())
    env$manifest_entry <- entry
    env$config <- config
    tryCatch({
      sys.source(script_path, envir = env)
      tlf_log(sprintf("Completed QC for %s", entry$tlf_id), log_file = log_file)
      results[[i]] <- list(tlf_id = entry$tlf_id, status = "success", message = "")
    }, error = function(e) {
      msg <- sprintf("QC failed for %s: %s", entry$tlf_id, conditionMessage(e))
      tlf_log(msg, log_file = log_file)
      results[[i]] <- list(tlf_id = entry$tlf_id, status = "error", message = conditionMessage(e))
    })
  }

  do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
}
