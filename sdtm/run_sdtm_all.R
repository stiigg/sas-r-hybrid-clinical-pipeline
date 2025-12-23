#!/usr/bin/env Rscript

# Master SDTM Pipeline Runner
# Executes all SDTM mapping programs in sequence

message("========================================")
message("  SDTM Pipeline - Starting")
message("========================================")

# Set working directory to project root
if (basename(getwd()) == "sdtm") {
  setwd("..")
}

root <- getwd()
message(sprintf("Project root: %s", root))

# Create output directory
sdtm_output_dir <- file.path(root, "sdtm", "data", "output")
dir.create(sdtm_output_dir, showWarnings = FALSE, recursive = TRUE)

# Track start time
start_time <- Sys.time()

# Run R-based SDTM programs
message("\n--- Running R-based SDTM Programs ---")

sdtm_r_programs <- c(
  "sdtm/programs/R/01_build_sdtm_pharmaverse.R"
)

for (prog in sdtm_r_programs) {
  prog_path <- file.path(root, prog)
  if (file.exists(prog_path)) {
    message(sprintf("\nExecuting: %s", prog))
    tryCatch({
      source(prog_path)
      message(sprintf("✓ SUCCESS: %s", prog))
    }, error = function(e) {
      message(sprintf("✗ ERROR in %s: %s", prog, e$message))
      stop(sprintf("SDTM pipeline failed at %s", prog))
    })
  } else {
    message(sprintf("⚠ SKIP: %s (file not found)", prog))
  }
}

# TODO: Add SAS program execution when SAS is available
message("\n--- SAS SDTM Programs ---")
message("⚠ SAS programs require SAS installation:")
message("  - sdtm/programs/sas/20_sdtm_dm.sas")
message("  - sdtm/programs/sas/sdtm_tu_tr.sas")

# Calculate elapsed time
end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "secs")

message("\n========================================")
message(sprintf("  SDTM Pipeline - Complete (%.1f sec)", elapsed))
message("========================================")
message(sprintf("\nSDTM datasets written to: %s", sdtm_output_dir))
message("\nNext step: Run ADaM pipeline with source('adam/run_adam_all.R')")
