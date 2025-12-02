# qc/r/survival/qc_pfs_analysis.R
# R-based double programming check for PFS using ADTTE

library(dplyr)
library(haven)
library(survival)
library(survminer)

adtte <- read_xpt("data/adam/adtte.xpt") %>%
  filter(PARAMCD == "PFS")

cox_model <- coxph(Surv(AVAL, 1 - CNSR) ~ TRT01PN + AGE + SEX, data = adtte)
cox_zph_test <- cox.zph(cox_model)

if (any(cox_zph_test$table[, "p"] < 0.05)) {
  warning("Proportional hazards assumption violated")
}

km_fit <- survfit(Surv(AVAL, 1 - CNSR) ~ TRT01PN, data = adtte)

km_plot <- ggsurvplot(
  km_fit,
  data = adtte,
  risk.table = TRUE,
  pval = TRUE,
  conf.int = TRUE,
  xlab = "Time (days)",
  ylab = "Progression-Free Survival",
  break.time.by = 90,
  ggtheme = theme_bw()
)

if (!dir.exists("outputs/qc")) dir.create("outputs/qc", recursive = TRUE)
ggsave("outputs/qc/km_pfs.pdf", plot = km_plot$plot, width = 10, height = 8)

sas_median <- read.csv("outputs/tlf/median_pfs.csv")
r_median <- summary(km_fit)$table[, "median"]

if (any(abs(r_median - sas_median$median) > 1)) {
  cat("FAIL: Median PFS discrepancy detected\n")
} else {
  cat("PASS: R-SAS survival outputs concordant\n")
}
