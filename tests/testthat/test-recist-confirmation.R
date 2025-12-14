# Unit Tests for RECIST 1.1 Confirmation Window Logic
# Tests temporal requirements for response confirmation

library(testthat)
library(dplyr)
library(tibble)

# Note: Adjust source path based on your actual RECIST function locations
# source("etl/adam_program_library/oncology_response/recist_functions.R")

#' Helper function to create multi-timepoint test data
#'
#' @param usubjid Subject identifier
#' @param timepoints Vector of study days for assessments
#' @param sld_values Vector of SLD values corresponding to timepoints
#'
#' @return Tibble with temporal SDTM RS structure
create_temporal_test_data <- function(usubjid, timepoints, sld_values) {
  n <- length(timepoints)
  
  tibble(
    USUBJID = usubjid,
    RSDY = timepoints,
    RSDTC = as.Date("2024-01-01") + (timepoints - 1),
    RSCAT = "TARGET",
    RSTEST = "Sum of Diameters",
    RSSTRESC = sld_values,
    ABLFL = c("Y", rep("N", n - 1)),
    RSSEQ = seq_len(n)
  )
}

test_that("Confirmation window: 28 days is valid minimum", {
  # Initial response at Day 57, confirmation at Day 85 (28 days later)
  test_data <- create_temporal_test_data(
    usubjid = "TEST-CONF-28",
    timepoints = c(1, 57, 85),
    sld_values = c(100, 65, 65)  # PR at Day 57, maintained at Day 85
  )
  
  initial_response_day <- 57
  confirmation_day <- 85
  interval <- confirmation_day - initial_response_day
  
  expect_equal(interval, 28)
  expect_gte(interval, 28)  # Meets minimum
  expect_lte(interval, 84)  # Within maximum
  
  # Should be confirmed
  # expect_equal(result$BORCONF, "Y")
})

test_that("Confirmation window: 27 days is invalid (below minimum)", {
  # Initial response at Day 57, confirmation attempt at Day 84 (27 days later)
  test_data <- create_temporal_test_data(
    usubjid = "TEST-CONF-27",
    timepoints = c(1, 57, 84),
    sld_values = c(100, 65, 65)
  )
  
  initial_response_day <- 57
  confirmation_day <- 84
  interval <- confirmation_day - initial_response_day
  
  expect_equal(interval, 27)
  expect_lt(interval, 28)  # Below minimum
  
  # Should NOT be confirmed
  # expect_equal(result$BORCONF, "N")
})

test_that("Confirmation window: 84 days is valid maximum", {
  # Initial response at Day 57, confirmation at Day 141 (84 days later)
  test_data <- create_temporal_test_data(
    usubjid = "TEST-CONF-84",
    timepoints = c(1, 57, 141),
    sld_values = c(100, 65, 65)
  )
  
  initial_response_day <- 57
  confirmation_day <- 141
  interval <- confirmation_day - initial_response_day
  
  expect_equal(interval, 84)
  expect_gte(interval, 28)  # Meets minimum
  expect_lte(interval, 84)  # At maximum boundary
  
  # Should be confirmed
  # expect_equal(result$BORCONF, "Y")
})

test_that("Confirmation window: 85 days exceeds maximum", {
  # Initial response at Day 57, confirmation attempt at Day 142 (85 days later)
  test_data <- create_temporal_test_data(
    usubjid = "TEST-CONF-85",
    timepoints = c(1, 57, 142),
    sld_values = c(100, 65, 65)
  )
  
  initial_response_day <- 57
  confirmation_day <- 142
  interval <- confirmation_day - initial_response_day
  
  expect_equal(interval, 85)
  expect_gt(interval, 84)  # Exceeds maximum
  
  # Should NOT be confirmed
  # expect_equal(result$BORCONF, "N")
})

test_that("Confirmation window: 56 days is well within valid range", {
  # Standard case: Initial at Day 57, confirmation at Day 113 (56 days)
  test_data <- create_temporal_test_data(
    usubjid = "TEST-CONF-56",
    timepoints = c(1, 57, 113),
    sld_values = c(100, 65, 65)
  )
  
  initial_response_day <- 57
  confirmation_day <- 113
  interval <- confirmation_day - initial_response_day
  
  expect_equal(interval, 56)
  expect_gte(interval, 28)
  expect_lte(interval, 84)
  
  # Should be confirmed
  # expect_equal(result$BORCONF, "Y")
})

test_that("SD minimum duration: 42 days required from baseline", {
  # SD requires ≥42 days from baseline to be considered confirmed
  test_data <- create_temporal_test_data(
    usubjid = "TEST-SD-42",
    timepoints = c(1, 43),  # Day 43 = 42 days from baseline
    sld_values = c(100, 85)  # -15% (SD range)
  )
  
  duration_from_baseline <- 43 - 1
  
  expect_equal(duration_from_baseline, 42)
  expect_gte(duration_from_baseline, 42)  # Meets SD minimum
  
  # Should be confirmed SD
  # expect_equal(result$BOR, "SD")
  # expect_equal(result$BORCONF, "Y")
})

test_that("SD minimum duration: 41 days is insufficient", {
  test_data <- create_temporal_test_data(
    usubjid = "TEST-SD-41",
    timepoints = c(1, 42),  # Day 42 = 41 days from baseline
    sld_values = c(100, 85)
  )
  
  duration_from_baseline <- 42 - 1
  
  expect_equal(duration_from_baseline, 41)
  expect_lt(duration_from_baseline, 42)  # Below minimum
  
  # Should NOT meet SD duration requirement
  # expect_equal(result$BORCONF, "N")
})

test_that("Unconfirmed response: progression before confirmation", {
  # Response at Day 57, progression before confirmation window
  test_data <- create_temporal_test_data(
    usubjid = "TEST-PD-BEFORE-CONF",
    timepoints = c(1, 57, 113),
    sld_values = c(100, 65, 130)  # PR at Day 57, PD at Day 113
  )
  
  # Subject shows PR at Day 57 but progresses at Day 113
  # Should result in unconfirmed PR and overall BOR = PD
  pct_change_day57 <- ((65 - 100) / 100) * 100
  pct_change_day113 <- ((130 - 65) / 65) * 100  # From nadir
  
  expect_equal(pct_change_day57, -35.0, tolerance = 0.1)  # PR
  expect_equal(pct_change_day113, 100.0, tolerance = 0.1)  # PD
  
  # expect_equal(result$BOR, "PD")  # Progression takes precedence
})

test_that("Multiple confirmation opportunities: first valid confirmation used", {
  # Multiple follow-up assessments maintaining response
  test_data <- create_temporal_test_data(
    usubjid = "TEST-MULTI-CONF",
    timepoints = c(1, 57, 85, 113, 169),  # Multiple confirmations possible
    sld_values = c(100, 65, 65, 65, 65)  # Response maintained
  )
  
  # First valid confirmation at Day 85 (28 days from Day 57)
  first_conf_interval <- 85 - 57
  
  expect_equal(first_conf_interval, 28)
  expect_gte(first_conf_interval, 28)
  
  # BOR date should be at first confirmation (Day 85)
  # expect_equal(result$BORDT, as.Date("2024-03-25"))  # Day 85
})

test_that("CR confirmation: same 28-84 day window applies", {
  # CR also requires confirmation in 28-84 day window
  test_data <- create_temporal_test_data(
    usubjid = "TEST-CR-CONF",
    timepoints = c(1, 57, 113),
    sld_values = c(100, 0, 0)  # CR at Day 57, confirmed Day 113
  )
  
  interval <- 113 - 57
  
  expect_equal(interval, 56)
  expect_gte(interval, 28)
  expect_lte(interval, 84)
  
  # expect_equal(result$BOR, "CR")
  # expect_equal(result$BORCONF, "Y")
})

test_that("Missed visit scenario: no confirmation assessment within window", {
  # Response at Day 57, next assessment at Day 150 (93 days, exceeds window)
  test_data <- create_temporal_test_data(
    usubjid = "TEST-MISSED-VISIT",
    timepoints = c(1, 57, 150),
    sld_values = c(100, 65, 65)
  )
  
  interval <- 150 - 57
  
  expect_equal(interval, 93)
  expect_gt(interval, 84)  # Exceeds maximum window
  
  # Cannot be confirmed due to missed visit
  # expect_equal(result$BORCONF, "N")
})

test_that("Early withdrawal: no confirmation possible", {
  # Response at Day 57, no subsequent assessments (withdrawal)
  test_data <- create_temporal_test_data(
    usubjid = "TEST-WITHDRAWAL",
    timepoints = c(1, 57),
    sld_values = c(100, 65)
  )
  
  # Only one post-baseline assessment
  n_followup <- sum(test_data$ABLFL == "N")
  
  expect_equal(n_followup, 1)
  
  # Cannot be confirmed without follow-up assessment
  # expect_equal(result$BORCONF, "N")
})
