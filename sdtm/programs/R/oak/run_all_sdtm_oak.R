# Master Orchestration Script: Generate All SDTM Domains with sdtm.oak
# Author: Christian Baghai
# Date: 2024-12-24
# Description: End-to-end SDTM pipeline execution using sdtm.oak v0.2.0

# Load required packages
library(logger)
library(here)

# Configure logging
log_threshold(INFO)
log_appender(appender_file(here::here("sdtm", "logs", "sdtm_oak_pipeline.log")))

log_info("=", strrep("=", 70))
log_info("SDTM Domain Generation Pipeline with sdtm.oak v0.2.0")
log_info("Start Time: {Sys.time()}")
log_info("=", strrep("=", 70))

# Track execution time and results
pipeline_start <- Sys.time()
execution_summary <- list()

# Helper function to execute domain script
execute_domain <- function(script_path, domain_name) {
  log_info("Processing domain: {domain_name}")
  
  start_time <- Sys.time()
  
  tryCatch({
    source(script_path)
    
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    
    execution_summary[[domain_name]] <<- list(
      status = "SUCCESS",
      elapsed_seconds = round(elapsed, 2),
      timestamp = Sys.time()
    )
    
    log_info("{domain_name} completed in {round(elapsed, 2)} seconds")
    
  }, error = function(e) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    
    execution_summary[[domain_name]] <<- list(
      status = "FAILED",
      elapsed_seconds = round(elapsed, 2),
      timestamp = Sys.time(),
      error_message = as.character(e)
    )
    
    log_error("{domain_name} failed: {e$message}")
  })
}

# ============================================================================
# PHASE 1: FOUNDATION DOMAINS (Must run first)
# ============================================================================
log_info("\nPHASE 1: Foundation Domains")
log_info("-" , strrep("-", 70))

execute_domain(
  here::here("sdtm", "programs", "R", "oak", "foundation", "generate_dm_with_oak.R"),
  "DM (Demographics)"
)

# ============================================================================
# PHASE 2: EVENTS DOMAINS
# ============================================================================
log_info("\nPHASE 2: Events Domains")
log_info("-" , strrep("-", 70))

execute_domain(
  here::here("sdtm", "programs", "R", "oak", "events", "generate_ae_with_oak.R"),
  "AE (Adverse Events)"
)

# Additional events domains (to be implemented)
# execute_domain(
#   here::here("sdtm", "programs", "R", "oak", "events", "generate_cm_with_oak.R"),
#   "CM (Concomitant Medications)"
# )
# 
# execute_domain(
#   here::here("sdtm", "programs", "R", "oak", "events", "generate_mh_with_oak.R"),
#   "MH (Medical History)"
# )
# 
# execute_domain(
#   here::here("sdtm", "programs", "R", "oak", "events", "generate_ds_with_oak.R"),
#   "DS (Disposition)"
# )
# 
# execute_domain(
#   here::here("sdtm", "programs", "R", "oak", "events", "generate_ex_with_oak.R"),
#   "EX (Exposure)"
# )

# ============================================================================
# PHASE 3: FINDINGS DOMAINS
# ============================================================================
log_info("\nPHASE 3: Findings Domains")
log_info("-" , strrep("-", 70))

execute_domain(
  here::here("sdtm", "programs", "R", "oak", "findings", "generate_vs_with_oak.R"),
  "VS (Vital Signs)"
)

# Additional findings domains (to be implemented)
# execute_domain(
#   here::here("sdtm", "programs", "R", "oak", "findings", "generate_lb_with_oak.R"),
#   "LB (Laboratory Results)"
# )
# 
# execute_domain(
#   here::here("sdtm", "programs", "R", "oak", "findings", "generate_eg_with_oak.R"),
#   "EG (ECG)"
# )
# 
# execute_domain(
#   here::here("sdtm", "programs", "R", "oak", "findings", "generate_pe_with_oak.R"),
#   "PE (Physical Examination)"
# )

# ============================================================================
# PHASE 4: FINDINGS ABOUT DOMAINS
# ============================================================================
# log_info("\nPHASE 4: Findings About Domains")
# log_info("-" , strrep("-", 70))
# 
# execute_domain(
#   here::here("sdtm", "programs", "R", "oak", "findings_about", "generate_qs_with_oak.R"),
#   "QS (Questionnaires)"
# )

# ============================================================================
# PIPELINE SUMMARY
# ============================================================================
pipeline_elapsed <- as.numeric(difftime(Sys.time(), pipeline_start, units = "mins"))

log_info("\n" , strrep("=", 70))
log_info("PIPELINE EXECUTION SUMMARY")
log_info(strrep("=", 70))

# Count successes and failures
success_count <- sum(sapply(execution_summary, function(x) x$status == "SUCCESS"))
failure_count <- sum(sapply(execution_summary, function(x) x$status == "FAILED"))
total_domains <- length(execution_summary)

log_info("Total Domains Processed: {total_domains}")
log_info("Successful: {success_count}")
log_info("Failed: {failure_count}")
log_info("Total Elapsed Time: {round(pipeline_elapsed, 2)} minutes")

# Detailed results
log_info("\nDomain-Level Results:")
log_info("-" , strrep("-", 70))

for (domain in names(execution_summary)) {
  result <- execution_summary[[domain]]
  status_symbol <- if (result$status == "SUCCESS") "✓" else "✗"
  
  log_info("{status_symbol} {domain}: {result$status} ({result$elapsed_seconds}s)")
  
  if (result$status == "FAILED") {
    log_error("   Error: {result$error_message}")
  }
}

log_info("\n" , strrep("=", 70))
log_info("End Time: {Sys.time()}")
log_info(strrep("=", 70))

# Return execution summary for programmatic access
invisible(execution_summary)
