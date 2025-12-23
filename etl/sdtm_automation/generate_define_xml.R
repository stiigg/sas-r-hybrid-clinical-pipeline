#!/usr/bin/env Rscript
#=============================================================================
# DEFINE-XML 2.1 GENERATOR FOR SDTM DOMAINS
# Creates FDA-required Define-XML metadata document
# Required for all FDA submissions since March 15, 2023
#=============================================================================

library(xportr)
library(dplyr)
library(readr)
library(here)
library(logger)
library(purrr)
library(xml2)

log_info("Generating Define-XML 2.1 for SDTM domains")

# Study-level metadata
study_metadata <- list(
  studyid = "RECIST-DEMO",
  study_name = "RECIST Response Assessment Demonstration Study",
  protocol_name = "RECIST-DEMO-001",
  sponsor = "Demo Pharmaceutical Inc.",
  define_version = "2.1",
  standard = "SDTM",
  standard_version = "3.4",
  ig_version = "3.4",
  creation_date = Sys.Date()
)

# Domain metadata - describes each SDTM domain
domain_metadata <- tribble(
  ~domain, ~label, ~description, ~class, ~purpose,
  "DM", "Demographics", "Subject-level demographic and study participation information", "SPECIAL PURPOSE", "Tabulation",
  "TU", "Tumor Identification", "Baseline tumor inventory for target and non-target lesions", "FINDINGS", "Tabulation",
  "TR", "Tumor Results", "Longitudinal tumor measurements per RECIST criteria", "FINDINGS", "Tabulation",
  "RS", "Disease Response", "Overall response assessment per RECIST 1.1", "FINDINGS", "Tabulation",
  "AE", "Adverse Events", "Adverse events and safety observations", "EVENTS", "Tabulation",
  "EX", "Exposure", "Study treatment exposure and dosing records", "INTERVENTIONS", "Tabulation",
  "SV", "Subject Visits", "Subject visit attendance and completion status", "EVENTS", "Tabulation",
  "DS", "Disposition", "Subject disposition and study completion status", "EVENTS", "Tabulation",
  "CM", "Concomitant Medications", "Non-study medications taken during trial", "INTERVENTIONS", "Tabulation",
  "MH", "Medical History", "Pre-existing medical conditions before study enrollment", "EVENTS", "Tabulation",
  "LB", "Laboratory Tests", "Laboratory test results including hematology and chemistry", "FINDINGS", "Tabulation",
  "VS", "Vital Signs", "Vital signs measurements including blood pressure and pulse", "FINDINGS", "Tabulation",
  "EG", "ECG Tests", "Electrocardiogram measurements for cardiac safety", "FINDINGS", "Tabulation",
  "PE", "Physical Examination", "Physical examination findings by body system", "FINDINGS", "Tabulation",
  "QS", "Questionnaires", "Patient-reported outcomes and quality of life assessments", "FINDINGS", "Tabulation"
)

# Variable-level metadata template for common SDTM variables
common_variables <- tribble(
  ~variable, ~label, ~type, ~length, ~role, ~cdisc_notes,
  "STUDYID", "Study Identifier", "text", 200, "Identifier", "Unique identifier for the study",
  "DOMAIN", "Domain Abbreviation", "text", 2, "Identifier", "Two-character domain code",
  "USUBJID", "Unique Subject Identifier", "text", 200, "Identifier", "Unique subject identifier across all studies",
  "SUBJID", "Subject Identifier for the Study", "text", 200, "Topic", "Subject identifier within the study",
  "VISITNUM", "Visit Number", "integer", 8, "Timing", "Numeric visit identifier",
  "VISIT", "Visit Name", "text", 200, "Synonym Qualifier", "Protocol-defined visit name",
  "VISITDY", "Planned Study Day of Visit", "integer", 8, "Timing", "Planned study day of visit relative to RFSTDTC"
)

# Function to create variable metadata for a specific domain
create_domain_variables <- function(domain_code) {
  # This is a simplified version - in production, read from actual XPT files
  # or metadata specifications
  
  base_vars <- common_variables %>%
    mutate(domain = domain_code)
  
  # Add domain-specific variables based on domain type
  domain_specific <- switch(domain_code,
    "DM" = tribble(
      ~variable, ~label, ~type, ~length, ~role, ~cdisc_notes,
      "ARM", "Description of Planned Arm", "text", 200, "Synonym Qualifier", "Planned treatment arm",
      "ARMCD", "Planned Arm Code", "text", 20, "Topic", "Short code for planned arm",
      "ACTARM", "Description of Actual Arm", "text", 200, "Synonym Qualifier", "Actual treatment arm",
      "ACTARMCD", "Actual Arm Code", "text", 20, "Topic", "Short code for actual arm",
      "AGE", "Age", "integer", 8, "Record Qualifier", "Age at study entry",
      "AGEU", "Age Units", "text", 10, "Variable Qualifier", "Units for age (YEARS)",
      "SEX", "Sex", "text", 1, "Record Qualifier", "Sex of subject (M/F)",
      "RACE", "Race", "text", 200, "Record Qualifier", "Race of subject",
      "ETHNIC", "Ethnicity", "text", 200, "Record Qualifier", "Ethnicity",
      "RFSTDTC", "Subject Reference Start Date/Time", "datetime", 20, "Record Qualifier", "Reference start date for subject",
      "RFENDTC", "Subject Reference End Date/Time", "datetime", 20, "Record Qualifier", "Reference end date for subject",
      "DTHDTC", "Date/Time of Death", "datetime", 20, "Record Qualifier", "Date/time of death if applicable",
      "DTHFL", "Subject Death Flag", "text", 1, "Record Qualifier", "Y if subject died"
    ),
    "AE" = tribble(
      ~variable, ~label, ~type, ~length, ~role, ~cdisc_notes,
      "AESEQ", "Sequence Number", "integer", 8, "Identifier", "Sequence number for AE",
      "AETERM", "Reported Term for the Adverse Event", "text", 200, "Topic", "Verbatim AE term",
      "AEDECOD", "Dictionary-Derived Term", "text", 200, "Synonym Qualifier", "MedDRA preferred term",
      "AESOC", "Primary System Organ Class", "text", 200, "Grouping Qualifier", "MedDRA SOC",
      "AESEV", "Severity/Intensity", "text", 20, "Record Qualifier", "Severity (MILD/MODERATE/SEVERE)",
      "AESER", "Serious Event", "text", 1, "Record Qualifier", "Y if serious AE",
      "AEREL", "Causality", "text", 50, "Record Qualifier", "Relationship to study drug",
      "AEACN", "Action Taken with Study Treatment", "text", 50, "Record Qualifier", "Action taken",
      "AEOUT", "Outcome of Adverse Event", "text", 50, "Record Qualifier", "AE outcome",
      "AESTDTC", "Start Date/Time of Adverse Event", "datetime", 20, "Timing", "AE start date",
      "AEENDTC", "End Date/Time of Adverse Event", "datetime", 20, "Timing", "AE end date"
    ),
    "LB" = tribble(
      ~variable, ~label, ~type, ~length, ~role, ~cdisc_notes,
      "LBSEQ", "Sequence Number", "integer", 8, "Identifier", "Sequence number",
      "LBTESTCD", "Lab Test or Examination Short Name", "text", 8, "Topic", "Lab test code",
      "LBTEST", "Lab Test or Examination Name", "text", 200, "Synonym Qualifier", "Lab test name",
      "LBCAT", "Category for Lab Test", "text", 200, "Grouping Qualifier", "HEMATOLOGY/CHEMISTRY",
      "LBSPEC", "Specimen Type", "text", 200, "Record Qualifier", "Specimen type",
      "LBORRES", "Result or Finding in Original Units", "text", 200, "Result Qualifier", "Original result",
      "LBORRESU", "Original Units", "text", 40, "Variable Qualifier", "Original units",
      "LBSTRESC", "Character Result/Finding in Std Format", "text", 200, "Result Qualifier", "Standardized result",
      "LBSTRESN", "Numeric Result/Finding in Standard Units", "float", 8, "Result Qualifier", "Numeric result",
      "LBSTRESU", "Standard Units", "text", 40, "Variable Qualifier", "Standard units",
      "LBSTNRLO", "Reference Range Lower Limit in Std Units", "float", 8, "Variable Qualifier", "Normal range low",
      "LBSTNRHI", "Reference Range Upper Limit in Std Units", "float", 8, "Variable Qualifier", "Normal range high",
      "LBNRIND", "Reference Range Indicator", "text", 20, "Variable Qualifier", "NORMAL/HIGH/LOW",
      "LBBLFL", "Baseline Flag", "text", 1, "Record Qualifier", "Y if baseline",
      "LBDTC", "Date/Time of Specimen Collection", "datetime", 20, "Timing", "Collection date"
    ),
    # Default for other domains
    tribble(
      ~variable, ~label, ~type, ~length, ~role, ~cdisc_notes,
      paste0(domain_code, "SEQ"), "Sequence Number", "integer", 8, "Identifier", "Sequence number"
    )
  )
  
  bind_rows(base_vars, domain_specific %>% mutate(domain = domain_code))
}

# Generate Define-XML 2.1 structure
generate_define_xml <- function() {
  log_info("Creating Define-XML 2.1 structure")
  
  # Create XML root
  define <- xml_new_root(
    "ODM",
    xmlns = "http://www.cdisc.org/ns/odm/v1.3",
    "xmlns:def" = "http://www.cdisc.org/ns/def/v2.1",
    "xmlns:xlink" = "http://www.w3.org/1999/xlink",
    ODMVersion = "1.3.2",
    FileOID = paste0("Define.", study_metadata$studyid, ".", format(Sys.Date(), "%Y%m%d")),
    FileType = "Snapshot",
    CreationDateTime = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    Originator = study_metadata$sponsor
  )
  
  # Add Study section
  study_node <- xml_add_child(define, "Study", OID = study_metadata$studyid)
  
  # Global Variables
  global_vars <- xml_add_child(study_node, "GlobalVariables")
  xml_add_child(global_vars, "StudyName", study_metadata$study_name)
  xml_add_child(global_vars, "StudyDescription", "RECIST Response Assessment Oncology Trial")
  xml_add_child(global_vars, "ProtocolName", study_metadata$protocol_name)
  
  # MetaDataVersion
  metadata_version <- xml_add_child(
    study_node, 
    "MetaDataVersion",
    OID = paste0(study_metadata$studyid, ".SDTM"),
    Name = "SDTM Metadata",
    Description = "SDTM 3.4 Implementation",
    "def:DefineVersion" = "2.1",
    "def:StandardName" = "SDTM-IG",
    "def:StandardVersion" = study_metadata$ig_version
  )
  
  # Add ItemGroupDef for each domain
  log_info("Adding domain definitions")
  
  for (i in seq_len(nrow(domain_metadata))) {
    domain <- domain_metadata[i, ]
    
    item_group <- xml_add_child(
      metadata_version,
      "ItemGroupDef",
      OID = paste0("IG.", domain$domain),
      Name = domain$domain,
      Repeating = "Yes",
      "def:Class" = domain$class,
      "def:Purpose" = domain$purpose,
      "def:Structure" = "One record per subject per event"
    )
    
    xml_add_child(item_group, "Description")
    xml_add_child(xml_children(item_group)[[1]], "TranslatedText", 
                  "xml:lang" = "en", domain$description)
    
    # Add variables for this domain
    domain_vars <- create_domain_variables(domain$domain)
    
    for (j in seq_len(nrow(domain_vars))) {
      var <- domain_vars[j, ]
      xml_add_child(
        item_group,
        "ItemRef",
        ItemOID = paste0("IT.", domain$domain, ".", var$variable),
        OrderNumber = as.character(j),
        Mandatory = if(var$role == "Identifier") "Yes" else "No"
      )
    }
  }
  
  log_info("Define-XML structure created successfully")
  return(define)
}

# Create output directory
dir.create(here("outputs", "define"), recursive = TRUE, showWarnings = FALSE)

# Generate Define-XML
define_xml <- generate_define_xml()

# Write to file
output_path <- here("outputs", "define", "define.xml")
write_xml(define_xml, output_path, options = c("format", "no_declaration"))

log_info("✓ Define-XML 2.1 written: {output_path}")

# Also create a summary report
summary_report <- domain_metadata %>%
  mutate(
    variables_count = map_int(domain, ~nrow(create_domain_variables(.x))),
    status = "Complete"
  )

summary_path <- here("outputs", "define", "define_summary.csv")
write_csv(summary_report, summary_path)

log_info("✓ Define summary written: {summary_path}")

message("\n========================================")
message("Define-XML 2.1 Generation Complete")
message("========================================")
message(sprintf("Domains documented: %d", nrow(domain_metadata)))
message(sprintf("Standard: SDTM-IG v%s", study_metadata$ig_version))
message(sprintf("Define-XML version: %s", study_metadata$define_version))
message(sprintf("Output: %s", output_path))
message("========================================\n")

message("NOTE: This is a template Define-XML generator.")
message("For production use, enhance with:")
message("  - Full variable-level metadata from actual XPT files")
message("  - Controlled terminology references")
message("  - Value-level metadata and codelists")
message("  - Where clauses and comments")
message("  - Origin metadata (CRF pages, derivations)")
