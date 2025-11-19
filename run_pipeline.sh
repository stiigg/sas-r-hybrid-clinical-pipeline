#!/usr/bin/env bash
set -euo pipefail

Rscript run_all.R \
  --pipeline_mode "${PIPELINE_MODE:-dev}" \
  --data_cut "${DATA_CUT:-}" \
  --target_tlfs "${TARGET_TLFS:-}" \
  --changed_sdtm "${CHANGED_SDTM:-}" \
  --changed_adam "${CHANGED_ADAM:-}"
