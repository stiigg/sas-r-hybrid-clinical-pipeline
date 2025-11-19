# Logging utilities for the TLF subsystem.

#' Write a timestamped message to the configured log directory.
#'
#' @param message Character string to log.
#' @param log_file Name of the log file (default "tlf_run.log").
#' @param append Logical indicating whether to append (default TRUE).
#' @return Invisibly returns the message.
tlf_log <- function(message, log_file = "tlf_run.log", append = TRUE) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_dir <- getOption("tlf.log_dir", "logs")
  if (dirname(log_file) %in% c(".", "")) {
    dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
    path <- file.path(log_dir, log_file)
  } else {
    dir.create(dirname(log_file), showWarnings = FALSE, recursive = TRUE)
    path <- log_file
  }
  line <- sprintf("[%s] %s\n", timestamp, message)
  cat(line, file = path, append = append)
  invisible(message)
}

#' Convenience helper to log and message simultaneously.
#'
#' @param message Message to emit.
#' @param log_file Log file name.
tlf_log_message <- function(message, log_file = "tlf_run.log") {
  tlf_log(message, log_file = log_file)
  message(message)
  invisible(message)
}
