#' Build ADTTE dataset
#'
#' Creates a CDISC ADaM-compliant ADTTE (Analysis Dataset Time-To-Event) dataset
#' with proper derivation of time-to-event variables including AVAL, censoring,
#' and traceability variables required for regulatory submissions.
#'
#' @param adsl Derived ADSL data frame providing subject-level variables.
#'   Must contain RANDDT (randomization date) for proper time calculations.
#' @return ADTTE data frame with time-to-event derivations following
#'   CDISC ADaM BDS v1.0 structure.
#' @noRd
build_adtte <- function(adsl) {
  adsl |>
    dplyr::transmute(
      # Core identifiers
      STUDYID,
      USUBJID,
      
      # Treatment variables
      TRT01P,
      TRT01A,
      
      # Demographics
      SEX,
      AGEGR1,
      
      # Biomarker stratification (simulated)
      BMRKR2 = dplyr::if_else(dplyr::row_number() %% 2 == 0, "High", "Low"),
      
      # Time-to-event parameter identification
      PARAMCD = "OS",
      PARAM = "Overall Survival",
      
      # Date variables for time calculation
      # STARTDT: Reference start date (typically randomization date)
      STARTDT = RANDDT,
      
      # ADT: Analysis date (event or censor date)
      # In production: would derive from actual death dates (ADSL.DTHDT) or
      # last known alive dates. Here simulated for demonstration.
      ADT = RANDDT + (dplyr::row_number() * 45),
      
      # AVAL: Analysis value (TIME TO EVENT IN DAYS) - REQUIRED VARIABLE
      # This is the primary variable used in survival analysis (Kaplan-Meier, Cox)
      AVAL = as.numeric(ADT - STARTDT),
      
      # ADY: Analysis relative day (study day of event/censor)
      # ADaM convention: study day = date - reference date + 1 (no day 0)
      ADY = as.numeric(ADT - STARTDT) + 1,
      
      # Censoring indicator
      # 0 = Event occurred (death)
      # 1 = Censored (alive at last contact)
      CNSR = rep(c(0, 1), length.out = dplyr::n()),
      
      # Event description (human-readable)
      EVENTDESC = dplyr::if_else(CNSR == 0, "Death", "Censored"),
      
      # Traceability variables (required for regulatory submissions)
      # SRCDOM: Source domain where the data originated
      SRCDOM = "ADSL",
      
      # SRCVAR: Source variable(s) used for derivation
      # In production: would be "DTHDT" for deaths, "LSTALVDT" for censored
      SRCVAR = dplyr::if_else(CNSR == 0, "DTHDT", "LSTALVDT")
    )
}
