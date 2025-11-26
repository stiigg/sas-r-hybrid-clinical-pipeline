#!/usr/bin/env Rscript

if (!exists("manifest_entry", inherits = FALSE)) {
  stop("manifest_entry not supplied. Generation scripts must be run via the batch orchestrator.")
}

source("outputs/tlf/r/utils/load_config.R")

required_pkgs <- c("haven", "dplyr", "tern", "rtables", "ggplot2")
missing <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop(sprintf("Missing required packages for FSTG02 generation: %s", paste(missing, collapse = ", ")), call. = FALSE)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || identical(x, "") || all(is.na(x))) y else x
}

config <- getOption("tlf.config") %||% load_tlf_config()
adam_dir <- config$paths$adam %||% "data/adam"

adtte_path <- file.path(adam_dir, "adtte.xpt")
if (!file.exists(adtte_path)) {
  stop(sprintf("ADTTE not found at %s", adtte_path), call. = FALSE)
}

adtte <- haven::read_xpt(adtte_path)

adtte_os <- adtte %>%
  filter(PARAMCD == "OS") %>%
  mutate(
    TRT01P = TRT01P %||% TRT01A %||% "Overall",
    ADT = if (inherits(ADT, "Date")) as.numeric(ADT - min(ADT, na.rm = TRUE)) else as.numeric(ADT),
    EVTTIME = ADT / 30.4375,
    EVENT = 1L - as.integer(CNSR %||% 0L)
  )

extract <- tern::extract_survival_subgroups(
  data = adtte_os,
  arm = "TRT01P",
  aval = "EVTTIME",
  cnsr = "CNSR",
  strata_vars = c("SEX", "BMRKR2")
)

tbl <- tern::tabulate_survival_subgroups(extract)

forest <- tern::g_forest(
  tbl,
  xlab = "Hazard Ratio (OS)",
  ref_line = 1
)

output_path <- get_tlf_output_path(manifest_entry$out_file)

ggplot2::ggsave(output_path, forest, width = 8, height = 6)

message(sprintf("FSTG02 forest plot written to %s", output_path))
