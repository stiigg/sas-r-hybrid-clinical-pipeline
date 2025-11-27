#' Build ADSL dataset
#'
#' @param dm SDTM DM data frame.
#' @return ADSL data frame with derived treatment and demographic variables.
#' @noRd
build_adsl <- function(dm) {
  dm |>
    dplyr::mutate(
      TRT01P = ARM %||% "Placebo",
      TRT01A = ARM %||% "Placebo",
      STUDYID = STUDYID %||% "PHARMAVERSE",
      SITEID = "SITE01",
      ITTFL = "Y"
    ) |>
    admiral::derive_vars_merged(
      dataset_add = dm |>
        dplyr::select(USUBJID, ARM),
      by_vars = admiral::exprs(USUBJID),
      new_vars = admiral::exprs(TRTSEQP = ARM)
    ) |>
    dplyr::mutate(AGEGR1 = cut(AGE, breaks = c(-Inf, 50, 65, Inf), labels = c("<50", "50-65", ">65")))
}
