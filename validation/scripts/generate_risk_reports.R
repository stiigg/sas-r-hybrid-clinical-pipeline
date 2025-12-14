# Comprehensive R Package Risk Assessment (2024-2025 Standards)
# Based on R Validation Hub + FDA submission lessons
# 
# Usage:
#   Rscript validation/scripts/generate_risk_reports.R
#
# Output:
#   - validation/evidence/package_risk_scores.csv
#   - validation/evidence/package_detailed_metrics.csv
#   - Console summary report

# Install required packages if not present
required_packages <- c("riskmetric", "dplyr", "tibble")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing ", pkg, "...")
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

library(riskmetric)
library(dplyr)
library(tibble)

# Create output directory if needed
if (!dir.exists("validation/evidence")) {
  dir.create("validation/evidence", recursive = TRUE)
}

# Define package universe
pharmaverse_pkgs <- c("admiral", "metacore", "metatools")
infrastructure_pkgs <- c("shiny", "renv", "diffdf", "haven", "readr")
tidyverse_pkgs <- c("dplyr", "tidyr", "purrr", "ggplot2", "stringr")

all_packages <- c(pharmaverse_pkgs, infrastructure_pkgs, tidyverse_pkgs)

cat("\n========== R Package Risk Assessment ==========\n")
cat("Assessment Date:", as.character(Sys.Date()), "\n")
cat("Total Packages:", length(all_packages), "\n")
cat("Framework: R Validation Hub riskmetric\n\n")

# Step 1: Create package references
cat("Step 1/5: Creating package references...\n")
pkg_refs <- lapply(all_packages, function(pkg) {
  tryCatch(
    pkg_ref(pkg),
    error = function(e) {
      warning("Could not create reference for ", pkg, ": ", e$message)
      NULL
    }
  )
})
pkg_refs <- pkg_refs[!sapply(pkg_refs, is.null)]

# Step 2: Assess against validation criteria
cat("Step 2/5: Assessing packages (this may take a few minutes)...\n")
assessments <- tryCatch(
  pkg_assess(pkg_refs),
  error = function(e) {
    warning("Assessment failed: ", e$message)
    return(NULL)
  }
)

if (is.null(assessments)) {
  stop("Risk assessment failed. Check package availability.")
}

# Step 3: Score individual metrics (0.0 = no risk, 1.0 = max risk)
cat("Step 3/5: Calculating risk scores...\n")
scores <- tryCatch(
  pkg_score(assessments),
  error = function(e) {
    warning("Scoring failed: ", e$message)
    return(NULL)
  }
)

if (is.null(scores)) {
  # Fallback: create simplified risk report
  cat("\nWARNING: Full risk scoring unavailable. Generating simplified report.\n\n")
  
  # Create basic validation report
  simple_report <- data.frame(
    package = all_packages,
    installed = sapply(all_packages, function(p) {
      requireNamespace(p, quietly = TRUE)
    }),
    version = sapply(all_packages, function(p) {
      if (requireNamespace(p, quietly = TRUE)) {
        as.character(packageVersion(p))
      } else {
        NA
      }
    }),
    stringsAsFactors = FALSE
  )
  
  write.csv(simple_report, 
            "validation/evidence/package_simple_validation.csv", 
            row.names = FALSE)
  
  cat("Simplified validation report saved to: validation/evidence/package_simple_validation.csv\n")
  
} else {
  # Step 4: Generate detailed risk report
  cat("Step 4/5: Generating detailed risk report...\n")
  
  risk_report <- scores %>%
    as_tibble() %>%
    mutate(
      package = all_packages[1:nrow(.)],
      risk_category = case_when(
        pkg_score <= 0.25 ~ "LOW",
        pkg_score <= 0.50 ~ "MEDIUM",
        pkg_score <= 0.75 ~ "HIGH",
        TRUE ~ "CRITICAL"
      ),
      validation_decision = case_when(
        pkg_score <= 0.33 ~ "APPROVED",
        pkg_score <= 0.50 ~ "CONDITIONAL (Enhanced Testing Required)",
        TRUE ~ "REJECTED (Alternative Required)"
      )
    ) %>%
    arrange(desc(pkg_score))
  
  # Step 5: Export validation evidence
  cat("Step 5/5: Exporting validation evidence...\n")
  
  write.csv(risk_report, 
            "validation/evidence/package_risk_scores.csv", 
            row.names = FALSE)
  
  # Individual metric breakdown (if available)
  if (ncol(assessments) > 1) {
    detailed_metrics <- assessments %>%
      as_tibble() %>%
      select(any_of(c(
        "package",
        "has_vignettes",
        "has_news",
        "has_bug_reports_url",
        "export_help",
        "license",
        "downloads_1yr",
        "reverse_dependencies",
        "has_maintainer"
      )))
    
    if (nrow(detailed_metrics) > 0) {
      write.csv(detailed_metrics,
                "validation/evidence/package_detailed_metrics.csv",
                row.names = FALSE)
    }
  }
  
  # Generate regulatory-ready summary
  cat("\n========== R Package Validation Summary ==========\n")
  cat("Assessment Date:", as.character(Sys.Date()), "\n")
  cat("Methodology: R Validation Hub riskmetric framework\n")
  cat("Acceptance Threshold: Risk Score ≤0.33\n\n")
  
  cat("APPROVED Packages (Risk ≤0.33):\n")
  approved <- risk_report %>% filter(validation_decision == "APPROVED")
  if (nrow(approved) > 0) {
    for (i in 1:nrow(approved)) {
      if (requireNamespace(approved$package[i], quietly = TRUE)) {
        cat(sprintf("  ✓ %s (v%s): Risk %.3f\n", 
                    approved$package[i], 
                    packageVersion(approved$package[i]),
                    approved$pkg_score[i]))
      } else {
        cat(sprintf("  ✓ %s: Risk %.3f (not installed)\n",
                    approved$package[i],
                    approved$pkg_score[i]))
      }
    }
  } else {
    cat("  None\n")
  }
  
  cat("\nREJECTED/CONDITIONAL Packages:\n")
  rejected <- risk_report %>% filter(validation_decision != "APPROVED")
  if (nrow(rejected) > 0) {
    for (i in 1:nrow(rejected)) {
      cat(sprintf("  ✗ %s: Risk %.3f - %s\n",
                  rejected$package[i],
                  rejected$pkg_score[i],
                  rejected$validation_decision[i]))
    }
  } else {
    cat("  None - all packages approved\n")
  }
  
  cat("\n=================================================\n")
  cat("\nValidation evidence exported to:\n")
  cat("  - validation/evidence/package_risk_scores.csv\n")
  if (file.exists("validation/evidence/package_detailed_metrics.csv")) {
    cat("  - validation/evidence/package_detailed_metrics.csv\n")
  }
}

# Generate session info for evidence package
sink("validation/evidence/sessionInfo.txt")
cat("Session Info for Package Risk Assessment\n")
cat("=========================================\n\n")
cat("Assessment Date:", as.character(Sys.time()), "\n\n")
sessionInfo()
sink()

cat("\n✓ Session info saved to: validation/evidence/sessionInfo.txt\n")

# Generate SHA-256 hash of renv.lock if it exists
if (file.exists("renv.lock")) {
  if (requireNamespace("digest", quietly = TRUE)) {
    lock_hash <- digest::digest(file = "renv.lock", algo = "sha256")
    writeLines(lock_hash, "validation/evidence/renv_lock_sha256.txt")
    cat("✓ renv.lock SHA-256 hash saved\n")
  }
}

cat("\n✓ Risk assessment complete!\n\n")
