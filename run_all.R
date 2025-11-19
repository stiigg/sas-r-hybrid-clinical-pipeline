#!/usr/bin/env Rscript

# Repository-level orchestration entry point.
#
# The script coordinates three phases:
#   1. ETL steps defined in specs/etl_manifest.csv (SAS + R).
#   2. QC tasks defined in specs/qc_manifest.csv.
#   3. TLF generation based on specs/tlf/tlf_shell_map.csv.
#
# Each phase is metadata-driven and respects environment variables
# (ETL_DRY_RUN, QC_DRY_RUN, TLF_DRY_RUN) which now default to safe dry-run
# values when not explicitly provided.

# --- Dependency management ----------------------------------------------------

required_cran_pkgs <- c(
  "digest",
  "yaml",
  "dplyr",
  "readr",
  "purrr",
  "tidyr",
  "stringr",
  "glue",
  "jsonlite",
  "openxlsx",
  "haven"
  # TODO: add any other CRAN packages used in etl/qc/tlf scripts
)

install_missing_pkgs <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) == 0L) {
    message("All required packages already installed.")
    return(invisible(TRUE))
  }

  message("Installing missing packages: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
}

install_missing_pkgs(required_cran_pkgs)
invisible(lapply(required_cran_pkgs, require, character.only = TRUE))

# --- Environment configuration -----------------------------------------------

get_bool_env <- function(var, default = TRUE) {
  raw <- Sys.getenv(var, NA_character_)
  if (is.na(raw) || !nzchar(raw)) {
    return(default)
  }
  tolower(raw) %in% c("false", "0", "no", "n") |> `!`()
}

ETL_DRY_RUN  <- get_bool_env("ETL_DRY_RUN",  default = TRUE)
QC_DRY_RUN   <- get_bool_env("QC_DRY_RUN",   default = TRUE)
TLF_DRY_RUN  <- get_bool_env("TLF_DRY_RUN",  default = TRUE)

message("Configuration:")
message("  ETL_DRY_RUN  = ", ETL_DRY_RUN)
message("  QC_DRY_RUN   = ", QC_DRY_RUN)
message("  TLF_DRY_RUN  = ", TLF_DRY_RUN)

check_sas_available <- function() {
  status <- tryCatch(
    system("sas -help > /dev/null 2>&1"),
    error = function(e) 1L
  )

  if (!identical(status, 0L)) {
    stop(
      "SAS does not appear to be available on this system.\n",
      "For full ETL, ensure that:\n",
      "  * SAS is installed, and\n",
      "  * the 'sas' executable is on your PATH\n",
      "Or re-run with ETL_DRY_RUN=true to skip SAS-dependent steps.",
      call. = FALSE
    )
  }
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
if (file.exists("R/mdr_utils.R")) {
  source("R/mdr_utils.R")
}

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

config <- load_tlf_config()

etl_manifest_path <- "specs/etl_manifest.csv"
etl_manifest <- utils::read.csv(etl_manifest_path, stringsAsFactors = FALSE)
validate_manifest(
  etl_manifest,
  name = "ETL manifest",
  required_cols = c("step_id", "dataset", "script", "engine", "description", "parity_group")
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

etl_dry_run <- ETL_DRY_RUN
qc_dry_run  <- QC_DRY_RUN
tlf_dry_run <- TLF_DRY_RUN

log_msg(sprintf("ETL_DRY_RUN = %s", etl_dry_run))
log_msg(sprintf("QC_DRY_RUN  = %s", qc_dry_run))
log_msg(sprintf("TLF_DRY_RUN = %s", tlf_dry_run))

log_msg("Starting full pipeline run")

if (!etl_dry_run) {
  check_sas_available()
}

etl_results <- run_full_etl(
  manifest_path = etl_manifest_path,
  dry_run = etl_dry_run
)
log_msg(sprintf("ETL phase completed with %s", paste(unique(etl_results$status), collapse = ",")))

if (!etl_dry_run) {
  adam_checks <- tryCatch({
    spec <- read_adam_dataset_spec()
    ensure_adam_datasets(spec)
  }, error = function(err) {
    stop(err)
  })
  log_msg(sprintf(
    "Verified %d ADaM dataset expectation(s) from specs/adam/adam_dataset_spec.csv",
    nrow(adam_checks)
  ))
}

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
