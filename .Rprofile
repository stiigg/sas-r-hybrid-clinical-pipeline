## Project-specific environment for sasrhybrid

# 1) Enforce R version
R_version <- "4.3.1"
if (getRversion() != R_version) {
  stop(
    sprintf("Project requires R %s, but you're using %s.",
            R_version, getRversion()),
    call. = FALSE
  )
}

# 2) Freeze package universe via CRAN snapshot
snapshot_date <- "2024-10-01"
options(repos = paste0(
  "https://packagemanager.posit.co/cran/", snapshot_date
))

# 3) Activate renv
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}
