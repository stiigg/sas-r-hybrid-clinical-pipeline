#!/usr/bin/env Rscript
# validation/recist_validator.R
# Lightweight RECIST rule checks against SDTM TU/TR domains

library(dplyr)
library(readr)
library(haven)

message("Running RECIST validator for TU/TR domains...")

if (!file.exists("data/sdtm/tu.xpt") || !file.exists("data/sdtm/tr.xpt")) {
  message("No TU/TR XPT files found; skipping RECIST validation.")
  quit(status = 0)
}

tu <- read_xpt("data/sdtm/tu.xpt")
tr <- read_xpt("data/sdtm/tr.xpt")

errors <- list()

# Max 5 target lesions per organ
limit_check <- tu %>%
  filter(TUEVAL == "TARGET") %>%
  count(SUBJID, ORGAN) %>%
  filter(n > 5)
if (nrow(limit_check) > 0) {
  errors[[length(errors) + 1]] <- paste0("Target lesion limit exceeded for ", paste(limit_check$SUBJID, collapse = ", "))
}

# Ensure TR rows link to TU identifiers
unlinked_tr <- tr %>%
  anti_join(tu %>% select(SUBJID, TULNKID), by = c("SUBJID", "TULNKID"))
if (nrow(unlinked_tr) > 0) {
  errors[[length(errors) + 1]] <- "TR records found without matching TU identifiers"
}

if (length(errors) > 0) {
  message("::error::RECIST 1.1 compliance failures detected")
  message(paste(errors, collapse = "\n"))
  quit(status = 1)
}

message("RECIST validation passed")
