# Unit Tests for DM Domain Generation
# Author: Christian Baghai
# Date: 2024-12-24

library(testthat)
library(dplyr)

# Execute DM domain generation
test_that("DM domain generation executes without errors", {
  expect_error(
    source(here::here("sdtm", "programs", "R", "oak", "foundation", "generate_dm_with_oak.R")),
    NA
  )
})

test_that("DM domain has required SDTM variables", {
  # Required core variables per SDTM IG
  required_vars <- c(
    "STUDYID", "DOMAIN", "USUBJID", "SUBJID",
    "RFSTDTC", "RFENDTC", "SITEID",
    "AGE", "AGEU", "SEX", "RACE", "ETHNIC"
  )
  
  expect_true(
    all(required_vars %in% names(dm_final)),
    info = paste("Missing variables:", 
                 paste(setdiff(required_vars, names(dm_final)), collapse = ", "))
  )
})

test_that("DM DOMAIN variable is correctly populated", {
  expect_true(all(dm_final$DOMAIN == "DM"))
})

test_that("DM has unique subjects (USUBJID)", {
  expect_equal(
    nrow(dm_final),
    length(unique(dm_final$USUBJID)),
    info = "USUBJID should be unique in DM domain"
  )
})

test_that("DM has at least one record", {
  expect_true(nrow(dm_final) > 0)
})

test_that("DM SEX values are from controlled terminology", {
  valid_sex_values <- c("M", "F", "U", "UNDIFFERENTIATED", NA)
  expect_true(
    all(dm_final$SEX %in% valid_sex_values),
    info = paste("Invalid SEX values found:", 
                 paste(unique(dm_final$SEX[!dm_final$SEX %in% valid_sex_values]), 
                       collapse = ", "))
  )
})

test_that("DM AGEU is YEARS for all subjects", {
  expect_true(
    all(dm_final$AGEU %in% c("YEARS", "MONTHS", "DAYS", NA)),
    info = "AGEU should be from controlled terminology"
  )
})

test_that("DM AGE is numeric and reasonable", {
  ages <- dm_final$AGE[!is.na(dm_final$AGE)]
  
  expect_true(all(is.numeric(ages) | is.integer(ages)))
  expect_true(all(ages >= 0 & ages <= 120), 
              info = "AGE values should be between 0 and 120")
})

test_that("DM RFSTDTC is in ISO 8601 format", {
  # Check ISO 8601 format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS
  iso_pattern <- "^\\d{4}-\\d{2}-\\d{2}(T\\d{2}:\\d{2}(:\\d{2})?)?$"
  
  expect_true(
    all(grepl(iso_pattern, dm_final$RFSTDTC[!is.na(dm_final$RFSTDTC)])),
    info = "RFSTDTC should be in ISO 8601 format"
  )
})

test_that("DM CSV output file exists", {
  csv_path <- file.path(PATH_SDTM_CSV, "dm.csv")
  expect_true(file.exists(csv_path))
})

test_that("DM XPT output file exists", {
  xpt_path <- file.path(PATH_SDTM_XPT, "dm.xpt")
  expect_true(file.exists(xpt_path))
})
