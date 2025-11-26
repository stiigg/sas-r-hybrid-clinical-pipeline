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

  `%||%` <- function(x, y) {
    if (is.null(x) || length(x) == 0 || all(is.na(x)) || identical(x, "")) y else x
  }

  ensure_input <- function(path) {
    if (!file.exists(path)) {
      stop(sprintf("Required SDTM file missing at %s", path), call. = FALSE)
    }
    path
  }

  dm_path <- ensure_input(file.path(sdtm_root, "dm.xpt"))
  ae_path <- ensure_input(file.path(sdtm_root, "ae.xpt"))

  dm <- haven::read_xpt(dm_path)
  ae <- haven::read_xpt(ae_path)
  dir.create(adam_root, showWarnings = FALSE, recursive = TRUE)

  adsl <- dm |>
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

  if (!"AESEQ" %in% names(ae)) {
    ae <- ae |>
      dplyr::mutate(AESEQ = dplyr::row_number())
  }

  adae <- ae |>
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

  adtte <- adsl |>
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

  haven::write_xpt(adsl, file.path(adam_root, "adsl.xpt"))
  haven::write_xpt(adae, file.path(adam_root, "adae.xpt"))
  haven::write_xpt(adtte, file.path(adam_root, "adtte.xpt"))

  message(sprintf("Pharmaverse ADaM build complete at %s", adam_root))
  invisible(list(adsl = adsl, adae = adae, adtte = adtte))
}
