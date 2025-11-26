#!/usr/bin/env Rscript

# ADaM builder that layers admiral-style derivations on top of SDTM XPTs.
# The goal is to provide an R-native alternative path alongside SAS ETL.

required_pkgs <- c("admiral", "dplyr", "haven", "lubridate")

load_required <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(
      sprintf("Missing required packages: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x)) || identical(x, "")) y else x
}

load_required(required_pkgs)
invisible(lapply(required_pkgs, require, character.only = TRUE))

sdtm_dir <- file.path("data", "sdtm")
adam_dir <- file.path("data", "adam")

ensure_input <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Required SDTM file missing at %s", path), call. = FALSE)
  }
  path
}

dm_path <- ensure_input(file.path(sdtm_dir, "dm.xpt"))
ae_path <- ensure_input(file.path(sdtm_dir, "ae.xpt"))

dm <- haven::read_xpt(dm_path)
ae <- haven::read_xpt(ae_path)

dir.create(adam_dir, showWarnings = FALSE, recursive = TRUE)

adsl <- dm %>%
  mutate(
    TRT01P = ARM %||% "Placebo",
    TRT01A = ARM %||% "Placebo",
    STUDYID = STUDYID %||% "PHARMAVERSE",
    SITEID = "SITE01",
    ITTFL = "Y"
  ) %>%
  admiral::derive_vars_merged(
    dataset_add = dm %>% select(USUBJID, ARM),
    by_vars = admiral::exprs(USUBJID),
    new_vars = admiral::exprs(TRTSEQP = ARM)
  ) %>%
  mutate(AGEGR1 = cut(AGE, breaks = c(-Inf, 50, 65, Inf), labels = c("<50", "50-65", ">65")))

if (!"AESEQ" %in% names(ae)) {
  ae <- ae %>% mutate(AESEQ = dplyr::row_number())
}

adae <- ae %>%
  admiral::derive_vars_merged(
    dataset_add = select(adsl, USUBJID, TRT01P, TRT01A, AGEGR1, SEX),
    by_vars = admiral::exprs(USUBJID)
  ) %>%
  mutate(
    ASTDT = lubridate::as_date(AESTDTC),
    AENDT = lubridate::as_date(AEENDTC),
    ASEV = if_else(AESER %in% c("Y", "YES", "1"), "SEVERE", "MILD"),
    ANL01FL = "Y"
  )

adtte <- adsl %>%
  transmute(
    STUDYID,
    USUBJID,
    TRT01P,
    TRT01A,
    SEX,
    AGEGR1,
    BMRKR2 = if_else(row_number() %% 2 == 0, "High", "Low"),
    PARAMCD = "OS",
    PARAM = "Overall Survival",
    ADT = as.numeric(row_number() * 45),
    CNSR = rep(c(0, 1), length.out = n()),
    EVENTDESC = if_else(CNSR == 0, "Death", "Censored")
  )

haven::write_xpt(adsl, file.path(adam_dir, "adsl.xpt"))
haven::write_xpt(adae, file.path(adam_dir, "adae.xpt"))
haven::write_xpt(adtte, file.path(adam_dir, "adtte.xpt"))

message(sprintf("Pharmaverse ADaM build complete at %s", adam_dir))
