# Build pkglite bundle for sasrhybrid
# Run this script from project root to produce inst/submission/sasrhybrid-pkglite.txt

if (!requireNamespace("pkglite", quietly = TRUE)) {
  stop("Package 'pkglite' is required to create the bundle.", call. = FALSE)
}

files <- c(
  pkglite::file_root_core("sasrhybrid"),
  pkglite::file_r("sasrhybrid"),
  pkglite::file_vignettes("sasrhybrid"),
  pkglite::file_auto("inst")
)

pkglite::pack(
  files = files,
  output = "inst/submission/sasrhybrid-pkglite.txt",
  compression = "gzip"
)
