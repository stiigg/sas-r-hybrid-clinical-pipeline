/******************************************************************************
* File: config/global_parameters.sas
* Purpose: Centralized configuration for ADTR program execution
* Author: Christian Baghai
* Date: 2026-01-03
* Version: 1.0
*
* Description:
*   Configuration-driven approach for ADTR derivation following metadata-driven
*   development principles (PharmaSUG 2025-AI-239). Enables Mode 1 (Basic SDIAM)
*   or Mode 2 (Enhanced BDS) execution through simple parameter changes.
*
* Usage:
*   %include "&PROJ_ROOT/adam/programs/sas/config/global_parameters.sas";
*
* References:
*   - PharmaSUG 2025-SD-116: SAS Packages framework
*   - PharmaSUG 2025-AI-239: Metadata-driven development
******************************************************************************/

/* ========================================
   EXECUTION MODE CONTROL
   ======================================== */
%let ADTR_MODE = 2;              /* 1=Basic SDIAM only, 2=Enhanced BDS */
%let STUDY_ID = NEXICART2-SOLID-TUMOR;
%let PROTOCOL_VERSION = 2.0;

/* ========================================
   QUALITY CONTROL OPTIONS
   ======================================== */
%let DEBUG_MODE = 0;             /* 0=Standard, 1=Verbose, 2=Debug */
%let RUN_VALIDATION = 1;         /* 1=Run QC checks, 0=Skip */
%let COMPARE_BASELINE = 0;       /* 1=Compare against archived output */

/* ========================================
   OUTPUT OPTIONS
   ======================================== */
%let EXPORT_CSV = 1;             /* 1=Create CSV, 0=Skip */
%let EXPORT_XPT = 1;             /* 1=Create XPT transport, 0=Skip */
%let EXPORT_SAS7BDAT = 1;        /* 1=Create SAS dataset, 0=Skip */
%let CREATE_METADATA = 1;        /* 1=Generate define.xml prep, 0=Skip */

/* ========================================
   ALGORITHM OPTIONS (MODE-SPECIFIC)
   ======================================== */
%let APPLY_ENAWORU_RULE = 1;     /* 1=Use 25mm nadir rule, 0=Standard */
%let BASELINE_METHOD = PRETREAT; /* PRETREAT=ADY<1, FIRST=First visit */
%let NADIR_EXCLUDE_BASELINE = 1; /* 1=Vitale 2025 method, 0=Include baseline */
%let MIN_TARGET_LESIONS = 1;     /* Minimum required target lesions */

/* ========================================
   PATH DEFINITIONS
   ======================================== */
%let PROJ_ROOT = %sysget(PROJ_ROOT);
%if %length(&PROJ_ROOT) = 0 %then %do;
    /* Default path if environment variable not set */
    %let PROJ_ROOT = /workspace/sas-r-hybrid-clinical-pipeline;
%end;

%let SDTM_PATH = &PROJ_ROOT/sdtm/data/csv;
%let ADAM_PATH = &PROJ_ROOT/adam/data;
%let MACRO_PATH = &PROJ_ROOT/adam/programs/sas/macros;
%let OUTPUT_PATH = &ADAM_PATH;
%let LOG_PATH = &PROJ_ROOT/logs;

/* Create log directory if it doesn't exist */
options dlcreatedir;
libname _tmplog "&LOG_PATH";
libname _tmplog clear;

/* ========================================
   VERSION CONTROL
   ======================================== */
%let PROGRAM_VERSION = 3.0;
%let LAST_MODIFIED = 2026-01-03;
%let CDISC_ADAM_VERSION = 1.3;
%let RECIST_VERSION = 1.1;

/* ========================================
   DISPLAY CONFIGURATION
   ======================================== */
%put NOTE: ================================================;
%put NOTE: ADTR Configuration Loaded;
%put NOTE: ================================================;
%put NOTE: Execution Mode: &ADTR_MODE;
%put NOTE: Study ID: &STUDY_ID;
%put NOTE: Protocol Version: &PROTOCOL_VERSION;
%put NOTE: ------------------------------------------------;
%put NOTE: Algorithm Options:;
%put NOTE:   ENAWORU Rule: &APPLY_ENAWORU_RULE;
%put NOTE:   Baseline Method: &BASELINE_METHOD;
%put NOTE:   Nadir Exclude Baseline: &NADIR_EXCLUDE_BASELINE;
%put NOTE: ------------------------------------------------;
%put NOTE: Quality Control:;
%put NOTE:   Debug Mode: &DEBUG_MODE;
%put NOTE:   Run Validation: &RUN_VALIDATION;
%put NOTE: ------------------------------------------------;
%put NOTE: Project Root: &PROJ_ROOT;
%put NOTE: ================================================;
