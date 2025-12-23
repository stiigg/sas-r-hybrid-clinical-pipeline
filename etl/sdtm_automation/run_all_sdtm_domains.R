#!/usr/bin/env Rscript
#=============================================================================
# MASTER SCRIPT: RUN ALL SDTM DOMAINS + DEFINE-XML + QC
# Executes complete SDTM automation pipeline with validation
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
  "generate_vs_with_oak.R",
  
  # PHASE 7: Optional domains
  "generate_eg_with_oak.R",
  "generate_pe_with_oak.R",
  "generate_qs_with_oak.R"
)

# Track execution results
results <- list()
start_time <- Sys.time()

# Execute each domain script
log_info("\n=== PHASE 1: SDTM DOMAIN GENERATION ===")

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

# Generate Define-XML
log_info("\n=== PHASE 2: DEFINE-XML 2.1 GENERATION ===")

define_script <- here("etl", "sdtm_automation", "generate_define_xml.R")

if (file.exists(define_script)) {
  log_info("[DEFINE-XML] Starting Define-XML generation...")
  
  tryCatch({
    source(define_script, local = TRUE)
    results[["DEFINE_XML"]] <- list(status = "SUCCESS", error = NULL)
    log_info("[DEFINE-XML] ✓ Completed successfully\n")
  }, error = function(e) {
    results[["DEFINE_XML"]] <- list(status = "FAILED", error = as.character(e))
    log_error("[DEFINE-XML] ✗ Failed: {e$message}\n")
  })
} else {
  log_warn("[DEFINE-XML] Script not found, skipping\n")
  results[["DEFINE_XML"]] <- list(status = "SKIPPED", error = "Script not found")
}

# Run Quality Control Checks
log_info("\n=== PHASE 3: QUALITY CONTROL VALIDATION ===")

qc_script <- here("etl", "sdtm_automation", "qc", "validate_all_domains.R")

if (file.exists(qc_script)) {
  log_info("[QC] Starting quality control validation...")
  
  tryCatch({
    source(qc_script, local = TRUE)
    results[["QC_VALIDATION"]] <- list(status = "SUCCESS", error = NULL)
    log_info("[QC] ✓ Completed successfully\n")
  }, error = function(e) {
    results[["QC_VALIDATION"]] <- list(status = "FAILED", error = as.character(e))
    log_error("[QC] ✗ Failed: {e$message}\n")
  })
} else {
  log_warn("[QC] Script not found, skipping\n")
  results[["QC_VALIDATION"]] <- list(status = "SKIPPED", error = "Script not found")
}

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "secs")

# Summary report
log_info("\n============================================")
log_info("SDTM AUTOMATION PIPELINE COMPLETE")
log_info("============================================")

success_count <- sum(sapply(results, function(x) x$status == "SUCCESS"))
failed_count <- sum(sapply(results, function(x) x$status == "FAILED"))
skipped_count <- sum(sapply(results, function(x) x$status == "SKIPPED"))

log_info("Total components: {length(results)}")
log_info("Successful: {success_count}")
log_info("Failed: {failed_count}")
log_info("Skipped: {skipped_count}")
log_info("Execution time: {round(elapsed, 2)} seconds\n")

if (failed_count > 0) {
  log_warn("Failed components:")
  for (component in names(results)) {
    if (results[[component]]$status == "FAILED") {
      log_warn("  - {component}: {results[[component]]$error}")
    }
  }
}

log_info("\nOutput directories:")
log_info("  SDTM XPT files: {here('outputs', 'sdtm')}")
log_info("  Define-XML: {here('outputs', 'define')}")
log_info("  QC Reports: {here('outputs', 'qc')}")
log_info("============================================\n")

message("\n✅ PIPELINE EXECUTION SUMMARY")
message("==============================")
message(sprintf("✓ %d SDTM domains generated", success_count - 2))  # Subtract Define-XML and QC
message(sprintf("✓ Define-XML 2.1: %s", results$DEFINE_XML$status))
message(sprintf("✓ QC Validation: %s", results$QC_VALIDATION$status))
message("==============================\n")

# Return status code
if (failed_count > 0) {
  quit(status = 1)
} else {
  quit(status = 0)
}
