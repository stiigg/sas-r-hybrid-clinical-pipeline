# Synthetic ETL helpers for SAS-free demos and CI runs.

generate_mock_dm <- function(n = 100) {
  set.seed(123)
  subjects <- sprintf("%03d", seq_len(n))
  data.frame(
    STUDYID = "MOCKSTUDY",
    DOMAIN = "DM",
    USUBJID = paste0("MOCK-", subjects),
    SUBJID = subjects,
    SITEID = sample(sprintf("SITE%02d", 1:5), n, replace = TRUE),
    ARM = sample(c("Placebo", "Active"), n, replace = TRUE),
    SEX = sample(c("M", "F"), n, replace = TRUE),
    AGE = sample(30:80, n, replace = TRUE),
    RACE = sample(c("WHITE", "ASIAN", "BLACK"), n, replace = TRUE),
    TRTSDT = as.Date("2024-01-01") + sample(0:30, n, replace = TRUE),
    TRTSDTM = as.POSIXct(as.Date("2024-01-01") + sample(0:30, n, replace = TRUE)),
    ARMCD = substr(sample(c("PBO", "TRT"), n, replace = TRUE), 1, 3),
    stringsAsFactors = FALSE
  )
}

generate_mock_adsl <- function(dm_data) {
  if (is.null(dm_data) || nrow(dm_data) == 0) {
    stop("DM data required to build mock ADSL", call. = FALSE)
  }
  adsl <- dm_data
  adsl$SAFFL <- "Y"
  adsl$ITTFL <- "Y"
  adsl$EFFICACYFL <- sample(c("Y", "N"), nrow(dm_data), replace = TRUE, prob = c(0.9, 0.1))
  adsl$RANDDT <- adsl$TRTSDT - sample(1:7, nrow(dm_data), replace = TRUE)
  adsl$ANALYSIS_VISIT <- sample(1:5, nrow(dm_data), replace = TRUE)
  adsl
}
