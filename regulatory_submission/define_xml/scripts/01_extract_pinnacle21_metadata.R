################################################################################
# Program: 01_extract_pinnacle21_metadata.R
# Purpose: Generate XPT files and extract baseline metadata via Pinnacle 21
# Author: Clinical Programming Team
# Date: 2026-01-01
#
# Inputs:
#   - sdtm/data/*.sas7bdat (SDTM datasets from SAS programs)
#   - sdtm/specs/*_spec_v2.csv (transformation specifications)
#
# Outputs:
#   - regulatory_submission/define_xml/metadata/xpt_files/*.xpt
#   - regulatory_submission/define_xml/metadata/pinnacle21_spec.xlsx (manual)
#   - regulatory_submission/define_xml/metadata/pinnacle21_parsed.rds
################################################################################

library(haven)
library(xportr)
library(dplyr)
library(readxl)
library(purrr)
library(cli)
library(yaml)

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("  PHASE 1: XPT Generation & Pinnacle 21 Metadata Extraction    \n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Load configuration
config <- read_yaml("regulatory_submission/define_xml/config/study_config.yml")

# Configuration
sdtm_data_dir <- config$paths$sdtm_data
xpt_output_dir <- file.path(config$paths$metadata, "xpt_files")
metadata_dir <- config$paths$metadata
pinnacle_spec <- file.path(metadata_dir, "pinnacle21_spec.xlsx")

# Create output directories
dir.create(xpt_output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(metadata_dir, recursive = TRUE, showWarnings = FALSE)

################################################################################
# Step 1: Generate XPT Transport Files for Pinnacle 21
################################################################################

cli_h2("Step 1: Generating SAS XPT Transport Files")

# Find all SDTM datasets
sdtm_files <- list.files(
  sdtm_data_dir,
  pattern = "\\.(sas7bdat|rds)$",
  full.names = TRUE
)

if (length(sdtm_files) == 0) {
  cli_alert_warning("No SDTM datasets found in {sdtm_data_dir}")
  cli_alert_info("Creating demo dataset for testing...")
  
  # Create minimal demo DM dataset
  demo_dm <- data.frame(
    STUDYID = rep("STUDY001", 10),
    DOMAIN = rep("DM", 10),
    USUBJID = paste0("STUDY001-001-", sprintf("%03d", 1:10)),
    SUBJID = sprintf("%03d", 1:10),
    RFSTDTC = "2024-01-15",
    SITEID = "001",
    AGE = sample(50:75, 10, replace = TRUE),
    AGEU = rep("YEARS", 10),
    SEX = sample(c("M", "F"), 10, replace = TRUE),
    RACE = sample(c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN"), 10, replace = TRUE),
    ARMCD = sample(c("TRT", "PBO"), 10, replace = TRUE),
    ARM = ifelse(sample(c("TRT", "PBO"), 10, replace = TRUE) == "TRT", "Treatment", "Placebo"),
    COUNTRY = "USA",
    stringsAsFactors = FALSE
  )
  
  # Save demo
  dir.create(sdtm_data_dir, recursive = TRUE, showWarnings = FALSE)
  haven::write_sas(demo_dm, file.path(sdtm_data_dir, "dm.sas7bdat"))
  
  sdtm_files <- list.files(sdtm_data_dir, pattern = "\\.sas7bdat$", full.names = TRUE)
  cli_alert_success("Created demo DM dataset")
}

cli_alert_info("Found {length(sdtm_files)} SDTM dataset(s)")
cat("\n")

# Generate XPT files with metadata preservation
xpt_manifest <- tibble(
  dataset = character(),
  xpt_path = character(),
  num_records = integer(),
  num_vars = integer(),
  file_size_kb = numeric()
)

for (dataset_path in sdtm_files) {
  # Extract domain name
  file_name <- tools::file_path_sans_ext(basename(dataset_path))
  domain <- toupper(file_name)
  
  cli_alert_info("Processing: {domain}")
  
  # Read dataset (support both SAS and RDS)
  if (grepl("\\.sas7bdat$", dataset_path)) {
    df <- read_sas(dataset_path)
  } else {
    df <- readRDS(dataset_path)
  }
  
  # Create XPT
  xpt_path <- file.path(xpt_output_dir, paste0(tolower(domain), ".xpt"))
  
  tryCatch({
    xportr_write(
      df,
      path = xpt_path,
      domain = domain,
      label = paste(domain, "Domain"),
      strict_checks = FALSE
    )
    
    # Track for manifest
    file_info_xpt <- file.info(xpt_path)
    xpt_manifest <- xpt_manifest %>%
      add_row(
        dataset = domain,
        xpt_path = xpt_path,
        num_records = nrow(df),
        num_vars = ncol(df),
        file_size_kb = round(file_info_xpt$size / 1024, 1)
      )
    
    cli_alert_success("✓ {domain} ({nrow(df)} obs, {ncol(df)} vars)")
    
  }, error = function(e) {
    cli_alert_danger("✗ {domain} failed: {conditionMessage(e)}")
  })
}

cli_alert_success("Total XPT files created: {nrow(xpt_manifest)}")
cli_alert_info("Total size: {round(sum(xpt_manifest$file_size_kb) / 1024, 1)} MB")

# Save manifest
write.csv(
  xpt_manifest,
  file.path(metadata_dir, "xpt_manifest.csv"),
  row.names = FALSE
)

cat("\n")

################################################################################
# Step 2: Generate Pinnacle 21 Specification
################################################################################

cli_h2("Step 2: Pinnacle 21 Community Spec Generation")

cat("\n")
cli_alert_warning("MANUAL STEP REQUIRED: Pinnacle 21 Community")
cat("\n")
cli_ol(c(
  "Open Pinnacle 21 Community application",
  "Select: Define.xml → Create Spec",
  paste0("Browse to XPT directory: ", xpt_output_dir),
  "Select ALL xpt files (Ctrl+A)",
  paste0("Configuration: Standard = SDTMIG ", config$standards$sdtm$version),
  "Version: 2.1 (for Define-XML 2.1)",
  "Click 'Create' button",
  paste0("Save Excel spec to: ", pinnacle_spec),
  "Return here and press ENTER to continue..."
))
cat("\n")

# Wait for user confirmation
if (interactive()) {
  invisible(readline(prompt = "Press ENTER when Pinnacle 21 spec is created: "))
}

################################################################################
# Step 3: Parse Pinnacle 21 Excel Specification
################################################################################

cli_h2("Step 3: Parsing Pinnacle 21 Specification")

# Check if spec exists
if (!file.exists(pinnacle_spec)) {
  cli_alert_warning("Pinnacle 21 spec not found: {pinnacle_spec}")
  cli_alert_info("Creating placeholder template for demonstration...")
  
  # Create minimal placeholder
  placeholder_data <- list(
    Datasets = tibble(
      Dataset = character(),
      Label = character(),
      Class = character(),
      Structure = character(),
      Purpose = character(),
      Keys = character()
    ),
    Variables = tibble(
      Dataset = character(),
      Variable = character(),
      Label = character(),
      `Data Type` = character(),
      Length = integer(),
      `Display Format` = character(),
      Origin = character(),
      Role = character(),
      Core = character()
    )
  )
  
  writexl::write_xlsx(placeholder_data, pinnacle_spec)
  cli_alert_success("Template created")
  
  cli_alert_warning("Please populate Pinnacle 21 spec and rerun script")
  quit(save = "no", status = 0)
}

# Parse Excel sheets
cli_alert_info("Reading Excel specification...")

# Dataset-level metadata
datasets_meta <- read_excel(pinnacle_spec, sheet = "Datasets") %>%
  janitor::clean_names() %>%
  mutate(
    repeating = case_when(
      dataset == "DM" ~ "No",
      grepl("one.*subject", tolower(structure)) ~ "No",
      TRUE ~ "Yes"
    )
  )

cli_alert_success("Datasets: {nrow(datasets_meta)}")

# Variable-level metadata
variables_meta <- read_excel(pinnacle_spec, sheet = "Variables") %>%
  janitor::clean_names() %>%
  mutate(
    data_type = case_when(
      grepl("char|text", tolower(data_type)) ~ "text",
      grepl("num|int|float", tolower(data_type)) ~ "float",
      grepl("date", tolower(data_type)) ~ "datetime",
      TRUE ~ tolower(data_type)
    )
  )

cli_alert_success("Variables: {nrow(variables_meta)}")

# Save parsed metadata
pinnacle_metadata <- list(
  datasets = datasets_meta,
  variables = variables_meta,
  value_level = tibble(),
  codelists = tibble(),
  generation_time = Sys.time(),
  config = config
)

saveRDS(
  pinnacle_metadata,
  file.path(metadata_dir, "pinnacle21_parsed.rds")
)

cli_alert_success("Parsed metadata saved")

cat("\n")
cli_rule("PHASE 1 COMPLETE")
cli_alert_success("Next: Phase 2 - Metadata Enrichment from SDTM Specs")
cat("\n")
