#!/usr/bin/env Rscript
################################################################################
# Program: generate_define_sdtm.R
# Purpose: Master orchestrator for SDTM Define-XML v2.1 generation
# Author: Clinical Programming Team
# Date: 2026-01-01
#
# Workflow:
#   Phase 1: Extract metadata from Pinnacle 21 Community
#   Phase 2: Enrich with SDTM specification derivations
#   Phase 3: Generate compliant Define-XML v2.1
#   Phase 4: Validate with Pinnacle 21
#
# Usage:
#   Rscript regulatory_submission/define_xml/generate_define_sdtm.R
################################################################################

suppressPackageStartupMessages({
  library(here)
  library(yaml)
  library(cli)
  library(logger)
})

# Set working directory to project root
setwd(here())

# Initialize logging
log_dir <- here("logs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
log_threshold(INFO)
log_appender(appender_tee(file.path(log_dir, paste0("define_xml_", Sys.Date(), ".log"))))

################################################################################
# Banner
################################################################################

cli_rule("SDTM Define-XML v2.1 Generation Pipeline")
cli_h1("Pinnacle 21 + Automated Enrichment Workflow")
cli_alert_info("Starting: {Sys.time()}")
cat("\n")

################################################################################
# Load Configuration
################################################################################

cli_h2("Configuration")

config_path <- here("regulatory_submission", "define_xml", "config", "study_config.yml")

if (!file.exists(config_path)) {
  cli_alert_danger("Configuration file not found: {config_path}")
  stop("Please create study_config.yml")
}

config <- read_yaml(config_path)

cli_alert_success("Study: {config$study$id} - {config$study$name}")
cli_alert_success("SDTM Standard: {config$standards$sdtm$name} v{config$standards$sdtm$version}")
cli_alert_success("Define-XML Version: {config$define_xml$version}")

cat("\n")

################################################################################
# Check Dependencies
################################################################################

cli_h2("Dependency Check")

required_packages <- c("xml2", "dplyr", "readr", "readxl", "xportr", 
                       "haven", "purrr", "tidyr", "janitor")

missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
  cli_alert_danger("Missing packages: {paste(missing_packages, collapse = ', ')}")
  cli_alert_info("Install with: install.packages(c({paste0('\"', missing_packages, '\"', collapse = ', ')}))")
  stop("Missing required packages")
}

cli_alert_success("All required packages available")

cat("\n")

################################################################################
# Phase 1: Pinnacle 21 Metadata Extraction
################################################################################

cli_rule("Phase 1: Pinnacle 21 Metadata Extraction")

phase1_script <- here("regulatory_submission", "define_xml", "scripts", 
                       "01_extract_pinnacle21_metadata.R")

if (!file.exists(phase1_script)) {
  cli_alert_danger("Phase 1 script not found: {phase1_script}")
  stop("Missing Phase 1 script")
}

cli_alert_info("Executing Phase 1...")
log_info("Starting Phase 1: Pinnacle 21 metadata extraction")

tryCatch({
  source(phase1_script, local = new.env())
  cli_alert_success("Phase 1 complete")
  log_info("Phase 1 completed successfully")
}, error = function(e) {
  cli_alert_danger("Phase 1 failed: {conditionMessage(e)}")
  log_error("Phase 1 error: {conditionMessage(e)}")
  stop("Phase 1 execution failed")
})

cat("\n")

################################################################################
# Phase 2: Metadata Enrichment from SDTM Specs
################################################################################

cli_rule("Phase 2: Metadata Enrichment from SDTM Specs")

# Check if Pinnacle 21 metadata exists
p21_metadata <- here(config$paths$metadata, "pinnacle21_parsed.rds")

if (!file.exists(p21_metadata)) {
  cli_alert_warning("Pinnacle 21 metadata not found")
  cli_alert_info("Please complete Phase 1 manual steps:")
  cli_ol(c(
    "Open Pinnacle 21 Community",
    "Generate spec from XPT files",
    "Export to Excel",
    "Rerun this script"
  ))
  cli_alert_info("Expected file: {p21_metadata}")
  stop("Pinnacle 21 metadata required")
}

phase2_script <- here("regulatory_submission", "define_xml", "scripts",
                       "02_enrich_from_specs.R")

cli_alert_info("Executing Phase 2...")
log_info("Starting Phase 2: Metadata enrichment")

tryCatch({
  source(phase2_script, local = new.env())
  cli_alert_success("Phase 2 complete")
  log_info("Phase 2 completed successfully")
}, error = function(e) {
  cli_alert_danger("Phase 2 failed: {conditionMessage(e)}")
  log_error("Phase 2 error: {conditionMessage(e)}")
  stop("Phase 2 execution failed")
})

cat("\n")

################################################################################
# Phase 3: Define-XML v2.1 Generation
################################################################################

cli_rule("Phase 3: Define-XML v2.1 Generation")

phase3_script <- here("regulatory_submission", "define_xml", "scripts",
                       "03_generate_define_xml_v2_1.R")

cli_alert_info("Executing Phase 3...")
log_info("Starting Phase 3: Define-XML generation")

tryCatch({
  source(phase3_script, local = new.env())
  cli_alert_success("Phase 3 complete")
  log_info("Phase 3 completed successfully")
}, error = function(e) {
  cli_alert_danger("Phase 3 failed: {conditionMessage(e)}")
  log_error("Phase 3 error: {conditionMessage(e)}")
  stop("Phase 3 execution failed")
})

cat("\n")

################################################################################
# Phase 4: Validation (Optional)
################################################################################

cli_rule("Phase 4: Validation")

define_xml_path <- here(config$paths$output, "define_sdtm.xml")

if (!file.exists(define_xml_path)) {
  cli_alert_warning("Define-XML not found, skipping validation")
} else {
  cli_alert_info("Define-XML created: {basename(define_xml_path)}")
  
  # Check file size
  file_size <- file.info(define_xml_path)$size / 1024
  cli_alert_info("File size: {round(file_size, 1)} KB")
  
  # Validation script
  validation_script <- here("regulatory_submission", "define_xml", "scripts",
                             "04_validate_define.sh")
  
  if (file.exists(validation_script)) {
    cli_alert_info("Running Pinnacle 21 validation...")
    
    result <- system2("bash", args = c(validation_script), 
                      stdout = TRUE, stderr = TRUE)
    
    if (is.null(attr(result, "status")) || attr(result, "status") == 0) {
      cli_alert_success("Validation complete")
    } else {
      cli_alert_warning("Validation completed with warnings (see reports)")
    }
  } else {
    cli_alert_info("Validation script not found, skipping automated validation")
    cli_alert_info("Manual validation: Open {basename(define_xml_path)} in Pinnacle 21")
  }
}

cat("\n")

################################################################################
# Pipeline Summary
################################################################################

cli_rule("Pipeline Summary")

output_files <- list.files(
  here(config$paths$output),
  pattern = "\\.(xml|xlsx|csv|html)$",
  full.names = TRUE
)

cli_h3("Generated Files ({length(output_files)}):")

if (length(output_files) > 0) {
  for (f in output_files) {
    size <- file.info(f)$size / 1024
    cli_li("{basename(f)} ({round(size, 1)} KB)")
  }
} else {
  cli_alert_warning("No output files found")
}

cat("\n")

################################################################################
# Next Steps
################################################################################

cli_h3("Next Steps:")

cli_ol(c(
  paste0("Review Define-XML: ", define_xml_path),
  "Validate with Pinnacle 21 Community",
  paste0("Check metadata CSVs in: ", config$paths$metadata),
  paste0("Review generation log: logs/define_xml_", Sys.Date(), ".log"),
  "Package for eCTD submission"
))

cat("\n")

cli_rule("Define-XML Generation Complete")
cli_alert_success("Completed: {Sys.time()}")

log_info("Define-XML generation pipeline completed successfully")
