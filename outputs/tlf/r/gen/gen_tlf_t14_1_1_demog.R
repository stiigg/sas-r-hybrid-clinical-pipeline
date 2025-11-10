# Demographics TLF generator implemented with deterministic helpers.

source("outputs/tlf/r/utils/manifest_helpers.R")
source("outputs/tlf/r/utils/tlf_log.R")
source("outputs/tlf/r/utils/safe_io.R")
source("outputs/tlf/r/utils/file_paths.R")

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || identical(x, "") || all(is.na(x))) {
    y
  } else {
    x
  }
}

sanitize_for_log <- function(x) {
  gsub("[^A-Za-z0-9]+", "_", x)
}

resolve_shell_entry <- function(config, tlf_id) {
  if (is.null(config$shells)) {
    return(NULL)
  }
  matches <- Filter(function(x) identical(x$id, tlf_id), config$shells)
  if (length(matches) == 0) {
    return(NULL)
  }
  matches[[1]]
}

script_filename <- function(fun) {
  srcref <- attr(fun, "srcref")
  if (is.null(srcref)) {
    return(NA_character_)
  }
  srcfile <- attr(srcref, "srcfile")
  if (is.null(srcfile$filename)) {
    return(NA_character_)
  }
  basename(srcfile$filename)
}

write_rtf_atomic <- function(lines, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile("rtf_", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  con <- file(tmp, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(lines, con)
  if (!file.rename(tmp, path)) {
    stop(sprintf("Failed to atomically write RTF to %s", path), call. = FALSE)
  }
  invisible(path)
}

generate_tlf <- function(tlf_id, config, dry_run = FALSE) {
  if (missing(config)) {
    stop("`config` must be supplied to generate_tlf().", call. = FALSE)
  }

  shell_entry <- resolve_shell_entry(config, tlf_id)
  tlf_title <- shell_entry$name %||% tlf_id
  output_type <- shell_entry$type %||% "tables"
  output_version <- shell_entry$version %||% "v1"
  qc_script <- shell_entry$qc_script %||% NA_character_

  log_file <- sprintf("%s_generation.jsonl", sanitize_for_log(tlf_id))
  start_meta <- list(tlf_id = tlf_id, dry_run = dry_run)
  tlf_log(level = "INFO", message = sprintf("Starting generator for %s", tlf_id), meta = start_meta, log_file = log_file)

  output_path <- get_output_path(
    config = config,
    type = output_type,
    tlf_id = tlf_id,
    name = tlf_title,
    version = output_version,
    ext = "rtf"
  )

  summary_table <- aggregate(mtcars$mpg, by = list(Cylinders = mtcars$cyl), FUN = function(x) c(N = length(x), Mean = mean(x)))
  summary_table <- do.call(data.frame, summary_table)

  rtf_lines <- c(
    "{\\rtf1\\ansi",
    sprintf("{\\b %s\\b0}\\line", paste(tlf_id, tlf_title, sep = ": ")),
    paste("Population:", config$options$default_population %||% getOption("tlf.default_population", "Not specified")),
    "\\line",
    "Cylinders\\tab N\\tab Mean MPG\\line"
  )

  for (i in seq_len(nrow(summary_table))) {
    row <- summary_table[i, ]
    rtf_lines <- c(rtf_lines, sprintf("%s\\tab %s\\tab %.2f\\line", row$Cylinders, row$x.N, row$x.Mean))
  }
  rtf_lines <- c(rtf_lines, "}")

  if (!isTRUE(dry_run)) {
    write_rtf_atomic(rtf_lines, output_path)
  }

  manifest_path <- file.path(config$paths$output_dir %||% "outputs/tlf/r/output", "manifest.csv")

  generator_script <- script_filename(generate_tlf)
  if (is.na(generator_script)) {
    generator_script <- "gen_tlf_t14_1_1_demog.R"
  }

  manifest_row <- list(
    tlf_id = tlf_id,
    title = tlf_title,
    generator_script = generator_script,
    qc_script = qc_script,
    output_path = output_path,
    output_type = output_type,
    output_version = output_version,
    input_files = "",
    input_hashes = "",
    code_sha = get_git_sha(),
    run_date = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    run_by = Sys.info()[["user"]] %||% Sys.getenv("USER", unset = NA_character_),
    run_status = if (isTRUE(dry_run)) "dry_run" else "success",
    output_sha256 = if (isTRUE(dry_run)) NA_character_ else hash_file(output_path),
    notes = if (isTRUE(dry_run)) "dry_run" else ""
  )

  if (!isTRUE(dry_run)) {
    append_manifest_row(manifest_path, manifest_row)
  }

  tlf_log(level = "INFO", message = sprintf("Completed generator for %s", tlf_id), meta = c(start_meta, list(output_path = output_path)), log_file = log_file)

  invisible(output_path)
}
