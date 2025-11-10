#!/usr/bin/env Rscript

# Central quality-control orchestrator driven by specs/qc_manifest.csv. Each
# row defines a QC task, the runner to use, and the target script. Tasks can be
# SAS command lines, standalone R scripts, or metadata-driven batch processes
# (e.g., TLF QC using the shell map). The script produces machine- and
# human-readable summaries to streamline review workflows.

source("outputs/tlf/r/utils/load_config.R")
source("qc/r/tlf/run_tlf_qc_batch.R")

read_qc_manifest <- function(path = "specs/qc_manifest.csv") {
  if (!file.exists(path)) {
    stop(sprintf("QC manifest not found at %s", path), call. = FALSE)
  }
  manifest <- utils::read.csv(path, stringsAsFactors = FALSE)
  expected <- c("task_id", "runner", "language", "script", "description")
  missing <- setdiff(expected, names(manifest))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "QC manifest missing required columns: %s",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  manifest
}

run_qc_task <- function(task, dry_run = TRUE, config = NULL) {
  runner <- tolower(task$runner)
  language <- tolower(task$language)
  script <- task$script
  message <- ""
  status <- "skipped"
  command <- NULL
  details <- NULL

  if (runner == "tlf_batch") {
    command <- "run_qc_for_all_tlfs()"
    if (!file.exists(script)) {
      status <- "missing"
      message <- sprintf("Batch runner not found at %s", script)
    } else if (dry_run) {
      status <- "dry_run"
      message <- "Dry run - batch QC not executed"
    } else {
      config <- config %||% load_tlf_config()
      batch_results <- run_qc_for_all_tlfs(config)
      details <- batch_results
      if (all(batch_results$status == "success")) {
        status <- "success"
        message <- sprintf("Processed %d TLF QC scripts", nrow(batch_results))
      } else {
        status <- "warning"
        message <- sprintf(
          "Processed %d TLF QC scripts with issues", nrow(batch_results)
        )
      }
    }
  } else if (runner %in% c("rscript", "rs")) {
    command <- sprintf("Rscript %s", shQuote(script))
    if (!file.exists(script)) {
      status <- "missing"
      message <- sprintf("QC script not found at %s", script)
    } else if (dry_run) {
      status <- "dry_run"
      message <- "Dry run - no execution"
    } else {
      exit_code <- system2("Rscript", c(script))
      status <- if (identical(exit_code, 0L)) "success" else "error"
      message <- if (identical(exit_code, 0L)) "" else sprintf("Exited with code %s", exit_code)
    }
  } else if (runner %in% c("sas", "sas_batch")) {
    sas_bin <- Sys.which("sas")
    command <- sprintf("%s -sysin %s", sas_bin, shQuote(script))
    if (!file.exists(script)) {
      status <- "missing"
      message <- sprintf("QC script not found at %s", script)
    } else if (!nzchar(sas_bin)) {
      status <- "sas_missing"
      message <- "SAS executable not found on PATH"
    } else if (dry_run) {
      status <- "dry_run"
      message <- "Dry run - no execution"
    } else {
      exit_code <- system2(sas_bin, c("-sysin", script))
      status <- if (identical(exit_code, 0L)) "success" else "error"
      message <- if (identical(exit_code, 0L)) "" else sprintf("Exited with code %s", exit_code)
    }
  } else {
    status <- "unsupported"
    message <- sprintf("Unsupported runner '%s' for task %s", runner, task$task_id)
  }

  list(
    task_id = task$task_id,
    description = task$description,
    status = status,
    message = message,
    command = command,
    details = details
  )
}

run_qc_plan <- function(manifest_path = "specs/qc_manifest.csv", dry_run = TRUE, config = NULL) {
  manifest <- read_qc_manifest(manifest_path)
  records <- lapply(seq_len(nrow(manifest)), function(i) {
    run_qc_task(manifest[i, ], dry_run = dry_run, config = config)
  })
  summary <- data.frame(
    task_id = vapply(records, `[[`, character(1), "task_id"),
    description = vapply(records, `[[`, character(1), "description"),
    status = vapply(records, `[[`, character(1), "status"),
    message = vapply(records, function(x) x$message %||% "", character(1)),
    command = vapply(records, function(x) x$command %||% "", character(1)),
    stringsAsFactors = FALSE
  )
  summary$details <- I(lapply(records, `[[`, "details"))
  summary
}

write_qc_reports <- function(summary, output_dir = "qc/reports") {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  html_path <- file.path(output_dir, sprintf("qc_summary_%s.html", timestamp))
  text_path <- file.path(output_dir, sprintf("qc_summary_%s.txt", timestamp))
  latest_html <- file.path(output_dir, "qc_summary_latest.html")
  latest_text <- file.path(output_dir, "qc_summary_latest.txt")

  status_counts <- sort(table(summary$status), decreasing = TRUE)
  issue_rows <- which(summary$status %in% c("error", "warning", "missing", "sas_missing", "unsupported"))
  validation_flag <- if (length(issue_rows) > 0) "FAILED" else "PASSED"

  to_table <- function(df) {
    if (nrow(df) == 0) {
      return("<p>No issues detected.</p>")
    }
    rows <- apply(df, 1, function(row) {
      sprintf(
        "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
        row[["task_id"]],
        row[["status"]],
        row[["description"]],
        row[["message"]]
      )
    })
    paste0(
      "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\">",
      "<thead><tr><th>Task</th><th>Status</th><th>Description</th><th>Message</th></tr></thead>",
      "<tbody>",
      paste(rows, collapse = ""),
      "</tbody></table>"
    )
  }

  issue_df <- summary[issue_rows, c("task_id", "status", "description", "message"), drop = FALSE]
  html_lines <- c(
    "<html>",
    "<head><title>QC Summary Report</title></head>",
    "<body>",
    sprintf("<h1>QC Summary - %s</h1>", timestamp),
    sprintf("<p><strong>Validation flag:</strong> %s</p>", validation_flag),
    "<h2>Status Counts</h2>",
    "<ul>",
    sapply(names(status_counts), function(name) {
      sprintf("<li>%s: %s</li>", name, status_counts[[name]])
    }),
    "</ul>",
    "<h2>Issues</h2>",
    to_table(issue_df),
    "<h2>All Tasks</h2>",
    to_table(summary[, c("task_id", "status", "description", "message"), drop = FALSE]),
    "</body>",
    "</html>"
  )

  writeLines(unlist(html_lines), con = html_path)
  file.copy(html_path, latest_html, overwrite = TRUE)

  text_lines <- c(
    sprintf("QC Summary - %s", timestamp),
    sprintf("Validation flag: %s", validation_flag),
    "",
    "Status counts:",
    sprintf("  %s: %s", names(status_counts), status_counts),
    "",
    "Issues:",
    if (nrow(issue_df) == 0) {
      "  None"
    } else {
      apply(issue_df, 1, function(row) {
        sprintf("  %s (%s): %s", row[["task_id"]], row[["status"]], row[["message"]])
      })
    }
  )

  writeLines(unlist(text_lines), con = text_path)
  file.copy(text_path, latest_text, overwrite = TRUE)

  invisible(list(html = html_path, text = text_path, validation = validation_flag))
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

if (identical(environment(), globalenv()) && !interactive()) {
  dry_run_env <- tolower(Sys.getenv("QC_DRY_RUN", "true"))
  dry_run <- dry_run_env %in% c("true", "1", "yes", "y")
  manifest_path <- commandArgs(trailingOnly = TRUE)
  manifest_path <- if (length(manifest_path) > 0) manifest_path[[1]] else "specs/qc_manifest.csv"
  config <- NULL
  if (!dry_run) {
    config <- load_tlf_config()
  }
  summary <- run_qc_plan(manifest_path = manifest_path, dry_run = dry_run, config = config)
  reports <- write_qc_reports(summary)
  print(summary[, setdiff(names(summary), "details"), drop = FALSE])
  message(sprintf("QC summary written to %s", reports$html))
}
