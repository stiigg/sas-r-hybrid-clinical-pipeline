#!/usr/bin/env Rscript

# Repository-level orchestration entry point.
#
# The script coordinates three phases:
#   1. ETL steps defined in specs/etl_manifest.csv (SAS + R).
#   2. QC tasks defined in specs/qc_manifest.csv.
#   3. TLF generation based on specs/tlf/tlf_shell_map.csv.
#
# Each phase is metadata-driven and requires explicit dry-run environment
# variables (ETL_DRY_RUN, QC_DRY_RUN, TLF_DRY_RUN) set to boolean-like strings.

# ---- Required dry-run flags ----
required_flags <- c("ETL_DRY_RUN", "QC_DRY_RUN", "TLF_DRY_RUN")

missing_flags <- required_flags[Sys.getenv(required_flags, "") == ""]
if (length(missing_flags) > 0) {
  stop(
    sprintf(
      "Missing required environment flag(s): %s. Each must be 'true' or 'false'.",
      paste(missing_flags, collapse = ", ")
    )
  )
}

parse_bool <- function(env_var) {
  val <- tolower(Sys.getenv(env_var))
  if (!val %in% c("true", "false", "1", "0", "yes", "no", "y", "n")) {
    stop(sprintf("Environment variable %s must be a boolean-like string, got '%s'.",
                 env_var, val))
  }
  val %in% c("true", "1", "yes", "y")
}

# ---- Manifest validation helper ----
validate_manifest <- function(df, name, required_cols) {
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "%s missing required column(s): %s",
        name,
        paste(missing, collapse = ", ")
      )
    )
  }

  has_missing <- vapply(
    required_cols,
    function(col) any(is.na(df[[col]]) | df[[col]] == ""),
    logical(1)
  )
  if (any(has_missing)) {
    stop(
      sprintf(
        "%s has NA values in required column(s): %s",
        name,
        paste(required_cols[has_missing], collapse = ", ")
      )
    )
  }

  invisible(df)
}

source("etl/run_etl.R")
source("qc/run_qc.R")
source("outputs/tlf/r/utils/load_config.R")
source("outputs/tlf/r/utils/tlf_logging.R")
source("automation/r/tlf/batch/batch_run_all_tlfs.R")

# ---- Simple pipeline logger ----
if (!dir.exists("logs")) dir.create("logs", recursive = TRUE)
pipeline_log <- "logs/pipeline.log"

log_msg <- function(msg, log_file = pipeline_log) {
  line <- sprintf("[%s][%s] %s",
                  format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                  Sys.info()[["user"]],
                  msg)
  cat(line, "\n", file = log_file, append = TRUE)
  message(line)
}

if (!requireNamespace("digest", quietly = TRUE)) {
  stop("Package 'digest' is required for hashing manifests.")
}

config <- load_tlf_config()

etl_manifest_path <- "specs/etl_manifest.csv"
etl_manifest <- utils::read.csv(etl_manifest_path, stringsAsFactors = FALSE)
validate_manifest(
  etl_manifest,
  name = "ETL manifest",
  required_cols = c("step_id", "language", "script", "description")
)
etl_manifest_hash <- digest::digest(etl_manifest)
log_msg(sprintf("ETL manifest loaded from %s, hash=%s", etl_manifest_path, etl_manifest_hash))

qc_manifest_path <- "specs/qc_manifest.csv"
qc_manifest <- utils::read.csv(qc_manifest_path, stringsAsFactors = FALSE)
validate_manifest(
  qc_manifest,
  name = "QC manifest",
  required_cols = c("task_id", "runner", "language", "script", "description")
)
qc_manifest_hash <- digest::digest(qc_manifest)
log_msg(sprintf("QC manifest loaded from %s, hash=%s", qc_manifest_path, qc_manifest_hash))

tlf_manifest_path <- "specs/tlf/tlf_shell_map.csv"
tlf_manifest <- utils::read.csv(tlf_manifest_path, stringsAsFactors = FALSE)
validate_manifest(
  tlf_manifest,
  name = "TLF manifest",
  required_cols = c("tlf_id", "name", "gen_script", "qc_script", "out_file")
)
tlf_manifest_hash <- digest::digest(tlf_manifest)
log_msg(sprintf("TLF manifest loaded from %s, hash=%s", tlf_manifest_path, tlf_manifest_hash))

etl_dry_run <- parse_bool("ETL_DRY_RUN")
qc_dry_run  <- parse_bool("QC_DRY_RUN")
tlf_dry_run <- parse_bool("TLF_DRY_RUN")

log_msg(sprintf("ETL_DRY_RUN = %s", etl_dry_run))
log_msg(sprintf("QC_DRY_RUN  = %s", qc_dry_run))
log_msg(sprintf("TLF_DRY_RUN = %s", tlf_dry_run))

log_msg("Starting full pipeline run")

etl_results <- run_full_etl(manifest_path = etl_manifest_path, dry_run = etl_dry_run)
log_msg(sprintf("ETL phase completed with %s", paste(unique(etl_results$status), collapse = ",")))

qc_results <- run_qc_plan(
  manifest_path = qc_manifest_path,
  dry_run = qc_dry_run,
  config = if (qc_dry_run) NULL else config
)
qc_status <- paste(unique(qc_results$status), collapse = ",")
log_msg(sprintf("QC phase completed with %s", qc_status))
if (qc_dry_run) {
  log_msg("QC log check skipped: dry run mode")
} else {
  qc_log_postmortem()
}

gen_results <- if (tlf_dry_run) {
  data.frame(
    tlf_id = tlf_manifest$tlf_id,
    status = "dry_run",
    message = "Dry run - generation skipped",
    stringsAsFactors = FALSE
  )
} else {
  run_all_tlfs(config)
}

gen_status <- paste(unique(gen_results$status), collapse = ",")
log_msg(sprintf("TLF generation completed with %s", gen_status))

log_msg("Pipeline run finished")

invisible(list(etl = etl_results, qc = qc_results, generation = gen_results))
