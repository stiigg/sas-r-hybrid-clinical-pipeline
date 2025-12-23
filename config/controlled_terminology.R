# CDISC Controlled Terminology Specifications for sdtm.oak
# Author: Christian Baghai
# Date: 2024-12-24
# Description: CT specifications in format required by sdtm.oak v0.2.0

library(tibble)

# Initialize controlled terminology specification list
oak_ct_spec <- list()

# Study Identifier
oak_ct_spec$studyid <- tibble(
  codelist_code = "STUDYID",
  term_code = "PROTO001",
  term_value = "PROTO001",
  collected_value = "PROTO001",
  term_preferred_term = "Protocol 001"
)

# Age Units (C66781)
oak_ct_spec$ageu <- tibble(
  codelist_code = c("C66781", "C66781", "C66781"),
  term_code = c("C29848", "C29846", "C25564"),
  term_value = c("YEARS", "MONTHS", "DAYS"),
  collected_value = c("Years", "Months", "Days"),
  term_preferred_term = c("Year", "Month", "Day")
)

# Sex (C66731)
oak_ct_spec$sex <- tibble(
  codelist_code = c("C66731", "C66731", "C66731", "C66731"),
  term_code = c("C20197", "C16576", "C17998", "C45908"),
  term_value = c("M", "F", "U", "UNDIFFERENTIATED"),
  collected_value = c("Male", "Female", "Unknown", "Undifferentiated"),
  term_preferred_term = c("Male", "Female", "Unknown", "Undifferentiated"),
  term_synonyms = c("M", "F", NA, NA)
)

# Race (C74457)
oak_ct_spec$race <- tibble(
  codelist_code = rep("C74457", 7),
  term_code = c("C41261", "C41219", "C41260", "C41257", "C17998", "C41259", "C41222"),
  term_value = c(
    "AMERICAN INDIAN OR ALASKA NATIVE",
    "ASIAN",
    "BLACK OR AFRICAN AMERICAN",
    "NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER",
    "UNKNOWN",
    "WHITE",
    "MULTIPLE"
  ),
  collected_value = c(
    "American Indian or Alaska Native",
    "Asian",
    "Black or African American",
    "Native Hawaiian or Other Pacific Islander",
    "Unknown",
    "White",
    "Multiple"
  ),
  term_preferred_term = c(
    "American Indian or Alaska Native",
    "Asian",
    "Black or African American",
    "Native Hawaiian or Other Pacific Islander",
    "Unknown",
    "White",
    "Multiple Race"
  )
)

# Ethnicity (C66790)
oak_ct_spec$ethnic <- tibble(
  codelist_code = c("C66790", "C66790", "C66790"),
  term_code = c("C41222", "C41221", "C17998"),
  term_value = c("HISPANIC OR LATINO", "NOT HISPANIC OR LATINO", "UNKNOWN"),
  collected_value = c("Hispanic or Latino", "Not Hispanic or Latino", "Unknown"),
  term_preferred_term = c("Hispanic or Latino", "Not Hispanic or Latino", "Unknown")
)

# Country (C66789) - Sample subset
oak_ct_spec$country <- tibble(
  codelist_code = rep("C66789", 5),
  term_code = c("C16592", "C16628", "C16761", "C16804", "C17142"),
  term_value = c("USA", "CAN", "GBR", "FRA", "DEU"),
  collected_value = c("United States", "Canada", "United Kingdom", "France", "Germany"),
  term_preferred_term = c(
    "United States of America",
    "Canada",
    "United Kingdom",
    "France",
    "Germany"
  ),
  term_synonyms = c("US;United States", "CA", "UK", "FR", "DE")
)

# Yes/No Response (C66742)
oak_ct_spec$ny <- tibble(
  codelist_code = c("C66742", "C66742", "C66742"),
  term_code = c("C49487", "C49488", "C48660"),
  term_value = c("Y", "N", "U"),
  collected_value = c("Yes", "No", "Unknown"),
  term_preferred_term = c("Yes", "No", "Unknown")
)

# AE Severity (C66769)
oak_ct_spec$aesev <- tibble(
  codelist_code = c("C66769", "C66769", "C66769"),
  term_code = c("C41338", "C41337", "C41339"),
  term_value = c("MILD", "MODERATE", "SEVERE"),
  collected_value = c("Mild", "Moderate", "Severe"),
  term_preferred_term = c("Mild", "Moderate", "Severe")
)

# VS Test Code (C67153) - Vital Signs
oak_ct_spec$vstestcd <- tibble(
  codelist_code = rep("C67153", 6),
  term_code = c("C25298", "C25299", "C25158", "C49673", "C49676", "C25677"),
  term_value = c("SYSBP", "DIABP", "PULSE", "TEMP", "RESP", "WEIGHT"),
  collected_value = c(
    "Systolic Blood Pressure",
    "Diastolic Blood Pressure",
    "Pulse Rate",
    "Temperature",
    "Respiratory Rate",
    "Weight"
  ),
  term_preferred_term = c(
    "Systolic Blood Pressure",
    "Diastolic Blood Pressure",
    "Pulse Rate",
    "Temperature",
    "Respiratory Rate",
    "Weight"
  )
)

# Units (C71620) - Common vital signs units
oak_ct_spec$unit <- tibble(
  codelist_code = rep("C71620", 8),
  term_code = c("C49673", "C49676", "C49677", "C48155", "C64848", "C48531", "C67388", "C49670"),
  term_value = c("mmHg", "beats/min", "breaths/min", "kg", "cm", "C", "F", "lb"),
  collected_value = c(
    "mmHg",
    "beats/min",
    "breaths/min",
    "kg",
    "cm",
    "degrees Celsius",
    "degrees Fahrenheit",
    "pounds"
  ),
  term_preferred_term = c(
    "Millimeter of Mercury",
    "Beats per Minute",
    "Breaths per Minute",
    "Kilogram",
    "Centimeter",
    "Degree Celsius",
    "Degree Fahrenheit",
    "Pound"
  )
)

message("Controlled terminology specifications loaded successfully")
message("Available CT specs: ", paste(names(oak_ct_spec), collapse = ", "))
