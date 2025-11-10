#!/usr/bin/env Rscript

# Repository-level orchestration entry point.
#
# The script now coordinates three phases:
#   1. ETL steps defined in specs/etl_manifest.csv (SAS + R).
#   2. QC tasks defined in specs/qc_manifest.csv.
#   3. TLF generation based on specs/tlf/tlf_shell_map.csv.
#
# Each phase is metadata-driven and can be executed in dry-run mode by setting
# environment variables (ETL_DRY_RUN, QC_DRY_RUN, TLF_DRY_RUN) to "true" or
# "false". Dry-run is enabled by default so that the pipeline can be inspected in
# environments without SAS or optional R tooling.

source("etl/run_etl.R")
source("qc/run_qc.R")
source("outputs/tlf/r/utils/load_config.R")
source("outputs/tlf/r/utils/tlf_logging.R")
source("automation/r/tlf/batch/batch_run_qc_all_tlfs.R")
source("automation/r/tlf/batch/batch_run_all_tlfs.R")

parse_bool <- function(env_var, default = TRUE) {
  value <- tolower(Sys.getenv(env_var, if (default) "true" else "false"))
  value %in% c("true", "1", "yes", "y")
}

config <- load_tlf_config()

pipeline_log <- "pipeline.log"

tlf_log("Starting full pipeline run", log_file = pipeline_log)

etl_dry_run <- parse_bool("ETL_DRY_RUN", default = TRUE)
etl_results <- run_full_etl(dry_run = etl_dry_run)
tlf_log(
  sprintf("ETL phase completed with %s", paste(unique(etl_results$status), collapse = ",")),
  log_file = pipeline_log
)

qc_dry_run <- parse_bool("QC_DRY_RUN", default = TRUE)
qc_results <- run_qc_plan(dry_run = qc_dry_run, config = if (qc_dry_run) NULL else config)
qc_status <- paste(unique(qc_results$status), collapse = ",")
tlf_log(sprintf("QC phase completed with %s", qc_status), log_file = pipeline_log)

tlf_dry_run <- parse_bool("TLF_DRY_RUN", default = TRUE)
gen_results <- if (tlf_dry_run) {
  manifest <- load_tlf_shell_map()
  data.frame(
    tlf_id = manifest$tlf_id,
    status = "dry_run",
    message = "Dry run - generation skipped",
    stringsAsFactors = FALSE
  )
} else {
  run_all_tlfs(config)
}

gen_status <- paste(unique(gen_results$status), collapse = ",")
tlf_log(sprintf("TLF generation completed with %s", gen_status), log_file = pipeline_log)

tlf_log("Pipeline run finished", log_file = pipeline_log)

invisible(list(etl = etl_results, qc = qc_results, generation = gen_results))
