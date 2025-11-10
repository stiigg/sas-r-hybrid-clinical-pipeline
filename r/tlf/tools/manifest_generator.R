#!/usr/bin/env Rscript

suppressWarnings(suppressMessages({
  if (!requireNamespace("yaml", quietly = TRUE)) {
    message("NOTE: yaml package not installed. Shell metadata may be limited.")
  }
}))

read_lines_safe <- function(path) {
  if (!file.exists(path)) {
    return(character())
  }
  readLines(path, warn = FALSE, encoding = "UTF-8")
}

extract_literals <- function(lines, predicate) {
  if (length(lines) == 0) {
    return(character())
  }
  target_lines <- lines[predicate(lines)]
  if (length(target_lines) == 0) {
    return(character())
  }
  matches <- regmatches(target_lines, gregexpr('"([^"\\]*(\\.[^"\\]*)*)"', target_lines, perl = TRUE))
  literals <- unique(unlist(matches))
  literals <- gsub('^"|"$', "", literals)
  literals
}

has_function_export <- function(lines, fun_name) {
  any(grepl(sprintf("%s\\s*<-\\s*function", fun_name), lines, perl = TRUE))
}

scan_script <- function(path) {
  lines <- read_lines_safe(path)
  reads <- extract_literals(lines, function(x) grepl("safe_read|read\\.csv|readr::read", x))
  writes <- extract_literals(lines, function(x) grepl("atomic_write|writeLines|write\\.csv|openxlsx::write", x))
  literals <- extract_literals(lines, function(x) grepl('"', x))
  abs_paths <- literals[grepl("^(/|[A-Za-z]:\\\\)", literals)]

  list(
    script = basename(path),
    has_generate_tlf = has_function_export(lines, "generate_tlf"),
    has_qc = has_function_export(lines, "qc_tlf"),
    reads = paste(sort(unique(reads)), collapse = ";"),
    writes = paste(sort(unique(writes)), collapse = ";"),
    absolute_paths = paste(sort(unique(abs_paths)), collapse = ";")
  )
}

scripts <- list.files("r/tlf/gen", pattern = "\\.R$", full.names = TRUE)
qc_scripts <- list.files("r/tlf/qc", pattern = "\\.R$", full.names = TRUE)
all_scripts <- unique(c(scripts, qc_scripts))

info <- lapply(all_scripts, scan_script)
if (length(info) == 0) {
  info_df <- data.frame(
    script = character(),
    has_generate_tlf = logical(),
    has_qc = logical(),
    reads = character(),
    writes = character(),
    absolute_paths = character(),
    stringsAsFactors = FALSE
  )
} else {
  info_df <- do.call(rbind, lapply(info, as.data.frame, stringsAsFactors = FALSE))
}

output_dir <- file.path("r", "tlf", "output")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

output_path <- file.path(output_dir, "manifest_auto.csv")
utils::write.table(
  info_df,
  file = output_path,
  sep = ",",
  row.names = FALSE,
  col.names = TRUE,
  na = "",
  quote = TRUE
)

message(sprintf("Manifest auto-report written to %s", output_path))
