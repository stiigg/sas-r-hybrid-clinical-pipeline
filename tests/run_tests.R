#!/usr/bin/env Rscript

scripts <- c(
  file.path("qc", "tests", "run_tests.R"),
  file.path("automation", "tests", "run_tests.R")
)

failures <- 0
for (script in scripts) {
  message(sprintf("[TEST HARNESS] Running %s", script))
  result <- system2("Rscript", args = script)
  if (!identical(result, 0L)) {
    message(sprintf("[TEST HARNESS] %s failed with exit code %s", script, result))
    failures <- failures + 1
  }
}

if (failures > 0) {
  stop(sprintf("%s test script(s) failed", failures), call. = FALSE)
} else {
  message("All repository test scripts passed.")
}
