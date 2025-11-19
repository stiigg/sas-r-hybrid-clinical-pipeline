#!/usr/bin/env Rscript

# Repository-level orchestration entry point with metadata-driven controls,
# dependency awareness, and provenance capture.

required_cran_pkgs <- c(
  "digest",
  "yaml",
  "dplyr",
  "readr",
  "purrr",
  "tidyr",
  "stringr",
  "glue",
  "jsonlite",
  "openxlsx",
  "haven",
  "testthat"
)

install_missing_pkgs <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) == 0L) {
    return(invisible(TRUE))
  }
  message("Installing missing packages: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
}

install_missing_pkgs(required_cran_pkgs)
invisible(lapply(required_cran_pkgs, require, character.only = TRUE))

`%||%` <- function(x, y) {
  if (is.null(x) || (is.character(x) && length(x) == 0)) {
    y
  } else {
    x
  }
}

source("automation/dependencies.R")
source("automation/hash_utils.R")
source("automation/run_manifest.R")
source("etl/run_etl.R")
source("qc/run_qc.R")
source("outputs/tlf/r/utils/load_config.R")
source("outputs/tlf/r/utils/tlf_logging.R")
source("automation/r/tlf/batch/batch_run_all_tlfs.R")
if (file.exists("validation/check_golden_patients.R")) {
  source("validation/check_golden_patients.R")
}
if (file.exists("R/mdr_utils.R")) {
  source("R/mdr_utils.R")
}

parse_bool_env <- function(var, default = TRUE) {
  raw <- Sys.getenv(var, NA_character_)
  if (is.na(raw) || !nzchar(raw)) {
    return(default)
  }
  !tolower(raw) %in% c("false", "0", "no", "n")
}

parse_cli_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  defaults <- list(
    pipeline_mode = Sys.getenv("PIPELINE_MODE", "dev"),
    data_cut = Sys.getenv("DATA_CUT", ""),
    target_tlfs = Sys.getenv("TARGET_TLFS", ""),
    changed_sdtm = Sys.getenv("CHANGED_SDTM", ""),
    changed_adam = Sys.getenv("CHANGED_ADAM", "")
  )
  for (arg in args) {
    if (!startsWith(arg, "--")) next
    kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1]]
    key <- kv[1]
    value <- if (length(kv) > 1) kv[2] else ""
    if (key %in% names(defaults)) {
      defaults[[key]] <- value
    }
  }
  defaults
}

parse_list_arg <- function(value) {
  if (!nzchar(value)) return(character())
  parts <- unlist(strsplit(value, ","))
  parts <- trimws(parts)
  parts[nzchar(parts)]
}

resolve_mode <- function(mode, study_cfg) {
  if (!nzchar(mode)) {
    mode <- names(study_cfg$modes)[1]
  }
  if (!mode %in% names(study_cfg$modes)) {
    stop(sprintf("Unknown pipeline mode '%s'", mode), call. = FALSE)
  }
  mode
}

resolve_cut <- function(requested, study_cfg) {
  if (!nzchar(requested)) {
    requested <- study_cfg$default_cut
  }
  if (!requested %in% names(study_cfg$analysis_cuts)) {
    stop(sprintf("Unknown analysis cut '%s'", requested), call. = FALSE)
  }
  requested
}

check_sas_available <- function() {
  status <- tryCatch(system("sas -help > /dev/null 2>&1"), error = function(e) 1L)
  if (!identical(status, 0L)) {
    stop(
      "SAS does not appear to be available on this system.\n",
      "For full ETL, ensure that:\n",
      "  * SAS is installed, and\n",
      "  * the 'sas' executable is on your PATH\n",
      "Or re-run with ETL_DRY_RUN=true to skip SAS-dependent steps.",
      call. = FALSE
    )
  }
}

state_path <- ".pipeline_state.json"
read_previous_state <- function(path) {
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

save_state <- function(path, hashes, run_meta, previous_state = NULL) {
  runs <- if (!is.null(previous_state) && !is.null(previous_state$runs)) {
    previous_state$runs
  } else {
    list()
  }
  runs <- append(runs, list(run_meta))
  jsonlite::write_json(
    list(
      sdtm = hashes$sdtm,
      adam = hashes$adam,
      specs = hashes$specs,
      runs = runs
    ),
    path,
    auto_unbox = TRUE,
    pretty = TRUE
  )
}

diff_hashes <- function(current, previous) {
  previous <- previous %||% list()
  names_all <- union(names(current), names(previous))
  changed <- character()
  for (nm in names_all) {
    cur_val <- current[[nm]]
    prev_val <- previous[[nm]]
    if (!identical(cur_val, prev_val)) {
      changed <- c(changed, nm)
    }
  }
  unique(changed)
}

compute_current_hashes <- function(data_root) {
  list(
    sdtm = hash_dir_files(file.path(data_root, "sdtm")),
    adam = hash_dir_files(file.path(data_root, "adam")),
    specs = list(
      study_config = hash_file("specs/config/study_config.yml"),
      oncology_endpoints = hash_file("specs/config/oncology_endpoints.yml"),
      adam_manifest = hash_file("specs/etl/adam_manifest.yml"),
      tlf_config = hash_file("specs/tlf/tlf_config.yml")
    )
  )
}

resolve_target_tlfs <- function(target_arg, impacted_adam, mode, study_cfg, spec_changes, initial_run) {
  catalog <- get_tlf_catalog(mode, study_cfg)
  allowed_ids <- vapply(catalog, function(entry) entry$tlf_id, character(1))
  if (nzchar(target_arg) && target_arg != "auto_from_dependencies") {
    requested <- parse_list_arg(target_arg)
    hits <- intersect(requested, allowed_ids)
    return(unique(hits))
  }
  target_ids <- get_impacted_tlfs(impacted_adam, mode, study_cfg)
  if (length(target_ids) == 0 && (initial_run || length(spec_changes) > 0)) {
    target_ids <- allowed_ids
  }
  if ("tlf_config" %in% spec_changes) {
    target_ids <- unique(c(target_ids, allowed_ids))
  }
  target_ids
}

args <- parse_cli_args()
study_cfg <- yaml::read_yaml("specs/config/study_config.yml")
mode <- resolve_mode(args$pipeline_mode, study_cfg)
cut <- resolve_cut(args$data_cut, study_cfg)
data_root <- study_cfg$analysis_cuts[[cut]]$data_root
config <- load_tlf_config()

ETL_DRY_RUN <- parse_bool_env("ETL_DRY_RUN", TRUE)
QC_DRY_RUN <- parse_bool_env("QC_DRY_RUN", TRUE)
TLF_DRY_RUN <- parse_bool_env("TLF_DRY_RUN", TRUE)

if (!dir.exists("logs")) dir.create("logs", recursive = TRUE)
pipeline_log <- "logs/pipeline.log"
log_msg <- function(msg) {
  line <- sprintf("[%s][%s] %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), Sys.info()[["user"]], msg)
  cat(line, "\n", file = pipeline_log, append = TRUE)
  message(line)
}

log_msg(sprintf("Pipeline mode: %s", mode))
log_msg(sprintf("Analysis cut: %s (%s)", cut, data_root))
log_msg(sprintf("ETL_DRY_RUN=%s QC_DRY_RUN=%s TLF_DRY_RUN=%s", ETL_DRY_RUN, QC_DRY_RUN, TLF_DRY_RUN))

hashes_cur <- compute_current_hashes(data_root)
prev_state <- read_previous_state(state_path)
initial_run <- is.null(prev_state)
prev_sdtm <- if (!is.null(prev_state)) prev_state$sdtm else list()
prev_adam <- if (!is.null(prev_state)) prev_state$adam else list()
prev_specs <- if (!is.null(prev_state)) prev_state$specs else list()

changed_sdtm <- unique(c(parse_list_arg(args$changed_sdtm), diff_hashes(hashes_cur$sdtm, prev_sdtm)))
changed_adam <- unique(c(parse_list_arg(args$changed_adam), diff_hashes(hashes_cur$adam, prev_adam)))
spec_changes <- diff_hashes(hashes_cur$specs, prev_specs)

log_msg(sprintf("Detected SDTM changes: %s", if (length(changed_sdtm) == 0) "none" else paste(changed_sdtm, collapse = ",")))
log_msg(sprintf("Detected ADaM changes: %s", if (length(changed_adam) == 0) "none" else paste(changed_adam, collapse = ",")))
log_msg(sprintf("Detected spec changes: %s", if (length(spec_changes) == 0) "none" else paste(spec_changes, collapse = ",")))

impacted_from_sdtm <- get_impacted_adam_from_sdtm(changed_sdtm)
impacted_from_adam <- get_impacted_adam_from_adam(changed_adam)
impacted_adam <- unique(c(changed_adam, impacted_from_sdtm, impacted_from_adam))

if (initial_run && length(impacted_adam) == 0) {
  adam_manifest <- read_adam_manifest()
  impacted_adam <- names(adam_manifest$adam)
}
if (any(spec_changes %in% c("study_config", "adam_manifest", "oncology_endpoints"))) {
  adam_manifest <- read_adam_manifest()
  impacted_adam <- unique(c(impacted_adam, names(adam_manifest$adam)))
}

log_msg(sprintf("Impacted ADaM datasets: %s", if (length(impacted_adam) == 0) "none" else paste(impacted_adam, collapse = ",")))

target_tlf_ids <- resolve_target_tlfs(args$target_tlfs, impacted_adam, mode, study_cfg, spec_changes, initial_run)
log_msg(sprintf("Target TLFs: %s", if (length(target_tlf_ids) == 0) "none" else paste(target_tlf_ids, collapse = ",")))

run_sdtm <- initial_run || length(changed_sdtm) > 0 || any(spec_changes %in% c("study_config"))
run_adam <- initial_run || length(impacted_adam) > 0
run_qc <- (!QC_DRY_RUN) && (initial_run || length(target_tlf_ids) > 0 || run_adam)
run_tlf <- length(target_tlf_ids) > 0

if (!ETL_DRY_RUN && run_sdtm) {
  check_sas_available()
}

validate_manifest <- function(df, name, required_cols) {
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop(sprintf("%s missing required column(s): %s", name, paste(missing, collapse = ", ")))
  }
  invisible(df)
}

etl_manifest_path <- "specs/etl_manifest.csv"
etl_manifest <- utils::read.csv(etl_manifest_path, stringsAsFactors = FALSE)
validate_manifest(etl_manifest, "ETL manifest", c("step_id", "dataset", "script", "engine", "description", "parity_group"))
qc_manifest_path <- "specs/qc_manifest.csv"
qc_manifest <- utils::read.csv(qc_manifest_path, stringsAsFactors = FALSE)
validate_manifest(qc_manifest, "QC manifest", c("task_id", "runner", "language", "script", "description"))
tlf_manifest_path <- "specs/tlf/tlf_shell_map.csv"
tlf_manifest <- utils::read.csv(tlf_manifest_path, stringsAsFactors = FALSE)
validate_manifest(tlf_manifest, "TLF manifest", c("tlf_id", "name", "gen_script", "qc_script", "out_file"))

steps_run <- character()
log_msg("Starting pipeline orchestration")

if (run_sdtm) {
  log_msg(sprintf("Running ETL phase (dry_run=%s)", ETL_DRY_RUN))
  etl_results <- run_full_etl(manifest_path = etl_manifest_path, dry_run = ETL_DRY_RUN)
  steps_run <- c(steps_run, sprintf("ETL:%s", paste(unique(etl_results$status), collapse = ",")))
} else {
  log_msg("Skipping ETL phase – no impacted SDTM")
}

if (run_adam && !run_sdtm) {
  log_msg("Re-running ADaM dependent steps due to impacted datasets")
  etl_results <- run_full_etl(manifest_path = etl_manifest_path, dry_run = ETL_DRY_RUN)
  steps_run <- c(steps_run, sprintf("ADAM:%s", paste(unique(etl_results$status), collapse = ",")))
}

qc_results <- NULL
if (run_qc) {
  log_msg(sprintf("Running QC phase (dry_run=%s)", QC_DRY_RUN))
  qc_results <- run_qc_plan(manifest_path = qc_manifest_path, dry_run = QC_DRY_RUN, config = if (QC_DRY_RUN) NULL else config)
  steps_run <- c(steps_run, sprintf("QC:%s", paste(unique(qc_results$status), collapse = ",")))
} else {
  log_msg("Skipping QC phase – not required for this mode/run")
}

if (run_tlf) {
  if (TLF_DRY_RUN) {
    gen_results <- data.frame(
      tlf_id = target_tlf_ids,
      status = "dry_run",
      message = "Dry run - generation skipped",
      script = NA_character_,
      log = NA_character_,
      stringsAsFactors = FALSE
    )
  } else {
    manifest_subset <- tlf_manifest[tlf_manifest$tlf_id %in% target_tlf_ids, , drop = FALSE]
    if (nrow(manifest_subset) == 0 && length(target_tlf_ids) > 0) {
      warning("Requested TLFs not found in manifest; running full set.")
      manifest_subset <- tlf_manifest
    }
    options(tlf.config = config)
    gen_results <- run_all_tlfs(config, target_ids = target_tlf_ids)
  }
  steps_run <- c(steps_run, sprintf("TLF:%s", paste(unique(gen_results$status), collapse = ",")))
} else {
  log_msg("Skipping TLF generation – no impacted shells")
  gen_results <- data.frame()
}

if (exists("check_golden_patients")) {
  if (mode %in% c("near_lock", "final_lock")) {
    log_msg("Running oncology golden patient regression checks")
    try(check_golden_patients(data_root), silent = TRUE)
  } else {
    log_msg("Golden patient checks skipped for this mode")
  }
}

log_msg("Pipeline run complete; writing provenance artefacts")

git_commit <- tryCatch(system("git rev-parse HEAD", intern = TRUE), error = function(e) "unknown")
run_meta <- list(
  timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  git_commit = git_commit,
  mode = mode,
  analysis_cut = cut,
  target_tlfs = target_tlf_ids
)
save_state(state_path, hashes_cur, run_meta, prev_state)
manifest_name <- sprintf("run_manifest_%s.yml", format(Sys.time(), "%Y%m%d_%H%M%S"))
write_run_manifest(
  manifest_path = file.path("logs", manifest_name),
  git_commit = git_commit,
  pipeline_mode = mode,
  analysis_cut = cut,
  data_root = data_root,
  sdtm_hashes = hashes_cur$sdtm,
  adam_hashes = hashes_cur$adam,
  spec_hashes = hashes_cur$specs,
  steps_ran = steps_run
)

invisible(list(
  etl = if (exists("etl_results")) etl_results else NULL,
  qc = qc_results,
  generation = gen_results,
  target_tlfs = target_tlf_ids
))
