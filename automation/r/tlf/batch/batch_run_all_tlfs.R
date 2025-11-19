# Batch runner for executing generation scripts listed in the manifest.

source("outputs/tlf/r/utils/batch_runner.R")

run_all_tlfs <- function(config = getOption("tlf.config"), target_ids = NULL) {
  manifest <- load_tlf_shell_map()
  if (!is.null(target_ids) && length(target_ids) > 0) {
    manifest <- manifest[manifest$tlf_id %in% target_ids, , drop = FALSE]
    if (nrow(manifest) == 0) {
      return(data.frame(
        tlf_id = character(),
        status = character(),
        message = character(),
        script = character(),
        log = character(),
        stringsAsFactors = FALSE
      ))
    }
  }
  execute_tlf_manifest(
    manifest = manifest,
    script_column = "gen_script",
    script_type = "gen",
    log_suffix = "generation.log",
    config = config
  )
}
