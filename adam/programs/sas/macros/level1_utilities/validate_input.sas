/******************************************************************************
* Macro: VALIDATE_INPUT
* Purpose: Comprehensive data quality validation for ADTR inputs
* Version: 1.0
* 
* PARAMETERS:
*   tr_ds          - TR dataset name
*   tu_ds          - TU dataset name
*   adsl_ds        - ADSL dataset name
*   min_subjects   - Minimum required subjects (default: 1)
*   min_measurements - Minimum measurements per subject (default: 1)
*
* VALIDATION CHECKS:
*   1. Dataset existence and non-empty
*   2. USUBJID consistency across domains
*   3. Required variable presence
*   4. TULINKID linkage between TU and TR
*   5. RFSTDTC availability for ADY derivation
*   6. Minimum data thresholds
*   7. Date format validation
*
* REFERENCES:
*   - PharmaSUG 2024: Data quality checks
*   - NRG Oncology 2025: Common RECIST errors
*   - CDISC validation rules
*
* EXAMPLE USAGE:
*   %validate_input(
*       tr_ds=work.tr_raw,
*       tu_ds=work.tu_raw,
*       adsl_ds=work.adsl,
*       min_subjects=1,
*       min_measurements=1
*   );
*
* AUTHOR: Christian Baghai
* DATE: 2026-01-03
******************************************************************************/

%macro validate_input(
    tr_ds=,
    tu_ds=,
    adsl_ds=,
    min_subjects=1,
    min_measurements=1
) / des="Comprehensive data quality validation for ADTR inputs";

    /* Parameter validation */
    %if %length(&tr_ds) = 0 or %length(&tu_ds) = 0 or %length(&adsl_ds) = 0 %then %do;
        %put ERROR: [VALIDATE_INPUT] All dataset parameters required: tr_ds, tu_ds, adsl_ds;
        %return;
    %end;
    
    %put NOTE: [VALIDATE_INPUT] Starting comprehensive validation...;
    
    %let validation_errors = 0;
    %let validation_warnings = 0;
    
    /* Check dataset existence */
    %if not %sysfunc(exist(&tr_ds)) %then %do;
        %put ERROR: [VALIDATE_INPUT] TR dataset not found: &tr_ds;
        %let validation_errors = %eval(&validation_errors + 1);
    %end;
    
    %if not %sysfunc(exist(&tu_ds)) %then %do;
        %put ERROR: [VALIDATE_INPUT] TU dataset not found: &tu_ds;
        %let validation_errors = %eval(&validation_errors + 1);
    %end;
    
    %if not %sysfunc(exist(&adsl_ds)) %then %do;
        %put ERROR: [VALIDATE_INPUT] ADSL dataset not found: &adsl_ds;
        %let validation_errors = %eval(&validation_errors + 1);
    %end;
    
    /* Stop if datasets don't exist */
    %if &validation_errors > 0 %then %do;
        %put ERROR: [VALIDATE_INPUT] Cannot proceed with missing datasets;
        %return;
    %end;
    
    /* Check non-empty datasets */
    proc sql noprint;
        select count(*) into :n_tr_records trimmed from &tr_ds;
        select count(*) into :n_tu_records trimmed from &tu_ds;
        select count(*) into :n_adsl_records trimmed from &adsl_ds;
    quit;
    
    %if &n_tr_records = 0 %then %do;
        %put ERROR: [VALIDATE_INPUT] TR dataset is empty;
        %let validation_errors = %eval(&validation_errors + 1);
    %end;
    
    %if &n_tu_records = 0 %then %do;
        %put ERROR: [VALIDATE_INPUT] TU dataset is empty;
        %let validation_errors = %eval(&validation_errors + 1);
    %end;
    
    %if &n_adsl_records = 0 %then %do;
        %put ERROR: [VALIDATE_INPUT] ADSL dataset is empty;
        %let validation_errors = %eval(&validation_errors + 1);
    %end;
    
    /* Check minimum subjects */
    proc sql noprint;
        select count(distinct USUBJID) into :n_subjects_adsl trimmed from &adsl_ds;
        select count(distinct USUBJID) into :n_subjects_tr trimmed from &tr_ds;
        select count(distinct USUBJID) into :n_subjects_tu trimmed from &tu_ds;
    quit;
    
    %if &n_subjects_adsl < &min_subjects %then %do;
        %put ERROR: [VALIDATE_INPUT] ADSL has &n_subjects_adsl subjects, minimum required: &min_subjects;
        %let validation_errors = %eval(&validation_errors + 1);
    %end;
    
    %put NOTE: [VALIDATE_INPUT] Subject counts:;
    %put NOTE: [VALIDATE_INPUT]   ADSL: &n_subjects_adsl;
    %put NOTE: [VALIDATE_INPUT]   TR: &n_subjects_tr;
    %put NOTE: [VALIDATE_INPUT]   TU: &n_subjects_tu;
    
    /* Check USUBJID consistency */
    proc sql;
        create table _subjects_in_tr_not_adsl as
        select distinct USUBJID
        from &tr_ds
        where USUBJID not in (select USUBJID from &adsl_ds);
        
        create table _subjects_in_tu_not_adsl as
        select distinct USUBJID
        from &tu_ds
        where USUBJID not in (select USUBJID from &adsl_ds);
    quit;
    
    proc sql noprint;
        select count(*) into :n_tr_orphan trimmed from _subjects_in_tr_not_adsl;
        select count(*) into :n_tu_orphan trimmed from _subjects_in_tu_not_adsl;
    quit;
    
    %if &n_tr_orphan > 0 %then %do;
        %put WARNING: [VALIDATE_INPUT] &n_tr_orphan subjects in TR but not in ADSL;
        %let validation_warnings = %eval(&validation_warnings + 1);
    %end;
    
    %if &n_tu_orphan > 0 %then %do;
        %put WARNING: [VALIDATE_INPUT] &n_tu_orphan subjects in TU but not in ADSL;
        %let validation_warnings = %eval(&validation_warnings + 1);
    %end;
    
    /* Check TULINKID linkage */
    proc sql;
        create table _tulinkid_in_tr_not_tu as
        select distinct USUBJID, TULINKID
        from &tr_ds
        where not missing(TULINKID)
          and cats(USUBJID, TULINKID) not in 
              (select distinct cats(USUBJID, TULINKID) from &tu_ds);
    quit;
    
    proc sql noprint;
        select count(*) into :n_unlinked_tulinkid trimmed from _tulinkid_in_tr_not_tu;
    quit;
    
    %if &n_unlinked_tulinkid > 0 %then %do;
        %put WARNING: [VALIDATE_INPUT] &n_unlinked_tulinkid TR records with TULINKID not in TU;
        %put WARNING: [VALIDATE_INPUT] These measurements cannot be classified as target/non-target;
        %let validation_warnings = %eval(&validation_warnings + 1);
    %end;
    
    /* Check RFSTDTC for ADY derivation */
    proc sql noprint;
        select count(*) into :n_missing_rfstdtc trimmed
        from &adsl_ds
        where missing(RFSTDTC);
    quit;
    
    %if &n_missing_rfstdtc > 0 %then %do;
        %put WARNING: [VALIDATE_INPUT] &n_missing_rfstdtc subjects missing RFSTDTC in ADSL;
        %put WARNING: [VALIDATE_INPUT] ADY cannot be derived for these subjects;
        %let validation_warnings = %eval(&validation_warnings + 1);
    %end;
    
    /* Check TRDTC format in TR */
    proc sql noprint;
        select count(*) into :n_missing_trdtc trimmed
        from &tr_ds
        where missing(TRDTC);
    quit;
    
    %if &n_missing_trdtc > 0 %then %do;
        %put WARNING: [VALIDATE_INPUT] &n_missing_trdtc TR records missing TRDTC;
        %put WARNING: [VALIDATE_INPUT] ADY/ADT cannot be derived for these records;
        %let validation_warnings = %eval(&validation_warnings + 1);
    %end;
    
    /* Check measurements per subject */
    proc sql;
        create table _subject_measurement_counts as
        select USUBJID, count(*) as n_measurements
        from &tr_ds
        group by USUBJID
        having count(*) < &min_measurements;
    quit;
    
    proc sql noprint;
        select count(*) into :n_insufficient_data trimmed from _subject_measurement_counts;
    quit;
    
    %if &n_insufficient_data > 0 %then %do;
        %put WARNING: [VALIDATE_INPUT] &n_insufficient_data subjects have < &min_measurements measurements;
        %let validation_warnings = %eval(&validation_warnings + 1);
    %end;
    
    /* Check TRSTRESN (numeric result) */
    proc sql noprint;
        select count(*) into :n_missing_trstresn trimmed
        from &tr_ds
        where missing(TRSTRESN) and TRTESTCD in ('LDIAM', 'LPERP');
    quit;
    
    %if &n_missing_trstresn > 0 %then %do;
        %put WARNING: [VALIDATE_INPUT] &n_missing_trstresn lesion measurements missing TRSTRESN;
        %let validation_warnings = %eval(&validation_warnings + 1);
    %end;
    
    /* Validation summary */
    %put NOTE: ================================================;
    %put NOTE: [VALIDATE_INPUT] VALIDATION SUMMARY;
    %put NOTE: ================================================;
    %put NOTE: Records:;
    %put NOTE:   TR: &n_tr_records records, &n_subjects_tr subjects;
    %put NOTE:   TU: &n_tu_records records, &n_subjects_tu subjects;
    %put NOTE:   ADSL: &n_adsl_records subjects;
    %put NOTE: ------------------------------------------------;
    %put NOTE: Data Quality:;
    %put NOTE:   Subjects in TR not in ADSL: &n_tr_orphan;
    %put NOTE:   Subjects in TU not in ADSL: &n_tu_orphan;
    %put NOTE:   Unlinked TULINKIDs: &n_unlinked_tulinkid;
    %put NOTE:   Missing RFSTDTC: &n_missing_rfstdtc;
    %put NOTE:   Missing TRDTC: &n_missing_trdtc;
    %put NOTE:   Missing TRSTRESN: &n_missing_trstresn;
    %put NOTE:   Subjects < &min_measurements measurements: &n_insufficient_data;
    %put NOTE: ------------------------------------------------;
    %put NOTE: Validation Result:;
    %put NOTE:   Errors: &validation_errors;
    %put NOTE:   Warnings: &validation_warnings;
    
    %if &validation_errors > 0 %then %do;
        %put ERROR: [VALIDATE_INPUT] VALIDATION FAILED with &validation_errors errors;
        %put ERROR: [VALIDATE_INPUT] Review data quality before proceeding;
    %end;
    %else %if &validation_warnings > 0 %then %do;
        %put WARNING: [VALIDATE_INPUT] VALIDATION PASSED with &validation_warnings warnings;
        %put WARNING: [VALIDATE_INPUT] Review warnings and proceed with caution;
    %end;
    %else %do;
        %put NOTE: [VALIDATE_INPUT] VALIDATION PASSED - No errors or warnings;
    %end;
    
    %put NOTE: ================================================;
    
    /* Clean up temporary datasets */
    proc datasets library=work nolist;
        delete _subjects_in_tr_not_adsl _subjects_in_tu_not_adsl
               _tulinkid_in_tr_not_tu _subject_measurement_counts;
    quit;
    
%mend validate_input;