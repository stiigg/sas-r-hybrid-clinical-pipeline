# Batch runner for executing all generation scripts listed in the manifest.

source("outputs/tlf/r/utils/batch_runner.R")

run_all_tlfs <- function(config = getOption("tlf.config")) {
  manifest <- load_tlf_shell_map()
  execute_tlf_manifest(
    manifest = manifest,
    script_column = "gen_script",
    script_type = "gen",
    log_suffix = "generation.log",
    config = config
  )
}
