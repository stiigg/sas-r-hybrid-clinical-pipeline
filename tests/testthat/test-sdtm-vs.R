# Unit Tests for VS Domain Generation
# Author: Christian Baghai
# Date: 2024-12-24

library(testthat)
library(dplyr)

# Execute VS domain generation
test_that("VS domain generation executes without errors", {
  expect_error(
    source(here::here("sdtm", "programs", "R", "oak", "findings", "generate_vs_with_oak.R")),
    NA
  )
})

test_that("VS domain has required SDTM variables", {
  required_vars <- c(
    "STUDYID", "DOMAIN", "USUBJID", "VSSEQ",
    "VSTESTCD", "VSTEST", "VSORRES", "VSORRESU",
    "VSSTRESC", "VSSTRESN", "VSSTRESU",
    "VISITNUM", "VISIT", "VSDTC"
  )
  
  expect_true(
    all(required_vars %in% names(vs_final)),
    info = paste("Missing variables:", 
                 paste(setdiff(required_vars, names(vs_final)), collapse = ", "))
  )
})

test_that("VS DOMAIN variable is correctly populated", {
  expect_true(all(vs_final$DOMAIN == "VS"))
})

test_that("VS has at least one record", {
  expect_true(nrow(vs_final) > 0)
})

test_that("VS VSSEQ is unique within subject", {
  duplicates <- vs_final %>%
    group_by(USUBJID, VSSEQ) %>%
    filter(n() > 1) %>%
    nrow()
  
  expect_equal(duplicates, 0, 
               info = "VSSEQ should be unique within each USUBJID")
})

test_that("VS VSTESTCD values are from controlled terminology", {
  valid_testcd <- c("SYSBP", "DIABP", "PULSE", "TEMP", "RESP", "WEIGHT", "HEIGHT")
  
  expect_true(
    all(vs_final$VSTESTCD %in% valid_testcd),
    info = paste("Invalid VSTESTCD values:", 
                 paste(unique(vs_final$VSTESTCD[!vs_final$VSTESTCD %in% valid_testcd]), 
                       collapse = ", "))
  )
})

test_that("VS VSSTRESN is numeric", {
  numeric_results <- vs_final$VSSTRESN[!is.na(vs_final$VSSTRESN)]
  
  expect_true(
    all(is.numeric(numeric_results)),
    info = "VSSTRESN should be numeric"
  )
})

test_that("VS baseline flag (VSBLFL) is Y or NA", {
  valid_blfl <- c("Y", NA)
  
  expect_true(
    all(vs_final$VSBLFL %in% valid_blfl | is.na(vs_final$VSBLFL)),
    info = "VSBLFL should be 'Y' or NA"
  )
})

test_that("VS VSDTC is in ISO 8601 format", {
  iso_pattern <- "^\\d{4}-\\d{2}-\\d{2}(T\\d{2}:\\d{2}(:\\d{2})?)?$"
  
  expect_true(
    all(grepl(iso_pattern, vs_final$VSDTC[!is.na(vs_final$VSDTC)])),
    info = "VSDTC should be in ISO 8601 format"
  )
})

test_that("VS has consistent units for each test", {
  # Check that each VSTESTCD has only one unique unit
  unit_consistency <- vs_final %>%
    filter(!is.na(VSSTRESU)) %>%
    group_by(VSTESTCD) %>%
    summarise(unique_units = n_distinct(VSSTRESU)) %>%
    filter(unique_units > 1)
  
  expect_equal(nrow(unit_consistency), 0,
               info = "Each VSTESTCD should have consistent units")
})

test_that("VS CSV output file exists", {
  csv_path <- file.path(PATH_SDTM_CSV, "vs.csv")
  expect_true(file.exists(csv_path))
})

test_that("VS XPT output file exists", {
  xpt_path <- file.path(PATH_SDTM_XPT, "vs.xpt")
  expect_true(file.exists(xpt_path))
})
