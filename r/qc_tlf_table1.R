# qc_tlf_table1.R: independently compute subject counts by TRT01A
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

qc_counts <- adsl %>%
  group_by(TRT01A) %>%
  summarise(N = n(), .groups = "drop")

dir.create(file.path(root, "logs"), showWarnings = FALSE, recursive = TRUE)
write_csv(qc_counts, file.path(root, "logs", "qc_table1_counts_r.csv"))
