# QC script for Table 14.1.1 generation demo.

if (!exists("manifest_entry", inherits = FALSE)) {
  stop("manifest_entry not supplied. QC scripts must be run via the batch orchestrator.")
}

source("r/tlf/config/load_config.R")
source("r/tlf/utils/tlf_logging.R")

output_path <- get_tlf_output_path(manifest_entry$out_file)
log_file <- paste0(manifest_entry$tlf_id, "_qc.log")

if (!file.exists(output_path)) {
  stop(sprintf("Expected TLF output missing at %s", output_path))
}

tlf_log(sprintf("Validated existence of %s", output_path), log_file = log_file)

qc_report <- file.path(getOption("tlf.qc_report_dir"), paste0(manifest_entry$tlf_id, "_qc.txt"))
dir.create(dirname(qc_report), recursive = TRUE, showWarnings = FALSE)

report_lines <- c(
  sprintf("QC report for %s", manifest_entry$tlf_id),
  sprintf("Output path: %s", output_path),
  sprintf("Checked at: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "Checks:",
  " - [x] Output file exists"
)

writeLines(report_lines, qc_report)

tlf_log(sprintf("QC report written to %s", qc_report), log_file = log_file)

invisible(qc_report)
