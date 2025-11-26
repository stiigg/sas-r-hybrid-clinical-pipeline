# R Environment for `sasrhybrid`

- R version: 4.3.1
- CRAN snapshot: https://packagemanager.posit.co/cran/2024-10-01

Rebuild steps (example):

1. Install R 4.3.1.
2. Clone or unpack the `sasrhybrid` package source.
3. In R:

   ```r
   source(".Rprofile")  # applies snapshot and activates renv when present
   install.packages("renv")
   renv::restore()
   sasrhybrid::run_pipeline(
     etl_dry_run = TRUE, qc_dry_run = TRUE, tlf_dry_run = TRUE
   )
   ```
