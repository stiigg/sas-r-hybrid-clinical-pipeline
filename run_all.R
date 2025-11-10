#!/usr/bin/env Rscript

# Top-level orchestrator for the R-based TLF pipeline.
#
# The script assumes it is executed from the repository root. It loads the
# configuration, initialises logging, and executes the QC and generation batch
# runners in sequence. Any additional orchestration (e.g., launching review apps)
# can be appended at the end of this file.

source("r/tlf/config/load_config.R")
source("r/tlf/utils/tlf_logging.R")
source("r/tlf/batch/batch_run_qc_all_tlfs.R")
source("r/tlf/batch/batch_run_all_tlfs.R")

config <- load_tlf_config()

pipeline_log <- "pipeline.log"

tlf_log("Starting full TLF pipeline run", log_file = pipeline_log)

qc_results <- run_qc_for_all_tlfs(config)

if (all(vapply(qc_results$status, identical, logical(1), "success"))) {
  tlf_log("QC completed successfully for all TLFs", log_file = pipeline_log)
} else {
  tlf_log("QC completed with warnings/failures - see logs for details", log_file = pipeline_log)
}

gen_results <- run_all_tlfs(config)

if (all(vapply(gen_results$status, identical, logical(1), "success"))) {
  tlf_log("Generation completed successfully for all TLFs", log_file = pipeline_log)
} else {
  tlf_log("Generation completed with warnings/failures - see logs for details", log_file = pipeline_log)
}

tlf_log("TLF pipeline run finished", log_file = pipeline_log)

invisible(list(qc = qc_results, generation = gen_results))
