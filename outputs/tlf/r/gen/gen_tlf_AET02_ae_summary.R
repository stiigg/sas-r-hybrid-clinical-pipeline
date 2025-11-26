#!/usr/bin/env Rscript

if (!exists("manifest_entry", inherits = FALSE)) {
  stop("manifest_entry not supplied. Generation scripts must be run via the batch orchestrator.")
}

source("outputs/tlf/r/utils/load_config.R")

required_pkgs <- c("haven", "dplyr", "rtables", "tern", "forcats")
missing <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop(sprintf("Missing required packages for AET02 generation: %s", paste(missing, collapse = ", ")), call. = FALSE)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || identical(x, "") || all(is.na(x))) y else x
}

config <- getOption("tlf.config") %||% load_tlf_config()
adam_dir <- config$paths$adam %||% "data/adam"

adae_path <- file.path(adam_dir, "adae.xpt")
if (!file.exists(adae_path)) {
  stop(sprintf("ADAE not found at %s", adae_path), call. = FALSE)
}

adae <- haven::read_xpt(adae_path)

adae <- adae %>%
  mutate(
    TRT01P = TRT01P %||% TRT01A %||% "Overall",
    AEBODSYS = forcats::fct_explicit_na(.data$AEBODSYS, na_level = "UNSPECIFIED"),
    AEDECOD = forcats::fct_explicit_na(.data$AEDECOD, na_level = "UNSPECIFIED")
  )

lyt <- rtables::basic_table() %>%
  tern::split_cols_by_groups("TRT01P", keep_totals = TRUE, col_label = "Treatment") %>%
  tern::analyze_num_patients_vars("USUBJID", denom = "n", na_str = "0") %>%
  tern::analyze_num_patients_vars("AESEQ", denom = "n", na_str = "0") %>%
  rtables::split_rows_by("AEBODSYS", nested = FALSE) %>%
  tern::summarize_num_patients("USUBJID", label = "Subjects with event") %>%
  rtables::split_rows_by("AEDECOD", nested = TRUE) %>%
  tern::summarize_num_patients("USUBJID", label = "Subjects with event")

tbl <- rtables::build_table(lyt, adae)

output_path <- get_tlf_output_path(manifest_entry$out_file)
rtables::export_as_pdf(tbl, file = output_path)

message(sprintf("AET02 table written to %s", output_path))
