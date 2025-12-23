#!/usr/bin/env Rscript
#=============================================================================
# MASTER ORCHESTRATION SCRIPT
# Executes full 360i automation pipeline: SDTM -> ADaM -> Validation
#=============================================================================

library(here)
library(logger)
library(cli)

log_threshold(INFO)

# Banner
cli_h1("CDISC 360i Automation Pipeline")
cli_alert_info("SAS-R Hybrid with pharmaverse")
cat("\n")

# Step 1: SDTM Generation with sdtm.oak
cli_h2("Step 1: SDTM Generation (sdtm.oak)")
log_info("Generating RS domain with sdtm.oak...")

try({
  source(here("etl", "sdtm_automation", "generate_rs_with_oak.R"))
  cli_alert_success("RS domain generated")
}, error = function(e) {
  cli_alert_danger("SDTM generation failed: {e$message}")
  stop("Pipeline stopped at SDTM generation")
})

cat("\n")

# Step 2: ADaM Generation with admiral
cli_h2("Step 2: ADaM Generation (admiral)")
log_info("Generating ADRS with admiral/admiralonco...")

try({
  source(here("etl", "adam_automation", "generate_adrs_with_admiral.R"))
  cli_alert_success("ADRS dataset generated")
}, error = function(e) {
  cli_alert_danger("ADaM generation failed: {e$message}")
  stop("Pipeline stopped at ADaM generation")
})

cat("\n")

# Step 3: CDISC CORE Validation
cli_h2("Step 3: CDISC CORE Validation")
log_info("Running conformance checks...")

core_script <- here("validation", "validate_with_core.py")
if (file.exists(core_script)) {
  system2("python3", args = c(core_script), wait = TRUE)
  cli_alert_success("CORE validation complete")
} else {
  cli_alert_warning("CORE validation script not found, skipping...")
}

cat("\n")

# Summary
cli_h1("Pipeline Complete!")

output_files <- c(
  "SDTM RS" = "outputs/sdtm/rs_oak.xpt",
  "ADaM ADRS" = "outputs/adam/adrs_admiral.xpt",
  "ADaM ADSL" = "outputs/adam/adsl.xpt"
)

cli_h3("Output Files:")
for (name in names(output_files)) {
  path <- here(output_files[name])
  if (file.exists(path)) {
    size <- file.info(path)$size
    cli_alert_success("{name}: {basename(path)} ({format(size, big.mark=','))} bytes)")
  } else {
    cli_alert_danger("{name}: NOT FOUND")
  }
}

cat("\n")
cli_h3("Next Steps:")
cli_alert_info("1. Review validation reports in outputs/validation/")
cli_alert_info("2. Launch Shiny dashboard: Rscript shiny/run_app.R")
cli_alert_info("3. Export to regulatory format: Rscript export/create_define_xml.R")

cat("\n")
