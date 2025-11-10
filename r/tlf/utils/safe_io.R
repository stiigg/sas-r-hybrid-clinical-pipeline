# Safe IO helpers for deterministic pipeline operations.

.with_atomic_file <- function(path, write_fun) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile("atomic_", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  write_fun(tmp)
  if (!file.rename(tmp, path)) {
    stop(sprintf("Failed to atomically replace %s", path), call. = FALSE)
  }
  invisible(path)
}

safe_read <- function(path, reader = NULL, ...) {
  if (!file.exists(path)) {
    stop(sprintf("Input file not found: %s", path), call. = FALSE)
  }
  if (is.null(reader)) {
    reader <- function(file, ...) utils::read.csv(file, stringsAsFactors = FALSE, ...)
  }
  reader(path, ...)
}

atomic_write_csv <- function(data, path, writer = NULL, ...) {
  if (is.null(writer)) {
    writer <- function(x, file, ...) utils::write.csv(x, file = file, row.names = FALSE, ...)
  }
  .with_atomic_file(path, function(tmp) writer(data, file = tmp, ...))
}

atomic_write_xlsx <- function(data, path, writer = NULL, sheet = 1, ...) {
  if (is.null(writer)) {
    if (!requireNamespace("openxlsx", quietly = TRUE)) {
      stop("The 'openxlsx' package is required to write XLSX files.", call. = FALSE)
    }
    writer <- function(x, file, sheet, ...) {
      openxlsx::write.xlsx(x, file = file, sheetName = sheet, ...)
    }
  }
  .with_atomic_file(path, function(tmp) writer(data, file = tmp, sheet = sheet, ...))
}
