# Manifest-driven QC execution for all TLF assets.

source("outputs/tlf/r/utils/batch_runner.R")

run_qc_for_all_tlfs <- function(config = getOption("tlf.config")) {
  manifest <- load_tlf_shell_map()
  execute_tlf_manifest(
    manifest = manifest,
    script_column = "qc_script",
    script_type = "qc",
    log_suffix = "qc.log",
    config = config
  )
}
