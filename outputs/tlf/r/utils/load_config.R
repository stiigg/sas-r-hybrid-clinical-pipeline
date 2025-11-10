# Helper utilities to load TLF configuration and shell manifests.

`%||%` <- function(x, y) {
  if (is.null(x) || (is.character(x) && length(x) == 0)) {
    y
  } else {
    x
  }
}

#' Load the YAML configuration file for the TLF subsystem.
#'
#' @param config_path Path to the YAML file. Defaults to
#'   "specs/tlf/tlf_config.yml".
#' @return A named list representing the configuration.
load_tlf_config <- function(config_path = "specs/tlf/tlf_config.yml") {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("The 'yaml' package is required to load the TLF configuration.", call. = FALSE)
  }

  config <- yaml::read_yaml(config_path)

  paths <- config$paths %||% list()
  options(
    tlf.config = config,
    tlf.paths = paths,
    tlf.output_dir = paths$output_dir %||% "outputs/tlf/r/output",
    tlf.log_dir = paths$log_dir %||% "logs",
    tlf.qc_report_dir = paths$qc_reports %||% "outputs/qc",
    tlf.default_population = config$options$default_population %||% NA_character_,
    tlf.default_qc_tolerance = config$options$default_qc_tolerance %||% 1e-6,
    tlf.archive_outputs = isTRUE(config$options$archive_outputs)
  )

  dir.create(getOption("tlf.output_dir"), showWarnings = FALSE, recursive = TRUE)
  dir.create(getOption("tlf.log_dir"), showWarnings = FALSE, recursive = TRUE)
  dir.create(getOption("tlf.qc_report_dir"), showWarnings = FALSE, recursive = TRUE)

  config
}

#' Load the CSV shell map that enumerates available TLFs.
#'
#' @param manifest_path Path to the CSV manifest.
#' @return A data.frame with at least columns tlf_id, gen_script, qc_script, out_file.
load_tlf_shell_map <- function(manifest_path = "specs/tlf/tlf_shell_map.csv") {
  config <- getOption("tlf.config")

  if (!is.null(config$shells)) {
    manifest <- as.data.frame(config$shells, stringsAsFactors = FALSE)
  } else {
    if (!file.exists(manifest_path)) {
      stop(sprintf("TLF manifest not found at '%s'", manifest_path), call. = FALSE)
    }

    manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
  }

  expected_cols <- c("tlf_id", "name", "gen_script", "qc_script", "out_file")
  missing_cols <- setdiff(expected_cols, names(manifest))
  if (length(missing_cols) > 0) {
    stop(sprintf("TLF manifest is missing required columns: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
  }

  manifest
}

#' Resolve the path to a generation or QC script.
#'
#' @param script_name File name from the manifest.
#' @param type Either "gen" or "qc" to indicate the directory.
#' @return The full path to the script within the process-oriented layout.
resolve_tlf_script_path <- function(script_name, type = c("gen", "qc")) {
  type <- match.arg(type)
  base_dir <- switch(type,
    gen = "outputs/tlf/r/gen",
    qc = "qc/r/tlf"
  )
  file.path(base_dir, script_name)
}

get_tlf_output_path <- function(filename) {
  file.path(getOption("tlf.output_dir", "outputs/tlf/r/output"), filename)
}

get_tlf_log_path <- function(filename) {
  file.path(getOption("tlf.log_dir", "logs"), filename)
}
