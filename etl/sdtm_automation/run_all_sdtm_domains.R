#!/usr/bin/env Rscript
#=============================================================================
# MASTER SCRIPT: RUN ALL SDTM DOMAINS
# Executes complete SDTM automation pipeline in correct order
#=============================================================================

library(here)
library(logger)

log_threshold(INFO)
log_info("Starting complete SDTM automation pipeline")
log_info("============================================\n")

# Define execution order (dependencies matter)
domain_scripts <- c(
  # PHASE 1: Foundation - must run first
  "generate_dm_with_oak.R",
  
  # PHASE 2: Visit tracking
  "generate_sv_with_oak.R",
  
  # PHASE 3: Oncology package (TU must precede TR and RS)
  "generate_tu_with_oak.R",
  "generate_tr_with_oak.R",
  "generate_rs_with_oak.R",
  
  # PHASE 4: Safety and exposure
  "generate_ae_with_oak.R",
  "generate_ex_with_oak.R",
  
  # PHASE 5: Subject status
  "generate_ds_with_oak.R",
  "generate_cm_with_oak.R",
  "generate_mh_with_oak.R",
  
  # PHASE 6: Clinical measurements
  "generate_lb_with_oak.R",
  "generate_vs_with_oak.R"
)

# Track execution results
results <- list()
start_time <- Sys.time()

# Execute each domain script
for (script in domain_scripts) {
  script_path <- here("etl", "sdtm_automation", script)
  domain <- toupper(gsub("generate_(.*?)_with_oak\\.R", "\\1", script))
  
  log_info("[{domain}] Starting domain generation...")
  
  tryCatch({
    source(script_path, local = TRUE)
    results[[domain]] <- list(status = "SUCCESS", error = NULL)
    log_info("[{domain}] ✓ Completed successfully\n")
  }, error = function(e) {
    results[[domain]] <- list(status = "FAILED", error = as.character(e))
    log_error("[{domain}] ✗ Failed: {e$message}\n")
  })
}

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "secs")

# Summary report
log_info("\n============================================")
log_info("SDTM AUTOMATION PIPELINE COMPLETE")
log_info("============================================")

success_count <- sum(sapply(results, function(x) x$status == "SUCCESS"))
failed_count <- sum(sapply(results, function(x) x$status == "FAILED"))

log_info("Total domains: {length(results)}")
log_info("Successful: {success_count}")
log_info("Failed: {failed_count}")
log_info("Execution time: {round(elapsed, 2)} seconds\n")

if (failed_count > 0) {
  log_warn("Failed domains:")
  for (domain in names(results)) {
    if (results[[domain]]$status == "FAILED") {
      log_warn("  - {domain}: {results[[domain]]$error}")
    }
  }
}

log_info("\nOutput files written to: {here('outputs', 'sdtm')}")
log_info("============================================\n")

# Return status code
if (failed_count > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
