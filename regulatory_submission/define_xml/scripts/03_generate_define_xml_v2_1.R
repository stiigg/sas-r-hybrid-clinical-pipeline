################################################################################
# Program: 03_generate_define_xml_v2_1.R
# Purpose: Generate production-ready Define-XML v2.1 for SDTM submission
# Author: Clinical Programming Team
# Date: 2026-01-01
################################################################################

library(xml2)
library(dplyr)
library(glue)
library(purrr)
library(cli)
library(yaml)

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("  PHASE 3: Define-XML v2.1 Generation                          \n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Load configuration
config <- read_yaml("regulatory_submission/define_xml/config/study_config.yml")

metadata_dir <- config$paths$metadata
output_dir <- config$paths$output

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

################################################################################
# Step 1: Load Enriched Metadata
################################################################################

cli_h2("Step 1: Loading Enriched Metadata")

metadata_file <- file.path(metadata_dir, "enriched_metadata_complete.rds")

if (!file.exists(metadata_file)) {
  cli_alert_danger("Enriched metadata not found: {metadata_file}")
  stop("Please complete Phase 2 first")
}

metadata <- readRDS(metadata_file)

datasets_meta <- metadata$datasets
variables_meta <- metadata$variables
codelists_meta <- metadata$codelists

cli_alert_success("Datasets: {nrow(datasets_meta)}")
cli_alert_success("Variables: {nrow(variables_meta)}")
cli_alert_success("Codelists: {nrow(codelists_meta)}")

cat("\n")

################################################################################
# Step 2: Initialize Define-XML Document Structure
################################################################################

cli_h2("Step 2: Initializing Define-XML v2.1 Structure")

# Create ODM root element
odm <- xml_new_root(
  "ODM",
  xmlns = "http://www.cdisc.org/ns/odm/v1.3",
  `xmlns:def` = "http://www.cdisc.org/ns/def/v2.1",
  `xmlns:xlink` = "http://www.w3.org/1999/xlink",
  `xmlns:arm` = "http://www.cdisc.org/ns/arm/v1.0",
  FileType = "Snapshot",
  FileOID = glue("define.{config$study$id}.{Sys.Date()}"),
  CreationDateTime = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
  ODMVersion = "1.3.2",
  `def:DefineVersion` = config$define_xml$version,
  `def:Context` = config$define_xml$context
)

# Study element
study <- xml_add_child(odm, "Study", OID = config$study$id)

# Global variables
global_vars <- xml_add_child(study, "GlobalVariables")
xml_add_child(global_vars, "StudyName", config$study$name)
xml_add_child(global_vars, "StudyDescription", 
              glue("{config$standards$sdtm$name} v{config$standards$sdtm$version} conformant datasets"))
xml_add_child(global_vars, "ProtocolName", config$study$protocol)

# MetaDataVersion
mdv <- xml_add_child(
  study,
  "MetaDataVersion",
  OID = glue("MDV.{config$study$id}.1.0"),
  Name = glue("{config$standards$sdtm$name} Metadata v1.0"),
  `def:DefineVersion` = config$define_xml$version,
  `def:StandardName` = config$standards$sdtm$name,
  `def:StandardVersion` = config$standards$sdtm$version
)

cli_alert_success("ODM structure created")
cli_alert_info("Study: {config$study$id}")
cli_alert_info("Standard: {config$standards$sdtm$name} {config$standards$sdtm$version}")

cat("\n")

################################################################################
# Step 3: Add Dataset Definitions (ItemGroupDef)
################################################################################

cli_h2("Step 3: Adding Dataset Definitions (ItemGroupDef)")

for (i in 1:nrow(datasets_meta)) {
  ds <- datasets_meta[i, ]
  
  ig <- xml_add_child(
    mdv,
    "ItemGroupDef",
    OID = glue("IG.{ds$dataset}"),
    Name = ds$dataset,
    Repeating = ds$repeating,
    `def:Class` = toupper(ds$class),
    `def:Structure` = ds$structure,
    `def:Label` = ds$label
  )
  
  # Add variables for this dataset
  ds_vars <- variables_meta %>%
    filter(dataset == ds$dataset) %>%
    arrange(variable)
  
  for (j in 1:nrow(ds_vars)) {
    var <- ds_vars[j, ]
    
    mandatory <- ifelse(
      !is.na(var$core) && grepl("Req|Yes", var$core, ignore.case = TRUE),
      "Yes",
      "No"
    )
    
    xml_add_child(
      ig,
      "ItemRef",
      ItemOID = glue("IT.{ds$dataset}.{var$variable}"),
      Mandatory = mandatory,
      OrderNumber = as.character(j)
    )
  }
  
  # Add dataset description
  if (!is.na(ds$label)) {
    desc <- xml_add_child(ig, "Description")
    xml_add_child(desc, "TranslatedText", ds$label, `xml:lang` = "en")
  }
  
  cli_li("{ds$dataset}")
}

cli_alert_success("Added {nrow(datasets_meta)} dataset definitions")

cat("\n")

################################################################################
# Step 4: Add Variable Definitions (ItemDef)
################################################################################

cli_h2("Step 4: Adding Variable Definitions (ItemDef)")

method_counter <- 1

for (i in 1:nrow(variables_meta)) {
  var <- variables_meta[i, ]
  
  if (i %% 50 == 0) cli_alert_info("Progress: {i}/{nrow(variables_meta)}")
  
  item <- xml_add_child(
    mdv,
    "ItemDef",
    OID = glue("IT.{var$dataset}.{var$variable}"),
    Name = var$variable,
    DataType = tolower(var$data_type),
    Length = as.character(var$length)
  )
  
  xml_set_attr(item, "SASFieldName", var$variable)
  
  if (!is.na(var$label)) {
    desc <- xml_add_child(item, "Description")
    xml_add_child(desc, "TranslatedText", var$label, `xml:lang` = "en")
  }
  
  if (!is.na(var$origin_enhanced)) {
    origin_elem <- xml_add_child(
      item,
      "def:Origin",
      Type = var$origin_enhanced
    )
  }
  
  if (!is.na(var$method_description) && nchar(var$method_description) > 0) {
    method_oid <- glue("MT.{var$dataset}.{var$variable}.{method_counter}")
    xml_add_child(item, "def:MethodRef", MethodOID = method_oid)
    method_counter <- method_counter + 1
  }
  
  if (!is.na(var$codelist_final) && nchar(var$codelist_final) > 0) {
    codelist_oid <- codelists_meta %>%
      filter(codelist_name == var$codelist_final) %>%
      pull(codelist_id) %>%
      first()
    
    if (!is.na(codelist_oid)) {
      xml_add_child(item, "CodeListRef", CodeListOID = codelist_oid)
    }
  }
}

cli_alert_success("Added {nrow(variables_meta)} variable definitions")

cat("\n")

################################################################################
# Step 5: Add Methods (Derivation Algorithms)
################################################################################

cli_h2("Step 5: Adding Derivation Methods (MethodDef)")

vars_with_methods <- variables_meta %>%
  filter(!is.na(method_description))

method_counter <- 1

for (i in 1:nrow(vars_with_methods)) {
  var <- vars_with_methods[i, ]
  
  method_oid <- glue("MT.{var$dataset}.{var$variable}.{method_counter}")
  
  method_def <- xml_add_child(
    mdv,
    "def:MethodDef",
    OID = method_oid,
    Name = glue("Method for {var$variable}"),
    Type = "Computation"
  )
  
  method_desc <- xml_add_child(method_def, "Description")
  xml_add_child(
    method_desc,
    "TranslatedText",
    var$method_description,
    `xml:lang` = "en"
  )
  
  method_counter <- method_counter + 1
}

cli_alert_success("Added {nrow(vars_with_methods)} method definitions")

cat("\n")

################################################################################
# Step 6: Add Codelists
################################################################################

cli_h2("Step 6: Adding Controlled Terminology Codelists")

for (i in 1:nrow(codelists_meta)) {
  cl <- codelists_meta[i, ]
  
  codelist <- xml_add_child(
    mdv,
    "CodeList",
    OID = cl$codelist_id,
    Name = cl$codelist_name,
    DataType = "text"
  )
  
  desc <- xml_add_child(codelist, "Description")
  xml_add_child(
    desc,
    "TranslatedText",
    glue("Controlled terminology for {cl$codelist_name}. See CDISC CT package."),
    `xml:lang` = "en"
  )
  
  cli_li("{cl$codelist_name}")
}

cli_alert_success("Added {nrow(codelists_meta)} codelist definitions")

cat("\n")

################################################################################
# Step 7: Write Define-XML to File
################################################################################

cli_h2("Step 7: Writing Define-XML File")

define_path <- file.path(output_dir, "define_sdtm.xml")

write_xml(
  odm,
  define_path,
  options = c("format", "no_declaration")
)

# Add XML declaration
define_content <- readLines(define_path)
define_content <- c(
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<?xml-stylesheet type="text/xsl" href="define2-1-0.xsl"?>',
  define_content
)
writeLines(define_content, define_path)

file_size <- file.info(define_path)$size / 1024

cli_alert_success("Define-XML created: {basename(define_path)}")
cli_alert_info("File size: {round(file_size, 1)} KB")

cat("\n")

################################################################################
# Step 8: Generate Summary Report
################################################################################

cli_h2("Step 8: Generating Summary Report")

summary_path <- file.path(output_dir, "define_generation_summary.txt")

writeLines(
  c(
    "════════════════════════════════════════════════════════════════",
    "  Define-XML v2.1 Generation Summary                           ",
    "════════════════════════════════════════════════════════════════",
    "",
    paste("Generated:", Sys.time()),
    paste("Study:", config$study$id),
    paste("Standard:", config$standards$sdtm$name, config$standards$sdtm$version),
    paste("Define-XML Version:", config$define_xml$version),
    "",
    "── Content Statistics ──────────────────────────────────────────",
    paste("Datasets:", nrow(datasets_meta)),
    paste("Variables:", nrow(variables_meta)),
    paste("  - With derivations:", nrow(vars_with_methods)),
    paste("Codelists:", nrow(codelists_meta)),
    "",
    "── Output Files ────────────────────────────────────────────────",
    paste("Define-XML:", define_path),
    paste("File size:", sprintf("%.1f KB", file_size)),
    "",
    "── Next Steps ──────────────────────────────────────────────────",
    "1. Download define2-1-0.xsl stylesheet from CDISC",
    "2. Validate with Pinnacle 21 Community",
    "3. Review metadata CSVs in metadata/",
    "4. Package with XPT files for submission",
    "",
    "════════════════════════════════════════════════════════════════"
  ),
  summary_path
)

cli_alert_success("Summary report saved")

cat("\n")
cli_rule("PHASE 3 COMPLETE")
cli_alert_success("Define-XML v2.1 Generated Successfully!")
cat("\n")
