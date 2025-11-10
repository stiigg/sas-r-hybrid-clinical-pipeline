# Helper to construct deterministic output paths for TLF artefacts.

`%||%` <- function(x, y) {
  if (is.null(x) || (is.character(x) && length(x) == 0) || identical(x, "")) {
    y
  } else {
    x
  }
}

sanitize_component <- function(x) {
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  tolower(x)
}

get_output_path <- function(config, type, tlf_id, name = NULL, version = NULL, ext) {
  stopifnot(!missing(config), !missing(type), !missing(tlf_id), !missing(ext))
  base_dir <- config$paths$output_dir %||% getOption("tlf.output_dir", "outputs/tlf/r/output")
  sub_dir <- file.path(base_dir, sanitize_component(type))
  dir.create(sub_dir, recursive = TRUE, showWarnings = FALSE)

  parts <- c(tlf_id, name, version)
  parts <- parts[!vapply(parts, function(p) is.null(p) || !nzchar(p), logical(1))]
  filename <- paste(vapply(parts, sanitize_component, character(1)), collapse = "_")
  filename <- paste0(filename, ".", ext)

  file.path(sub_dir, filename)
}
