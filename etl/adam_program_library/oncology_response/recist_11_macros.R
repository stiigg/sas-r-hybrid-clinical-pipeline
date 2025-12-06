# RECIST 1.1 Response Derivation Functions
# Standardized across Compound-X NSCLC program
# Version: 1.0.0
# Last Updated: 2025-12-05

library(dplyr)
library(lubridate)

#' Derive Best Overall Response (BOR)
#'
#' Implements RECIST 1.1 criteria for best overall response
#' 
#' @param rs Response dataset (SDTM RS domain)
#' @param reference_date Date of randomization/treatment start
#' @param confirmation_required Logical, whether CR/PR require confirmation
#' @return Data frame with BOR derivations
#' 
#' @export
derive_bor <- function(rs, reference_date, confirmation_required = TRUE) {
  message("Deriving Best Overall Response (RECIST 1.1)")
  
  # Response hierarchy: CR > PR > SD > PD
  response_levels <- c("CR", "PR", "SD", "PD", "NE", "MISSING")
  
  rs_processed <- rs %>%
    arrange(USUBJID, RSDTC) %>%
    group_by(USUBJID) %>%
    mutate(
      # Parse assessment dates
      AVAL = case_when(
        RSSTRESC == "CR" ~ 1,
        RSSTRESC == "PR" ~ 2,
        RSSTRESC == "SD" ~ 3,
        RSSTRESC == "PD" ~ 4,
        RSSTRESC == "NE" ~ 5,
        TRUE ~ 6
      ),
      
      # Calculate time from reference
      DAYS_FROM_REF = as.numeric(
        as.Date(RSDTC) - as.Date(reference_date)
      )
    )
  
  if (confirmation_required) {
    # Implement confirmation logic (CR/PR must be confirmed ≥4 weeks later)
    rs_processed <- rs_processed %>%
      mutate(
        NEXT_RESPONSE = lead(RSSTRESC),
        NEXT_RESPONSE_DAYS = lead(DAYS_FROM_REF),
        CONFIRMED = case_when(
          RSSTRESC %in% c("CR", "PR") ~ 
            (NEXT_RESPONSE == RSSTRESC & 
             (NEXT_RESPONSE_DAYS - DAYS_FROM_REF) >= 28),
          TRUE ~ TRUE
        )
      ) %>%
      filter(CONFIRMED)
  }
  
  # Derive BOR as best confirmed response
  bor <- rs_processed %>%
    group_by(USUBJID) %>%
    summarize(
      BOR = RSSTRESC[which.min(AVAL)],
      BOR_DATE = RSDTC[which.min(AVAL)],
      .groups = "drop"
    )
  
  message(sprintf("BOR derived for %d patients", nrow(bor)))
  bor
}

#' Calculate Objective Response Rate (ORR)
#'
#' ORR = proportion of patients with CR or PR
#'
#' @param adrs Response analysis dataset with BOR
#' @return Data frame with ORR statistics
#' @export
calculate_orr <- function(adrs) {
  orr_summary <- adrs %>%
    summarize(
      N = n(),
      N_RESPONDERS = sum(BOR %in% c("CR", "PR"), na.rm = TRUE),
      ORR_PCT = (N_RESPONDERS / N) * 100,
      CI_LOWER = binom.test(N_RESPONDERS, N)$conf.int[1] * 100,
      CI_UPPER = binom.test(N_RESPONDERS, N)$conf.int[2] * 100
    )
  
  message(sprintf("ORR: %.1f%% (95%% CI: %.1f-%.1f%%)",
                  orr_summary$ORR_PCT,
                  orr_summary$CI_LOWER,
                  orr_summary$CI_UPPER))
  
  orr_summary
}

#' Derive Duration of Response (DoR)
#'
#' Time from first response (CR/PR) to PD or death
#'
#' @param adrs Response dataset
#' @param adsl Subject-level dataset with death dates
#' @return Data frame with DoR calculations
#' @export
derive_dor <- function(adrs, adsl) {
  # Implementation of DoR calculation
  # (Simplified for demonstration)
  
  responders <- adrs %>%
    filter(BOR %in% c("CR", "PR")) %>%
    select(USUBJID, RESPONSE_DATE = BOR_DATE)
  
  progression <- adrs %>%
    filter(RSSTRESC == "PD") %>%
    group_by(USUBJID) %>%
    slice_min(RSDTC, n = 1) %>%
    select(USUBJID, PD_DATE = RSDTC)
  
  dor <- responders %>%
    left_join(progression, by = "USUBJID") %>%
    left_join(adsl %>% select(USUBJID, DTH_DATE = DTHDT), by = "USUBJID") %>%
    mutate(
      EVENT_DATE = pmin(PD_DATE, DTH_DATE, na.rm = TRUE),
      DOR_DAYS = as.numeric(as.Date(EVENT_DATE) - as.Date(RESPONSE_DATE)),
      DOR_MONTHS = DOR_DAYS / 30.4375,
      CNSR = as.numeric(is.na(EVENT_DATE))
    )
  
  message(sprintf("DoR calculated for %d responders", nrow(dor)))
  dor
}
