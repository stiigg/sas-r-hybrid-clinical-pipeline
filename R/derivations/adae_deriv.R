#' Build ADAE dataset
#'
#' @param ae SDTM AE data frame.
#' @param adsl Derived ADSL data frame providing subject-level variables.
#' @return ADAE data frame with merged treatment and AE derivations.
#' @noRd
build_adae <- function(ae, adsl) {
  if (!"AESEQ" %in% names(ae)) {
    ae <- ae |>
      dplyr::mutate(AESEQ = dplyr::row_number())
  }

  ae |>
    admiral::derive_vars_merged(
      dataset_add = dplyr::select(adsl, USUBJID, TRT01P, TRT01A, AGEGR1, SEX),
      by_vars = admiral::exprs(USUBJID)
    ) |>
    dplyr::mutate(
      ASTDT = lubridate::as_date(AESTDTC),
      AENDT = lubridate::as_date(AEENDTC),
      ASEV = dplyr::if_else(AESER %in% c("Y", "YES", "1"), "SEVERE", "MILD"),
      ANL01FL = "Y"
    )
}
