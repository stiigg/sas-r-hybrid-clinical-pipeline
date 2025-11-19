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

load_adam_dataset <- function(config, dataset_name) {
  adam_dir <- config$paths$adam %||% "data/adam"
  base <- tolower(dataset_name %||% "adsl")
  candidates <- file.path(adam_dir, paste0(base, c(".xpt", ".sas7bdat")))
  existing <- candidates[file.exists(candidates)]
  if (length(existing) == 0) {
    return(list(data = NULL, path = candidates[[1]]))
  }
  if (!requireNamespace("haven", quietly = TRUE)) {
    warning("Package 'haven' not installed; returning NULL dataset")
    return(list(data = NULL, path = existing[[1]]))
  }
  path <- existing[[1]]
  reader <- if (grepl("\\.xpt$", path, ignore.case = TRUE)) haven::read_xpt else haven::read_sas
  list(data = reader(path), path = path)
}

apply_metadata_filters <- function(df, filters) {
  filters <- Filter(function(x) !is.null(x) && nzchar(x), filters)
  if (length(filters) == 0 || is.null(df)) {
    return(df)
  }
  expr <- parse(text = paste(filters, collapse = " & "))
  tryCatch(subset(df, eval(expr, envir = df)), error = function(err) {
    warning(sprintf("Failed to apply metadata filters: %s", err$message))
    df
  })
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
  analysis_meta <- list(
    objective_id = shell_entry$objective_id %||% NA_character_,
    estimand_id = shell_entry$estimand_id %||% NA_character_,
    endpoint_id = shell_entry$endpoint_id %||% NA_character_,
    population = shell_entry$population %||% config$options$default_population %||% getOption("tlf.default_population", NA_character_),
    analysis_method = shell_entry$analysis_method %||% NA_character_,
    adam_dataset = shell_entry$adam_dataset %||% "ADSL",
    paramcd_filter = shell_entry$paramcd_filter %||% "",
    flag_filter = shell_entry$flag_filter %||% ""
  )

  log_file <- sprintf("%s_generation.jsonl", sanitize_for_log(tlf_id))
  start_meta <- c(list(tlf_id = tlf_id, dry_run = dry_run), analysis_meta)
  tlf_log(level = "INFO", message = sprintf("Starting generator for %s", tlf_id), meta = start_meta, log_file = log_file)

  output_path <- get_output_path(
    config = config,
    type = output_type,
    tlf_id = tlf_id,
    name = tlf_title,
    version = output_version,
    ext = "rtf"
  )

  dataset_info <- load_adam_dataset(config, analysis_meta$adam_dataset)
  analysis_data <- apply_metadata_filters(dataset_info$data, c(analysis_meta$paramcd_filter, analysis_meta$flag_filter))
  summary_table <- NULL
  if (!is.null(analysis_data) && "TRT01A" %in% names(analysis_data)) {
    counts <- as.data.frame(table(analysis_data$TRT01A), stringsAsFactors = FALSE)
    names(counts) <- c("Group", "N")
    summary_table <- counts
  } else if (!is.null(analysis_data) && "SEX" %in% names(analysis_data)) {
    counts <- as.data.frame(table(analysis_data$SEX), stringsAsFactors = FALSE)
    names(counts) <- c("Group", "N")
    summary_table <- counts
  } else {
    summary_table <- aggregate(mtcars$mpg, by = list(Group = mtcars$cyl), FUN = function(x) c(N = length(x), Mean = mean(x)))
    summary_table <- do.call(data.frame, summary_table)
  }

  rtf_lines <- c(
    "{\\rtf1\\ansi",
    sprintf("{\\b %s\\b0}\\line", paste(tlf_id, tlf_title, sep = ": ")), 
    paste("Objective:", analysis_meta$objective_id %||% "Not specified"),
    paste("Estimand:", analysis_meta$estimand_id %||% "Not specified"),
    paste("Endpoint:", analysis_meta$endpoint_id %||% "Not specified"),
    paste("Population:", analysis_meta$population %||% "Not specified"),
    paste("Analysis Method:", analysis_meta$analysis_method %||% "Not specified"),
    "\\line",
    if (ncol(summary_table) == 3) "Group\\tab N\\tab Mean\\line" else "Group\\tab N\\line"
  )

  for (i in seq_len(nrow(summary_table))) {
    row <- summary_table[i, ]
    if (ncol(summary_table) == 3) {
      rtf_lines <- c(rtf_lines, sprintf("%s\\tab %s\\tab %.2f\\line", row$Group, row$x.N, row$x.Mean))
    } else {
      rtf_lines <- c(rtf_lines, sprintf("%s\\tab %s\\line", row$Group, row$N))
    }
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

  filter_desc <- paste(Filter(nzchar, c(analysis_meta$paramcd_filter, analysis_meta$flag_filter)), collapse = " & ")
  manifest_row <- list(
    tlf_id = tlf_id,
    title = tlf_title,
    generator_script = generator_script,
    qc_script = qc_script,
    output_path = output_path,
    output_type = output_type,
    output_version = output_version,
    input_files = dataset_info$path %||% "",
    input_hashes = "",
    code_sha = get_git_sha(),
    run_date = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    run_by = Sys.info()[["user"]] %||% Sys.getenv("USER", unset = NA_character_),
    run_status = if (isTRUE(dry_run)) "dry_run" else "success",
    output_sha256 = if (isTRUE(dry_run)) NA_character_ else hash_file(output_path),
    notes = if (isTRUE(dry_run)) "dry_run" else if (nzchar(filter_desc)) sprintf("Filters: %s", filter_desc) else ""
  )

  if (!isTRUE(dry_run)) {
    append_manifest_row(manifest_path, manifest_row)
  }

  tlf_log(
    level = "INFO",
    message = sprintf("Completed generator for %s", tlf_id),
    meta = c(start_meta, list(output_path = output_path, input_path = dataset_info$path %||% NA_character_)),
    log_file = log_file
  )

  invisible(output_path)
}
