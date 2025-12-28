################################################################################
# Script: imwg_waterfall_plot.R
# Purpose: Generate waterfall plot for IMWG M-protein response
# Author: Christian Baghai
# Date: December 2025
################################################################################

library(ggplot2)
library(dplyr)
library(haven)

# Load IMWG response data
adrs_imwg <- read.csv("outputs/adam/adrs_imwg_admiral.csv")

# Prepare data for waterfall plot
waterfall_data <- adrs_imwg %>%
  filter(!is.na(PCHG_SPROT), VISIT != "BASELINE") %>%
  group_by(USUBJID) %>%
  # Get best (most negative) percent change for each subject
  slice_min(PCHG_SPROT, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  arrange(PCHG_SPROT) %>%
  mutate(
    USUBJID_ORDER = factor(USUBJID, levels = USUBJID),
    # Color by response category
    RESPONSE_COLOR = case_when(
      IMWG_RESP == "sCR" ~ "#00441b",  # Dark green
      IMWG_RESP == "CR" ~ "#238b45",   # Green
      IMWG_RESP == "VGPR" ~ "#74c476", # Light green
      IMWG_RESP == "PR" ~ "#bae4b3",   # Very light green
      IMWG_RESP == "SD" ~ "#969696",   # Gray
      IMWG_RESP == "PD" ~ "#d73027",   # Red
      TRUE ~ "#bdbdbd"                  # Light gray (NE)
    )
  )

# Create waterfall plot
p <- ggplot(waterfall_data, aes(x = USUBJID_ORDER, y = PCHG_SPROT, fill = IMWG_RESP)) +
  geom_col() +
  # Add threshold lines
  geom_hline(yintercept = -50, linetype = "dashed", color = "#238b45", linewidth = 0.8) +
  geom_hline(yintercept = -90, linetype = "dashed", color = "#00441b", linewidth = 0.8) +
  geom_hline(yintercept = 25, linetype = "dashed", color = "#d73027", linewidth = 0.8) +
  # Annotations
  annotate("text", x = 2, y = -55, label = "PR (-50%)", color = "#238b45", hjust = 0) +
  annotate("text", x = 2, y = -95, label = "VGPR (-90%)", color = "#00441b", hjust = 0) +
  annotate("text", x = 2, y = 30, label = "PD (+25%)", color = "#d73027", hjust = 0) +
  # Styling
  scale_fill_manual(
    values = c("sCR" = "#00441b", "CR" = "#238b45", "VGPR" = "#74c476",
               "PR" = "#bae4b3", "SD" = "#969696", "PD" = "#d73027", "NE" = "#bdbdbd"),
    name = "IMWG Response"
  ) +
  labs(
    title = "IMWG Response: Best M-Protein Reduction Waterfall Plot",
    subtitle = "Multiple Myeloma IMWG Criteria (2016)",
    x = "Subject ID",
    y = "Best % Change in M-Protein from Baseline"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 8),
    plot.title = element_text(face = "bold", size = 14),
    panel.grid.minor = element_blank()
  )

# Save plot
ggsave("outputs/figures/imwg_waterfall_plot.png", p, width = 12, height = 6, dpi = 300)

cat("Waterfall plot saved: outputs/figures/imwg_waterfall_plot.png\n")
