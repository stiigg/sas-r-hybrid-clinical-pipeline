# Utility helpers for manifest management and hashing.

MANIFEST_COLUMNS <- c(
  "tlf_id","title","generator_script","qc_script","output_path",
  "output_type","output_version","input_files","input_hashes","code_sha",
  "run_date","run_by","run_status","output_sha256","notes"
)

get_git_sha <- function(short = TRUE) {
  args <- if (isTRUE(short)) c("rev-parse", "--short", "HEAD") else c("rev-parse", "HEAD")
  sha <- tryCatch(
    system2("git", args, stdout = TRUE, stderr = FALSE),
    warning = function(...) NA_character_,
    error = function(...) NA_character_
  )
  sha <- trimws(sha)
  if (length(sha) == 0) {
    NA_character_
  } else {
    sha[[1]]
  }
}

hash_file <- function(path, algo = "sha256") {
  if (!file.exists(path)) {
    stop(sprintf("Cannot hash missing file: %s", path), call. = FALSE)
  }
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("The 'digest' package is required for hashing.", call. = FALSE)
  }
  digest::digest(file = path, algo = algo, file = TRUE)
}

append_manifest_row <- function(manifest_path, row) {
  if (!is.list(row)) {
    stop("Manifest row must be provided as a named list.", call. = FALSE)
  }
  missing_cols <- setdiff(MANIFEST_COLUMNS, names(row))
  if (length(missing_cols) > 0) {
    stop(
      sprintf(
        "Manifest row missing required columns: %s",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)

  tmp_file <- tempfile("manifest_", tmpdir = dirname(manifest_path))
  on.exit(unlink(tmp_file), add = TRUE)

  header_line <- paste(MANIFEST_COLUMNS, collapse = ",")

  if (file.exists(manifest_path)) {
    if (!file.copy(manifest_path, tmp_file, overwrite = TRUE)) {
      stop(sprintf("Failed to create temporary copy of %s", manifest_path), call. = FALSE)
    }
  } else {
    writeLines(header_line, con = tmp_file)
  }

  con <- file(tmp_file, open = "a", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)

  row_df <- as.data.frame(row[MANIFEST_COLUMNS], stringsAsFactors = FALSE)
  utils::write.table(
    row_df,
    file = con,
    sep = ",",
    row.names = FALSE,
    col.names = FALSE,
    na = "",
    quote = TRUE
  )

  if (!file.rename(tmp_file, manifest_path)) {
    stop(sprintf("Failed to atomically update manifest at %s", manifest_path), call. = FALSE)
  }

  invisible(manifest_path)
}
