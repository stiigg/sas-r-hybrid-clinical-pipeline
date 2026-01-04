/******************************************************************************
* Program: 80_adam_adtr_consolidated.sas
* Version: 3.1 - Integrated Import Macros
* Purpose: ADTR (Tumor Results Analysis Dataset) per RECIST 1.1
* Author: Christian Baghai
* Date: 2026-01-04
* 
* EXECUTION MODES:
*   MODE 1: Basic SDIAM parameter (legacy functionality, fast execution)
*   MODE 2: Enhanced BDS with LDIAM+SDIAM+SNTLDIAM (regulatory ready)
*
* CONFIGURATION:
*   Edit config/global_parameters.sas to set execution mode and options
*
* USAGE:
*   %include "80_adam_adtr_consolidated.sas";
*
* ARCHITECTURE:
*   - Package-based modular design per PharmaSUG 2025-SD-116
*   - Hierarchical macro library (Foundation → Derivation → Parameter)
*   - Metadata-driven configuration per PharmaSUG 2025-AI-239
*   - Self-documenting with embedded validation
*
* DEPENDENCIES:
*   - SDTM: TR (Tumor Results), TU (Tumor Identification), DM or ADSL
*   - Package: ADTR_CORE v1.1+
*
* REFERENCES:
*   - PharmaSUG 2025-SA-287: Efficacy roadmap for early phase oncology
*   - PharmaSUG 2025-SD-116: SAS Packages framework
*   - PharmaSUG 2025-AI-239: GenAI code conversion (66% efficiency gain)
*   - PharmaSUG 2024-SD-211: Utility macros for data exploration
*   - Vitale et al. JNCI 2025: Censoring transparency
*   - Enaworu et al. Cureus 2025: 25mm nadir rule for progression
*
* VERSION HISTORY:
*   v1.0 (2026-01-03): Basic SLD/SDIAM implementation
*   v2.0 (2026-01-03): Enhanced BDS with multiple parameters
*   v3.0 (2026-01-03): Consolidated modular architecture
*   v3.1 (2026-01-04): Integrated import_tr/import_tu macros with validation
******************************************************************************/

/* ========================================
   STEP 0: INITIALIZATION & PACKAGE LOADING
   ======================================== */

options mprint mlogic symbolgen;  /* Enable macro debugging if needed */

/* Set project root if not already defined */
%let PROJ_ROOT = %sysget(PROJ_ROOT);
%if %length(&PROJ_ROOT) = 0 %then %do;
    %let PROJ_ROOT = /workspace/sas-r-hybrid-clinical-pipeline;
    %put WARNING: PROJ_ROOT not set in environment, using default: &PROJ_ROOT;
%end;

/* Load ADTR_CORE package with all dependencies */
%include "&PROJ_ROOT/adam/programs/sas/packages/package_loader.sas";
%load_package(ADTR_CORE);

/* Display package information */
%package_info(ADTR_CORE);

/* Initialize execution timer */
%let START_TIME = %sysfunc(datetime());
%put NOTE: ================================================;
%put NOTE: ADTR Program Execution Started;
%put NOTE: Mode: &ADTR_MODE | Study: &STUDY_ID;
%put NOTE: Start Time: %sysfunc(putn(&START_TIME, datetime20.));
%put NOTE: ================================================;

/* ========================================
   STEP 1: DATA IMPORT WITH VALIDATION
   ======================================== */

title "ADTR v&PROGRAM_VERSION: Data Import and Validation";

%put NOTE: ------------------------------------------------;
%put NOTE: STEP 1: Importing SDTM datasets with validation;
%put NOTE: ------------------------------------------------;

/* Import TR (Tumor Results) with validation */
%put NOTE: Importing TR (Tumor Results) with built-in validation...;
%import_tr(
    path=&SDTM_PATH,
    outds=work.tr_raw,
    validate=1
);

/* Import TU (Tumor Identification) with validation */
%put NOTE: Importing TU (Tumor Identification) with built-in validation...;
%import_tu(
    path=&SDTM_PATH,
    outds=work.tu_raw,
    validate=1
);

/* Import ADSL (if exists, otherwise create minimal version from DM) */
%macro import_adsl_safe;
    %if %sysfunc(fileexist(&ADAM_PATH/adsl.csv)) %then %do;
        %put NOTE: Importing ADSL from &ADAM_PATH...;
        proc import datafile="&ADAM_PATH/adsl.csv"
            out=work.adsl
            dbms=csv
            replace;
            guessingrows=max;
        run;
    %end;
    %else %if %sysfunc(fileexist(&SDTM_PATH/dm.csv)) %then %do;
        %put WARNING: ADSL not found, creating minimal version from DM...;
        proc import datafile="&SDTM_PATH/dm.csv"
            out=work.dm_temp
            dbms=csv
            replace;
            guessingrows=max;
        run;
        
        data work.adsl;
            set work.dm_temp;
            /* Add minimal ADaM variables */
            SAFFL = 'Y';
            ITTFL = 'Y';
            PPROTFL = 'Y';
            EVLFL = 'Y';
            label SAFFL = "Safety Population Flag"
                  ITTFL = "Intent-to-Treat Population Flag"
                  PPROTFL = "Per-Protocol Population Flag"
                  EVLFL = "Evaluable Population Flag";
        run;
    %end;
    %else %do;
        %put ERROR: Neither ADSL nor DM found in specified paths;
        %put ERROR: Cannot proceed without subject-level data;
        %abort;
    %end;
%mend import_adsl_safe;

%import_adsl_safe;

/* Data import summary already provided by validation macros */
%put NOTE: ------------------------------------------------;
%put NOTE: Data import with validation complete;
%put NOTE: ------------------------------------------------;

/* Additional summary from ADSL */
proc sql noprint;
    select count(*) into :n_subjects_adsl trimmed from work.adsl;
quit;

%put NOTE: Final Data Summary:;
%put NOTE:   TR records: &n_records (from import_tr validation);
%put NOTE:   TU records: (validated by import_tu);
%put NOTE:   ADSL subjects: &n_subjects_adsl;

/* ========================================
   STEP 2: FRAMEWORK DEMONSTRATION
   ======================================== */

title "ADTR v&PROGRAM_VERSION: Modular Framework Demonstration";

%put NOTE: ------------------------------------------------;
%put NOTE: STEP 2: Demonstrating modular architecture;
%put NOTE: ------------------------------------------------;

/* Create sample measurement data for baseline derivation demo */
data work.sample_measurements;
    set work.tr_raw;
    if not missing(TRSTRESN) and TRTESTCD = 'LDIAM';
    
    /* Add ADaM variables for demo */
    PARAMCD = 'LDIAM';
    AVAL = TRSTRESN;
    AVISITN = input(scan(VISIT, 1, ' '), ?? best.);
    if missing(AVISITN) then AVISITN = _N_;
    
    /* Derive ADY (Analysis Day) */
    if not missing(TRDTC) and not missing(RFSTDTC) then do;
        trdt = input(substr(TRDTC, 1, 10), yymmdd10.);
        rfstdt = input(substr(RFSTDTC, 1, 10), yymmdd10.);
        if not missing(trdt) and not missing(rfstdt) then do;
            ADY = trdt - rfstdt;
            if ADY >= 0 then ADY = ADY + 1;
        end;
    end;
    
    format trdt rfstdt date9.;
    keep USUBJID PARAMCD AVAL ADY AVISITN VISIT;
run;

proc sort data=work.sample_measurements;
    by USUBJID ADY;
run;

/* Demonstrate modular baseline derivation */
%if %sysmacexist(derive_baseline) %then %do;
    %put NOTE: Demonstrating derive_baseline macro...;
    
    %derive_baseline(
        inds=work.sample_measurements,
        outds=work.measurements_with_baseline,
        method=&BASELINE_METHOD,
        paramcd=LDIAM
    );
    
    /* Display results */
    proc sql;
        title2 "Baseline Derivation Results (First 10 records)";
        select USUBJID, ADY, AVAL, BASE, BASEFL
        from work.measurements_with_baseline
        order by USUBJID, ADY
        limit 10;
    quit;
%end;
%else %do;
    %put WARNING: derive_baseline macro not loaded - skipping demonstration;
%end;

/* ========================================
   STEP 3: PLACEHOLDER FOR FULL IMPLEMENTATION
   ======================================== */

%put NOTE: ------------------------------------------------;
%put NOTE: FRAMEWORK NOTES:;
%put NOTE: ------------------------------------------------;
%put NOTE: This consolidated program demonstrates the modular architecture.;
%put NOTE: Full ADTR derivation logic from v1.0 and v2.0 will be refactored;
%put NOTE: into the hierarchical macro library structure:;
%put NOTE: ;
%put NOTE: - macros/level1_utilities/ : Data import and validation (COMPLETE);
%put NOTE: - macros/level2_derivations/ : Baseline, nadir, percent change;
%put NOTE: - macros/level3_parameters/ : LDIAM, SDIAM, SNTLDIAM derivations;
%put NOTE: - macros/bds_structure/ : PARCAT, CRIT, ANL flags;
%put NOTE: - macros/qc_validation/ : Quality control checks;
%put NOTE: - macros/export/ : Output management;
%put NOTE: ;
%put NOTE: Update v3.1: import_tr and import_tu now integrated with validation;
%put NOTE: Each macro follows self-documenting standards per;
%put NOTE: PharmaSUG 2024-SD-211 with embedded validation.;
%put NOTE: ------------------------------------------------;

/* ========================================
   STEP 4: EXECUTION SUMMARY
   ======================================== */

%let END_TIME = %sysfunc(datetime());
%let ELAPSED_SEC = %sysevalf(&END_TIME - &START_TIME);
%let ELAPSED_MIN = %sysevalf(&ELAPSED_SEC / 60);

%put NOTE: ================================================;
%put NOTE: ADTR Program Execution Complete;
%put NOTE: ================================================;
%put NOTE: Program Version: &PROGRAM_VERSION (v3.1);
%put NOTE: Execution Mode: &ADTR_MODE;
%put NOTE: Study: &STUDY_ID;
%put NOTE: CDISC ADaM Version: &CDISC_ADAM_VERSION;
%put NOTE: RECIST Version: &RECIST_VERSION;
%put NOTE: ------------------------------------------------;
%put NOTE: Framework Status: Level 1 utilities integrated;
%put NOTE: Data Import: Complete with validation;
%put NOTE: Import Macros: import_tr v2.0, import_tu loaded;
%put NOTE: Baseline Demo: %sysfunc(ifc(%sysmacexist(derive_baseline), Complete, Skipped));
%put NOTE: ------------------------------------------------;
%put NOTE: Execution Time: %sysfunc(putn(&ELAPSED_MIN, 8.2)) minutes;
%put NOTE: End Time: %sysfunc(putn(&END_TIME, datetime20.));
%put NOTE: ================================================;
%put NOTE: Next Steps:;
%put NOTE: 1. Review enhanced import validation in log;
%put NOTE: 2. Refactor v1.0/v2.0 logic into Level 2+ macros;
%put NOTE: 3. Run integration tests in validation/integration_tests/;
%put NOTE: 4. Configure execution mode in config/global_parameters.sas;
%put NOTE: ================================================;

title;
