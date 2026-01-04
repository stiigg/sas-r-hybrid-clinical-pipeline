/******************************************************************************
* Macro: import_tr
* Version: 2.0
* Purpose: Import SDTM TR dataset with comprehensive validation
* Author: Christian Baghai
* Date: 2026-01-04
*
* PARAMETERS:
*   path     - Directory containing tr.csv file (required)
*   outds    - Output dataset name (default: work.tr)
*   validate - Run validation checks (default: 1)
*              1 = Full validation with quality summary
*              0 = Import only, no validation
*
* RETURNS:
*   - Output dataset with TR data
*   - Macro variables: n_records, n_subjects, n_missing_result
*   - Log messages with validation summary
*   - Aborts on critical errors if STOP_ON_ERROR=1
*
* VALIDATION CHECKS:
*   - File existence
*   - Import success (SYSERR check)
*   - Required variables: USUBJID (critical), TRTESTCD, TRDTC, TRSTRESN
*   - Missing value analysis
*   - Data quality warnings
*
* DEPENDENCIES:
*   - Global macro variable: STOP_ON_ERROR (from global_parameters.sas)
*
* USAGE EXAMPLES:
*   %import_tr(path=../../sdtm/data/csv, outds=work.tr_raw, validate=1);
*   %import_tr(path=&SDTM_PATH, outds=tr);
*
* MODIFICATION HISTORY:
*   v1.0 (2026-01-03): Initial version with basic validation
*   v2.0 (2026-01-04): Enhanced error handling and abort capability
******************************************************************************/

%macro import_tr(
    path=,
    outds=work.tr,
    validate=1
) / des="Import SDTM TR dataset with validation";

    /* ============================================
       PARAMETER VALIDATION
       ============================================ */
    
    %if %length(&path) = 0 %then %do;
        %put ERROR: [IMPORT_TR] PATH parameter is required;
        %put ERROR: [IMPORT_TR] Usage: %%import_tr(path=/path/to/csv, outds=work.tr, validate=1);
        %abort cancel;
    %end;

    %put NOTE: ================================================;
    %put NOTE: [IMPORT_TR] Starting TR import;
    %put NOTE: [IMPORT_TR] Version: 2.0;
    %put NOTE: [IMPORT_TR] Source: &path/tr.csv;
    %put NOTE: [IMPORT_TR] Target: &outds;
    %put NOTE: [IMPORT_TR] Validation: %sysfunc(ifc(&validate=1, ENABLED, DISABLED));
    %put NOTE: ================================================;
    
    /* ============================================
       FILE EXISTENCE CHECK
       ============================================ */
    
    %if %sysfunc(fileexist(&path/tr.csv)) = 0 %then %do;
        %put ERROR: [IMPORT_TR] File not found: &path/tr.csv;
        %put ERROR: [IMPORT_TR] Verify SDTM_PATH is correct;
        %put ERROR: [IMPORT_TR] Current path: &path;
        
        /* Check if STOP_ON_ERROR is defined */
        %if %symexist(STOP_ON_ERROR) %then %do;
            %if &STOP_ON_ERROR = 1 %then %do;
                %abort cancel;
            %end;
        %end;
        %else %do;
            %abort cancel;  /* Default to abort if not specified */
        %end;
    %end;
    
    /* ============================================
       IMPORT DATA
       ============================================ */
    
    %put NOTE: [IMPORT_TR] Importing data from CSV...;
    
    proc import datafile="&path/tr.csv"
        out=&outds
        dbms=csv
        replace;
        guessingrows=max;
    run;
    
    /* Check for import errors */
    %if &SYSERR > 0 or &SYSCC > 4 %then %do;
        %put ERROR: [IMPORT_TR] PROC IMPORT failed;
        %put ERROR: [IMPORT_TR] SYSERR=&SYSERR, SYSCC=&SYSCC;
        
        %if %symexist(STOP_ON_ERROR) %then %do;
            %if &STOP_ON_ERROR = 1 %then %do;
                %abort cancel;
            %end;
        %end;
        %else %do;
            %abort cancel;
        %end;
    %end;
    
    %put NOTE: [IMPORT_TR] Import completed successfully;
    
    /* ============================================
       VALIDATION (if requested)
       ============================================ */
    
    %if &validate = 1 %then %do;
        
        %put NOTE: [IMPORT_TR] Running validation checks...;
        
        /* Check dataset exists and has observations */
        %let dsid = %sysfunc(open(&outds));
        %if &dsid = 0 %then %do;
            %put ERROR: [IMPORT_TR] Cannot open dataset &outds;
            %abort cancel;
        %end;
        
        %let nobs = %sysfunc(attrn(&dsid, NOBS));
        %let rc = %sysfunc(close(&dsid));
        
        %if &nobs = 0 %then %do;
            %put WARNING: [IMPORT_TR] Dataset &outds has 0 observations;
            %put WARNING: [IMPORT_TR] Check source data file;
        %end;
        
        /* Check required variables exist */
        proc contents data=&outds out=work._tr_vars(keep=name) noprint;
        run;
        
        %global has_usubjid has_trtestcd has_trdtc has_trstresn;
        
        data _null_;
            set work._tr_vars end=eof;
            retain has_usubjid has_trtestcd has_trdtc has_trstresn 0;
            
            name_upper = upcase(name);
            
            if name_upper = 'USUBJID' then has_usubjid = 1;
            if name_upper = 'TRTESTCD' then has_trtestcd = 1;
            if name_upper = 'TRDTC' then has_trdtc = 1;
            if name_upper = 'TRSTRESN' then has_trstresn = 1;
            
            if eof then do;
                call symputx('has_usubjid', has_usubjid, 'G');
                call symputx('has_trtestcd', has_trtestcd, 'G');
                call symputx('has_trdtc', has_trdtc, 'G');
                call symputx('has_trstresn', has_trstresn, 'G');
                
                put "NOTE: [IMPORT_TR] Variable Check Results:";
                if has_usubjid = 1 then put "NOTE: [IMPORT_TR]   ✓ USUBJID found";
                else put "ERROR: [IMPORT_TR]   ✗ USUBJID NOT FOUND (CRITICAL)";
                
                if has_trtestcd = 1 then put "NOTE: [IMPORT_TR]   ✓ TRTESTCD found";
                else put "WARNING: [IMPORT_TR]   ✗ TRTESTCD not found";
                
                if has_trdtc = 1 then put "NOTE: [IMPORT_TR]   ✓ TRDTC found";
                else put "WARNING: [IMPORT_TR]   ✗ TRDTC not found";
                
                if has_trstresn = 1 then put "NOTE: [IMPORT_TR]   ✓ TRSTRESN found";
                else put "WARNING: [IMPORT_TR]   ✗ TRSTRESN not found";
            end;
        run;
        
        /* Abort if critical variable missing */
        %if &has_usubjid = 0 %then %do;
            %put ERROR: [IMPORT_TR] USUBJID variable is required but not found;
            %put ERROR: [IMPORT_TR] This is a CDISC SDTM TR domain requirement;
            %put ERROR: [IMPORT_TR] Cannot proceed without patient identifier;
            
            %if %symexist(STOP_ON_ERROR) %then %do;
                %if &STOP_ON_ERROR = 1 %then %do;
                    %abort cancel;
                %end;
            %end;
            %else %do;
                %abort cancel;
            %end;
        %end;
        
        /* Data quality summary */
        %global n_records n_subjects n_missing_result;
        
        proc sql noprint;
            select count(*) into :n_records trimmed from &outds;
            
            %if &has_usubjid = 1 %then %do;
                select count(distinct USUBJID) into :n_subjects trimmed from &outds;
            %end;
            %else %do;
                %let n_subjects = UNKNOWN;
            %end;
            
            %if &has_trstresn = 1 %then %do;
                select count(*) into :n_missing_result trimmed 
                    from &outds 
                    where missing(TRSTRESN) or TRSTRESN = .;
            %end;
            %else %do;
                %let n_missing_result = UNKNOWN;
            %end;
        quit;
        
        %put NOTE: ================================================;
        %put NOTE: [IMPORT_TR] VALIDATION SUMMARY;
        %put NOTE: ================================================;
        %put NOTE: [IMPORT_TR] Dataset: &outds;
        %put NOTE: [IMPORT_TR] Total Records: &n_records;
        %put NOTE: [IMPORT_TR] Unique Subjects: &n_subjects;
        %put NOTE: [IMPORT_TR] Missing TRSTRESN: &n_missing_result;
        
        /* Calculate and warn if too many missing values */
        %if &n_records > 0 and &n_missing_result ne UNKNOWN %then %do;
            %let pct_missing = %sysevalf(&n_missing_result / &n_records * 100);
            %put NOTE: [IMPORT_TR] Percent Missing: %sysfunc(putn(&pct_missing, 5.1))%%;
            
            %if %sysevalf(&pct_missing > 10) %then %do;
                %put WARNING: [IMPORT_TR] More than 10%% of records have missing TRSTRESN;
                %put WARNING: [IMPORT_TR] This may be expected for non-target lesions;
                %put WARNING: [IMPORT_TR] Review data to confirm appropriateness;
            %end;
        %end;
        
        %put NOTE: ================================================;
        
        /* Cleanup temporary datasets */
        proc datasets library=work nolist;
            delete _tr_vars;
        quit;
        
    %end; /* End validation */
    
    %put NOTE: [IMPORT_TR] Import complete: &outds (&n_records records, &n_subjects subjects);
    %put NOTE: ================================================;
    
%mend import_tr;
