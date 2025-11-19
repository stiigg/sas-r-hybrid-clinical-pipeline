# Golden patient regression checks for oncology-critical ADaM datasets.

check_golden_patients <- function(data_root) {
  adtte_path <- file.path(data_root, "adam", "adtte.csv")
  adresp_path <- file.path(data_root, "adam", "adresp.csv")
  exp_adtte_path <- "validation/expected/expected_ADTTE_golden.csv"
  exp_adresp_path <- "validation/expected/expected_ADRESP_golden.csv"

  required_pkgs <- c("readr", "dplyr", "testthat")
  missing <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    message("[golden] Missing packages for golden patient check: ", paste(missing, collapse = ", "))
    return(invisible(FALSE))
  }

  paths <- c(adtte_path, adresp_path, exp_adtte_path, exp_adresp_path)
  if (!all(file.exists(paths))) {
    message("[golden] Skipping regression check – required files missing.")
    return(invisible(FALSE))
  }

  adtte <- readr::read_csv(adtte_path, show_col_types = FALSE)
  adresp <- readr::read_csv(adresp_path, show_col_types = FALSE)
  exp_adtte <- readr::read_csv(exp_adtte_path, show_col_types = FALSE)
  exp_adresp <- readr::read_csv(exp_adresp_path, show_col_types = FALSE)

  cmp_adtte <- dplyr::semi_join(adtte, exp_adtte, by = c("USUBJID", "PARAMCD")) |>
    dplyr::inner_join(exp_adtte, by = c("USUBJID", "PARAMCD"), suffix = c("_cur", "_exp"))
  cmp_adresp <- dplyr::semi_join(adresp, exp_adresp, by = c("USUBJID")) |>
    dplyr::inner_join(exp_adresp, by = c("USUBJID"), suffix = c("_cur", "_exp"))

  testthat::test_that("golden ADTTE matches expectations", {
    testthat::expect_equal(cmp_adtte$AVAL_cur, cmp_adtte$AVAL_exp)
    testthat::expect_equal(cmp_adtte$CNSR_cur, cmp_adtte$CNSR_exp)
  })

  testthat::test_that("golden ADRESP matches expectations", {
    testthat::expect_equal(cmp_adresp$BOR_cur, cmp_adresp$BOR_exp)
    testthat::expect_equal(cmp_adresp$RSPFL_cur, cmp_adresp$RSPFL_exp)
  })

  invisible(TRUE)
}
