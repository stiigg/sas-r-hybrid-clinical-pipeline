#!/usr/bin/env Rscript

# Master Pipeline Runner - New Dedicated Directory Structure
# Runs both SDTM and ADaM pipelines in sequence

message("#########################################")
message("#  SAS-R Hybrid Clinical Pipeline      #")
message("#  Dedicated SDTM/ADaM Structure       #")
message("#########################################")

overall_start <- Sys.time()

# Stage 1: SDTM Pipeline
message("\n[STAGE 1] Running SDTM Pipeline...\n")
tryCatch({
  source("sdtm/run_sdtm_all.R")
}, error = function(e) {
  stop(sprintf("Pipeline failed at SDTM stage: %s", e$message))
})

# Stage 2: ADaM Pipeline
message("\n[STAGE 2] Running ADaM Pipeline...\n")
tryCatch({
  source("adam/run_adam_all.R")
}, error = function(e) {
  stop(sprintf("Pipeline failed at ADaM stage: %s", e$message))
})

# Pipeline complete
overall_end <- Sys.time()
total_elapsed <- difftime(overall_end, overall_start, units = "secs")

message("\n#########################################")
message(sprintf("#  Pipeline Complete (%.1f sec)        #", total_elapsed))
message("#########################################")
message("\nOutput Locations:")
message("  - SDTM datasets: sdtm/data/output/")
message("  - ADaM datasets: adam/data/output/")
message("\nReview logs in sdtm/outputs/ and adam/outputs/")
