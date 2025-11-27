#' Build example ADaM datasets using pharmaverse tooling
#'
#' This function wraps the existing demonstration pipeline under
#' `etl/R/02_build_adam_pharmaverse.R` so it can be called from the
#' project-specific package API.
#'
#' @param sdtm_root Directory containing SDTM XPT files (expects dm.xpt and ae.xpt).
#' @param adam_root Directory where ADaM XPT files should be written.
#' @return Invisibly returns a list containing the created data frames.
#' @export
build_adam_pharmaverse <- function(sdtm_root = file.path("data", "sdtm"),
                                   adam_root = file.path("data", "adam")) {
  required_pkgs <- c("admiral", "dplyr", "haven", "lubridate")
  missing <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(
      sprintf("Missing required packages: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }

  dm_path <- ensure_input(file.path(sdtm_root, "dm.xpt"))
  ae_path <- ensure_input(file.path(sdtm_root, "ae.xpt"))

  dm <- haven::read_xpt(dm_path)
  ae <- haven::read_xpt(ae_path)
  dir.create(adam_root, showWarnings = FALSE, recursive = TRUE)

  adsl <- build_adsl(dm)
  adae <- build_adae(ae, adsl)
  adtte <- build_adtte(adsl)

  haven::write_xpt(adsl, file.path(adam_root, "adsl.xpt"))
  haven::write_xpt(adae, file.path(adam_root, "adae.xpt"))
  haven::write_xpt(adtte, file.path(adam_root, "adtte.xpt"))

  message(sprintf("Pharmaverse ADaM build complete at %s", adam_root))
  invisible(list(adsl = adsl, adae = adae, adtte = adtte))
}
