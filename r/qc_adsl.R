# qc_adsl.R: simple QC of ADaM-style ADSL
library(haven)
library(dplyr)
library(readr)

root <- "/project-root"

adsl_path <- file.path(root, "data", "adam", "adsl.sas7bdat")
if (!file.exists(adsl_path)) {
  stop("ADSL file not found at: ", adsl_path,
       "\nRun the SAS steps 10_raw_import, 20_sdtm_dm, 30_adam_adsl first.")
}

adsl <- read_sas(adsl_path)

required_vars <- c("USUBJID", "SUBJID", "SEX", "AGE", "TRT01P", "TRT01A", "COUNTRY", "SAFFL")
missing_vars <- setdiff(required_vars, names(adsl))

qc_summary <- list(
  n_records      = nrow(adsl),
  missing_vars   = missing_vars,
  sex_counts     = count(adsl, SEX),
  trt_counts     = count(adsl, TRT01A),
  saffl_counts   = count(adsl, SAFFL),
  age_summary    = summary(adsl$AGE)
)

dir.create(file.path(root, "logs"), showWarnings = FALSE, recursive = TRUE)

write_csv(qc_summary$sex_counts,   file.path(root, "logs", "qc_adsl_sex_counts.csv"))
write_csv(qc_summary$trt_counts,   file.path(root, "logs", "qc_adsl_trt_counts.csv"))
write_csv(qc_summary$saffl_counts, file.path(root, "logs", "qc_adsl_saffl_counts.csv"))

sink(file.path(root, "logs", "qc_adsl_summary.txt"))
cat("ADSL QC SUMMARY\n\n")
cat("N records: ", qc_summary$n_records, "\n\n")
cat("Missing required vars:\n")
print(qc_summary$missing_vars)
cat("\nAge summary:\n")
print(qc_summary$age_summary)
sink()
