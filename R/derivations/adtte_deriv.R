#' Build ADTTE dataset
#'
#' @param adsl Derived ADSL data frame providing subject-level variables.
#' @return ADTTE data frame with time-to-event derivations.
#' @noRd
build_adtte <- function(adsl) {
  adsl |>
    dplyr::transmute(
      STUDYID,
      USUBJID,
      TRT01P,
      TRT01A,
      SEX,
      AGEGR1,
      BMRKR2 = dplyr::if_else(dplyr::row_number() %% 2 == 0, "High", "Low"),
      PARAMCD = "OS",
      PARAM = "Overall Survival",
      ADT = as.numeric(dplyr::row_number() * 45),
      CNSR = rep(c(0, 1), length.out = dplyr::n()),
      EVENTDESC = dplyr::if_else(CNSR == 0, "Death", "Censored")
    )
}
