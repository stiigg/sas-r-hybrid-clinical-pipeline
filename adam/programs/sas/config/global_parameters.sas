/******************************************************************************
* Program: global_parameters.sas
* Version: 1.0
* Purpose: Global configuration parameters for ADTR pipeline
* Author: Christian Baghai
* Date: 2026-01-04
*
* USAGE:
*   %include "config/global_parameters.sas";
*   (All parameters become available as macro variables)
*
* MODIFICATION INSTRUCTIONS:
*   1. Update SDTM_PATH and ADAM_PATH for your environment
*   2. Set ADTR_MODE: 1=Basic (SDIAM only), 2=Enhanced (all parameters)
*   3. Configure validation options per your SOPs
*   4. Set algorithm options per protocol requirements
*
* NOTES:
*   - This file is included by package_loader.sas automatically
*   - Changes here affect all programs using ADTR_CORE package
*   - Document any deviations from defaults in study-specific documentation
******************************************************************************/

%put NOTE: ================================================;
%put NOTE: Loading Global Parameters v1.0;
%put NOTE: ================================================;

/* ============================================
   EXECUTION MODE
   ============================================ */
%global ADTR_MODE;
%let ADTR_MODE = 2;              /* 1=Basic SDIAM, 2=Enhanced BDS */

%put NOTE: [CONFIG] Execution Mode: &ADTR_MODE;
%if &ADTR_MODE = 1 %then %put NOTE: [CONFIG]   Mode 1: Basic SDIAM parameter (fast execution);
%if &ADTR_MODE = 2 %then %put NOTE: [CONFIG]   Mode 2: Enhanced BDS with LDIAM+SDIAM+SNTLDIAM;

/* ============================================
   PATH CONFIGURATION
   ============================================ */
%global SDTM_PATH ADAM_PATH OUTPUT_PATH;
%let SDTM_PATH = ../../sdtm/data/csv;
%let ADAM_PATH = ../../adam/data;
%let OUTPUT_PATH = ../../adam/output;

%put NOTE: [CONFIG] Paths:;
%put NOTE: [CONFIG]   SDTM: &SDTM_PATH;
%put NOTE: [CONFIG]   ADaM: &ADAM_PATH;
%put NOTE: [CONFIG]   Output: &OUTPUT_PATH;

/* ============================================
   VALIDATION OPTIONS
   ============================================ */
%global VALIDATE_IMPORTS STOP_ON_ERROR DEBUG_MODE;
%let VALIDATE_IMPORTS = 1;       /* 1=Run validation on all imports, 0=Skip */
%let STOP_ON_ERROR = 1;          /* 1=Abort on validation errors, 0=Continue with warnings */
%let DEBUG_MODE = 0;             /* 0=Standard, 1=Verbose, 2=Full debug */

%put NOTE: [CONFIG] Validation Options:;
%put NOTE: [CONFIG]   Validate Imports: %sysfunc(ifc(&VALIDATE_IMPORTS=1, YES, NO));
%put NOTE: [CONFIG]   Stop on Error: %sysfunc(ifc(&STOP_ON_ERROR=1, YES, NO));
%put NOTE: [CONFIG]   Debug Mode: &DEBUG_MODE;

/* ============================================
   ALGORITHM OPTIONS
   ============================================ */
%global APPLY_ENAWORU_RULE BASELINE_METHOD NADIR_EXCLUDE_BASELINE RECIST_VERSION;
%let APPLY_ENAWORU_RULE = 1;     /* 1=Use 25mm nadir rule (Enaworu et al.), 0=Standard */
%let BASELINE_METHOD = PRETREAT; /* PRETREAT=Pre-treatment scan, FIRST=First available */
%let NADIR_EXCLUDE_BASELINE = 1; /* 1=Exclude baseline from nadir (Vitale et al.), 0=Include */
%let RECIST_VERSION = 1.1;       /* RECIST version: 1.1 or 1.0 */

%put NOTE: [CONFIG] Algorithm Options:;
%put NOTE: [CONFIG]   Enaworu Rule (25mm nadir): %sysfunc(ifc(&APPLY_ENAWORU_RULE=1, ENABLED, DISABLED));
%put NOTE: [CONFIG]   Baseline Method: &BASELINE_METHOD;
%put NOTE: [CONFIG]   Nadir Excludes Baseline: %sysfunc(ifc(&NADIR_EXCLUDE_BASELINE=1, YES, NO));
%put NOTE: [CONFIG]   RECIST Version: &RECIST_VERSION;

/* ============================================
   QUALITY CONTROL
   ============================================ */
%global RUN_VALIDATION VALIDATION_OUTPUT;
%let RUN_VALIDATION = 1;         /* 1=Run QC checks, 0=Skip */
%let VALIDATION_OUTPUT = &OUTPUT_PATH/validation;

%put NOTE: [CONFIG] Quality Control:;
%put NOTE: [CONFIG]   Run Validation: %sysfunc(ifc(&RUN_VALIDATION=1, YES, NO));
%put NOTE: [CONFIG]   Validation Output: &VALIDATION_OUTPUT;

/* ============================================
   STUDY METADATA
   ============================================ */
%global STUDY_ID PROGRAM_VERSION CDISC_ADAM_VERSION SPONSOR;
%let STUDY_ID = NEXICART2-SOLID-TUMOR;
%let PROGRAM_VERSION = 3.1;
%let CDISC_ADAM_VERSION = 1.3;
%let SPONSOR = Generic Sponsor;

%put NOTE: [CONFIG] Study Metadata:;
%put NOTE: [CONFIG]   Study ID: &STUDY_ID;
%put NOTE: [CONFIG]   Program Version: &PROGRAM_VERSION;
%put NOTE: [CONFIG]   CDISC ADaM Version: &CDISC_ADAM_VERSION;
%put NOTE: [CONFIG]   Sponsor: &SPONSOR;

/* ============================================
   DATE/TIME STAMP
   ============================================ */
%global CONFIG_LOAD_TIME;
%let CONFIG_LOAD_TIME = %sysfunc(datetime());

%put NOTE: [CONFIG] Configuration loaded: %sysfunc(putn(&CONFIG_LOAD_TIME, datetime20.));
%put NOTE: ================================================;
