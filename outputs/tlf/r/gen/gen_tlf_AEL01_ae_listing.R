#!/usr/bin/env Rscript

if (!exists("manifest_entry", inherits = FALSE)) {
  stop("manifest_entry not supplied. Generation scripts must be run via the batch orchestrator.")
}

source("outputs/tlf/r/utils/load_config.R")

required_pkgs <- c("haven", "dplyr", "rlistings")
missing <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop(sprintf("Missing required packages for AEL01 generation: %s", paste(missing, collapse = ", ")), call. = FALSE)
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
    ASTDT = as.character(ASTDT %||% AESTDTC),
    AENDT = as.character(AENDT %||% AEENDTC)
  )

listing <- adae %>%
  select(USUBJID, TRT01P, AEBODSYS, AEDECOD, AETERM, ASTDT, AENDT) %>%
  rlistings::as_listing(
    key_vars = c("USUBJID", "TRT01P", "AEBODSYS", "AEDECOD"),
    disp_vars = c("AETERM", "ASTDT", "AENDT"),
    main_title = "Listing of Adverse Events (AEL01)"
  )

output_path <- get_tlf_output_path(manifest_entry$out_file)
rlistings::export_listing(listing, file = output_path)

message(sprintf("AEL01 listing written to %s", output_path))
