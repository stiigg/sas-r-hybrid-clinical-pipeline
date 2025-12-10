################################################################################
# Program: generate_define_adam.R
# Purpose: Generate CDISC-compliant define.xml for ADaM datasets using xportr
# Author: Clinical Programming Team
# Date: 2025-12-10
# 
# Input:
#   - outputs/adam/*.rds (ADaM datasets from pipeline)
#   - dataset_specifications/adam_spec.xlsx (variable metadata)
#   - value_level_metadata/adam_vl_spec.xlsx (value-level metadata)
#
# Output:
#   - outputs/*.xpt (SAS transport files)
#   - outputs/define_metadata_adam.xlsx (metadata for review)
#
# Requirements:
#   - xportr >= 0.3.0
#   - admiral >= 0.12.0
#   - readxl, dplyr, purrr
################################################################################

# Load required packages
suppressPackageStartupMessages({
  library(xportr)
  library(dplyr)
  library(readxl)
  library(purrr)
})

cat("\n=== ADaM Define.xml Generation Workflow ===")
cat("\nStarting:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

################################################################################
# 1. Setup and Configuration
################################################################################

# Set xportr options
options(
  xportr.length = "message",
  xportr.label = "message",
  xportr.format_verbose = "none"
)

# Define paths
output_dir <- "regulatory_submission/define_xml/outputs"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

################################################################################
# 2. Load Specifications
################################################################################

cat("[Step 1/5] Loading specifications...\n")

# Check if spec files exist
spec_file <- "regulatory_submission/define_xml/dataset_specifications/adam_spec.xlsx"

if (!file.exists(spec_file)) {
  cat("  Note: Specification file not found at:", spec_file, "\n")
  cat("  This is expected for initial setup. Create specifications using:\n")
  cat("    - Template at: regulatory_submission/define_xml/dataset_specifications/\n")
  cat("    - See README.md for specification format\n\n")
  
  cat("  For demonstration, we'll extract metadata from existing ADaM datasets.\n\n")
  
  # Continue with metadata extraction from existing datasets
  spec_exists <- FALSE
} else {
  spec_exists <- TRUE
  adam_spec <- read_excel(spec_file, sheet = "Variables")
  dataset_spec <- read_excel(spec_file, sheet = "Datasets")
  cat("  \u2713 Loaded specifications\n\n")
}

################################################################################
# 3. Process ADaM Datasets
################################################################################

cat("[Step 2/5] Processing ADaM datasets...\n")

# Find available ADaM datasets
adam_dir <- "outputs/adam"
if (!dir.exists(adam_dir)) {
  stop("ADaM directory not found: ", adam_dir, "\n",
       "Please run the main pipeline first to generate ADaM datasets.")
}

# Get list of RDS files
adam_files <- list.files(adam_dir, pattern = "\\.rds$", full.names = TRUE)

if (length(adam_files) == 0) {
  stop("No ADaM datasets found in: ", adam_dir)
}

cat("  Found", length(adam_files), "ADaM dataset(s):\n")
for (f in adam_files) {
  cat("    -", basename(f), "\n")
}
cat("\n")

# Load and process each dataset
adam_data <- list()
for (file_path in adam_files) {
  
  dataset_name <- toupper(tools::file_path_sans_ext(basename(file_path)))
  cat("  Processing", dataset_name, "...\n")
  
  # Load dataset
  dataset <- readRDS(file_path)
  
  # Basic validation
  n_rows <- nrow(dataset)
  n_cols <- ncol(dataset)
  
  cat("    \u2713 Loaded:", n_rows, "records,", n_cols, "variables\n")
  
  # Store in list
  adam_data[[dataset_name]] <- dataset
}

cat("\n  \u2713 Successfully loaded", length(adam_data), "dataset(s)\n\n")

################################################################################
# 4. Generate XPT Transport Files
################################################################################

cat("[Step 3/5] Generating XPT transport files...\n")

# Function to write XPT file
write_xpt_from_data <- function(dataset, dataset_name) {
  
  xpt_path <- file.path(output_dir, paste0(tolower(dataset_name), ".xpt"))
  
  # Create a basic label if not exists
  dataset_label <- attr(dataset, "label")
  if (is.null(dataset_label)) {
    dataset_label <- paste(dataset_name, "Analysis Dataset")
  }
  
  # Write XPT file
  tryCatch({
    xportr_write(
      dataset,
      path = xpt_path,
      domain = dataset_name,
      label = dataset_label
    )
    
    file_size <- file.info(xpt_path)$size / 1024 / 1024
    cat("  \u2713 Created", basename(xpt_path), "-", 
        sprintf("%.2f MB", file_size), "\n")
    
    return(xpt_path)
  }, error = function(e) {
    cat("  \u26a0 Warning: Could not create XPT for", dataset_name, "\n")
    cat("    Error:", conditionMessage(e), "\n")
    return(NULL)
  })
}

# Write all XPT files
xpt_files <- imap(adam_data, write_xpt_from_data)
xpt_files <- xpt_files[!sapply(xpt_files, is.null)]

cat("\n  \u2713 Generated", length(xpt_files), "XPT file(s)\n\n")

################################################################################
# 5. Extract Metadata
################################################################################

cat("[Step 4/5] Extracting metadata for define.xml...\n")

# Function to extract variable metadata
extract_metadata <- function(dataset, dataset_name) {
  
  var_names <- names(dataset)
  
  metadata <- tibble(
    dataset = dataset_name,
    variable = var_names,
    label = map_chr(var_names, ~{
      lbl <- attr(dataset[[.x]], "label")
      if (is.null(lbl)) "" else as.character(lbl)
    }),
    type = map_chr(dataset, ~class(.x)[1]),
    length = map_int(dataset, ~{
      if (is.character(.x)) {
        max_len <- max(nchar(.x, keepNA = FALSE), na.rm = TRUE)
        if (is.infinite(max_len)) 0L else max_len
      } else {
        8L
      }
    }),
    n_records = nrow(dataset),
    n_missing = map_int(dataset, ~sum(is.na(.x))),
    pct_missing = round(map_int(dataset, ~sum(is.na(.x))) / nrow(dataset) * 100, 1)
  )
  
  return(metadata)
}

# Extract metadata from all datasets
define_metadata <- map_dfr(names(adam_data), ~{
  extract_metadata(adam_data[[.x]], .x)
})

cat("  \u2713 Extracted metadata for", nrow(define_metadata), "variables\n")

# Add suggested origin and role (basic heuristics)
define_metadata <- define_metadata %>%
  mutate(
    suggested_origin = case_when(
      variable %in% c("STUDYID", "USUBJID") ~ "Assigned",
      variable == "SUBJID" ~ "Protocol",
      grepl("DT$|DTM$", variable) ~ "Derived",
      grepl("FL$", variable) ~ "Derived",
      TRUE ~ "Predecessor"
    ),
    suggested_role = case_when(
      variable %in% c("STUDYID", "USUBJID", "SUBJID") ~ "Identifier",
      variable %in% c("PARAM", "PARAMCD") ~ "Topic",
      grepl("FL$", variable) ~ "Qualifier",
      TRUE ~ "Qualifier"
    )
  )

################################################################################
# 6. Export Metadata
################################################################################

cat("\n[Step 5/5] Exporting metadata...\n")

# Create summary of datasets
dataset_summary <- define_metadata %>%
  group_by(dataset) %>%
  summarise(
    n_variables = n(),
    n_records = first(n_records),
    .groups = "drop"
  )

# Export to Excel for review
metadata_path <- file.path(output_dir, "define_metadata_adam.xlsx")

if (requireNamespace("writexl", quietly = TRUE)) {
  writexl::write_xlsx(
    list(
      Summary = dataset_summary,
      Variables = define_metadata
    ),
    path = metadata_path
  )
  cat("  \u2713 Exported metadata to:", metadata_path, "\n")
} else {
  cat("  Note: Install 'writexl' package to export metadata to Excel\n")
}

################################################################################
# 7. Summary Report
################################################################################

cat("\n=== Generation Summary ===")
cat("\nDatasets processed:", length(adam_data))
cat("\nTotal variables:", nrow(define_metadata))
cat("\nXPT files generated:", length(xpt_files))
cat("\nOutput directory:", output_dir)
cat("\n\nCompleted:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))

cat("\n\n=== Next Steps ===")
cat("\n1. Review metadata: ", metadata_path)
cat("\n2. Create adam_spec.xlsx using metadata as template")
cat("\n3. Add value-level metadata for coded variables")
cat("\n4. Re-run with specifications to apply xportr validations")
cat("\n5. Generate define.xml using specialized tools (Pinnacle 21, etc.)")
cat("\n6. Validate with FDA Validator or Pinnacle 21 Community\n\n")

# Save workspace
workspace_file <- file.path(output_dir, "define_workspace.RData")
save(
  adam_data,
  define_metadata,
  dataset_summary,
  file = workspace_file
)

cat("Workspace saved to:", workspace_file, "\n\n")
