#!/usr/bin/env Rscript

# Master ADaM Pipeline Runner
# Executes all ADaM analysis dataset programs in sequence
# REQUIRES: SDTM datasets must exist in sdtm/data/output/

message("========================================")
message("  ADaM Pipeline - Starting")
message("========================================")

# Set working directory to project root
if (basename(getwd()) == "adam") {
  setwd("..")
}

root <- getwd()
message(sprintf("Project root: %s", root))

# Check if SDTM datasets exist
sdtm_dir <- file.path(root, "sdtm", "data", "output")
if (!dir.exists(sdtm_dir)) {
  stop("ERROR: SDTM output directory not found. Run SDTM pipeline first: source('sdtm/run_sdtm_all.R')")
}

# Check for required SDTM domains
required_sdtm <- c("dm.xpt", "ae.xpt")
missing_sdtm <- setdiff(required_sdtm, list.files(sdtm_dir))
if (length(missing_sdtm) > 0) {
  warning(sprintf("Missing SDTM datasets: %s", paste(missing_sdtm, collapse = ", ")))
  stop("Run SDTM pipeline first: source('sdtm/run_sdtm_all.R')")
}

message(sprintf("✓ SDTM datasets found in: %s", sdtm_dir))

# Create output directory
adam_output_dir <- file.path(root, "adam", "data", "output")
dir.create(adam_output_dir, showWarnings = FALSE, recursive = TRUE)

# Track start time
start_time <- Sys.time()

# Run R-based ADaM programs
message("\n--- Running R-based ADaM Programs ---")

adam_r_programs <- c(
  "adam/programs/R/02_build_adam_pharmaverse.R"
)

for (prog in adam_r_programs) {
  prog_path <- file.path(root, prog)
  if (file.exists(prog_path)) {
    message(sprintf("\nExecuting: %s", prog))
    tryCatch({
      source(prog_path)
      message(sprintf("✓ SUCCESS: %s", prog))
    }, error = function(e) {
      message(sprintf("✗ ERROR in %s: %s", prog, e$message))
      stop(sprintf("ADaM pipeline failed at %s", prog))
    })
  } else {
    message(sprintf("⚠ SKIP: %s (file not found)", prog))
  }
}

# TODO: Add SAS program execution when SAS is available
message("\n--- SAS ADaM Programs ---")
message("⚠ SAS programs require SAS installation:")
message("  - adam/programs/sas/30_adam_adsl.sas")
message("  - adam/programs/sas/adam_*.sas (various analysis datasets)")

# Calculate elapsed time
end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "secs")

message("\n========================================")
message(sprintf("  ADaM Pipeline - Complete (%.1f sec)", elapsed))
message("========================================")
message(sprintf("\nADaM datasets written to: %s", adam_output_dir))
message("\nNext step: Generate TLFs or perform statistical analysis")
