# Batch runner for executing all generation scripts listed in the manifest.

source("outputs/tlf/r/utils/load_config.R")
source("outputs/tlf/r/utils/tlf_logging.R")

run_all_tlfs <- function(config = getOption("tlf.config")) {
  if (is.null(config)) {
    config <- load_tlf_config()
  }

  manifest <- load_tlf_shell_map()
  results <- vector("list", nrow(manifest))

  for (i in seq_len(nrow(manifest))) {
    entry <- manifest[i, ]
    script_path <- resolve_tlf_script_path(entry$gen_script, type = "gen")
    log_file <- paste0(entry$tlf_id, "_generation.log")

    if (!file.exists(script_path)) {
      msg <- sprintf("Generation script missing for %s at %s", entry$tlf_id, script_path)
      tlf_log(msg, log_file = log_file)
      results[[i]] <- list(tlf_id = entry$tlf_id, status = "missing", message = msg)
      next
    }

    tlf_log(sprintf("Starting generation for %s", entry$tlf_id), log_file = log_file)
    env <- new.env(parent = globalenv())
    env$manifest_entry <- entry
    env$config <- config
    tryCatch({
      sys.source(script_path, envir = env)
      tlf_log(sprintf("Completed generation for %s", entry$tlf_id), log_file = log_file)
      results[[i]] <- list(tlf_id = entry$tlf_id, status = "success", message = "")
    }, error = function(e) {
      msg <- sprintf("Generation failed for %s: %s", entry$tlf_id, conditionMessage(e))
      tlf_log(msg, log_file = log_file)
      results[[i]] <- list(tlf_id = entry$tlf_id, status = "error", message = conditionMessage(e))
    })
  }

  do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
}
