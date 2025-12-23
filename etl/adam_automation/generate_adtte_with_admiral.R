#!/usr/bin/env Rscript
#=============================================================================
# ADaM ADTTE GENERATION WITH ADMIRAL/ADMIRALONCO
# Time-to-Event Endpoints: PFS and Duration of Response
#=============================================================================

library(admiral)
library(admiralonco)
library(dplyr)
library(lubridate)
library(haven)
library(here)
library(logger)

log_info("Generating ADTTE with admiral/admiralonco")

# Create output directory
dir.create(here("outputs", "adam"), recursive = TRUE, showWarnings = FALSE)

# Read required datasets
adsl_path <- here("outputs", "adam", "adsl.xpt")
adrs_path <- here("outputs", "adam", "adrs_admiral.xpt")

if (!file.exists(adsl_path) || !file.exists(adrs_path)) {
  log_error("ADSL or ADRS not found. Run generate_adrs_with_admiral.R first.")
  stop("Missing prerequisite datasets")
}

adsl <- read_xpt(adsl_path) %>% convert_blanks_to_na()
adrs <- read_xpt(adrs_path) %>% convert_blanks_to_na()

log_info("Loaded ADSL: {nrow(adsl)} subjects")
log_info("Loaded ADRS: {nrow(adrs)} records")

#=============================================================================
# PARAMETER 1: PROGRESSION-FREE SURVIVAL (PFS)
#=============================================================================

log_info("\nDeriving PFS (Progression-Free Survival)...")

# Define PFS event: first PD or death
adtte_pfs <- derive_param_tte(
  dataset_adsl = adsl,
  source_datasets = list(adrs = adrs),
  start_date = TRTSDT,
  
  # Event: Progression (PD)
  event_conditions = list(
    disease_progression = expr(
      PARAMCD == "OVR" & AVALC == "PD"
    )
  ),
  
  # Censoring rules per RECIST 1.1
  censor_conditions = list(
    # Last adequate assessment without PD
    last_assessment = expr(
      PARAMCD == "OVR" & AVALC %in% c("CR", "PR", "SD")
    ),
    # Treatment end if no PD observed
    tx_end = expr(
      ADT == TRTEDT
    )
  ),
  
  set_values_to = exprs(
    PARAMCD = "PFS",
    PARAM = "Progression-Free Survival",
    PARCAT1 = "Time-to-Event",
    AVAL = as.numeric(difftime(ADT, TRTSDT, units = "days")),
    AVALU = "DAYS"
  )
)

log_info("Derived PFS for {nrow(adtte_pfs)} subjects")
log_info("  Events: {sum(adtte_pfs$CNSR == 0, na.rm = TRUE)}")
log_info("  Censored: {sum(adtte_pfs$CNSR == 1, na.rm = TRUE)}")

#=============================================================================
# PARAMETER 2: DURATION OF RESPONSE (DoR)
#=============================================================================

log_info("\nDeriving DoR (Duration of Response)...")

# Duration of Response: CR/PR confirmed to PD or death
adtte_dor <- derive_param_dor(
  dataset_adsl = adsl,
  dataset_adrs = adrs,
  
  # Define response criteria (CR or PR)
  filter_source = PARAMCD == "CBOR" & AVALC %in% c("CR", "PR"),
  
  # Start date: first confirmed response
  start_date = TRTSDT,
  
  # Event: first PD after response
  event_conditions = list(
    progression = expr(
      PARAMCD == "OVR" & AVALC == "PD" & ADT > TRTSDT
    )
  ),
  
  # Censoring: last assessment without PD
  censor_conditions = list(
    last_visit = expr(
      PARAMCD == "OVR" & AVALC %in% c("CR", "PR", "SD")
    )
  ),
  
  set_values_to = exprs(
    PARAMCD = "DOR",
    PARAM = "Duration of Response",
    PARCAT1 = "Time-to-Event",
    AVAL = as.numeric(difftime(ADT, TRTSDT, units = "days")),
    AVALU = "DAYS"
  )
)

log_info("Derived DoR for {nrow(adtte_dor)} responders")
if (nrow(adtte_dor) > 0) {
  log_info("  Events: {sum(adtte_dor$CNSR == 0, na.rm = TRUE)}")
  log_info("  Censored: {sum(adtte_dor$CNSR == 1, na.rm = TRUE)}")
  log_info("  Median DoR: {median(adtte_dor$AVAL[adtte_dor$CNSR == 0], na.rm = TRUE)} days")
} else {
  log_warn("No responders (CR/PR) found for DoR calculation")
}

#=============================================================================
# PARAMETER 3: TIME TO RESPONSE (TTR) - BONUS
#=============================================================================

log_info("\nDeriving TTR (Time to Response)...")

# Time to Response: treatment start to first CR/PR
adtte_ttr <- adrs %>%
  filter(PARAMCD == "OVR", AVALC %in% c("CR", "PR")) %>%
  group_by(USUBJID) %>%
  arrange(ADT) %>%
  slice(1) %>%
  ungroup() %>%
  left_join(adsl, by = c("STUDYID", "USUBJID")) %>%
  transmute(
    STUDYID, USUBJID,
    PARAMCD = "TTR",
    PARAM = "Time to Response",
    PARCAT1 = "Time-to-Event",
    AVAL = as.numeric(difftime(ADT, TRTSDT.y, units = "days")),
    AVALU = "DAYS",
    ADT = ADT,
    CNSR = 0,  # All are events (achieved response)
    AVISIT = "Overall",
    TRT01A = TRT01A,
    TRT01P = TRT01P
  )

log_info("Derived TTR for {nrow(adtte_ttr)} responders")
if (nrow(adtte_ttr) > 0) {
  log_info("  Median TTR: {median(adtte_ttr$AVAL, na.rm = TRUE)} days")
}

#=============================================================================
# COMBINE AND FINALIZE ADTTE
#=============================================================================

log_info("\nCombining all time-to-event parameters...")

# Combine all TTE parameters
adtte_final <- bind_rows(
  adtte_pfs,
  adtte_dor,
  adtte_ttr
) %>%
  arrange(USUBJID, PARAMCD, ADT) %>%
  group_by(USUBJID) %>%
  mutate(
    ASEQ = row_number(),
    # Convert days to months for easier interpretation
    AVAL_MONTHS = round(AVAL / 30.4375, 2)
  ) %>%
  ungroup() %>%
  # Add study day
  mutate(
    ADY = as.integer(difftime(ADT, TRTSDT, units = "days")) + 1
  )

log_info("Final ADTTE: {nrow(adtte_final)} records")

# Summary statistics by parameter
summary_stats <- adtte_final %>%
  group_by(PARAMCD, PARAM) %>%
  summarise(
    N = n(),
    Events = sum(CNSR == 0, na.rm = TRUE),
    Censored = sum(CNSR == 1, na.rm = TRUE),
    Median_Days = median(AVAL[CNSR == 0], na.rm = TRUE),
    Median_Months = round(Median_Days / 30.4375, 1),
    .groups = "drop"
  )

log_info("\n=== ADTTE Summary Statistics ===")
for (i in 1:nrow(summary_stats)) {
  log_info("{summary_stats$PARAM[i]}:")
  log_info("  N = {summary_stats$N[i]}")
  log_info("  Events = {summary_stats$Events[i]}")
  log_info("  Censored = {summary_stats$Censored[i]}")
  log_info("  Median = {summary_stats$Median_Days[i]} days ({summary_stats$Median_Months[i]} months)")
}

#=============================================================================
# WRITE OUTPUTS
#=============================================================================

# Write ADTTE XPT
output_path <- here("outputs", "adam", "adtte_admiral.xpt")

if (requireNamespace("xportr", quietly = TRUE)) {
  xportr::xportr_write(
    adtte_final,
    path = output_path,
    label = "Time-to-Event Analysis Dataset",
    domain = "ADTTE"
  )
  log_info("✓ ADTTE written: {output_path}")
} else {
  write_xpt(adtte_final, output_path)
  log_info("✓ ADTTE written (haven): {output_path}")
}

# Save CSV
csv_path <- here("outputs", "adam", "adtte_admiral.csv")
write.csv(adtte_final, csv_path, row.names = FALSE)
log_info("✓ CSV version saved: {csv_path}")

# Save summary statistics
summary_path <- here("outputs", "adam", "adtte_summary.csv")
write.csv(summary_stats, summary_path, row.names = FALSE)
log_info("✓ Summary statistics: {summary_path}")

message("\n========================================")
message("ADaM ADTTE Generation Complete")
message("========================================")
message(sprintf("Total records: %d", nrow(adtte_final)))
message(sprintf("Subjects: %d", length(unique(adtte_final$USUBJID))))
message(sprintf("Parameters: %s", paste(unique(adtte_final$PARAMCD), collapse = ", ")))
message(sprintf("Output: %s", output_path))
message("========================================\n")
