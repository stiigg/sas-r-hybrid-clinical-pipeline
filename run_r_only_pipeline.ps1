# PowerShell script to run R-only clinical pipeline
# No SAS required - uses pharmaverse packages

Write-Host "Installing pharmaverse packages..." -ForegroundColor Cyan
Rscript install_pharmaverse.R

Write-Host "`nRunning R-only pipeline in non-dry-run mode..." -ForegroundColor Green
$env:ETL_DRY_RUN = "false"
$env:QC_DRY_RUN = "false"
$env:TLF_DRY_RUN = "false"

Rscript.exe -e "options(repos = c(CRAN = 'https://cloud.r-project.org')); source('run_all.R')"

Write-Host "`nPipeline execution complete!" -ForegroundColor Green
Write-Host "Check outputs/ directory for generated files" -ForegroundColor Yellow
