# Unit tests for RECIST 1.1 derivation functions
# Ensures quality and consistency across program

library(testthat)
source("etl/adam_program_library/oncology_response/recist_11_macros.R")

test_that("derive_bor correctly identifies CR as best response", {
  # Mock RS data
  rs_test <- data.frame(
    USUBJID = rep("001", 3),
    RSSTRESC = c("PR", "CR", "CR"),
    RSDTC = as.Date(c("2024-01-15", "2024-02-15", "2024-03-15")),
    stringsAsFactors = FALSE
  )
  
  ref_date <- as.Date("2024-01-01")
  
  result <- derive_bor(rs_test, ref_date, confirmation_required = TRUE)
  
  expect_equal(result$BOR[1], "CR")
  expect_equal(as.Date(result$BOR_DATE[1]), as.Date("2024-02-15"))
})

test_that("calculate_orr produces valid confidence intervals", {
  adrs_test <- data.frame(
    USUBJID = paste0("00", 1:100),
    BOR = c(rep("CR", 10), rep("PR", 20), rep("SD", 40), rep("PD", 30)),
    stringsAsFactors = FALSE
  )
  
  result <- calculate_orr(adrs_test)
  
  expect_equal(result$N, 100)
  expect_equal(result$N_RESPONDERS, 30)
  expect_equal(result$ORR_PCT, 30)
  expect_true(result$CI_LOWER > 0 && result$CI_LOWER < 30)
  expect_true(result$CI_UPPER > 30 && result$CI_UPPER < 100)
})

test_that("derive_bor handles missing data appropriately", {
  rs_test <- data.frame(
    USUBJID = "001",
    RSSTRESC = NA_character_,
    RSDTC = as.Date("2024-01-15"),
    stringsAsFactors = FALSE
  )
  
  ref_date <- as.Date("2024-01-01")
  
  result <- derive_bor(rs_test, ref_date)
  
  expect_equal(result$BOR[1], "MISSING")
})
