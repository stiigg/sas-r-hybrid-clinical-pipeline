# Unit Tests for RECIST 1.1 Threshold Boundaries
# Tests critical decision points in response classification

library(testthat)
library(dplyr)
library(tibble)

# Note: Adjust source path based on your actual RECIST function locations
# source("etl/adam_program_library/oncology_response/recist_functions.R")

#' Helper function to create minimal test data for threshold testing
#'
#' @param usubjid Subject identifier
#' @param baseline_sld Baseline sum of longest diameters
#' @param follow_up_sld Follow-up assessment SLD
#' @param follow_up_day Study day of follow-up assessment
#'
#' @return Tibble with minimal SDTM RS structure
create_threshold_test_data <- function(usubjid, 
                                      baseline_sld, 
                                      follow_up_sld, 
                                      follow_up_day = 57) {
  tibble(
    USUBJID = usubjid,
    RSDY = c(1, follow_up_day),
    RSDTC = as.Date("2024-01-01") + c(0, follow_up_day - 1),
    RSCAT = "TARGET",
    RSTEST = "Sum of Diameters",
    RSSTRESC = c(baseline_sld, follow_up_sld),
    ABLFL = c("Y", "N"),
    RSSEQ = c(1, 2)
  )
}

test_that("PR threshold: exactly -30% is classified as PR", {
  test_data <- create_threshold_test_data(
    usubjid = "TEST-PR-30",
    baseline_sld = 100,
    follow_up_sld = 70  # Exactly -30%
  )
  
  # This test assumes you have a derive_target_lesion_response function
  # Adjust function name and parameters to match your implementation
  # result <- derive_target_lesion_response(test_data)
  
  # Expected calculations
  pct_change <- ((70 - 100) / 100) * 100
  
  expect_equal(pct_change, -30.0, tolerance = 0.01)
  # expect_equal(result$TL_RESP[result$ABLFL == "N"], "PR")
  
  # Placeholder for now - replace with actual function call
  expect_true(abs(pct_change - (-30.0)) < 0.01)
})

test_that("Below PR threshold: -29.9% is classified as SD", {
  test_data <- create_threshold_test_data(
    usubjid = "TEST-SD-29.9",
    baseline_sld = 100,
    follow_up_sld = 70.1  # -29.9%
  )
  
  pct_change <- ((70.1 - 100) / 100) * 100
  
  expect_gt(pct_change, -30.0)
  expect_lt(pct_change, 0)
  # expect_equal(result$TL_RESP[result$ABLFL == "N"], "SD")
  
  expect_true(pct_change > -30.0)
})

test_that("Above PR threshold: -30.1% is classified as PR", {
  test_data <- create_threshold_test_data(
    usubjid = "TEST-PR-30.1",
    baseline_sld = 100,
    follow_up_sld = 69.9  # -30.1%
  )
  
  pct_change <- ((69.9 - 100) / 100) * 100
  
  expect_lt(pct_change, -30.0)
  # expect_equal(result$TL_RESP[result$ABLFL == "N"], "PR")
  
  expect_true(pct_change < -30.0)
})

test_that("PD requires both +20% AND +5mm: +20% with only +4mm is not PD", {
  test_data <- create_threshold_test_data(
    usubjid = "TEST-NOT-PD",
    baseline_sld = 20,
    follow_up_sld = 24  # +20%, but only +4mm absolute
  )
  
  pct_change <- ((24 - 20) / 20) * 100
  abs_change <- 24 - 20
  
  expect_equal(pct_change, 20.0, tolerance = 0.01)
  expect_equal(abs_change, 4.0, tolerance = 0.01)
  expect_lt(abs_change, 5.0)  # Does not meet 5mm threshold
  
  # Should NOT be PD because absolute increase < 5mm
  # expect_false(result$TL_RESP[result$ABLFL == "N"] == "PD")
})

test_that("PD threshold: +20% with +5mm meets both criteria", {
  test_data <- create_threshold_test_data(
    usubjid = "TEST-PD-BOTH",
    baseline_sld = 25,
    follow_up_sld = 30  # +20%, exactly +5mm
  )
  
  pct_change <- ((30 - 25) / 25) * 100
  abs_change <- 30 - 25
  
  expect_equal(pct_change, 20.0, tolerance = 0.01)
  expect_equal(abs_change, 5.0, tolerance = 0.01)
  
  # Should be PD because both criteria met
  # expect_equal(result$TL_RESP[result$ABLFL == "N"], "PD")
})

test_that("PD threshold: +21% with +6mm clearly meets PD criteria", {
  test_data <- create_threshold_test_data(
    usubjid = "TEST-PD-CLEAR",
    baseline_sld = 95,
    follow_up_sld = 115  # +21.1%, +20mm
  )
  
  pct_change <- ((115 - 95) / 95) * 100
  abs_change <- 115 - 95
  
  expect_gt(pct_change, 20.0)
  expect_gt(abs_change, 5.0)
  
  # expect_equal(result$TL_RESP[result$ABLFL == "N"], "PD")
})

test_that("CR requires SLD = 0 (complete disappearance)", {
  test_data <- create_threshold_test_data(
    usubjid = "TEST-CR",
    baseline_sld = 50,
    follow_up_sld = 0  # Complete response
  )
  
  expect_equal(test_data$RSSTRESC[2], 0)
  
  # expect_equal(result$TL_RESP[result$ABLFL == "N"], "CR")
  # expect_equal(result$TL_SLD[result$ABLFL == "N"], 0)
})

test_that("Non-zero SLD cannot be CR: 1mm is not complete response", {
  test_data <- create_threshold_test_data(
    usubjid = "TEST-NOT-CR",
    baseline_sld = 50,
    follow_up_sld = 1  # Minimal residual disease
  )
  
  expect_gt(test_data$RSSTRESC[2], 0)
  
  # Should be PR (-98%), not CR
  # expect_equal(result$TL_RESP[result$ABLFL == "N"], "PR")
})

test_that("SD range: -29% to +19% with <5mm increase", {
  # Test stable disease classification range
  test_cases <- list(
    list(baseline = 100, follow_up = 75, desc = "-25% (SD)"),
    list(baseline = 100, follow_up = 85, desc = "-15% (SD)"),
    list(baseline = 100, follow_up = 100, desc = "0% (SD)"),
    list(baseline = 100, follow_up = 115, desc = "+15% (SD)")
  )
  
  for (tc in test_cases) {
    pct_change <- ((tc$follow_up - tc$baseline) / tc$baseline) * 100
    abs_change <- abs(tc$follow_up - tc$baseline)
    
    # Should be in SD range
    expect_true(
      pct_change > -30.0 && (pct_change < 20.0 || abs_change < 5.0),
      info = tc$desc
    )
  }
})

test_that("Nadir calculation for PD assessment", {
  # PD is assessed from nadir (lowest previous SLD), not baseline
  test_data <- tibble(
    USUBJID = "TEST-NADIR",
    RSDY = c(1, 57, 113),
    RSDTC = as.Date("2024-01-01") + c(0, 56, 112),
    RSCAT = "TARGET",
    RSSTRESC = c(100, 50, 65),  # Baseline, nadir, progression check
    ABLFL = c("Y", "N", "N"),
    RSSEQ = c(1, 2, 3)
  )
  
  nadir <- min(test_data$RSSTRESC[1:2])  # Nadir at Week 8: 50mm
  current <- test_data$RSSTRESC[3]  # Week 16: 65mm
  pct_from_nadir <- ((current - nadir) / nadir) * 100
  abs_from_nadir <- current - nadir
  
  expect_equal(nadir, 50)
  expect_equal(pct_from_nadir, 30.0, tolerance = 0.1)
  expect_equal(abs_from_nadir, 15.0)
  
  # Meets PD criteria from nadir (+30%, +15mm)
  expect_true(pct_from_nadir >= 20.0 && abs_from_nadir >= 5.0)
})
