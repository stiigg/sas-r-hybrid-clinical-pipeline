# Structured JSONL logger for the TLF subsystem.

if (!exists("get_git_sha", mode = "function")) {
  get_git_sha <- function(...) NA_character_
}

tlf_log <- function(level = "INFO", message, meta = list(), log_file = NULL) {
  if (missing(message)) {
    stop("`message` must be supplied to tlf_log().", call. = FALSE)
  }

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The 'jsonlite' package is required for logging.", call. = FALSE)
  }

  log_dir <- getOption("tlf.log_dir", default = file.path("r", "tlf", "logs"))
  dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.null(log_file) || !nzchar(log_file)) {
    log_file <- file.path(
      log_dir,
      sprintf("run_%s.jsonl", format(Sys.time(), "%Y%m%d"))
    )
  } else if (!grepl(.Platform$file.sep, log_file, fixed = TRUE)) {
    log_file <- file.path(log_dir, log_file)
  }

  event <- list(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    level = toupper(level),
    message = as.character(message),
    git_sha = getOption("tlf.git_sha", default = tryCatch(get_git_sha(), error = function(...) NA_character_)),
    pid = Sys.getpid(),
    r_version = getRversion(),
    meta = meta
  )

  line <- jsonlite::toJSON(event, auto_unbox = TRUE)
  con <- file(log_file, open = "a", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(line, con = con, sep = "\n")

  invisible(event)
}
