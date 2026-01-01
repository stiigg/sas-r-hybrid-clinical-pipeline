################################################################################
# Program: 02_enrich_from_specs.R
# Purpose: Enrich Pinnacle 21 metadata with derivation logic from SDTM specs
# Author: Clinical Programming Team
# Date: 2026-01-01
################################################################################

library(dplyr)
library(readr)
library(purrr)
library(tidyr)
library(cli)
library(yaml)

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("  PHASE 2: Metadata Enrichment from SDTM Specifications       \n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Load configuration
config <- read_yaml("regulatory_submission/define_xml/config/study_config.yml")

metadata_dir <- config$paths$metadata
specs_dir <- config$paths$sdtm_specs

################################################################################
# Step 1: Load Pinnacle 21 Baseline Metadata
################################################################################

cli_h2("Step 1: Loading Pinnacle 21 Metadata")

p21_file <- file.path(metadata_dir, "pinnacle21_parsed.rds")

if (!file.exists(p21_file)) {
  cli_alert_danger("Pinnacle 21 metadata not found: {p21_file}")
  stop("Please complete Phase 1 first")
}

pinnacle_metadata <- readRDS(p21_file)

datasets_p21 <- pinnacle_metadata$datasets
variables_p21 <- pinnacle_metadata$variables

cli_alert_success("Datasets: {nrow(datasets_p21)}")
cli_alert_success("Variables: {nrow(variables_p21)}")

cat("\n")

################################################################################
# Step 2: Load and Consolidate SDTM Specifications
################################################################################

cli_h2("Step 2: Loading SDTM Transformation Specifications")

# Find all spec files
spec_files <- list.files(
  specs_dir,
  pattern = "sdtm_.*_spec_v2\\.csv$",
  full.names = TRUE
)

if (length(spec_files) == 0) {
  cli_alert_warning("No SDTM spec files found in {specs_dir}")
  cli_alert_info("Skipping enrichment...")
  
  # Save minimal enriched metadata
  enriched_metadata <- list(
    datasets = datasets_p21,
    variables = variables_p21,
    codelists = tibble(),
    value_level = tibble(),
    generation_metadata = list(
      enrichment_time = Sys.time(),
      pinnacle_baseline = nrow(variables_p21),
      spec_rules_applied = 0
    )
  )
  
  saveRDS(
    enriched_metadata,
    file.path(metadata_dir, "enriched_metadata_complete.rds")
  )
  
  cli_alert_warning("Minimal metadata saved")
  quit(save = "no", status = 0)
}

cli_alert_info("Found {length(spec_files)} specification file(s)")

# Load and combine all specs
all_specs <- spec_files %>%
  map_dfr(function(spec_file) {
    domain <- toupper(
      gsub("sdtm_(.+)_spec_v2\\.csv", "\\1", basename(spec_file))
    )
    
    cli_li("Loading: {domain}")
    
    spec <- read_csv(
      spec_file,
      col_types = cols(.default = "c"),
      show_col_types = FALSE
    ) %>%
      mutate(domain = domain)
    
    return(spec)
  })

cli_alert_success("Total transformation rules: {nrow(all_specs)}")
cli_alert_success("Domains covered: {length(unique(all_specs$domain))}")

cat("\n")

################################################################################
# Step 3: Map Transformation Logic to Variables
################################################################################

cli_h2("Step 3: Enriching Variable Metadata")

# Prepare specs for joining
specs_for_join <- all_specs %>%
  select(
    domain = target_domain,
    variable = target_var,
    seq,
    source_dataset,
    source_var,
    transformation_type,
    transformation_logic,
    ct_codelist,
    quality_check,
    spec_comments = comments
  ) %>%
  group_by(domain, variable) %>%
  arrange(seq) %>%
  slice(1) %>%
  ungroup()

# Join with Pinnacle 21 metadata
enriched_variables <- variables_p21 %>%
  left_join(
    specs_for_join,
    by = c("dataset" = "domain", "variable" = "variable")
  ) %>%
  mutate(
    origin_enhanced = case_when(
      transformation_type == "CONSTANT" ~ "Assigned",
      transformation_type == "DIRECT_MAP" ~ "Collected",
      transformation_type %in% c("CONCAT", "DATE_CONSTRUCT", "DATE_CONVERT",
                                  "RECODE", "CONDITIONAL", "FORMAT",
                                  "MULTI_CHECKBOX") ~ "Derived",
      transformation_type == "CROSS_DOMAIN" ~ "Derived",
      !is.na(origin) ~ origin,
      TRUE ~ "Collected"
    ),
    
    method_description = case_when(
      !is.na(transformation_logic) & transformation_type != "DIRECT_MAP" ~ 
        paste0(
          transformation_type, ": ",
          substr(transformation_logic, 1, 500)
        ),
      transformation_type == "DIRECT_MAP" ~
        paste0("Collected as ", source_var, " from ", source_dataset),
      TRUE ~ NA_character_
    ),
    
    codelist_final = coalesce(ct_codelist, codelist),
    qc_rules = quality_check
  )

derivations_count <- sum(!is.na(enriched_variables$method_description))
codelists_count <- sum(!is.na(enriched_variables$codelist_final))

cli_alert_success("Variables enriched: {nrow(enriched_variables)}")
cli_li("With derivations: {derivations_count}")
cli_li("With codelists: {codelists_count}")

cat("\n")

################################################################################
# Step 4: Extract Codelists
################################################################################

cli_h2("Step 4: Extracting Controlled Terminology Codelists")

unique_codelists <- enriched_variables %>%
  filter(!is.na(codelist_final)) %>%
  distinct(codelist_final) %>%
  mutate(
    codelist_id = paste0("CL.", toupper(gsub("[^A-Z0-9]", "_", codelist_final))),
    codelist_name = codelist_final,
    ct_package = "SDTM",
    ct_version = config$standards$sdtm$ct_version
  )

cli_alert_success("Unique codelists identified: {nrow(unique_codelists)}")

cat("\n")

################################################################################
# Step 5: Save Enriched Metadata Package
################################################################################

cli_h2("Step 5: Saving Enriched Metadata Package")

enriched_metadata <- list(
  datasets = datasets_p21,
  variables = enriched_variables,
  codelists = unique_codelists,
  value_level = tibble(),
  generation_metadata = list(
    enrichment_time = Sys.time(),
    pinnacle_baseline = nrow(variables_p21),
    spec_rules_applied = nrow(all_specs),
    derivations_added = derivations_count,
    codelists_identified = nrow(unique_codelists)
  )
)

saveRDS(
  enriched_metadata,
  file.path(metadata_dir, "enriched_metadata_complete.rds")
)

write_csv(
  enriched_variables,
  file.path(metadata_dir, "define_variables_enriched.csv")
)

write_csv(
  unique_codelists,
  file.path(metadata_dir, "define_codelists.csv")
)

cli_alert_success("Enriched metadata package saved")
cli_alert_success("CSV exports created for review")

cat("\n")
cli_rule("PHASE 2 COMPLETE")
cli_alert_success("Next: Phase 3 - Define-XML 2.1 Generation")
cat("\n")
