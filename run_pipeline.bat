@echo off
setlocal enabledelayedexpansion

set PIPELINE_MODE=%PIPELINE_MODE:=%
set DATA_CUT=%DATA_CUT:=%
set TARGET_TLFS=%TARGET_TLFS:=%
set CHANGED_SDTM=%CHANGED_SDTM:=%
set CHANGED_ADAM=%CHANGED_ADAM:=%

Rscript run_all.R ^
  --pipeline_mode "%PIPELINE_MODE%" ^
  --data_cut "%DATA_CUT%" ^
  --target_tlfs "%TARGET_TLFS%" ^
  --changed_sdtm "%CHANGED_SDTM%" ^
  --changed_adam "%CHANGED_ADAM%"
