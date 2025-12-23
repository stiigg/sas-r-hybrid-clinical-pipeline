# config/paths.R
# Centralized Path Configuration for Clinical Pipeline
# Part of pharmaverse-aligned repository structure

library(here)
library(logger)

# ============================================================================
# Raw Data Paths
# ============================================================================
PATH_RAW_DATA <- here("data-raw", "sdtm_input")

# ============================================================================
# SDTM Paths
# ============================================================================
PATH_SDTM_PROGRAMS_OAK <- here("sdtm", "programs", "R", "oak")
PATH_SDTM_PROGRAMS_OAK_FOUNDATION <- here("sdtm", "programs", "R", "oak", "foundation")
PATH_SDTM_PROGRAMS_OAK_EVENTS <- here("sdtm", "programs", "R", "oak", "events")
PATH_SDTM_PROGRAMS_OAK_FINDINGS <- here("sdtm", "programs", "R", "oak", "findings")
PATH_SDTM_PROGRAMS_OAK_FINDINGS_ABOUT <- here("sdtm", "programs", "R", "oak", "findings_about")
PATH_SDTM_PROGRAMS_OAK_INTERVENTIONS <- here("sdtm", "programs", "R", "oak", "interventions")
PATH_SDTM_PROGRAMS_OAK_ONCOLOGY <- here("sdtm", "programs", "R", "oak", "oncology")

PATH_SDTM_DATA_XPT <- here("sdtm", "data", "xpt")
PATH_SDTM_DATA_CSV <- here("sdtm", "data", "csv")
PATH_SDTM_SPECS <- here("sdtm", "specifications")
PATH_SDTM_LOGS <- here("sdtm", "logs")
PATH_SDTM_VALIDATION <- here("sdtm", "validation")

# ============================================================================
# ADaM Paths
# ============================================================================
PATH_ADAM_PROGRAMS <- here("adam", "programs", "R", "admiral")
PATH_ADAM_PROGRAMS_ADSL <- here("adam", "programs", "R", "admiral", "adsl")
PATH_ADAM_PROGRAMS_BDS <- here("adam", "programs", "R", "admiral", "bds")
PATH_ADAM_PROGRAMS_OCCDS <- here("adam", "programs", "R", "admiral", "occds")
PATH_ADAM_PROGRAMS_ONCOLOGY <- here("adam", "programs", "R", "admiral", "oncology")

PATH_ADAM_DATA_XPT <- here("adam", "data", "xpt")
PATH_ADAM_DATA_CSV <- here("adam", "data", "csv")
PATH_ADAM_SPECS <- here("adam", "specifications")
PATH_ADAM_LOGS <- here("adam", "logs")
PATH_ADAM_VALIDATION <- here("adam", "validation")

# ============================================================================
# TLF Paths
# ============================================================================
PATH_TLF_PROGRAMS <- here("tlf", "programs", "R")
PATH_TLF_OUTPUTS <- here("tlf", "outputs")
PATH_TLF_SPECS <- here("tlf", "specifications")

# ============================================================================
# QC Paths
# ============================================================================
PATH_QC_PROGRAMS <- here("qc", "programs", "R")
PATH_QC_REPORTS <- here("qc", "reports")

# ============================================================================
# Regulatory Submission Paths
# ============================================================================
PATH_REGULATORY <- here("regulatory_submission")
PATH_ECTD_M5 <- here("regulatory_submission", "ectd", "m5")
PATH_ADRG <- here("regulatory_submission", "adrg")
PATH_SDRG <- here("regulatory_submission", "sdrg")

# ============================================================================
# Configuration Paths
# ============================================================================
PATH_CONFIG <- here("config")
PATH_CT <- here("config", "controlled_terminology")
PATH_METADATA <- here("inst", "metadata")

# ============================================================================
# Validation Function
# ============================================================================
validate_paths <- function() {
  log_info("Validating repository directory structure...")
  
  required_dirs <- c(
    # SDTM
    PATH_SDTM_PROGRAMS_OAK_FOUNDATION,
    PATH_SDTM_PROGRAMS_OAK_EVENTS,
    PATH_SDTM_PROGRAMS_OAK_FINDINGS,
    PATH_SDTM_PROGRAMS_OAK_FINDINGS_ABOUT,
    PATH_SDTM_PROGRAMS_OAK_INTERVENTIONS,
    PATH_SDTM_PROGRAMS_OAK_ONCOLOGY,
    PATH_SDTM_DATA_XPT,
    PATH_SDTM_DATA_CSV,
    PATH_SDTM_LOGS,
    
    # ADaM
    PATH_ADAM_PROGRAMS_ADSL,
    PATH_ADAM_PROGRAMS_BDS,
    PATH_ADAM_PROGRAMS_OCCDS,
    PATH_ADAM_PROGRAMS_ONCOLOGY,
    PATH_ADAM_DATA_XPT,
    PATH_ADAM_DATA_CSV,
    PATH_ADAM_LOGS,
    
    # TLF
    PATH_TLF_PROGRAMS,
    PATH_TLF_OUTPUTS,
    
    # QC
    PATH_QC_PROGRAMS,
    PATH_QC_REPORTS,
    
    # Config
    PATH_CONFIG,
    PATH_METADATA
  )
  
  missing_dirs <- required_dirs[!dir.exists(required_dirs)]
  
  if (length(missing_dirs) > 0) {
    log_warn("Missing {length(missing_dirs)} required directories")
    log_info("Creating missing directories...")
    
    for (dir in missing_dirs) {
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
      log_info("  Created: {dir}")
    }
  } else {
    log_success("✓ All required directories exist")
  }
  
  invisible(TRUE)
}

# ============================================================================
# Export Path Environment Variables (optional)
# ============================================================================
export_path_env <- function() {
  Sys.setenv(
    PATH_SDTM_DATA_XPT = PATH_SDTM_DATA_XPT,
    PATH_SDTM_DATA_CSV = PATH_SDTM_DATA_CSV,
    PATH_ADAM_DATA_XPT = PATH_ADAM_DATA_XPT,
    PATH_ADAM_DATA_CSV = PATH_ADAM_DATA_CSV
  )
  log_info("Path environment variables exported")
}

# ============================================================================
# Auto-run validation on source
# ============================================================================
if (interactive()) {
  validate_paths()
  log_info("Path configuration loaded successfully")
  log_info("Repository structure: Pharmaverse-aligned CDISC pipeline")
}
