@echo off
REM Default to dry-run unless already set
IF "%ETL_DRY_RUN%"==""  SET ETL_DRY_RUN=true
IF "%QC_DRY_RUN%"==""   SET QC_DRY_RUN=true
IF "%TLF_DRY_RUN%"==""  SET TLF_DRY_RUN=true

ECHO Running sas-r-hybrid-clinical-pipeline with:
ECHO   ETL_DRY_RUN=%ETL_DRY_RUN%
ECHO   QC_DRY_RUN=%QC_DRY_RUN%
ECHO   TLF_DRY_RUN=%TLF_DRY_RUN%

Rscript run_all.R
