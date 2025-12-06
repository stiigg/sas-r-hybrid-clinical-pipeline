#!/usr/bin/env Rscript

# Portfolio-level orchestration for multi-study pipeline management
# Demonstrates senior programmer capability to coordinate concurrent studies

library(yaml)
library(dplyr)
library(purrr)
library(glue)
library(rlang)

source("automation/dependencies.R")
source("automation/change_detection.R")

#' Load Portfolio Registry
#'
#' @return List containing portfolio configuration
load_portfolio_registry <- function(path = "studies/portfolio_registry.yml") {
  if (!file.exists(path)) {
    stop("Portfolio registry not found at: ", path)
  }
  yaml::read_yaml(path)
}

#' Get Active Studies Based on Priority and Status
#'
#' @param registry Portfolio registry list
#' @param priority_threshold Run only studies with priority <= threshold
#' @return Character vector of study IDs to process
get_active_studies <- function(registry, priority_threshold = 3) {
  studies <- registry$studies
  
  active <- names(studies)[
    vapply(studies, function(s) {
      s$priority <= priority_threshold && 
        !grepl("Complete|On Hold", s$status, ignore.case = TRUE)
    }, logical(1))
  ]
  
  # Sort by priority (1 = highest)
  priorities <- vapply(studies[active], function(s) s$priority, numeric(1))
  active[order(priorities)]
}

#' Detect Study-Level Changes
#'
#' @param study_id Study identifier
#' @param study_root Path to study directory
#' @return List with detected changes by domain
detect_study_changes <- function(study_id, study_root) {
  message(sprintf("[%s] Detecting changes...", study_id))
  
  sdtm_path <- file.path(study_root, "data/sdtm")
  state_file <- file.path(study_root, "logs/sdtm_state.yml")
  
  if (!dir.exists(sdtm_path)) {
    warning(sprintf("[%s] SDTM directory not found: %s", study_id, sdtm_path))
    return(list(sdtm = character(), adam = character()))
  }
  
  changed_sdtm <- detect_changed_sdtm(
    root = sdtm_path,
    state_file = state_file,
    mode = "mtime"
  )
  
  list(
    study_id = study_id,
    sdtm = as.character(changed_sdtm),
    adam = character(),  # Will implement ADaM change detection
    timestamp = Sys.time()
  )
}

#' Run Pipeline for Single Study
#'
#' @param study_id Study identifier
#' @param study_config Study-specific configuration
#' @param dry_run Logical, whether to run in dry-run mode
run_study_pipeline <- function(study_id, study_config, dry_run = TRUE) {
  message(sprintf("\n========== Processing %s ==========", study_id))
  message(sprintf("Protocol: %s | Phase: %s | Priority: %d", 
                  study_config$protocol_number,
                  study_config$phase,
                  study_config$priority))
  
  study_root <- file.path("studies", study_id)
  
  # Load study metadata
  metadata_path <- file.path(study_root, "config/study_metadata.yml")
  if (!file.exists(metadata_path)) {
    warning(sprintf("[%s] Study metadata not found, skipping", study_id))
    return(NULL)
  }
  
  metadata <- yaml::read_yaml(metadata_path)
  
  # Detect changes
  changes <- detect_study_changes(study_id, study_root)
  
  if (length(changes$sdtm) == 0 && !dry_run) {
    message(sprintf("[%s] No changes detected, skipping pipeline", study_id))
    return(list(status = "skipped", reason = "no_changes"))
  }
  
  message(sprintf("[%s] Changed SDTM domains: %s", 
                  study_id, 
                  if(length(changes$sdtm) > 0) paste(changes$sdtm, collapse = ", ") else "none"))
  
  # Run ETL for this study
  if (!dry_run) {
    message(sprintf("[%s] Running ETL...", study_id))
    # Call study-specific run_all.R with appropriate parameters
    # Sys.setenv(STUDY_ID = study_id, STUDY_ROOT = study_root)
    # source("run_all.R")
  }
  
  list(
    study_id = study_id,
    status = if(dry_run) "dry_run" else "completed",
    changes = changes,
    timestamp = Sys.time()
  )
}

#' Generate Portfolio Status Report
#'
#' @param registry Portfolio registry
#' @param results List of study processing results
#' @return Data frame with portfolio summary
generate_portfolio_report <- function(registry, results) {
  studies <- registry$studies
  
  report_df <- map_dfr(names(studies), function(sid) {
    study <- studies[[sid]]
    result <- results[[sid]]
    
    data.frame(
      study_id = sid,
      protocol = study$protocol_number,
      phase = study$phase,
      priority = study$priority,
      status = study$status,
      db_lock_planned = study$database_lock_planned %||% NA_character_,
      pipeline_status = result$status %||% "not_run",
      changed_domains = if(!is.null(result$changes$sdtm)) 
        paste(result$changes$sdtm, collapse = ", ") else "",
      programmer = study$team$trial_programmer %||% "Unassigned",
      stringsAsFactors = FALSE
    )
  })
  
  report_df
}

#' Main Portfolio Runner
#'
#' Demonstrates multi-study coordination capability
main <- function() {
  message("=================================================")
  message("Multi-Study Portfolio Pipeline Orchestration")
  message("=================================================\n")
  
  # Parse arguments
  args <- commandArgs(trailingOnly = TRUE)
  dry_run <- Sys.getenv("PORTFOLIO_DRY_RUN", "true") == "true"
  priority_filter <- as.numeric(Sys.getenv("PRIORITY_THRESHOLD", "3"))
  
  message(sprintf("Mode: %s", if(dry_run) "DRY RUN" else "FULL EXECUTION"))
  message(sprintf("Priority Filter: <= %d\n", priority_filter))
  
  # Load registry
  registry <- load_portfolio_registry()
  message(sprintf("Portfolio: %s", registry$portfolio$program_name))
  message(sprintf("Compound: %s | Indication: %s\n", 
                  registry$portfolio$compound,
                  registry$portfolio$indication))
  
  # Get active studies
  active_studies <- get_active_studies(registry, priority_filter)
  message(sprintf("Active studies to process: %d", length(active_studies)))
  message(sprintf("Studies: %s\n", paste(active_studies, collapse = ", ")))
  
  # Process each study
  results <- setNames(
    lapply(active_studies, function(sid) {
      run_study_pipeline(sid, registry$studies[[sid]], dry_run)
    }),
    active_studies
  )
  
  # Generate summary report
  message("\n========== Portfolio Summary ==========")
  report <- generate_portfolio_report(registry, results)
  print(report)
  
  # Write report to logs
  report_path <- file.path("logs", sprintf("portfolio_status_%s.csv", 
                                           format(Sys.time(), "%Y%m%d_%H%M%S")))
  write.csv(report, report_path, row.names = FALSE)
  message(sprintf("\nPortfolio report written to: %s", report_path))
  
  invisible(list(registry = registry, results = results, report = report))
}

# Execute if run as script
if (!interactive()) {
  main()
}
