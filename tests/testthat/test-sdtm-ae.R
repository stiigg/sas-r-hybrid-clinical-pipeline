# Unit Tests for AE Domain Generation
# Author: Christian Baghai
# Date: 2024-12-24

library(testthat)
library(dplyr)

# Execute AE domain generation
test_that("AE domain generation executes without errors", {
  expect_error(
    source(here::here("sdtm", "programs", "R", "oak", "events", "generate_ae_with_oak.R")),
    NA
  )
})

test_that("AE domain has required SDTM variables", {
  required_vars <- c(
    "STUDYID", "DOMAIN", "USUBJID", "AESEQ",
    "AETERM", "AEDECOD", "AESEV", "AESER",
    "AESTDTC", "AEENDTC"
  )
  
  expect_true(
    all(required_vars %in% names(ae_final)),
    info = paste("Missing variables:", 
                 paste(setdiff(required_vars, names(ae_final)), collapse = ", "))
  )
})

test_that("AE DOMAIN variable is correctly populated", {
  expect_true(all(ae_final$DOMAIN == "AE"))
})

test_that("AE has at least one record", {
  expect_true(nrow(ae_final) > 0)
})

test_that("AE AESEQ is unique within subject", {
  duplicates <- ae_final %>%
    group_by(USUBJID, AESEQ) %>%
    filter(n() > 1) %>%
    nrow()
  
  expect_equal(duplicates, 0, 
               info = "AESEQ should be unique within each USUBJID")
})

test_that("AE AESEV values are from controlled terminology", {
  valid_sev <- c("MILD", "MODERATE", "SEVERE", NA)
  
  expect_true(
    all(ae_final$AESEV %in% valid_sev),
    info = paste("Invalid AESEV values:", 
                 paste(unique(ae_final$AESEV[!ae_final$AESEV %in% valid_sev]), 
                       collapse = ", "))
  )
})

test_that("AE AESER (serious flag) is Y, N, or NA", {
  valid_ser <- c("Y", "N", "U", NA)
  
  expect_true(
    all(ae_final$AESER %in% valid_ser),
    info = paste("Invalid AESER values:", 
                 paste(unique(ae_final$AESER[!ae_final$AESER %in% valid_ser]), 
                       collapse = ", "))
  )
})

test_that("AE AETERM is not empty", {
  expect_true(
    all(!is.na(ae_final$AETERM) & nchar(ae_final$AETERM) > 0),
    info = "AETERM should not be empty or NA"
  )
})

test_that("AE AESTDTC is in ISO 8601 format", {
  iso_pattern <- "^\\d{4}-\\d{2}-\\d{2}(T\\d{2}:\\d{2}(:\\d{2})?)?$"
  
  expect_true(
    all(grepl(iso_pattern, ae_final$AESTDTC[!is.na(ae_final$AESTDTC)])),
    info = "AESTDTC should be in ISO 8601 format"
  )
})

test_that("AE end date is not before start date", {
  dates_to_check <- ae_final %>%
    filter(!is.na(AESTDTC) & !is.na(AEENDTC)) %>%
    mutate(
      start_date = as.Date(substr(AESTDTC, 1, 10)),
      end_date = as.Date(substr(AEENDTC, 1, 10)),
      invalid = end_date < start_date
    )
  
  expect_equal(
    sum(dates_to_check$invalid, na.rm = TRUE), 0,
    info = "AEENDTC should not be before AESTDTC"
  )
})

test_that("AE duration (AEDUR) is non-negative", {
  durations <- ae_final$AEDUR[!is.na(ae_final$AEDUR)]
  
  expect_true(
    all(durations >= 0),
    info = "AEDUR should be non-negative"
  )
})

test_that("AE CSV output file exists", {
  csv_path <- file.path(PATH_SDTM_CSV, "ae.csv")
  expect_true(file.exists(csv_path))
})

test_that("AE XPT output file exists", {
  xpt_path <- file.path(PATH_SDTM_XPT, "ae.xpt")
  expect_true(file.exists(xpt_path))
})
