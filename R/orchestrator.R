#' Run the SAS-R hybrid pipeline
#'
#' This wrapper mirrors the repository-level orchestration in `run_all.R`
#' while keeping the control surface inside the package. It assumes the
#' working directory is the project root so existing scripts and specs are
#' discoverable without relocation.
#'
#' @param etl_dry_run Logical flag passed through to `run_all.R` via the
#'   `ETL_DRY_RUN` environment variable.
#' @param qc_dry_run Logical flag passed through to `run_all.R` via the
#'   `QC_DRY_RUN` environment variable.
#' @param tlf_dry_run Logical flag passed through to `run_all.R` via the
#'   `TLF_DRY_RUN` environment variable.
#' @return Invisibly returns whatever `run_all.R` produces (a list with ETL,
#'   QC, and generation details when available).
#' @export
run_pipeline <- function(
  etl_dry_run = as.logical(Sys.getenv("ETL_DRY_RUN", "TRUE")),
  qc_dry_run = as.logical(Sys.getenv("QC_DRY_RUN", "TRUE")),
  tlf_dry_run = as.logical(Sys.getenv("TLF_DRY_RUN", "TRUE"))
) {
  run_all <- file.path(getwd(), "run_all.R")
  if (!file.exists(run_all)) {
    stop("run_all.R not found in the working directory.", call. = FALSE)
  }

  old_env <- Sys.getenv(c("ETL_DRY_RUN", "QC_DRY_RUN", "TLF_DRY_RUN"), unset = NA_character_)
  on.exit({
    mapply(
      function(var, val) {
        if (is.na(val)) {
          Sys.unsetenv(var)
        } else {
          Sys.setenv(structure(val, names = var))
        }
      },
      names(old_env),
      old_env,
      SIMPLIFY = FALSE
    )
  }, add = TRUE)

  Sys.setenv(ETL_DRY_RUN = ifelse(isTRUE(etl_dry_run), "TRUE", "FALSE"))
  Sys.setenv(QC_DRY_RUN = ifelse(isTRUE(qc_dry_run), "TRUE", "FALSE"))
  Sys.setenv(TLF_DRY_RUN = ifelse(isTRUE(tlf_dry_run), "TRUE", "FALSE"))

  pipeline_env <- new.env(parent = baseenv())
  sys.source(run_all, envir = pipeline_env)
  invisible(mget(ls(envir = pipeline_env), envir = pipeline_env, inherits = FALSE))
}
